'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { validateAdminUpdatePayload } = require('../lib/admin_user_management_core');

const valid = {
  uid: 'target-user-1', firstName: 'Ava', lastName: 'Santos',
  email: 'ava@example.org', phoneNumber: '+639171234567',
  location: 'Rizal', educationLevel: 'College', employmentStatus: 'Looking for work',
  professionalTitle: 'Bookkeeper', bio: 'Seeking a bookkeeping role.', disabled: false,
};

test('accepts a valid profile update and normalizes surrounding whitespace', () => {
  const result = validateAdminUpdatePayload({ ...valid, firstName: ' Ava ' });
  assert.equal(result.error, null);
  assert.equal(result.profile.firstName, 'Ava');
  assert.equal(result.uid, 'target-user-1');
  assert.equal(result.disabled, false);
});
test('rejects missing target IDs and malformed bodies', () => {
  assert.match(validateAdminUpdatePayload(null).error, /object/);
  assert.match(validateAdminUpdatePayload({ ...valid, uid: '' }).error, /user ID/);
});
test('rejects attempts to edit role or protected fields', () => {
  assert.match(validateAdminUpdatePayload({ ...valid, role: 'admin' }).error, /unsupported field/);
  assert.match(validateAdminUpdatePayload({ ...valid, customClaims: {} }).error, /unsupported field/);
});
test('requires non-empty names and a valid email', () => {
  assert.match(validateAdminUpdatePayload({ ...valid, firstName: ' ' }).error, /First name/);
  assert.match(validateAdminUpdatePayload({ ...valid, email: 'not-an-email' }).error, /email/);
});
test('rejects overlong text and invalid phone values', () => {
  assert.match(validateAdminUpdatePayload({ ...valid, bio: 'x'.repeat(3001) }).error, /3000/);
  assert.match(validateAdminUpdatePayload({ ...valid, phoneNumber: 'phone-number?' }).error, /phone number/);
});
test('requires explicit account status and rejects extra fields', () => {
  assert.match(validateAdminUpdatePayload({ ...valid, disabled: 'false' }).error, /enabled or disabled/);
  assert.match(validateAdminUpdatePayload({ ...valid, password: 'secret' }).error, /unsupported field/);
});
