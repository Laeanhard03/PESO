import test from 'node:test';
import assert from 'node:assert/strict';
import {
  AI_PDF_LIMITS,
  PublicPdfAiError,
  createPublicPdfAiReader,
  mapDocumentReadError,
  normalizeBatchAnswer,
  planPageRanges,
} from './gemini-public-pdf-reader.js';

function answerFor(start, end, { listings = [] } = {}) {
  const pages = [];
  for (let page = start; page <= end; page += 1) {
    pages.push({ page, summary: 'Page ' + page + ' poster.' });
  }
  return { pages, listings };
}

test('page ranges cover every page exactly once', () => {
  const ranges = planPageRanges(13, { batchPages: 8 });
  assert.deepEqual(ranges, [{ start: 1, end: 8 }, { start: 9, end: 13 }]);
  const covered = ranges.flatMap((range) =>
    Array.from({ length: range.end - range.start + 1 }, (_, index) => range.start + index));
  assert.deepEqual(covered, Array.from({ length: 13 }, (_, index) => index + 1));

  assert.deepEqual(planPageRanges(8, { batchPages: 8 }), [{ start: 1, end: 8 }]);
  assert.throws(() => planPageRanges(0), /invalid_page_count|Invalid/i);
});

test('a batch answer is clamped to the requested range and missing pages are reported', () => {
  const normalized = normalizeBatchAnswer({
    pages: [{ page: 9, summary: ' First ' }, { page: 10, summary: 'Second' }],
    listings: [
      { page: 99, company: ' Acme  Corp ', roles: ['Helper', 'helper', '  '], category: 'walk_in_application' },
      { page: 9, company: '', roles: [] },
    ],
  }, { start: 9, end: 12 });

  assert.deepEqual(normalized.pages.map((page) => page.page), [9, 10]);
  assert.equal(normalized.listings.length, 1);
  assert.equal(normalized.listings[0].page, 12, 'a page outside the range is clamped into it');
  assert.equal(normalized.listings[0].company, 'Acme Corp');
  assert.deepEqual(normalized.listings[0].roles, ['Helper']);
  assert.equal(normalized.listings[0].category, 'walk_in_application');
  assert.deepEqual(normalized.missingPages, [11, 12]);
});

test('the reader uploads once, reads every page range, and deletes the uploaded file', async () => {
  const reads = [];
  const deleted = [];
  const reader = createPublicPdfAiReader({
    batchPages: 4,
    upload: async () => ({ name: 'files/abc', uri: 'https://generativelanguage.googleapis.com/v1beta/files/abc' }),
    remove: async (name) => { deleted.push(name); },
    readRange: async ({ start, end, uri }) => {
      reads.push({ start, end, uri });
      return answerFor(start, end, {
        listings: [{ page: start, company: 'Acme', roles: ['Clerk'], category: 'local_recruitment_activity' }],
      });
    },
  });

  const result = await reader.readDocument({ bytes: new Uint8Array(64), pageCount: 10, sourceTitle: 'Compilation' });

  assert.equal(reads.length, 3);
  assert.deepEqual(reads.map((read) => [read.start, read.end]), [[1, 4], [5, 8], [9, 10]]);
  assert.ok(reads.every((read) => read.uri.endsWith('/files/abc')));
  assert.deepEqual(deleted, ['files/abc']);
  assert.equal(result.complete, true);
  assert.deepEqual(result.gaps, []);
  assert.equal(result.pagesRead, 10);
  assert.equal(result.listings.length, 3);
  assert.equal(result.pageCount, 10);
});

test('a truncated answer splits the range so no page is dropped', async () => {
  const attempted = [];
  const reader = createPublicPdfAiReader({
    batchPages: 8,
    upload: async () => ({ name: 'files/abc', uri: 'https://generativelanguage.googleapis.com/v1beta/files/abc' }),
    remove: async () => {},
    readRange: async ({ start, end }) => {
      attempted.push([start, end]);
      if (end - start + 1 > 2) {
        const error = new Error('cut off');
        error.code = 'gemini_response_incomplete';
        throw error;
      }
      return answerFor(start, end);
    },
  });

  const result = await reader.readDocument({ bytes: new Uint8Array(64), pageCount: 8 });

  assert.deepEqual(attempted, [
    [1, 8], [1, 4], [1, 2], [3, 4], [5, 8], [5, 6], [7, 8],
  ]);
  assert.equal(result.complete, true);
  assert.equal(result.pagesRead, 8);
  assert.deepEqual(result.gaps, []);
});

