import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

import {
  MAX_ARTIFACT_BYTES,
  isAllowedMimeType,
  safeFileName,
  sanitizePreferences,
  sanitizeProfilePatch,
} from './security.js';

const LEGACY_ARTIFACT_ROOT = 'artifacts';

export function buildLegacyMongoProfile(identity, requested = {}, legacy = null, now = new Date()) {
  const old = legacy && typeof legacy === 'object' ? legacy : {};
  const fieldsFromClient = sanitizeProfilePatch(requested);
  const fullName = String(
    old.displayName || old.fullName || fieldsFromClient.displayName ||
    identity.name || (identity.email ? identity.email.split('@')[0] : 'PESO User'),
  ).trim();
  const parts = fullName.split(/\s+/).filter(Boolean);
  const role = ['admin', 'job_seeker', 'employer', 'staff'].includes(old.role)
    ? old.role
    : 'job_seeker';

  return {
    uid: identity.uid,
    role,
    email: identity.email || old.email || requested.email || '',
    displayName: fullName,
    firstName: String(fieldsFromClient.firstName || old.firstName || parts[0] || ''),
    lastName: String(fieldsFromClient.lastName || old.lastName || parts.slice(1).join(' ') || ''),
    phoneNumber: identity.phoneNumber || fieldsFromClient.phoneNumber || old.phoneNumber || '',
    photoURL: identity.picture || old.photoURL || '',
    providerIds: identity.signInProvider ? [identity.signInProvider] : (old.providerIds || []),
    emailVerified: identity.emailVerified === true,
    phoneVerified: Boolean(identity.phoneNumber || old.phoneVerified),
    location: String(fieldsFromClient.location || old.location || ''),
    educationLevel: String(fieldsFromClient.educationLevel || old.educationLevel || ''),
    employmentStatus: String(fieldsFromClient.employmentStatus || old.employmentStatus || 'Looking for work'),
    professionalTitle: String(fieldsFromClient.professionalTitle || old.professionalTitle || ''),
    bio: String(fieldsFromClient.bio || old.bio || ''),
    skills: Array.isArray(old.skills) ? old.skills : [],
    aiProfile: old.aiProfile && typeof old.aiProfile === 'object' ? old.aiProfile : {},
    resumeData: old.resumeData && typeof old.resumeData === 'object' ? old.resumeData : {},
    pesoFormData: old.pesoFormData && typeof old.pesoFormData === 'object' ? old.pesoFormData : {},
    onboardingText: typeof old.onboardingText === 'string' ? old.onboardingText : '',
    preferences: old.preferences && typeof old.preferences === 'object'
      ? sanitizePreferences(old.preferences)
      : { language: 'English', emailNotifications: true, appNotifications: true },
    assessmentOutcomes: Array.isArray(old.assessmentOutcomes) ? old.assessmentOutcomes.slice(0, 100) : [],
    profileCompleted: old.profileCompleted === true,
    createdAt: now,
    updatedAt: now,
    lastLoginAt: now,
    legacyFirestoreImported: Boolean(legacy),
  };
}

function toDate(value) {
  if (value instanceof Date && Number.isFinite(value.getTime())) return value;
  if (value && typeof value.toDate === 'function') {
    try {
      const date = value.toDate();
      if (date instanceof Date && Number.isFinite(date.getTime())) return date;
    } catch {
      return null;
    }
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const date = new Date(value);
    if (Number.isFinite(date.getTime())) return date;
  }
  return null;
}

function safeIdentity(user) {
  const provider = Array.isArray(user.providerData) ? user.providerData[0] : null;
  return {
    uid: user.uid,
    email: user.email || '',
    emailVerified: user.emailVerified === true,
    phoneNumber: user.phoneNumber || '',
    name: user.displayName || '',
    picture: user.photoURL || '',
    signInProvider: provider?.providerId || '',
  };
}

function initialStats() {
  return {
    profilesScanned: 0,
    profilesWouldInsert: 0,
    profilesInserted: 0,
    profilesAlreadyPresent: 0,
    profilesSkippedMissingAuth: 0,
    artifactsScanned: 0,
    artifactsWouldCopy: 0,
    artifactsCopied: 0,
    artifactsAlreadyPresent: 0,
    artifactsSkippedInvalidPath: 0,
    artifactsSkippedMissingAuth: 0,
    artifactsSkippedUnsupportedType: 0,
    artifactsSkippedTooLarge: 0,
    artifactsMissing: 0,
    errors: 0,
  };
}

/**
 * Copy existing PESO data from the legacy Firebase stores into MongoDB.
 *
 * All stores are injected so tests can prove the default dry-run has no writes.
 * Existing profile records are never updated. Existing GridFS copies are found
 * through metadata.legacyStoragePath, making sequential reruns idempotent.
 * No function in this module writes to or deletes from Firestore or Storage.
 */
