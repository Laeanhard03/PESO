// Applicant-owned essentials for the React NSRP/Resume onboarding editors.
// Deliberately excludes tax/government IDs, licenses, assessor signatures,
// work history for new entrants, and any employer-only or PESO-only fields.
export const educationChoices = Object.freeze([
  'No formal schooling',
  'Elementary',
  'Junior High School',
  'Senior High School',
  'Technical / Vocational',
  'College Undergraduate',
  'College Graduate',
  'Postgraduate',
  'Currently studying',
]);
export const experienceChoices = Object.freeze([
  'No previous work experience',
  'Has work experience',
  'Prefer to discuss with PESO',
]);
export const skillsChoices = Object.freeze([
  'Has skills or training to list',
  'New entrant / still learning',
]);
const nonempty = value => String(value ?? '').trim();

export function applicantCareerEntries(details = {}) {
  return [
    { label: 'Highest education attained', fieldKey: 'applicant.highestEducation', value: nonempty(details.education) },
    { label: 'Work experience status', fieldKey: 'applicant.experienceStatus', value: nonempty(details.experience) },
    { label: 'Career readiness stage', fieldKey: 'applicant.skillsStage', value: nonempty(details.skillsStage) },
    ...(details.skillsStage === skillsChoices[0] && nonempty(details.skills)
      ? [{ label: 'Other skills acquired', fieldKey: 'applicant.skills', value: nonempty(details.skills) }]
      : []),
  ].filter(entry => entry.value);
}
export function validateApplicantEssentials(data = {}, { nsrp = true } = {}) {
  const missing = [];
  const first = nonempty(data.firstName);
  const last = nonempty(data.lastName);
  const full = nonempty(data.fullName);
  const completeName = nsrp ? Boolean(first && last)
    : Boolean((first && last) || full.split(/\s+/).filter(Boolean).length >= 2);
  if (!completeName) missing.push({ key: 'firstName', label: 'Your real first and last name' });
  if (!nonempty(data.email) && !nonempty(data.phone)) missing.push({ key: 'email', label: 'An email address or mobile number' });
  if (nsrp && !nonempty(data.city)) missing.push({ key: 'city', label: 'Your city or municipality' });
  if (nsrp && !nonempty(data.preferredOccupation)) missing.push({ key: 'preferredOccupation', label: 'A preferred occupation (or "Open to opportunities")' });
  if (!educationChoices.includes(data.education)) missing.push({ key: 'education', label: 'Highest schooling or currently studying' });
  if (!experienceChoices.includes(data.experience)) missing.push({ key: 'experience', label: 'Experience status (new entrants can select no experience)' });
  if (!skillsChoices.includes(data.skillsStage)) missing.push({ key: 'skillsStage', label: 'Whether you have skills to list or are still learning' });
  if (data.skillsStage === skillsChoices[0] && !nonempty(data.skills)) {
    missing.push({ key: 'skills', label: 'Your skills or training (or choose "still learning")' });
  }
  return missing;
}
