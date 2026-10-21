import assert from 'node:assert/strict';
import { test } from 'node:test';
import { applicantCareerEntries, validateApplicantEssentials,
  educationChoices, experienceChoices, skillsChoices } from './applicantEssentials.js';

const complete = {
  firstName: 'Ana', lastName: 'Santos',
  email: 'ana@example.test', phone: '', city: 'Rodriguez, Rizal',
  preferredOccupation: 'Open to opportunities',
  education: 'Currently studying',
  experience: 'No previous work experience',
  skillsStage: 'New entrant / still learning',
  skills: '',
};

test('NSRP blocks only essential applicant-owned fields', () => {
  assert.deepEqual(validateApplicantEssentials(complete), []);
  const empty = validateApplicantEssentials({});
  assert.ok(empty.some(x => x.key === 'firstName'));
  assert.ok(empty.some(x => x.key === 'education'));
  assert.ok(empty.some(x => x.key === 'preferredOccupation'));
  assert.equal(empty.some(x => /TIN|SSS|PhilHealth|assessor|certificate/i.test(x.label)), false);
});

test('contact alternatives, new entrants, and no formal schooling are accepted', () => {
  const candidate = {
    ...complete, email: '', phone: '09175551234',
    education: 'No formal schooling', experience: 'No previous work experience',
  };
  assert.deepEqual(validateApplicantEssentials(candidate), []);
  assert.ok(educationChoices.includes(candidate.education));
  assert.ok(experienceChoices.includes(candidate.experience));
});

test('applicants who report existing skills must name them, or select still learning', () => {
  const incomplete = { ...complete, skillsStage: skillsChoices[0], skills: '' };
  assert.ok(validateApplicantEssentials(incomplete).some(x => x.key === 'skills'));
  const ready = { ...incomplete, skills: 'Carpentry, Basic Workplace Safety' };
  assert.deepEqual(validateApplicantEssentials(ready), []);
  const entries = applicantCareerEntries(ready);
  assert.ok(entries.some(x => x.fieldKey === 'applicant.skills' && x.value.includes('Carpentry')));
  assert.equal(entries.some(x => /\b(?:tin|sss|sex|age|assessor)\b/i.test(x.label)), false);
  assert.equal(applicantCareerEntries(complete).some(x => x.fieldKey === 'applicant.skills'), false);
});

test('resume essentials require a real multi-part name and contact, but not city or occupation', () => {
  const a = { ...complete, firstName: '', lastName: '', fullName: 'Ana Santos',
    city: '', preferredOccupation: '' };
  assert.deepEqual(validateApplicantEssentials(a, { nsrp: false }), []);
  assert.ok(validateApplicantEssentials({ ...a, fullName: 'Ana' }, { nsrp: false })
    .some(x => x.key === 'firstName'));
  assert.ok(validateApplicantEssentials({ ...a, email: '', phone: '' }, { nsrp: false })
    .some(x => x.key === 'email'));
});
