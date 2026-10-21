import { createHash } from 'node:crypto';

export const PUBLIC_PDF_SOURCES = Object.freeze([
  Object.freeze({
    sourceId: 'montalban-walk-in-official',
    title: 'Walk-in Compilation — Montalban official website',
    url: 'https://montalban.gov.ph/wp-content/uploads/2020/07/walk-in-compilation.pdf',
  }),
  Object.freeze({
    sourceId: 'montalban-para-sa-montalbeno',
    title: 'Para sa Montalbeño',
    url: 'https://dev.montalban.gov.ph/wp-content/uploads/2020/07/PARA-SA-MONTALBENO.pdf',
  }),
  Object.freeze({
    sourceId: 'montalban-walk-in-development',
    title: 'Walk-in Compilation — Montalban development website',
    url: 'https://dev.montalban.gov.ph/wp-content/uploads/2020/07/walk-in-compilation.pdf',
  }),
]);

export const PUBLIC_PDF_LIMITS = Object.freeze({
  maxBytes: 64 * 1024 * 1024,
  timeoutMs: 120_000,
  maxRedirects: 3,
  maxPages: 2_000,
  maxChunkChars: 1_800,
  overlapChars: 220,
  minExtractedChars: 200,
  queryChars: 1_000,
  // A read that left pages unread is retried, but not on every sync: a page the
  // model genuinely cannot describe would otherwise be re-read around the clock.
  aiRereadRetryMs: 6 * 60 * 60 * 1000,
  // Quota and provider hiccups are not a reason to sit out six hours: the read
  // resumes from the pages already covered, so a short wait is enough.
  aiTransientRetryMs: 5 * 60 * 1000,
});

const TRANSIENT_AI_GAP_CODES = new Set([
  'gemini_rate_limited',
  'gemini_no_eligible_key',
  'gemini_temporarily_unavailable',
  'gemini_request_timed_out',
]);

const SOURCE_BY_URL = new Map(PUBLIC_PDF_SOURCES.map((source) => [source.url, source]));
const SOURCE_BY_ID = new Map(PUBLIC_PDF_SOURCES.map((source) => [source.sourceId, source]));

export class PublicPdfIngestionError extends Error {
  constructor(code, message = code) {
    super(message);
    this.name = 'PublicPdfIngestionError';
    this.code = code;
  }
}

export function sha256(buffer) {
  return createHash('sha256').update(buffer).digest('hex');
}

export function resolveApprovedSource(sourceOrUrl) {
  const source = typeof sourceOrUrl === 'string'
    ? SOURCE_BY_URL.get(sourceOrUrl)
    : SOURCE_BY_ID.get(sourceOrUrl?.sourceId) || SOURCE_BY_URL.get(sourceOrUrl?.url);
  if (!source) throw new PublicPdfIngestionError('source_not_allowlisted');
  return source;
}

function exactApprovedUrl(input, base) {
  let parsed;
  try {
    parsed = new URL(input, base);
  } catch {
    throw new PublicPdfIngestionError('invalid_source_url');
  }
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password || parsed.port) {
    throw new PublicPdfIngestionError('unsafe_source_url');
  }
  if (!SOURCE_BY_URL.has(parsed.href)) {
    throw new PublicPdfIngestionError('redirect_target_not_allowlisted');
  }
  return parsed.href;
}

function safeErrorCode(error) {
  const code = error?.code;
  if (typeof code === 'string' && /^[a-z0-9_]{1,80}$/i.test(code)) return code;
  if (error?.name === 'TimeoutError' || error?.name === 'AbortError') return 'fetch_timeout';
  return 'ingestion_failed';
}

async function readBoundedBody(response, maxBytes) {
  const declaredSize = Number(response.headers?.get?.('content-length') || 0);
  if (Number.isFinite(declaredSize) && declaredSize > maxBytes) {
    throw new PublicPdfIngestionError('pdf_too_large');
  }
  if (!response.body?.getReader) {
    const bytes = Buffer.from(await response.arrayBuffer());
    if (bytes.length > maxBytes) throw new PublicPdfIngestionError('pdf_too_large');
    return bytes;
  }

  const reader = response.body.getReader();
  const parts = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel().catch(() => {});
        throw new PublicPdfIngestionError('pdf_too_large');
      }
      parts.push(Buffer.from(value));
    }
  } finally {
    reader.releaseLock?.();
  }
  return Buffer.concat(parts, total);
}

