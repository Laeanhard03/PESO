import { createHmac, timingSafeEqual } from 'node:crypto';

export const ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
]);

export const MAX_ARTIFACT_BYTES = 20 * 1024 * 1024;

export function isAllowedMimeType(value) {
  return ALLOWED_MIME_TYPES.has(String(value ?? '').toLowerCase());
}

export function safeFileName(value) {
  const leaf = String(value ?? 'document.pdf').split(/[\\/]/).at(-1)?.trim() ?? '';
  const safe = leaf.replace(/[^A-Za-z0-9._ -]/g, '_').slice(0, 120);
  return safe || 'document.pdf';
}

/** Only explicitly writable profile fields are accepted; role and uid are never client-controlled. */
export function sanitizeProfilePatch(input = {}) {
  const allowed = [
    'firstName',
    'lastName',
    'displayName',
    'phoneNumber',
    'location',
    'educationLevel',
    'employmentStatus',
    'professionalTitle',
    'bio',
  ];
  const result = {};
  for (const key of allowed) {
    if (typeof input[key] === 'string') result[key] = input[key].trim().slice(0, 4000);
  }
  if (['person', 'leaf', 'briefcase', 'sun', 'photo'].includes(input.avatarStyle)) {
    result.avatarStyle = input.avatarStyle;
  }
  return result;
}

export function sanitizePreferences(input = {}) {
  const out = {};
  if (['English', 'Tagalog', 'Taglish'].includes(input.language)) {
    out.language = input.language;
  }
  if (typeof input.emailNotifications === 'boolean') {
    out.emailNotifications = input.emailNotifications;
  }
  if (typeof input.appNotifications === 'boolean') {
    out.appNotifications = input.appNotifications;
  }
  return out;
}

export function createFileSignature(secret, uid, fileId, exp) {
  return createHmac('sha256', secret)
    .update(`${uid}:${fileId}:${exp}`)
    .digest('hex');
}

export function verifyFileSignature(secret, uid, fileId, exp, supplied) {
  if (!secret || !uid || !fileId || !Number.isInteger(Number(exp))) return false;
  const expiration = Number(exp);
  const now = Math.floor(Date.now() / 1000);
  if (expiration < now || expiration > now + 10 * 60) return false;
  const expected = createFileSignature(secret, uid, fileId, expiration);
  const a = Buffer.from(expected, 'hex');
  const b = Buffer.from(String(supplied ?? ''), 'hex');
  return a.length === b.length && timingSafeEqual(a, b);
}

export function normalizeProfileForClient(profile) {
  if (!profile) return null;
  const { _id, ...safe } = profile;
  return safe;
}
