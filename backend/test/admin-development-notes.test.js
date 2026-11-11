import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { Readable, Writable } from 'node:stream';
import { ObjectId } from 'mongodb';
import { app, state } from '../server.js';

const noteRows = new Map();
const userRows = new Map();
const imageRows = new Map();

function matches(document, filter = {}) {
  if (filter._id && String(document._id) !== String(filter._id)) return false;
  if (filter.uid && document.uid !== filter.uid) return false;
  if (filter.revision !== undefined && document.revision !== filter.revision) return false;
  if (filter.kind && document.kind !== filter.kind) return false;
  if (filter.status && document.status !== filter.status) return false;
  if (filter.archived === true && document.archived !== true) return false;
  if (filter.archived && typeof filter.archived === 'object' &&
      Object.hasOwn(filter.archived, '$ne') &&
      document.archived === filter.archived.$ne) return false;
  if (filter['attachments.id'] &&
      !(document.attachments || []).some((item) => item.id === filter['attachments.id'])) return false;
  if (Array.isArray(filter.$or)) {
    const found = filter.$or.some((condition) => {
      const [key, pattern] = Object.entries(condition)[0] || [];
      if (!key || !(pattern instanceof RegExp)) return false;
      const value = document[key];
      if (Array.isArray(value)) return value.some((item) => pattern.test(String(item)));
      return pattern.test(String(value || ''));
    });
    if (!found) return false;
  }
  return true;
}

const usersCollection = {
  async findOne(filter) {
    return userRows.get(filter.uid) || null;
  },
  async updateOne(filter, update, options = {}) {
    let row = userRows.get(filter.uid);
    if (!row && options.upsert) {
      row = { ...(update.$setOnInsert || {}), uid: filter.uid };
      userRows.set(filter.uid, row);
    }
    if (row && update.$set) Object.assign(row, update.$set);
    return { matchedCount: row ? 1 : 0, upsertedCount: 0 };
  },
};

const notesCollection = {
  async findOne(filter) {
    return [...noteRows.values()].find((row) => matches(row, filter)) || null;
  },
  async insertOne(note) {
    note._id = new ObjectId();
    noteRows.set(String(note._id), note);
    return { insertedId: note._id };
  },
  find(filter = {}) {
    let rows = [...noteRows.values()].filter((row) => matches(row, filter));
    return {
      sort() {
        rows.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
        return this;
      },
      limit(value) {
        rows = rows.slice(0, value);
        return this;
      },
      async toArray() {
        return rows;
      },
    };
  },
  async updateOne(filter, update) {
    const row = [...noteRows.values()].find((item) => matches(item, filter));
    if (!row) return { matchedCount: 0 };
    if (update.$set) Object.assign(row, update.$set);
    if (update.$inc) {
      for (const [key, amount] of Object.entries(update.$inc)) {
        row[key] = Number(row[key] || 0) + amount;
      }
    }
    if (update.$push) {
      for (const [key, instruction] of Object.entries(update.$push)) {
        const values = instruction && Array.isArray(instruction.$each)
          ? instruction.$each
          : [instruction];
        row[key] = [...(row[key] || []), ...values];
        if (instruction && Number.isInteger(instruction.$slice)) {
          const count = Math.abs(instruction.$slice);
          row[key] = instruction.$slice < 0
            ? row[key].slice(-count)
            : row[key].slice(0, count);
        }
      }
    }
    return { matchedCount: 1 };
  },
};

