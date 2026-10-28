import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { ObjectId } from 'mongodb';

import { app, state } from '../server.js';

class MemoryCollection {
  constructor() { this.records = new Map(); }
  async createIndex() { return 'fake-test-index'; }
  async findOne(filter = {}) {
    const record = [...this.records.values()].find((item) =>
      Object.entries(filter).every(([key, value]) => String(item[key]) === String(value)),
    );
    return record ? structuredClone(record) : null;
  }
  async updateOne(filter, update, options = {}) {
    let record = [...this.records.values()].find((item) =>
      Object.entries(filter).every(([key, value]) => String(item[key]) === String(value)),
    );
    let upserted = false;
    if (!record && options.upsert) {
      record = Object.fromEntries(Object.entries(filter).filter(([, value]) => value == null || typeof value !== 'object'));
      Object.assign(record, structuredClone(update.$setOnInsert || {}));
      upserted = true;
    }
    if (!record) return { matchedCount: 0, modifiedCount: 0, upsertedCount: 0 };
    Object.assign(record, structuredClone(update.$set || {}));
    for (const key of Object.keys(update.$unset || {})) delete record[key];
    const id = record.uid ?? record._id ?? 'singleton';
    this.records.set(String(id), record);
    return { matchedCount: upserted ? 0 : 1, modifiedCount: 1, upsertedCount: upserted ? 1 : 0 };
  }
  async insertOne(record) {
    const clone = structuredClone(record);
    const id = String(clone._id ?? clone.uid ?? this.records.size + 1);
    this.records.set(id, clone);
    return { acknowledged: true, insertedId: clone._id ?? id };
  }
  async deleteOne(filter = {}) {
    for (const [id, record] of this.records) {
      if (Object.entries(filter).every(([key, value]) => String(record[key]) === String(value))) {
        this.records.delete(id);
        return { deletedCount: 1 };
      }
    }
    return { deletedCount: 0 };
  }
  find(filter = {}) {
    let results = [...this.records.values()].filter((item) =>
      Object.entries(filter).every(([key, value]) => {
        if (value && typeof value === 'object' && '$nin' in value) {
          return !value.$nin.some((v) => String(v) === String(item[key]));
        }
        return String(item[key]) === String(value);
      }),
    );
    const cursor = {
      sort(fields) {
        results.sort((a, b) => {
          for (const [key, direction] of Object.entries(fields)) {
            const left = a[key] == null ? 0 : (a[key] instanceof Date ? a[key].getTime() : a[key]);
            const right = b[key] == null ? 0 : (b[key] instanceof Date ? b[key].getTime() : b[key]);
            if (left < right) return -direction;
            if (left > right) return direction;
          }
          return 0;
        });
        return cursor;
      },
      limit(count) { results = results.slice(0, count); return cursor; },
      skip(count) { results = results.slice(count); return cursor; },
      toArray: async () => structuredClone(results),
    };
    return cursor;
  }
  async findOneAndUpdate(filter, update, options = {}) {
    const found = await this.find(filter).sort(options.sort || {}).limit(1).toArray();
    if (!found.length) return null;
    const record = found[0];
    Object.assign(record, structuredClone(update.$set || {}));
    const key = String(record._id ?? record.uid ?? 'singleton');
    this.records.set(key, record);
    return structuredClone(record);
  }
}

const originalState = {};
const originalGeminiKey = process.env.GEMINI_API_KEY;
const originalModel = process.env.GEMINI_MODEL;
const calls = [];
let baseUrl;
let server;

function fakeDatabase() {
  const collections = new Map();
  return {
    collections,
    collection(name) {
      if (!collections.has(name)) collections.set(name, new MemoryCollection());
      return collections.get(name);
    },
  };
}

