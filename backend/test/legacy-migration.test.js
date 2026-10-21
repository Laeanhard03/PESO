import test from 'node:test';
import assert from 'node:assert/strict';
import { Writable } from 'node:stream';

let migrator;
try {
  migrator = await import('../src/legacy-migration.js');
} catch {
  migrator = null;
}

function requireMigrator() {
  assert.ok(
    migrator,
    'legacy migration helpers should exist before the migration contract tests run',
  );
  return migrator;
}

function createHarness() {
  const users = new Map([
    ['existing-user', { uid: 'existing-user', role: 'admin', displayName: 'Protected Admin' }],
  ]);
  const legacyUsers = [
    {
      id: 'existing-user',
      data: () => ({ displayName: 'Old Admin Display', role: 'admin' }),
    },
    {
      id: 'new-user',
      data: () => ({
        fullName: 'New Example',
        role: 'job_seeker',
        skills: ['Dart', 'Communication'],
        preferences: { language: 'Tagalog', appNotifications: false, unexpected: 'discard' },
      }),
    },
  ];
  const legacyArtifacts = new Map([
    ['existing-user', [{
      id: 'existing-artifact',
      data: () => ({
        id: 'existing-artifact',
        category: 'resume_upload',
        fileName: 'existing.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 5,
        storagePath: 'users/existing-user/artifacts/existing-artifact',
      }),
    }]],
    ['new-user', [{
      id: 'new-artifact',
      data: () => ({
        id: 'new-artifact',
        category: 'resume_upload',
        fileName: 'new.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 5,
        storagePath: 'users/new-user/artifacts/new-artifact',
        uploadedAt: new Date('2025-01-02T03:04:05.000Z'),
      }),
    }, {
      id: 'invalid-artifact',
      data: () => ({
        id: 'invalid-artifact',
        category: 'document',
        fileName: 'not-owned.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 5,
        storagePath: 'users/existing-user/artifacts/invalid-artifact',
      }),
    }]],
  ]);

  const storageObjects = new Map([
    ['users/existing-user/artifacts/existing-artifact', {
      bytes: Buffer.from('old-a'),
      mimeType: 'application/pdf',
    }],
    ['users/new-user/artifacts/new-artifact', {
      bytes: Buffer.from('new-b'),
      mimeType: 'application/pdf',
    }],
  ]);

  const firebaseUsers = new Map([
    ['existing-user', {
      uid: 'existing-user',
      email: 'admin@example.test',
      displayName: 'Auth Admin',
      emailVerified: true,
      phoneNumber: '',
      photoURL: '',
      providerData: [{ providerId: 'google.com' }],
    }],
    ['new-user', {
      uid: 'new-user',
      email: 'new@example.test',
      displayName: 'Auth New User',
      emailVerified: true,
      phoneNumber: '+15551234567',
      photoURL: 'https://example.test/photo.png',
      providerData: [{ providerId: 'google.com' }],
    }],
  ]);

  let profileWrites = 0;
  let artifactUploads = 0;
  const gridfsFiles = new Map();

  const firestore = {
    collection(name) {
      assert.equal(name, 'users');
      return {
        async get() {
          return { docs: legacyUsers };
        },
        doc(uid) {
          return {
            collection(subcollection) {
              assert.equal(subcollection, 'artifacts');
              return {
                async get() {
                  return { docs: legacyArtifacts.get(uid) || [] };
                },
              };
            },
          };
        },
      };
    },
  };

  const auth = {
    async getUser(uid) {
      const user = firebaseUsers.get(uid);
      if (!user) throw Object.assign(new Error('not found'), { code: 'auth/user-not-found' });
      return user;
    },
  };

  const mongoUsers = {
    async findOne(query) {
      return users.get(query.uid) || null;
    },
    async updateOne(query, update, options) {
      profileWrites += 1;
      assert.equal(options.upsert, true);
      assert.ok(update.$setOnInsert, 'profile migration must be insert-only');
      if (!users.has(query.uid)) {
        users.set(query.uid, { ...update.$setOnInsert });
        return { upsertedCount: 1 };
      }
      return { upsertedCount: 0, matchedCount: 1 };
    },
  };

  const mongoArtifactFiles = {
    async findOne(query) {
      const legacyPath = query['metadata.legacyStoragePath'];
      return gridfsFiles.get(legacyPath) || null;
    },
  };

  const storageBucket = {
    file(path) {
      const item = storageObjects.get(path);
      if (!item) {
        return {
          async getMetadata() {
            throw Object.assign(new Error('not found'), { code: 404 });
          },
          async download() {
            throw Object.assign(new Error('not found'), { code: 404 });
          },
        };
      }
      return {
        async getMetadata() {
          return [{
            size: String(item.bytes.length),
            contentType: item.mimeType,
          }];
        },
        async download() {
          return [Buffer.from(item.bytes)];
        },
      };
    },
  };

  const gridfsBucket = {
    openUploadStream(filename, options) {
      artifactUploads += 1;
      const chunks = [];
      const fileId = 'migrated-' + artifactUploads;
      const upload = new Writable({
        write(chunk, encoding, callback) {
          chunks.push(Buffer.from(chunk));
          callback();
        },
        final(callback) {
          const bytes = Buffer.concat(chunks);
          gridfsFiles.set(options.metadata.legacyStoragePath, {
            _id: fileId,
            filename,
            length: bytes.length,
            metadata: { ...options.metadata },
          });
          callback();
        },
      });
      upload.id = fileId;
      return upload;
    },
  };

  return {
    firestore,
    auth,
    mongoUsers,
    mongoArtifactFiles,
    storageBucket,
    gridfsBucket,
    users,
    gridfsFiles,
    get profileWrites() { return profileWrites; },
    get artifactUploads() { return artifactUploads; },
  };
}

