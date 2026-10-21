import test from 'node:test';
import assert from 'node:assert/strict';
import {
  isAllowedMimeType,
  safeFileName,
  sanitizeProfilePatch,
  sanitizePreferences,
  createFileSignature,
  verifyFileSignature,
} from './security.js';

test('file types are allowlisted', () => {
  assert.equal(isAllowedMimeType('application/pdf'), true);
  assert.equal(isAllowedMimeType('image/jpeg'), true);
  assert.equal(isAllowedMimeType('text/html'), false);
});

test('file names drop directory traversal and unsafe characters', () => {
  assert.equal(safeFileName('../../private\u0000.pdf'), 'private_.pdf');
  assert.equal(safeFileName(''), 'document.pdf');
});

test('profile patch cannot alter uid, role or credentials', () => {
  assert.deepEqual(
    sanitizeProfilePatch({
      uid: 'victim',
      role: 'admin',
      firstName: 'Ari',
      location: 'Rizal',
      password: 'secret',
    }),
    { firstName: 'Ari', location: 'Rizal' },
  );
});

test('profile avatar choices are allowlisted but artifact ownership stays server-controlled', () => {
  assert.deepEqual(sanitizeProfilePatch({
    firstName: 'Lia', avatarStyle: 'sun', photoArtifactId: 'victim-id',
  }), { firstName: 'Lia', avatarStyle: 'sun' });
  assert.deepEqual(sanitizeProfilePatch({ avatarStyle: 'javascript:alert(1)' }), {});
});

test('preferences are allowlisted', () => {
  assert.deepEqual(
    sanitizePreferences({
      language: 'Tagalog',
      emailNotifications: false,
      role: 'admin',
    }),
    { language: 'Tagalog', emailNotifications: false },
  );
});

test('signed file links validate owner, signature and expiry', () => {
  const secret = 'unit-test-secret-never-used-in-production';
  const uid = 'firebase-uid';
  const id = '507f1f77bcf86cd799439011';
  const exp = Math.floor(Date.now() / 1000) + 60;
  const sig = createFileSignature(secret, uid, id, exp);
  assert.equal(verifyFileSignature(secret, uid, id, exp, sig), true);
  assert.equal(verifyFileSignature(secret, 'another-user', id, exp, sig), false);
  assert.equal(verifyFileSignature(secret, uid, id, exp - 120, sig), false);
  assert.equal(verifyFileSignature(secret, uid, id, exp, 'bad'), false);
});
