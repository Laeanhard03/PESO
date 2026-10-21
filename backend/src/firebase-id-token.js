import { createPublicKey, verify, X509Certificate } from 'node:crypto';

const certUrl = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
let cache = { keys: null, until: 0 };

async function getSigningKeys(options, nowMs) {
  if (options.publicKeys) return options.publicKeys;
  if (cache.keys && cache.until > nowMs()) return cache.keys;
  let response;
  try {
    response = await (options.fetchImpl || fetch)(certUrl, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    throw new Error('firebase_keys_unavailable');
  }
  if (!response.ok) throw new Error('firebase_keys_unavailable');
  const keys = await response.json();
  if (!keys || typeof keys !== 'object' || Array.isArray(keys) || !Object.keys(keys).length ||
      Object.values(keys).some((value) => typeof value !== 'string' || !value.includes('-----BEGIN CERTIFICATE-----'))) {
    throw new Error('firebase_keys_invalid');
  }
  const maxAge = Number((response.headers.get('cache-control') || '').match(/max-age=(\d+)/i)?.[1] || 300);
  cache = { keys, until: nowMs() + Math.min(Math.max(maxAge, 30) * 1000, 86400000) };
  return keys;
}

/** Verify Firebase client ID tokens using Google's published Secure Token keys. */
export async function verifyFirebaseIdToken(token, projectId, options = {}) {
  if (!projectId || typeof token !== 'string' || token.length < 100 || token.length > 16384) {
    throw new Error('invalid_firebase_id_token');
  }
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('invalid_firebase_id_token');
  let header; let claims; let signature;
  try {
    header = JSON.parse(Buffer.from(parts[0], 'base64url').toString());
    claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
    signature = Buffer.from(parts[2], 'base64url');
  } catch { throw new Error('invalid_firebase_id_token'); }
  if (!header || typeof header !== 'object' || Array.isArray(header) ||
      !claims || typeof claims !== 'object' || Array.isArray(claims) ||
      header.alg !== 'RS256' || typeof header.kid !== 'string' || !header.kid || !signature.length) {
    throw new Error('invalid_firebase_id_token');
  }
  const nowMs = options.nowMs || Date.now;
  const now = Number.isFinite(options.nowSeconds) ? options.nowSeconds : Math.floor(nowMs() / 1000);
  if (claims.aud !== projectId || claims.iss !== 'https://securetoken.google.com/' + projectId ||
      typeof claims.sub !== 'string' || !claims.sub || claims.sub.length > 128 ||
      !Number.isFinite(claims.exp) || !Number.isFinite(claims.iat) || !Number.isFinite(claims.auth_time) ||
      claims.exp <= now - 60 || claims.iat > now + 60 || claims.auth_time > now + 60 ||
      claims.auth_time > claims.iat + 60) {
    throw new Error('invalid_firebase_id_token_claims');
  }
  const keys = await getSigningKeys(options, nowMs);
  const certificate = keys[header.kid];
  if (typeof certificate !== 'string') throw new Error('firebase_key_not_found');
  let publicKey;
  try {
    publicKey = certificate.includes('-----BEGIN CERTIFICATE-----')
      ? new X509Certificate(certificate).publicKey
      : createPublicKey(certificate);
  } catch { throw new Error('firebase_signing_key_invalid'); }
  if (!verify('RSA-SHA256', Buffer.from(parts[0] + '.' + parts[1]), publicKey, signature)) {
    throw new Error('firebase_token_signature_invalid');
  }
  return {
    uid: claims.sub,
    email: typeof claims.email === 'string' ? claims.email : '',
    name: typeof claims.name === 'string' ? claims.name : '',
    picture: typeof claims.picture === 'string' ? claims.picture : '',
    phone_number: typeof claims.phone_number === 'string' ? claims.phone_number : '',
    email_verified: claims.email_verified === true,
    firebase: claims.firebase && typeof claims.firebase === 'object' ? claims.firebase : {},
  };
}

export function clearFirebaseKeyCacheForTests() { cache = { keys: null, until: 0 }; }
