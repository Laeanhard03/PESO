import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { ObjectId } from 'mongodb';

import { app, state } from '../server.js';

const jobs = new Map();

function jobCopy(job) {
  return {
    ...job,
    createdAt: job.createdAt instanceof Date ? new Date(job.createdAt) : job.createdAt,
    expiresAt: job.expiresAt instanceof Date ? new Date(job.expiresAt) : job.expiresAt,
    updatedAt: job.updatedAt instanceof Date ? new Date(job.updatedAt) : job.updatedAt,
  };
}

function matches(job, filter = {}) {
  return Object.entries(filter).every(([key, value]) => {
    if (value instanceof ObjectId) return String(job[key]) === String(value);
    return job[key] === value;
  });
}

const jobCollection = {
  find(filter = {}) {
    let documents = [...jobs.values()].filter((job) => matches(job, filter));
    const cursor = {
      sort(order = {}) {
        const [[field, direction]] = Object.entries(order);
        if (field) {
          documents = documents.sort((a, b) => {
            const av = a[field] instanceof Date ? a[field].getTime() : Number(a[field] || 0);
            const bv = b[field] instanceof Date ? b[field].getTime() : Number(b[field] || 0);
            return (av - bv) * (direction < 0 ? -1 : 1);
          });
        }
        return cursor;
      },
      limit(maximum) {
        documents = documents.slice(0, maximum);
        return cursor;
      },
      async toArray() {
        return documents.map(jobCopy);
      },
    };
    return cursor;
  },
  async findOne(filter = {}) {
    const found = [...jobs.values()].find((job) => matches(job, filter));
    return found ? jobCopy(found) : null;
  },
  async insertOne(record) {
    const _id = new ObjectId();
    jobs.set(String(_id), { ...record, _id });
    return { insertedId: _id };
  },
  async updateOne(filter, update) {
    const existing = [...jobs.values()].find((job) => matches(job, filter));
    if (!existing) return { matchedCount: 0, modifiedCount: 0 };
    Object.assign(existing, structuredClone(update.$set || {}));
    return { matchedCount: 1, modifiedCount: 1 };
  },
};

const userProfiles = new Map();
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
    if (token === 'admin-token') {
      return { uid: 'test-admin', email: 'admin@example.test', admin: true, email_verified: true };
    }
    if (token === 'regular-token') {
      return { uid: 'test-user', email: 'user@example.test', admin: false, email_verified: true };
    }
    throw new Error('Invalid token');
  },
};

let server;
let baseUrl;

before(async () => {
  jobs.clear();
  userProfiles.clear();
  state.tokenVerifierOverride = async (token) => {
    if (token === 'admin-token') return {
      uid: 'test-admin', email: 'admin@example.invalid', name: 'PESO Administrator',
      email_verified: true, firebase: { sign_in_provider: 'google.com' },
    };
    if (token === 'regular-token') return {
      uid: 'test-user', email: 'user@example.test', name: 'Test User',
      email_verified: true, firebase: { sign_in_provider: 'google.com' },
    };
    if (token === 'unverified-token') return {
      uid: 'unverified-user', email: 'unverified@example.test', name: 'Unverified User',
      email_verified: false, firebase: { sign_in_provider: 'password' },
    };
    throw new Error('Invalid token');
  };
  state.mongoConnected = true;
  state.mongoProblem = null;
  state.db = {
    collection(name) {
      if (name === 'jobPostings') return jobCollection;
      if (name === 'users') return userCollection;
      throw new Error('Unexpected collection: ' + name);
    },
  };
  state.bucket = {};
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = 'http://127.0.0.1:' + server.address().port;
});

after(async () => {
  const closed = new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
  server.closeAllConnections?.();
  await closed;
  state.tokenVerifierOverride = null;
  state.mongoConnected = false;
  state.db = null;
  state.bucket = null;
});

