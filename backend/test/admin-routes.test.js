import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { app, state } from '../server.js';

const profiles = new Map();
const authUsers = new Map();

function userRecord(uid, overrides = {}) {
  return {
    uid,
    email: uid + '@example.test',
    displayName: uid,
    phoneNumber: '',
    photoURL: '',
    disabled: false,
    emailVerified: true,
    customClaims: {},
    metadata: {
      creationTime: '2026-01-01T00:00:00.000Z',
      lastSignInTime: '2026-10-01T00:00:00.000Z',
    },
    ...overrides,
  };
}

function resetFixtures() {
  profiles.clear();
  authUsers.clear();

  authUsers.set('admin-uid', userRecord('admin-uid', {
    email: 'admin@example.invalid',
    displayName: 'PESO Administrator',
    customClaims: { admin: true },
  }));
  authUsers.set('user-one', userRecord('user-one', {
    email: 'one@example.test',
    displayName: 'Original User',
  }));
  authUsers.set('user-two', userRecord('user-two', {
    email: 'two@example.test',
    displayName: 'Second User',
  }));

  profiles.set('user-one', {
    uid: 'user-one',
    role: 'job_seeker',
    email: 'one@example.test',
    firstName: 'Original',
    lastName: 'User',
    displayName: 'Original User',
    location: 'Balite',
    resumeData: {},
    pesoFormData: {},
  });
  profiles.set('user-two', {
    uid: 'user-two',
    role: 'job_seeker',
    email: 'two@example.test',
    firstName: 'Second',
    lastName: 'User',
    displayName: 'Second User',
  });
}

const profileCollection = {
  async findOne({ uid }) {
    return profiles.has(uid) ? structuredClone(profiles.get(uid)) : null;
  },
  find(filter = {}) {
    const requested = filter.uid?.$in;
    let documents = [...profiles.values()].filter((doc) => {
      const matchesUid = !Array.isArray(requested) || requested.includes(doc.uid);
      const matchesAuthDeletion = filter.firebaseAuthAccountDeleted?.$ne !== true ||
        doc.firebaseAuthAccountDeleted !== true;
      const matchesPending = filter.deletionPending !== true || doc.deletionPending === true;
      const matchesDeleted = filter.deleted !== true || doc.deleted === true;
      return matchesUid && matchesAuthDeletion && matchesPending && matchesDeleted;
    });
    return { sort() { documents.sort((a, b) => (a.createdAt ? 0 : 1) - (b.createdAt ? 0 : 1)); return this; }, skip(count) { documents = documents.slice(count); return this; }, limit(maximum) { documents = documents.slice(0, maximum); return this; }, toArray: async () => structuredClone(documents) };
  },
  async updateOne({ uid }, update, options = {}) {
    let profile = profiles.get(uid);
    if (!profile && options.upsert) {
      profile = structuredClone(update.$setOnInsert || { uid });
      profiles.set(uid, profile);
    }
    if (profile && update.$set) Object.assign(profile, structuredClone(update.$set));
    if (profile && update.$unset) for (const field of Object.keys(update.$unset)) delete profile[field];
    return { matchedCount: profile ? 1 : 0, upsertedCount: 0 };
  },
  async deleteOne({ uid }) {
    const deletedCount = profiles.delete(uid) ? 1 : 0;
    return { deletedCount };
  },
};

const fakeAuth = {
  async verifyIdToken(token) {
    if (token === 'admin-token') {
      return {
        uid: 'admin-uid',
        email: 'admin@example.test',
        name: 'PESO Administrator',
        admin: true,
        email_verified: true,
        firebase: { sign_in_provider: 'google.com' },
      };
    }
    if (token === 'user-token') {
      return {
        uid: 'user-one',
        email: 'one@example.test',
        name: 'Original User',
        admin: false,
        email_verified: true,
        firebase: { sign_in_provider: 'password' },
      };
    }
    throw new Error('Invalid token');
  },
  async listUsers(limit, pageToken) {
    const all = [...authUsers.values()].sort((a, b) => a.uid.localeCompare(b.uid));
    const offset = pageToken ? Number.parseInt(pageToken, 10) : 0;
    const users = all.slice(offset, offset + limit).map((item) => structuredClone(item));
    const nextOffset = offset + users.length;
    return {
      users,
      pageToken: nextOffset < all.length ? String(nextOffset) : undefined,
    };
  },
  async getUser(uid) {
    if (!authUsers.has(uid)) {
      throw Object.assign(new Error('User not found'), { code: 'auth/user-not-found' });
    }
    return structuredClone(authUsers.get(uid));
  },
  async updateUser(uid, changes) {
    if (!authUsers.has(uid)) {
      throw Object.assign(new Error('User not found'), { code: 'auth/user-not-found' });
    }
    const updated = { ...authUsers.get(uid), ...changes };
    authUsers.set(uid, updated);
    return structuredClone(updated);
  },
  async deleteUser(uid) {
    if (!authUsers.delete(uid)) {
      throw Object.assign(new Error('User not found'), { code: 'auth/user-not-found' });
    }
  },
};

