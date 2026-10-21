import test from 'node:test';
import assert from 'node:assert/strict';

import {
  PUBLIC_PDF_SOURCES,
  PublicPdfIngestionError,
  chunkPdfPages,
  createPublicPdfIngestion,
  downloadPublicPdf,
  resolveApprovedSource,
  sha256,
} from './public-pdf-ingestion.js';

function pdfBytes(label) {
  return Buffer.from('%PDF-1.7\n' + label + '\n%%EOF', 'utf8');
}

function pdfResponse(bytes, {
  status = 200,
  contentType = 'application/pdf',
  etag = '"test-etag"',
  lastModified = 'Sun, 18 Oct 2026 00:00:00 GMT',
  contentLength = bytes?.length,
} = {}) {
  const headers = new Headers();
  if (contentType) headers.set('content-type', contentType);
  if (etag) headers.set('etag', etag);
  if (lastModified) headers.set('last-modified', lastModified);
  if (contentLength !== null && contentLength !== undefined) {
    headers.set('content-length', String(contentLength));
  }
  return new Response(bytes || null, { status, headers });
}

function matches(doc, filter = {}) {
  for (const [key, value] of Object.entries(filter)) {
    if (key === '$text') {
      const needle = String(value?.$search || '').toLowerCase().split(/\s+/).filter(Boolean);
      const haystack = String(doc.text || '').toLowerCase();
      if (!needle.some((term) => haystack.includes(term.replace(/["']/g, '')))) return false;
      continue;
    }
    const actual = doc[key];
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      if ('$in' in value && !value.$in.some((candidate) => Array.isArray(actual)
        ? actual.includes(candidate)
        : actual === candidate)) return false;
      if ('$ne' in value) {
        if (Array.isArray(actual) && Array.isArray(value.$ne)) {
          if (JSON.stringify(actual) === JSON.stringify(value.$ne)) return false;
        } else if (actual === value.$ne) return false;
      }
      if ('$exists' in value && Boolean(actual !== undefined) !== value.$exists) return false;
      if ('$size' in value && (!Array.isArray(actual) || actual.length !== value.$size)) return false;
    } else if (Array.isArray(actual)) {
      if (!actual.includes(value)) return false;
    } else if (actual !== value) {
      return false;
    }
  }
  return true;
}

function applyUpdate(doc, update, isInsert) {
  if (isInsert && update.$setOnInsert) Object.assign(doc, structuredClone(update.$setOnInsert));
  if (update.$set) Object.assign(doc, structuredClone(update.$set));
  for (const [field, value] of Object.entries(update.$addToSet || {})) {
    const values = doc[field] || (doc[field] = []);
    if (!values.includes(value)) values.push(value);
  }
  for (const [field, value] of Object.entries(update.$pull || {})) {
    doc[field] = (doc[field] || []).filter((item) => item !== value);
  }
  for (const field of Object.keys(update.$unset || {})) delete doc[field];
}

function assertNoConflictingUpdatePaths(update) {
  const paths = [];
  for (const operator of ['$setOnInsert', '$set', '$addToSet', '$pull', '$unset']) {
    for (const path of Object.keys(update[operator] || {})) {
      const conflict = paths.find((existing) => existing === path ||
        existing.startsWith(path + '.') || path.startsWith(existing + '.'));
      if (conflict) throw new Error('MongoDB update path conflict: ' + conflict + ' / ' + path);
      paths.push(path);
    }
  }
}
class MemoryCollection {
  constructor() {
    this.docs = [];
    this.indexes = [];
  }

  async createIndex(keys, options = {}) {
    this.indexes.push({ keys, options });
    return 'mock-index';
  }

  async findOne(filter) {
    const doc = this.docs.find((item) => matches(item, filter));
    return doc ? structuredClone(doc) : null;
  }

  async updateOne(filter, update, options = {}) {
    assertNoConflictingUpdatePaths(update);
    let doc = this.docs.find((item) => matches(item, filter));
    if (!doc && options.upsert) {
      doc = {};
      for (const [key, value] of Object.entries(filter)) {
        if (key.startsWith('$') || (value && typeof value === 'object')) continue;
        doc[key] = value;
      }
      applyUpdate(doc, update, true);
      this.docs.push(doc);
      return { upsertedCount: 1, matchedCount: 0, modifiedCount: 0 };
    }
    if (!doc) return { upsertedCount: 0, matchedCount: 0, modifiedCount: 0 };
    applyUpdate(doc, update, false);
    return { upsertedCount: 0, matchedCount: 1, modifiedCount: 1 };
  }

  async updateMany(filter, update) {
    assertNoConflictingUpdatePaths(update);
    let modifiedCount = 0;
    for (const doc of this.docs.filter((item) => matches(item, filter))) {
      applyUpdate(doc, update, false);
      modifiedCount += 1;
    }
    return { matchedCount: modifiedCount, modifiedCount };
  }

  async deleteMany(filter) {
    const before = this.docs.length;
    this.docs = this.docs.filter((doc) => !matches(doc, filter));
    return { deletedCount: before - this.docs.length };
  }

  find(filter = {}) {
    let rows = this.docs.filter((doc) => matches(doc, filter)).map((doc) => structuredClone(doc));
    const cursor = {
      sort(spec) {
        if (spec?.score?.$meta === 'textScore') {
          rows.sort((a, b) => String(b.text || '').length - String(a.text || '').length);
        }
        return cursor;
      },
      limit(amount) {
        rows = rows.slice(0, amount);
        return cursor;
      },
      project() { return cursor; },
      async toArray() { return rows; },
    };
    return cursor;
  }
}

function memoryDb() {
  const collections = new Map();
  return {
    collection(name) {
      if (!collections.has(name)) collections.set(name, new MemoryCollection());
      return collections.get(name);
    },
  };
}

function repeatText(text, minimum = 1000) {
  let value = '';
  while (value.length < minimum) value += text + ' ';
  return value;
}

test('source registry contains only the three exact approved HTTPS URLs', () => {
  assert.equal(PUBLIC_PDF_SOURCES.length, 3);
  assert.equal(resolveApprovedSource(PUBLIC_PDF_SOURCES[0].url).sourceId, 'montalban-walk-in-official');
  assert.throws(() => resolveApprovedSource('https://example.com/evil.pdf'), /source_not_allowlisted/);
  assert.throws(() => resolveApprovedSource(PUBLIC_PDF_SOURCES[0].url + '?download=1'), /source_not_allowlisted/);
});

test('chunking preserves page references and caps chunk size', () => {
  const text = repeatText('Employment requirements and public assistance information.', 4500);
  const chunks = chunkPdfPages([
    { pageNumber: 7, text },
    { pageNumber: 8, text: 'Short second-page content.' },
  ], { maxChunkChars: 600, overlapChars: 50, minExtractedChars: 100 });

  assert.ok(chunks.length >= 8);
  assert.ok(chunks.every((chunk) => chunk.text.length <= 600));
  assert.ok(chunks.filter((chunk) => chunk.pageStart === 7).length >= 7);
  assert.deepEqual(chunks.at(-1) && [chunks.at(-1).pageStart, chunks.at(-1).pageEnd], [8, 8]);
});

test('chunking reports OCR need instead of indexing effectively empty scanned PDFs', () => {
  assert.throws(
    () => chunkPdfPages([{ pageNumber: 1, text: '   ' }]),
    (error) => error instanceof PublicPdfIngestionError && error.code === 'pdf_text_not_extractable',
  );
});

test('download accepts a valid PDF response and captures validators/hash', async () => {
  const bytes = pdfBytes('hello');
  const result = await downloadPublicPdf(PUBLIC_PDF_SOURCES[0], {
    fetchImpl: async () => pdfResponse(bytes, { etag: '"v1"' }),
  });

  assert.equal(result.notModified, false);
  assert.deepEqual(result.bytes, bytes);
  assert.match(result.sha256, /^[a-f0-9]{64}$/);
  assert.equal(result.etag, '"v1"');
});

test('download rejects non-PDF content types and bad signatures', async () => {
  await assert.rejects(
    () => downloadPublicPdf(PUBLIC_PDF_SOURCES[0], {
      fetchImpl: async () => pdfResponse(Buffer.from('<html>'), { contentType: 'text/html' }),
    }),
    (error) => error.code === 'unexpected_content_type',
  );
  await assert.rejects(
    () => downloadPublicPdf(PUBLIC_PDF_SOURCES[0], {
      fetchImpl: async () => pdfResponse(Buffer.from('not a pdf')),
    }),
    (error) => error.code === 'invalid_pdf_signature',
  );
});

test('download enforces size limit from headers and streamed bytes', async () => {
  await assert.rejects(
    () => downloadPublicPdf(PUBLIC_PDF_SOURCES[0], {
      maxBytes: 10,
      fetchImpl: async () => pdfResponse(pdfBytes('tiny'), { contentLength: 100 }),
    }),
    (error) => error.code === 'pdf_too_large',
  );
  await assert.rejects(
    () => downloadPublicPdf(PUBLIC_PDF_SOURCES[0], {
      maxBytes: 10,
      fetchImpl: async () => pdfResponse(pdfBytes('payload'), { contentLength: null }),
    }),
    (error) => error.code === 'pdf_too_large',
  );
});

test('download rejects redirects to hosts or URLs outside the approved source registry', async () => {
  await assert.rejects(
    () => downloadPublicPdf(PUBLIC_PDF_SOURCES[0], {
      fetchImpl: async () => new Response(null, {
        status: 302,
        headers: { location: 'https://example.com/redirect.pdf' },
      }),
    }),
    (error) => error.code === 'redirect_target_not_allowlisted',
  );
});

test('download supports conditional-not-modified responses', async () => {
  let capturedHeaders;
  const result = await downloadPublicPdf(PUBLIC_PDF_SOURCES[0], {
    etag: '"stable"',
    lastModified: 'Fri, 11 Sep 2026 00:19:22 GMT',
    fetchImpl: async (_url, init) => {
      capturedHeaders = init.headers;
      return new Response(null, { status: 304, headers: { etag: '"stable"' } });
    },
  });
  assert.equal(result.notModified, true);
  assert.equal(capturedHeaders['If-None-Match'], '"stable"');
  assert.equal(capturedHeaders['If-Modified-Since'], 'Fri, 11 Sep 2026 00:19:22 GMT');
});

test('ingestion initializes Mongo indexes, indexes pages, and returns source-linked search results', async () => {
  const db = memoryDb();
  const source = PUBLIC_PDF_SOURCES[0];
  const bytes = pdfBytes('source-v1');
  let parseCalls = 0;
  const ingestion = createPublicPdfIngestion({
    db,
    fetchImpl: async () => pdfResponse(bytes, { etag: '"v1"' }),
    extractPages: async () => {
      parseCalls += 1;
      return [
        { pageNumber: 3, text: repeatText('Montalban employment applicant requirements and walk-in services.', 1200) },
        { pageNumber: 4, text: repeatText('Bring identification and prepare the application documents.', 600) },
      ];
    },
    now: () => new Date('2026-10-18T00:00:00Z'),
  });

  await ingestion.initialize();
  const result = await ingestion.syncSource(source);
  assert.equal(result.ok, true);
  assert.equal(result.status, 'ready');
  assert.equal(parseCalls, 1);

  const status = await ingestion.getStatus();
  const savedSource = status.find((item) => item.sourceId === source.sourceId);
  assert.equal(savedSource.syncStatus, 'ready');
  assert.equal(savedSource.pagesExtracted, 2);
  assert.ok(savedSource.chunkCount >= 2);

  const matchesFound = await ingestion.search('employment applicant requirements');
  assert.ok(matchesFound.length > 0);
  assert.equal(matchesFound[0].sources[0].url, source.url);
  assert.ok(matchesFound[0].pageStart >= 3 && matchesFound[0].pageStart <= 4);
  assert.ok(db.collection('publicInformationChunks').indexes.some((index) => index.keys.text === 'text'));
});

test('duplicate source files share chunk records while preserving both source URLs', async () => {
  const db = memoryDb();
  // Mirror URLs can differ at the PDF-byte level (metadata) while the extracted
  // text is identical; use separate byte payloads to verify text-hash dedup.
  const extractPages = async () => [
    { pageNumber: 1, text: repeatText('Montalban public employment program requirements.', 600) },
  ];
  const ingestion = createPublicPdfIngestion({
    db,
    fetchImpl: async (url) => pdfResponse(pdfBytes(url === PUBLIC_PDF_SOURCES[0].url ? 'binary-metadata-a' : 'binary-metadata-b')),
    extractPages,
  });

  await ingestion.syncSource(PUBLIC_PDF_SOURCES[0]);
  await ingestion.syncSource(PUBLIC_PDF_SOURCES[2]);

  const stored = db.collection('publicInformationChunks').docs;
  assert.ok(stored.length > 0);
  assert.ok(stored.every((chunk) => chunk.sourceIds.includes(PUBLIC_PDF_SOURCES[0].sourceId)
    && chunk.sourceIds.includes(PUBLIC_PDF_SOURCES[2].sourceId)));
  const matchesFound = await ingestion.search('employment program');
  assert.ok(matchesFound[0].sources.some((source) => source.url === PUBLIC_PDF_SOURCES[0].url));
  assert.ok(matchesFound[0].sources.some((source) => source.url === PUBLIC_PDF_SOURCES[2].url));
});

test('changed source version removes stale-only chunks and retains shared duplicates', async () => {
  const db = memoryDb();
  const sourceA = PUBLIC_PDF_SOURCES[0];
  const sourceB = PUBLIC_PDF_SOURCES[2];
  let version = 1;
  const fetchImpl = async () => pdfResponse(pdfBytes('version-' + version), { etag: '"v' + version + '"' });
  const extractPages = async () => [
    { pageNumber: version, text: repeatText(version === 1 ? 'old montalban process information' : 'new montalban process information', 500) },
  ];
  const ingestion = createPublicPdfIngestion({ db, fetchImpl, extractPages });

  await ingestion.syncSource(sourceA);
  await ingestion.syncSource(sourceB);
  const before = db.collection('publicInformationChunks').docs.length;
  assert.ok(before > 0);

  version = 2;
  const result = await ingestion.syncSource(sourceA);
  assert.equal(result.status, 'ready');
  const chunks = db.collection('publicInformationChunks').docs;
  assert.ok(chunks.some((chunk) => chunk.text.includes('old montalban') && chunk.sourceIds.includes(sourceB.sourceId)));
  assert.ok(chunks.some((chunk) => chunk.text.includes('new montalban') && chunk.sourceIds.includes(sourceA.sourceId)));
  assert.ok(!chunks.some((chunk) => chunk.text.includes('old montalban') && !chunk.sourceIds.length));
});

test('same-hash failed sources are reindexed when no successful chunk index exists', async () => {
  const db = memoryDb();
  const source = PUBLIC_PDF_SOURCES[0];
  const bytes = pdfBytes('stale-failed-source');
  await db.collection('publicInformationSources').updateOne(
    { sourceId: source.sourceId },
    { $set: {
      sourceId: source.sourceId,
      title: source.title,
      url: source.url,
      contentSha256: sha256(bytes),
      syncStatus: 'error',
      chunkCount: 0,
      pagesExtracted: 0,
      etag: '"existing-etag"',
      lastSuccessfulSyncAt: null,
    } },
    { upsert: true },
  );
  let parseCalls = 0;
  const ingestion = createPublicPdfIngestion({
    db,
    fetchImpl: async () => pdfResponse(bytes, { etag: '"existing-etag"' }),
    extractPages: async () => {
      parseCalls += 1;
      return [{ pageNumber: 1, text: repeatText('Montalban official walk-in service and applicant information.', 600) }];
    },
  });

  const result = await ingestion.syncSource(source);
  assert.equal(result.ok, true);
  assert.equal(result.status, 'ready');
  assert.equal(parseCalls, 1);
  const status = (await ingestion.getStatus()).find((item) => item.sourceId === source.sourceId);
  assert.ok(status.lastSuccessfulSyncAt);
  assert.ok(status.chunkCount > 0);
  assert.ok(db.collection('publicInformationChunks').docs.some((chunk) => chunk.sourceIds.includes(source.sourceId)));
});
test('low-text extraction marks OCR needed and preserves the prior successful content', async () => {
  const db = memoryDb();
  const source = PUBLIC_PDF_SOURCES[1];
  let parserReturnsText = true;
  const ingestion = createPublicPdfIngestion({
    db,
    fetchImpl: async () => pdfResponse(pdfBytes(parserReturnsText ? 'text' : 'scan'), { etag: parserReturnsText ? '"text"' : '"scan"' }),
    extractPages: async () => [{
      pageNumber: 1,
      text: parserReturnsText ? repeatText('Existing public service information is indexed.', 500) : '',
    }],
  });

  const first = await ingestion.syncSource(source);
  assert.equal(first.status, 'ready');
  const originalHash = (await ingestion.getStatus()).find((item) => item.sourceId === source.sourceId).contentSha256;

  parserReturnsText = false;
  const second = await ingestion.syncSource(source);
  assert.equal(second.status, 'needs_ocr');
  assert.equal(second.errorCode, 'pdf_text_not_extractable');
  const current = (await ingestion.getStatus()).find((item) => item.sourceId === source.sourceId);
  assert.equal(current.contentSha256, originalHash);
  assert.ok(db.collection('publicInformationChunks').docs.some((chunk) => chunk.sourceIds.includes(source.sourceId)));
});

test('a server-side 304 updates last-check state without reparsing', async () => {
  const db = memoryDb();
  const source = PUBLIC_PDF_SOURCES[0];
  const bytes = pdfBytes('unchanged');
  let conditional = false;
  let parseCalls = 0;
  const ingestion = createPublicPdfIngestion({
    db,
    fetchImpl: async (_url, init) => conditional
      ? new Response(null, { status: 304, headers: { etag: '"v1"' } })
      : pdfResponse(bytes, { etag: '"v1"' }),
    extractPages: async () => {
      parseCalls += 1;
      return [{ pageNumber: 1, text: repeatText('Stable source text.', 500) }];
    },
  });

  assert.equal((await ingestion.syncSource(source)).status, 'ready');
  conditional = true;
  assert.equal((await ingestion.syncSource(source)).status, 'unchanged');
  assert.equal(parseCalls, 1);
});

test('a read that left pages unread is retried after a cool-off, not on every sync', async () => {
  const db = memoryDb();
  const source = PUBLIC_PDF_SOURCES[0];
  const bytes = pdfBytes('ai-partial');
  let readerCalls = 0;
  let clock = new Date('2026-10-19T08:00:00Z');

  const ingestion = createPublicPdfIngestion({
    db,
    now: () => clock,
    countPages: async () => 4,
    fetchImpl: async (_url, init) => {
      const headers = init?.headers || {};
      if (headers['If-None-Match'] || headers['if-none-match']) {
        return new Response(null, { status: 304, headers: { etag: '"v1"' } });
      }
      return pdfResponse(bytes, { etag: '"v1"' });
    },
    aiReader: {
      async readDocument() {
        readerCalls += 1;
        return {
          listings: [{
            page: 2,
            company: 'Acme',
            roles: ['Clerk'],
            category: 'walk_in_application',
            summary: 'Now hiring.',
          }],
          pages: [
            { page: 1, summary: 'Cover page.' },
            { page: 2, summary: 'Now hiring clerks.' },
          ],
          pagesRead: 2,
          pageCount: 4,
          complete: false,
          gaps: [{ start: 3, end: 4, code: 'invalid_response' }],
          model: 'gemini-test',
        };
      },
    },
  });

  const first = await ingestion.syncSource(source);
  assert.equal(first.status, 'ready');
  assert.equal(first.aiListings, 1);
  assert.equal(first.aiComplete, false);
  assert.equal(readerCalls, 1);

  // Soon afterwards the partial read is accepted as-is: no repeat AI spend.
  clock = new Date('2026-10-19T09:00:00Z');
  const second = await ingestion.syncSource(source);
  assert.equal(second.status, 'unchanged');
  assert.equal(readerCalls, 1);

  // After the cool-off the unread pages are attempted again.
  clock = new Date('2026-10-19T15:30:00Z');
  const third = await ingestion.syncSource(source);
  assert.equal(third.status, 'ready', 'retry failed with ' + third.errorCode);
  assert.equal(readerCalls, 2);
});

test('a quota failure is retried within minutes, not hours', async () => {
  const db = memoryDb();
  const source = PUBLIC_PDF_SOURCES[0];
  const bytes = pdfBytes('ai-quota');
  let readerCalls = 0;
  let clock = new Date('2026-10-19T08:00:00Z');

  const ingestion = createPublicPdfIngestion({
    db,
    now: () => clock,
    countPages: async () => 4,
    fetchImpl: async (_url, init) => {
      const headers = init?.headers || {};
      if (headers['If-None-Match'] || headers['if-none-match']) {
        return new Response(null, { status: 304, headers: { etag: '"q1"' } });
      }
      return pdfResponse(bytes, { etag: '"q1"' });
    },
    aiReader: {
      async readDocument() {
        readerCalls += 1;
        return {
          listings: [{ page: 1, company: 'Acme', roles: ['Clerk'], category: 'walk_in_application', summary: 'Hiring.' }],
          pages: [{ page: 1, summary: 'Hiring clerks.' }],
          pagesRead: 1,
          pageCount: 4,
          complete: false,
          gaps: [{ start: 2, end: 4, code: 'gemini_rate_limited' }],
          model: 'gemini-test',
        };
      },
    },
  });

  await ingestion.syncSource(source);
  assert.equal(readerCalls, 1);

  clock = new Date('2026-10-19T08:04:00Z');
  assert.equal((await ingestion.syncSource(source)).status, 'unchanged');
  assert.equal(readerCalls, 1);

  clock = new Date('2026-10-19T08:06:00Z');
  assert.equal((await ingestion.syncSource(source)).status, 'ready');
  assert.equal(readerCalls, 2);
});

test('a partial read keeps the pages an earlier read already found', async () => {
  const { mergeAiListings } = await import('./public-pdf-ingestion.js');
  const merged = mergeAiListings(
    [
      { page: 2, company: 'Home Credit', roles: ['Clerk'] },
      { page: 9, company: 'Alorica', roles: ['CSR'] },
    ],
    [
      { page: 2, company: 'Home Credit', roles: ['Clerk'] },
      { page: 3, company: 'Wilcon', roles: ['Cashier'] },
    ],
  );

  assert.equal(merged.length, 3);
  assert.deepEqual(merged.map((listing) => listing.page), [2, 3, 9]);
});

test('syncAll checks all three sources serially and reports per-source failures', async () => {
  const db = memoryDb();
  const calls = [];
  const ingestion = createPublicPdfIngestion({
    db,
    fetchImpl: async (url) => {
      calls.push(url);
      if (url.includes('PARA-SA-MONTALBENO')) {
        return new Response('<html/>', { status: 200, headers: { 'content-type': 'text/html' } });
      }
      return pdfResponse(pdfBytes(url));
    },
    extractPages: async () => [{ pageNumber: 1, text: repeatText('Public walk-in services and application information.', 600) }],
  });

  const result = await ingestion.syncAll();
  assert.equal(calls.length, 3);
  assert.deepEqual(calls, PUBLIC_PDF_SOURCES.map((source) => source.url));
  assert.equal(result.ok, false);
  assert.equal(result.results.filter((item) => item.ok).length, 2);
  assert.equal(result.results.find((item) => item.sourceId === PUBLIC_PDF_SOURCES[1].sourceId).errorCode, 'unexpected_content_type');
});
