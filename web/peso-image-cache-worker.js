const CACHE_NAME = 'peso-remote-images-v1';
const BUNDLED_CACHE_NAME = 'peso-bundled-assets-v2';
const MAX_CACHED_IMAGES = 300;

const BUNDLED_ASSET_IMAGES = [
  // Warm only first-view and common job fallback imagery.
  // Gallery/About photos are loaded and cached on first visit instead of
  // downloading the entire photo set during initial landing-page startup.
  'assets/lib/assets/peso_hero_career.jpg',
  'assets/lib/assets/peso_job_default.jpg',
  'assets/lib/assets/peso_job_technology.jpg',
];

const BUILT_IN_PUBLIC_IMAGES = [
  'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1528605105345-5344ea20e269?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1556761175-4b46a572b786?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1517048676732-d65bc937f952?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
  'https://images.unsplash.com/photo-1573164713988-8665fc963095?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1522071820081-009f0129c71c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1552664730-d307ca884978?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1497215728101-856f4ea42174?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?auto=format&fit=crop&w=600&q=80',
  'https://images.unsplash.com/photo-1556761175-4b46a572b786?auto=format&fit=crop&w=600&q=80',
  'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=600&q=80',
  'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=600&q=80',
  'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&q=80',
  'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&q=80',
  'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&q=80',
  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&q=80'
];

const PRIVATE_QUERY_KEYS = new Set([
  'token',
  'access_token',
  'auth',
  'authorization',
  'signature',
  'x-goog-signature',
  'x-amz-signature',
  'awsaccesskeyid',
  'credential',
  'key'
]);

function isBundledLocalImageRequest(request) {
  if (request.method !== 'GET') return false;
  const url = new URL(request.url);
  const scope = new URL(self.registration.scope);
  if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) return false;
  const relativePath = url.pathname.slice(scope.pathname.length);
  return /^assets\/lib\/assets\/peso_[a-z_]+\.jpg$/i.test(relativePath);
}

async function trimCache(cache) {
  const keys = await cache.keys();
  if (keys.length <= MAX_CACHED_IMAGES) return;
  const excess = keys.length - MAX_CACHED_IMAGES;
  await Promise.all(keys.slice(0, excess).map((key) => cache.delete(key)));
}

async function cacheImageResponse(cache, request, response) {
  if (!response || (!response.ok && response.type !== 'opaque')) return;
  try {
    await cache.put(request, response.clone());
    await trimCache(cache);
  } catch (_) {
    // Cache quota or an unusual response must never break normal online images.
  }
}

async function warmBundledAssetImages() {
  const cache = await caches.open(BUNDLED_CACHE_NAME);
  await Promise.all(BUNDLED_ASSET_IMAGES.map(async (relativePath) => {
    const url = new URL(relativePath, self.registration.scope).toString();
    try {
      const response = await fetch(new Request(url, { method: 'GET', cache: 'reload' }));
      if (response.ok) await cache.put(url, response.clone());
    } catch (_) {
      // Local assets are also bundled with the app; failed warm-up is non-fatal.
    }
  }));
}

async function serveBundledAssetImage(request) {
  const cache = await caches.open(BUNDLED_CACHE_NAME);
  const cached = await cache.match(request, { ignoreSearch: true });
  if (cached) return cached;
  try {
    const response = await fetch(request);
    if (response.ok) {
      try {
        await cache.put(request, response.clone());
      } catch (_) {
        // Keep serving the fetched image if the browser denies cache storage.
      }
    }
    return response;
  } catch (_) {
    const fallback = await cache.match(request, { ignoreSearch: true });
    return fallback || Response.error();
  }
}

function isPublicRemoteImageRequest(request) {
  if (request.method !== 'GET') return false;
  const url = new URL(request.url);
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return false;
  if (url.origin === self.location.origin) return false;

  const accept = (request.headers.get('accept') || '').toLowerCase();
  const pathname = url.pathname.toLowerCase();
  const imageExtension = /\.(avif|bmp|gif|jpe?g|png|svg|webp)(?:$)/i.test(pathname);
  const knownImageHost = /(^|\.)images\.unsplash\.com$|(^|\.)upload\.wikimedia\.org$|(^|\.)i\.kym-cdn\.com$/i.test(url.hostname);
  const looksLikeImage = request.destination === 'image' || accept.includes('image/') || imageExtension || knownImageHost;
  if (!looksLikeImage) return false;
  for (const key of url.searchParams.keys()) {
    if (PRIVATE_QUERY_KEYS.has(key.toLowerCase())) return false;
  }
  return true;
}

async function fetchAndCachePublicImage(cache, url) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12000);
  try {
    const request = new Request(url, {
      method: 'GET',
      mode: 'no-cors',
      cache: 'reload',
      signal: controller.signal
    });
    const response = await fetch(request);
    await cacheImageResponse(cache, request, response);
  } catch (_) {
    // Optional warm-up; the app must still install if an image host is offline.
  } finally {
    clearTimeout(timer);
  }
}

async function warmBuiltInPublicImages() {
  const cache = await caches.open(CACHE_NAME);
  for (let start = 0; start < BUILT_IN_PUBLIC_IMAGES.length; start += 3) {
    const batch = BUILT_IN_PUBLIC_IMAGES.slice(start, start + 3);
    await Promise.all(batch.map((url) => fetchAndCachePublicImage(cache, url)));
  }
}

self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(
      names
        .filter((name) => (name.startsWith('peso-remote-images-') && name !== CACHE_NAME) || (name.startsWith('peso-bundled-assets-') && name !== BUNDLED_CACHE_NAME))
        .map((name) => caches.delete(name))
    );
    await self.clients.claim();
    await warmBundledAssetImages();
  })());
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'PRECACHE_PUBLIC_IMAGES') {
    event.waitUntil(warmBuiltInPublicImages());
  }
});

self.addEventListener('fetch', (event) => {
  if (isBundledLocalImageRequest(event.request)) {
    event.respondWith(serveBundledAssetImage(event.request));
    return;
  }
  if (!isPublicRemoteImageRequest(event.request)) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(event.request, { ignoreVary: true });
    if (cached) return cached;
    try {
      const response = await fetch(event.request);
      await cacheImageResponse(cache, event.request, response);
      return response;
    } catch (_) {
      const fallback = await cache.match(event.request, { ignoreVary: true });
      if (fallback) return fallback;
      return Response.error();
    }
  })());
});
