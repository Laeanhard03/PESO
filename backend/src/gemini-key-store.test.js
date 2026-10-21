import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { ObjectId } from 'mongodb';
import test from 'node:test';

import { createMongoGeminiKeyStore } from './gemini-key-store.js';
import { decryptApiKey } from './gemini-key-vault.js';

function deepClone(value) {
  if (value instanceof Date) return new Date(value.getTime());
  if (value instanceof ObjectId) return new ObjectId(value.toHexString());
  if (Buffer.isBuffer(value)) return Buffer.from(value);
  if (Array.isArray(value)) return value.map(deepClone);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, deepClone(item)]));
  }
  return value;
}

function equalValue(left, right) {
  if (left instanceof ObjectId || right instanceof ObjectId) return String(left) === String(right);
  if (left instanceof Date || right instanceof Date) return new Date(left).getTime() === new Date(right).getTime();
  return left === right;
}

function matchesOperator(actual, condition) {
  for (const [op, expected] of Object.entries(condition)) {
    if (op === '$nin' && expected.some((value) => equalValue(value, actual))) return false;
    if (op === '$ne' && equalValue(actual, expected)) return false;
    if (op === '$lte' && !(actual != null && new Date(actual).getTime() <= new Date(expected).getTime())) return false;
    if (op === '$exists' && Boolean(actual !== undefined) !== Boolean(expected)) return false;
  }
  return true;
}

function matches(doc, filter = {}) {
  for (const [key, condition] of Object.entries(filter)) {
    if (key === '$or') {
      if (!condition.some((clause) => matches(doc, clause))) return false;
      continue;
    }
    if (key === '$and') {
      if (!condition.every((clause) => matches(doc, clause))) return false;
      continue;
    }
    const actual = doc[key];
    if (condition && typeof condition === 'object' && !Array.isArray(condition) &&
        !(condition instanceof Date) && !(condition instanceof ObjectId) &&
        Object.keys(condition).some((item) => item.startsWith('$'))) {
      if (!matchesOperator(actual, condition)) return false;
    } else if (!equalValue(actual, condition)) {
      return false;
    }
  }
  return true;
}

class FakeCollection {
  constructor() { this.docs = new Map(); }
  async insertOne(input) {
    const doc = deepClone(input);
    if (!doc._id) doc._id = new ObjectId();
    this.docs.set(String(doc._id), doc);
    return { acknowledged: true, insertedId: doc._id };
  }
  async findOne(filter) {
    const doc = [...this.docs.values()].find((item) => matches(item, filter));
    return doc ? deepClone(doc) : null;
  }
  find(filter = {}) {
    let docs = [...this.docs.values()].filter((item) => matches(item, filter));
    const cursor = {
      sort: (fields) => {
        docs.sort((a, b) => {
          for (const [field, dir] of Object.entries(fields)) {
            const av = a[field] == null ? 0 : (a[field] instanceof Date ? a[field].getTime() : a[field]);
            const bv = b[field] == null ? 0 : (b[field] instanceof Date ? b[field].getTime() : b[field]);
            if (av < bv) return -1 * dir;
            if (av > bv) return 1 * dir;
          }
          return 0;
        });
        return cursor;
      },
      toArray: async () => docs.map(deepClone),
    };
    return cursor;
  }
  async updateOne(filter, update, options = {}) {
    let doc = [...this.docs.values()].find((item) => matches(item, filter));
    let inserted = false;
    if (!doc && options.upsert) {
      doc = {};
      for (const [key, value] of Object.entries(filter)) {
        if (!(value && typeof value === 'object' && Object.keys(value).some((x) => x.startsWith('$')))) {
          doc[key] = deepClone(value);
        }
      }
      for (const [key, value] of Object.entries(update.$setOnInsert || {})) doc[key] = deepClone(value);
      if (!doc._id) doc._id = new ObjectId();
      inserted = true;
    }
    if (!doc) return { acknowledged: true, matchedCount: 0, modifiedCount: 0 };
    for (const [key, value] of Object.entries(update.$set || {})) doc[key] = deepClone(value);
    for (const key of Object.keys(update.$unset || {})) delete doc[key];
    for (const [key, amount] of Object.entries(update.$inc || {})) doc[key] = Number(doc[key] || 0) + Number(amount);
    this.docs.set(String(doc._id), doc);
    return { acknowledged: true, matchedCount: inserted ? 0 : 1, modifiedCount: 1, upsertedId: inserted ? doc._id : null };
  }
  async findOneAndUpdate(filter, update, options = {}) {
    let docs = [...this.docs.values()].filter((item) => matches(item, filter));
    if (options.sort) {
      docs.sort((a, b) => {
        for (const [field, dir] of Object.entries(options.sort)) {
          const av = a[field] == null ? 0 : (a[field] instanceof Date ? a[field].getTime() : a[field]);
          const bv = b[field] == null ? 0 : (b[field] instanceof Date ? b[field].getTime() : b[field]);
          if (av < bv) return -1 * dir;
          if (av > bv) return 1 * dir;
        }
        return 0;
      });
    }
    const doc = docs[0];
    if (!doc) return null;
    for (const [key, value] of Object.entries(update.$set || {})) doc[key] = deepClone(value);
    for (const [key, amount] of Object.entries(update.$inc || {})) doc[key] = Number(doc[key] || 0) + Number(amount);
    this.docs.set(String(doc._id), doc);
    return deepClone(doc);
  }
  async deleteOne(filter) {
    const doc = [...this.docs.values()].find((item) => matches(item, filter));
    if (!doc) return { acknowledged: true, deletedCount: 0 };
    this.docs.delete(String(doc._id));
    return { acknowledged: true, deletedCount: 1 };
  }
}