export async function downloadPublicPdf(sourceOrUrl, {
  fetchImpl = globalThis.fetch,
  etag,
  lastModified,
  maxBytes = PUBLIC_PDF_LIMITS.maxBytes,
  timeoutMs = PUBLIC_PDF_LIMITS.timeoutMs,
  maxRedirects = PUBLIC_PDF_LIMITS.maxRedirects,
} = {}) {
  const source = resolveApprovedSource(sourceOrUrl);
  if (typeof fetchImpl !== 'function') throw new PublicPdfIngestionError('fetch_unavailable');

  let currentUrl = source.url;
  let response;
  for (let redirects = 0; redirects <= maxRedirects; redirects += 1) {
    const headers = { Accept: 'application/pdf, application/octet-stream;q=0.9' };
    if (redirects === 0 && etag) headers['If-None-Match'] = etag;
    if (redirects === 0 && lastModified) headers['If-Modified-Since'] = lastModified;

    try {
      response = await fetchImpl(currentUrl, {
        method: 'GET',
        headers,
        redirect: 'manual',
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (error) {
      throw new PublicPdfIngestionError(safeErrorCode(error));
    }

    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers?.get?.('location');
      if (!location || redirects === maxRedirects) {
        throw new PublicPdfIngestionError('redirect_limit_exceeded');
      }
      currentUrl = exactApprovedUrl(location, currentUrl);
      continue;
    }
    break;
  }

  const responseEtag = response.headers?.get?.('etag') || etag || null;
  const responseLastModified = response.headers?.get?.('last-modified') || lastModified || null;
  if (response.status === 304) {
    return {
      notModified: true,
      etag: responseEtag,
      lastModified: responseLastModified,
    };
  }
  if (response.status !== 200) {
    throw new PublicPdfIngestionError('http_status_' + String(response.status));
  }

  const contentType = String(response.headers?.get?.('content-type') || '')
    .split(';', 1)[0].trim().toLowerCase();
  if (!['application/pdf', 'application/octet-stream'].includes(contentType)) {
    throw new PublicPdfIngestionError('unexpected_content_type');
  }

  const bytes = await readBoundedBody(response, maxBytes);
  if (bytes.length < 5 || bytes.subarray(0, 5).toString('ascii') !== '%PDF-') {
    throw new PublicPdfIngestionError('invalid_pdf_signature');
  }
  return {
    notModified: false,
    bytes,
    sha256: sha256(bytes),
    etag: responseEtag,
    lastModified: responseLastModified,
    contentLength: bytes.length,
  };
}

/**
 * Uses PDF.js to extract searchable text page-by-page. pdfjs-dist is loaded
 * lazily so fetch/chunk/state logic can be tested without parsing dependencies.
 */
export async function extractPdfPages(pdfBytes, {
  maxPages = PUBLIC_PDF_LIMITS.maxPages,
} = {}) {
  let pdfjs;
  try {
    pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
  } catch {
    throw new PublicPdfIngestionError('pdf_parser_not_installed');
  }

  const loadingTask = pdfjs.getDocument({
    data: new Uint8Array(pdfBytes),
    useSystemFonts: true,
    disableFontFace: true,
    isEvalSupported: false,
    stopAtErrors: false,
  });
  let pdf;
  try {
    pdf = await loadingTask.promise;
    if (!Number.isInteger(pdf.numPages) || pdf.numPages < 1) {
      throw new PublicPdfIngestionError('pdf_has_no_pages');
    }
    if (pdf.numPages > maxPages) throw new PublicPdfIngestionError('pdf_too_many_pages');

    const pages = [];
    for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber += 1) {
      const page = await pdf.getPage(pageNumber);
      try {
        const content = await page.getTextContent({ includeMarkedContent: false });
        const text = content.items
          .filter((item) => typeof item.str === 'string')
          .map((item) => item.str + (item.hasEOL ? '\n' : ' '))
          .join('');
        pages.push({ pageNumber, text });
      } finally {
        page.cleanup?.();
      }
    }
    return pages;
  } catch (error) {
    if (error instanceof PublicPdfIngestionError) throw error;
    throw new PublicPdfIngestionError('pdf_extraction_failed');
  } finally {
    try {
      if (pdf) await pdf.destroy();
      else await loadingTask.destroy();
    } catch {
      // Ignore parser cleanup failure; the primary parse result is authoritative.
    }
  }
}

/**
 * Page count only. This reads document metadata, never page content, so the
 * job content itself is read by Gemini — the count is needed to plan the page
 * ranges that guarantee every page is requested.
 */
export async function countPdfPages(pdfBytes, { maxPages = PUBLIC_PDF_LIMITS.maxPages } = {}) {
  let pdfjs;
  try {
    pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
  } catch {
    throw new PublicPdfIngestionError('pdf_parser_not_installed');
  }
  const loadingTask = pdfjs.getDocument({
    data: new Uint8Array(pdfBytes),
    useSystemFonts: true,
    disableFontFace: true,
    isEvalSupported: false,
    stopAtErrors: false,
  });
  let pdf;
  try {
    pdf = await loadingTask.promise;
    if (!Number.isInteger(pdf.numPages) || pdf.numPages < 1) {
      throw new PublicPdfIngestionError('pdf_has_no_pages');
    }
    if (pdf.numPages > maxPages) throw new PublicPdfIngestionError('pdf_too_many_pages');
    return pdf.numPages;
  } catch (error) {
    if (error instanceof PublicPdfIngestionError) throw error;
    throw new PublicPdfIngestionError('pdf_page_count_failed');
  } finally {
    try {
      if (pdf) await pdf.destroy();
      else await loadingTask.destroy();
    } catch {
      // Ignore parser cleanup failure; the page count is authoritative.
    }
  }
}

/** Per-page summaries from two reads, later pages winning. */
function mergeAiPages(previous, next) {
  const byPage = new Map();
  for (const page of [...(Array.isArray(previous) ? previous : []),
    ...(Array.isArray(next) ? next : [])]) {
    const number = Number(page?.page);
    if (!Number.isInteger(number) || number < 1) continue;
    byPage.set(number, String(page?.summary || ''));
  }
  return [...byPage.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([page, summary]) => ({ page, summary }));
}

/** Collapse overlapping or adjacent covered page ranges. */
function mergeAiRanges(ranges) {
  const valid = (Array.isArray(ranges) ? ranges : [])
    .map((range) => ({ start: Number(range?.start), end: Number(range?.end) }))
    .filter((range) => Number.isInteger(range.start) && Number.isInteger(range.end) &&
      range.start >= 1 && range.end >= range.start)
    .sort((a, b) => a.start - b.start);
  const merged = [];
  for (const range of valid) {
    const last = merged[merged.length - 1];
    if (last && range.start <= last.end + 1) last.end = Math.max(last.end, range.end);
    else merged.push({ ...range });
  }
  return merged;
}

/** Union of two listing lists, keyed by page and company so a re-read cannot duplicate. */
export function mergeAiListings(previous, next) {
  const keyOf = (listing) => [
    Number(listing?.page) || 0,
    String(listing?.company || '').toLowerCase(),
    (Array.isArray(listing?.roles) ? listing.roles : []).join('|').toLowerCase(),
  ].join('\u0000');
  const merged = new Map();
  // A later read refines an earlier entry for the same page and employer.
  for (const listing of [...(Array.isArray(previous) ? previous : []),
    ...(Array.isArray(next) ? next : [])]) {
    if (!listing || typeof listing !== 'object') continue;
    merged.set(keyOf(listing), listing);
  }
  return [...merged.values()].sort((a, b) => (Number(a.page) || 0) - (Number(b.page) || 0));
}

/**
 * Turn Gemini's per-page reading into the page text used for the search index,
 * so indexed content comes from Gemini's reading rather than PDF.js fragments.
 */
export function pagesFromAiListings(aiRead) {
  const byPage = new Map();
  for (const page of aiRead?.pages || []) {
    const number = Number(page?.page);
    if (!Number.isInteger(number) || number < 1) continue;
    byPage.set(number, String(page?.summary || '').trim());
  }
  for (const listing of aiRead?.listings || []) {
    const number = Number(listing?.page);
    if (!Number.isInteger(number) || number < 1) continue;
    const extra = [listing.company, (listing.roles || []).join(', ')].filter(Boolean).join(' — ');
    if (!extra) continue;
    const current = byPage.get(number) || '';
    byPage.set(number, (current ? current + ' ' : '') + extra);
  }
  return [...byPage.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([pageNumber, text]) => ({ pageNumber, text: String(text).trim() }))
    .filter((page) => page.text);
}

function normalizePageText(value) {
  return String(value || '')
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, ' ')
    .replace(/[ \t]+/g, ' ')
    .replace(/ *\n */g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function bestBoundary(text, start, end) {
  if (end >= text.length) return end;
  const floor = start + Math.floor((end - start) * 0.6);
  const paragraph = text.lastIndexOf('\n\n', end);
  if (paragraph >= floor) return paragraph;
  const line = text.lastIndexOf('\n', end);
  if (line >= floor) return line;
  const space = text.lastIndexOf(' ', end);
  return space >= floor ? space : end;
}

export function chunkPdfPages(pages, {
  maxChunkChars = PUBLIC_PDF_LIMITS.maxChunkChars,
  overlapChars = PUBLIC_PDF_LIMITS.overlapChars,
  minExtractedChars = PUBLIC_PDF_LIMITS.minExtractedChars,
} = {}) {
  if (!Array.isArray(pages)) throw new PublicPdfIngestionError('invalid_page_text');
  const normalized = pages.map((page, index) => ({
    pageNumber: Number.isInteger(page?.pageNumber) && page.pageNumber > 0
      ? page.pageNumber
      : index + 1,
    text: normalizePageText(page?.text),
  }));
  const totalTextChars = normalized.reduce((sum, page) => sum + page.text.length, 0);
  if (totalTextChars < minExtractedChars) {
    throw new PublicPdfIngestionError('pdf_text_not_extractable');
  }
  if (!Number.isInteger(maxChunkChars) || maxChunkChars < 200 ||
      !Number.isInteger(overlapChars) || overlapChars < 0 ||
      overlapChars >= maxChunkChars) {
    throw new PublicPdfIngestionError('invalid_chunk_configuration');
  }

  const chunks = [];
  for (const page of normalized) {
    const text = page.text;
    if (!text) continue;
    let start = 0;
    while (start < text.length) {
      let end = Math.min(text.length, start + maxChunkChars);
      end = bestBoundary(text, start, end);
      if (end <= start) end = Math.min(text.length, start + maxChunkChars);
      const chunkText = text.slice(start, end).trim();
      if (chunkText) {
        chunks.push({
          chunkIndex: chunks.length,
          pageStart: page.pageNumber,
          pageEnd: page.pageNumber,
          text: chunkText,
        });
      }
      if (end >= text.length) break;
      const next = Math.max(start + 1, end - overlapChars);
      start = next;
    }
  }
  if (!chunks.length) throw new PublicPdfIngestionError('pdf_text_not_extractable');
  return chunks;
}

function publicSourceStatus(source) {
  return {
    sourceId: source.sourceId,
    title: source.title,
    url: source.url,
    syncStatus: source.syncStatus || 'pending',
    contentSha256: source.contentSha256 || null,
    etag: source.etag || null,
    lastModified: source.lastModified || null,
    lastCheckedAt: source.lastCheckedAt || null,
    lastFetchedAt: source.lastFetchedAt || null,
    lastSuccessfulSyncAt: source.lastSuccessfulSyncAt || null,
    pagesExtracted: Number(source.pagesExtracted || 0),
    chunkCount: Number(source.chunkCount || 0),
    lastErrorCode: source.lastErrorCode || null,
    aiListingsCount: Number(source.aiListingsCount || 0),
    aiPagesRead: Number(source.aiPagesRead || 0),
    aiPageCount: Number(source.aiPageCount || 0),
    aiComplete: source.aiComplete === true,
    aiGaps: Array.isArray(source.aiGaps) ? source.aiGaps : [],
    aiCoveredRanges: Array.isArray(source.aiCoveredRanges) ? source.aiCoveredRanges : [],
    aiModel: source.aiModel || null,
    aiReadAt: source.aiReadAt || null,
    aiReusedFrom: source.aiReusedFrom || null,
    aiErrorCode: source.aiErrorCode || null,
  };
}

function cursorToArray(cursor) {
  return cursor && typeof cursor.toArray === 'function' ? cursor.toArray() : Promise.resolve([]);
}

export function createPublicPdfIngestion({
  db,
  fetchImpl = globalThis.fetch,
  extractPages = extractPdfPages,
  countPages = countPdfPages,
  aiReader = null,
  now = () => new Date(),
  logger = { warn: () => {} },
} = {}) {
  if (!db?.collection) throw new TypeError('A connected MongoDB database is required.');
  const sources = db.collection('publicInformationSources');
  const chunks = db.collection('publicInformationChunks');
  let initializePromise = null;
  let syncAllPromise = null;
  const sourceSyncs = new Map();

  async function initialize() {
    if (!initializePromise) {
      initializePromise = (async () => {
        await sources.createIndex({ sourceId: 1 }, { unique: true });
        await sources.createIndex({ url: 1 }, { unique: true });
        await chunks.createIndex({ contentSha256: 1, chunkIndex: 1 }, { unique: true });
        await chunks.createIndex({ sourceIds: 1 });
        await chunks.createIndex({ text: 'text' }, { default_language: 'none' });

        for (const source of PUBLIC_PDF_SOURCES) {
          await sources.updateOne(
            { sourceId: source.sourceId },
            {
              $setOnInsert: {
                ...source,
                syncStatus: 'pending',
                contentSha256: null,
                createdAt: now(),
                lastCheckedAt: null,
                lastSuccessfulSyncAt: null,
                lastErrorCode: null,
                pagesExtracted: 0,
                chunkCount: 0,
              },
            },
            { upsert: true },
          );
        }
        return true;
      })().catch((error) => {
        initializePromise = null;
        throw error;
      });
    }
    return initializePromise;
  }

  async function getStatus() {
    await initialize();
    const rows = await cursorToArray(sources.find({ sourceId: { $in: PUBLIC_PDF_SOURCES.map((source) => source.sourceId) } }));
    return rows
      .map(publicSourceStatus)
      .sort((a, b) => a.sourceId.localeCompare(b.sourceId));
  }

  /**
   * Read the document with Gemini, or reuse an identical document that a mirror
   * source already read. Never throws: a failed read is recorded on the source so
   * the previous job cards survive and the status shows the gap.
   */
  /**
   * A completed read covers every page by definition, even if the record predates
   * the coverage field; without this a legacy record would look uncovered.
   */
  function coveredRangesFor(ranges, complete, totalPages) {
    const valid = (Array.isArray(ranges) ? ranges : []).filter((range) =>
      Number.isInteger(Number(range?.start)) && Number.isInteger(Number(range?.end)) &&
      Number(range.end) >= Number(range.start));
    if (valid.length) return valid;
    const total = Number(totalPages);
    return complete === true && Number.isInteger(total) && total > 0
      ? [{ start: 1, end: total }]
      : [];
  }

  async function readWithAi({ source, bytes, pageCount, contentSha256, existing }) {
    const empty = {
      ok: false,
      code: null,
      model: null,
      listings: [],
      pages: [],
      rawPages: [],
      coveredRanges: [],
      pagesRead: 0,
      pageCount,
      complete: false,
      gaps: [],
      reusedFrom: null,
    };
    if (!aiReader || typeof aiReader.readDocument !== 'function') {
      return { ...empty, code: 'ai_reader_not_configured' };
    }

    // The development and official sites host the same compilation; reading an
    // identical document twice would double the cost for the same notices.
    try {
      const reusable = await sources.findOne({
        sourceId: { $ne: source.sourceId },
        contentSha256,
        aiContentSha256: contentSha256,
        aiListingsCount: { $gt: 0 },
      }, {
        projection: {
          sourceId: 1, aiListings: 1, aiPages: 1, aiCoveredRanges: 1, aiModel: 1,
          aiPageCount: 1, aiPagesRead: 1, aiComplete: 1, aiGaps: 1,
        },
      });
      if (reusable?.aiListings?.length) {
        return {
          ok: true,
          code: null,
          model: reusable.aiModel || null,
          listings: reusable.aiListings,
          pages: pagesFromAiListings({
            pages: reusable.aiPages || [],
            listings: reusable.aiListings,
          }),
          rawPages: Array.isArray(reusable.aiPages) ? reusable.aiPages : [],
          coveredRanges: coveredRangesFor(
            reusable.aiCoveredRanges,
            reusable.aiComplete === true,
            reusable.aiPageCount || pageCount,
          ),
          pagesRead: Number(reusable.aiPagesRead || 0),
          pageCount: Number(reusable.aiPageCount || pageCount),
          complete: reusable.aiComplete === true,
          gaps: Array.isArray(reusable.aiGaps) ? reusable.aiGaps : [],
          reusedFrom: reusable.sourceId,
        };
      }
    } catch {
      // Reuse is an optimisation only; a lookup failure must not block the read.
    }

    try {
      // An earlier partial read of the same bytes is continued, not repeated: the
      // page ranges it already covered are passed back and skipped.
      const resume = existing?.aiContentSha256 === contentSha256 &&
        Array.isArray(existing?.aiCoveredRanges) && existing.aiCoveredRanges.length
        ? {
            coveredRanges: existing.aiCoveredRanges,
            listings: Array.isArray(existing.aiListings) ? existing.aiListings : [],
            pages: Array.isArray(existing.aiPages) ? existing.aiPages : [],
          }
        : null;

      const result = await aiReader.readDocument({
        bytes,
        pageCount,
        sourceId: source.sourceId,
        sourceTitle: source.title,
        model: source.model,
        ...(resume ? { resume } : {}),
      });
      const listings = Array.isArray(result?.listings) ? result.listings : [];
      const previousListings = Array.isArray(existing?.aiListings) ? existing.aiListings : [];
      const previousPages = Array.isArray(existing?.aiPages) ? existing.aiPages : [];
      const previousCovered = Array.isArray(existing?.aiCoveredRanges) ? existing.aiCoveredRanges : [];
      const partial = Array.isArray(result?.gaps) && result.gaps.length > 0;
      // A partial read must not throw away pages an earlier read already covered:
      // losing them would silently drop published jobs from the feed.
      const mergedPages = partial
        ? mergeAiPages(previousPages, Array.isArray(result?.pages) ? result.pages : [])
        : (Array.isArray(result?.pages) ? result.pages : []);
      const mergedListings = partial
        ? mergeAiListings(previousListings, listings)
        : listings;
      return {
        ok: true,
        code: null,
        model: result?.model || null,
        listings: mergedListings,
        pages: pagesFromAiListings({ pages: mergedPages, listings: mergedListings }),
        rawPages: mergedPages,
        coveredRanges: partial
          ? mergeAiRanges([...previousCovered, ...(Array.isArray(result?.coveredRanges) ? result.coveredRanges : [])])
          : coveredRangesFor(
              result?.coveredRanges,
              result?.complete === true,
              result?.pageCount || pageCount,
            ),
        pagesRead: Number(result?.pagesRead || 0),
        pageCount: Number(result?.pageCount || pageCount),
        complete: result?.complete === true,
        gaps: Array.isArray(result?.gaps) ? result.gaps : [],
        reusedFrom: null,
      };
    } catch (error) {
      logger.warn('[Public PDF ingestion] ' + source.sourceId +
        ' AI read failed (' + String(error?.code || error?.name || 'error').slice(0, 60) + ').');
      return { ...empty, code: safeErrorCode(error) };
    }
  }

  async function syncSource(sourceOrId, { forceAiRead = false } = {}) {
    const source = resolveApprovedSource(sourceOrId);
    if (sourceSyncs.has(source.sourceId)) return sourceSyncs.get(source.sourceId);
    const operation = (async () => {
      await initialize();
      const existing = await sources.findOne({ sourceId: source.sourceId });
      const existingHasIndexedContent = Number(existing?.chunkCount || 0) > 0 && Boolean(existing?.lastSuccessfulSyncAt);
      // A source only counts as fully up to date once the job content has been
      // read for the current PDF. A read that left pages unread is retried after
      // a cool-off, because "some pages read" is not the same as "all jobs read".
      const startedAt = now();
      const aiContentIsCurrent = Boolean(existing?.aiContentSha256) &&
        existing.aiContentSha256 === existing?.contentSha256 &&
        Number(existing?.aiListingsCount || 0) > 0;
      const aiGaps = Array.isArray(existing?.aiGaps) ? existing.aiGaps : [];
      const gapsAreTransient = aiGaps.length > 0 && aiGaps.every((gap) =>
        TRANSIENT_AI_GAP_CODES.has(String(gap?.code || '')));
      const aiRetryMs = gapsAreTransient
        ? PUBLIC_PDF_LIMITS.aiTransientRetryMs
        : PUBLIC_PDF_LIMITS.aiRereadRetryMs;
      const aiLastAttemptAt = existing?.aiReadAt instanceof Date ? existing.aiReadAt.getTime() : null;
      const aiRetryDue = aiLastAttemptAt == null ||
        (startedAt.getTime() - aiLastAttemptAt) >= aiRetryMs;
      const aiSettled = !forceAiRead && aiContentIsCurrent &&
        (existing.aiComplete === true || aiRetryDue === false);
      const canSkipDownload = existingHasIndexedContent && (!aiReader || aiSettled);
      await sources.updateOne(
        { sourceId: source.sourceId },
        { $set: { syncStatus: 'syncing', lastCheckedAt: startedAt, lastErrorCode: null } },
      );

      try {
        const downloaded = await downloadPublicPdf(source, {
          fetchImpl,
          etag: canSkipDownload ? existing?.etag : undefined,
          lastModified: canSkipDownload ? existing?.lastModified : undefined,
        });
        if (downloaded.notModified) {
          if (!existingHasIndexedContent) {
            throw new PublicPdfIngestionError('unexpected_not_modified_without_index');
          }
          await sources.updateOne(
            { sourceId: source.sourceId },
            {
              $set: {
                syncStatus: 'unchanged',
                etag: downloaded.etag,
                lastModified: downloaded.lastModified,
                lastCheckedAt: now(),
                lastErrorCode: null,
              },
            },
          );
          return { ok: true, sourceId: source.sourceId, status: 'unchanged' };
        }

        if (canSkipDownload && existing?.contentSha256 && existing.contentSha256 === downloaded.sha256) {
          await sources.updateOne(
            { sourceId: source.sourceId },
            {
              $set: {
                syncStatus: 'unchanged',
                etag: downloaded.etag,
                lastModified: downloaded.lastModified,
                lastCheckedAt: now(),
                lastFetchedAt: now(),
                lastErrorCode: null,
              },
            },
          );
          return { ok: true, sourceId: source.sourceId, status: 'unchanged' };
        }

        // With Gemini configured it reads the document, so the page count is
        // needed up front to plan complete page ranges. Without it the PDF.js
        // fallback supplies the pages directly.
        let aiResult = {
          ok: false,
          code: null,
          model: null,
          listings: [],
          pages: [],
          pagesRead: 0,
          pageCount: 0,
          complete: false,
          gaps: [],
          reusedFrom: null,
        };
        if (typeof aiReader?.readDocument === 'function') {
          const pdfPageCount = await countPages(downloaded.bytes);
          aiResult = await readWithAi({
            source,
            bytes: downloaded.bytes,
            pageCount: pdfPageCount,
            contentSha256: downloaded.sha256,
            existing,
          });
        }
        const pagesFromAi = aiResult.pages.length > 0;
        const pages = pagesFromAi ? aiResult.pages : await extractPages(downloaded.bytes);
        const pageCount = aiResult.pageCount || pages.length;
        // Deduplicate by normalized extracted text, not the raw PDF bytes:
        // mirrors of a document often differ in PDF metadata but not content.
        const extractedContentSha256 = sha256(Buffer.from(JSON.stringify(
          pages.map((page, index) => ({
            pageNumber: Number.isInteger(page?.pageNumber) && page.pageNumber > 0
              ? page.pageNumber
              : index + 1,
            text: normalizePageText(page?.text),
          })),
        )));
        // Gemini's reading is authoritative: a short page (a cover, or a poster
        // with little text) is not evidence that OCR is required, which is what
        // the minimum-length guard exists to detect for raw PDF.js extraction.
        const preparedChunks = chunkPdfPages(pages, pagesFromAi ? { minExtractedChars: 1 } : {}).map((chunk) => ({
          ...chunk,
          contentSha256: extractedContentSha256,
          sourceIds: [source.sourceId],
          title: source.title,
          sourceUrl: source.url,
          updatedAt: now(),
        }));

        for (const chunk of preparedChunks) {
          await chunks.updateOne(
            { contentSha256: chunk.contentSha256, chunkIndex: chunk.chunkIndex },
            {
              $setOnInsert: {
                contentSha256: chunk.contentSha256,
                chunkIndex: chunk.chunkIndex,
                text: chunk.text,
                createdAt: now(),
              },
              $set: {
                title: source.title,
                sourceUrl: source.url,
                pageStart: chunk.pageStart,
                pageEnd: chunk.pageEnd,
                updatedAt: now(),
              },
              $addToSet: { sourceIds: source.sourceId },
            },
            { upsert: true },
          );
        }

        // A failed AI read must not erase the job cards read earlier: only a
        // successful read replaces them, and the error is recorded alongside.
        const aiFields = aiResult.ok
          ? {
              aiContentSha256: downloaded.sha256,
              aiModel: aiResult.model,
              aiReadAt: now(),
              aiPageCount: aiResult.pageCount,
              aiPagesRead: aiResult.pagesRead,
              aiComplete: aiResult.complete,
              aiGaps: aiResult.gaps,
              aiListings: aiResult.listings,
              aiListingsCount: aiResult.listings.length,
              aiPages: aiResult.rawPages,
              aiCoveredRanges: aiResult.coveredRanges,
              aiReusedFrom: aiResult.reusedFrom,
              aiErrorCode: null,
            }
          : { aiErrorCode: aiResult.code || 'ai_read_failed' };

        await sources.updateOne(
          { sourceId: source.sourceId },
          {
            $set: {
              syncStatus: 'ready',
              contentSha256: downloaded.sha256,
              indexedContentSha256: extractedContentSha256,
              etag: downloaded.etag,
              lastModified: downloaded.lastModified,
              lastFetchedAt: now(),
              lastCheckedAt: now(),
              lastSuccessfulSyncAt: now(),
              pagesExtracted: pageCount,
              chunkCount: preparedChunks.length,
              lastErrorCode: null,
              ...aiFields,
            },
          },
        );

        await chunks.updateMany(
          { sourceIds: source.sourceId, contentSha256: { $ne: extractedContentSha256 } },
          { $pull: { sourceIds: source.sourceId } },
        );
        await chunks.deleteMany({ sourceIds: { $size: 0 } });

        return {
          ok: true,
          sourceId: source.sourceId,
          status: 'ready',
          pagesExtracted: pageCount,
          chunkCount: preparedChunks.length,
          contentSha256: downloaded.sha256,
          aiListings: aiResult.listings.length,
          aiPagesRead: aiResult.pagesRead,
          aiComplete: aiResult.complete,
          aiErrorCode: aiResult.ok ? null : (aiResult.code || 'ai_read_failed'),
        };
      } catch (error) {
        const errorCode = safeErrorCode(error);
        const status = errorCode === 'pdf_text_not_extractable' || errorCode.startsWith('ocr_')
          ? 'needs_ocr'
          : 'error';
        await sources.updateOne(
          { sourceId: source.sourceId },
          {
            $set: {
              syncStatus: status,
              lastCheckedAt: now(),
              lastErrorCode: errorCode,
            },
          },
        );
        logger.warn('[Public PDF ingestion] ' + source.sourceId + ' ' + status + ' (' + errorCode + ').');
        return { ok: false, sourceId: source.sourceId, status, errorCode };
      }
    })().finally(() => sourceSyncs.delete(source.sourceId));

    sourceSyncs.set(source.sourceId, operation);
    return operation;
  }

  async function syncAll() {
    if (syncAllPromise) return syncAllPromise;
    syncAllPromise = (async () => {
      await initialize();
      const results = [];
      for (const source of PUBLIC_PDF_SOURCES) results.push(await syncSource(source));
      return {
        ok: results.every((result) => result.ok),
        checkedAt: now(),
        results,
      };
    })().finally(() => {
      syncAllPromise = null;
    });
    return syncAllPromise;
  }

  async function search(query, { limit = 5 } = {}) {
    await initialize();
    const normalizedQuery = String(query || '').trim().slice(0, PUBLIC_PDF_LIMITS.queryChars);
    if (normalizedQuery.length < 2) return [];
    const boundedLimit = Math.max(1, Math.min(10, Number.isInteger(limit) ? limit : 5));
    const matched = await cursorToArray(
      chunks.find({ $text: { $search: normalizedQuery }, sourceIds: { $exists: true, $ne: [] } })
        .sort({ score: { $meta: 'textScore' } })
        .limit(boundedLimit),
    );
    const ids = [...new Set(matched.flatMap((chunk) => Array.isArray(chunk.sourceIds) ? chunk.sourceIds : []))];
    const sourceRows = await cursorToArray(sources.find({ sourceId: { $in: ids } }));
    const sourceById = new Map(sourceRows.map((item) => [item.sourceId, publicSourceStatus(item)]));
    return matched.map((chunk) => ({
      text: chunk.text,
      pageStart: chunk.pageStart,
      pageEnd: chunk.pageEnd,
      relevanceScore: chunk.score,
      sources: (chunk.sourceIds || [])
        .map((sourceId) => sourceById.get(sourceId))
        .filter(Boolean)
        .map(({ sourceId, title, url, contentSha256, lastSuccessfulSyncAt }) => ({
          sourceId, title, url, contentSha256, lastSuccessfulSyncAt,
        })),
    }));
  }

  return Object.freeze({
    initialize,
    getStatus,
    syncSource,
    syncAll,
    search,
  });
}

export function publicPdfSourcesForClient(statusRows = []) {
  const statusById = new Map(statusRows.map((item) => [item.sourceId, item]));
  return PUBLIC_PDF_SOURCES.map((source) => ({
    sourceId: source.sourceId,
    title: source.title,
    url: source.url,
    ...(statusById.get(source.sourceId) || { syncStatus: 'pending' }),
  }));
}
