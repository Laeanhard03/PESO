import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import test from "node:test";

const workerSource = readFileSync(
  new URL("../../web/peso-image-cache-worker.js", import.meta.url),
  "utf8",
);
const origin = "https://peso.test";
const localImagePaths = [
  "/assets/lib/assets/peso_hero_career.jpg",
  "/assets/lib/assets/peso_programs_workshop.jpg",
  "/assets/lib/assets/peso_about_team.jpg",
  "/assets/lib/assets/peso_gallery_conference.jpg",
  "/assets/lib/assets/peso_gallery_workspace.jpg",
  "/assets/lib/assets/peso_gallery_team.jpg",
  "/assets/lib/assets/peso_gallery_meeting.jpg",
  "/assets/lib/assets/peso_gallery_event.jpg",
  "/assets/lib/assets/peso_gallery_career.jpg",
  "/assets/lib/assets/peso_job_default.jpg",
  "/assets/lib/assets/peso_job_technology.jpg",
];

test("worker caches every bundled PESO photo and can serve one after offline", async () => {
  const listeners = new Map();
  const cacheStore = new Map();
  let offlineLocalImages = false;
  const fakeCaches = {
    async open(name) {
      if (!cacheStore.has(name)) cacheStore.set(name, new Map());
      const entries = cacheStore.get(name);
      const keyOf = (request) =>
        request instanceof Request ? request.url : String(request);
      return {
        async match(request) {
          const key = keyOf(request);
          if (entries.has(key)) return entries.get(key).clone();
          const withoutSearch = key.split("?")[0];
          for (const [entryKey, response] of entries) {
            if (entryKey.split("?")[0] === withoutSearch) return response.clone();
          }
          return undefined;
        },
        async put(request, response) {
          entries.set(keyOf(request), response.clone());
        },
        async keys() {
          return [...entries.keys()].map((url) => new Request(url));
        },
        async delete(request) {
          return entries.delete(keyOf(request));
        },
      };
    },
    async keys() {
      return [...cacheStore.keys()];
    },
    async delete(name) {
      return cacheStore.delete(name);
    },
  };
  const fakeFetch = async (request) => {
    const url = new URL(request.url);
    if (
      offlineLocalImages &&
      url.origin === origin &&
      url.pathname.startsWith("/assets/lib/assets/peso_")
    ) {
      throw new TypeError("simulated offline connection");
    }
    return new Response("bundled photo bytes", {
      status: 200,
      headers: { "Content-Type": "image/jpeg" },
    });
  };
  const self = {
    location: { origin },
    registration: { scope: origin + "/" },
    addEventListener(name, handler) {
      listeners.set(name, handler);
    },
    skipWaiting: async () => undefined,
    clients: { claim: async () => undefined },
  };

  runInNewContext(workerSource, {
    self,
    caches: fakeCaches,
    fetch: fakeFetch,
    Request,
    Response,
    URL,
    AbortController,
    Promise,
    Set,
    RegExp,
    Array,
    console,
    setTimeout,
    clearTimeout,
  }, { filename: "peso-image-cache-worker.js" });

  const pending = [];
  listeners.get("activate")({
    waitUntil(promise) { pending.push(promise); },
  });
  await Promise.all(pending);

  const localCache = cacheStore.get("peso-bundled-assets-v1");
  assert.ok(localCache, "dedicated bundled-asset cache is created");
  assert.equal(localCache.size, localImagePaths.length);
  for (const path of localImagePaths) {
    assert.ok(
      localCache.has(new URL(path, origin).href),
      `cached ${path}`,
    );
  }

  // A later local-image request must be fulfilled from cache without network.
  offlineLocalImages = true;
  let responsePromise;
  listeners.get("fetch")({
    request: new Request(new URL(localImagePaths[0], origin).href),
    respondWith(promise) { responsePromise = promise; },
  });
  const cachedResponse = await responsePromise;
  assert.equal(cachedResponse.status, 200);
  assert.equal(await cachedResponse.text(), "bundled photo bytes");
});
