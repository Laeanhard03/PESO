import test from 'node:test';
import assert from 'node:assert/strict';

import { migrateLegacyData } from '../src/legacy-migration.js';

test('migration applies the requested limit in the Firestore query before iterating', async () => {
  const docs = [
    { id: 'a-user', data: () => ({}) },
    { id: 'b-user', data: () => ({}) },
  ];
  let requestedLimit = null;
  let fullCollectionReads = 0;

  const firestore = {
    collection(name) {
      assert.equal(name, 'users');
      const ref = {
        async get() {
          fullCollectionReads += 1;
          return { docs };
        },
        limit(count) {
          requestedLimit = count;
          return { async get() { return { docs: docs.slice(0, count) }; } };
        },
        doc() {
          return { collection() { return { async get() { return { docs: [] }; } }; } };
        },
      };
      return ref;
    },
  };
  const auth = {
    async getUser(uid) {
      return { uid, email: uid + '@example.test', providerData: [] };
    },
  };

  const result = await migrateLegacyData({
    firestore,
    auth,
    mongoUsers: { async findOne() { return { uid: 'already-migrated' }; } },
    mongoArtifactFiles: { async findOne() { return null; } },
    gridfsBucket: { openUploadStream() { assert.fail('dry run must not upload'); } },
    storageBucket: { file() { assert.fail('no artifacts should be read'); } },
    apply: false,
    limit: 1,
  });

  assert.equal(requestedLimit, 1);
  assert.equal(fullCollectionReads, 0);
  assert.equal(result.profilesScanned, 1);
});
