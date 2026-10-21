import assert from 'node:assert/strict';
import express from 'express';
import test from 'node:test';

import { createGeminiKeyRouter } from '../src/gemini-key-routes.js';

const testKeyValue = 'fake-gemini-key-for-route-tests-ABCD';
const baseMetadata = (id, label) => ({
  id,
  label,
  maskedSuffix: '••••ABCD',
  enabled: true,
  health: 'ready',
  cooldownUntil: null,
  lastUsedAt: null,
  lastTestedAt: null,
  lastErrorCategory: null,
  createdAt: '2026-10-18T00:00:00.000Z',
  updatedAt: '2026-10-18T00:00:00.000Z',
});

function makeStore() {
  const keys = new Map();
  const calls = [];
  let nextId = 1;
  let activated = false;
  const store = {
    calls,
    keys,
    async getPoolSettings() { return { managedPoolActivated: activated }; },
    async listPublicKeys() { return [...keys.values()].map(({ metadata }) => structuredClone(metadata)); },
    async getPublicKey(id) { return keys.get(id)?.metadata ?? null; },
    async getKeyRecord(id) { return keys.get(id)?.record ?? null; },
    async createKey({ label, apiKey, actorUid }) {
      calls.push({ method: 'createKey', apiKey, actorUid });
      const id = String(nextId++).padStart(24, '0');
      const metadata = baseMetadata(id, label);
      keys.set(id, { metadata, record: { _id: id, label, encryptedPayload: 'ciphertext' } });
      activated = true;
      return structuredClone(metadata);
    },
    async updateKey(id, changes) {
      calls.push({ method: 'updateKey', id, changes });
      const item = keys.get(id);
      if (!item) return null;
      if (changes.label) item.metadata.label = changes.label;
      if (changes.apiKey) item.metadata.maskedSuffix = '••••ABCD';
      item.record.label = item.metadata.label;
      return structuredClone(item.metadata);
    },
    async setEnabled(id, enabled, actorUid) {
      calls.push({ method: 'setEnabled', id, enabled, actorUid });
      const item = keys.get(id);
      if (!item) return null;
      item.metadata.enabled = enabled;
      item.metadata.health = enabled ? 'ready' : 'disabled';
      return structuredClone(item.metadata);
    },
    async deleteKey(id, actorUid) {
      calls.push({ method: 'deleteKey', id, actorUid });
      return keys.delete(id);
    },
  };
  return store;
}

function setup({ user = null, mongoReady = true, store = makeStore(), testKey } = {}) {
  const app = express();
  app.use(express.json());
  const requireAuth = (req, res, next) => {
    const token = (req.get('authorization') || '').replace(/^Bearer\s+/i, '');
    if (!token) return res.status(401).json({ ok: false, error: 'authentication_required' });
    const identity = user ?? (token === 'admin-token'
      ? { uid: 'admin-uid', role: 'admin' }
      : token === 'user-token'
        ? { uid: 'user-uid', role: 'job_seeker' }
        : null);
    if (!identity) return res.status(401).json({ ok: false, error: 'invalid_or_expired_token' });
    req.user = identity;
    return next();
  };
  const requireAdmin = (req, res, next) => req.user.role === 'admin'
    ? next()
    : res.status(403).json({ ok: false, error: 'admin_required' });
  const requireMongo = (_req, res, next) => mongoReady
    ? next()
    : res.status(503).json({ ok: false, error: 'mongodb_not_ready' });
  app.use('/api', createGeminiKeyRouter({
    express,
    requireAuth,
    requireAdmin,
    requireMongo,
    getStore: () => store,
    testKey: testKey ?? (async () => ({ passed: true, category: 'test_success' })),
  }));
  const server = app.listen(0, '127.0.0.1');
  return new Promise((resolve) => {
    server.on('listening', () => resolve({
      server,
      store,
      async request(path, { method = 'GET', token, body } = {}) {
        const response = await fetch('http://127.0.0.1:' + server.address().port + path, {
          method,
          headers: {
            ...(token ? { authorization: 'Bearer ' + token } : {}),
            ...(body !== undefined ? { 'content-type': 'application/json' } : {}),
          },
          ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
        });
        return { status: response.status, json: await response.json() };
      },
      close: () => new Promise((done) => server.close(done)),
    }));
  });
}

test('key-list route requires authentication, admin role, and MongoDB readiness', async () => {
  const app = await setup();
  try {
    assert.equal((await app.request('/api/admin/gemini-keys')).status, 401);
    assert.equal((await app.request('/api/admin/gemini-keys', { token: 'user-token' })).status, 403);
  } finally { await app.close(); }

  const unavailable = await setup({ mongoReady: false });
  try {
    assert.equal((await unavailable.request('/api/admin/gemini-keys', { token: 'admin-token' })).status, 503);
  } finally { await unavailable.close(); }
});

test('key-list reports only a boolean for the legacy environment fallback', async () => {
  const original = process.env.GEMINI_API_KEY;
  process.env.GEMINI_API_KEY = 'fake-legacy-key-for-status-test';
  const app = await setup();
  try {
    const result = await app.request('/api/admin/gemini-keys', { token: 'admin-token' });
    assert.equal(result.status, 200);
    assert.equal(result.json.legacyFallbackConfigured, true);
    assert.equal(JSON.stringify(result.json).includes(process.env.GEMINI_API_KEY), false);
  } finally {
    await app.close();
    if (original === undefined) delete process.env.GEMINI_API_KEY;
    else process.env.GEMINI_API_KEY = original;
  }
});

