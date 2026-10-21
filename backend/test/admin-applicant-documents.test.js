import assert from 'node:assert/strict';
import { test } from 'node:test';
import express from 'express';
import { Readable } from 'node:stream';
import { installAdminApplicantDocumentRoutes } from '../src/admin-applicant-documents.js';

test('admin document lookup is UID-scoped, private, and distinguishes NSRP from resume', async () => {
  const app = express();
  app.use(express.json());
  const profileRows = [
    { uid: 'candidate-a', resumeData: { skills: ['clerical'] } },
    { uid: 'candidate-b', pesoFormData: { lastName: 'Example' } },
  ];
  const resumeId = '64a000000000000000000001';
  const nsrpId = '64a000000000000000000002';
  const stored = [
    { _id: resumeId, metadata: { ownerUid: 'candidate-a',
      category: 'resume_upload', mimeType: 'application/pdf', originalFileName: 'a.pdf' },
      filename: 'a.pdf', length: 8, uploadDate: new Date('2026-10-22') },
    { _id: nsrpId, metadata: { ownerUid: 'candidate-b',
      category: 'nsrp_form', mimeType: 'application/pdf', originalFileName: 'b.pdf' },
      filename: 'b.pdf', length: 8, uploadDate: new Date('2026-10-22') },
  ];
  const usersCollection = () => ({
    find: ({ uid }) => ({ toArray: async () =>
      profileRows.filter((profile) => uid.$in.includes(profile.uid)) }),
    findOne: async ({ uid }) => profileRows.find((profile) => profile.uid === uid) || null,
  });
  const matches = (row, filter) => {
    const uid = filter['metadata.ownerUid'];
    const category = filter['metadata.category']?.$in || [];
    return (typeof uid === 'string' ? uid === row.metadata.ownerUid :
      uid.$in.includes(row.metadata.ownerUid)) && category.includes(row.metadata.category) &&
      (!filter._id || String(filter._id) === String(row._id));
  };
  const state = {
    db: { collection: () => ({
      find: (filter) => ({
        sort: () => ({ toArray: async () => stored.filter((row) => matches(row, filter)) }),
      }),
      findOne: async (filter) => stored.find((row) => matches(row, filter)) || null,
    }) },
    bucket: {
      find: (filter) => ({ sort: () => ({ toArray: async () =>
        stored.filter((row) => row.metadata.ownerUid === filter['metadata.ownerUid']) }) }),
      openDownloadStream: (id) =>
        Readable.from([Buffer.from(String(id) === resumeId ? 'resume-a' : 'nsrp-bbb')]),
    },
  };
  const requireAuth = (req, res, next) => req.headers.authorization
    ? next() : res.status(401).json({ error: 'missing_bearer_token' });
  const requireAdmin = (req, res, next) =>
    req.headers.authorization === 'Bearer admin'
      ? next() : res.status(403).json({ error: 'admin_required' });
  installAdminApplicantDocumentRoutes({
    app, requireAuth, requireAdmin, requireMongo: (_, __, next) => next(),
    state, usersCollection,
    artifactFromGridFs: (file) => ({ id: file._id,
      category: file.metadata.category, fileName: file.filename,
      mimeType: file.metadata.mimeType }),
    isAllowedMimeType: (value) => value === 'application/pdf',
    safeFileName: (value) => value,
  });
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  const base = 'http://127.0.0.1:' + server.address().port;
  const request = (path, token = 'admin', options = {}) =>
    fetch(base + path, { ...options, headers: { Authorization: 'Bearer ' + token,
      'Content-Type': 'application/json' } });
  try {
    const batch = await request('/api/admin/users/document-status', 'admin', {
      method: 'POST', body: JSON.stringify({ uids: ['candidate-a', 'candidate-b'] }),
    });
    assert.equal(batch.status, 200);
    const result = (await batch.json()).records;
    assert.equal(result['candidate-a'].resume.artifact.id, resumeId);
    assert.equal(result['candidate-a'].nsrp.status, 'not_submitted');
    assert.equal(result['candidate-b'].resume.status, 'not_submitted');
    assert.equal(result['candidate-b'].nsrp.artifact.id, nsrpId);
    const metadataA = await request('/api/admin/users/candidate-a/documents');
    assert.equal(metadataA.status, 200);
    const metadata = await metadataA.json();
    assert.equal(metadata.uid, 'candidate-a');
    assert.equal(metadata.resumeCount, 1);
    assert.equal(metadata.artifacts[0].id, resumeId);
    assert.equal(metadata.documents.nsrp.status, 'not_submitted');
    const metadataB = await request('/api/admin/users/candidate-b/documents');
    assert.equal(metadataB.status, 200);
    assert.equal((await metadataB.json()).nsrpCount, 1);
    assert.equal((await request('/api/admin/users/candidate-a/documents', 'user')).status, 403);
    const preview = await request('/api/admin/users/candidate-a/documents/resume/content?artifactId=' + resumeId);
    assert.equal(preview.status, 200);
    assert.equal(await preview.text(), 'resume-a');
    assert.match(preview.headers.get('cache-control'), /no-store/);
    assert.equal((await request('/api/admin/users/candidate-b/documents/nsrp/content?artifactId=' + resumeId)).status, 404);
    const other = await request('/api/admin/users/candidate-b/documents/resume/content');
    assert.equal(other.status, 404);
    assert.equal((await request('/api/admin/users/candidate-a/documents/nsrp/content',
      'user')).status, 403);
    assert.equal((await request('/api/admin/users/candidate-b/documents/nsrp/content',
      'admin')).status, 200);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
