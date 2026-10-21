import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import test from 'node:test';

import {
  decryptApiKey,
  encryptApiKey,
  maskApiKey,
  publicKeyMetadata,
  validateApiKeyInput,
} from './gemini-key-vault.js';

const encryptionSecret = randomBytes(32).toString('base64');

function fixture(overrides = {}) {
  return {
    _id: '507f1f77bcf86cd799439011',
    label: 'Primary test key',
    enabled: true,
    health: 'ready',
    maskedSuffix: '••••wxyz',
    iv: randomBytes(12).toString('base64'),
    ciphertext: Buffer.from('ciphertext-fixture').toString('base64'),
    authTag: randomBytes(16).toString('base64'),
    schemaVersion: 1,
    keyVersion: 1,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    createdBy: 'admin-uid',
    updatedBy: 'admin-uid',
    ...overrides,
  };
}

test('AES-256-GCM key vault round-trips key bytes with record-bound AAD', () => {
  const input = 'fake-gemini-key-for-unit-test-wxyz';
  const recordId = '507f1f77bcf86cd799439011';
  const encrypted = encryptApiKey({
    apiKey: input,
    encryptionSecret,
    recordId,
  });

  assert.equal(encrypted.schemaVersion, 1);
  assert.equal(encrypted.keyVersion, 1);
  assert.equal(Buffer.from(encrypted.iv, 'base64').length, 12);
  assert.equal(Buffer.from(encrypted.authTag, 'base64').length, 16);
  assert.equal(decryptApiKey({
    record: { ...encrypted, _id: recordId },
    encryptionSecret,
    recordId,
  }), input);
  assert.equal(JSON.stringify(encrypted).includes(input), false);
});

test('vault encrypts the same key using a fresh IV each time', () => {
  const options = {
    apiKey: 'another-fake-gemini-key-for-tests',
    encryptionSecret,
    recordId: '507f1f77bcf86cd799439012',
  };
  const first = encryptApiKey(options);
  const second = encryptApiKey(options);
  assert.notEqual(first.iv, second.iv);
  assert.notEqual(first.ciphertext, second.ciphertext);
});

test('vault rejects ciphertext tampering and wrong record-bound AAD', () => {
  const encrypted = encryptApiKey({
    apiKey: 'fake-key-for-tamper-test',
    encryptionSecret,
    recordId: 'key-record-a',
  });
  const alteredCiphertext = Buffer.from(encrypted.ciphertext, 'base64');
  alteredCiphertext[0] ^= 1;
  assert.throws(() => decryptApiKey({
    record: { ...encrypted, _id: 'key-record-a', ciphertext: alteredCiphertext.toString('base64') },
    encryptionSecret,
    recordId: 'key-record-a',
  }), /decrypt|authenticate|ciphertext/i);
  assert.throws(() => decryptApiKey({
    record: { ...encrypted, _id: 'key-record-a' },
    encryptionSecret,
    recordId: 'different-record',
  }), /decrypt|authenticate|ciphertext/i);
});

test('vault rejects an invalid encryption secret and unknown record version', () => {
  assert.throws(() => encryptApiKey({
    apiKey: 'fake-key-for-secret-test',
    encryptionSecret: 'not-base64-secret',
    recordId: 'key-record',
  }), /GEMINI_KEY_ENCRYPTION_SECRET|32 bytes|encryption secret/i);

  const encrypted = encryptApiKey({
    apiKey: 'fake-key-for-version-test',
    encryptionSecret,
    recordId: 'key-record',
  });
  assert.throws(() => decryptApiKey({
    record: { ...encrypted, _id: 'key-record', keyVersion: 99 },
    encryptionSecret,
    recordId: 'key-record',
  }), /version/i);
});

test('key input validation rejects empty, oversized, or multiline input without echoing it', () => {
  assert.throws(() => validateApiKeyInput('  '), /required|empty/i);
  assert.throws(() => validateApiKeyInput('fake-key\nsecond-line'), /line|newline/i);
  assert.throws(() => validateApiKeyInput('x'.repeat(513)), /length|long/i);
  assert.equal(validateApiKeyInput('  valid-key-shape-for-test  '), 'valid-key-shape-for-test');
});

test('mask helper reveals only the last four characters', () => {
  assert.equal(maskApiKey('fake-api-key-ABCD'), '••••ABCD');
  assert.equal(maskApiKey('short'), '••••••••');
  assert.equal(maskApiKey(''), '');
});

test('public metadata uses an allowlist and excludes all encrypted fields and actors', () => {
  const record = fixture();
  const result = publicKeyMetadata(record);
  const serialized = JSON.stringify(result);
  assert.equal(result.label, 'Primary test key');
  assert.equal(result.maskedSuffix, '••••wxyz');
  for (const forbidden of ['ciphertext', 'iv', 'authTag', 'apiKey', 'plaintext', 'createdBy', 'updatedBy']) {
    assert.equal(Object.hasOwn(result, forbidden), false, forbidden);
    assert.equal(serialized.includes(record.ciphertext), false);
    assert.equal(serialized.includes(record.authTag), false);
  }
});

test('public metadata has a stable masked view when secret fields are missing', () => {
  const result = publicKeyMetadata({
    _id: 'key-id',
    label: 'Broken legacy record',
    enabled: false,
    health: 'attention_required',
  });
  assert.equal(result.id, 'key-id');
  assert.equal(result.maskedSuffix, '••••');
  assert.equal(result.enabled, false);
});
