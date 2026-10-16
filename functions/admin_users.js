'use strict';

const { getApps, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const { validateAdminUpdatePayload } = require('./lib/admin_user_management_core');

if (getApps().length === 0) initializeApp();
const db = getFirestore();
const PAGE_SIZE = 100;
const PROFILE_FIELDS = [
  'firstName', 'lastName', 'phoneNumber', 'location', 'educationLevel',
  'employmentStatus', 'professionalTitle', 'bio',
];

async function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in with an administrator account.');
  }
  const hasAdminClaim = request.auth.token && request.auth.token.admin === true;
  if (!hasAdminClaim) {
    throw new HttpsError('permission-denied', 'This action requires the verified Firebase admin custom claim.');
  }
  return request.auth.uid;
}

async function getTarget(uid) {
  let authUser;
  try {
    authUser = await getAuth().getUser(uid);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError('not-found', 'The registered account no longer exists.');
    }
    throw error;
  }
  const profileRef = db.collection('users').doc(uid);
  const profileSnapshot = await profileRef.get();
  const profile = profileSnapshot.data() || {};
  if (profile.role === 'admin' || (authUser.customClaims && authUser.customClaims.admin === true)) {
    throw new HttpsError('failed-precondition', 'Administrator accounts cannot be edited or deleted from this screen.');
  }
  return { authUser, profileRef, profile };
}

function userForClient(authUser, profile) {
  const displayName = authUser.displayName || profile.displayName ||
    [profile.firstName, profile.lastName].filter(Boolean).join(' ');
  const nameParts = String(displayName || '').trim().split(/\s+/).filter(Boolean);
  return {
    uid: authUser.uid,
    email: authUser.email || profile.email || '',
    displayName: displayName || '',
    phoneNumber: profile.phoneNumber || authUser.phoneNumber || '',
    firstName: profile.firstName || nameParts[0] || '',
    lastName: profile.lastName || nameParts.slice(1).join(' '),
    location: profile.location || profile.barangay || '',
    educationLevel: profile.educationLevel || '',
    employmentStatus: profile.employmentStatus || '',
    professionalTitle: profile.professionalTitle || '',
    bio: profile.bio || '',
    role: profile.role || ((authUser.customClaims && authUser.customClaims.admin === true) ? 'admin' : 'job_seeker'),
    customAdmin: Boolean(authUser.customClaims && authUser.customClaims.admin === true),
    disabled: Boolean(authUser.disabled),
    createdAt: authUser.metadata && authUser.metadata.creationTime || '',
    lastSignInAt: authUser.metadata && authUser.metadata.lastSignInTime || '',
  };
}

async function writeAudit(actorUid, action, targetUid, details = {}) {
  await db.collection('adminAuditLogs').add({
    actorUid,
    action,
    targetUid,
    details,
    createdAt: FieldValue.serverTimestamp(),
  });
}

exports.adminListUsers = onCall({ region: 'us-central1', timeoutSeconds: 60, memory: '512MiB' }, async (request) => {
  await requireAdmin(request);
  const pageToken = request.data && typeof request.data.pageToken === 'string'
    ? request.data.pageToken : undefined;
  try {
    const page = await getAuth().listUsers(PAGE_SIZE, pageToken);
    const users = await Promise.all(page.users.map(async (authUser) => {
      const snapshot = await db.collection('users').doc(authUser.uid).get();
      return userForClient(authUser, snapshot.data() || {});
    }));
    return { users, nextPageToken: page.pageToken || null };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error('adminListUsers failed: ' + String(error && error.code || 'unknown'));
    throw new HttpsError('internal', 'Registered users could not be loaded.');
  }
});

