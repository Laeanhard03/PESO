import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { Readable, Writable } from 'node:stream';
import { ObjectId } from 'mongodb';
import { app, state } from '../server.js';

const fileId = new ObjectId();
const pdf = Buffer.from('%PDF-1.7\\nPESO private PDF bytes');
let server;
let origin;

before(async () => {
  state.mongoConnected = true;
  state.db = {
    collection(name) {
      if (name === 'users') {
        return { async findOne({ uid }) { return {
          uid, role: 'job_seeker', deleted: false, disabled: false,
        }; } };
      }
      if (name === 'profileArtifacts.files') {
        return { async findOne(query) {
          if (String(query._id) !== String(fileId) ||
              query['metadata.ownerUid'] !== 'owner') return null;
          return { _id: fileId, filename: 'my-resume.pdf', length: pdf.length,
            metadata: { ownerUid: 'owner', mimeType: 'application/pdf',
              originalFileName: 'my-resume.pdf' } };
        } };
      }
      throw new Error('Unexpected collection ' + name);
    },
  };
  state.bucket = {
    openDownloadStream(id) {
      assert.equal(String(id), String(fileId));
      return Readable.from([pdf]);
    },
  };
  state.tokenVerifierOverride = async (token) => {
    if (!['owner-token', 'other-token'].includes(token)) throw new Error('bad');
    return { uid: token === 'owner-token' ? 'owner' : 'other',
      email: 'applicant@example.test', email_verified: true,
      firebase: { sign_in_provider: 'password' },
    };
  };
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  origin = 'http://127.0.0.1:' + server.address().port;
});

after(async () => {
  server.closeAllConnections?.();
  await new Promise((resolve, reject) =>
    server.close(error => error ? reject(error) : resolve()));
  state.tokenVerifierOverride = null;
  state.mongoConnected = false;
  state.db = null;
  state.bucket = null;
});

test('private PDF preview requires owner bearer and returns exact bytes', async () => {
  const path = '/api/artifacts/' + fileId + '/content';
  assert.equal((await fetch(origin + path)).status, 401);
  assert.equal((await fetch(origin + path,
    { headers: { Authorization: 'Bearer other-token' } })).status, 404);
  assert.equal((await fetch(origin + '/api/artifacts/not-an-id/content',
    { headers: { Authorization: 'Bearer owner-token' } })).status, 404);
  const result = await fetch(origin + path, { headers: {
    Authorization: 'Bearer owner-token',
    Origin: 'http://localhost:63041',
  } });
  assert.equal(result.status, 200);
  assert.ok(result.headers.get('content-type')?.startsWith('application/pdf'));
  assert.match(result.headers.get('content-disposition'), /^inline/);
  assert.match(result.headers.get('cache-control'), /no-store/);
  assert.equal(result.headers.get('access-control-allow-origin'), 'http://localhost:63041');
  assert.deepEqual(Buffer.from(await result.arrayBuffer()), pdf);
});


test('owner can upload a private PNG avatar and other users cannot read it', async () => {
  const priorDb = state.db;
  const priorBucket = state.bucket;
  const photoId = new ObjectId();
  const png = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+9hHsAAAAASUVORK5CYII=',
    'base64',
  );
  const profile = { uid: 'owner', role: 'job_seeker',
    deleted: false, disabled: false, avatarStyle: 'person' };
  let file;
  state.db = { collection(name) {
    if (name === 'users') return {
      async findOne({ uid }) {
        return uid === 'owner' ? { ...profile } : null;
      },
      async updateOne({ uid }, update) {
        if (uid !== 'owner') return { matchedCount: 0 };
        Object.assign(profile, update.$set || {});
        return { matchedCount: 1 };
      },
    };
    if (name === 'profileArtifacts.files') return {
      async findOne(query) {
        if (!file || String(query._id) !== String(photoId)) return null;
        if (query['metadata.ownerUid'] &&
          query['metadata.ownerUid'] !== file.metadata.ownerUid) return null;
        return file;
      },
    };
    throw Error('Unexpected collection: ' + name);
  }};
  state.bucket = {
    openUploadStream(filename, config) {
      const writer = new Writable({
        write(_chunk, _encoding, callback) { callback(); },
      });
      writer.id = photoId;
      file = {
        _id: photoId, filename,
        length: png.length, uploadDate: new Date(),
        metadata: config.metadata,
      };
      return writer;
    },
    openDownloadStream() { return Readable.from([png]); },
    async delete() {},
  };
  try {
    const send = (mimeType, value) => fetch(origin + '/api/artifacts', {
      method: 'POST',
      headers: { Authorization: 'Bearer owner-token', 'content-type': 'application/json' },
      body: JSON.stringify({
        category: 'profile_photo', fileName: 'avatar.png',
        mimeType, base64: Buffer.from(value).toString('base64'),
      }),
    });
    const invalid = await send('image/png', Buffer.from('not a PNG'));
    assert.equal(invalid.status, 415);
    const uploaded = await send('image/png', png);
    assert.equal(uploaded.status, 201);
    const body = await uploaded.json();
    assert.equal(body.artifact.category, 'profile_photo');
    assert.equal(profile.photoArtifactId, String(photoId));
    assert.equal(profile.avatarStyle, 'photo');
    const downloadPath = '/api/artifacts/' + photoId + '/content';
    assert.equal((await fetch(origin + downloadPath)).status, 401);
    assert.equal((await fetch(origin + downloadPath, {
      headers: { Authorization: 'Bearer other-token' },
    })).status, 404);
    const mine = await fetch(origin + downloadPath, {
      headers: { Authorization: 'Bearer owner-token' },
    });
    assert.equal(mine.status, 200);
    assert.equal(mine.headers.get('content-type'), 'image/png');
    assert.deepEqual(Buffer.from(await mine.arrayBuffer()), png);
  } finally {
    state.db = priorDb;
    state.bucket = priorBucket;
  }
});
