import test from 'node:test';
import assert from 'node:assert/strict';
import { JOB_POSTING_CATEGORIES } from './job_postings.js';
import {
  AI_JOB_SOURCE,
  buildAiJobRecords,
  noticeFingerprintFor,
  retireLegacyPublicPdfCards,
  roleFingerprintFor,
  slugify,
  syncAiJobListingsFromRecords,
  syncAllPublicPdfAiJobs,
  syncPublicPdfAiJobs,
} from './public-pdf-ai-listings.js';

const HOUR_MS = 60 * 60 * 1000;

function matches(row, filter) {
  return Object.entries(filter).every(([key, expected]) => {
    const value = row[key];
    if (expected && typeof expected === 'object' && !Array.isArray(expected)) {
      if ('$in' in expected) return expected.$in.includes(value);
      if ('$nin' in expected) return !expected.$nin.includes(value);
      if ('$ne' in expected) return value !== expected.$ne;
      if ('$gt' in expected) return Number(value) > Number(expected.$gt);
    }
    return value === expected;
  });
}

class FakeCollection {
  constructor(rows = []) { this.rows = structuredClone(rows); }
  find(filter = {}) {
    const selected = () => this.rows.filter((row) => matches(row, filter));
    const cursor = {
      project: () => cursor,
      sort: () => cursor,
      limit: () => cursor,
      toArray: async () => structuredClone(selected()),
    };
    return cursor;
  }
  async findOne(filter = {}) {
    return structuredClone(this.rows.find((row) => matches(row, filter)) || null);
  }
  async countDocuments(filter = {}) {
    return this.rows.filter((row) => matches(row, filter)).length;
  }
  async updateOne(filter, update, options = {}) {
    let row = this.rows.find((item) => matches(item, filter));
    if (!row && options.upsert) {
      row = { ...filter, ...structuredClone(update.$setOnInsert || {}), ...structuredClone(update.$set || {}) };
      this.rows.push(row);
      return { upsertedCount: 1, matchedCount: 0 };
    }
    if (!row) return { upsertedCount: 0, matchedCount: 0 };
    Object.assign(row, structuredClone(update.$set || {}));
    return { upsertedCount: 0, matchedCount: 1 };
  }
  async updateMany(filter, update) {
    const rows = this.rows.filter((row) => matches(row, filter));
    for (const row of rows) Object.assign(row, structuredClone(update.$set || {}));
    return { modifiedCount: rows.length };
  }
}

const SOURCE = {
  sourceId: 'montalban-walk-in-official',
  title: 'Walk-in Compilation',
  url: 'https://montalban.gov.ph/wp-content/uploads/2020/07/walk-in-compilation.pdf',
};

const LISTINGS = [
  {
    page: 2,
    company: 'Home Credit',
    title: '',
    roles: ['Sales Associate', 'Field Officer'],
    location: 'Montalban, Rizal',
    requirements: ['College level'],
    contact: 'Walk in at PESO',
    category: 'local_recruitment_activity',
    summary: 'Hiring on-site this week.',
  },
  {
    page: 4,
    company: 'GCCS & Associates Corp.',
    title: '',
    roles: [],
    location: '',
    requirements: [],
    contact: '',
    category: 'walk_in_application',
    summary: 'Walk-in applicants accepted.',
  },
];

test('slugs are stable and safe for fingerprints', () => {
  assert.equal(slugify('  Home  Credit  '), 'home-credit');
  assert.equal(slugify('GCCS & Associates Corp.'), 'gccs-associates-corp');
  assert.equal(slugify('!!!'), 'unknown');
  assert.equal(slugify('a'.repeat(100)).length, 60);
});