test('create/list expose only masked metadata and never echo plaintext or ciphertext', async () => {
  const app = await setup();
  try {
    const created = await app.request('/api/admin/gemini-keys', {
      method: 'POST',
      token: 'admin-token',
      body: { label: 'Primary key', apiKey: testKeyValue },
    });
    assert.equal(created.status, 201);
    assert.equal(created.json.ok, true);
    assert.equal(created.json.key.label, 'Primary key');
    assert.equal(created.json.key.maskedSuffix, '••••ABCD');
    const list = await app.request('/api/admin/gemini-keys', { token: 'admin-token' });
    assert.equal(list.status, 200);
    const serialized = JSON.stringify({ create: created.json, list: list.json });
    assert.equal(serialized.includes(testKeyValue), false);
    assert.equal(serialized.includes('ciphertext'), false);
    assert.equal(Object.hasOwn(created.json.key, 'apiKey'), false);
    assert.equal(app.store.calls[0].actorUid, 'admin-uid');
    assert.equal((await app.store.getPoolSettings()).managedPoolActivated, true);
  } finally { await app.close(); }
});

test('request cannot add or update role, actor identity, ciphertext, or unknown fields', async () => {
  const app = await setup();
  try {
    const badCreate = await app.request('/api/admin/gemini-keys', {
      method: 'POST',
      token: 'admin-token',
      body: { label: 'Key', apiKey: testKeyValue, role: 'admin', actorUid: 'spoofed' },
    });
    assert.equal(badCreate.status, 400);
    assert.equal(app.store.calls.length, 0);
    const badStatus = await app.request('/api/admin/gemini-keys/a/status', {
      method: 'PATCH',
      token: 'admin-token',
      body: { enabled: true, role: 'admin' },
    });
    assert.equal(badStatus.status, 400);
  } finally { await app.close(); }
});

test('replace, toggle, and delete use exact routes with server-derived actor identity', async () => {
  const app = await setup();
  try {
    const created = await app.request('/api/admin/gemini-keys', {
      method: 'POST', token: 'admin-token',
      body: { label: 'Initial', apiKey: testKeyValue },
    });
    const id = created.json.key.id;
    const changed = await app.request('/api/admin/gemini-keys/' + id, {
      method: 'PUT', token: 'admin-token',
      body: { label: 'Replacement label', apiKey: 'fake-another-gemini-key-EFGH' },
    });
    assert.equal(changed.status, 200);
    assert.equal(changed.json.key.label, 'Replacement label');
    const disabled = await app.request('/api/admin/gemini-keys/' + id + '/status', {
      method: 'PATCH', token: 'admin-token', body: { enabled: false },
    });
    assert.equal(disabled.json.key.enabled, false);
    const removed = await app.request('/api/admin/gemini-keys/' + id, {
      method: 'DELETE', token: 'admin-token',
    });
    assert.equal(removed.status, 200);
    assert.equal(removed.json.deleted, true);
    assert.ok(app.store.calls.every((call) => call.actorUid === undefined || call.actorUid === 'admin-uid'));
  } finally { await app.close(); }
});

test('test endpoint requires admin and invokes its injected one-shot tester once', async () => {
  let invocations = 0;
  const app = await setup({ testKey: async () => { invocations += 1; return { passed: false, category: 'quota_limited', retryAfterSeconds: 25 }; } });
  try {
    const created = await app.request('/api/admin/gemini-keys', {
      method: 'POST', token: 'admin-token',
      body: { label: 'Test', apiKey: testKeyValue },
    });
    const id = created.json.key.id;
    assert.equal((await app.request('/api/admin/gemini-keys/' + id + '/test', { token: 'user-token', method: 'POST' })).status, 403);
    assert.equal(invocations, 0);
    const testResult = await app.request('/api/admin/gemini-keys/' + id + '/test', { token: 'admin-token', method: 'POST', body: { confirm: true } });
    assert.equal(testResult.status, 200);
    assert.equal(testResult.json.test.passed, false);
    assert.equal(testResult.json.test.category, 'quota_limited');
    assert.equal(testResult.json.test.retryAfterSeconds, 25);
    assert.equal(invocations, 1);
    assert.equal(JSON.stringify(testResult.json).includes(testKeyValue), false);
  } finally { await app.close(); }
});

test('encryption-configuration and database errors are sanitized instead of leaking details', async () => {
  const store = makeStore();
  store.createKey = async () => { throw new Error('GEMINI_KEY_ENCRYPTION_SECRET has private-secret-text'); };
  const app = await setup({ store });
  try {
    const response = await app.request('/api/admin/gemini-keys', {
      method: 'POST', token: 'admin-token',
      body: { label: 'New', apiKey: testKeyValue },
    });
    assert.equal(response.status, 503);
    assert.equal(JSON.stringify(response.json).includes('private-secret-text'), false);
    assert.equal(JSON.stringify(response.json).includes(testKeyValue), false);
  } finally { await app.close(); }
});
