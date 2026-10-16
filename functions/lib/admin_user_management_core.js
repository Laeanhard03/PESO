'use strict';

const FIELD_LIMITS = Object.freeze({
  firstName: 80, lastName: 80, email: 254, phoneNumber: 32,
  location: 160, educationLevel: 100, employmentStatus: 100,
  professionalTitle: 160, bio: 3000,
});

function validateAdminUpdatePayload(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return { error: 'The update body must be an object.' };
  }
  const allowed = new Set(['uid', 'disabled', ...Object.keys(FIELD_LIMITS)]);
  if (Object.keys(data).some((key) => !allowed.has(key))) {
    return { error: 'The update contains an unsupported field.' };
  }
  if (typeof data.uid !== 'string' || !data.uid.trim() || data.uid.length > 128) {
    return { error: 'A valid target user ID is required.' };
  }
  if (typeof data.disabled !== 'boolean') {
    return { error: 'Account status must be enabled or disabled.' };
  }
  const profile = {};
  for (const [field, limit] of Object.entries(FIELD_LIMITS)) {
    if (typeof data[field] !== 'string') return { error: field + ' must be text.' };
    const value = data[field].trim();
    if (value.length > limit) return { error: field + ' must be ' + limit + ' characters or fewer.' };
    profile[field] = value;
  }
  if (!profile.firstName || !profile.lastName) return { error: 'First name and last name are required.' };
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(profile.email)) return { error: 'Enter a valid email address.' };
  if (profile.phoneNumber && !/^[+0-9() .-]{6,32}$/.test(profile.phoneNumber)) return { error: 'Enter a valid phone number.' };
  return { error: null, uid: data.uid.trim(), disabled: data.disabled, profile };
}

module.exports = { FIELD_LIMITS, validateAdminUpdatePayload };