function fakeDb() {
  const collections = new Map();
  return {
    collections,
    collection(name) {
      if (!collections.has(name)) collections.set(name, new FakeCollection());
      return collections.get(name);
    },
  };
}

const encryptionSecret = randomBytes(32).toString('base64');

function createStoreAt(time = '2026-10-18T00:00:00.000Z') {
  const db = fakeDb();
  let current = new Date(time).getTime();
  const store = createMongoGeminiKeyStore(db, {
    encryptionSecret,
    now: () => new Date(current),
  });
  return { db, store, setNow: (next) => { current = new Date(next).getTime(); }, now: () => current };
}

test('create stores ciphertext only, activates managed pool, audits safe metadata', async () => {
  const { db, store } = createStoreAt();
  const secret = 'fake-gemini-key-for-store-unit-test-1234';
  const result = await store.createKey({ label: 'My test key', apiKey: secret, actorUid: 'admin-uid' });
  assert.equal(result.label, 'My test key');
  assert.equal(result.maskedSuffix.endsWith('1234'), true);
  assert.equal(Object.hasOwn(result, 'ciphertext'), false);

  const record = await store.getKeyRecord(result.id);
  assert.ok(record);
  assert.equal(JSON.stringify(record).includes(secret), false);
  assert.equal(decryptApiKey({ record, recordId: result.id, encryptionSecret }), secret);
  const settings = await store.getPoolSettings();
  assert.equal(settings.managedPoolActivated, true);
  const audit = await db.collection('geminiKeyAudit').find({}).toArray();
  assert.equal(audit.length, 1);
  assert.equal(JSON.stringify(audit).includes(secret), false);
});

test('list API returns metadata only for every key', async () => {
  const { store } = createStoreAt();
  await store.createKey({ label: 'first', apiKey: 'fake-first-gemini-key-1234', actorUid: 'admin' });
  await store.createKey({ label: 'second', apiKey: 'fake-second-gemini-key-5678', actorUid: 'admin' });
  const list = await store.listPublicKeys();
  assert.equal(list.length, 2);
  for (const item of list) {
    for (const forbidden of ['ciphertext', 'iv', 'authTag', 'createdBy', 'updatedBy', 'apiKey']) {
      assert.equal(Object.hasOwn(item, forbidden), false);
    }
  }
  assert.ok(list.every((item) => item.maskedSuffix.startsWith('••••')));
});

test('replace re-encrypts using a fresh IV and the same record identity', async () => {
  const { store } = createStoreAt();
  const initial = await store.createKey({ label: 'one', apiKey: 'fake-first-key-value-1234', actorUid: 'admin' });
  const before = await store.getKeyRecord(initial.id);
  const changed = await store.updateKey(initial.id, {
    label: 'replaced',
    apiKey: 'fake-replacement-key-5678',
    actorUid: 'admin',
  });
  const after = await store.getKeyRecord(initial.id);
  assert.equal(changed.label, 'replaced');
  assert.notEqual(before.iv, after.iv);
  assert.equal(decryptApiKey({ record: after, recordId: initial.id, encryptionSecret }), 'fake-replacement-key-5678');
  assert.equal(after.ciphertext.includes('fake-replacement'), false);
});

