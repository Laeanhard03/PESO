// Isolated admin-category regression. Only the QA Firebase emulator,
// loopback API :3003 and QA Mongo database :27117 are ever touched.
import assert from 'node:assert/strict';
import { MongoClient } from 'mongodb';

const api = 'http://127.0.0.1:3003';
const auth = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=qa-local';
const dbName = 'peso_e2e_browser_20261020';
const urls = [
  'https://dev.montalban.gov.ph/wp-content/uploads/2020/07/walk-in-compilation.pdf',
  'https://dev.montalban.gov.ph/wp-content/uploads/2020/07/PARA-SA-MONTALBENO.pdf',
];
const mongo = new MongoClient('mongodb://127.0.0.1:27117/?directConnection=true',
  { serverSelectionTimeoutMS: 5000 });
await mongo.connect();
const db = mongo.db(dbName);
assert.equal(db.databaseName, dbName);
const collection = db.collection('jobPdfLinks');
const existing = [];
for (const url of urls) existing.push(await collection.findOne({ url }));
const jobsBefore = await db.collection('jobPostings').countDocuments({});
let passed = 0;
const check = (label, condition) => {
  assert.ok(condition, label);
  console.log('PASS', label);
  passed++;
};
try {
  const identity = await fetch(auth, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'qa-admin@peso.example.test',
      password: 'QA-Temporary-Admin-Only-42!', returnSecureToken: true }),
  });
  assert.equal(identity.status, 200);
  let { idToken } = await identity.json();
  // QA admin was created before the email-verification gate was added;
  // verify through the LOCAL emulator rather than bypassing backend policy.
  const oob = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=qa-local', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ requestType: 'VERIFY_EMAIL', idToken }),
  });
  assert.equal(oob.status, 200);
  const codes = await (await fetch('http://127.0.0.1:9099/emulator/v1/projects/capstone-4th-year-peso-ai/oobCodes')).json();
  const code = codes.oobCodes.filter(row => row.email === 'qa-admin@peso.example.test' &&
    row.requestType === 'VERIFY_EMAIL').at(-1)?.oobCode;
  assert.ok(code);
  const verify = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:update?key=qa-local', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ oobCode: code }),
  });
  assert.equal(verify.status, 200);
  const renewed = await fetch(auth, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'qa-admin@peso.example.test',
      password: 'QA-Temporary-Admin-Only-42!', returnSecureToken: true }),
  });
  assert.equal(renewed.status, 200);
  idToken = (await renewed.json()).idToken;
  const post = async (body, authToken = idToken) => {
    const result = await fetch(api + '/api/admin/jobs/pdf-links', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        ...(authToken ? { authorization: 'Bearer ' + authToken } : {}),
      },
      body: JSON.stringify(body),
    });
    return { code: result.status, body: await result.json() };
  };
  const bad = await post({ title: 'QA classified walkin', url: urls[0] });
  console.log('QA BAD REQUEST', bad.code, bad.body.error, bad.body.message);
  check('missing recruitment category rejected 400', bad.code === 400 &&
    bad.body.error === 'invalid_pdf_job_category');
  const fake = await post({ title: 'QA classified', url: urls[0],
    category: 'illegal_unknown_category' });
  check('invalid category rejected', fake.code === 400);
  const anonymous = await post({ title: 'QA', url: urls[0],
    category: 'walk_in_application' }, null);
  check('anonymous URL intake rejected', anonymous.code === 401);
  const walk = await post({ title: 'Walk-in government reference', url: urls[0],
    category: 'walk_in_application' });
  check('official walk-in link accepted as Walk-in', [200, 201].includes(walk.code) &&
    walk.body.source?.category === 'walk_in_application');
  const lra = await post({ title: 'Para sa Montalbeño LRA source', url: urls[1],
    category: 'local_recruitment_activity' });
  check('47.7MB official LRA link accepted', [200, 201].includes(lra.code) &&
    lra.body.source?.category === 'local_recruitment_activity');
  const change = await post({ title: 'QA category changed', url: urls[0],
    category: 'local_recruitment_activity' });
  check('existing link updates type with explicit admin selection',
    change.code === 200 && change.body.updated === true &&
    change.body.source?.category === 'local_recruitment_activity');
  const list = await fetch(api + '/api/admin/jobs/pdf-links',
    { headers: { authorization: 'Bearer ' + idToken } });
  const listing = await list.json();
  check('GET exposes selected categories to admin', list.status === 200 &&
    listing.sources.some(row => row.url === urls[1] &&
      row.category === 'local_recruitment_activity'));
  check('link intake publishes no job records',
    await db.collection('jobPostings').countDocuments({}) === jobsBefore);
  console.log('QA PDF CATEGORY SUMMARY',passed,'passed');
} finally {
  // Restore the isolated QA registry to its pre-test state.
  for (let index = 0; index < urls.length; index++) {
    const prior = existing[index];
    if (!prior) await collection.deleteOne({ url: urls[index] });
    else {
      if (prior.category == null) await collection.updateOne({ _id: prior._id },
        { $unset: { category: '' } });
      else await collection.updateOne({ _id: prior._id },
        { $set: { category: prior.category } });
    }
  }
  await mongo.close();
}
