import assert from 'node:assert/strict';
import { test } from 'node:test';

import { buildResumeCareerPrefillUpdates } from './resumeCareerPrefill.js';

const choices = {
  education: ['College Graduate', 'Senior High School'],
  experience: ['No previous work experience', 'With previous work experience'],
  skillsStage: ['New entrant / still learning', 'Has skills or training'],
};

test('late draft restore never overwrites any career field already touched by the applicant', () => {
  const updates = buildResumeCareerPrefillUpdates(
    { education: 'Senior High School', experience: 'With previous work experience',
      skillsStage: 'Has skills or training', skills: 'Welding' },
    { education: true, experience: true, skillsStage: true, skills: true },
    choices,
  );
  assert.deepEqual(updates, {});
});

test('initial draft restore applies valid saved values and normalizes invalid choices', () => {
  const updates = buildResumeCareerPrefillUpdates(
    { education: 'College Graduate', experience: 'Invalid value',
      skillsStage: 'New entrant / still learning', skills: 42 },
    {},
    choices,
  );
  assert.deepEqual(updates, {
    education: 'College Graduate',
    experience: '',
    skillsStage: 'New entrant / still learning',
    skills: '',
  });
});

test('late restore preserves touched fields while filling fields the applicant has not changed', () => {
  const updates = buildResumeCareerPrefillUpdates(
    { education: 'Senior High School', experience: 'With previous work experience',
      skillsStage: 'Has skills or training', skills: 'Welding' },
    { education: true, skillsStage: true },
    choices,
  );
  assert.deepEqual(updates, {
    experience: 'With previous work experience',
    skills: 'Welding',
  });
});