exports.adminUpdateUser = onCall({ region: 'us-central1', timeoutSeconds: 60, memory: '512MiB' }, async (request) => {
  const actorUid = await requireAdmin(request);
  const parsed = validateAdminUpdatePayload(request.data);
  if (parsed.error) throw new HttpsError('invalid-argument', parsed.error);
  if (parsed.uid === actorUid) {
    throw new HttpsError('failed-precondition', 'Use your account settings to edit your own administrator profile.');
  }

  const { authUser, profileRef, profile: existing } = await getTarget(parsed.uid);
  const displayName = parsed.profile.firstName + ' ' + parsed.profile.lastName;
  const authUpdates = { displayName, disabled: parsed.disabled };
  if (parsed.profile.email !== (authUser.email || '')) {
    authUpdates.email = parsed.profile.email;
    authUpdates.emailVerified = false;
  }

  try {
    await getAuth().updateUser(parsed.uid, authUpdates);
    await profileRef.set({
      uid: parsed.uid,
      role: existing.role || 'job_seeker',
      ...parsed.profile,
      displayName,
      disabled: parsed.disabled,
      updatedAt: FieldValue.serverTimestamp(),
      adminUpdatedAt: FieldValue.serverTimestamp(),
      adminUpdatedBy: actorUid,
    }, { merge: true });
    await writeAudit(actorUid, 'user_updated', parsed.uid, {
      updatedFields: [...PROFILE_FIELDS, 'email', 'disabled'],
      emailChanged: parsed.profile.email !== (authUser.email || ''),
    });
    return { success: true, uid: parsed.uid, displayName, email: parsed.profile.email, disabled: parsed.disabled };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error('adminUpdateUser failed: ' + String(error && error.code || 'unknown'));
    if (error && error.code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'That email address is already used by another account.');
    }
    if (error && error.code === 'auth/invalid-email') {
      throw new HttpsError('invalid-argument', 'Enter a valid email address.');
    }
    throw new HttpsError('internal', 'The account was not fully updated. Refresh the account list before retrying.');
  }
});

exports.adminDeleteUser = onCall({ region: 'us-central1', timeoutSeconds: 120, memory: '512MiB' }, async (request) => {
  const actorUid = await requireAdmin(request);
  const uid = request.data && typeof request.data.uid === 'string' ? request.data.uid.trim() : '';
  if (!uid || uid.length > 128) throw new HttpsError('invalid-argument', 'A valid target user ID is required.');
  if (uid === actorUid) throw new HttpsError('failed-precondition', 'You cannot delete the currently signed-in administrator.');

  const { profileRef, profile } = await getTarget(uid);
  const cleanupWarnings = [];

  // Delete the identity first so the user cannot continue signing in. Cleanup
  // failures are returned explicitly and retained in the audit trail.
  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    console.error('adminDeleteUser auth deletion failed: ' + String(error && error.code || 'unknown'));
    throw new HttpsError('internal', 'Firebase Authentication could not delete this account.');
  }

  try {
    const bucket = getStorage().bucket();
    if (bucket.name) await bucket.deleteFiles({ prefix: 'users/' + uid + '/', force: true });
  } catch (error) {
    cleanupWarnings.push('Cloud Storage cleanup failed.');
    console.error('adminDeleteUser storage cleanup failed: ' + String(error && error.code || 'unknown'));
  }

  try {
    await db.recursiveDelete(profileRef);
  } catch (error) {
    cleanupWarnings.push('Firestore profile cleanup failed.');
    console.error('adminDeleteUser Firestore cleanup failed: ' + String(error && error.code || 'unknown'));
  }

  try {
    await writeAudit(actorUid, 'user_deleted', uid, {
      cleanupComplete: cleanupWarnings.length === 0,
      roleBeforeDeletion: profile.role || 'job_seeker',
    });
  } catch (error) {
    cleanupWarnings.push('Admin audit logging failed.');
    console.error('adminDeleteUser audit write failed: ' + String(error && error.code || 'unknown'));
  }

  return { success: true, uid, cleanupComplete: cleanupWarnings.length === 0, cleanupWarnings };
});
