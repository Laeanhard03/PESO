import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { ObjectId } from 'mongodb';

import { app, state } from '../server.js';

const applications = new Map();
const userProfiles = new Map();
const welderId = new ObjectId('507f1f77bcf86cd799439011');
const encoderId = new ObjectId('507f1f77bcf86cd799439012');
const postedJobs = new Map([
  [String(welderId), { _id: welderId, status: 'active', category: 'walk_in_application',
    title: 'NOW HIRING! — Welder', company: 'JCRCC', location: 'Rodriguez, Rizal' }],
  [String(encoderId), { _id: encoderId, status: 'active', category: 'walk_in_application',
    title: 'Encoder', company: 'PESO', location: 'Rodriguez, Rizal' }],
]);

function appCopy(record) {
  return {
    ...record,
    submittedAt: record.submittedAt instanceof Date ? new Date(record.submittedAt) : record.submittedAt,
    updatedAt: record.updatedAt instanceof Date ? new Date(record.updatedAt) : record.updatedAt,
  };
}

function matches(record, filter = {}) {
  return Object.entries(filter).every(([key, value]) =>
    value instanceof ObjectId ? String(record[key]) === String(value)
      : record[key] === value);
}

const appCollection = {
  find(filter = {}) {
    let documents = [...applications.values()].filter((row) => matches(row, filter));
    const cursor = {
      sort(order = {}) {
        const [[field, direction]] = Object.entries(order);
        if (field) {
          documents = documents.sort((a, b) => {
            const av = a[field] instanceof Date ? a[field].getTime() : String(a[field] || '');
            const bv = b[field] instanceof Date ? b[field].getTime() : String(b[field] || '');
            return (av < bv ? -1 : av > bv ? 1 : 0) * (direction < 0 ? -1 : 1);
          });
        }
        return cursor;
      },
      skip(offset) {
        documents = documents.slice(offset);
        return cursor;
      },
      limit(maximum) {
        documents = documents.slice(0, maximum);
        return cursor;
      },
      async toArray() {
        return documents.map(appCopy);
      },
    };
    return cursor;
  },
  async findOne(filter = {}) {
    const found = [...applications.values()].find((row) => matches(row, filter));
    return found ? appCopy(found) : null;
  },
  async insertOne(record) {
    const _id = record._id ?? new ObjectId();
    if (applications.has(String(_id))) throw Object.assign(new Error('Duplicate'), { code: 11000 });
    const stored = { ...record, _id };
    applications.set(String(_id), stored);
    return { insertedId: _id };
  },
  async updateOne(filter, update, options = {}) {
    const existing = [...applications.values()].find((row) => matches(row, filter));
    if (existing) {
      if (update.$set) Object.assign(existing, structuredClone(update.$set));
      return { matchedCount: 1, modifiedCount: 1, upsertedCount: 0 };
    }
    if (!options.upsert) return { matchedCount: 0, modifiedCount: 0, upsertedCount: 0 };
    const _id = new ObjectId();
    const stored = {
      ...structuredClone(update.$setOnInsert || {}),
      ...Object.fromEntries(Object.entries(filter).filter(([, v]) => v != null && typeof v !== 'object')),
      ...structuredClone(update.$set || {}),
      _id,
    };
    applications.set(String(_id), stored);
    return { matchedCount: 0, modifiedCount: 0, upsertedCount: 1 };
  },
};

const userCollection = {
  async findOne({ uid }) { return userProfiles.has(uid) ? structuredClone(userProfiles.get(uid)) : null; },
  async updateOne({ uid }, update, options = {}) {
    let profile = userProfiles.get(uid);
    if (!profile && options.upsert) { profile = structuredClone(update.$setOnInsert || { uid }); userProfiles.set(uid, profile); }
    if (profile && update.$set) Object.assign(profile, structuredClone(update.$set));
    return { matchedCount: profile ? 1 : 0, upsertedCount: 0 };
  },
};