export async function migrateLegacyData({
  firestore,
  auth,
  mongoUsers,
  mongoArtifactFiles,
  gridfsBucket,
  storageBucket,
  apply = false,
  limit = Infinity,
  maxArtifactBytes = MAX_ARTIFACT_BYTES,
  now = () => new Date(),
}) {
  if (!firestore || !auth || !mongoUsers || !mongoArtifactFiles || !gridfsBucket || !storageBucket) {
    throw new TypeError('Firestore, Firebase Auth, MongoDB collections, GridFS, and Storage are required.');
  }
  if (!(limit === Infinity || (Number.isInteger(limit) && limit > 0))) {
    throw new TypeError('limit must be a positive integer or Infinity.');
  }
  if (!Number.isInteger(maxArtifactBytes) || maxArtifactBytes < 1) {
    throw new TypeError('maxArtifactBytes must be a positive integer.');
  }

  const stats = initialStats();
  const userCollection = firestore.collection('users');
  const userQuery = limit === Infinity ? userCollection : userCollection.limit(limit);
  const userSnapshot = await userQuery.get();
  const userDocs = Array.isArray(userSnapshot.docs) ? userSnapshot.docs.slice(0, limit) : [];

  for (const userDoc of userDocs) {
    stats.profilesScanned += 1;
    const uid = String(userDoc.id || '');
    if (!uid || uid.includes('/')) {
      stats.errors += 1;
      continue;
    }

    let authUser;
    try {
      authUser = await auth.getUser(uid);
    } catch (error) {
      if (error?.code === 'auth/user-not-found') stats.profilesSkippedMissingAuth += 1;
      else stats.errors += 1;
      continue;
    }

    try {
      const existingProfile = await mongoUsers.findOne({ uid });
      if (existingProfile) {
        stats.profilesAlreadyPresent += 1;
      } else {
        const profile = buildLegacyMongoProfile(
          safeIdentity(authUser),
          {},
          userDoc.data() || {},
          now(),
        );
        if (!apply) {
          stats.profilesWouldInsert += 1;
        } else {
          const result = await mongoUsers.updateOne(
            { uid },
            { $setOnInsert: profile },
            { upsert: true },
          );
          if (result?.upsertedCount === 1) stats.profilesInserted += 1;
          else stats.profilesAlreadyPresent += 1;
        }
      }
    } catch {
      stats.errors += 1;
    }

    let artifactDocs;
    try {
      const artifactSnapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection(LEGACY_ARTIFACT_ROOT)
        .get();
      artifactDocs = Array.isArray(artifactSnapshot.docs) ? artifactSnapshot.docs : [];
    } catch {
      stats.errors += 1;
      continue;
    }

    for (const artifactDoc of artifactDocs) {
      stats.artifactsScanned += 1;
      const artifact = artifactDoc.data() || {};
      const artifactId = String(artifactDoc.id || artifact.id || '');
      const storagePath = String(artifact.storagePath || '');
      const expectedStoragePath = 'users/' + uid + '/artifacts/' + artifactId;
      if (!artifactId || storagePath !== expectedStoragePath) {
        stats.artifactsSkippedInvalidPath += 1;
        continue;
      }

      let existingArtifact;
      try {
        existingArtifact = await mongoArtifactFiles.findOne({
          'metadata.ownerUid': uid,
          'metadata.legacyStoragePath': storagePath,
        });
      } catch {
        stats.errors += 1;
        continue;
      }
      if (existingArtifact) {
        stats.artifactsAlreadyPresent += 1;
        continue;
      }

      const sourceFile = storageBucket.file(storagePath);
      let sourceMetadata;
      try {
        const [metadata] = await sourceFile.getMetadata();
        sourceMetadata = metadata;
      } catch (error) {
        if (error?.code === 404 || error?.code === '404' || error?.code === 'storage/object-not-found') {
          stats.artifactsMissing += 1;
        } else {
          stats.errors += 1;
        }
        continue;
      }

      const firestoreMime = String(artifact.mimeType || '').trim().toLowerCase();
      const storageMime = String(sourceMetadata.contentType || '').trim().toLowerCase();
      if (!isAllowedMimeType(firestoreMime) ||
          !isAllowedMimeType(storageMime) ||
          firestoreMime !== storageMime) {
        stats.artifactsSkippedUnsupportedType += 1;
        continue;
      }

      const declaredBytes = Number(sourceMetadata.size ?? artifact.sizeBytes ?? 0);
      if (!Number.isFinite(declaredBytes) || declaredBytes < 0 || declaredBytes > maxArtifactBytes) {
        stats.artifactsSkippedTooLarge += 1;
        continue;
      }

      if (!apply) {
        stats.artifactsWouldCopy += 1;
        continue;
      }

      let uploadedId;
      try {
        const [bytes] = await sourceFile.download();
        if (!Buffer.isBuffer(bytes) || bytes.length === 0) {
          stats.artifactsMissing += 1;
          continue;
        }
        if (bytes.length > maxArtifactBytes) {
          stats.artifactsSkippedTooLarge += 1;
          continue;
        }

        const filename = safeFileName(artifact.fileName || artifact.originalFileName || artifactId);
        const uploadedAt = toDate(artifact.uploadedAt);
        const upload = gridfsBucket.openUploadStream(filename, {
          contentType: firestoreMime,
          metadata: {
            ownerUid: uid,
            category: String(artifact.category || 'document').slice(0, 80),
            originalFileName: filename,
            mimeType: firestoreMime,
            legacyStoragePath: storagePath,
            legacyFirestoreArtifactId: artifactId,
            legacyUploadedAt: uploadedAt,
          },
        });
        uploadedId = upload.id;
        await pipeline(Readable.from([bytes]), upload);
        stats.artifactsCopied += 1;
      } catch {
        if (uploadedId) {
          try {
            await gridfsBucket.delete(uploadedId);
          } catch {
            // Keep the source file; a rerun can inspect the migration state.
          }
        }
        stats.errors += 1;
      }
    }
  }

  return stats;
}
