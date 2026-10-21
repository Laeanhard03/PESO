import assert from 'node:assert/strict';
import { before, after, test } from 'node:test';
import { app, state } from '../server.js';

const profiles = new Map();
const deepCopy = (value) => structuredClone(value);
function readField(record, key) {
  return key.split('.').reduce((value, component) => value?.[component], record);
}
function setField(record, key, value) {
  const path = key.split('.');
  let obj = record;
  for (const part of path.slice(0, -1)) obj = obj[part] ??= {};
  obj[path.at(-1)] = deepCopy(value);
}
const collection = {
  async findOne(filter) {
    const result = profiles.get(filter.uid);
    return result ? deepCopy(result) : null;
  },
  async updateOne(filter, update, options = {}) {
    let doc = profiles.get(filter.uid);
    if (!doc && options.upsert) {
      doc = { uid: filter.uid, ...deepCopy(update.$setOnInsert || {}) };
      profiles.set(filter.uid, doc);
    }
    if (!doc) return { matchedCount: 0, upsertedCount: 0 };
    for (const [key, expected] of Object.entries(filter)) {
      if (key === 'uid') continue;
      const actual = readField(doc, key);
      if (expected && typeof expected === 'object') {
        if ('$exists' in expected && (actual !== undefined) !== expected.$exists)
          return { matchedCount: 0, upsertedCount: 0 };
        if ('$in' in expected && !expected.$in.some(v => v == actual))
          return { matchedCount: 0, upsertedCount: 0 };
      } else if (actual !== expected) {
        return { matchedCount: 0, upsertedCount: 0 };
      }
    }
    for (const [key, val] of Object.entries(update.$set || {})) setField(doc, key, val);
    for (const key of Object.keys(update.$unset || {})) delete doc[key];
    for (const [key, push] of Object.entries(update.$push || {})) {
      const current = readField(doc, key) || [];
      const merged = [...current, ...push.$each];
      setField(doc, key, merged.slice(push.$slice || -100));
    }
    return { matchedCount: 1, upsertedCount: 0 };
  },
};
const emptyFiles = {
  find() { return { sort() { return this; }, limit() { return this; },
    toArray: async () => [] }; },
};
let server, base;
before(async () => {
  profiles.clear();
  profiles.set('admin1', { uid: 'admin1', role: 'admin', email: 'admin@local.test' });
  profiles.set('resident1', { uid: 'resident1', role: 'job_seeker',
    email: 'resident@local.test', firstName: 'Test', lastName: 'Resident',
    resumeData: {}, pesoFormData: {} });
  state.tokenVerifierOverride = async (token) => {
    if (!['admin', 'resident'].includes(token)) throw Error('Invalid token');
    return { uid: token === 'admin' ? 'admin1' : 'resident1',
      email: token === 'admin' ? 'admin@local.test' : 'resident@local.test',
      email_verified: true, name: 'Test Resident',
      firebase: { sign_in_provider: 'password' } };
  };
  state.db = { collection(name) {
    if (name === 'users') return collection;
    if (name === 'residencyAudit') return emptyFiles;
    if (name === 'profileArtifacts.files') return emptyFiles;
    throw Error('Unexpected collection ' + name);
  } };
  state.bucket = emptyFiles;
  state.mongoConnected = true;
  server = app.listen(0, '127.0.0.1');
  await new Promise(ok => server.once('listening', ok));
  base = 'http://127.0.0.1:' + server.address().port;
});
after(async () => {
  server.closeAllConnections?.();
  await new Promise(ok => server.close(ok));
  state.tokenVerifierOverride = null;
  state.db = null;
  state.bucket = null;
  state.mongoConnected = false;
});
async function request(path, token, method = 'GET', body) {
  const r = await fetch(base + path, { method, headers: {
    ...(token ? { Authorization: 'Bearer ' + token } : {}),
    ...(body ? { 'Content-Type': 'application/json' } : {}),
    Connection: 'close',
  }, ...(body ? { body: JSON.stringify(body) } : {}) });
  return { status:r.status, body: await r.json() };
}
test('public barangay list is precise and no arbitrary barangay accepted', async () => {
  const list = await request('/api/residency/barangays');
  assert.equal(list.status,200);
  assert.equal(list.body.barangays.length,11);
  const invalid = await request('/api/account/residency','resident','PUT',{
    municipality:'Montalban',barangay:'Wawa',address:'Block 5 Lot 7' });
  assert.equal(invalid.status,400);
  assert.equal(profiles.get('resident1').residency,undefined);
});
test('registration records a pending barangay but not false verification', async () => {
  const r = await request('/api/profile/ensure','resident','POST',{
    municipality:'Montalban',barangay:'Mascap' });
  assert.equal(r.status,200);
  assert.equal(r.body.profile.barangay,'Mascap');
  assert.equal(r.body.profile.residency.status,'pending');
  assert.equal(r.body.profile.residencyAudit,undefined);
});
test('applicant cannot self-verify; job application is protected', async () => {
  const r = await request('/api/applications','resident','POST',{
    jobTitle:'Welder',answers:{experience:'2 years'} });
  assert.equal(r.status,403);
  assert.equal(r.body.error,'residency_verification_required');
  const unauthorized = await request('/api/admin/users/resident1/residency','resident','PATCH',{
    status:'verified', expectedRevision:0, note:'fake evidence' });
  assert.equal(unauthorized.status,403);
});
test('bad profile DOB does not partially mutate submitted residency', async () => {
  const r = await request('/api/profile','resident','PUT',{
    municipality:'Marikina',dateOfBirth:'2000-02-30'});
  assert.equal(r.status,400);
  assert.equal(profiles.get('resident1').barangay,'Mascap');
});
test('admin review validates evidence and writes atomic bounded audit', async () => {
  const saved = await request('/api/account/residency','resident','PUT',{
    municipality:'Montalban',barangay:'Mascap',address:'Lot 10 Block 2 Street 4' });
  assert.equal(saved.status,200);
  const revision = saved.body.profile.residency.revision;
  const missing = await request('/api/admin/users/resident1/residency','admin','PATCH',{
    status:'verified', expectedRevision:revision});
  assert.equal(missing.status,400);
  assert.equal(missing.body.error,'residency_review_evidence_required');
  const reviewed = await request('/api/admin/users/resident1/residency','admin','PATCH',{
    status:'verified', expectedRevision:revision,
    evidenceType:'in_person', note:'Document checked at PESO counter' });
  assert.equal(reviewed.status,200);
  assert.equal(reviewed.body.status,'verified');
  const stale = await request('/api/admin/users/resident1/residency','admin','PATCH',{
    status:'rejected',expectedRevision:revision,note:'Stale review'});
  assert.equal(stale.status,409);
  const audits = await request('/api/admin/users/resident1/residency/audit','admin');
  assert.equal(audits.status,200);
  assert.ok(audits.body.entries.length>=2);
  assert.ok(audits.body.entries.some(x=>x.actorUid==='admin1' && x.status==='verified'));
  const own = await request('/api/profile','resident');
  assert.equal(own.body.profile.residency.status,'verified');
  assert.equal(own.body.profile.residencyAudit,undefined);
});
test('residency address edits invalidate verification before any application', async () => {
  const update = await request('/api/account/residency','resident','PUT',{
    municipality:'Montalban',barangay:'Balite',address:'Block 4, San Rafael' });
  assert.equal(update.status,200);
  assert.equal(update.body.profile.residency.status,'pending');
  const blocked = await request('/api/applications','resident','POST',{
    jobTitle:'Welder',answers:{experience:'2 years'} });
  assert.equal(blocked.status,403);
});
test('onboarding preserves legacy forms, detects stale edits and deduplicates retry', async () => {
  const first = await request('/api/profile/onboarding','resident','PATCH',{
    draft:true,complete:true,expectedRevision:0,
    mutationId:'task1-mutation-first',
    pesoFormData:{skills:'Welding'}});
  assert.equal(first.status,200);
  assert.equal(first.body.profile.onboardingRevision,1);
  const replay = await request('/api/profile/onboarding','resident','PATCH',{
    draft:true,complete:true,expectedRevision:0,
    mutationId:'task1-mutation-first',
    pesoFormData:{skills:'Welding'}});
  assert.equal(replay.status,200);
  assert.equal(replay.body.profile.onboardingRevision,1);
  const conflict = await request('/api/profile/onboarding','resident','PATCH',{
    draft:true,expectedRevision:0,mutationId:'task1-mutation-stale',
    resumeData:{skills:'Invalid'}});
  assert.equal(conflict.status,409);
  const second = await request('/api/profile/onboarding','resident','PATCH',{
    draft:true,complete:true,expectedRevision:1,mutationId:'task1-mutation-second',
    pesoFormData:{education:'TVET'}});
  assert.equal(second.status,200);
  assert.equal(second.body.profile.pesoFormData.skills,'Welding');
  assert.equal(second.body.profile.pesoFormData.education,'TVET');
  assert.ok(second.body.profile.onboardingCompletedAt);
});
test('NSRP birth date derives age and Other sex without trusting a typed age', async () => {
  const latest = await request('/api/profile','resident');
  const revision = latest.body.profile.onboardingRevision;
  const invalid = await request('/api/profile/onboarding','resident','PATCH',{
    draft:true, complete:true, expectedRevision:revision,
    mutationId:'task1-invalid-birthday',
    pesoFormData:{dateOfBirth:'2001-02-29',age:99,sex:'Other'}});
  assert.equal(invalid.status,400);
  assert.equal(invalid.body.error,'invalid_date_of_birth');
  const saved = await request('/api/profile/onboarding','resident','PATCH',{
    draft:true,complete:true,expectedRevision:revision,
    mutationId:'task1-valid-birthday',
    pesoFormData:{dateOfBirth:'2000-02-29',age:99,sex:'Other',religion:'Prefer not to say'}});
  assert.equal(saved.status,200);
  assert.equal(saved.body.profile.sex,'Other');
  assert.equal(saved.body.profile.dateOfBirth,'2000-02-29');
  assert.notEqual(saved.body.profile.age,99);
  assert.equal(saved.body.profile.pesoFormData.age,saved.body.profile.age);
  assert.equal(saved.body.profile.pesoFormData.religion,'Prefer not to say');
});

test('document status from saved NSRP data does not require Gemini', async () => {
  const s = await request('/api/account/documents','resident');
  assert.equal(s.status,200);
  assert.equal(s.body.formSubmitted,true);
  assert.equal(s.body.resumeSubmitted,false);
});