test('buildLegacyMongoProfile maps identity and the approved legacy fields safely', () => {
  const { buildLegacyMongoProfile } = requireMigrator();
  const createdAt = new Date('2026-01-01T00:00:00.000Z');
  const profile = buildLegacyMongoProfile({
    uid: 'legacy-user',
    email: 'verified@example.test',
    emailVerified: true,
    phoneNumber: '+15551234567',
    name: 'Verified Identity',
    picture: 'https://example.test/photo.png',
    signInProvider: 'google.com',
  }, {}, {
    fullName: 'Legacy Name',
    role: 'admin',
    skills: ['Dart'],
    preferences: { language: 'Tagalog', appNotifications: false, unexpected: true },
    assessmentOutcomes: Array.from({ length: 105 }, (_, index) => ({ index })),
  }, createdAt);

  assert.equal(profile.uid, 'legacy-user');
  assert.equal(profile.email, 'verified@example.test');
  assert.equal(profile.displayName, 'Legacy Name');
  assert.equal(profile.role, 'admin');
  assert.equal(profile.emailVerified, true);
  assert.equal(profile.phoneNumber, '+15551234567');
  assert.deepEqual(profile.skills, ['Dart']);
  assert.deepEqual(profile.preferences, { language: 'Tagalog', appNotifications: false });
  assert.equal(profile.assessmentOutcomes.length, 100);
  assert.equal(profile.createdAt, createdAt);
  assert.equal(Object.hasOwn(profile, '_id'), false);
});

test('dry run previews missing profiles and valid Storage artifacts without writing', async () => {
  const { migrateLegacyData } = requireMigrator();
  const harness = createHarness();

  const result = await migrateLegacyData({ ...harness, apply: false });

  assert.equal(result.profilesScanned, 2);
  assert.equal(result.profilesWouldInsert, 1);
  assert.equal(result.profilesAlreadyPresent, 1);
  assert.equal(result.artifactsScanned, 3);
  assert.equal(result.artifactsWouldCopy, 2);
  assert.equal(result.artifactsSkippedInvalidPath, 1);
  assert.equal(harness.profileWrites, 0);
  assert.equal(harness.artifactUploads, 0);
  assert.equal(harness.users.get('existing-user').displayName, 'Protected Admin');
});

test('apply inserts only missing profiles and copies valid artifacts idempotently', async () => {
  const { migrateLegacyData } = requireMigrator();
  const harness = createHarness();

  const first = await migrateLegacyData({ ...harness, apply: true });
  assert.equal(first.profilesInserted, 1);
  assert.equal(first.profilesAlreadyPresent, 1);
  assert.equal(first.artifactsCopied, 2);
  assert.equal(first.artifactsSkippedInvalidPath, 1);
  assert.equal(harness.profileWrites, 1);
  assert.equal(harness.artifactUploads, 2);
  assert.equal(harness.users.get('existing-user').displayName, 'Protected Admin');
  assert.equal(harness.users.get('new-user').email, 'new@example.test');
  assert.equal(harness.gridfsFiles.get('users/new-user/artifacts/new-artifact').metadata.ownerUid, 'new-user');

  const second = await migrateLegacyData({ ...harness, apply: true });
  assert.equal(second.profilesInserted, 0);
  assert.equal(second.profilesAlreadyPresent, 2);
  assert.equal(second.artifactsCopied, 0);
  assert.equal(second.artifactsAlreadyPresent, 2);
  assert.equal(harness.profileWrites, 1);
  assert.equal(harness.artifactUploads, 2);
});

test('migration skips unsupported file types and files above the size limit', async () => {
  const { migrateLegacyData } = requireMigrator();
  const harness = createHarness();
  harness.storageBucket.file = (path) => {
    const mimeType = path.endsWith('existing-artifact') ? 'text/plain' : 'application/pdf';
    const bytes = Buffer.alloc(path.endsWith('new-artifact') ? 20 * 1024 * 1024 + 1 : 5);
    return {
      async getMetadata() {
        return [{ size: String(bytes.length), contentType: mimeType }];
      },
      async download() {
        return [bytes];
      },
    };
  };

  const result = await migrateLegacyData({ ...harness, apply: false, maxArtifactBytes: 20 * 1024 * 1024 });
  assert.equal(result.artifactsSkippedUnsupportedType, 1);
  assert.equal(result.artifactsSkippedTooLarge, 1);
  assert.equal(harness.profileWrites, 0);
  assert.equal(harness.artifactUploads, 0);
});