test('each notice becomes a card and each role becomes its own card under it', () => {
  const now = new Date('2026-10-19T04:00:00Z');
  const records = buildAiJobRecords({ source: SOURCE, listings: LISTINGS, now });

  assert.equal(records.length, 4);
  const notices = records.filter((record) => record.aiListingKind === 'notice');
  const roles = records.filter((record) => record.aiListingKind === 'role');
  assert.equal(notices.length, 2);
  assert.equal(roles.length, 2);

  const homeCredit = notices.find((record) => record.company === 'Home Credit');
  assert.equal(homeCredit.listingLabel, '2 roles');
  assert.equal(homeCredit.category, JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY);
  assert.equal(homeCredit.parentFingerprint, null);
  assert.equal(homeCredit.createdBy, AI_JOB_SOURCE);
  assert.equal(homeCredit.expiresAt.getTime(), now.getTime() + 24 * HOUR_MS);
  assert.ok(homeCredit.description.includes('Sales Associate'));
  assert.ok(homeCredit.description.includes('Walk in at PESO'));
  assert.ok(homeCredit.availabilityNote.includes('not confirmed'));

  const homeCreditRoles = roles.filter((record) => record.parentFingerprint === homeCredit.sourceFingerprint);
  assert.deepEqual(homeCreditRoles.map((record) => record.title), [
    'Sales Associate — Home Credit',
    'Field Officer — Home Credit',
  ]);
  assert.equal(homeCreditRoles[0].category, homeCredit.category);
  assert.equal(homeCreditRoles[0].sourcePageStart, 2);
  assert.equal(homeCreditRoles[0].availabilityNote, homeCredit.availabilityNote);

  // Newest first is the feed order, so a notice must outrank its own roles.
  const ordered = [...records].sort((a, b) => b.createdAt - a.createdAt);
  assert.equal(ordered.indexOf(homeCredit) + 1, ordered.indexOf(homeCreditRoles[0]));
  assert.equal(ordered.indexOf(homeCreditRoles[0]) + 1, ordered.indexOf(homeCreditRoles[1]));

  const walkIn = notices.find((record) => record.company.startsWith('GCCS'));
  assert.equal(walkIn.category, JOB_POSTING_CATEGORIES.WALK_IN);
  assert.equal(walkIn.expiresAt, null);
  assert.equal(walkIn.listingLabel, 'Notice');
});

test('fingerprints are derived from the source, company and first page', () => {
  const notice = noticeFingerprintFor('src', { company: 'Acme', page: 7 });
  assert.equal(notice, 'public-pdf-ai:src:notice:acme-p7');
  assert.equal(roleFingerprintFor('src', { company: 'Acme', page: 7 }, 'Clerk'),
    'public-pdf-ai:src:notice:acme-p7:role:clerk');
});

test('dry run reports counts without writing any card', async () => {
  const jobs = new FakeCollection();
  const db = { collection: (name) => (name === 'jobPostings' ? jobs : new FakeCollection()) };
  const records = buildAiJobRecords({ source: SOURCE, listings: LISTINGS, now: new Date() });

  const report = await syncAiJobListingsFromRecords({ db, source: SOURCE, records, apply: false });

  assert.equal(report.apply, false);
  assert.equal(report.total, 4);
  assert.equal(report.notices, 2);
  assert.equal(report.roles, 2);
  assert.equal(report.created, 4);
  assert.equal(jobs.rows.length, 0);
});

test('applying renews expiry on every sync and retires cards that disappeared', async () => {
  const jobs = new FakeCollection();
  const db = { collection: (name) => (name === 'jobPostings' ? jobs : new FakeCollection()) };

  const first = new Date('2026-10-19T04:00:00Z');
  const firstRecords = buildAiJobRecords({ source: SOURCE, listings: LISTINGS, now: first });
  await syncAiJobListingsFromRecords({ db, source: SOURCE, records: firstRecords, apply: true, now: () => first });

  const homeCredit = jobs.rows.find((row) => row.company === 'Home Credit' && row.aiListingKind === 'notice');
  const originalCreatedAt = homeCredit.createdAt.getTime();
  assert.equal(homeCredit.expiresAt.getTime(), first.getTime() + 24 * HOUR_MS);

  const later = new Date(first.getTime() + 20 * HOUR_MS);
  const secondRecords = buildAiJobRecords({ source: SOURCE, listings: [LISTINGS[0]], now: later });
  const report = await syncAiJobListingsFromRecords({ db, source: SOURCE, records: secondRecords, apply: true, now: () => later });

  assert.equal(report.created, 0);
  assert.equal(report.renewed, 3);
  assert.equal(report.superseded, 1);

  const renewed = jobs.rows.find((row) => row.company === 'Home Credit' && row.aiListingKind === 'notice');
  assert.equal(renewed.createdAt.getTime(), originalCreatedAt, 'createdAt is written once');
  assert.equal(renewed.expiresAt.getTime(), later.getTime() + 24 * HOUR_MS, 'expiry is renewed');

  const superseded = jobs.rows.find((row) => row.company.startsWith('GCCS'));
  assert.equal(superseded.status, 'inactive');
  assert.equal(superseded.supersededAt.getTime(), later.getTime());
});