let baseUrl;
let server;

before(async () => {
  resetFixtures();
  state.tokenVerifierOverride = async (token) => {
    if (token === 'admin-token') return {
      uid: 'admin-uid', email: 'admin@example.invalid', name: 'PESO Administrator',
      email_verified: true, firebase: { sign_in_provider: 'google.com' },
    };
    if (token === 'user-token') return {
      uid: 'user-one', email: 'one@example.test', name: 'Original User',
      email_verified: true, firebase: { sign_in_provider: 'password' },
    };
    if (token === 'unverified-admin-token') return {
      uid: 'unverified-admin', email: 'admin@example.invalid', name: 'Unverified Admin',
      email_verified: false, firebase: { sign_in_provider: 'google.com' },
    };
    if (token === 'password-admin-token') return {
      uid: 'password-admin', email: 'admin@example.invalid', name: 'Password Provider',
      email_verified: true, firebase: { sign_in_provider: 'password' },
    };
    throw new Error('Invalid token');
  };
  state.mongoConnected = true;
  state.mongoProblem = null;
  state.db = {
    collection(name) {
      if (name === 'users') return profileCollection;
      throw new Error('Unexpected collection: ' + name);
    },
  };
  state.bucket = {
    find() {
      return { toArray: async () => [] };
    },
    async delete() {},
  };
  state.firebaseAdminAuthOverride = fakeAuth;
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = 'http://127.0.0.1:' + server.address().port;
});

after(async () => {
  const closed = new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
  server.closeAllConnections?.();
  await closed;
  state.tokenVerifierOverride = null;
  state.firebaseAdminAuthOverride = null;
  state.mongoConnected = false;
  state.db = null;
  state.bucket = null;
});

