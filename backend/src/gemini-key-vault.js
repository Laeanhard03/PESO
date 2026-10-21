import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_BYTES = 12;
const TAG_BYTES = 16;
const ENCRYPTION_KEY_BYTES = 32;
const CURRENT_SCHEMA_VERSION = 1;
const CURRENT_KEY_VERSION = 1;
const MAX_API_KEY_LENGTH = 512;
const MIN_API_KEY_LENGTH = 16;

function getAesKey(encryptionSecret) {
  if (typeof encryptionSecret !== 'string' || !encryptionSecret.trim()) {
    throw new Error('GEMINI_KEY_ENCRYPTION_SECRET is required.');
  }
  const encoded = encryptionSecret.trim();
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)) {
    throw new Error('GEMINI_KEY_ENCRYPTION_SECRET must be base64 for exactly 32 bytes.');
  }
  const bytes = Buffer.from(encoded, 'base64');
  if (bytes.length !== ENCRYPTION_KEY_BYTES || bytes.toString('base64') !== encoded) {
    throw new Error('GEMINI_KEY_ENCRYPTION_SECRET must be base64 for exactly 32 bytes.');
  }
  return bytes;
}

export function validateApiKeyInput(value) {
  if (typeof value !== 'string') {
    throw new TypeError('Gemini API key is required.');
  }
  const key = value.trim();
  if (!key) throw new Error('Gemini API key is required.');
  if (key.length < MIN_API_KEY_LENGTH || key.length > MAX_API_KEY_LENGTH) {
    throw new Error('Gemini API key length is invalid.');
  }
  if (/[\u0000-\u0020\u007f]/.test(key)) {
    throw new Error('Gemini API key must be a single line without whitespace.');
  }
  return key;
}

export function maskApiKey(value) {
  if (typeof value !== 'string' || value.length === 0) return '';
  if (value.length <= 8) return '••••••••';
  return '••••' + value.slice(-4);
}

function aadFor(recordId, schemaVersion) {
  if (typeof recordId !== 'string' || !recordId.trim() || recordId.length > 128) {
    throw new Error('A valid Gemini key record ID is required.');
  }
  if (schemaVersion !== CURRENT_SCHEMA_VERSION) {
    throw new Error('Unsupported Gemini key record version.');
  }
  return Buffer.from('peso-gemini-api-key|schema=' + schemaVersion + '|id=' + recordId, 'utf8');
}

function decodeBase64Field(value, expectedBytes, fieldName) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) {
    throw new Error('Gemini key record ' + fieldName + ' is invalid.');
  }
  const decoded = Buffer.from(value, 'base64');
  if (decoded.toString('base64') !== value ||
      (expectedBytes != null && decoded.length !== expectedBytes)) {
    throw new Error('Gemini key record ' + fieldName + ' is invalid.');
  }
  return decoded;
}

/**
 * Encrypt a Gemini key for one specific MongoDB key-record ID.
 * Plaintext exists only in this call's memory and is never included in output.
 */
