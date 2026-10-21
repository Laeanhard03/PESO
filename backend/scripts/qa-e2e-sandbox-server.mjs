// Local-only, explicitly isolated functional QA. Never run against production DB.
// No real Gemini requests or actual applicant records are created by this server.
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { createJobPostingRecord, JOB_POSTING_CATEGORIES } from '../src/job_postings.js';

const DB = 'peso_e2e_browser_20261020';
const PROJECT = 'capstone-4th-year-peso-ai';
if (process.env.MONGODB_DB_NAME && process.env.MONGODB_DB_NAME !== DB) {
  throw new Error('Refusing to start: QA database name differs from approved sandbox.');
}
if (process.env.PORT && process.env.PORT !== '3003') {
  throw new Error('Refusing to start: QA must bind to port 3003.');
}
process.env.MONGODB_DB_NAME = DB;
// Connect to the dedicated loopback-only local Mongo instance, never Atlas.
process.env.MONGODB_URI = 'mongodb://127.0.0.1:27117/?directConnection=true';
process.env.PORT = '3003';
process.env.HOST = '127.0.0.1';
// Keep signed export and preview links inside QA; do not inherit a production base URL.
process.env.PUBLIC_API_BASE_URL = 'http://127.0.0.1:3003';
process.env.PESO_SKIP_AUTOMATIC_JOB_SYNC = '1';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.GEMINI_API_KEY = 'qa-local-fake-provider-key-NOT-REAL';
process.env.GEMINI_FALLBACK_MODEL = '';
process.env.INITIAL_ADMIN_EMAIL = 'qa-admin@peso.example.test';

const { startServer, state } = await import('../server.js');
const app = initializeApp({ projectId: PROJECT }, 'peso-qa-auth-emulator');
state.tokenVerifierOverride = async (token) => getAuth(app).verifyIdToken(token);

const QA_TAG = 'QA_ISOLATED_NOT_REAL_APPLICANT';
let simulatedFailureCount = 0;
state.geminiProviderOverride = async ({ operation, payload }) => {
  if (operation === 'profile_extraction') {
    const plain = (payload?.parts || []).map((p) => p.text || '').join('\n');
    if (plain.includes('QA_SIMULATE_GEMINI_429')) {
      simulatedFailureCount += 1;
      throw Object.assign(new Error('Simulated QA quota limit'), {
        status: 429, code: 'RESOURCE_EXHAUSTED', retryAfterSeconds: 30,
        quotaScope: 'minute', quotaMetric: 'RPM'
      });
    }
    return { profile: {
      fullName: 'QA Sample Applicant', professionalTitle: 'Data Entry Clerk',
      skills: ['MS Excel', 'Data Entry'], education: ['Senior High School'],
      employmentHistory: [], certifications: [], yearsExperience: 0,
      bilingualBio: 'QA mock extraction only. Demonstration profile, not a real applicant.'
    }};
  }
  if (operation === 'job_translation') {
    const prompt = String(payload?.prompt || '');
    const last = prompt.lastIndexOf('{');
    let source;
    try { source = JSON.parse(prompt.slice(last)); } catch { source = null; }
    if (!source) {
      return { text: JSON.stringify({
        title: 'QA Data Entry Clerk',
        description: 'Trabaho sa Montalban, Rizal',
        requirements: ['MS Excel', 'Data Entry']
      }) };
    }
    return { text: JSON.stringify({
      title: 'Salin: ' + source.title,
      description: 'Salin: ' + source.description,
      requirements: source.requirements.map((r) => 'Salin: ' + r),
    }) };
  }
  if (operation === 'job_evaluation_explanation') {
    const prompt = String(payload?.prompt || '');
    const limited = /"statusFixedByGoRules":"no_match"/.test(prompt);
    return { text: JSON.stringify({ explanation: limited
      ? 'Your current career categories may not fully connect to this opening. PESO can review listed requirements and related opportunities.'
      : 'Your recorded occupation areas relate to this job. PESO and the employer must still confirm the exact qualifications.' }) };
  }
  if (operation === 'query' || operation === 'key_test') {
    return { text: 'QA simulated answer; no real Gemini was contacted.' };
  }
  throw new Error('QA mock provider received unsupported operation');
};

const server = await startServer();
if (!state.mongoConnected || state.db?.databaseName !== DB) {
  server.close();
  throw new Error('QA refused to operate without the isolated Mongo database.');
}
const jobs = state.db.collection('jobPostings');
const fixtureJobs = [
  {
    title: 'QA Data Entry Clerk', company: 'PESO QA Fictional Employer',
    location: 'Montalban, Rizal', salary: 'PHP 15,000 monthly',
    employmentType: 'Full-time', vacancies: 2,
    description: 'QA sandbox vacancy for manual testing. No real job is available. MS Excel and Data Entry.',
    requirements: ['MS Excel', 'Data Entry'],
    category: JOB_POSTING_CATEGORIES.WALK_IN,
  },
  {
    title: 'QA Construction Assistant', company: 'PESO QA Fictional Employer',
    location: 'Rodriguez, Rizal', salary: 'PHP 16,000 monthly',
    employmentType: 'Contract', vacancies: 1,
    description: 'QA sandbox vacancy only. Basic construction assistance.',
    requirements: ['Construction experience preferred'],
    category: JOB_POSTING_CATEGORIES.WALK_IN,
  },
];
await jobs.deleteMany({ qaTag: QA_TAG });
await jobs.insertMany(fixtureJobs.map((body) => ({
  ...createJobPostingRecord(body, 'qa-sandbox-fixture'),
  qaTag: QA_TAG,
})));
const authBase = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/';
const adminEmail = 'qa-admin@peso.example.test';
const adminPassword = 'QA-Temporary-Admin-Only-42!';
async function authRequest(op, body) {
  const result = await fetch(authBase + op + '?key=qa-local', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: result.status, value: await result.json() };
}
let admin = await authRequest('accounts:signUp', {
  email: adminEmail, password: adminPassword, returnSecureToken: true
});
if (admin.status === 400) {
  admin = await authRequest('accounts:signInWithPassword', {
    email: adminEmail, password: adminPassword, returnSecureToken: true
  });
}
if (admin.status !== 200 || !admin.value?.localId) throw new Error('QA admin emulator setup failed.');
await state.db.collection('users').updateOne({ uid: admin.value.localId }, {
  $set: { uid: admin.value.localId, email: adminEmail, role: 'admin', disabled: false,
    displayName: 'QA Test Administrator', firstName: 'QA', lastName: 'Administrator',
    updatedAt: new Date(), qaTag: QA_TAG },
  $setOnInsert: { createdAt: new Date() }
}, { upsert: true });
console.log(JSON.stringify({
  qa: true, database: DB, api: 'http://127.0.0.1:3003',
  fixtureJobCount: fixtureJobs.length,
  authEmulator: '127.0.0.1:9099', fakeGemini: true,
  adminEmail, adminPassword: 'available inside test script only',
  notes: 'Never use fictional results for actual qualification decisions'
}));
process.on('SIGUSR1', () => console.log(JSON.stringify({
  qa: true, simulatedGeminiQuotaFailures: simulatedFailureCount
})));
