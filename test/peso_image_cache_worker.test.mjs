import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const scopeUrl = 'http://127.0.0.1:5237/';

class MemoryCache {
  constructor() {
    this.entries = new Map();
  }

  async put(request, response) {
    const key = typeof request === 'string' ? request : request.url;
    this.entries.set(key, response.clone());
  }

  async match(request, options = {}) {
    const key = typeof request === 'string' ? request : request.url;
    const exact = this.entries.get(key);
    if (exact) return exact.clone();
    if (!options.ignoreSearch) return undefined;

    const target = new URL(key);
    for (const [candidate, response] of this.entries) {
      const parsed = new URL(candidate);
      if (parsed.origin === target.origin && parsed.pathname === target.pathname) {
        return response.clone();
      }
    }
    return undefined;
  }

  async keys() {
    return [...this.entries.keys()].map((url) => new Request(url));
  }

  async delete(request) {
    const key = typeof request === 'string' ? request : request.url;
    return this.entries.delete(key);
  }
}

async function loadWorkerHarness() {
  const source = await readFile(new URL('../web/peso-image-cache-worker.js', import.meta.url), 'utf8');
  const listeners = new Map();
  const cacheStore = new Map();
  let networkOffline = false;
  let fetchCount = 0;

  const caches = {
    async open(name) {
      if (!cacheStore.has(name)) cacheStore.set(name, new MemoryCache());
      return cacheStore.get(name);
    },
    async keys() {
      return [...cacheStore.keys()];
    },
    async delete(name) {
      return cacheStore.delete(name);
    },
  };

  const self = {
    location: new URL(scopeUrl),
    registration: { scope: scopeUrl },
    clients: { claim: async () => {} },
    skipWaiting: async () => {},
    addEventListener(name, callback) {
      listeners.set(name, callback);
    },
  };

  async function fakeFetch(input) {
    fetchCount += 1;
    if (networkOffline) throw new Error('simulated offline connection');
    const url = typeof input === 'string' ? input : input.url;
    return new Response(
      Buffer.from('local-image:' + new URL(url).pathname),
      { status: 200, headers: { 'Content-Type': 'image/jpeg' } },
    );
  }

  vm.runInNewContext(source, {
    self,
    caches,
    fetch: fakeFetch,
    URL,
    Request,
    Response,
    Set,
    Promise,
    AbortController,
    setTimeout,
    clearTimeout,
    console,
  });

  return {
    listeners,
    cacheStore,
    setOffline(value) { networkOffline = value; },
    get fetchCount() { return fetchCount; },
  };
}

test('activation caches all 11 bundled PESO photos without waiting on remote stock image warm-up', async () => {
  const harness = await loadWorkerHarness();
  let activationPromise;
  harness.listeners.get('activate')({
    waitUntil(promise) { activationPromise = promise; },
  });
  await activationPromise;

  const cache = harness.cacheStore.get('peso-bundled-assets-v1');
  assert.ok(cache, 'bundled asset cache must exist');
  assert.equal(cache.entries.size, 11);
  assert.equal(harness.fetchCount, 11, 'activation should fetch only the 11 bundled assets');
});

test('a cached bundled PESO photo remains available when the network is offline', async () => {
  const harness = await loadWorkerHarness();
  let activationPromise;
  harness.listeners.get('activate')({
    waitUntil(promise) { activationPromise = promise; },
  });
  await activationPromise;

  harness.setOffline(true);
  const url = new URL('assets/lib/assets/peso_hero_career.jpg', scopeUrl).toString();
  let responsePromise;
  harness.listeners.get('fetch')({
    request: new Request(url),
    respondWith(promise) { responsePromise = promise; },
  });

  assert.ok(responsePromise, 'bundled photo requests must be intercepted by the cache handler');
  const response = await responsePromise;
  assert.equal(response.status, 200);
  assert.equal(await response.text(), 'local-image:/assets/lib/assets/peso_hero_career.jpg');
});

test('ordinary same-origin app resources are left to Flutter and not intercepted as photos', async () => {
  const harness = await loadWorkerHarness();
  let respondWithCalled = false;
  harness.listeners.get('fetch')({
    request: new Request(new URL('main.dart.js', scopeUrl)),
    respondWith() { respondWithCalled = true; },
  });
  assert.equal(respondWithCalled, false);
});
