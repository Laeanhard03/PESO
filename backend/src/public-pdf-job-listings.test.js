import test from 'node:test';
import assert from 'node:assert/strict';
import { JOB_POSTING_CATEGORIES } from './job_postings.js';
import {
  PUBLIC_PDF_JOB_LISTINGS,
  syncPublicPdfJobListings,
} from './public-pdf-job-listings.js';

class MemoryCollection {
  constructor(rows = []) { this.rows = structuredClone(rows); }
  async findOne(filter) {
    return structuredClone(this.rows.find((row) =>
      Object.entries(filter).every(([key, value]) => row[key] === value),
    ) || null);
  }
  async updateOne(filter, update, options = {}) {
    let row = this.rows.find((item) =>
      Object.entries(filter).every(([key, value]) => item[key] === value),
    );
    if (!row && options.upsert) {
      row = { ...filter, ...structuredClone(update.$setOnInsert || {}) };
      this.rows.push(row);
      return { upsertedCount: 1, matchedCount: 0 };
    }
    return { upsertedCount: 0, matchedCount: row ? 1 : 0 };
  }
}

function testDb({ indexed = true } = {}) {
  const sources = new MemoryCollection([
    {
      sourceId: 'montalban-walk-in-official',
      syncStatus: indexed ? 'ready' : 'error',
      pagesExtracted: indexed ? 13 : 0,
      chunkCount: indexed ? 15 : 0,
      contentSha256: 'a'.repeat(64),
      lastSuccessfulSyncAt: indexed ? new Date('2026-10-18T07:19:53.505Z') : null,
    },
    {
      sourceId: 'montalban-para-sa-montalbeno',
      syncStatus: 'ready',
      pagesExtracted: 64,
      chunkCount: 64,
      contentSha256: 'b'.repeat(64),
      lastSuccessfulSyncAt: new Date('2026-10-18T07:30:05.959Z'),
    },
  ]);
  const jobs = new MemoryCollection();
  return {
    db: { collection(name) { return name === 'publicInformationSources' ? sources : jobs; } },
    jobs,
  };
}

test('public PDF job groups use only the two existing categories and exact allowlisted source URLs', () => {
  assert.ok(PUBLIC_PDF_JOB_LISTINGS.length >= 5);
  assert.ok(PUBLIC_PDF_JOB_LISTINGS.every((item) =>
    [JOB_POSTING_CATEGORIES.WALK_IN, JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY]
      .includes(item.category),
  ));
  assert.ok(PUBLIC_PDF_JOB_LISTINGS.every((item) =>
    [
      'https://montalban.gov.ph/wp-content/uploads/2020/07/walk-in-compilation.pdf',
      'https://dev.montalban.gov.ph/wp-content/uploads/2020/07/PARA-SA-MONTALBENO.pdf',
    ].includes(item.sourceUrl),
  ));
  assert.ok(PUBLIC_PDF_JOB_LISTINGS.every((item) =>
    item.availabilityNote.includes('not confirmed') &&
    item.sourcePageStart > 0 &&
    item.sourcePageEnd >= item.sourcePageStart,
  ));
});

test('dry run reports cards without writing and skips sources that were not indexed successfully', async () => {
  const { db, jobs } = testDb({ indexed: false });
  const report = await syncPublicPdfJobListings({
    db,
    apply: false,
    now: () => new Date('2026-10-18T08:00:00Z'),
  });

  assert.equal(report.apply, false);
  assert.equal(jobs.rows.length, 0);
  assert.ok(report.results.some((result) => result.reason === 'source_not_successfully_indexed'));
});

test('apply imports source-backed cards with correct categories and lifecycle', async () => {
  const { db, jobs } = testDb();
  const checkedAt = new Date('2026-10-18T08:00:00Z');
  const report = await syncPublicPdfJobListings({ db, apply: true, now: () => checkedAt });

  assert.equal(report.ok, true);
  assert.equal(jobs.rows.length, PUBLIC_PDF_JOB_LISTINGS.length);
  const walkIn = jobs.rows.find((job) => job.category === JOB_POSTING_CATEGORIES.WALK_IN);
  const lra = jobs.rows.find((job) => job.category === JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY);

  assert.ok(walkIn);
  assert.equal(walkIn.expiresAt, null);
  assert.equal(walkIn.vacancies, null);
  assert.ok(walkIn.sourceUrl.startsWith('https://'));
  assert.ok(walkIn.description.includes(walkIn.availabilityNote));

  assert.ok(lra);
  assert.equal(lra.expiresAt.getTime() - lra.createdAt.getTime(), 24 * 60 * 60 * 1000);
  assert.equal(lra.vacancies, null);
  assert.equal(lra.isPublicPdfListing, true);
});

test('re-running the importer does not duplicate cards or extend an LRA expiry', async () => {
  const { db, jobs } = testDb();
  let now = new Date('2026-10-18T08:00:00Z');
  await syncPublicPdfJobListings({ db, apply: true, now: () => now });
  const lraBefore = jobs.rows.find((job) => job.category === JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY);
  const originalExpiry = lraBefore.expiresAt.getTime();

  now = new Date('2026-10-18T15:00:00Z');
  const report = await syncPublicPdfJobListings({ db, apply: true, now: () => now });

  assert.equal(jobs.rows.length, PUBLIC_PDF_JOB_LISTINGS.length);
  assert.ok(report.results.every((result) => result.action === 'already_imported'));
  assert.equal(
    jobs.rows.find((job) => job.sourceFingerprint === lraBefore.sourceFingerprint).expiresAt.getTime(),
    originalExpiry,
  );
});
