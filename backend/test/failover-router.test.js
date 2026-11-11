import test from 'node:test';
import assert from 'node:assert/strict';
import { createFailoverMiddleware } from '../src/failover-router.js';

const PRIMARY = 'https://peso-psi.vercel.app';

function response(ok, payload = {}) {
  return {
    ok,
    async json() { return payload; },
  };
}

function request({ method = 'GET', path = '/', originalUrl = path, cookie = '' } = {}) {
  return {
    method,
    path,
    originalUrl,
    headers: { cookie },
  };
}

function responseRecorder() {
  return {
    headers: {},
    cookies: [],
    redirected: null,
    setHeader(name, value) { this.headers[name] = value; },
    cookie(name, value, options) { this.cookies.push({ name, value, options }); },
    redirect(status, location) { this.redirected = { status, location }; },
  };
}

async function run(middleware, req) {
  const res = responseRecorder();
  let nextCalled = false;
  await middleware(req, res, () => { nextCalled = true; });
  return { res, nextCalled };
}

test('healthy Vercel primary receives a path-preserving redirect', async () => {
  const calls = [];
  const middleware = createFailoverMiddleware({
    primaryUrl: PRIMARY,
    fetchImpl: async (url) => {
      calls.push(url);
      return url.endsWith('/api/health')
        ? response(true, { ok: true, mongoDbConnected: true })
        : response(true);
    },
  });

  const { res, nextCalled } = await run(
    middleware,
    request({ path: '/nsrp/resume', originalUrl: '/nsrp/resume?mode=edit' }),
  );

  assert.equal(nextCalled, false);
  assert.deepEqual(res.redirected, {
    status: 302,
    location: PRIMARY + '/nsrp/resume?mode=edit',
  });
  assert.equal(res.headers['X-PESO-Route'], 'vercel-primary');
  assert.equal(res.headers['Cache-Control'], 'no-store');
  assert.equal(calls.length, 2);
});

test('paused Vercel primary falls through to Render and sets a session cookie', async () => {
  const middleware = createFailoverMiddleware({
    primaryUrl: PRIMARY,
    fetchImpl: async (url) => url.endsWith('/api/health')
      ? response(false)
      : response(false),
  });

  const { res, nextCalled } = await run(middleware, request());

  assert.equal(nextCalled, true);
  assert.equal(res.redirected, null);
  assert.equal(res.headers['X-PESO-Route'], 'render-fallback');
  assert.equal(res.cookies.length, 1);
  assert.equal(res.cookies[0].name, 'peso_failover');
  assert.equal(res.cookies[0].value, 'render');
  assert.equal(res.cookies[0].options.httpOnly, true);
  assert.equal(res.cookies[0].options.secure, true);
  assert.equal(res.cookies[0].options.sameSite, 'lax');
  assert.equal(res.cookies[0].options.path, '/');
});

test('a Vercel site with an unavailable MongoDB API is not treated as healthy', async () => {
  const middleware = createFailoverMiddleware({
    primaryUrl: PRIMARY,
    fetchImpl: async (url) => url.endsWith('/api/health')
      ? response(true, { ok: true, mongoDbConnected: false })
      : response(true),
  });

  const { res, nextCalled } = await run(middleware, request());

  assert.equal(nextCalled, true);
  assert.equal(res.redirected, null);
  assert.equal(res.headers['X-PESO-Route'], 'render-fallback');
});

test('primary must expose required features before traffic returns to it', async () => {
  const middleware = createFailoverMiddleware({
    primaryUrl: PRIMARY,
    requiredFeatures: 'adminDevelopmentNotes',
    fetchImpl: async (url) => url.endsWith('/api/health')
      ? response(true, {
          ok: true,
          mongoDbConnected: true,
          features: { adminDevelopmentNotes: false },
        })
      : response(true),
  });

  const { res, nextCalled } = await run(middleware, request());

  assert.equal(nextCalled, true);
  assert.equal(res.redirected, null);
  assert.equal(res.headers['X-PESO-Route'], 'render-fallback');
});

test('API and health-check requests never redirect to the primary', async () => {
  let fetchCalls = 0;
  const middleware = createFailoverMiddleware({
    primaryUrl: PRIMARY,
    fetchImpl: async () => {
      fetchCalls += 1;
      return response(true, { ok: true, mongoDbConnected: true });
    },
  });

  for (const path of ['/api/health', '/api/jobs', '/healthz']) {
    const { res, nextCalled } = await run(middleware, request({ path }));
    assert.equal(nextCalled, true);
    assert.equal(res.redirected, null);
  }
  assert.equal(fetchCalls, 0);
});

test('a browser already pinned to the Render fallback stays on that origin', async () => {
  let fetchCalls = 0;
  const middleware = createFailoverMiddleware({
    primaryUrl: PRIMARY,
    fetchImpl: async () => {
      fetchCalls += 1;
      return response(true, { ok: true, mongoDbConnected: true });
    },
  });

  const { res, nextCalled } = await run(
    middleware,
    request({ cookie: 'session=abc; peso_failover=render' }),
  );

  assert.equal(nextCalled, true);
  assert.equal(res.redirected, null);
  assert.equal(res.headers['X-PESO-Route'], 'render-fallback');
  assert.equal(fetchCalls, 0);
});

test('primary health checks are cached across requests', async () => {
  let now = 1000;
  let fetchCalls = 0;
  const middleware = createFailoverMiddleware({
    primaryUrl: PRIMARY,
    cacheMs: 10_000,
    now: () => now,
    fetchImpl: async (url) => {
      fetchCalls += 1;
      return url.endsWith('/api/health')
        ? response(true, { ok: true, mongoDbConnected: true })
        : response(true);
    },
  });

  const first = await run(middleware, request());
  const second = await run(middleware, request({ path: '/jobs', originalUrl: '/jobs' }));
  assert.equal(first.res.redirected.location, PRIMARY + '/');
  assert.equal(second.res.redirected.location, PRIMARY + '/jobs');
  assert.equal(fetchCalls, 2);

  now += 10_001;
  await run(middleware, request({ path: '/about', originalUrl: '/about' }));
  assert.equal(fetchCalls, 4);
});

test('network failures safely select the Render fallback', async () => {
  const middleware = createFailoverMiddleware({
    primaryUrl: PRIMARY,
    fetchImpl: async () => { throw new Error('upstream unavailable'); },
  });

  const { res, nextCalled } = await run(middleware, request());

  assert.equal(nextCalled, true);
  assert.equal(res.redirected, null);
  assert.equal(res.headers['X-PESO-Route'], 'render-fallback');
});

test('an unset or non-HTTPS primary disables redirect logic safely', async () => {
  let fetchCalls = 0;
  const middleware = createFailoverMiddleware({
    primaryUrl: 'http://peso-psi.vercel.app',
    fetchImpl: async () => {
      fetchCalls += 1;
      return response(true, { ok: true, mongoDbConnected: true });
    },
  });

  const { res, nextCalled } = await run(middleware, request());

  assert.equal(nextCalled, true);
  assert.equal(res.redirected, null);
  assert.equal(res.cookies.length, 0);
  assert.equal(fetchCalls, 0);
});
