import assert from 'node:assert/strict';
import test from 'node:test';

import { createGeminiKeyRotator } from './gemini-key-rotator.js';

function makeKey(id, overrides = {}) {
  return {
    _id: id,
    enabled: true,
    health: 'ready',
    cooldownUntil: null,
    ciphertext: 'ciphertext-fixture-' + id,
    ...overrides,
  };
}

function createStore(keys, { managedPoolActivated = true } = {}) {
  const state = {
    keys: keys.map((key) => structuredClone(key)),
    managedPoolActivated,
    cursor: 0,
    used: [],
    successes: [],
    failures: [],
  };
  state.getPoolSettings = async () => ({
    managedPoolActivated: state.managedPoolActivated,
    cursor: state.cursor,
  });
  state.reserveNextKey = async ({ excludeIds = [], now = new Date() } = {}) => {
    const excluded = new Set(excludeIds.map(String));
    const eligible = state.keys.filter((key) =>
      key.enabled === true &&
      key.health !== 'attention_required' &&
      key.health !== 'configuration_error' &&
      !excluded.has(String(key._id)) &&
      (!key.cooldownUntil || new Date(key.cooldownUntil).getTime() <= now.getTime()),
    );
    if (!eligible.length) return null;
    const chosen = eligible[state.cursor % eligible.length];
    state.cursor += 1;
    return structuredClone(chosen);
  };
  state.markUsed = async (id, at) => { state.used.push({ id: String(id), at }); };
  state.markSuccess = async (id, at) => {
    state.successes.push({ id: String(id), at });
  };
  state.markFailure = async (id, failure) => {
    state.failures.push({ id: String(id), ...failure });
    const record = state.keys.find((key) => String(key._id) === String(id));
    if (record) {
      record.health = failure.health;
      record.cooldownUntil = failure.cooldownUntil;
      if (failure.health === 'attention_required' ||
          failure.health === 'configuration_error') record.enabled = false;
    }
  };
  return state;
}

const decryptKey = async (record) => 'fake-key-' + String(record._id);

function providerError(status, code = 'provider_error', extra = {}) {
  const error = new Error('sanitized test provider failure');
  error.status = status;
  error.code = code;
  Object.assign(error, extra);
  return error;
}

test('first-key success calls the provider exactly once and records success', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    legacyApiKey: 'fake-legacy-key-for-tests',
    providerCall: async ({ apiKey }) => {
      calls.push(apiKey);
      return { text: 'ok' };
    },
    now: () => 1000,
    sleep: async () => {},
  });

  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hello' } });
  assert.deepEqual(result, { ok: true, result: { text: 'ok' }, attempts: 1, keyId: 'key-a' });
  assert.deepEqual(calls, ['fake-key-key-a']);
  assert.equal(store.successes.length, 1);
  assert.equal(store.successes[0].id, 'key-a');
});

test('timeout fails over to another distinct key and cools down the failed key', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    providerCall: async ({ apiKey }) => {
      calls.push(apiKey);
      if (apiKey.endsWith('key-a')) {
        const error = new Error('upstream timeout');
        error.name = 'AbortError';
        throw error;
      }
      return { text: 'recovered' };
    },
    now: () => 10000,
    sleep: async () => {},
    cooldownMs: 30000,
  });

  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hi' } });
  assert.deepEqual(calls, ['fake-key-key-a', 'fake-key-key-b']);
  assert.equal(new Set(calls).size, calls.length);
  assert.equal(result.ok, true);
  assert.equal(result.attempts, 2);
  assert.equal(store.failures[0].health, 'cooling_down');
  assert.equal(new Date(store.failures[0].cooldownUntil).getTime(), 40000);
});

test('verified invalid-key error quarantines that key and tries a different key', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    providerCall: async ({ apiKey }) => {
      calls.push(apiKey);
      if (apiKey.endsWith('key-a')) throw providerError(401, 'API_KEY_INVALID');
      return { text: 'ok' };
    },
    now: () => 1000,
    sleep: async () => {},
  });

  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hi' } });
  assert.equal(result.ok, true);
  assert.deepEqual(calls, ['fake-key-key-a', 'fake-key-key-b']);
  assert.equal(store.failures[0].health, 'attention_required');
});