const adminAuth = {
  async verifyIdToken(token) {
    if (token === 'admin-token') return { uid: 'test-admin', email: 'admin@example.test', admin: true, email_verified: true };
    if (token === 'regular-token') return { uid: 'test-user', email: 'user@example.test', admin: false, email_verified: true };
    throw new Error('Invalid token');
  },
};

let server;
let baseUrl;

function request(path, { method = 'GET', token, body } = {}) {
  const headers = { Accept: 'application/json' };
  if (token) headers.Authorization = 'Bearer ' + token;
  if (body != null) headers['Content-Type'] = 'application/json';
  return fetch(baseUrl + path, {
    method,
    headers,
    body: body == null ? undefined : JSON.stringify(body),
  }).then(async (response) => {
    let payload = {};
    try { payload = await response.json(); } catch { payload = {}; }
    return { status: response.status, body: payload };
  });
}

before(async () => {
  applications.clear();
  userProfiles.clear();
  userProfiles.set('test-admin', { uid: 'test-admin', role: 'admin', email: 'admin@example.test', displayName: 'PESO Admin', disabled: false, deleted: false });
  userProfiles.set('test-user', { uid: 'test-user', role: 'job_seeker', email: 'user@example.test', displayName: 'Test User', disabled: false, deleted: false,
    municipality: 'Rodriguez', barangay: 'San Jose', address: 'San Jose, Rodriguez, Rizal',
    residency: { status: 'verified' } });
  state.tokenVerifierOverride = async (token) => {
    if (token === 'admin-token') return { uid: 'test-admin', email: 'admin@example.test', name: 'PESO Admin', email_verified: true, firebase: { sign_in_provider: 'google.com' } };
    if (token === 'regular-token') return { uid: 'test-user', email: 'user@example.test', name: 'Test User', email_verified: true, firebase: { sign_in_provider: 'google.com' } };
    throw new Error('Invalid token');
  };
  state.mongoConnected = true;
  state.mongoProblem = null;
  state.db = {
    collection(name) {
      if (name === 'jobApplications') return appCollection;
      if (name === 'users') return userCollection;
      if (name === 'jobPostings') return {
        async findOne(filter) {
          const job = postedJobs.get(String(filter._id));
          return job?.status === filter.status ? structuredClone(job) : null;
        },
      };
      throw new Error('Unexpected collection: ' + name);
    },
  };
  state.bucket = {};
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = 'http://127.0.0.1:' + server.address().port;
});

after(async () => {
  await new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
});

test('application submission requires authentication', async () => {
  const result = await request('/api/applications', {
    method: 'POST',
    body: { jobTitle: 'Welder', answers: { experience: '1-2' } },
  });
  assert.equal(result.status, 401);
});

test('application submission requires a job title and answers', async () => {
  const result = await request('/api/applications', {
    method: 'POST',
    token: 'regular-token',
    body: { jobTitle: 'Welder', answers: {} },
  });
  assert.equal(result.status, 400);
  assert.equal(result.body.error, 'application_incomplete');
});

test('a signed-in user submits once and retry does not overwrite screening answers', async () => {
  const first = await request('/api/applications', {
    method: 'POST',
    token: 'regular-token',
    body: {
      jobId: String(welderId),
      jobTitle: 'NOW HIRING! — Welder',
      employer: 'JCRCC',
      location: 'Rodriguez, Rizal',
      matchScore: 0,
      answers: { experience: '3-5', availability: 'Next week', willingToWork: 'Yes' },
    },
  });
  assert.equal(first.status, 201);
  assert.equal(first.body.ok, true);
  assert.equal(first.body.application.jobTitle, 'NOW HIRING! — Welder');
  assert.equal(first.body.application.status, 'submitted');
  assert.equal(applications.size, 1);

  const second = await request('/api/applications', {
    method: 'POST',
    token: 'regular-token',
    body: {
      jobId: String(welderId),
      jobTitle: 'NOW HIRING! — Welder',
      employer: 'JCRCC',
      answers: { experience: 'More than 5 years', availability: 'Within a few days', willingToWork: 'Yes' },
    },
  });
  assert.equal(second.status, 409);
  assert.equal(second.body.error, 'application_already_submitted');
  assert.equal(applications.size, 1);
  const stored = [...applications.values()][0];
  assert.equal(stored.answers.experience, '3-5');
  assert.equal(stored.status, 'submitted');
});