export function encryptApiKey({ apiKey, encryptionSecret, recordId }) {
  const key = validateApiKeyInput(apiKey);
  const aesKey = getAesKey(encryptionSecret);
  const aad = aadFor(recordId, CURRENT_SCHEMA_VERSION);
  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv(ALGORITHM, aesKey, iv, { authTagLength: TAG_BYTES });
  cipher.setAAD(aad);
  const ciphertext = Buffer.concat([
    cipher.update(key, 'utf8'),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();

  return {
    iv: iv.toString('base64'),
    ciphertext: ciphertext.toString('base64'),
    authTag: authTag.toString('base64'),
    schemaVersion: CURRENT_SCHEMA_VERSION,
    keyVersion: CURRENT_KEY_VERSION,
    maskedSuffix: maskApiKey(key),
  };
}

/** Decrypt only in server memory immediately before the provider request. */
export function decryptApiKey({ record, encryptionSecret, recordId }) {
  if (!record || typeof record !== 'object') {
    throw new Error('Gemini key record is invalid.');
  }
  if (record.schemaVersion !== CURRENT_SCHEMA_VERSION ||
      record.keyVersion !== CURRENT_KEY_VERSION) {
    throw new Error('Unsupported Gemini key record version.');
  }
  const targetId = recordId || String(record._id || '');
  const aad = aadFor(targetId, record.schemaVersion);
  const iv = decodeBase64Field(record.iv, IV_BYTES, 'IV');
  const ciphertext = decodeBase64Field(record.ciphertext, null, 'ciphertext');
  const authTag = decodeBase64Field(record.authTag, TAG_BYTES, 'authentication tag');
  if (!ciphertext.length || ciphertext.length > MAX_API_KEY_LENGTH) {
    throw new Error('Gemini key record ciphertext is invalid.');
  }

  const decipher = createDecipheriv(ALGORITHM, getAesKey(encryptionSecret), iv, {
    authTagLength: TAG_BYTES,
  });
  decipher.setAAD(aad);
  decipher.setAuthTag(authTag);
  let plaintext;
  try {
    plaintext = Buffer.concat([
      decipher.update(ciphertext),
      decipher.final(),
    ]).toString('utf8');
  } catch {
    throw new Error('Gemini key record could not be authenticated or decrypted.');
  }
  try {
    return validateApiKeyInput(plaintext);
  } catch {
    throw new Error('Gemini key record contains invalid plaintext.');
  }
}

function safeDate(value) {
  if (value == null) return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value.toISOString();
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
  }
  return null;
}

/** Explicit allowlist; never copy arbitrary Mongo fields into API responses. */
export function publicKeyMetadata(record) {
  const safe = record && typeof record === 'object' ? record : {};
  const id = safe._id == null ? '' : String(safe._id);
  return {
    id,
    label: typeof safe.label === 'string' ? safe.label : '',
    maskedSuffix: typeof safe.maskedSuffix === 'string' && safe.maskedSuffix
      ? safe.maskedSuffix
      : '••••',
    enabled: safe.enabled === true,
    health: [
      'ready',
      'cooling_down',
      'attention_required',
      'configuration_error',
      'disabled',
    ].includes(safe.health) ? safe.health : (safe.enabled === true ? 'ready' : 'disabled'),
    cooldownUntil: safe.cooldownUntil == null ? null : safeDate(safe.cooldownUntil),
    quotaUntil: safe.quotaUntil == null ? null : safeDate(safe.quotaUntil),
    lastQuotaAt: safe.lastQuotaAt == null ? null : safeDate(safe.lastQuotaAt),
    quotaModel: typeof safe.quotaModel === 'string' ? safe.quotaModel.slice(0, 80) : null,
    quotaScope: ['daily', 'minute', 'unknown'].includes(safe.quotaScope) ? safe.quotaScope : null,
    quotaMetric: ['RPD', 'RPM', 'TPM', 'unspecified'].includes(safe.quotaMetric) ? safe.quotaMetric : null,
    lastUsedAt: safe.lastUsedAt == null ? null : safeDate(safe.lastUsedAt),
    lastTestedAt: safe.lastTestedAt == null ? null : safeDate(safe.lastTestedAt),
    lastErrorCategory: typeof safe.lastErrorCategory === 'string'
      ? safe.lastErrorCategory.slice(0, 64)
      : null,
    createdAt: safe.createdAt == null ? null : safeDate(safe.createdAt),
    updatedAt: safe.updatedAt == null ? null : safeDate(safe.updatedAt),
  };
}

export const GEMINI_KEY_VAULT_LIMITS = Object.freeze({
  minApiKeyLength: MIN_API_KEY_LENGTH,
  maxApiKeyLength: MAX_API_KEY_LENGTH,
  ivBytes: IV_BYTES,
  authTagBytes: TAG_BYTES,
  encryptionKeyBytes: ENCRYPTION_KEY_BYTES,
  schemaVersion: CURRENT_SCHEMA_VERSION,
  keyVersion: CURRENT_KEY_VERSION,
});
