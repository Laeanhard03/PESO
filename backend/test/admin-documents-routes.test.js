import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { app, state } from '../server.js';

const profiles = new Map([
  ['test-admin', {
    uid: 'test-admin', role: 'admin', email: 'admin@example.org',
    displayName: 'PESO Admin', disabled: false, deleted: false,
  }],
  ['resume-builder', {
    uid: 'resume-builder', role: 'job_seeker',
    displayName: 'Applicant <Unsafe>',
    email: 'candidate@example.org',
    resumeData: {
      summary: 'Comfortable with <script>fake text</script> and spreadsheets',
      skills: ['Customer service', 'Encoding'],
    },
    disabled: false, deleted: false,
  }],
]);

const emptyCursor = {
  sort() { return this; },
  limit() { return this; },
  async toArray() { return []; },
};

const db = {
  collection(name) {
    if (name === 'users') {
      return {
        async findOne({ uid }) { return profiles.get(uid) || null; },
      };
    }
    if (name === 'profileArtifacts.files') {
      return { async findOne() { return null; } };
    }
    if (name === 'jobPdfLinks') {
      return { find() { return emptyCursor; } };
    }
    throw new Error('Unexpected collection ' + name);
  },
};

let server;
let origin;

before(async () => {
  state.mongoConnected = true;
  state.db = db;
  state.bucket = {};
  state.tokenVerifierOverride = async (token) => {
    if (token !== 'admin-token') throw new Error('Invalid token');
    return {
      uid: 'test-admin', email: 'admin@example.org',
      email_verified: true, name: 'PESO Admin',
      firebase: { sign_in_provider: 'google.com' },
    };
  };
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  origin = 'http://127.0.0.1:' + server.address().port;
});
after(async () => {
  await new Promise((resolve, reject) =>
    server.close((error) => error ? reject(error) : resolve()));
});

test('only admins can obtain a private structured resume link', async () => {
  const denied = await fetch(origin + '/api/admin/users/resume-builder/resume-link', {
    method: 'POST',
  });
  assert.equal(denied.status, 401);

  const signed = await fetch(origin + '/api/admin/users/resume-builder/resume-link', {
    method: 'POST',
    headers: { Authorization: 'Bearer admin-token' },
  });
  assert.equal(signed.status, 200);
  const data = await signed.json();
  assert.equal(data.ok, true);
  assert.equal(data.type, 'structured_preview');
  const signedUrl = new URL(data.url);
  assert.equal(signedUrl.searchParams.get('fileId'), 'profile');
  const fetchLocal = origin + signedUrl.pathname + signedUrl.search;
  const result = await fetch(fetchLocal);
  assert.equal(result.status, 200);
  assert.match(result.headers.get('content-type'), /text\/html/);
  assert.match(result.headers.get('content-security-policy'), /default-src 'none'/);
  const html = await result.text();
  assert.match(html, /Applicant &lt;Unsafe&gt;/);
  assert.match(html, /&lt;script&gt;fake text&lt;\/script&gt;/);
  assert.doesNotMatch(html, /<script>fake text/);

  signedUrl.searchParams.set('ownerUid', 'test-admin');
  const tampered = await fetch(origin + signedUrl.pathname + signedUrl.search);
  assert.equal(tampered.status, 403);
});

test('PDF link registry is admin-only and rejects unapproved hosts', async () => {
  const denied = await fetch(origin + '/api/admin/jobs/pdf-links');
  assert.equal(denied.status, 401);
  const list = await fetch(origin + '/api/admin/jobs/pdf-links', {
    headers: { Authorization: 'Bearer admin-token' },
  });
  assert.equal(list.status, 200);
  assert.deepEqual((await list.json()).sources, []);
  const invalid = await fetch(origin + '/api/admin/jobs/pdf-links', {
    method: 'POST',
    headers: {
      Authorization: 'Bearer admin-token',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ title: 'Untrusted PDF', url: 'https://unapproved.example/jobs.pdf',
      category: 'walk_in_application' }),
  });
  assert.equal(invalid.status, 422);
  const payload = await invalid.json();
  assert.equal(payload.error, 'pdf_host_not_approved');
});
