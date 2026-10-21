/**
 * Reads a public PESO job-compilation PDF with Gemini instead of PDF.js.
 *
 * Why this exists: the Montalban compilations are scanned hiring posters. PDF.js
 * text extraction returns unusable fragments of poster artwork, and its image
 * rendering path (used by the OCR fallback) throws in this environment, so the
 * jobs a human sees on the page were never reliably recovered. Gemini reads the
 * pages directly.
 *
 * The document is uploaded once through the Gemini Files API, then read in fixed
 * page ranges. Coverage is checked, not assumed: every page in a requested range
 * must be accounted for by the model, and a range whose answer was cut off is
 * split in half and re-read so a long page list cannot silently drop notices.
 */

import { inspectRoleRequirements } from './role-requirement-evidence.js';

const DOCUMENT_MIME_TYPE = 'application/pdf';

export const AI_PDF_LIMITS = Object.freeze({
  // Free-tier quota is counted per request, so a batch is sized to the most pages
  // a single answer can hold rather than a handful. A cut-off answer is split and
  // re-read, so a too-large batch costs accuracy, never coverage.
  batchPages: 16,
  maxRolesPerListing: 60,
  maxRequirementsPerListing: 25,
  maxListingsPerRange: 80,
  maxPagesPerAnswer: 80,
  maxFieldLength: 400,
  maxSummaryLength: 600,
  uploadTimeoutMs: 300_000,
  pollIntervalMs: 2_000,
  maxPollAttempts: 60,
  batchAttempts: 2,
});

export class PublicPdfAiError extends Error {
  constructor(code, message = code) {
    super(message);
    this.name = 'PublicPdfAiError';
    this.code = code;
  }
}

function boundedText(value, maxLength) {
  if (typeof value !== 'string') return '';
  return value.replace(/\s+/g, ' ').trim().slice(0, maxLength);
}

function boundedList(value, maxItems, maxLength) {
  const items = Array.isArray(value) ? value : typeof value === 'string' ? value.split(/\r?\n|,/) : [];
  const seen = new Set();
  const result = [];
  for (const item of items) {
    const text = boundedText(item, maxLength);
    if (!text) continue;
    const key = text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(text);
    if (result.length >= maxItems) break;
  }
  return result;
}

function safePageNumber(value, fallback) {
  const number = Number(value);
  return Number.isInteger(number) && number > 0 && number <= 100_000 ? number : fallback;
}

/**
 * Ordered page ranges covering the pages that still need reading. Pages already
 * covered by an earlier read are left out, so a resumed read never pays twice.
 */
export function planPageRanges(pageCount, { batchPages = AI_PDF_LIMITS.batchPages, covered = [] } = {}) {
  const total = Number(pageCount);
  if (!Number.isInteger(total) || total < 1) throw new PublicPdfAiError('invalid_page_count');
  const size = Number.isInteger(batchPages) && batchPages > 0 ? batchPages : AI_PDF_LIMITS.batchPages;
  const coveredRanges = normalizeCoveredRanges(covered);
  const pages = [];
  for (let page = 1; page <= total; page += 1) {
    if (!rangeCovered({ start: page, end: page }, coveredRanges)) pages.push(page);
  }
  const ranges = [];
  for (let index = 0; index < pages.length; index += size) {
    const slice = pages.slice(index, index + size);
    ranges.push({ start: slice[0], end: slice[slice.length - 1] });
  }
  return ranges;
}

/**
 * Codes that mean "the account cannot read anything right now". Continuing to
 * ask burns time and quota for answers that cannot succeed.
 */
const STOP_ON_GAP_CODES = new Set([
  'gemini_rate_limited',
  'gemini_no_eligible_key',
  'gemini_key_needs_attention',
  'gemini_configuration_error',
  'invalid_upstream_request',
]);