test('enable/disable updates enabled state without resetting managed-pool activation', async () => {
  const { store } = createStoreAt();
  const created = await store.createKey({ label: 'toggle', apiKey: 'fake-gemini-key-toggle-1234', actorUid: 'admin' });
  const disabled = await store.setEnabled(created.id, false, 'admin');
  assert.equal(disabled.enabled, false);
  assert.equal(disabled.health, 'disabled');
  const enabled = await store.setEnabled(created.id, true, 'admin');
  assert.equal(enabled.enabled, true);
  assert.equal(enabled.health, 'ready');
  assert.equal((await store.getPoolSettings()).managedPoolActivated, true);
});

test('selection is atomic and excludes disabled, cooling, unhealthy and same-request IDs', async () => {
  const { store } = createStoreAt('2026-10-18T00:00:03.000Z');
  const disabled = await store.createKey({ label: 'disabled', apiKey: 'fake-disabled-key-1234', actorUid: 'admin' });
  const cooling = await store.createKey({ label: 'cooling', apiKey: 'fake-cooling-key-1234', actorUid: 'admin' });
  const broken = await store.createKey({ label: 'broken', apiKey: 'fake-broken-key-1234', actorUid: 'admin' });
  const ready = await store.createKey({ label: 'ready', apiKey: 'fake-ready-key-1234', actorUid: 'admin' });
  await store.createKey({ label: 'ready two', apiKey: 'fake-ready-key-5678', actorUid: 'admin' });
  await store.setEnabled(disabled.id, false, 'admin');
  await store.markFailure(cooling.id, { category: 'transient_upstream_failure', health: 'cooling_down', cooldownUntil: new Date('2026-10-18T00:10:00Z'), at: new Date('2026-10-18T00:00:01Z') });
  await store.markFailure(broken.id, { category: 'invalid_key', health: 'attention_required', cooldownUntil: null, at: new Date('2026-10-18T00:00:02Z') });
  const first = await store.reserveNextKey({ excludeIds: [], now: new Date('2026-10-18T00:00:03Z') });
  const second = await store.reserveNextKey({ excludeIds: [first._id], now: new Date('2026-10-18T00:00:03Z') });
  assert.ok(first && second);
  assert.equal(String(first._id), ready.id);
  assert.notEqual(String(first._id), String(second._id));
  assert.ok(second._id instanceof ObjectId);
});

test('mark failure persists only bounded safe categories and status', async () => {
  const { store } = createStoreAt();
  const created = await store.createKey({ label: 'fail', apiKey: 'fake-failure-key-1234', actorUid: 'admin' });
  await store.markFailure(created.id, {
    category: 'transient_upstream_failure\nnever-store-provider-text',
    health: 'cooling_down',
    cooldownUntil: new Date('2026-10-18T00:01:00Z'),
    at: new Date('2026-10-18T00:00:00Z'),
  });
  const record = await store.getKeyRecord(created.id);
  assert.equal(record.health, 'cooling_down');
  assert.equal(record.lastErrorCategory, 'unknown_upstream_failure');
  assert.equal(JSON.stringify(record).includes('never-store-provider-text'), false);
});

test('delete removes encrypted secret and audit log records only metadata', async () => {
  const { db, store } = createStoreAt();
  const secret = 'fake-delete-test-key-ABCD';
  const created = await store.createKey({ label: 'delete me', apiKey: secret, actorUid: 'admin' });
  assert.equal(await store.deleteKey(created.id, 'admin'), true);
  assert.equal(await store.getKeyRecord(created.id), null);
  assert.equal((await store.getPoolSettings()).managedPoolActivated, true);
  const audit = await db.collection('geminiKeyAudit').find({}).toArray();
  assert.equal(JSON.stringify(audit).includes(secret), false);
  assert.equal(audit.at(-1).action, 'delete');
});