test('publishing reads the stored AI listings for one source', async () => {
  const sources = new FakeCollection([{
    ...SOURCE,
    aiListings: LISTINGS,
    aiErrorCode: null,
  }]);
  const jobs = new FakeCollection();
  const db = {
    collection: (name) => (name === 'publicInformationSources' ? sources : jobs),
  };

  const report = await syncPublicPdfAiJobs({ db, sourceId: SOURCE.sourceId, apply: true, now: () => new Date('2026-10-19T04:00:00Z') });

  assert.equal(report.ok, true);
  assert.equal(report.total, 4);
  assert.equal(jobs.rows.length, 4);
  assert.ok(jobs.rows.every((row) => row.createdBy === AI_JOB_SOURCE && row.isPublicPdfListing === true));
});

test('a source without a completed read publishes nothing and says so', async () => {
  const sources = new FakeCollection([{ ...SOURCE, aiListings: [], aiErrorCode: 'gemini_temporarily_unavailable' }]);
  const jobs = new FakeCollection();
  const db = { collection: (name) => (name === 'publicInformationSources' ? sources : jobs) };

  const report = await syncPublicPdfAiJobs({ db, sourceId: SOURCE.sourceId, apply: true });

  assert.equal(report.ok, false);
  assert.equal(report.reason, 'no_ai_listings');
  assert.equal(report.aiErrorCode, 'gemini_temporarily_unavailable');
  assert.equal(jobs.rows.length, 0);
});

test('a mirror of a document another source read does not duplicate its cards', async () => {
  const sources = new FakeCollection([{
    ...SOURCE,
    sourceId: 'montalban-walk-in-development',
    aiListings: LISTINGS,
    aiReusedFrom: 'montalban-walk-in-official',
  }]);
  const jobs = new FakeCollection();
  const db = { collection: (name) => (name === 'publicInformationSources' ? sources : jobs) };

  const report = await syncPublicPdfAiJobs({ db, sourceId: 'montalban-walk-in-development', apply: true });

  assert.equal(report.skipped, true);
  assert.equal(report.reason, 'duplicate_of_read_source');
  assert.equal(report.duplicateOf, 'montalban-walk-in-official');
  assert.equal(jobs.rows.length, 0);
});

test('a partial read never retires cards for the pages it did not read', async () => {
  const sources = new FakeCollection([{
    ...SOURCE,
    aiComplete: false,
    aiListings: [LISTINGS[0]],
  }]);
  const jobs = new FakeCollection([
    { createdBy: AI_JOB_SOURCE, publicPdfSourceId: SOURCE.sourceId, sourceFingerprint: 'old-gccs-card', status: 'active' },
  ]);
  const db = { collection: (name) => (name === 'publicInformationSources' ? sources : jobs) };

  const report = await syncPublicPdfAiJobs({ db, sourceId: SOURCE.sourceId, apply: true, now: () => new Date('2026-10-19T04:00:00Z') });

  assert.equal(report.allowSupersede, false);
  assert.equal(report.superseded, 0);
  assert.equal(report.supersedeSkipped, 1);
  assert.equal(jobs.rows.find((row) => row.sourceFingerprint === 'old-gccs-card').status, 'active');
});

