import test from 'node:test';
import assert from 'node:assert/strict';
import { documentSummary } from '../src/residency.js';
import { hasStructuredResume } from '../src/resume-preview.js';

test('pending drafts are not submitted documents', () => {
  const draft = {
    resumeData: { pendingDraft: { draftUpdatedAt: '2026-10-22T00:00:00Z',
      fields: [{ value: 'Example' }] } },
    pesoFormData: { pendingDraft: { dateOfBirth: '2000-02-29',
      draftUpdatedAt: '2026-10-22T00:00:00Z' } },
  };
  assert.equal(documentSummary(draft).resumeSubmitted, false);
  assert.equal(documentSummary(draft).formSubmitted, false);
  assert.equal(hasStructuredResume(draft), false);
});

test('submitted documents retain their status when new drafts exist', () => {
  const data = {
    resumeData: { documentType: 'Resume Builder',
      completedAt: '2026-10-22T00:00:00Z',
      applicantEssentials: { education: 'Senior High School' },
      pendingDraft: { draftUpdatedAt: '2026-10-22T00:01:00Z' } },
    pesoFormData: { documentType: 'NSRP Form 1',
      completedAt: '2026-10-22T00:00:00Z',
      entries: [{ label: 'Surname', value: 'Example' }],
      pendingDraft: { draftUpdatedAt: '2026-10-22T00:01:00Z' } },
  };
  assert.equal(documentSummary(data).resumeSubmitted, true);
  assert.equal(documentSummary(data).formSubmitted, true);
  assert.equal(hasStructuredResume(data), true);
});