test('missing/invalid encryption secret fails closed without partial insert', async () => {
  const db = fakeDb();
  const store = createMongoGeminiKeyStore(db, {
    encryptionSecret: '',
    now: () => new Date('2026-10-18T00:00:00Z'),
  });
  await assert.rejects(store.createKey({
    label: 'will not save',
    apiKey: 'fake-key-value-without-encryption',
    actorUid: 'admin',
  }), /GEMINI_KEY_ENCRYPTION_SECRET|required|32 bytes/i);
  assert.equal((await db.collection('geminiApiKeys').find({}).toArray()).length, 0);
  assert.equal((await db.collection('geminiKeySettings').find({}).toArray()).length, 0);
});

test('invalid Mongo key IDs are rejected by lookup without a database query', async () => {
  const { store } = createStoreAt();
  assert.equal(await store.getKeyRecord('not-an-object-id'), null);
  assert.equal(await store.getPublicKey('not-an-object-id'), null);
});

test('permanent Gemini test failures are marked configuration_error and excluded until a retest passes', async () => {
  const { store } = createStoreAt();
  const denied = await store.createKey({ label: 'denied', apiKey: 'fake-denied-test-key-1234', actorUid: 'admin' });
  const invalidRequest = await store.createKey({ label: 'invalid request', apiKey: 'fake-invalid-test-key-1234', actorUid: 'admin' });
  const healthy = await store.createKey({ label: 'healthy', apiKey: 'fake-healthy-test-key-1234', actorUid: 'admin' });

  await store.recordTestResult(denied.id, { ok: false, category: 'provider_permission_denied' });
  await store.recordTestResult(invalidRequest.id, { ok: false, category: 'invalid_request' });
  assert.equal((await store.getPublicKey(denied.id)).health, 'configuration_error');
  assert.equal((await store.getPublicKey(invalidRequest.id)).health, 'configuration_error');

  const reserved = await store.reserveNextKey({ now: new Date('2026-10-18T00:00:01.000Z') });
  assert.equal(String(reserved._id), healthy.id);

  const recovered = await store.recordTestResult(denied.id, { ok: true, category: 'test_success' });
  assert.equal(recovered.health, 'ready');
  assert.equal(recovered.lastErrorCategory, null);
});

test('project/model quota is persisted once and only blocks its model before actual reset', async () => {
  const { store, db, setNow } = createStoreAt('2026-10-20T15:00:00.000Z');
  const model = 'gemini-3.8-flash';
  assert.equal(await store.getModelQuotaStatus(model), null);
  await store.markModelQuota({ model, retryAfterSeconds: 120, scope: 'minute',
    metric: 'RPM', at: new Date('2026-10-20T15:00:00.000Z') });
  const active = await store.getModelQuotaStatus(model);
  assert.equal(active.metric, 'RPM');
  assert.equal(active.scope, 'minute');
  assert.equal(active.retryAfterSeconds, 120);
  assert.equal(await store.getModelQuotaStatus('gemini-2.5-flash-lite'), null);
  assert.equal((await db.collection('geminiModelQuotas').find({}).toArray()).length, 1);
  setNow('2026-10-20T15:02:00.000Z');
  assert.equal(await store.getModelQuotaStatus(model), null);
  assert.equal(await store.markModelQuota({ model: 'unsafe/model', retryAfterSeconds: 60 }), null);
});


test('one model quota never disables a different fallback model on the same key', async () => {
  const { store } = createStoreAt('2026-10-20T15:00:00.000Z');
  const blocked = await store.createKey({ label: 'primary key', apiKey: 'fake-key-model-primary-1234', actorUid: 'admin' });
  const spare = await store.createKey({ label: 'spare key', apiKey: 'fake-key-model-spare-1234', actorUid: 'admin' });
  await store.markFailure(blocked.id, {
    category: 'quota_limited', health: 'cooling_down',
    quotaModel: 'gemini-3.8-flash', quotaUntil: new Date('2026-10-20T15:02:00Z'),
    quotaScope: 'minute', quotaMetric: 'RPM',
    at: new Date('2026-10-20T15:00:00Z'),
  });
  const primary = await store.reserveNextKey({ model: 'gemini-3.8-flash',
    now: new Date('2026-10-20T15:00:05Z') });
  assert.equal(String(primary._id), spare.id);
  const fallback = await store.reserveNextKey({ model: 'gemini-2.5-flash-lite',
    now: new Date('2026-10-20T15:00:05Z') });
  assert.equal(String(fallback._id), blocked.id);
});