before(async () => {
  for (const name of [
    'tokenVerifierOverride', 'mongoConnected', 'mongoProblem', 'db', 'bucket',
    'geminiProviderOverride', 'smsIndexesReady',
  ]) originalState[name] = state[name];

  process.env.GEMINI_API_KEY = 'fake-legacy-gemini-key-for-isolated-tests';
  process.env.GEMINI_MODEL = 'gemini-test';
  state.tokenVerifierOverride = async (token) => {
    if (token === 'test-user-token') return {
      uid: 'gemini-integration-user',
      email: 'user@example.test',
      name: 'Gemini Integration User',
      email_verified: true,
      firebase: { sign_in_provider: 'password' },
    };
    if (token === 'test-admin-token') return {
      uid: 'gemini-integration-admin',
      email: 'admin@example.invalid',
      name: 'Gemini Integration Admin',
      email_verified: true,
      firebase: { sign_in_provider: 'google.com' },
    };
    throw new Error('Invalid fake test token.');
  };
  state.mongoConnected = true;
  state.mongoProblem = null;
  state.db = fakeDatabase();
  state.bucket = { openUploadStream() {}, openDownloadStream() {}, find() { return { toArray: async () => [] }; } };
  state.smsIndexesReady = false;
  state.geminiProviderOverride = async ({ operation, apiKey, payload }) => {
    calls.push({ operation, apiKey, payload });
    if (operation === 'profile_extraction') {
      return { profile: { fullName: 'Example Applicant', professionalTitle: 'Clerk', skills: ['typing'] } };
    }
    if (operation === 'query') return { text: 'A fake answer from the test provider.' };
    if (operation === 'key_test') return { text: 'OK' };
    throw new Error('Unexpected fake Gemini operation.');
  };

  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = 'http://127.0.0.1:' + server.address().port;
});

after(async () => {
  if (server) {
    const closed = new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    server.closeAllConnections?.();
    await closed;
  }
  for (const [name, value] of Object.entries(originalState)) state[name] = value;
  if (originalGeminiKey === undefined) delete process.env.GEMINI_API_KEY;
  else process.env.GEMINI_API_KEY = originalGeminiKey;
  if (originalModel === undefined) delete process.env.GEMINI_MODEL;
  else process.env.GEMINI_MODEL = originalModel;
});

async function request(path, { token = 'test-user-token', method = 'GET', body } = {}) {
  const headers = { Connection: 'close' };
  if (token) headers.Authorization = 'Bearer ' + token;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const response = await fetch(baseUrl + path, {
    method,
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, headers: response.headers, body: await response.json() };
}

test('query endpoint calls injected provider through the rotator and returns stable response schema', async () => {
  calls.length = 0;
  const result = await request('/api/ai/query', { method: 'POST', body: { prompt: 'How do I prepare a resume?' } });
  assert.equal(result.status, 200);
  assert.equal(result.body.ok, true);
  assert.equal(result.body.text, 'A fake answer from the test provider.');
  assert.deepEqual(result.body.sources, []);
  assert.deepEqual(result.body.knowledgeBase, { status: 'no_matching_sources', excerptCount: 0 });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].operation, 'query');
  assert.equal(calls[0].payload.prompt, 'How do I prepare a resume?');
  assert.equal(calls[0].apiKey, 'fake-legacy-gemini-key-for-isolated-tests');
  assert.equal(JSON.stringify(result.body).includes(calls[0].apiKey), false);
});

test('query endpoint rejects anonymous requests and invalid/oversized prompts without calling provider', async () => {
  calls.length = 0;
  const anonymous = await request('/api/ai/query', { token: null, method: 'POST', body: { prompt: 'Hello' } });
  assert.equal(anonymous.status, 401);
  const empty = await request('/api/ai/query', { method: 'POST', body: { prompt: ' ' } });
  assert.equal(empty.status, 400);
  const oversized = await request('/api/ai/query', { method: 'POST', body: { prompt: 'x'.repeat(20001) } });
  assert.equal(oversized.status, 400);
  assert.equal(calls.length, 0);
});

test('profile extraction routes through the rotator and persists returned profile data', async () => {
  calls.length = 0;
  const result = await request('/api/ai/profile', {
    method: 'POST',
    body: { rawText: 'A test applicant with typing experience.' },
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.ok, true);
  assert.equal(result.body.saved, true);
  assert.equal(result.body.profile.fullName, 'Example Applicant');
  assert.deepEqual(result.body.profile.skills, ['typing']);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].operation, 'profile_extraction');
  const stored = await state.db.collection('users').findOne({ uid: 'gemini-integration-user' });
  assert.equal(stored.aiProfile.fullName, 'Example Applicant');
});