test('HTTP 429 stops the pool immediately and records the quota without a cooldown', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    providerCall: async ({ apiKey }) => {
      calls.push(apiKey);
      throw providerError(429, 'RESOURCE_EXHAUSTED', { retryAfterSeconds: 47 });
    },
    now: () => 5000,
    sleep: async () => {},
  });

  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hi' } });
  assert.equal(result.ok, false);
  assert.equal(result.statusCode, 429);
  assert.equal(result.code, 'gemini_rate_limited');
  assert.equal(result.retryAfterSeconds, 47);
  // Quota must not be bypassed by rotating to another key (ADMIN_API.md).
  assert.deepEqual(calls, ['fake-key-key-a']);
  assert.equal(store.failures.length, 1);
  assert.equal(store.failures[0].category, 'quota_limited');
  // No cooldown: the same key may still serve a fallback model's own quota.
  assert.equal(store.failures[0].cooldownUntil, null);
  assert.equal(store.keys[0].enabled, true);
});

test('quota exhaustion retries once on the configured fallback model', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    providerCall: async ({ apiKey, model }) => {
      calls.push({ apiKey, model });
      if (model === 'gemini-3.8-flash') {
        throw providerError(429, 'RESOURCE_EXHAUSTED', { retryAfterSeconds: 7200 });
      }
      return { profile: { fullName: 'Fallback Model' } };
    },
    fallbackModel: 'gemini-3.7-flash',
    maxAttempts: 2,
    now: () => 5000,
    sleep: async () => {},
  });

  const result = await rotator.generate({
    operation: 'profile_extraction',
    model: 'gemini-3.8-flash',
    payload: { parts: [] },
  });
  assert.equal(result.ok, true);
  assert.equal(result.model, 'gemini-3.7-flash');
  assert.equal(result.fallbackModel, 'gemini-3.7-flash');
  assert.equal(result.fallbackAttempted, true);
  assert.deepEqual(calls.map((call) => call.model), [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
  ]);
});

test('fallback model is not used for a non-quota failure', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  const models = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    providerCall: async ({ model }) => {
      models.push(model);
      throw providerError(400, 'INVALID_ARGUMENT');
    },
    fallbackModel: 'gemini-3.7-flash',
    now: () => 5000,
    sleep: async () => {},
  });

  const result = await rotator.generate({
    operation: 'profile_extraction',
    model: 'gemini-3.8-flash',
    payload: { parts: [] },
  });
  assert.equal(result.ok, false);
  assert.deepEqual(models, ['gemini-3.8-flash']);
});

test('fallback result keeps the quota message when the fallback also fails', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    providerCall: async ({ model }) => {
      if (model === 'gemini-3.8-flash') {
        throw providerError(429, 'RESOURCE_EXHAUSTED', { retryAfterSeconds: 47 });
      }
      throw providerError(503, 'UNAVAILABLE');
    },
    fallbackModel: 'gemini-3.7-flash',
    maxAttempts: 2,
    now: () => 5000,
    sleep: async () => {},
  });

  const result = await rotator.generate({ operation: 'query', model: 'gemini-3.8-flash', payload: {} });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'gemini_rate_limited');
  assert.equal(result.retryAfterSeconds, 47);
  assert.equal(result.fallbackAttempted, true);
  assert.equal(result.fallbackCode, 'gemini_pool_exhausted');
});

test('permanent bad request stops without switching to another key', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    providerCall: async ({ apiKey }) => {
      calls.push(apiKey);
      throw providerError(400, 'invalid_request');
    },
    now: () => 1000,
    sleep: async () => {},
  });
  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'bad' } });
  assert.equal(result.ok, false);
  assert.equal(result.statusCode, 400);
  assert.deepEqual(calls, ['fake-key-key-a']);
});

