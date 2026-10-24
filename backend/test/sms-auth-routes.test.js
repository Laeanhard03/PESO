import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { once } from 'node:events';

import { app } from '../server.js';

let server;
let baseUrl;

before(async () => {
  server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  baseUrl = 'http://127.0.0.1:' + server.address().port;
});

after(async () => {
  if (!server) return;
  const closed = new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  // undici fetch can leave keep-alive connections open; close them so node --test exits.
  server.closeAllConnections?.();
  await closed;
});

test('all legacy SMS auth and SMS password-reset routes are no longer mounted', async () => {
  const paths = [
    '/api/auth/sms/request',
    '/api/auth/sms/verify',
    '/api/auth/sms/logout',
    '/api/auth/password-reset/sms/reserve',
  ];
  for (const path of paths) {
    const response = await fetch(baseUrl + path, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ phone: '09942553411', code: '000000' }),
    });
    assert.equal(response.status, 404, path + ' should not exist');
  }
});