test('screening answers are sanitized and capped', async () => {
  const result = await request('/api/applications', {
    method: 'POST',
    token: 'regular-token',
    body: {
      jobId: String(encoderId),
      jobTitle: 'Encoder',
      answers: {
        experience: '<script>alert(1)</script>',
        'bad-key!': 'ignored',
        availability: 'A'.repeat(300),
      },
    },
  });
  assert.equal(result.status, 201);
  const stored = [...applications.values()].find((row) => row.jobTitle === 'Encoder');
  assert.equal(stored.answers.experience, '<script>alert(1)</script>'.slice(0, 200));
  assert.equal(stored.answers.availability.length, 200);
  assert.ok(!('bad-key!' in stored.answers));
});

test('applicants can list only their own submitted jobs and paginate safely', async () => {
  const previousApplications = new Map(applications);
  try {
    applications.clear();
  const newerId = new ObjectId();
  const olderId = new ObjectId();
  const foreignId = new ObjectId();
  const makeApplication = (id, uid, jobId, submittedAt, email) => ({
    _id: id,
    uid,
    email,
    applicantName: uid,
    jobId,
    jobKey: jobId,
    jobTitle: jobId,
    employer: 'PESO test employer',
    location: 'Rodriguez, Rizal',
    category: 'walk_in_application',
    answers: { experience: 'Just starting' },
    status: 'submitted',
    submittedAt: new Date(submittedAt),
  });
  applications.set(String(newerId), makeApplication(newerId, 'test-user', 'own-newer-job', '2026-10-21T10:00:00Z', 'user@example.test'));
  applications.set(String(olderId), makeApplication(olderId, 'test-user', 'own-older-job', '2026-10-20T10:00:00Z', 'user@example.test'));
  applications.set(String(foreignId), makeApplication(foreignId, 'other-user', 'foreign-job', '2026-10-22T10:00:00Z', 'other@example.test'));

  const first = await request('/api/applications?limit=1', { token: 'regular-token' });
  assert.equal(first.status, 200);
  const pageOne = first.body;
  assert.deepEqual(pageOne.applications.map((row) => row.jobId), ['own-newer-job']);
  assert.equal(pageOne.nextPageToken, '1');
  assert.equal(Object.hasOwn(pageOne.applications[0], 'uid'), false);
  assert.equal(Object.hasOwn(pageOne.applications[0], 'email'), false);

  const second = await request('/api/applications?limit=1&pageToken=1', { token: 'regular-token' });
  assert.equal(second.status, 200);
  assert.deepEqual(second.body.applications.map((row) => row.jobId), ['own-older-job']);

  const invalid = await request('/api/applications?pageToken=not-a-number', { token: 'regular-token' });
  assert.equal(invalid.status, 400);
  assert.equal(invalid.status, 400);
  assert.equal(invalid.body.error, 'invalid_page_token');
  } finally {
    applications.clear();
    for (const [id, row] of previousApplications) applications.set(id, row);
  }
});

test('admin applications paginate without hiding later entries', async () => {
  const first = await request('/api/admin/applications?limit=1', { token: 'admin-token' });
  assert.equal(first.status, 200);
  assert.equal(first.body.applications.length, 1);
  assert.equal(first.body.nextPageToken, '1');
  const second = await request('/api/admin/applications?limit=1&pageToken=1', { token: 'admin-token' });
  assert.equal(second.status, 200);
  assert.equal(second.body.applications.length, 1);
  assert.notEqual(first.body.applications[0].id, second.body.applications[0].id);
  const invalid = await request('/api/admin/applications?pageToken=not-a-number', { token: 'admin-token' });
  assert.equal(invalid.status, 400);
});