test('per-request attempt ceiling is three and each key is attempted at most once', async () => {
  const store = createStore([
    makeKey('key-a'), makeKey('key-b'), makeKey('key-c'), makeKey('key-d'),
  ]);
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    maxAttempts: 3,
    providerCall: async ({ apiKey }) => {
      calls.push(apiKey);
      throw providerError(503, 'upstream_unavailable');
    },
    now: () => 1000,
    sleep: async () => {},
  });
  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hi' } });
  assert.equal(result.ok, false);
  assert.equal(result.attempts, 3);
  assert.equal(calls.length, 3);
  assert.equal(new Set(calls).size, 3);
  assert.equal(store.used.length, 3);
});

test('disabled, cooling, and quarantined keys are never chosen', async () => {
  const store = createStore([
    makeKey('disabled', { enabled: false }),
    makeKey('cooling', { cooldownUntil: new Date(2000) }),
    makeKey('bad', { health: 'attention_required' }),
    makeKey('ready'),
  ]);
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    providerCall: async ({ apiKey }) => { calls.push(apiKey); return { text: 'ok' }; },
    now: () => 1000,
    sleep: async () => {},
  });
  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hi' } });
  assert.equal(result.ok, true);
  assert.deepEqual(calls, ['fake-key-ready']);
});

test('managed pool activated never silently falls back to legacy environment key', async () => {
  const store = createStore([makeKey('disabled', { enabled: false })], { managedPoolActivated: true });
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    legacyApiKey: 'fake-legacy-key-for-tests',
    providerCall: async ({ apiKey }) => { calls.push(apiKey); return { text: 'ok' }; },
    now: () => 1000,
    sleep: async () => {},
  });
  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hi' } });
  assert.equal(result.ok, false);
  assert.equal(result.statusCode, 503);
  assert.equal(calls.length, 0);
});

test('legacy fallback is used once only before managed pool activation', async () => {
  const store = createStore([], { managedPoolActivated: false });
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    legacyApiKey: 'fake-legacy-key-for-tests',
    providerCall: async ({ apiKey }) => { calls.push(apiKey); return { text: 'legacy-ok' }; },
    now: () => 1000,
    sleep: async () => {},
  });
  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hi' } });
  assert.equal(result.ok, true);
  assert.equal(result.keyId, 'legacy-env');
  assert.equal(result.attempts, 1);
  assert.deepEqual(calls, ['fake-legacy-key-for-tests']);
});

test('decryption failure disables that record and continues without logging its ciphertext', async () => {
  const store = createStore([makeKey('bad-ciphertext'), makeKey('ready')]);
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey: async (record) => {
      if (record._id === 'bad-ciphertext') throw new Error('do not expose ciphertext or secret');
      return 'fake-key-' + record._id;
    },
    providerCall: async ({ apiKey }) => { calls.push(apiKey); return { text: 'ok' }; },
    now: () => 1000,
    sleep: async () => {},
  });
  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hi' } });
  assert.equal(result.ok, true);
  assert.deepEqual(calls, ['fake-key-ready']);
  assert.equal(store.failures[0].health, 'configuration_error');
  assert.equal(JSON.stringify(result).includes('ciphertext'), false);
});

test('missing encryption configuration returns a safe 503 without marking keys unhealthy', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  let providerCalls = 0;
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey: async () => { throw new Error('GEMINI_KEY_ENCRYPTION_SECRET is required.'); },
    providerCall: async () => { providerCalls += 1; return { text: 'should not happen' }; },
    now: () => 1000,
    sleep: async () => {},
  });
  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hi' } });
  assert.equal(result.ok, false);
  assert.equal(result.statusCode, 503);
  assert.equal(result.code, 'gemini_key_encryption_not_configured');
  assert.equal(providerCalls, 0);
  assert.equal(store.failures.length, 0);
  assert.equal(JSON.stringify(result).includes('GEMINI_KEY_ENCRYPTION_SECRET'), false);
});

test('network failures are retryable but error response never includes upstream text', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  let calls = 0;
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    providerCall: async () => {
      calls += 1;
      const error = new Error('internal host timeout; possibly-secret-provider-detail');
      error.code = 'ETIMEDOUT';
      throw error;
    },
    now: () => 1000,
    sleep: async () => {},
  });
  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hi' } });
  assert.equal(result.ok, false);
  assert.equal(result.statusCode, 503);
  assert.equal(calls, 2);
  assert.equal(JSON.stringify(result).includes('possibly-secret'), false);
});