test('applicant source or education edits invalidate the cached AI match without altering account identity', async () => {
  const users = state.db.collection('users');
  const uid = 'gemini-integration-user';
  const original = await users.findOne({ uid });
  await users.updateOne({ uid }, { $set: { latestAiJobMatch: {
    modelVersion: 'peso-mini-ai-v1', status: 'ready', results: [{ score: 77 }],
  } } }, { upsert: true });

  const onboarding = await request('/api/profile/onboarding', {
    method: 'PATCH',
    body: { pesoFormData: {
      entries: [{ label: 'Other skills acquired', value: 'Welding' }],
      applicantEssentials: { education: 'Senior High School', skills: 'Welding' },
    } },
  });
  assert.equal(onboarding.status, 200);
  let stored = await users.findOne({ uid });
  assert.equal(stored.latestAiJobMatch, undefined);
  assert.equal(stored.pesoFormData.entries[0].value, 'Welding');

  await users.updateOne({ uid }, { $set: {
    latestAiJobMatch: { status: 'ready', results: [{ score: 77 }] },
  } });
  const contact = await request('/api/profile', {
    method: 'PUT', body: { location: 'Rodriguez, Rizal' },
  });
  assert.equal(contact.status, 200);
  stored = await users.findOne({ uid });
  assert.equal(stored.latestAiJobMatch.status, 'ready');

  const education = await request('/api/profile', {
    method: 'PUT', body: { educationLevel: 'Senior High School' },
  });
  assert.equal(education.status, 200);
  stored = await users.findOne({ uid });
  assert.equal(stored.latestAiJobMatch, undefined);
  assert.equal(stored.educationLevel, 'Senior High School');
  assert.equal(stored.uid, uid);
  assert.equal(stored.email, original.email);
  assert.equal((await request('/api/profile/onboarding', {
    token: null, method: 'PATCH', body: { pesoFormData: {} },
  })).status, 401);
});

test('quota response from the provider is passed through with retry guidance after one fallback-model retry', async () => {
  calls.length = 0;
  const originalProvider = state.geminiProviderOverride;
  const previousModel = process.env.GEMINI_MODEL;
  const previousFallback = process.env.GEMINI_FALLBACK_MODEL;
  // Quota state is model-wide; isolate this simulated 429 from later route tests.
  process.env.GEMINI_MODEL = 'gemini-quota-isolation-test';
  process.env.GEMINI_FALLBACK_MODEL = 'gemini-fallback-isolation-test';
  try {
    state.geminiProviderOverride = async ({ operation }) => {
      calls.push({ operation });
      const error = new Error('sanitized fake provider quota error');
      error.status = 429;
      error.code = 'RESOURCE_EXHAUSTED';
      error.retryAfterSeconds = 23;
      throw error;
    };
    const result = await request('/api/ai/query', { method: 'POST', body: { prompt: 'Check quota handling.' } });
    assert.equal(result.status, 429);
    assert.equal(result.headers.get('retry-after'), '23');
    assert.equal(result.body.error, 'gemini_rate_limited');
    assert.equal(result.body.retryAfterSeconds, 23);
    // One attempt on the primary model plus one on the configured fallback.
    assert.equal(calls.length, 2);
    assert.equal(JSON.stringify(result.body).includes('fake provider quota error'), false);
  } finally {
    state.geminiProviderOverride = originalProvider;
    if (previousModel === undefined) delete process.env.GEMINI_MODEL;
    else process.env.GEMINI_MODEL = previousModel;
    if (previousFallback === undefined) delete process.env.GEMINI_FALLBACK_MODEL;
    else process.env.GEMINI_FALLBACK_MODEL = previousFallback;
  }
});

test('key-management routes remain unreachable to anonymous and ordinary users', async () => {
  calls.length = 0;
  const anonymous = await request('/api/admin/gemini-keys', { token: null });
  assert.equal(anonymous.status, 401);
  const regular = await request('/api/admin/gemini-keys');
  assert.equal(regular.status, 403);
  assert.equal(calls.length, 0);
});