async function request(path, { token, method = 'GET', body } = {}) {
  const headers = {};
  if (token) headers.Authorization = 'Bearer ' + token;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  headers.Connection = 'close';
  return fetch(baseUrl + path, {
    method,
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

test('browser CORS preflight permits the protected admin DELETE method', async () => {
  const response = await fetch(baseUrl + '/api/admin/users/user-two', {
    method: 'OPTIONS',
    headers: {
      Origin: 'http://localhost:5237',
      'Access-Control-Request-Method': 'DELETE',
      'Access-Control-Request-Headers': 'authorization,content-type',
      Connection: 'close',
    },
  });
  assert.equal(response.status, 204);
  const allowedMethods = (response.headers.get('access-control-allow-methods') || '')
    .split(',')
    .map((method) => method.trim());
  assert.ok(allowedMethods.includes('DELETE'));
  assert.equal(response.headers.get('access-control-allow-origin'), 'http://localhost:5237');
});

test('admin endpoints reject missing and non-admin identities', async () => {
  const missing = await request('/api/admin/users');
  assert.equal(missing.status, 401);
  assert.equal((await missing.json()).error, 'missing_bearer_token');

  const regularUser = await request('/api/admin/users', { token: 'user-token' });
  assert.equal(regularUser.status, 403);
  assert.equal((await regularUser.json()).error, 'admin_required');
});

test('bootstrap admin requires a verified Google identity for the exact allowlisted email', async () => {
  for (const [token, uid] of [
    ['unverified-admin-token', 'unverified-admin'],
    ['password-admin-token', 'password-admin'],
  ]) {
    const response = await request('/api/admin/users', { token });
    assert.equal(response.status, 403);
    assert.equal(profiles.has(uid), false);
  }
});

test('admin list joins Firebase Auth accounts with safe MongoDB profile fields and paginates', async () => {
  const first = await request('/api/admin/users?limit=2', { token: 'admin-token' });
  assert.equal(first.status, 200);
  const payload = await first.json();
  assert.equal(payload.users.length, 2);
  assert.equal(payload.source, 'firebase_auth+mongodb');
  assert.equal(payload.authProviderMutationsAvailable, true);
  assert.ok(payload.nextPageToken);
  const admin = payload.users.find((item) => item.uid === 'admin-uid');
  assert.equal(admin.customAdmin, true);
  assert.equal(admin.role, 'admin');
  const user = payload.users.find((item) => item.uid === 'user-one');
  assert.equal(user.displayName, 'Original User');
  assert.equal(user.location, 'Balite');
  assert.equal(user.disabled, false);
  assert.equal(Object.hasOwn(user, 'resumeData'), false);

  const second = await request('/api/admin/users?limit=2&pageToken=' +
    encodeURIComponent(payload.nextPageToken), { token: 'admin-token' });
  assert.equal(second.status, 200);
  assert.equal((await second.json()).users.length, 1);
});

test('admin listing includes Firebase Auth users without MongoDB profiles and can delete an orphan', async () => {
  authUsers.set('orphan-user', userRecord('orphan-user', {
    email: 'orphan@example.test',
    displayName: 'Orphan User',
  }));

  const response = await request('/api/admin/users?limit=50', { token: 'admin-token' });
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.equal(result.authProviderMutationsAvailable, true);
  const orphan = result.users.find((item) => item.uid === 'orphan-user');
  assert.ok(orphan);
  assert.equal(orphan.profileMissing, true);
  assert.equal(orphan.firebaseAuthAccountExists, true);
  assert.equal(orphan.role, 'job_seeker');
  assert.equal(profiles.has('orphan-user'), false);

  const deleted = await request('/api/admin/users/orphan-user', {
    token: 'admin-token',
    method: 'DELETE',
  });
  assert.equal(deleted.status, 200);
  assert.equal((await deleted.json()).firebaseAuthAccountDeleted, true);
  assert.equal(authUsers.has('orphan-user'), false);
  assert.equal(profiles.get('orphan-user').deleted, true);
  assert.equal(profiles.get('orphan-user').firebaseAuthAccountDeleted, true);
  assert.equal(profiles.get('orphan-user').email, '');
});

test('admin listing falls back to MongoDB and reports unavailable Firebase Admin credentials', async () => {
  const originalListUsers = fakeAuth.listUsers;
  try {
    fakeAuth.listUsers = async () => {
      throw Object.assign(new Error('Sensitive credential details.'), {
        code: 'auth/insufficient-permission',
      });
    };
    const response = await request('/api/admin/users', { token: 'admin-token' });
    assert.equal(response.status, 200);
    const result = await response.json();
    assert.equal(result.source, 'mongodb');
    assert.equal(result.authProviderMutationsAvailable, false);
    assert.ok(result.users.some((item) => item.uid === 'user-one'));
    assert.equal(JSON.stringify(result).includes('Sensitive credential details'), false);
  } finally {
    fakeAuth.listUsers = originalListUsers;
    resetFixtures();
  }
});

test('admin profile updates allow only whitelisted profile fields and write server-side audit identity', async () => {
  const response = await request('/api/admin/users/user-one/profile', {
    token: 'admin-token',
    method: 'PATCH',
    body: {
      firstName: 'Updated',
      lastName: 'Candidate',
      location: 'Wawa',
      role: 'admin',
      uid: 'admin-uid',
      email: 'spoofed@example.test',
    },
  });
  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.equal(payload.user.uid, 'user-one');
  assert.equal(payload.user.displayName, 'Updated Candidate');
  assert.equal(payload.user.role, 'job_seeker');
  assert.equal(payload.user.email, 'one@example.test');
  assert.equal(profiles.get('user-one').adminUpdatedBy, 'admin-uid');
  assert.equal(profiles.get('user-one').location, 'Wawa');
});

test('admin cannot edit, disable, or delete its own account or another admin account', async () => {
  for (const [method, path, body] of [
    ['PATCH', '/api/admin/users/admin-uid/profile', { firstName: 'Change' }],
    ['PATCH', '/api/admin/users/admin-uid/status', { disabled: true }],
    ['DELETE', '/api/admin/users/admin-uid', undefined],
  ]) {
    const response = await request(path, { token: 'admin-token', method, body });
    assert.equal(response.status, 403);
  }

  authUsers.set('other-admin', userRecord('other-admin', {
    customClaims: { admin: true },
  }));
  profiles.set('other-admin', { uid: 'other-admin', role: 'admin' });
  const response = await request('/api/admin/users/other-admin/status', {
    token: 'admin-token',
    method: 'PATCH',
    body: { disabled: true },
  });
  assert.equal(response.status, 403);
  assert.equal(authUsers.get('other-admin').disabled, false);
});

test('admin can disable or enable a regular Auth account through the trusted API', async () => {
  const disabled = await request('/api/admin/users/user-one/status', {
    token: 'admin-token',
    method: 'PATCH',
    body: { disabled: true },
  });
  assert.equal(disabled.status, 200);
  assert.equal((await disabled.json()).user.disabled, true);
  assert.equal(profiles.get('user-one').disabled, true);

  const enabled = await request('/api/admin/users/user-one/status', {
    token: 'admin-token',
    method: 'PATCH',
    body: { disabled: false },
  });
  assert.equal(enabled.status, 200);
  assert.equal((await enabled.json()).user.disabled, false);
});

test('admin delete removes a regular Firebase Auth account and tombstones its MongoDB profile', async () => {
  const response = await request('/api/admin/users/user-two', {
    token: 'admin-token',
    method: 'DELETE',
  });
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.equal(result.cleanupComplete, true);
  assert.equal(result.firebaseAuthAccountDeleted, true);
  assert.equal(authUsers.has('user-two'), false);
  assert.equal(profiles.get('user-two').deleted, true);
});

test('admin deletion keeps app access revoked and can retry Firebase Auth cleanup safely', async () => {
  resetFixtures();
  const originalDeleteUser = fakeAuth.deleteUser;
  try {
    fakeAuth.deleteUser = async () => {
      throw Object.assign(new Error('Sensitive Firebase detail must not be returned.'), {
        code: 'auth/insufficient-permission',
      });
    };

    const first = await request('/api/admin/users/user-two', {
      token: 'admin-token',
      method: 'DELETE',
    });
    assert.equal(first.status, 503);
    const firstResult = await first.json();
    assert.equal(firstResult.error, 'firebase_auth_delete_failed');
    assert.equal(firstResult.applicationAccessRevoked, true);
    assert.equal(firstResult.firebaseAuthAccountDeleted, false);
    assert.equal(JSON.stringify(firstResult).includes('Sensitive Firebase detail'), false);
    assert.equal(profiles.get('user-two').deleted, undefined);
    assert.equal(profiles.get('user-two').deletionPending, true);
    assert.equal(profiles.get('user-two').disabled, true);
    assert.equal(profiles.get('user-two').email, '');
    assert.equal(profiles.get('user-two').displayName, 'Account deletion pending');
    assert.equal(Object.hasOwn(profiles.get('user-two'), 'phoneNumber'), false);
    assert.equal(authUsers.has('user-two'), true);

    const pendingList = await request('/api/admin/users', { token: 'admin-token' });
    assert.equal(pendingList.status, 200);
    const pendingAccount = (await pendingList.json()).users.find((item) => item.uid === 'user-two');
    assert.ok(pendingAccount, 'failed deletions remain visible for retry');
    assert.equal(pendingAccount.disabled, true);
    assert.equal(pendingAccount.email, '');

    const reopen = await request('/api/admin/users/user-two/status', {
      token: 'admin-token',
      method: 'PATCH',
      body: { disabled: false },
    });
    assert.equal(reopen.status, 409);
    assert.equal((await reopen.json()).error, 'account_deletion_pending');
    const edit = await request('/api/admin/users/user-two/profile', {
      token: 'admin-token',
      method: 'PATCH',
      body: { firstName: 'Must not return' },
    });
    assert.equal(edit.status, 409);
    assert.equal((await edit.json()).error, 'account_deletion_pending');
    assert.equal(profiles.get('user-two').disabled, true);
    assert.equal(profiles.get('user-two').firstName, undefined);

    fakeAuth.deleteUser = originalDeleteUser;
    const retry = await request('/api/admin/users/user-two', {
      token: 'admin-token',
      method: 'DELETE',
    });
    assert.equal(retry.status, 200);
    assert.equal((await retry.json()).firebaseAuthAccountDeleted, true);
    assert.equal(authUsers.has('user-two'), false);
    assert.equal(profiles.get('user-two').deleted, true);
    assert.equal(profiles.get('user-two').deletionPending, undefined);
    const completedList = await request('/api/admin/users', { token: 'admin-token' });
    assert.equal((await completedList.json()).users.some((item) => item.uid === 'user-two'), false);

    const repeated = await request('/api/admin/users/user-two', {
      token: 'admin-token',
      method: 'DELETE',
    });
    assert.equal(repeated.status, 200);
    assert.equal((await repeated.json()).cleanupComplete, true);
  } finally {
    fakeAuth.deleteUser = originalDeleteUser;
    resetFixtures();
  }
});

test('Mongo-backed Admin operations fail closed when MongoDB is unavailable', async () => {
  resetFixtures();
  state.mongoConnected = false;
  state.mongoProblem = 'MongoConnectionError';
  state.db = null;
  state.bucket = null;
  for (const [method, path, body] of [
    ['GET', '/api/admin/users', undefined],
    ['PATCH', '/api/admin/users/user-one/status', { disabled: true }],
    ['DELETE', '/api/admin/users/user-two', undefined],
  ]) {
    const response = await request(path, { token: 'admin-token', method, body });
    assert.equal(response.status, 503);
    assert.equal((await response.json()).error, 'mongodb_not_ready');
  }
  assert.equal(profiles.has('user-two'), true);
});