test('unknown 403/project permission failure does not quarantine or rotate credentials', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    providerCall: async ({ apiKey }) => {
      calls.push(apiKey);
      throw providerError(403, 'permission_denied');
    },
    now: () => 1000,
    sleep: async () => {},
  });
  const result = await rotator.generate({ operation: 'query', payload: { prompt: 'hi' } });
  assert.equal(result.ok, false);
  assert.equal(result.statusCode, 403);
  assert.deepEqual(calls, ['fake-key-key-a']);
  assert.equal(store.failures.length, 0);
});


test('model-wide 429 blocks requests across keys until reset but still allows alternate model', async () => {
  const store = createStore([makeKey('key-a'), makeKey('key-b')]);
  const blocked = new Map();
  const now = () => 1_000;
  store.getModelQuotaStatus = async (model) => {
    const quota = blocked.get(model);
    return quota && quota.retryUntil > now()
      ? { retryAfterSeconds: Math.ceil((quota.retryUntil - now()) / 1000) }
      : null;
  };
  store.markModelQuota = async ({ model, retryAfterSeconds }) => {
    blocked.set(model, { retryUntil: now() + retryAfterSeconds * 1000 });
  };
  const seen = [];
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey,
    fallbackModel: 'gemini-2.5-flash-lite',
    providerCall: async ({ model }) => {
      seen.push(model);
      if (model === 'gemini-3.8-flash') {
        throw providerError(429, 'RESOURCE_EXHAUSTED', {
          quotaScope: 'daily', quotaMetric: 'RPD', retryAfterSeconds: 3600,
        });
      }
      return { text: 'available' };
    },
    now, sleep: async () => {},
  });
  const request = { operation: 'query', model: 'gemini-3.8-flash', payload: { prompt: 'help' } };
  const first = await rotator.generate(request);
  const second = await rotator.generate(request);
  assert.equal(first.ok, true);
  assert.equal(second.ok, true);
  assert.equal(first.fallbackAttempted, true);
  assert.deepEqual(seen, ['gemini-3.8-flash', 'gemini-2.5-flash-lite', 'gemini-2.5-flash-lite']);
  assert.equal(store.failures.filter((f) => f.category === 'quota_limited').length, 1);
});


test('legacy environment key observes model quota and avoids repeat exhausted calls', async () => {
  const store = createStore([], { managedPoolActivated: false });
  const pending = new Map();
  const time = () => 10000;
  store.getModelQuotaStatus = async (model) => {
    const until = pending.get(model) || 0;
    return until > time() ? { retryAfterSeconds: Math.ceil((until - time()) / 1000) } : null;
  };
  store.markModelQuota = async ({ model, retryAfterSeconds }) => {
    pending.set(model, time() + 1000 * retryAfterSeconds);
  };
  const calls = [];
  const rotator = createGeminiKeyRotator({
    store, decryptKey,
    legacyApiKey: 'test-legacy-gemini-project-key',
    fallbackModel: 'gemini-2.5-flash-lite',
    now: time, sleep: async () => {},
    providerCall: async ({ model }) => {
      calls.push(model);
      if (model === 'gemini-3.8-flash') {
        throw providerError(429, 'RESOURCE_EXHAUSTED', {
          quotaScope: 'daily', quotaMetric: 'RPD', retryAfterSeconds: 1800,
        });
      }
      return { text: 'Fallback available' };
    },
  });
  const request = { operation: 'query', model: 'gemini-3.8-flash', payload: { prompt: 'Hello' } };
  const first = await rotator.generate(request);
  const again = await rotator.generate(request);
  assert.equal(first.ok, true);
  assert.equal(again.ok, true);
  assert.equal(pending.has('gemini-3.8-flash'), true);
  assert.deepEqual(calls,
    ['gemini-3.8-flash', 'gemini-2.5-flash-lite', 'gemini-2.5-flash-lite']);
});