/** Validated, ordered page ranges that an earlier read already completed. */
function normalizeCoveredRanges(input) {
  const ranges = [];
  for (const item of Array.isArray(input) ? input : []) {
    const start = Number(item?.start);
    const end = Number(item?.end);
    if (!Number.isInteger(start) || !Number.isInteger(end) || start < 1 || end < start) continue;
    ranges.push({ start, end });
  }
  return ranges.sort((a, b) => a.start - b.start);
}

function rangeCovered(range, covered) {
  return covered.some((item) => item.start <= range.start && item.end >= range.end);
}

/** Collapse overlapping or adjacent ranges so coverage stays small and readable. */
function mergeCoveredRanges(ranges) {
  const merged = [];
  for (const range of normalizeCoveredRanges(ranges)) {
    const last = merged[merged.length - 1];
    if (last && range.start <= last.end + 1) last.end = Math.max(last.end, range.end);
    else merged.push({ start: range.start, end: range.end });
  }
  return merged;
}

/** True when the covered ranges leave no page of the document unread. */
function coversAllPages(ranges, pageCount) {
  let nextExpected = 1;
  for (const range of mergeCoveredRanges(ranges)) {
    if (range.start > nextExpected) return false;
    nextExpected = Math.max(nextExpected, range.end + 1);
  }
  return nextExpected > pageCount;
}

/**
 * Normalize one batch answer. Listings are clamped into the requested range so a
 * confused page number cannot pin a job to a page that was never read.
 */
export function normalizeBatchAnswer(document, { start, end, sourceEvidencePages = [] } = {}) {
  if (!document || typeof document !== 'object' || Array.isArray(document)) {
    throw new PublicPdfAiError('invalid_document_answer');
  }
  const rangeStart = Number.isInteger(start) && start > 0 ? start : 1;
  const rangeEnd = Number.isInteger(end) && end >= rangeStart ? end : rangeStart;

  const pages = [];
  const rawPages = Array.isArray(document.pages) ? document.pages.slice(0, AI_PDF_LIMITS.maxPagesPerAnswer) : [];
  for (const entry of rawPages) {
    const page = safePageNumber(entry?.page, 0);
    if (!page) continue;
    pages.push({ page, summary: boundedText(entry?.summary, AI_PDF_LIMITS.maxSummaryLength) });
  }

  const listings = [];
  const rawListings = Array.isArray(document.listings)
    ? document.listings.slice(0, AI_PDF_LIMITS.maxListingsPerRange)
    : [];
  for (const entry of rawListings) {
    if (!entry || typeof entry !== 'object') continue;
    const company = boundedText(entry.company, AI_PDF_LIMITS.maxFieldLength);
    const roles = boundedList(entry.roles, AI_PDF_LIMITS.maxRolesPerListing, AI_PDF_LIMITS.maxFieldLength);
    if (!company && !roles.length) continue;
    const rawPage = safePageNumber(entry.page, rangeStart);
    const page = Math.min(Math.max(rawPage, rangeStart), rangeEnd);
    const category = String(entry.category || '').trim() === 'walk_in_application'
      ? 'walk_in_application'
      : 'local_recruitment_activity';
    listings.push({
      page,
      company: company || 'Employer not stated on the page',
      title: boundedText(entry.title, AI_PDF_LIMITS.maxFieldLength),
      roles,
      location: boundedText(entry.location, AI_PDF_LIMITS.maxFieldLength),
      requirements: boundedList(entry.requirements, AI_PDF_LIMITS.maxRequirementsPerListing, AI_PDF_LIMITS.maxFieldLength),
      // Gemini's self-reported verification fields are discarded. Only
      // independently matched PDF text can mark a role requirement correlated.
      roleRequirements: inspectRoleRequirements(entry, {
        start: rangeStart, end: rangeEnd, independentPages: sourceEvidencePages,
      }),
      contact: boundedText(entry.contact, AI_PDF_LIMITS.maxFieldLength),
      category,
      summary: boundedText(entry.summary, AI_PDF_LIMITS.maxSummaryLength),
    });
    if (listings.length >= AI_PDF_LIMITS.maxListingsPerRange) break;
  }

  const reportedPages = new Set(pages.map((page) => page.page));
  const missingPages = [];
  for (let page = rangeStart; page <= rangeEnd; page += 1) {
    if (!reportedPages.has(page)) missingPages.push(page);
  }
  return { pages, listings, missingPages };
}

