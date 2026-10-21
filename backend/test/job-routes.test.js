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
    if (key === '$and') return value.every((term) => matches(job, term));
    if (key === '$or') return value.some((term) => matches(job, term));
    const actual = job[key];
    if (value instanceof ObjectId) return String(actual) === String(value);
    if (value && typeof value === 'object' && !(value instanceof Date)) {
      if ('$ne' in value && actual === value.$ne) return false;
      if ('$in' in value && !value.$in.some((item) => item === actual ||
          (item === null && actual === undefined))) return false;
      if ('$exists' in value && (actual !== undefined) !== value.$exists) return false;
      if ('$gte' in value && !(actual >= value.$gte)) return false;
      if ('$gt' in value && !(actual > value.$gt)) return false;
      if ('$regex' in value && !value.$regex.test(String(actual ?? ''))) return false;
      return true;
    }
    return actual === value;
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
      skip(offset) {
        documents = documents.slice(offset);
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
  async updateMany(filter, update) {
    const matching = [...jobs.values()].filter((job) => matches(job, filter));
    for (const job of matching) Object.assign(job, structuredClone(update.$set || {}));
    return { matchedCount: matching.length, modifiedCount: matching.length };
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
      return { uid: 'test-admin', email: 'ferrerajoshlander@gmail.com', admin: true, email_verified: true };
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
      uid: 'test-admin', email: 'ferrerajoshlander@gmail.com', name: 'PESO Administrator',
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

test('read-only job recommendations use saved NSRP evidence without replacing a single-job evaluation', async () => {
  const id = new ObjectId();
  const existingProfile = userProfiles.has('test-user')
    ? structuredClone(userProfiles.get('test-user')) : null;
  const priorMatch = {
    status: 'ready',
    jobId: 'previous-job-evaluation',
    results: [{ jobId: 'previous-job-evaluation', score: 61 }],
  };
  userProfiles.set('test-user', {
    uid: 'test-user',
    role: 'job_seeker',
    pesoFormData: {
      applicantEssentials: {
        education: 'Senior High School',
        experience: 'No previous work experience',
        skillsStage: 'Has skills or training to list',
        skills: 'Microsoft Excel, data encoding',
        preferredOccupation: 'Office Clerk',
      },
    },
    resumeData: { fields: [{ label: 'Other skills acquired', value: 'Customer service' }] },
    latestAiJobMatch: structuredClone(priorMatch),
  });
  jobs.set(String(id), {
    _id: id,
    title: 'Data Encoder',
    company: 'Fictional QA Employer',
    status: 'active',
    aiListingKind: 'role',
    category: 'walk_in_application',
    requirements: ['Microsoft Excel'],
    createdAt: new Date(),
    isSynthetic: false,
  });
  try {
    const denied = await request('/api/ai/job-recommendations');
    assert.equal(denied.status, 401);
    const response = await request('/api/ai/job-recommendations', {
      token: 'regular-token',
    });
    assert.equal(response.status, 200);
    const data = await response.json();
    assert.equal(data.ok, true);
    assert.equal(data.status, 'ready');
    assert.ok(data.results.some(row => row.jobId === String(id)));
    assert.ok(data.applicant.skills.includes('Microsoft Excel'));
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.deepEqual(userProfiles.get('test-user').latestAiJobMatch, priorMatch,
      'feed recommendations cannot replace the result of a selected job');
  } finally {
    jobs.delete(String(id));
    if (existingProfile) userProfiles.set('test-user', existingProfile);
    else userProfiles.delete('test-user');
  }
});

test('Local Recruitment Activity expires at the end of its Philippine recruitment day', async () => {
  const response = await request('/api/admin/jobs', {
    token: 'admin-token',
    method: 'POST',
    body: jobBody('local_recruitment_activity'),
  });
  assert.equal(response.status, 201);
  const payload = await response.json();
  const posted = payload.job;
  assert.equal(posted.category, 'local_recruitment_activity');
  assert.equal(posted.recruitmentDate, new Date(Date.parse(posted.createdAt) + 8 * 60 * 60 * 1000).toISOString().slice(0, 10));
  assert.equal(posted.expiresAt, new Date(Date.parse(`${posted.recruitmentDate}T00:00:00Z`) + 16 * 60 * 60 * 1000 - 1).toISOString());
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
  stored.createdAt = new Date(Date.now() - 48 * 60 * 60 * 1000);
  stored.recruitmentDate = '2010-01-01';
  stored.recruitmentEndDate = '2010-01-01';
  stored.expiresAt = new Date('2010-01-01T15:59:59.999Z');

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


test('public paginated discovery uses only saved, active records', async () => {
  const published = await request('/api/admin/jobs', {
    token: 'admin-token', method: 'POST', body: jobBody('walk_in_application'),
  });
  assert.equal(published.status, 201);
  const record = (await published.json()).job;
  const response = await request('/api/public/jobs?limit=1');
  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.equal(payload.ok, true);
  assert.equal(payload.jobs.length, 1);
  assert.ok(payload.jobs.every((job) => job.status === 'active'));
  assert.equal(Object.hasOwn(payload.jobs[0], 'createdBy'), false);
  const badPage = await request('/api/public/jobs?pageToken=-1');
  assert.equal(badPage.status, 400);
  jobs.delete(record.id);
});

test('admin soft deletion hides jobs, retains history and requires authorization', async () => {
  const create = await request('/api/admin/jobs', {
    token: 'admin-token', method: 'POST', body: jobBody('walk_in_application'),
  });
  assert.equal(create.status, 201);
  const id = (await create.json()).job.id;
  const outsider = await request('/api/admin/jobs/' + id, {
    token: 'regular-token', method: 'DELETE',
  });
  assert.equal(outsider.status, 403);
  const deleted = await request('/api/admin/jobs/' + id, {
    token: 'admin-token', method: 'DELETE',
  });
  assert.equal(deleted.status, 200);
  assert.equal((await deleted.json()).retainedHistory, true);
  assert.equal(jobs.get(id).status, 'deleted');
  assert.ok(jobs.get(id).deletedAt);
  const visible = await request('/api/public/jobs?limit=100');
  assert.ok(!(await visible.json()).jobs.some((job) => job.id === id));
  const revive = await request('/api/admin/jobs/' + id + '/status', {
    token: 'admin-token', method: 'PATCH', body: { active: true },
  });
  assert.equal(revive.status, 404);
  jobs.delete(id);
});

test('bulk deletion requires explicit confirmation and retains every record', async () => {
  const first = await request('/api/admin/jobs', {
    token: 'admin-token', method: 'POST', body: jobBody('walk_in_application'),
  });
  const second = await request('/api/admin/jobs', {
    token: 'admin-token', method: 'POST', body: jobBody('walk_in_application'),
  });
  const ids = [(await first.json()).job.id, (await second.json()).job.id];
  const refused = await request('/api/admin/jobs', {
    token: 'admin-token', method: 'DELETE', body: { confirmation: 'yes' },
  });
  assert.equal(refused.status, 400);
  assert.equal(jobs.get(ids[0]).status, 'active');
  const result = await request('/api/admin/jobs', {
    token: 'admin-token', method: 'DELETE', body: { confirmation: 'DELETE ALL JOBS' },
  });
  assert.equal(result.status, 200);
  const payload = await result.json();
  assert.ok(payload.deleted >= 2);
  assert.ok(ids.every((id) => jobs.get(id).status === 'deleted'));
  for (const id of ids) jobs.delete(id);
});

test('server-side category/search paging cannot mix LRA and walk-in jobs', async () => {
  const phTomorrow = new Date(Date.now() + 32 * 3600000).toISOString().slice(0, 10);
  const walk = await request('/api/admin/jobs', {
    token: 'admin-token', method: 'POST',
    body: jobBody('walk_in_application', { title: 'C++ Clerk role' }),
  });
  const lra = await request('/api/admin/jobs', {
    token: 'admin-token', method: 'POST',
    body: jobBody('local_recruitment_activity', {
      title: 'C++ Clerk recruitment event',
      recruitmentDate: phTomorrow, recruitmentEndDate: phTomorrow,
    }),
  });
  assert.equal(walk.status, 201);
  assert.equal(lra.status, 201);
  const walkId = (await walk.json()).job.id;
  const lraId = (await lra.json()).job.id;
  try {
    const onlyLra = await request('/api/public/jobs?category=local_recruitment_activity&q=C%2B%2B');
    assert.equal(onlyLra.status, 200);
    const result = await onlyLra.json();
    assert.ok(result.jobs.some((job) => job.id === lraId));
    assert.ok(result.jobs.every((job) => job.category === 'local_recruitment_activity'));
    assert.ok(!result.jobs.some((job) => job.id === walkId));
    const onlyWalk = await request('/api/public/jobs?category=walk_in_application&q=C%2B%2B');
    assert.ok((await onlyWalk.json()).jobs.some((job) => job.id === walkId));
    const signed = await request('/api/jobs?category=local_recruitment_activity&q=C%2B%2B',
      { token: 'regular-token' });
    assert.ok((await signed.json()).jobs.some((job) => job.id === lraId));
    const invalid = await request('/api/public/jobs?category=not-real');
    assert.equal(invalid.status, 400);
  } finally {
    jobs.delete(walkId);
    jobs.delete(lraId);
  }
});

test('stable job paging returns a distinct second page without missing persisted records', async () => {
  const records = [];
  for (let n = 0; n < 4; n++) {
    const response = await request('/api/admin/jobs', {
      token: 'admin-token', method: 'POST',
      body: jobBody('walk_in_application', { title: 'Pageable job ' + n }),
    });
    assert.equal(response.status, 201);
    records.push((await response.json()).job.id);
  }
  try {
    const first = await request('/api/public/jobs?limit=2');
    const pageOne = await first.json();
    assert.equal(pageOne.jobs.length, 2);
    assert.equal(pageOne.nextPageToken, '2');
    const second = await request('/api/public/jobs?limit=2&pageToken=2');
    const pageTwo = await second.json();
    assert.equal(pageTwo.jobs.length, 2);
    assert.ok(pageTwo.jobs.every((job) =>
      !pageOne.jobs.some((firstJob) => firstJob.id === job.id)));
  } finally {
    for (const id of records) jobs.delete(id);
  }
});