test('a range that cannot be read is reported as a gap instead of a silent success', async () => {
  const reader = createPublicPdfAiReader({
    batchPages: 4,
    batchAttempts: 1,
    upload: async () => ({ name: 'files/abc', uri: 'https://generativelanguage.googleapis.com/v1beta/files/abc' }),
    remove: async () => {},
    readRange: async ({ start, end }) => {
      if (start === 5) {
        const error = new Error('upstream failed');
        error.code = 'gemini_temporarily_unavailable';
        throw error;
      }
      return answerFor(start, end);
    },
    logger: { warn: () => {} },
  });

  const result = await reader.readDocument({ bytes: new Uint8Array(64), pageCount: 8 });

  assert.equal(result.complete, false);
  assert.deepEqual(result.gaps, [{ start: 5, end: 8, code: 'gemini_temporarily_unavailable' }]);
  assert.equal(result.pagesRead, 4);
});

test('a re-read resumes from the ranges already covered instead of paying again', async () => {
  const reads = [];
  const reader = createPublicPdfAiReader({
    batchPages: 4,
    upload: async () => ({ name: 'files/abc', uri: 'https://generativelanguage.googleapis.com/v1beta/files/abc' }),
    remove: async () => {},
    readRange: async ({ start, end }) => {
      reads.push([start, end]);
      return answerFor(start, end, {
        listings: [{ page: start, company: 'Acme', roles: ['Clerk'], category: 'walk_in_application' }],
      });
    },
  });

  const result = await reader.readDocument({
    bytes: new Uint8Array(64),
    pageCount: 12,
    resume: {
      coveredRanges: [{ start: 1, end: 4 }],
      listings: [{ page: 2, company: 'Earlier', roles: ['Helper'] }],
      pages: [{ page: 1, summary: 'Cover.' }, { page: 2, summary: 'Earlier notice.' }],
    },
  });

  assert.deepEqual(reads, [[5, 8], [9, 12]], 'covered pages are not requested again');
  assert.equal(result.complete, true);
  assert.ok(result.listings.some((listing) => listing.company === 'Earlier'), 'earlier notices are kept');
  assert.equal(result.listings.length, 3);
  assert.equal(result.pagesRead, 10);
});

test('an exhausted quota stops the run instead of firing doomed batches', async () => {
  const reads = [];
  const reader = createPublicPdfAiReader({
    batchPages: 4,
    batchAttempts: 1,
    upload: async () => ({ name: 'files/abc', uri: 'https://generativelanguage.googleapis.com/v1beta/files/abc' }),
    remove: async () => {},
    readRange: async ({ start, end }) => {
      reads.push([start, end]);
      if (start === 5) {
        const error = new Error('rate limited');
        error.code = 'gemini_rate_limited';
        throw error;
      }
      return answerFor(start, end);
    },
    logger: { warn: () => {} },
  });

  const result = await reader.readDocument({ bytes: new Uint8Array(64), pageCount: 12 });

  assert.deepEqual(reads, [[1, 4], [5, 8]], 'later ranges are not attempted');
  assert.equal(result.complete, false);
  assert.deepEqual(result.coveredRanges, [{ start: 1, end: 4 }]);
  assert.deepEqual(result.gaps, [
    { start: 5, end: 8, code: 'gemini_rate_limited' },
    { start: 9, end: 12, code: 'gemini_rate_limited' },
  ]);
});

test('one key is pinned for the upload, every batch and the delete', async () => {
  const seen = [];
  const reader = createPublicPdfAiReader({
    batchPages: 4,
    withKey: async (fn) => fn('key-a'),
    upload: async (_bytes, apiKey) => {
      seen.push(['upload', apiKey]);
      return { name: 'files/x', uri: 'https://generativelanguage.googleapis.com/v1beta/files/x' };
    },
    remove: async (name, apiKey) => { seen.push(['remove', name, apiKey]); },
    readRange: async ({ apiKey, start, end }) => {
      seen.push(['read', apiKey]);
      return answerFor(start, end);
    },
  });

  await reader.readDocument({ bytes: new Uint8Array(8), pageCount: 8 });

  assert.deepEqual(seen, [
    ['upload', 'key-a'],
    ['read', 'key-a'],
    ['read', 'key-a'],
    ['remove', 'files/x', 'key-a'],
  ]);
});

test('provider failures are mapped to the gap codes the reader reasons about', () => {
  const quota = new Error('quota');
  quota.status = 429;
  assert.equal(mapDocumentReadError(quota).code, 'gemini_rate_limited');

  const denied = new Error('permission denied');
  denied.status = 403;
  assert.equal(mapDocumentReadError(denied).code, 'gemini_configuration_error');

  const truncated = new Error('answer cut off');
  truncated.code = 'RESPONSE_TRUNCATED';
  assert.equal(mapDocumentReadError(truncated).code, 'response_truncated');

  const outage = new Error('unavailable');
  outage.status = 503;
  assert.equal(mapDocumentReadError(outage).code, 'gemini_temporarily_unavailable');

  const already = new PublicPdfAiError('invalid_page_count');
  assert.equal(mapDocumentReadError(already), already);
});

test('the configured batch size stays within the provider document-part limit', () => {
  assert.ok(AI_PDF_LIMITS.batchPages >= 1);
  assert.ok(AI_PDF_LIMITS.batchAttempts >= 1);
});
