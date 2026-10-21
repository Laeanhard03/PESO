$ErrorActionPreference = 'Stop'
$path = 'C:\Users\Admin\Desktop\Prototype\backend\server.js'
$expected = 'B03631781CAD94701B2A8F2D938AC42F0E92C2B29200230ABC92C72FF8CDE5CC'
$source = [System.IO.File]::ReadAllText($path)
function Replace-One([string]$Text, [string]$Old, [string]$New, [string]$Label) {
  $Text = [regex]::Replace($Text, "\r\n?", [string][char]10)
$Old = [regex]::Replace($Old, "\r\n?", [string][char]10)
$first = $Text.IndexOf($Old, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $Text.IndexOf($Old, $first + $Old.Length, [StringComparison]::Ordinal) -ge 0) { throw "anchor not unique: $Label" }
  return $Text.Substring(0,$first) + $New + $Text.Substring($first + $Old.Length)
}
function Replace-Range([string]$Text, [string]$Start, [string]$End, [string]$New, [string]$Label) {
  $a = $Text.IndexOf($Start, [StringComparison]::Ordinal)
  $b = if($a -ge 0) { $Text.IndexOf($End,$a + $Start.Length,[StringComparison]::Ordinal) } else { -1 }
  if ($a -lt 0 -or $b -lt 0 -or $Text.IndexOf($Start,$a + $Start.Length,[StringComparison]::Ordinal) -ge 0) { throw "range anchor failed: $Label" }
  return $Text.Substring(0,$a) + $New + [Environment]::NewLine + [Environment]::NewLine + $Text.Substring($b)
}
$actual = [BitConverter]::ToString(([System.Security.Cryptography.SHA256]::Create()).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($source))).Replace('-','')
if ($actual -ne $expected) { throw "server.js changed since inspection. Expected $expected got $actual; no changes made." }

$oldImports = @'
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

