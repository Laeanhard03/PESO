const DEFAULT_CACHE_MS = 10_000;
const DEFAULT_TIMEOUT_MS = 2_500;
const FALLBACK_COOKIE = 'peso_failover=render';

function normalizePrimaryUrl(value) {
  try {
    const url = new URL(String(value || '').trim());
    if (url.protocol !== 'https:' || url.username || url.password ||
        url.pathname !== '/' || url.search || url.hash) return '';
    return url.origin;
  } catch {
    return '';
  }
}

function hasFallbackCookie(header) {
  return String(header || '').split(';')
    .some((part) => part.trim() === FALLBACK_COOKIE);
}

function requestPath(req) {
  return String(req.path || req.originalUrl || '/').split('?')[0] || '/';
}

/**
 * Creates an external-origin failover router for the Render-hosted copy.
 *
 * The Render URL is the stable entry point. It checks both the primary site's
 * HTML and its MongoDB-backed API health endpoint. When both are healthy, new
 * browser navigations are redirected to the Vercel primary. If Vercel is
 * paused/unhealthy, the request falls through to the Render-hosted Flutter
 * bundle and receives a session cookie so its assets and SPA routes stay on
 * the same backup origin.
 *
 * API requests are never redirected: the fallback app must use its own API.
 */
export function createFailoverMiddleware({
  primaryUrl = process.env.PESO_FAILOVER_PRIMARY_URL,
  fetchImpl = globalThis.fetch,
  cacheMs = DEFAULT_CACHE_MS,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  requiredFeatures = process.env.PESO_FAILOVER_REQUIRED_FEATURES || '',
  now = Date.now,
} = {}) {
  const primary = normalizePrimaryUrl(primaryUrl);
  const safeCacheMs = Number.isFinite(Number(cacheMs))
    ? Math.max(0, Number(cacheMs)) : DEFAULT_CACHE_MS;
  const safeTimeoutMs = Number.isFinite(Number(timeoutMs))
    ? Math.max(250, Number(timeoutMs)) : DEFAULT_TIMEOUT_MS;
  const required = (Array.isArray(requiredFeatures) ? requiredFeatures : String(requiredFeatures || '').split(','))
    .map((feature) => String(feature).trim())
    .filter(Boolean);

  let hasCache = false;
  let cachedHealthy = false;
  let checkedAt = 0;
  let pendingCheck = null;

  async function isPrimaryHealthy() {
    if (!primary || typeof fetchImpl !== 'function') return false;

    const currentTime = now();
    if (hasCache && currentTime - checkedAt < safeCacheMs) {
      return cachedHealthy;
    }
    if (pendingCheck) return pendingCheck;

    pendingCheck = (async () => {
      let healthy = false;
      try {
        const signal = AbortSignal.timeout(safeTimeoutMs);
        const [siteResponse, healthResponse] = await Promise.all([
          fetchImpl(primary + '/', {
            method: 'GET',
            redirect: 'follow',
            headers: { Accept: 'text/html' },
            signal,
          }),
          fetchImpl(primary + '/api/health', {
            method: 'GET',
            redirect: 'follow',
            headers: { Accept: 'application/json' },
            signal,
          }),
        ]);

        if (!siteResponse?.ok || !healthResponse?.ok) {
          throw new Error('primary_http_unhealthy');
        }
        const health = await healthResponse.json();
        const requiredFeaturesReady = required.every((feature) =>
          health?.features?.[feature] === true);
        healthy = health?.ok === true &&
          health?.mongoDbConnected === true &&
          requiredFeaturesReady;
      } catch {
        healthy = false;
      }

      cachedHealthy = healthy;
      checkedAt = now();
      hasCache = true;
      return healthy;
    })();

    try {
      return await pendingCheck;
    } finally {
      pendingCheck = null;
    }
  }

  return async function pesoFailoverRouter(req, res, next) {
    const pathname = requestPath(req);
    if (!primary || !['GET', 'HEAD'].includes(String(req.method || 'GET').toUpperCase()) ||
        pathname === '/healthz' || pathname === '/api' || pathname.startsWith('/api/')) {
      return next();
    }

    res.setHeader('Cache-Control', 'no-store');
    if (hasFallbackCookie(req.headers?.cookie)) {
      res.setHeader('X-PESO-Route', 'render-fallback');
      return next();
    }

    if (await isPrimaryHealthy()) {
      res.setHeader('X-PESO-Route', 'vercel-primary');
      const requested = String(req.originalUrl || pathname || '/');
      return res.redirect(302, primary + (requested.startsWith('/') ? requested : '/' + requested));
    }

    // Session-scoped so all subsequent Flutter, NSRP, and lazy-loaded assets
    // stay on the same Render origin even if Vercel recovers mid-navigation.
    res.cookie('peso_failover', 'render', {
      httpOnly: true,
      secure: true,
      sameSite: 'lax',
      path: '/',
    });
    res.setHeader('X-PESO-Route', 'render-fallback');
    return next();
  };
}

export { normalizePrimaryUrl };