const bucket = {
  openUploadStream(fileName, options) {
    const id = new ObjectId();
    const chunks = [];
    const stream = new Writable({
      write(chunk, _encoding, callback) {
        chunks.push(Buffer.from(chunk));
        callback();
      },
      final(callback) {
        imageRows.set(String(id), {
          id,
          fileName,
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
    const record = imageRows.get(String(id));
    return Readable.from(record ? [record.bytes] : []);
  },
  async delete(id) {
    imageRows.delete(String(id));
  },
};

let server;
let baseUrl;

before(async () => {
  noteRows.clear();
  userRows.clear();
  imageRows.clear();
  userRows.set('admin-uid', { uid: 'admin-uid', role: 'admin', email: 'admin@example.test' });
  userRows.set('user-uid', { uid: 'user-uid', role: 'job_seeker', email: 'user@example.test' });
  state.tokenVerifierOverride = async (token) => {
    if (token === 'admin-token') {
      return {
        uid: 'admin-uid',
        email: 'admin@example.test',
        name: 'PESO Developer',
        email_verified: true,
        firebase: { sign_in_provider: 'password' },
      };
    }
    if (token === 'user-token') {
      return {
        uid: 'user-uid',
        email: 'user@example.test',
        name: 'Regular Applicant',
        email_verified: true,
        firebase: { sign_in_provider: 'password' },
      };
    }
    throw new Error('Invalid test token');
  };
  state.mongoConnected = true;
  state.mongoProblem = null;
  state.db = {
    collection(name) {
      if (name === 'users') return usersCollection;
      if (name === 'adminDevelopmentNotes') return notesCollection;
      throw new Error('Unexpected test collection: ' + name);
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

async function request(path, { token = 'admin-token', method = 'GET', body } = {}) {
  const headers = { Connection: 'close' };
  if (token) headers.Authorization = 'Bearer ' + token;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  return fetch(baseUrl + path, {
    method,
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

test('development notes are restricted to verified administrator accounts', async () => {
  const anonymous = await request('/api/admin/development-notes', { token: null });
  assert.equal(anonymous.status, 401);
  const applicant = await request('/api/admin/development-notes', { token: 'user-token' });
  assert.equal(applicant.status, 403);
});

test('creates a bug report with an initial checklist and creator metadata', async () => {
  const response = await request('/api/admin/development-notes', {
    method: 'POST',
    body: {
      title: 'Login button does not respond',
      description: 'Reproduced on mobile after entering credentials.',
      kind: 'bug',
      priority: 'high',
      assignee: 'Edward',
      tags: ['login', 'mobile'],
      checklist: ['Reproduce on mobile', 'Fix the event handler'],
    },
  });
  assert.equal(response.status, 201);
  const payload = await response.json();
  assert.equal(payload.note.kind, 'bug');
  assert.equal(payload.note.status, 'open');
  assert.equal(payload.note.revision, 1);
  assert.equal(payload.note.createdBy.name, 'PESO Developer');
  assert.equal(payload.note.checklist.length, 2);
});

test('checklist completion derives fixed status and reopening reverses it', async () => {
  const created = await request('/api/admin/development-notes', {
    method: 'POST',
    body: {
      title: 'Broken menu',
      kind: 'bug',
      checklist: ['Fix the menu', 'Verify mobile navigation'],
    },
  });
  const note = (await created.json()).note;
  let revision = note.revision;
  let result = await request('/api/admin/development-notes/' + note.id +
    '/checklist/' + note.checklist[0].id, {
      method: 'PATCH',
      body: { completed: true, expectedRevision: revision },
    });
  let updated = (await result.json()).note;
  assert.equal(updated.status, 'in_progress');
  revision = updated.revision;
  result = await request('/api/admin/development-notes/' + note.id +
    '/checklist/' + note.checklist[1].id, {
      method: 'PATCH',
      body: { completed: true, expectedRevision: revision },
    });
  updated = (await result.json()).note;
  assert.equal(updated.status, 'fixed');
  revision = updated.revision;
  result = await request('/api/admin/development-notes/' + note.id +
    '/checklist/' + note.checklist[0].id, {
      method: 'PATCH',
      body: { completed: false, expectedRevision: revision },
    });
  updated = (await result.json()).note;
  assert.equal(updated.status, 'in_progress');
});

test('stale revisions are rejected instead of overwriting a coworker update', async () => {
  const created = await request('/api/admin/development-notes', {
    method: 'POST',
    body: { title: 'Concurrent edit test', kind: 'task' },
  });
  const note = (await created.json()).note;
  const first = await request('/api/admin/development-notes/' + note.id, {
    method: 'PATCH',
    body: { title: 'Updated title', expectedRevision: note.revision },
  });
  assert.equal(first.status, 200);
  const stale = await request('/api/admin/development-notes/' + note.id, {
    method: 'PATCH',
    body: { title: 'Stale title', expectedRevision: note.revision },
  });
  assert.equal(stale.status, 409);
  assert.equal((await stale.json()).error, 'note_revision_conflict');
});

test('comments are attributed and included in activity history', async () => {
  const created = await request('/api/admin/development-notes', {
    method: 'POST',
    body: { title: 'Comment test', kind: 'improvement' },
  });
  const note = (await created.json()).note;
  const response = await request('/api/admin/development-notes/' + note.id + '/comments', {
    method: 'POST',
    body: { message: 'I can reproduce this in Chrome.' },
  });
  assert.equal(response.status, 201);
  const updated = (await response.json()).note;
  assert.equal(updated.comments[0].message, 'I can reproduce this in Chrome.');
  assert.equal(updated.comments[0].actor.uid, 'admin-uid');
  assert.equal(updated.activity.at(-1).action, 'commented');
});

test('screenshots are stored privately, streamed only through admin route, and removable', async () => {
  const created = await request('/api/admin/development-notes', {
    method: 'POST',
    body: { title: 'Screenshot evidence', kind: 'bug' },
  });
  const note = (await created.json()).note;
  const png = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const uploaded = await request('/api/admin/development-notes/' + note.id + '/attachments', {
    method: 'POST',
    body: {
      fileName: 'bug.png',
      mimeType: 'image/png',
      base64: png.toString('base64'),
      expectedRevision: note.revision,
    },
  });
  assert.equal(uploaded.status, 201);
  const updated = (await uploaded.json()).note;
  const attachment = updated.attachments[0];
  assert.equal(imageRows.get(attachment.id).metadata.uploadedByUid, 'admin-uid');
  assert.equal(imageRows.get(attachment.id).metadata.ownerUid, undefined);
  const content = await request('/api/admin/development-notes/' + note.id +
    '/attachments/' + attachment.id + '/content');
  assert.equal(content.status, 200);
  assert.equal(content.headers.get('content-type'), 'image/png');
  assert.deepEqual(Buffer.from(await content.arrayBuffer()), png);

  const removed = await request('/api/admin/development-notes/' + note.id +
    '/attachments/' + attachment.id, {
      method: 'DELETE',
      body: { expectedRevision: updated.revision },
    });
  assert.equal(removed.status, 200);
  assert.equal((await removed.json()).note.attachments.length, 0);
  assert.equal(imageRows.has(attachment.id), false);
});

test('archived notes can be restored and then edited again', async () => {
  const created = await request('/api/admin/development-notes', {
    method: 'POST',
    body: { title: 'Archive and restore', kind: 'task' },
  });
  const note = (await created.json()).note;
  const archived = await request('/api/admin/development-notes/' + note.id, {
    method: 'PATCH',
    body: { archived: true, expectedRevision: note.revision },
  });
  assert.equal(archived.status, 200);
  const archivedNote = (await archived.json()).note;
  assert.equal(archivedNote.archived, true);
  const restored = await request('/api/admin/development-notes/' + note.id, {
    method: 'PATCH',
    body: { archived: false, expectedRevision: archivedNote.revision },
  });
  assert.equal(restored.status, 200);
  const restoredNote = (await restored.json()).note;
  assert.equal(restoredNote.archived, false);
  const edited = await request('/api/admin/development-notes/' + note.id, {
    method: 'PATCH',
    body: { title: 'Restored and edited', expectedRevision: restoredNote.revision },
  });
  assert.equal(edited.status, 200);
});

test('improvement checklist completion derives implemented status', async () => {
  const created = await request('/api/admin/development-notes', {
    method: 'POST',
    body: {
      title: 'Add dashboard filters',
      kind: 'improvement',
      checklist: ['Build filter UI'],
    },
  });
  const note = (await created.json()).note;
  const response = await request('/api/admin/development-notes/' + note.id +
    '/checklist/' + note.checklist[0].id, {
      method: 'PATCH',
      body: { completed: true, expectedRevision: note.revision },
    });
  assert.equal((await response.json()).note.status, 'implemented');
});

test('rejects invalid screenshot types and missing titles', async () => {
  const noTitle = await request('/api/admin/development-notes', {
    method: 'POST',
    body: { title: '   ' },
  });
  assert.equal(noTitle.status, 400);
  const created = await request('/api/admin/development-notes', {
    method: 'POST',
    body: { title: 'Validation test' },
  });
  const note = (await created.json()).note;
  const invalid = await request('/api/admin/development-notes/' + note.id + '/attachments', {
    method: 'POST',
    body: {
      fileName: 'payload.svg',
      mimeType: 'image/svg+xml',
      base64: 'PHN2Zz4=',
      expectedRevision: note.revision,
    },
  });
  assert.equal(invalid.status, 415);
});