async function request(path, { token, method = 'GET', body } = {}) {
  const headers = { Connection: 'close' };
  if (token) headers.Authorization = 'Bearer ' + token;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  return fetch(baseUrl + path, {
    method,
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

const jobBody = (category, overrides = {}) => ({
  title: 'Office Assistant',
  company: 'Montalban Demo Employer',
  location: 'Rodriguez, Rizal',
  salary: 'PHP 16,000 - 20,000',
  employmentType: 'Full-time',
  description: 'Support day-to-day office operations.',
  requirements: ['Communication', 'Organization'],
  vacancies: 2,
  category,
  ...overrides,
});

test('job routes require sign-in and admin privileges to manage postings', async () => {
  const publicWithoutToken = await request('/api/jobs');
  assert.equal(publicWithoutToken.status, 401);

  const adminWithoutToken = await request('/api/admin/jobs');
  assert.equal(adminWithoutToken.status, 401);

  const regularUser = await request('/api/admin/jobs', { token: 'regular-token' });
  assert.equal(regularUser.status, 403);
  assert.equal((await regularUser.json()).error, 'admin_required');
});

test('unverified accounts cannot access authenticated PESO routes', async () => {
  const response = await request('/api/jobs', { token: 'unverified-token' });
  assert.equal(response.status, 403);
  assert.equal((await response.json()).error, 'email_verification_required');
  assert.equal(userProfiles.has('unverified-user'), false);
});

test('Local Recruitment Activity is persisted with an exact 24-hour expiry and appears in the user feed', async () => {
  const response = await request('/api/admin/jobs', {
    token: 'admin-token',
    method: 'POST',
    body: jobBody('local_recruitment_activity'),
  });
  assert.equal(response.status, 201);
  const payload = await response.json();
  const posted = payload.job;
  assert.equal(posted.category, 'local_recruitment_activity');
  assert.equal(Date.parse(posted.expiresAt) - Date.parse(posted.createdAt), 24 * 60 * 60 * 1000);
  assert.equal(Object.hasOwn(posted, 'createdBy'), false);

  const feedResponse = await request('/api/jobs', { token: 'regular-token' });
  assert.equal(feedResponse.status, 200);
  const feed = await feedResponse.json();
  assert.ok(feed.jobs.some((job) => job.id === posted.id));
});

test('Walk-in Application has no expiration and stays listed until an admin deactivates it', async () => {
  const response = await request('/api/admin/jobs', {
    token: 'admin-token',
    method: 'POST',
    body: jobBody('walk_in_application'),
  });
  assert.equal(response.status, 201);
  const posted = (await response.json()).job;
  assert.equal(posted.expiresAt, null);

  const stored = jobs.get(posted.id);
  stored.createdAt = new Date('2010-01-01T00:00:00.000Z');
  const feedResponse = await request('/api/jobs', { token: 'regular-token' });
  const feed = await feedResponse.json();
  assert.ok(feed.jobs.some((job) => job.id === posted.id));

  const deactivate = await request('/api/admin/jobs/' + posted.id + '/status', {
    token: 'admin-token',
    method: 'PATCH',
    body: { active: false },
  });
  assert.equal(deactivate.status, 200);
  assert.equal((await deactivate.json()).job.status, 'inactive');

  const refreshedFeed = await request('/api/jobs', { token: 'regular-token' });
  assert.ok(!(await refreshedFeed.json()).jobs.some((job) => job.id === posted.id));
});

test('expired LRA is hidden and cannot be reactivated as a fresh listing', async () => {
  const response = await request('/api/admin/jobs', {
    token: 'admin-token',
    method: 'POST',
    body: jobBody('local_recruitment_activity'),
  });
  const posted = (await response.json()).job;
  const stored = jobs.get(posted.id);
  stored.createdAt = new Date(Date.now() - 25 * 60 * 60 * 1000);
  stored.expiresAt = new Date(Date.now() - 60 * 60 * 1000);

  const feedResponse = await request('/api/jobs', { token: 'regular-token' });
  assert.ok(!(await feedResponse.json()).jobs.some((job) => job.id === posted.id));

  const reactivate = await request('/api/admin/jobs/' + posted.id + '/status', {
    token: 'admin-token',
    method: 'PATCH',
    body: { active: true },
  });
  assert.equal(reactivate.status, 409);
  assert.equal((await reactivate.json()).error, 'job_expired');
});

test('job creation rejects unsupported categories and status updates require a boolean', async () => {
  const invalidCategory = await request('/api/admin/jobs', {
    token: 'admin-token',
    method: 'POST',
    body: jobBody('some_other_category'),
  });
  assert.equal(invalidCategory.status, 400);

  const invalidStatus = await request('/api/admin/jobs/507f1f77bcf86cd799439011/status', {
    token: 'admin-token',
    method: 'PATCH',
    body: { active: 'false' },
  });
  assert.equal(invalidStatus.status, 400);
});

test('one provenance-linked notice exposes individual jobs and scores only selected roles', async () => {
  const fingerprint = 'public-pdf-ai:official:notice:jcrcc-p17';
  const doc = { company: 'JCRCC', publicPdfSourceId: 'official',
    sourceUrl: 'https://montalban.gov.ph/official.pdf',
    sourcePageStart: 17, sourcePageEnd: 17, isPublicPdfListing: true,
    category: 'walk_in_application', status: 'active', requirements: [], createdAt: new Date() };
  const noticeId = new ObjectId();
  const roleA = new ObjectId();
  const roleB = new ObjectId();
  const unrelated = new ObjectId();
  const records = [
    { ...doc, _id: noticeId, title: 'NOW HIRING JCRCC',
      aiListingKind: 'notice', sourceFingerprint: fingerprint, sourceRoleCount: 2 },
    { ...doc, _id: roleA, title: 'WELDER - JCRCC', aiListingKind: 'role',
      parentFingerprint: fingerprint, requirementScope: 'unattributed_notice' },
    { ...doc, _id: roleB, title: 'EHS STAFF - JCRCC', aiListingKind: 'role',
      parentFingerprint: fingerprint, requirementScope: 'explicit_role',
      requirements: ['EHS STAFF: Workplace safety'] },
    { ...doc, _id: unrelated, title: 'ANOTHER WELDER - JCRCC', aiListingKind: 'role',
      parentFingerprint: 'other-notice' },
  ];
  for (const record of records) jobs.set(String(record._id), record);
  try {
    const anon = await request('/api/ai/job-match', {
      method: 'POST', body: { noticeId: String(noticeId), jobIds: [String(roleA), String(roleB)] },
    });
    assert.equal(anon.status, 401);
    const feedResponse = await request('/api/jobs', { token: 'regular-token' });
    assert.equal(feedResponse.status, 200);
    const feed = await feedResponse.json();
    const card = feed.jobs.find(job => job.id === String(noticeId));
    assert.deepEqual(card.linkedRoleIds.sort(), [String(roleA), String(roleB)].sort());
    assert.equal(Object.hasOwn(card, 'sourceFingerprint'), false);
    const mismatched = await request('/api/ai/job-match', { token: 'regular-token',
      method: 'POST', body: { noticeId: String(noticeId), jobIds: [String(roleA), String(unrelated)] } });
    assert.equal(mismatched.status, 400);
    assert.equal((await mismatched.json()).error, 'unlinked_or_ineligible_notice_role');
    const matched = await request('/api/ai/job-match', { token: 'regular-token',
      method: 'POST', body: { noticeId: String(noticeId), jobIds: [String(roleA), String(roleB)] } });
    assert.equal(matched.status, 200);
    const payload = await matched.json();
    assert.equal(payload.status, 'ready');
    assert.equal(payload.modelVersion, 'peso-mini-ai-v1');
    assert.deepEqual(new Set(payload.results.map(x => x.jobId)), new Set([String(roleA), String(roleB)]));
    assert.ok(!payload.results.some(x => x.jobId === String(noticeId)));
    assert.ok(!payload.results.some(x => x.jobId === String(unrelated)));
    assert.ok(payload.results.every(x => Array.isArray(x.needsReview)));
    const noticeSingle = await request('/api/ai/job-match', { token: 'regular-token',
      method: 'POST', body: { jobId: String(noticeId) } });
    assert.equal((await noticeSingle.json()).status, 'no_live_jobs');
  } finally {
    for (const record of records) jobs.delete(String(record._id));
  }
});

test('notice matching refuses missing source provenance, expired jobs, and similar employer name alone', async () => {
  const { linkedRolesForNotice } = await import('../src/notice-role-linkage.js');
  const shared = { status: 'active', isPublicPdfListing: true, company: 'Same Employer',
    publicPdfSourceId: 'source', sourceUrl: 'https://montalban.gov.ph/example.pdf',
    sourcePageStart: 4, sourcePageEnd: 4, category: 'walk_in_application' };
  const notice = { ...shared, id: 'n', aiListingKind: 'notice', sourceFingerprint: 'notice-fingerprint' };
  const good = { ...shared, id: 'good', title: 'Welder', aiListingKind: 'role',
    parentFingerprint: 'notice-fingerprint' };
  assert.deepEqual(linkedRolesForNotice(notice, [good]).map(x => x.id), ['good']);
  assert.deepEqual(linkedRolesForNotice({ ...notice, sourceFingerprint: '' }, [good]), []);
  assert.deepEqual(linkedRolesForNotice(notice, [
    { ...good, id: 'other-parent', parentFingerprint: 'other-fingerprint' },
    { ...good, id: 'other-document', sourceUrl: 'https://montalban.gov.ph/other.pdf' },
    { ...good, id: 'other-company', company: 'Same Employer 2' },
    { ...good, id: 'expired', category: 'local_recruitment_activity',
      expiresAt: new Date('2020-01-01') },
    { ...good, id: 'synthetic', isSynthetic: true },
    { ...good, id: 'inactive', status: 'inactive' },
  ]), []);
});
