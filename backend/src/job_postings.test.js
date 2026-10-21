import test from 'node:test';
import assert from 'node:assert/strict';
import {
  JOB_POSTING_CATEGORIES,
  createJobPostingRecord,
  isJobPostingVisible,
  publicJobPosting,
} from './job_postings.js';

const baseInput = {
  title: 'Office Assistant',
  company: 'Montalban Demo Employer',
  location: 'Rodriguez, Rizal',
  salary: 'PHP 16,000 - 20,000',
  employmentType: 'Full-time',
  description: 'Support day-to-day office operations.',
  requirements: ['Communication', 'Organization'],
  vacancies: 2,
};

test('Walk-in Application never receives a time-based expiry', () => {
  const createdAt = new Date('2026-10-17T06:00:00.000Z');
  const job = createJobPostingRecord(
    { ...baseInput, category: JOB_POSTING_CATEGORIES.WALK_IN },
    'verified-admin',
    createdAt,
  );

  assert.equal(job.expiresAt, null);
  assert.equal(job.status, 'active');
  assert.equal(isJobPostingVisible(job, new Date('2036-10-17T06:00:00.000Z')), true);
});

test('Local Recruitment Activity expires exactly 24 hours after creation', () => {
  const createdAt = new Date('2026-10-17T06:00:00.000Z');
  const job = createJobPostingRecord(
    { ...baseInput, category: JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY },
    'verified-admin',
    createdAt,
  );

  assert.equal(job.expiresAt.toISOString(), '2026-10-18T06:00:00.000Z');
  assert.equal(isJobPostingVisible(job, new Date('2026-10-18T05:59:59.999Z')), true);
  assert.equal(isJobPostingVisible(job, new Date('2026-10-18T06:00:00.000Z')), false);
});

test('inactive jobs stay hidden even when they do not expire', () => {
  const job = createJobPostingRecord(
    { ...baseInput, category: JOB_POSTING_CATEGORIES.WALK_IN },
    'verified-admin',
    new Date('2026-10-17T06:00:00.000Z'),
  );
  assert.equal(isJobPostingVisible({ ...job, status: 'inactive' }), false);
});

test('job category, required fields and vacancy count are validated', () => {
  assert.throws(() => createJobPostingRecord({ ...baseInput, category: 'unknown' }, 'admin'));
  assert.throws(() => createJobPostingRecord({ category: JOB_POSTING_CATEGORIES.WALK_IN }, 'admin'));
  assert.throws(() => createJobPostingRecord({ ...baseInput, vacancies: 0, category: JOB_POSTING_CATEGORIES.WALK_IN }, 'admin'));
});

test('public responses expose stable ISO lifecycle values and omit owner identity', () => {
  const job = createJobPostingRecord(
    { ...baseInput, category: JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY },
    'private-owner-uid',
    new Date('2026-10-17T06:00:00.000Z'),
  );
  const response = publicJobPosting({ ...job, _id: 'job-id-1' });

  assert.equal(response.id, 'job-id-1');
  assert.equal(response.createdAt, '2026-10-17T06:00:00.000Z');
  assert.equal(response.expiresAt, '2026-10-18T06:00:00.000Z');
  assert.equal(Object.hasOwn(response, 'createdBy'), false);
});
test('public PDF feed responses expose source provenance without inventing vacancy counts', () => {
  const sourceSyncAt = new Date('2026-10-18T07:30:05.959Z');
  const response = publicJobPosting({
    ...createJobPostingRecord(
      { ...baseInput, category: JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY },
      'public-pdf-importer',
      new Date('2026-10-18T08:00:00.000Z'),
    ),
    _id: 'public-pdf-job-1',
    isPublicPdfListing: true,
    vacancies: null,
    listingLabel: 'Multiple roles',
    sourceTitle: 'Para sa Montalbeño',
    sourceUrl: 'https://dev.montalban.gov.ph/wp-content/uploads/2020/07/PARA-SA-MONTALBENO.pdf',
    sourcePageStart: 2,
    sourcePageEnd: 2,
    availabilityNote: 'Current availability is not confirmed.',
    sourceLastSuccessfulSyncAt: sourceSyncAt,
    sourceFingerprint: 'internal-only-fingerprint',
    sourceContentSha256: 'internal-only-hash',
  });

  assert.equal(response.vacancies, null);
  assert.equal(response.isPublicPdfListing, true);
  assert.equal(response.listingLabel, 'Multiple roles');
  assert.equal(response.description.startsWith('[PESO_PUBLIC_PDF_LISTING'), false);
  assert.equal(response.sourcePageStart, 2);
  assert.equal(response.sourcePageEnd, 2);
  assert.equal(response.sourceLastSuccessfulSyncAt, sourceSyncAt.toISOString());
  assert.equal(Object.hasOwn(response, 'sourceFingerprint'), false);
  assert.equal(Object.hasOwn(response, 'sourceContentSha256'), false);
  assert.equal(Object.hasOwn(response, 'createdBy'), false);
});
