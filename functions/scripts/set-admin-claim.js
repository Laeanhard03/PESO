'use strict';

// One-time trusted administrator operation. Never expose this as an HTTP
// endpoint and never place service-account keys in the repository.
const { applicationDefault, getApps, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const projectId = String(process.env.FIREBASE_PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT || '').trim();
if (!projectId) throw new Error('Set FIREBASE_PROJECT_ID to the intended Firebase project ID.');
if (getApps().length === 0) initializeApp({ credential: applicationDefault(), projectId });

async function main() {
  const uid = String(process.env.ADMIN_UID || '').trim();
  if (!uid) throw new Error('Set ADMIN_UID to the intended Firebase Authentication UID.');
  const revoke = String(process.env.ADMIN_REVOKE_ADMIN_CLAIM || '').toLowerCase() === 'true';
  const user = await getAuth().getUser(uid);
  const claims = { ...(user.customClaims || {}) };
  if (revoke) delete claims.admin;
  else claims.admin = true;
  await getAuth().setCustomUserClaims(uid, claims);
  console.log(revoke ? 'Administrator claim revoked.' : 'Administrator claim enabled.');
}

main().catch((error) => {
  console.error('Administrator claim update failed: ' + String(error && error.code || error.message || 'unknown error'));
  process.exitCode = 1;
});
