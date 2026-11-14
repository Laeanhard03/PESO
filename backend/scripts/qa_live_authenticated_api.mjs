import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import { MongoClient } from 'mongodb';
import { initializeApp, cert, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const backend = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const root = path.dirname(backend);
dotenv.config({ path: path.join(backend, '.env') });

const dart = fs.readFileSync(path.join(root, 'lib', 'firebase_options.dart'), 'utf8');
const web = dart.split(/static const FirebaseOptions web\s*=\s*FirebaseOptions\(/)[1];
if (!web) throw new Error('Web Firebase options missing');
const webApiKey = web.match(/apiKey:\s*['"]([^'"]+)['"]/)[1];
const webProjectId = web.match(/projectId:\s*['"]([^'"]+)['"]/)[1];
if (webProjectId !== process.env.FIREBASE_PROJECT_ID) throw new Error('Firebase project mismatch');

const rawServiceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const serviceAccountPath = path.isAbsolute(rawServiceAccountPath)
  ? rawServiceAccountPath
  : path.resolve(backend, rawServiceAccountPath);
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
if (serviceAccount.project_id !== process.env.FIREBASE_PROJECT_ID) {
  throw new Error('Local Firebase service-account project mismatch');
}

const hosts = [
  'https://peso-jobkonek.vercel.app',
  'https://peso-jobkonek-failover-jlf-2026-tlgb.onrender.com',
];
const app = initializeApp({
  credential: cert(serviceAccount),
  projectId: process.env.FIREBASE_PROJECT_ID,
}, 'peso-admin-production-access-qa');
const client = new MongoClient(process.env.MONGODB_URI, { serverSelectionTimeoutMS: 12000 });

try {
  await client.connect();
  const profiles = await client.db(process.env.MONGODB_DB_NAME || 'peso_jobkonek')
    .collection('users')
    .find({ role: 'admin' }, { projection: { email: 1, emailLower: 1 } })
    .toArray();
  const emails = [...new Set(
    profiles.map(p => (p.emailLower || p.email || '').trim().toLowerCase()).filter(Boolean),
  )];
  if (emails.length === 0) throw new Error('No administrator profiles found');

  const auth = getAuth(app);
  const results = Object.fromEntries(hosts.map(host => [host, {
    profileRoleVerified: 0,
    protectedAdminAuthorized: 0,
    failures: [],
  }]));
  let verifiedEnabledAccounts = 0;
  let successfulExchanges = 0;
  let tokenUidMatches = 0;
  let unexpectedNewUsers = 0;

  for (const email of emails) {
    const account = await auth.getUserByEmail(email);
    if (!account.emailVerified || account.disabled) {
      for (const host of hosts) results[host].failures.push('Firebase identity not verified/enabled');
      continue;
    }
    verifiedEnabledAccounts++;

    // The documented signInWithCustomToken REST response returns idToken,
    // refreshToken and expiresIn; it does not include localId. Validate the
    // signed ID-token UID claim instead of expecting an absent response field.
    const customToken = await auth.createCustomToken(account.uid);
    const exchange = await fetch(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=' +
        encodeURIComponent(webApiKey),
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: customToken, returnSecureToken: true }),
      },
    );
    const session = await exchange.json().catch(() => ({}));
    if (!exchange.ok || !session.idToken) {
      for (const host of hosts) results[host].failures.push('Firebase token exchange HTTP ' + exchange.status);
      continue;
    }
    successfulExchanges++;
    if (session.isNewUser === true) {
      unexpectedNewUsers++;
      for (const host of hosts) results[host].failures.push('Custom-token sign-in unexpectedly created a new Firebase account');
      continue;
    }

    const tokenParts = session.idToken.split('.');
    if (tokenParts.length !== 3) {
      for (const host of hosts) results[host].failures.push('Malformed Firebase ID token');
      continue;
    }
    const claims = JSON.parse(Buffer.from(tokenParts[1], 'base64url').toString('utf8'));
    const tokenUid = claims.user_id || claims.sub;
    if (tokenUid !== account.uid) {
      for (const host of hosts) results[host].failures.push('Firebase ID token UID mismatch');
      continue;
    }
    tokenUidMatches++;

    for (const host of hosts) {
      const headers = {
        Authorization: 'Bearer ' + session.idToken,
        Origin: host,
        Accept: 'application/json',
      };
      const profileResponse = await fetch(host + '/api/profile', { headers });
      const profile = await profileResponse.json().catch(() => ({}));
      if (
        profileResponse.status === 200 &&
        profile.ok === true &&
        profile.profile?.role === 'admin' &&
        profile.profile?.uid === account.uid
      ) {
        results[host].profileRoleVerified++;
      } else {
        results[host].failures.push('Profile/role HTTP ' + profileResponse.status);
      }

      const adminResponse = await fetch(host + '/api/admin/development-notes?limit=1', { headers });
      const adminPayload = await adminResponse.json().catch(() => ({}));
      if (
        adminResponse.status === 200 &&
        adminPayload.ok === true &&
        Array.isArray(adminPayload.notes)
      ) {
        results[host].protectedAdminAuthorized++;
      } else {
        results[host].failures.push('Protected Admin API HTTP ' + adminResponse.status);
      }
    }
  }

  const summary = {
    distinctAdminEmails: emails.length,
    verifiedEnabledFirebaseAccounts: verifiedEnabledAccounts,
    successfulCustomTokenExchanges: successfulExchanges,
    IDTokenUIDsMatched: tokenUidMatches,
    unexpectedNewUsersCreated: unexpectedNewUsers,
    productionHosts: Object.fromEntries(hosts.map(host => [host, {
      profileRoleVerified: results[host].profileRoleVerified,
      protectedAdminAuthorized: results[host].protectedAdminAuthorized,
      failures: results[host].failures,
    }])),
  };
  console.log('LIVE_ADMIN_ACCESS_MATRIX', JSON.stringify(summary, null, 2));

  if (
    verifiedEnabledAccounts !== emails.length ||
    successfulExchanges !== emails.length ||
    tokenUidMatches !== emails.length ||
    unexpectedNewUsers !== 0 ||
    hosts.some(host =>
      results[host].profileRoleVerified !== emails.length ||
      results[host].protectedAdminAuthorized !== emails.length
    )
  ) {
    process.exitCode = 1;
  }
} catch (error) {
  console.log('LIVE_ADMIN_ACCESS_QA_FAILED', error?.name || 'Error', String(error?.message || '').slice(0, 180));
  process.exitCode = 1;
} finally {
  await client.close().catch(() => {});
  await deleteApp(app);
}