function batchPrompt({ start, end, pageCount, sourceTitle }) {
  return [
    'Read pages ' + start + ' to ' + end + ' of ' + pageCount + ' of this document.',
    'Document title as recorded by the agency: ' + sourceTitle + '.',
    'Fill the "pages" array with one entry for EVERY page from ' + start + ' to ' + end + ', in order.',
    'Put an employer notice in "listings" only when it is visible on those pages, and set its page to a page between ' + start + ' and ' + end + '.',
    'A page with no hiring notice still needs its "pages" entry, with a summary that says so.',
    'For each listing, you may add roleRequirements: an array of {role, requirement, kind, evidenceQuote, page}.',
    'The role must exactly match a visible name in roles. Include only qualifications explicitly stated for THAT individual position.',
    'Use kind mandatory only when the quote explicitly says required, must, minimum or mandatory; preferred only when explicitly preferred/advantage; otherwise unknown.',
    'evidenceQuote must reproduce the exact visible line starting with the role name followed by a colon or dash, then the requirement. Never invent a quote, license, certificate or condition.',
    'Leave roleRequirements empty for generic notice-wide criteria, mixed roles without attribution, or unreadable evidence. Never assign one role\'s requirements to another.'
  ].join('\n');
}

async function readJsonResponse(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

/**
 * Uploads a PDF once through the Gemini Files API and waits until it is ACTIVE.
 * The upload is deleted by the caller when the read finishes.
 */
export async function uploadPublicPdfDocument({
  bytes,
  apiKey,
  fetchImpl = globalThis.fetch,
  baseUrl = 'https://generativelanguage.googleapis.com',
  timeoutMs = AI_PDF_LIMITS.uploadTimeoutMs,
  pollIntervalMs = AI_PDF_LIMITS.pollIntervalMs,
  maxPollAttempts = AI_PDF_LIMITS.maxPollAttempts,
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
} = {}) {
  if (typeof apiKey !== 'string' || !apiKey) throw new PublicPdfAiError('gemini_key_unavailable');
  if (!bytes || typeof bytes.length !== 'number' || bytes.length < 5) {
    throw new PublicPdfAiError('invalid_document_bytes');
  }
  const uploadUrl = baseUrl + '/upload/v1beta/files?key=' + encodeURIComponent(apiKey);
  let upload;
  try {
    upload = await fetchImpl(uploadUrl, {
      method: 'POST',
      headers: {
        'X-Goog-Upload-Protocol': 'raw',
        'Content-Type': DOCUMENT_MIME_TYPE,
        'Content-Length': String(bytes.length),
      },
      body: bytes,
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch {
    throw new PublicPdfAiError('document_upload_failed');
  }
  const uploadBody = await readJsonResponse(upload);
  if (!upload.ok || !uploadBody?.file?.name) throw new PublicPdfAiError('document_upload_rejected');

  let file = uploadBody.file;
  const filePath = String(file.name).replace(/^\/+/, '');
  for (let attempt = 0; attempt < maxPollAttempts && file.state !== 'ACTIVE'; attempt += 1) {
    if (file.state === 'FAILED') throw new PublicPdfAiError('document_processing_failed');
    await sleep(pollIntervalMs);
    let poll;
    try {
      poll = await fetchImpl(baseUrl + '/v1beta/' + filePath + '?key=' + encodeURIComponent(apiKey), {
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch {
      throw new PublicPdfAiError('document_status_failed');
    }
    const pollBody = await readJsonResponse(poll);
    if (!poll.ok || !pollBody?.name) throw new PublicPdfAiError('document_status_failed');
    file = pollBody;
  }
  if (file.state !== 'ACTIVE') throw new PublicPdfAiError('document_not_ready');

  return {
    name: filePath,
    uri: String(file.uri || baseUrl + '/v1beta/' + filePath),
    state: file.state,
    sizeBytes: Number(file.sizeBytes || bytes.length),
  };
}

export async function deletePublicPdfDocument({
  name,
  apiKey,
  fetchImpl = globalThis.fetch,
  baseUrl = 'https://generativelanguage.googleapis.com',
  timeoutMs = 60_000,
} = {}) {
  if (typeof apiKey !== 'string' || !apiKey || typeof name !== 'string' || !name) return false;
  try {
    const response = await fetchImpl(baseUrl + '/v1beta/' + name.replace(/^\/+/, '') + '?key=' + encodeURIComponent(apiKey), {
      method: 'DELETE',
      signal: AbortSignal.timeout(timeoutMs),
    });
    return response.ok;
  } catch {
    return false;
  }
}

/** Both the provider's own code and the rotator's public code mean "answer cut off". */
function isTruncationError(error) {
  const code = String(error?.code || '');
  return code === 'response_truncated' || code === 'gemini_response_incomplete';
}

/**
 * @param upload     (bytes, apiKey) => {name, uri}
 * @param remove     (name, apiKey) => void
 * @param readRange  ({apiKey, uri, start, end, pageCount, sourceTitle}) => parsed JSON answer
 * @param withKey    optional (fn) => fn(apiKey) wrapper that pins ONE key for the
 *                   whole read: a Files API upload can only be read by the key
 *                   that uploaded it, so batches must not rotate keys.
 */
export function createPublicPdfAiReader({
  upload,
  remove,
  readRange,
  withKey = null,
  batchPages = AI_PDF_LIMITS.batchPages,
  batchAttempts = AI_PDF_LIMITS.batchAttempts,
  sourceEvidenceExtractor = async (bytes, pageCount) => {
    // Independently read local PDF text only for small text-accessible docs.
    // Scanned/large documents remain pending review: Gemini cannot verify itself.
    if (!Number.isInteger(pageCount) || pageCount > 40) return [];
    const { extractPdfPages } = await import('./public-pdf-ingestion.js');
    return extractPdfPages(bytes, { maxPages: 40 });
  },
  logger = { warn: () => {} },
} = {}) {
  if (typeof readRange !== 'function') throw new TypeError('A readRange function is required.');

  async function readOnce({ apiKey, uri, start, end, pageCount, sourceTitle, getSourceEvidence }) {
    let lastError = null;
    for (let attempt = 1; attempt <= Math.max(1, batchAttempts); attempt += 1) {
      try {
        const answer = await readRange({ apiKey, uri, start, end, pageCount, sourceTitle });
        const hasRoleCandidates = Array.isArray(answer?.listings) &&
          answer.listings.some((entry) => Array.isArray(entry?.roleRequirements) &&
            entry.roleRequirements.length > 0);
        const sourceEvidencePages = hasRoleCandidates && typeof getSourceEvidence === 'function'
          ? await getSourceEvidence()
          : [];
        return normalizeBatchAnswer(answer, { start, end, sourceEvidencePages });
      } catch (error) {
        lastError = error;
        if (isTruncationError(error)) break;
        // A rate limit or a rejected key will not change within the same second.
        if (STOP_ON_GAP_CODES.has(String(error?.code || ''))) break;
      }
    }
    throw lastError || new PublicPdfAiError('document_range_failed');
  }

  /**
   * Read a page range, splitting it in half whenever Gemini ran out of output
   * tokens. A split keeps every page inside a range that the model can finish.
   */
  async function readRangeCovered(context) {
    const { start, end } = context;
    try {
      const batch = await readOnce(context);
      logger.info?.('[Public PDF AI] pages ' + start + '-' + end + ': ' +
        batch.listings.length + ' notices, ' + batch.pages.length + ' pages read.');
      return { batches: [{ start, end, ...batch }], gaps: [] };
    } catch (error) {
      if (isTruncationError(error) && end > start) {
        logger.info?.('[Public PDF AI] pages ' + start + '-' + end + ' answer was cut off; splitting the range.');
        const middle = Math.floor((start + end) / 2);
        const left = await readRangeCovered({ ...context, start, end: middle });
        const right = await readRangeCovered({ ...context, start: middle + 1, end });
        return { batches: [...left.batches, ...right.batches], gaps: [...left.gaps, ...right.gaps] };
      }
      logger.warn('[Public PDF AI] pages ' + start + '-' + end + ' not read (' +
        String(error?.code || error?.name || 'error').slice(0, 60) + ').');
      return { batches: [], gaps: [{ start, end, code: String(error?.code || 'document_range_failed') }] };
    }
  }

  /**
   * Read the document with one pinned key, resuming an earlier partial read when
   * its covered ranges are supplied. A page range that was already read is never
   * paid for twice, so a run stopped by the free-tier quota continues where it
   * stopped.
   *
   * @param resume {{coveredRanges: {start:number,end:number}[], listings: object[], pages: object[]}}
   * @returns {{listings: object[], pages: object[], batches: object[], gaps: object[],
   *            coveredRanges: {start:number,end:number}[], pagesRead: number,
   *            pageCount: number, complete: boolean}}
   */
  async function readWithPinnedKey(apiKey, { bytes, pageCount, sourceTitle = '', resume = null }) {
    const covered = normalizeCoveredRanges(resume?.coveredRanges);
    const pending = planPageRanges(pageCount, { batchPages, covered });
    // Lazy, cached, local extraction. A PDF.js failure does not halt Gemini,
    // publish invented qualifications, or trigger another Gemini API request.
    let sourceEvidencePromise;
    const getSourceEvidence = () => {
      if (!sourceEvidencePromise) {
        sourceEvidencePromise = Promise.resolve()
          .then(() => sourceEvidenceExtractor(bytes, pageCount))
          .then((pages) => Array.isArray(pages) ? pages : [])
          .catch(() => []);
      }
      return sourceEvidencePromise;
    };
    const uploaded = pending.length ? await upload(bytes, apiKey) : null;
    try {
      const listings = Array.isArray(resume?.listings) ? [...resume.listings] : [];
      const pages = Array.isArray(resume?.pages) ? [...resume.pages] : [];
      const batches = [];
      const gaps = [];
      // Once the quota is exhausted every further range fails the same way, so
      // stop asking instead of burning the run on doomed requests.
      let stoppedBy = null;
      for (const range of pending) {
        if (stoppedBy) {
          gaps.push({ start: range.start, end: range.end, code: stoppedBy });
          continue;
        }
        const result = await readRangeCovered({
          apiKey,
          uri: uploaded.uri,
          start: range.start,
          end: range.end,
          pageCount,
          sourceTitle,
          getSourceEvidence,
        });
        batches.push(...result.batches);
        gaps.push(...result.gaps);
        for (const batch of result.batches) {
          listings.push(...batch.listings);
          pages.push(...batch.pages);
        }
        const failureCode = result.gaps.length ? result.gaps[result.gaps.length - 1].code : null;
        if (failureCode && STOP_ON_GAP_CODES.has(failureCode)) stoppedBy = failureCode;
      }
      const coveredRanges = mergeCoveredRanges([
        ...covered,
        ...batches.map((batch) => ({ start: batch.start, end: batch.end })),
      ]);
      return {
        listings,
        pages: pages.sort((a, b) => a.page - b.page),
        batches: batches.map((batch) => ({
          start: batch.start,
          end: batch.end,
          listings: batch.listings.length,
          pages: batch.pages.length,
        })),
        gaps,
        coveredRanges,
        pagesRead: new Set(pages.map((page) => page.page)).size,
        pageCount,
        complete: gaps.length === 0 && coversAllPages(coveredRanges, pageCount),
      };
    } finally {
      if (uploaded?.name && typeof remove === 'function') {
        await remove(uploaded.name, apiKey).catch(() => {});
      }
    }
  }

  async function readDocument(args = {}) {
    if (typeof withKey === 'function') {
      return withKey((apiKey) => readWithPinnedKey(apiKey, args));
    }
    return readWithPinnedKey(null, args);
  }

  return Object.freeze({ readDocument });
}

/** Convenience wrapper used by the ingestion service. */
export function createPublicPdfAiReaderFromRotator({
  rotator,
  model,
  fetchImpl = globalThis.fetch,
  generateWithKey = null,
  batchPages = AI_PDF_LIMITS.batchPages,
  logger = { warn: () => {} },
} = {}) {
  if (!rotator || typeof rotator.generate !== 'function') {
    throw new TypeError('A Gemini rotator is required.');
  }

  // A Files API upload belongs to the key that created it: reading it with a
  // different key returns 403 PERMISSION_DENIED. Without an explicit per-key
  // generator the batch calls cannot be pinned, so they fall back to the rotator
  // (only safe when a single key is configured).
  const generatePinned = typeof generateWithKey === 'function'
    ? generateWithKey
    : null;

  const reader = createPublicPdfAiReader({
    batchPages,
    logger,
    withKey: (fn) => rotator.withApiKey(fn),
    upload: (bytes, apiKey) => uploadPublicPdfDocument({ bytes, apiKey, fetchImpl }),
    remove: (name, apiKey) => deletePublicPdfDocument({ name, apiKey, fetchImpl }),
    readRange: async ({ apiKey, uri, start, end, pageCount, sourceTitle }) => {
      const parts = [
        { text: batchPrompt({ start, end, pageCount, sourceTitle }) },
        { fileData: { mimeType: DOCUMENT_MIME_TYPE, fileUri: uri } },
      ];
      if (generatePinned) {
        try {
          const result = await generatePinned({ apiKey, model, parts });
          return result?.document ?? result;
        } catch (error) {
          throw mapDocumentReadError(error);
        }
      }
      const rotated = await rotator.generate({
        operation: 'public_pdf_jobs',
        model,
        payload: { parts },
      });
      if (!rotated?.ok) {
        const error = new PublicPdfAiError(rotated?.code || 'document_range_failed', rotated?.message || '');
        error.status = rotated?.statusCode;
        throw error;
      }
      return rotated.result?.document;
    },
  });
  return Object.freeze({
    async readDocument(args = {}) {
      const result = await reader.readDocument(args);
      return { ...result, model: model || null };
    },
  });
}

/**
 * Translate a provider failure into the gap codes the reader reasons about, so a
 * quota stop, an unusable key and a truncated answer are told apart.
 */
export function mapDocumentReadError(error) {
  if (error instanceof PublicPdfAiError) return error;
  const status = Number(error?.status || error?.statusCode) || null;
  const raw = String(error?.code || error?.name || '');
  let code = 'document_range_failed';
  if (status === 429 || /RESOURCE_EXHAUSTED|rate_limited|quota/i.test(raw)) code = 'gemini_rate_limited';
  else if (status === 401 || status === 403 || /API_KEY|PERMISSION_DENIED|invalid_key/i.test(raw)) code = 'gemini_configuration_error';
  else if (/RESPONSE_TRUNCATED|response_truncated|MAX_TOKENS|incomplete/i.test(raw)) code = 'response_truncated';
  else if (status === 408 || status === 504 || /timed?\s?out|TIMEOUT/i.test(raw)) code = 'gemini_request_timed_out';
  else if (status >= 500) code = 'gemini_temporarily_unavailable';
  const mapped = new PublicPdfAiError(code, String(error?.message || code));
  mapped.status = status;
  return mapped;
}
