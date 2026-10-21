import test from 'node:test';
import assert from 'node:assert/strict';

import { installPublicPdfRoutes } from './public-pdf-routes.js';

function makeApp() {
  const routes = new Map();
  return {
    routes,
    get(path, ...handlers) { routes.set('GET ' + path, handlers); },
    post(path, ...handlers) { routes.set('POST ' + path, handlers); },
  };
}

function middleware(name) {
  const fn = (_req, _res, next) => next();
  fn.label = name;
  return fn;
}

test('public PDF admin routes register behind existing Firebase/Mongo admin middleware', () => {
  const app = makeApp();
  installPublicPdfRoutes(app, {
    ingestion: { getStatus: async () => [], syncAll: async () => ({ ok: true }) },
    requireAuth: middleware('auth'),
    requireAdmin: middleware('admin'),
    requireMongo: middleware('mongo'),
  });

  const statusHandlers = app.routes.get('GET /api/admin/public-information/sources');
  const syncHandlers = app.routes.get('POST /api/admin/public-information/sync');
  for (const handlers of [statusHandlers, syncHandlers]) {
    assert.deepEqual(handlers.slice(0, 3).map((handler) => handler.label), ['auth', 'admin', 'mongo']);
    assert.equal(typeof handlers[3], 'function');
  }
});

test('source status endpoint returns only ingestion status and forwards errors', async () => {
  const app = makeApp();
  const sources = [{ sourceId: 'montalban', syncStatus: 'ready' }];
  installPublicPdfRoutes(app, {
    ingestion: { getStatus: async () => sources, syncAll: async () => ({ ok: true }) },
    requireAuth: middleware('auth'),
    requireAdmin: middleware('admin'),
    requireMongo: middleware('mongo'),
  });

  let body;
  const response = { json(value) { body = value; return value; } };
  const handler = app.routes.get('GET /api/admin/public-information/sources').at(-1);
  await handler({}, response, (error) => { throw error; });
  assert.deepEqual(body, { ok: true, sources });
});

test('manual refresh returns quickly and background failure is sanitized', async () => {
  const app = makeApp();
  const warnings = [];
  let started = 0;
  installPublicPdfRoutes(app, {
    ingestion: {
      getStatus: async () => [],
      syncAll: async () => { started += 1; throw Object.assign(new Error('secret-like details'), { name: 'SafeTestError' }); },
    },
    requireAuth: middleware('auth'),
    requireAdmin: middleware('admin'),
    requireMongo: middleware('mongo'),
    logger: { warn: (message) => warnings.push(message) },
  });

  let httpStatus;
  let body;
  const response = {
    status(value) { httpStatus = value; return this; },
    json(value) { body = value; return value; },
  };
  const handler = app.routes.get('POST /api/admin/public-information/sync').at(-1);
  await handler({}, response, (error) => { throw error; });
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(httpStatus, 202);
  assert.deepEqual(body, { ok: true, status: 'sync_started' });
  assert.equal(started, 1);
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /SafeTestError/);
  assert.doesNotMatch(warnings[0], /secret-like details/);
});

test('manual refresh forwards synchronous route errors', async () => {
  const app = makeApp();
  installPublicPdfRoutes(app, {
    ingestion: {
      getStatus: async () => [],
      syncAll: () => { throw new Error('launch failed'); },
    },
    requireAuth: middleware('auth'),
    requireAdmin: middleware('admin'),
    requireMongo: middleware('mongo'),
  });
  const response = { status() { return this; }, json() { return this; } };
  const errors = [];
  const handler = app.routes.get('POST /api/admin/public-information/sync').at(-1);
  await handler({}, response, (error) => errors.push(error));
  assert.equal(errors.length, 1);
  assert.equal(errors[0].message, 'launch failed');
});