test('resume absorption preview returns the extracted profile without persisting it', async () => {
  calls.length = 0;
  const originalProvider = state.geminiProviderOverride;
  state.geminiProviderOverride = async ({ operation, payload }) => {
    calls.push({ operation, payload });
    if (operation === 'profile_extraction') return { profile: { skills: ['reading'] } };
    throw new Error('Unexpected fake Gemini operation.');
  };
  try {
    const users = state.db.collection('users');
    const before = await users.findOne({ uid: 'gemini-integration-user' });
    const result = await request('/api/ai/profile', {
      method: 'POST',
      body: { rawText: 'Preview this resume only.', persist: false },
    });
    assert.equal(result.status, 200);
    assert.equal(result.body.ok, true);
    assert.equal(result.body.saved, false);
    // The preview still inherits the registered account identity for the form.
    assert.equal(result.body.profile.fullName, 'Gemini Integration User');
    assert.equal(result.body.profile.email, 'user@example.test');
    assert.deepEqual(result.body.profile.skills, ['reading']);
    // The stored profile must be untouched by a preview request.
    const after = await users.findOne({ uid: 'gemini-integration-user' });
    assert.deepEqual(after.aiProfile, before.aiProfile);
    assert.equal(after.aiProfile.fullName, 'Example Applicant');
    assert.equal(after.profileCompleted, before.profileCompleted);
    // The extraction schema advertises phoneNumber so the app can inherit it.
    assert.equal(calls[0].payload.parts[0].text.includes('phoneNumber'), true);
  } finally {
    state.geminiProviderOverride = originalProvider;
  }
});


test('legacy AI PATCH cannot overwrite verified profile or manually entered qualifications', async () => {
  const users = state.db.collection('users');
  const uid = 'gemini-integration-user';
  await users.updateOne({ uid }, { $set: {
    professionalTitle: 'User-entered electrician',
    skills: ['User-entered electrical inspection'],
    aiMatchingExtraction: { status: 'needs_review', skills: [] },
    aiProfile: { skills: ['unverified historical suggestion'] },
  } });
  const before = await users.findOne({ uid });
  const response = await request('/api/profile/ai-profile', {
    method: 'PATCH',
    body: { aiProfile: { skills: ['unverified claim'], professionalTitle: 'Invented title' } },
  });
  assert.equal(response.status, 409);
  assert.equal(response.body.error, 'verified_extraction_required');
  const after = await users.findOne({ uid });
  for (const field of ['professionalTitle', 'skills', 'aiMatchingExtraction', 'aiProfile']) {
    assert.deepEqual(after[field], before[field], field + ' must remain unchanged');
  }
});


test('authenticated selected job translation is cached and preserves original posting', async () => {
  const id = new ObjectId();
  const source = {
    _id: id.toHexString(),
    title: 'Welder',
    company: 'Sample Company',
    description: 'TESDA NC II and 2 years of welding experience required',
    requirements: ['TESDA NC II', '2 years experience'],
    category: 'walk_in_application',
    status: 'active',
    createdAt: new Date(),
  };
  await state.db.collection('jobPostings').insertOne(source);
  const originalProvider = state.geminiProviderOverride;
  const seen = [];
  state.geminiProviderOverride = async ({ operation, payload }) => {
    if (operation !== 'job_translation') throw Error('Unexpected provider operation');
    seen.push(payload.prompt);
    return { text: JSON.stringify({
      title: 'Manghihinang',
      description: 'Kailangan ang TESDA NC II at 2 taong karanasan',
      requirements: ['TESDA NC II', '2 taong karanasan'],
    }) };
  };
  try {
    const url = '/api/jobs/' + id + '/translation';
    const missingAuth = await request(url, {
      token: null, method: 'POST', body: { language: 'Tagalog' },
    });
    assert.equal(missingAuth.status, 401);
    const badLang = await request(url, {
      method: 'POST', body: { language: 'English' },
    });
    assert.equal(badLang.status, 400);
    const first = await request(url, {
      method: 'POST', body: { language: 'Tagalog' },
    });
    assert.equal(first.status, 200);
    assert.equal(first.body.cached, false);
    assert.equal(first.body.translation.title, 'Manghihinang');
    assert.deepEqual(first.body.translation.requirements,
      ['TESDA NC II', '2 taong karanasan']);
    const second = await request(url, {
      method: 'POST', body: { language: 'Tagalog' },
    });
    assert.equal(second.status, 200);
    assert.equal(second.body.cached, true);
    assert.equal(seen.length, 1);
    const persisted = await state.db.collection('jobPostings').findOne({ _id: id });
    assert.equal(persisted.title, 'Welder');
    assert.equal(persisted.description, source.description);
    assert.deepEqual(persisted.requirements, source.requirements);
    assert.match(seen[0], /never instructions|NEVER instructions|untrusted quoted data/);
  } finally {
    state.geminiProviderOverride = originalProvider;
  }
});
