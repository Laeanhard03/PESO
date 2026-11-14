const REQUIRED_OFFICIAL_FIELDS = Object.freeze([
  ['lastName', 'Surname (green-highlighted field)'],
  ['firstName', 'First name (green-highlighted field)'],
  ['middleName', 'Middle name (enter N/A if not applicable)'],
  ['suffix', 'Suffix (enter N/A if not applicable)'],
  ['dateOfBirth', 'Date of birth'],
  ['sex', 'Sex'],
  ['religion', 'Religion or Prefer not to say'],
  ['presentAddress', 'Present address (complete the section; N/A where not applicable)'],
  ['city', 'Municipality / city'],
  ['height', 'Height (enter N/A if not available)'],
  ['email', 'Email address (enter N/A if not available)'],
  ['phone', 'Cellphone number (enter N/A if not available)'],
  ['civilStatus', 'Civil status (select one applicable option)'],
  ['employmentStatus', 'Employment status/type (select an applicable option)'],
  ['preferredOccupation', 'Preferred occupation'],
  ['preferredWorkLocation', 'Preferred work location (enter a location or N/A)'],
  ['languageProficiency', 'Language/dialect proficiency (select an applicable option or enter N/A)'],
  ['educationBackground', 'Educational background (enter details or N/A if not applicable)'],
  ['workExperience', 'Work experience (enter details or N/A if none)'],
  ['otherSkills', 'Other skills acquired (select skills or N/A if none apply)'],
  ['signature', 'Applicant signature'],
  ['signatureDate', 'Signature date'],
]);
export function isCompletePhilippineMobileNumber(value) {
  const raw = String(value || '').trim();
  if (raw.toUpperCase() === 'N/A') return true;
  const compact = raw.replace(/[\s()-]/g, '');
  return /^(?:09\d{9}|\+639\d{9}|639\d{9}|9\d{9})$/.test(compact);
}

export function isEligibleNsrpAge(value) {
  const age = Number(value);
  return String(value ?? '').trim() !== '' && Number.isFinite(age) && age >= 18;
}

export function collectMissingNsrpFields(values = {}) {
  return REQUIRED_OFFICIAL_FIELDS
    .filter(([key]) => {
      const value = values[key];
      return !(value === true || (typeof value === 'string' && value.trim().length > 0));
    })
    .map(([key, label]) => ({ key, label }));
}

export const nsrpRequiredFieldLabels = Object.freeze(
  Object.fromEntries(REQUIRED_OFFICIAL_FIELDS),
);