import dotenv from 'dotenv';
import express from 'express';
import { GridFSBucket, MongoClient, ObjectId } from 'mongodb';
import { GoogleGenAI } from '@google/genai';
import {
  applicationDefault,
  cert,
  getApps,
  initializeApp as initializeFirebaseAdminApp,
} from 'firebase-admin/app';
import { getAuth as getFirebaseAdminAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

import {
'@
$newImports = @'
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

import dotenv from 'dotenv';
import express from 'express';
import { GridFSBucket, MongoClient, ObjectId } from 'mongodb';
import { GoogleGenAI } from '@google/genai';
import { verifyFirebaseIdToken } from './src/firebase-id-token.js';

import {
'@
$source = Replace-One $source $oldImports $newImports 'imports'
$adminLine = "const DB_NAME = process.env.MONGODB_DB_NAME || 'peso_jobkonek';" + [Environment]::NewLine + "const BOOTSTRAP_ADMIN_EMAIL = (process.env.INITIAL_ADMIN_EMAIL || 'admin@example.invalid').trim().toLowerCase();"
$source = Replace-One $source "const DB_NAME = process.env.MONGODB_DB_NAME || 'peso_jobkonek';" $adminLine 'admin email config'
$oldState = @'
const state = {
  mongoClient: null,
  db: null,
  bucket: null,
  adminAuth: null,
  adminFirestore: null,
  firebaseAdminReady: false,
  mongoConnected: false,
  mongoProblem: null,
};
'@
$newState = @'
const state = {
  mongoClient: null,
  db: null,
  bucket: null,
  tokenVerifierOverride: null,
  mongoConnected: false,
  mongoProblem: null,
};
'@
$source = Replace-One $source $oldState $newState 'state'
$bootstrap = @'
function isBootstrapAdmin(identity) {
  return identity?.emailVerified === true &&
    identity?.signInProvider === 'google.com' &&
    String(identity.email || '').trim().toLowerCase() === BOOTSTRAP_ADMIN_EMAIL;
}
async function bootstrapAdminProfile(identity) {
  if (!state.mongoConnected || !state.db || !isBootstrapAdmin(identity)) return;
  const existing = await usersCollection().findOne({ uid: identity.uid });
  if (existing?.deleted === true) return;
  const now = new Date();
  await usersCollection().updateOne({ uid: identity.uid }, {
    $set: { role: 'admin', email: identity.email, emailVerified: true, updatedAt: now },
    $setOnInsert: {
      uid: identity.uid, displayName: identity.name || identity.email,
      firstName: String(identity.name || '').trim().split(/\s+/)[0] || '',
      lastName: String(identity.name || '').trim().split(/\s+/).slice(1).join(' '),
      createdAt: now, disabled: false, deleted: false,
    },
  }, { upsert: true });
}
'@
$source = Replace-Range $source 'function initFirebaseAdmin() {' 'async function connectMongo()' $bootstrap 'remove Firebase Admin initialization'
$auth = @'
async function requireAuth(req, res, next) {
  const header = req.get('authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) return res.status(401).json({ ok: false, error: 'missing_bearer_token' });
  let decoded;
  try {
    decoded = state.tokenVerifierOverride
      ? await state.tokenVerifierOverride(match[1])
      : await verifyFirebaseIdToken(match[1], PROJECT_ID);
  } catch (error) {
    if (error?.message === 'firebase_keys_unavailable' || error?.message === 'firebase_keys_invalid') {
      return res.status(503).json({ ok: false, error: 'firebase_token_verification_unavailable' });
    }
    return res.status(401).json({ ok: false, error: 'invalid_or_expired_token', message: 'Sign in again and retry the request.' });
  }
  req.user = {
    uid: decoded.uid || decoded.sub,
    email: decoded.email || '',
    name: decoded.name || decoded.displayName || '',
    picture: decoded.picture || decoded.photoURL || decoded.photoUrl || '',
    phoneNumber: decoded.phone_number || decoded.phoneNumber || '',
    emailVerified: decoded.email_verified === true || decoded.emailVerified === true,
    signInProvider: decoded.firebase?.sign_in_provider || decoded.signInProvider || '',
    admin: false,
    role: 'job_seeker',
  };
  if (!req.user.uid) return res.status(401).json({ ok: false, error: 'invalid_or_expired_token' });
  if (state.mongoConnected && state.db) {
    try {
      await bootstrapAdminProfile(req.user);
      const profile = await usersCollection().findOne({ uid: req.user.uid });
      if (profile?.deleted === true) return res.status(403).json({ ok: false, error: 'peso_account_deleted' });
      if (profile?.disabled === true) return res.status(403).json({ ok: false, error: 'peso_account_disabled' });
      req.user.role = String(profile?.role || 'job_seeker');
      req.user.admin = req.user.role === 'admin';
    } catch (error) { return next(error); }
  }
  return next();
}
'@
$source = Replace-Range $source 'async function requireAuth(req, res, next) {' 'function requireMongo(req, res, next)' $auth 'Mongo-backed request identity'
$adminGate = @'
function requireAdmin(req, res, next) {
  if (!state.mongoConnected || !state.db) return serviceUnavailable(res, 'mongodb');
  if (req.user?.role !== 'admin') {
    return res.status(403).json({
      ok: false, error: 'admin_required',
      message: 'This operation requires the admin role stored on the MongoDB user profile.',
    });
  }
  return next();
}
'@
$source = Replace-Range $source 'function requireAdmin(req, res, next) {' 'function usersCollection()' $adminGate 'MongoDB role gate'
$source = Replace-Range $source 'async function readLegacyFirestoreProfile(uid) {' 'function profileFromIdentity(' 'async function readLegacyFirestoreProfile() { return null; }' 'remove Firestore profile reads'
$source = [regex]::Replace($source, "const role = \['admin', 'job_seeker', 'employer', 'staff'\]\.includes\(old\.role\)\s*\? old\.role\s*:\s*'job_seeker';", "const role = isBootstrapAdmin(identity) ? 'admin' : 'job_seeker';", 1)
$source = [regex]::Replace($source, "const legacy = await readLegacyFirestoreProfile\(identity\.uid\);\s*const profile = profileFromIdentity\(identity, requested, legacy\);", "const profile = profileFromIdentity(identity, requested);", 1)
$source = Replace-One $source '    firebaseAdminReady: state.firebaseAdminReady,' "    firebaseTokenVerificationReady: true, appRolesStoredIn: 'mongodb'," 'health fields'
$adminRoutes = @'
function accountFromProfile(profile) {
  const data = profile && typeof profile === 'object' ? profile : {};
  const firstName = String(data.firstName || '');
  const lastName = String(data.lastName || '');
  const resumeData = data.resumeData && typeof data.resumeData === 'object' ? data.resumeData : {};
  const formData = data.pesoFormData && typeof data.pesoFormData === 'object' ? data.pesoFormData : {};
  const matchedJobs = data.matchedJobs;
  return {
    uid: String(data.uid || ''), email: String(data.email || ''),
    displayName: String(data.displayName || (firstName + ' ' + lastName).trim() || data.email || 'Unnamed account'),
    firstName, lastName, phoneNumber: String(data.phoneNumber || ''), photoURL: String(data.photoURL || ''),
    role: String(data.role || 'job_seeker'), customAdmin: data.role === 'admin',
    disabled: data.disabled === true, deleted: data.deleted === true,
    createdAt: data.createdAt || null, lastSignInAt: data.lastLoginAt || null,
    location: String(data.location || ''), educationLevel: String(data.educationLevel || ''),
    employmentStatus: String(data.employmentStatus || ''), professionalTitle: String(data.professionalTitle || ''),
    bio: String(data.bio || ''), profileCompleted: data.profileCompleted === true,
    resumeSubmitted: data.resumeSubmitted === true || Object.keys(resumeData).length > 0 || Boolean(data.resumeFileName || resumeData.fileName),
    formSubmitted: data.formSubmitted === true || Object.keys(formData).length > 0,
    matchStatus: ['matched', 'not_matched', 'pending'].includes(data.matchStatus) ? data.matchStatus : 'pending',
    matchedJobsCount: Number.isFinite(Number(data.matchedJobsCount)) ? Number(data.matchedJobsCount) :
      Array.isArray(matchedJobs) ? matchedJobs.length : matchedJobs && typeof matchedJobs === 'object' ? Object.keys(matchedJobs).length : 0,
    yearsExperience: Number(data.yearsExperience || data.aiProfile?.yearsExperience || 0) || 0,
    resumeFileName: String(data.resumeFileName || resumeData.fileName || ''),
  };
}

// Firebase verifies Google sign-in identity; MongoDB stores PESO roles and app status.
// Status/deletion below revokes PESO access, not the underlying Firebase Auth account.
app.get('/api/admin/users', requireAuth, requireAdmin, requireMongo, async (req, res, next) => {
  try {
    const n = Number.parseInt(String(req.query.limit || '100'), 10);
    const limit = Number.isFinite(n) ? Math.max(1, Math.min(500, n)) : 100;
    const rawToken = typeof req.query.pageToken === 'string' ? req.query.pageToken : '0';
    const offset = /^(0|[1-9][0-9]{0,8})$/.test(rawToken) ? Number.parseInt(rawToken, 10) : 0;
    const rows = await usersCollection().find({ deleted: { $ne: true } })
      .sort({ createdAt: -1, uid: 1 }).skip(offset).limit(limit + 1).toArray();
    const more = rows.length > limit;
    return res.json({ ok: true, mongoDbConnected: true,
      users: rows.slice(0, limit).map(accountFromProfile),
      nextPageToken: more ? String(offset + limit) : null,
      source: 'mongodb', authProviderMutationsAvailable: false });
  } catch (error) { return next(error); }
});
app.patch('/api/admin/users/:uid/profile', requireAuth, requireAdmin, requireMongo, async (req, res, next) => {
  try {
    const uid = String(req.params.uid || '').trim();
    if (!uid || uid.length > 128) return res.status(400).json({ ok: false, error: 'invalid_uid' });
    if (uid === req.user.uid) return res.status(403).json({ ok: false, error: 'cannot_edit_own_admin_profile' });
    const target = await usersCollection().findOne({ uid });
    if (!target || target.deleted === true) return res.status(404).json({ ok: false, error: 'user_not_found' });
    if (target.role === 'admin') return res.status(403).json({ ok: false, error: 'protected_admin_account' });
    const changes = sanitizeProfilePatch(req.body || {});
    if (!Object.keys(changes).length) return res.status(400).json({ ok: false, error: 'no_valid_profile_fields' });
    if (changes.firstName !== undefined || changes.lastName !== undefined) {
      changes.displayName = ((changes.firstName ?? target.firstName ?? '') + ' ' + (changes.lastName ?? target.lastName ?? '')).trim();
    }
    Object.assign(changes, { updatedAt: new Date(), adminUpdatedAt: new Date(), adminUpdatedBy: req.user.uid });
    await usersCollection().updateOne({ uid }, { $set: changes });
    return res.json({ ok: true, user: accountFromProfile(await usersCollection().findOne({ uid })) });
  } catch (error) { return next(error); }
});
app.patch('/api/admin/users/:uid/status', requireAuth, requireAdmin, requireMongo, async (req, res, next) => {
  try {
    const uid = String(req.params.uid || '').trim();
    if (!uid || uid.length > 128) return res.status(400).json({ ok: false, error: 'invalid_uid' });
    if (uid === req.user.uid) return res.status(403).json({ ok: false, error: 'cannot_disable_own_admin_account' });
    if (typeof req.body?.disabled !== 'boolean') return res.status(400).json({ ok: false, error: 'disabled_must_be_boolean' });
    const target = await usersCollection().findOne({ uid });
    if (!target || target.deleted === true) return res.status(404).json({ ok: false, error: 'user_not_found' });
    if (target.role === 'admin') return res.status(403).json({ ok: false, error: 'protected_admin_account' });
    await usersCollection().updateOne({ uid }, { $set: { disabled: req.body.disabled, updatedAt: new Date(), statusUpdatedBy: req.user.uid } });
    return res.json({ ok: true, source: 'mongodb', appAccessDisabled: req.body.disabled,
      firebaseAuthAccountChanged: false, user: accountFromProfile(await usersCollection().findOne({ uid })) });
  } catch (error) { return next(error); }
});
app.delete('/api/admin/users/:uid', requireAuth, requireAdmin, requireMongo, async (req, res, next) => {
  try {
    const uid = String(req.params.uid || '').trim();
    if (!uid || uid.length > 128) return res.status(400).json({ ok: false, error: 'invalid_uid' });
    if (uid === req.user.uid) return res.status(403).json({ ok: false, error: 'cannot_delete_own_admin_account' });
    const target = await usersCollection().findOne({ uid });
    if (!target || target.deleted === true) return res.status(404).json({ ok: false, error: 'user_not_found' });
    if (target.role === 'admin') return res.status(403).json({ ok: false, error: 'protected_admin_account' });
    let cleanupComplete = true;
    try {
      const files = await state.bucket.find({ 'metadata.ownerUid': uid }).toArray();
      for (const file of files) { try { await state.bucket.delete(file._id); } catch { cleanupComplete = false; } }
    } catch (error) { cleanupComplete = false; logSafeError('[Admin delete] GridFS cleanup incomplete', error); }
    await usersCollection().updateOne({ uid }, {
      $set: { email: '', displayName: 'Deleted PESO account', role: 'job_seeker', disabled: true,
        deleted: true, deletedAt: new Date(), deletedBy: req.user.uid, updatedAt: new Date() },
      $unset: { firstName: '', lastName: '', phoneNumber: '', photoURL: '', location: '',
        educationLevel: '', employmentStatus: '', professionalTitle: '', bio: '', skills: '',
        aiProfile: '', resumeData: '', pesoFormData: '', onboardingText: '', preferences: '',
        assessmentOutcomes: '', resumeFileName: '', matchedJobs: '', matchedJobsCount: '', yearsExperience: '' },
    });
    return res.json({ ok: true, uid, cleanupComplete, applicationAccessRevoked: true, firebaseAuthAccountDeleted: false });
  } catch (error) { return next(error); }
});
'@
$source = Replace-Range $source '// Admin account operations run on this API (not in the Flutter client).' "app.get('/api/artifacts'" $adminRoutes 'Mongo admin routes'
$source = Replace-One $source '  initFirebaseAdmin();' '' 'remove Firebase Admin startup'
[System.IO.File]::WriteAllText($path, $source, [System.Text.UTF8Encoding]::new($false))
$after = [BitConverter]::ToString(([System.Security.Cryptography.SHA256]::Create()).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($source))).Replace('-','')
Write-Output ('UPDATED_SHA256=' + $after)
Write-Output ('SERVER_BYTES=' + [System.Text.Encoding]::UTF8.GetByteCount($source))
