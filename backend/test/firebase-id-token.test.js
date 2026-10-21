import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { test } from 'node:test';

import { verifyFirebaseIdToken } from '../src/firebase-id-token.js';

const projectId = 'capstone-4th-year-peso-ai';
const now = Math.floor(Date.now() / 1000);
const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const publicKeys = {
  'test-firebase-key': publicKey.export({ type: 'spki', format: 'pem' }),
};

function createToken(overrides = {}, headerOverrides = {}) {
  const header = Buffer.from(JSON.stringify({
    alg: 'RS256',
    typ: 'JWT',
    kid: 'test-firebase-key',
    ...headerOverrides,
  })).toString('base64url');
  const claims = Buffer.from(JSON.stringify({
    aud: projectId,
    iss: 'https://securetoken.google.com/' + projectId,
    sub: 'firebase-user-1',
    iat: now,
    exp: now + 3600,
    auth_time: now - 60,
    email: 'admin@example.invalid',
    email_verified: true,
    firebase: { sign_in_provider: 'google.com' },
    ...overrides,
  })).toString('base64url');
  const content = header + '.' + claims;
  const signature = sign('RSA-SHA256', Buffer.from(content), privateKey).toString('base64url');
  return content + '.' + signature;
}

test('Firebase ID tokens verify signature and return only identity claims needed by PESO', async () => {
  const decoded = await verifyFirebaseIdToken(createToken(), projectId, { publicKeys, nowSeconds: now });
  assert.equal(decoded.uid, 'firebase-user-1');
  assert.equal(decoded.email, 'admin@example.invalid');
  assert.equal(decoded.email_verified, true);
  assert.equal(decoded.firebase.sign_in_provider, 'google.com');
});

test('Firebase ID token rejects wrong audience and issuer before key lookup', async () => {
  await assert.rejects(
    verifyFirebaseIdToken(createToken({ aud: 'another-project' }), projectId, {
      publicKeys, nowSeconds: now,
    }),
    /invalid_firebase_id_token_claims/,
  );
  await assert.rejects(
    verifyFirebaseIdToken(createToken({ iss: 'https://attacker.invalid/project' }), projectId, {
      publicKeys, nowSeconds: now,
    }),
    /invalid_firebase_id_token_claims/,
  );
});

test('Firebase ID token rejects expired or future-issued tokens', async () => {
  await assert.rejects(
    verifyFirebaseIdToken(createToken({ exp: now - 120 }), projectId, {
      publicKeys, nowSeconds: now,
    }),
    /invalid_firebase_id_token_claims/,
  );
  await assert.rejects(
    verifyFirebaseIdToken(createToken({ iat: now + 500 }), projectId, {
      publicKeys, nowSeconds: now,
    }),
    /invalid_firebase_id_token_claims/,
  );
});

test('Firebase ID token rejects a signature altered after signing', async () => {
  const token = createToken();
  const parts = token.split('.');
  parts[2] = (parts[2][0] === 'A' ? 'B' : 'A') + parts[2].slice(1);
  await assert.rejects(
    verifyFirebaseIdToken(parts.join('.'), projectId, { publicKeys, nowSeconds: now }),
    /firebase_token_signature_invalid/,
  );
});

test('Firebase ID token rejects non-RS256 algorithms', async () => {
  await assert.rejects(
    verifyFirebaseIdToken(createToken({}, { alg: 'HS256' }), projectId, {
      publicKeys, nowSeconds: now,
    }),
    /invalid_firebase_id_token/,
  );
});
