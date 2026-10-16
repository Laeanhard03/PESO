const CACHE_NAME = 'peso-resume-public-images-v1';
const MAX_CACHED_IMAGES = 200;
const WARM_IMAGES = [
  'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&q=80',
  'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&q=80',
  'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&q=80',
  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&q=80'
];
const PRIVATE_KEYS = new Set([
  'token', 'access_token', 'auth', 'authorization', 'signature',
  'x-goog-signature', 'x-amz-signature', 'awsaccesskeyid', 'credential', 'key'
]);

function isPublicImageRequest(request) {
  if (request.method !== 'GET') return false;
  const url = new URL(request.url);
  if (!['http:', 'https:'].includes(url.protocol) || url.origin === self.location.origin) return false;

  const acceptsImage = (request.headers.get('accept') || '').toLowerCase().includes('image/');
  const imagePath = /\.(avif|bmp|gif|jpe?g|png|svg|webp)$/i.test(url.pathname);
  const imageHost = /(^|\.)images\.unsplash\.com$/i.test(url.hostname);
  if (!(request.destination === 'image' || acceptsImage || imagePath || imageHost)) return false;

  for (const key of url.searchParams.keys()) {
    if (PRIVATE_KEYS.has(key.toLowerCase())) return false;
  }
  return true;
}

async function trimCache(cache) {
  const keys = await cache.keys();
  if (keys.length > MAX_CACHED_IMAGES) {
    await Promise.all(keys.slice(0, keys.length - MAX_CACHED_IMAGES).map((key) => cache.delete(key)));
  }
}

async function putImage(cache, request, response) {
  if (!response || (!response.ok && response.type !== 'opaque')) return;
  try {
    await cache.put(request, response.clone());
    await trimCache(cache);
  } catch {
    // Quota failures must not break the online resume builder.
  }
}

async function warmImage(cache, url) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const request = new Request(url, { mode: 'no-cors', signal: controller.signal });
    await putImage(cache, request, await fetch(request));
  } catch {
    // Optional background warm-up.
  } finally {
    clearTimeout(timeout);
  }
}

async function warmPublicImages() {
  const cache = await caches.open(CACHE_NAME);
  for (let start = 0; start < WARM_IMAGES.length; start += 2) {
    await Promise.all(WARM_IMAGES.slice(start, start + 2).map((url) => warmImage(cache, url)));
  }
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    await caches.open(CACHE_NAME);
    await self.skipWaiting();
  })());
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'PRECACHE_PUBLIC_IMAGES') {
    event.waitUntil(warmPublicImages());
  }
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  if (!isPublicImageRequest(event.request)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const hit = await cache.match(event.request, { ignoreVary: true });
    if (hit) return hit;
    try {
      const response = await fetch(event.request);
      await putImage(cache, event.request, response);
      return response;
    } catch {
      return (await cache.match(event.request, { ignoreVary: true })) || Response.error();
    }
  })());
});