test('the aggregate count does not treat a skipped mirror as published', async () => {
  const sources = new FakeCollection([
    { ...SOURCE, aiListings: LISTINGS, aiComplete: true },
    { ...SOURCE, sourceId: 'montalban-walk-in-development', aiListings: LISTINGS, aiReusedFrom: SOURCE.sourceId },
  ]);
  const jobs = new FakeCollection();
  const db = { collection: (name) => (name === 'publicInformationSources' ? sources : jobs) };

  const report = await syncAllPublicPdfAiJobs({ db, apply: true, now: () => new Date('2026-10-19T04:00:00Z') });

  assert.equal(report.results.length, 2);
  assert.equal(report.published, 1);
  assert.equal(report.ok, true);
  assert.equal(jobs.rows.length, 4, 'only the source that was really read publishes cards');
});

test('legacy hand-written cards are retired, not deleted', async () => {
  const jobs = new FakeCollection([
    { createdBy: 'public-pdf-importer', status: 'active', title: 'Old card' },
    { createdBy: 'public-pdf-importer', status: 'inactive', title: 'Already retired' },
    { createdBy: 'admin', status: 'active', title: 'Manual card' },
  ]);
  const db = { collection: () => jobs };

  const report = await retireLegacyPublicPdfCards({ db, apply: true, now: () => new Date('2026-10-19T04:00:00Z') });

  assert.equal(report.retired, 1);
  assert.equal(jobs.rows.length, 3);
  assert.equal(jobs.rows[0].status, 'inactive');
  assert.equal(jobs.rows[2].status, 'active', 'non-imported cards are untouched');
});

test('two roles never inherit each other\'s criteria or ambiguous notice criteria', () => {
  const records = buildAiJobRecords({ source: SOURCE, listings: [{
    page: 13, company: 'Example Corp', roles: ['Driver', 'Sales Associate'],
    requirements: [
      'Driver: Must hold driver license',
      'Sales Associate: Must have sales experience',
      'At least college graduate',
      'MALE NOT MORE THAN 35 YRS OLD.',
    ], category: 'walk_in_application',
  }] });
  const notice = records.find(x => x.aiListingKind === 'notice');
  const driver = records.find(x => x.title.startsWith('Driver'));
  const sales = records.find(x => x.title.startsWith('Sales Associate'));
  assert.ok(notice.requirements.some(x => x.includes('college')));
  assert.ok(driver.requirements.some(x => x.includes('Driver:')));
  assert.ok(!driver.requirements.some(x => x.includes('Sales Associate:')));
  assert.ok(sales.requirements.some(x => x.includes('Sales Associate:')));
  assert.ok(!sales.requirements.some(x => x.includes('Driver:')));
  assert.ok(driver.unattributedRequirements.some(x => x.includes('college')));
  assert.equal(driver.sourceRoleCount, 2);
  assert.equal(driver.requirementScope, 'explicit_role');
  assert.ok(!driver.requirements.some(x => x.includes('MALE')));
});

test('deleted source-backed cards remain deleted after subsequent PDF synchronization', async () => {
  const jobs = new FakeCollection();
  const db = { collection: (name) => (name === 'jobPostings' ? jobs : new FakeCollection()) };
  const first = new Date('2026-10-19T04:00:00Z');
  const records = buildAiJobRecords({ source: SOURCE, listings: LISTINGS, now: first });
  await syncAiJobListingsFromRecords({ db, source: SOURCE, records, apply: true, now: () => first });
  const target = jobs.rows.find((row) => row.aiListingKind === 'role');
  assert.ok(target);
  target.status = 'deleted';
  target.deletedBy = 'verified-admin';
  target.deletedAt = first;
  const later = new Date('2026-10-21T12:00:00Z');
  const refreshed = buildAiJobRecords({ source: SOURCE, listings: LISTINGS, now: later });
  const summary = await syncAiJobListingsFromRecords({
    db, source: SOURCE, records: refreshed, apply: true, now: () => later,
  });
  const stillDeleted = jobs.rows.find((row) => row.sourceFingerprint === target.sourceFingerprint);
  assert.equal(summary.suppressedDeleted, 1);
  assert.equal(stillDeleted.status, 'deleted');
  assert.equal(stillDeleted.deletedBy, 'verified-admin');
  assert.equal(jobs.rows.filter((row) => row.sourceFingerprint === target.sourceFingerprint).length, 1);
});