test('only admins can list applications', async () => {
  const anonymous = await request('/api/admin/applications');
  assert.equal(anonymous.status, 401);
  const regular = await request('/api/admin/applications', { token: 'regular-token' });
  assert.equal(regular.status, 403);
  const admin = await request('/api/admin/applications', { token: 'admin-token' });
  assert.equal(admin.status, 200);
  assert.equal(admin.body.ok, true);
  assert.ok(Array.isArray(admin.body.applications));
  const listed = admin.body.applications.find((row) => row.jobTitle.includes('Welder'));
  assert.ok(listed);
  assert.equal(listed.applicantUid, 'test-user');
});

test('concurrent retries create one saved application and preserve job provenance', async () => {
  const id = new ObjectId();
  postedJobs.set(String(id), { _id: id, status: 'active', category: 'walk_in_application',
    title: 'Actual saved role', company: 'Confirmed employer', location: 'Rodriguez, Rizal' });
  try {
    const payload = { jobId: String(id), jobTitle: 'Forged client title',
      employer: 'Forged employer', matchScore: 99,
      answers: { experience: 'yes', availability: 'now' } };
    const replies = await Promise.all(Array.from({ length: 12 }, () =>
      request('/api/applications', { token: 'regular-token', method: 'POST', body: payload })));
    assert.equal(replies.filter((r) => r.status === 201).length, 1);
    assert.equal(replies.filter((r) => r.status === 409).length, 11);
    const saved = [...applications.values()].filter((row) => row.jobId === String(id));
    assert.equal(saved.length, 1);
    assert.equal(saved[0].jobTitle, 'Actual saved role');
    assert.equal(saved[0].employer, 'Confirmed employer');
    assert.equal(saved[0].matchScore, null);
    assert.equal(replies.find((r) => r.status === 201).body.application.id, String(saved[0]._id));
  } finally {
    postedJobs.delete(String(id));
  }
});

test('a removed or expired job never accepts a new application', async () => {
  const id = new ObjectId();
  postedJobs.set(String(id), { _id: id, status: 'deleted', category: 'walk_in_application',
    title: 'Closed role', company: 'Previous employer' });
  try {
    const missing = await request('/api/applications', { token: 'regular-token',
      method: 'POST', body: { jobId: String(id), answers: { experience: 'yes' } } });
    assert.equal(missing.status, 409);
    assert.equal(missing.body.error, 'job_not_available');
    const invalid = await request('/api/applications', { token: 'regular-token',
      method: 'POST', body: { jobId: 'not-a-stored-id',
        jobTitle: 'Invented job', answers: { experience: 'yes' } } });
    assert.equal(invalid.status, 400);
  } finally {
    postedJobs.delete(String(id));
  }
});

test('notification records are scoped to the owner and open a saved application', async () => {
  const mine = await request('/api/notifications?limit=20', { token: 'regular-token' });
  assert.equal(mine.status, 200);
  assert.ok(Array.isArray(mine.body.notifications));
  assert.ok(mine.body.notifications.length >= 1);
  assert.ok(mine.body.notifications.every((notice) =>
    notice.kind === 'application' && notice.target === 'outcomes' &&
    notice.applicationId && notice.id === 'application:' + notice.applicationId));
  assert.ok(mine.body.notifications.every((notice) =>
    notice.message && !notice.message.includes('foreign-job')));
  const anonymous = await request('/api/notifications');
  assert.equal(anonymous.status, 401);
  const welder = [...applications.values()].find((row) => row.jobTitle.includes('Welder'));
  assert.ok(welder);
  const status = await request('/api/admin/applications/' + String(welder._id) + '/status',
    { token: 'admin-token', method: 'PATCH', body: { status: 'under_review' } });
  assert.equal(status.status, 200);
  const updated = await request('/api/notifications', { token: 'regular-token' });
  assert.ok(updated.body.notifications.some((notice) =>
    notice.applicationId === String(welder._id) &&
    notice.title === 'Application under review'));
});
