// Rodriguez (Montalban), Rizal - PSA PSGC 2026, municipality code 0405808.
// This is the authoritative backend allowlist; the UI must fetch/reuse it.
export const RODRIGUEZ_BARANGAYS = Object.freeze([
  'Balite', 'Burgos', 'Geronimo', 'Macabud', 'Manggahan', 'Mascap',
  'Puray', 'Rosario', 'San Isidro', 'San Jose', 'San Rafael',
]);
export const RESIDENCY_STATES = Object.freeze([
  'pending', 'verified', 'needs_review', 'rejected',
]);

export function normalizeMunicipality(value) {
  const key = String(value ?? '').trim().toLowerCase()
    .replace(/\s+/g, ' ').replace(/[(),.]/g, '');
  if (['rodriguez', 'montalban', 'rodriguez rizal', 'montalban rizal',
       'rodriguez montalban', 'rodriguez montalban rizal'].includes(key)) {
    return 'Rodriguez';
  }
  return '';
}

export function normalizeBarangay(value) {
  const key = String(value ?? '').trim().toLowerCase()
    .replace(/^(?:barangay|brgy\.?|bgy\.?)\s*/i, '')
    .replace(/\s+/g, ' ');
  return RODRIGUEZ_BARANGAYS.find((name) => name.toLowerCase() === key) || '';
}

export function validateResidency(input, { requireComplete = true } = {}) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    return { error: 'invalid_residency' };
  }
  for (const name of ['municipality', 'barangay', 'address']) {
    if (input[name] !== undefined && typeof input[name] !== 'string') {
      return { error: 'invalid_' + name };
    }
  }
  const rawMunicipality = String(input.municipality || '').trim();
  const rawBarangay = String(input.barangay || '').trim();
  const address = String(input.address || '').trim();
  const municipality = normalizeMunicipality(rawMunicipality);
  const barangay = normalizeBarangay(rawBarangay);
  if (rawMunicipality && !municipality) return { error: 'municipality_not_eligible' };
  if (rawBarangay && !barangay) return { error: 'invalid_rodriguez_barangay' };
  if (address.length > 500) return { error: 'address_too_long' };
  if (requireComplete && (!municipality || !barangay || address.length < 5)) {
    return { error: 'residency_address_incomplete' };
  }
  return { municipality, barangay, address };
}

export function residencyStatus(profile) {
  const status = profile?.residency?.status;
  return RESIDENCY_STATES.includes(status) ? status : 'needs_review';
}

export function isVerifiedResident(profile) {
  return residencyStatus(profile) === 'verified' &&
    normalizeMunicipality(profile?.municipality || profile?.residency?.municipality) === 'Rodriguez' &&
    Boolean(normalizeBarangay(profile?.barangay || profile?.residency?.barangay)) &&
    String(profile?.address || profile?.residency?.address || '').trim().length >= 5;
}

export function normalizeSex(value) {
  const key = String(value ?? '').trim().toLowerCase();
  if (['male', 'm'].includes(key)) return 'Male';
  if (['female', 'f'].includes(key)) return 'Female';
  if (['other', 'non-binary', 'nonbinary'].includes(key)) return 'Other';
  if (['prefer not to say', 'undisclosed'].includes(key)) return 'Prefer not to say';
  return '';
}

function manilaDateParts(value) {
  const fields = new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Manila',
    year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(value);
  return {
    year: Number(fields.find(field => field.type === 'year')?.value),
    month: Number(fields.find(field => field.type === 'month')?.value),
    day: Number(fields.find(field => field.type === 'day')?.value),
  };
}

export function normalizeDateOfBirth(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return '';
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 ||
      date.getUTCDate() !== day || year < 1900) return '';
  const now = manilaDateParts(new Date());
  if (year > now.year || (year === now.year && (month > now.month ||
    (month === now.month && day > now.day)))) return '';
  return value;
}

export function ageFromBirthDate(value, now = new Date()) {
  const dob = normalizeDateOfBirth(value);
  if (!dob) return null;
  const [y, m, d] = dob.split('-').map(Number);
  const current = manilaDateParts(now);
  let age = current.year - y;
  if (current.month < m || (current.month === m && current.day < d)) age--;
  return age >= 0 && age <= 125 ? age : null;
}

export function documentSummary(profile, files = []) {
  // Saving an incomplete applicant draft must not falsely mark a submitted
  // resume/NSRP. A pendingDraft is isolated from the canonical submitted data.
  const hasFinalData = (data) => data && typeof data === 'object' &&
    !Array.isArray(data) && Object.keys(data).some((key) =>
      !['pendingDraft', 'draftOnly', 'draftUpdatedAt'].includes(key));
  const resume = hasFinalData(profile?.resumeData);
  const nsrp = hasFinalData(profile?.pesoFormData);
  const list = Array.isArray(files) ? files : [];
  const categories = list.map((file) => String(file?.metadata?.category || file?.category || '').toLowerCase());
  const resumeFile = categories.some((s) => /resume/.test(s));
  const nsrpFile = categories.some((s) => /nsrp|peso_form|employment_form/.test(s));
  return {
    resumeSubmitted: Boolean(profile?.resumeSubmitted || resume ||
      profile?.resumeFileName || profile?.documentSummary?.resumeSubmitted || resumeFile),
    formSubmitted: Boolean(profile?.formSubmitted || nsrp ||
      profile?.documentSummary?.formSubmitted || nsrpFile),
    resumeCount: categories.filter((s) => /resume/.test(s)).length,
    nsrpCount: categories.filter((s) => /nsrp|peso_form|employment_form/.test(s)).length,
  };
}
