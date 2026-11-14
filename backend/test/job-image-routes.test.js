import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { Readable, Writable } from 'node:stream';
import { ObjectId } from 'mongodb';
import { app, state } from '../server.js';

const users = new Map([
  ['admin-uid', {
    uid: 'admin-uid',
    email: 'admin@example.test',
    role: 'admin',
    disabled: false,
    deleted: false,
  }],
]);
const jobs = [];
const imageFiles = new Map();

const usersCollection = {
  async findOne({ uid }) {
    return users.has(uid) ? structuredClone(users.get(uid)) : null;
  },
  async updateOne({ uid }, update) {
    const user = users.get(uid);
    if (user && update.$set) Object.assign(user, structuredClone(update.$set));
    return { matchedCount: user ? 1 : 0 };
  },
};

const jobsCollection = {
  async findOne(filter = {}) {
    return jobs.find((job) => {
      if (filter.status && job.status !== filter.status) return false;
      if (!Array.isArray(filter.$or)) return false;
      return filter.$or.some((condition) => {
        const [field, matcher] = Object.entries(condition)[0] || [];
        if (!field || matcher?.$regex === undefined) return false;
        const pattern = matcher.$regex instanceof RegExp
          ? matcher.$regex
          : new RegExp(String(matcher.$regex));
        return pattern.test(String(job[field] || ''));
      });
    }) || null;
  },
};

const filesCollection = {
  async findOne(filter = {}) {
    const file = imageFiles.get(String(filter._id));
    if (!file) return null;
    if (filter['metadata.category'] &&
        file.metadata.category !== filter['metadata.category']) return null;
    return {
      _id: file._id,
      filename: file.filename,
      contentType: file.contentType,
      metadata: file.metadata,
    };
  },
};

const bucket = {
  openUploadStream(filename, options) {
    const id = new ObjectId();
    const chunks = [];
    const stream = new Writable({
      write(chunk, _encoding, callback) {
        chunks.push(Buffer.from(chunk));
        callback();
      },
      final(callback) {
        imageFiles.set(String(id), {
          _id: id,
          filename,
          contentType: options.contentType,
          metadata: options.metadata,
          bytes: Buffer.concat(chunks),
        });
        callback();
      },
    });
    stream.id = id;
    return stream;
  },
  openDownloadStream(id) {
    const file = imageFiles.get(String(id));
    return Readable.from(file ? [file.bytes] : []);
  },
  async delete(id) {
    imageFiles.delete(String(id));
  },
};

let server;
let baseUrl;

before(async () => {
  jobs.length = 0;
  imageFiles.clear();
  state.tokenVerifierOverride = async (token) => {
    if (token !== 'admin-token') throw new Error('Invalid test token');
    return {
      uid: 'admin-uid',
      email: 'admin@example.test',
      name: 'Test Administrator',
      email_verified: true,
      firebase: { sign_in_provider: 'google.com' },
    };
  };
  state.mongoConnected = true;
  state.mongoProblem = null;
  state.db = {
    collection(name) {
      if (name === 'users') return usersCollection;
      if (name === 'jobPostings') return jobsCollection;
      if (name === 'profileArtifacts.files') return filesCollection;
      throw new Error('Unexpected collection: ' + name);
    },
  };
  state.bucket = bucket;
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = 'http://127.0.0.1:' + server.address().port;
});

after(async () => {
  if (server) {
    const closed = new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
    server.closeAllConnections?.();
    await closed;
  }
  state.tokenVerifierOverride = null;
  state.mongoConnected = false;
  state.db = null;
  state.bucket = null;
});

async function request(path, { token = 'admin-token', method = 'GET', body, headers = {} } = {}) {
  const requestHeaders = { Connection: 'close', ...headers };
  if (token) requestHeaders.Authorization = 'Bearer ' + token;
  if (body !== undefined) requestHeaders['Content-Type'] = 'application/json';
  return fetch(baseUrl + path, {
    method,
    headers: requestHeaders,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

const pngBytes = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

test('job images require an administrator and validate MIME, size, and file signature', async () => {
  const denied = await request('/api/admin/job-images', {
    token: null,
    method: 'POST',
    body: {
      fileName: 'job.png',
      mimeType: 'image/png',
      base64: pngBytes.toString('base64'),
    },
  });
  assert.equal(denied.status, 401);

  const wrongType = await request('/api/admin/job-images', {
    method: 'POST',
    body: {
      fileName: 'job.svg',
      mimeType: 'image/svg+xml',
      base64: Buffer.from('<svg/>').toString('base64'),
    },
  });
  assert.equal(wrongType.status, 415);

  const wrongSignature = await request('/api/admin/job-images', {
    method: 'POST',
    body: {
      fileName: 'job.png',
      mimeType: 'image/png',
      base64: Buffer.from('not a png').toString('base64'),
    },
  });
  assert.equal(wrongSignature.status, 415);
});

test('uploaded image stays private until linked to a visible job, then streams safely', async () => {
  const uploaded = await request('/api/admin/job-images', {
    method: 'POST',
    headers: { 'x-forwarded-proto': 'http' },
    body: {
      fileName: 'employer-logo.png',
      mimeType: 'image/png',
      base64: pngBytes.toString('base64'),
    },
  });
  assert.equal(uploaded.status, 201);
  const payload = await uploaded.json();
  assert.equal(payload.ok, true);
  assert.match(payload.imageUrl, /^http:\/\/127\.0\.0\.1:/);
  const id = payload.imageUrl.split('/').at(-1);
  const stored = imageFiles.get(id);
  assert.ok(stored);
  assert.equal(stored.metadata.category, 'job_listing_image');
  assert.equal(stored.metadata.uploadedByUid, 'admin-uid');

  const privateResponse = await request('/api/public/job-images/' + id);
  assert.equal(privateResponse.status, 404);

  jobs.push({
    status: 'active',
    category: 'walk_in_application',
    imageUrl: payload.imageUrl,
    logoUrl: '',
  });
  const publicResponse = await request('/api/public/job-images/' + id);
  assert.equal(publicResponse.status, 200);
  assert.equal(publicResponse.headers.get('content-type'), 'image/png');
  assert.match(publicResponse.headers.get('cache-control') || '', /public/);
  assert.deepEqual(Buffer.from(await publicResponse.arrayBuffer()), pngBytes);

  jobs[0].status = 'deleted';
  const deletedJobImage = await request('/api/public/job-images/' + id);
  assert.equal(deletedJobImage.status, 404);
});
