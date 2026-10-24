import assert from 'node:assert/strict';
import test from 'node:test';
import { JOB_POSTING_CATEGORIES } from './job_postings.js';
import { parseJobFeedQuery, visibleJobFilter } from './job-feed-service.js';

test('public and signed-in job feed accept all four supported job categories', () => {
  const values = [
    JOB_POSTING_CATEGORIES.WALK_IN,
    JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY,
    JOB_POSTING_CATEGORIES.SEAP,
    JOB_POSTING_CATEGORIES.GIP,
  ];
  for (const category of values) {
    assert.equal(parseJobFeedQuery({ category }).category, category);
    const filter = visibleJobFilter({ category }, new Date('2026-10-24T00:00:00.000Z'));
    assert.equal(filter.$and.at(-1).category, category);
  }
});

test('job feed still rejects unknown categories', () => {
  assert.throws(() => parseJobFeedQuery({ category: 'not-a-peso-category' }), (error) => {
    assert.equal(error.code, 'invalid_job_category');
    return true;
  });
});
