/**
 * Turns Gemini's reading of a public PESO compilation into feed cards.
 *
 * Each employer notice becomes one card, and every role on that notice becomes
 * its own card too. The role cards are created one millisecond apart directly
 * after their notice so the feed (sorted newest first) naturally shows the notice
 * followed by the roles that belong to it; `parentFingerprint` is stored as well,
 * so an interface can group them explicitly later.
 *
 * Unlike the earlier hand-written seed list, these rows are renewed on every
 * successful read: a Local Recruitment Activity card would otherwise vanish 24
 * hours after the import and never return.
 */
import { JOB_POSTING_CATEGORIES } from './job_postings.js';
import { attributedRequirementsForRole } from './role-requirement-evidence.js';

const DAY_MS = 24 * 60 * 60 * 1000;
export const AI_JOB_SOURCE = 'public-pdf-ai-importer';

export const AI_JOB_LIMITS = Object.freeze({
  maxRoleCardsPerNotice: 60,
  maxDescriptionChars: 12_000,
  maxTitleChars: 160,
  maxCompanyChars: 160,
  maxLocationChars: 240,
  maxSlugChars: 60,
});

export const AI_JOB_AVAILABILITY_NOTE =
  'This card was read automatically from the agency’s own compilation PDF. ' +
  'Current availability is not confirmed by that compilation: contact PESO Montalban to verify the opening before travelling or applying. ' +
  'Salary and vacancy counts are only shown when the source states them.';

export function slugify(value, maxLength = AI_JOB_LIMITS.maxSlugChars) {
  const slug = String(value == null ? '' : value)
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug.slice(0, maxLength) || 'unknown';
}

function bounded(value, maxLength) {
  return String(value == null ? '' : value).replace(/\s+/g, ' ').trim().slice(0, maxLength);
}

function uniqueTexts(values, maxItems, maxLength) {
  const seen = new Set();
  const result = [];
  for (const value of Array.isArray(values) ? values : []) {
    const text = bounded(value, maxLength);
    if (!text || seen.has(text.toLowerCase())) continue;
    seen.add(text.toLowerCase());
    result.push(text);
    if (result.length >= maxItems) break;
  }
  return result;
}

function pageRange(listing) {
  const page = Number(listing?.page);
  const start = Number.isInteger(page) && page > 0 ? page : 1;
  const end = Number.isInteger(Number(listing?.pageEnd)) && Number(listing.pageEnd) >= start
    ? Number(listing.pageEnd)
    : start;
  return [start, end];
}

function sourceMarkerFor({ source, start, end }) {
  return '[PESO_PUBLIC_PDF_LISTING|title=' + source.title + '|url=' + source.url +
    '|pages=' + start + '-' + end + ']';
}

export function noticeFingerprintFor(sourceId, listing) {
  const [start] = pageRange(listing);
  return 'public-pdf-ai:' + sourceId + ':notice:' + slugify(listing?.company) + '-p' + start;
}

export function roleFingerprintFor(sourceId, listing, role) {
  return noticeFingerprintFor(sourceId, listing) + ':role:' + slugify(role);
}

function baseRequirements(listing) {
  return [
    'Role-specific qualifications differ; consult the cited pages in the official source PDF.',
    'Confirm current availability, location, schedule and requirements with PESO Montalban before applying.',
    ...uniqueTexts(listing?.requirements, 25, 200),
  ].slice(0, 30);
}

// The Gemini schema has notice-wide requirements, not a role-requirements map.
// Never assign unprefixed qualifications to every role on a multi-role notice.
function qualificationsForRole(listing, role, roles) {
  const raw = uniqueTexts(listing?.requirements, 25, 200);
  const correlated = attributedRequirementsForRole(listing, role);
  if (roles.length === 1) {
    return { scope: 'single_role',
      accepted: uniqueTexts([...raw, ...correlated.accepted], 30, 200),
      unattributed: uniqueTexts(correlated.pending, 25, 200),
      correlatedCount: correlated.accepted.length,
      reviewCandidateCount: correlated.pending.length,
    };
  }
  const accepted = [];
  const unattributed = [];
  for (const item of raw) {
    const match = item.match(/^([^:]{2,100}):\s*(.+)$/);
    if (match && roles.some(candidate => slugify(candidate) === slugify(match[1]))) {
      if (slugify(match[1]) === slugify(role)) accepted.push(item);
      // Other roles' attributed requirements remain only on the notice.
    } else {
      unattributed.push(item);
    }
  }
  return {
    scope: accepted.length || correlated.accepted.length ? 'explicit_role' : 'unattributed_notice',
    accepted: uniqueTexts([...accepted, ...correlated.accepted], 30, 200),
    // Candidates lacking independent PDF text correlation cannot become Go
    // mandatory requirements, even if Gemini claimed they were verified.
    unattributed: uniqueTexts([...unattributed, ...correlated.pending], 25, 200),
    correlatedCount: correlated.accepted.length,
    reviewCandidateCount: correlated.pending.length,
  };
}

function noticeTitle(listing) {
  const stated = bounded(listing?.title, AI_JOB_LIMITS.maxTitleChars);
  const company = bounded(listing?.company, AI_JOB_LIMITS.maxCompanyChars);
  if (stated && company && !stated.toLowerCase().includes(company.toLowerCase())) {
    return (stated + ' — ' + company).slice(0, AI_JOB_LIMITS.maxTitleChars);
  }
  if (stated) return stated;
  return (company ? company + ' — ' : '') + 'Hiring Notices';
}

function noticeRecord({ source, listing, now }) {
  const [start, end] = pageRange(listing);
  const company = bounded(listing?.company, AI_JOB_LIMITS.maxCompanyChars) || 'Employer not stated on the page';
  const roles = uniqueTexts(listing?.roles, AI_JOB_LIMITS.maxRoleCardsPerNotice, AI_JOB_LIMITS.maxTitleChars);
  const category = listing?.category === JOB_POSTING_CATEGORIES.WALK_IN
    ? JOB_POSTING_CATEGORIES.WALK_IN
    : JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY;
  const location = bounded(listing?.location, AI_JOB_LIMITS.maxLocationChars) ||
    'Work locations vary by role; verify details with PESO Montalban';
  const contact = bounded(listing?.contact, 300);
  const summary = bounded(listing?.summary, 600);

  const descriptionParts = [
    sourceMarkerFor({ source, start, end }),
    category === JOB_POSTING_CATEGORIES.WALK_IN
      ? 'Walk-in applicant opportunity from the agency compilation.'
      : 'Local recruitment activity from the agency compilation.',
    summary,
    roles.length ? 'Roles read from this notice: ' + roles.join(', ') + '.' : '',
    location ? 'Location as stated: ' + location + '.' : '',
    contact ? 'Contact as stated: ' + contact + '.' : '',
    'This card groups the roles on the employer’s own notice; a role card exists for each one.',
    AI_JOB_AVAILABILITY_NOTE,
  ].filter(Boolean).join(' ').slice(0, AI_JOB_LIMITS.maxDescriptionChars);

  return {
    sourceFingerprint: noticeFingerprintFor(source.sourceId, listing),
    publicPdfSourceId: source.sourceId,
    sourceTitle: source.title,
    sourceUrl: source.url,
    sourcePageStart: start,
    sourcePageEnd: end,
    isPublicPdfListing: true,
    aiListing: true,
    aiListingKind: 'notice',
    requirementScope: 'notice',
    sourceRoleCount: roles.length,
    parentFingerprint: null,
    listingLabel: roles.length ? roles.length + (roles.length === 1 ? ' role' : ' roles') : 'Notice',
    availabilityNote: AI_JOB_AVAILABILITY_NOTE,
    title: noticeTitle({ ...listing, company }).slice(0, AI_JOB_LIMITS.maxTitleChars),
    company,
    location,
    salary: 'Not stated in source',
    employmentType: 'Varies by role',
    description: descriptionParts,
    requirements: baseRequirements(listing),
    imageUrl: '',
    category,
    status: 'active',
    createdBy: AI_JOB_SOURCE,
    vacancies: null,
    createdAt: now,
    updatedAt: now,
    expiresAt: category === JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY
      ? new Date(now.getTime() + DAY_MS)
      : null,
  };
}

function roleRecord({ source, listing, role, roles, notice, now }) {
  const [start, end] = pageRange(listing);
  const company = bounded(listing?.company, AI_JOB_LIMITS.maxCompanyChars) || 'Employer not stated on the page';
  const location = bounded(listing?.location, AI_JOB_LIMITS.maxLocationChars) ||
    'Confirm the work location with PESO Montalban';
  const contact = bounded(listing?.contact, 300);
  const qualifications = qualificationsForRole(listing, role, roles);

  const descriptionParts = [
    sourceMarkerFor({ source, start, end }),
    'Role "' + bounded(role, AI_JOB_LIMITS.maxTitleChars) + '" listed by ' + company + ' on page ' + start + ' of the agency compilation.',
    bounded(listing?.summary, 600),
    location ? 'Location as stated: ' + location + '.' : '',
    contact ? 'Contact as stated: ' + contact + '.' : '',
    AI_JOB_AVAILABILITY_NOTE,
  ].filter(Boolean).join(' ').slice(0, AI_JOB_LIMITS.maxDescriptionChars);

  return {
    sourceFingerprint: roleFingerprintFor(source.sourceId, listing, role),
    publicPdfSourceId: source.sourceId,
    sourceTitle: source.title,
    sourceUrl: source.url,
    sourcePageStart: start,
    sourcePageEnd: end,
    isPublicPdfListing: true,
    aiListing: true,
    aiListingKind: 'role',
    requirementScope: qualifications.scope,
    sourceRoleCount: roles.length,
    unattributedRequirements: qualifications.unattributed,
    roleRequirementEvidence: {
      correlatedSourceText: qualifications.correlatedCount,
      sourceReviewNeeded: qualifications.reviewCandidateCount,
      independentlyValidatedByEmployer: false,
    },
    parentFingerprint: notice.sourceFingerprint,
    parentTitle: notice.title,
    listingLabel: 'Single role',
    availabilityNote: AI_JOB_AVAILABILITY_NOTE,
    title: (bounded(role, AI_JOB_LIMITS.maxTitleChars) + ' — ' + company).slice(0, AI_JOB_LIMITS.maxTitleChars),
    company,
    location,
    salary: 'Not stated in source',
    employmentType: 'Varies by role',
    description: descriptionParts,
    requirements: baseRequirements({ requirements: qualifications.accepted }),
    imageUrl: '',
    category: notice.category,
    status: 'active',
    createdBy: AI_JOB_SOURCE,
    vacancies: null,
    createdAt: now,
    updatedAt: now,
    expiresAt: notice.expiresAt,
  };
}

/**
 * Build the full card set for one source read. The notice of a group is one
 * millisecond newer than its roles, so "newest first" renders the notice first.
 */
export function buildAiJobRecords({ source, listings, now = new Date() } = {}) {
  if (!source?.sourceId || !source?.url) throw new TypeError('A resolved public PDF source is required.');
  if (!Array.isArray(listings)) throw new TypeError('AI listings must be an array.');
  const base = now instanceof Date && !Number.isNaN(now.getTime()) ? now : new Date();

  const records = [];
  const seen = new Set();
  let offset = 0;
  for (const listing of listings) {
    const noticeStamp = new Date(base.getTime() - offset);
    const notice = noticeRecord({ source, listing, now: noticeStamp });
    if (seen.has(notice.sourceFingerprint)) continue;
    seen.add(notice.sourceFingerprint);

    const roles = uniqueTexts(listing?.roles, AI_JOB_LIMITS.maxRoleCardsPerNotice, AI_JOB_LIMITS.maxTitleChars);
    const roleRecords = [];
    for (const role of roles) {
      const roleStamp = new Date(noticeStamp.getTime() - roleRecords.length - 1);
      const record = roleRecord({ source, listing, role, roles, notice, now: roleStamp });
      if (seen.has(record.sourceFingerprint)) continue;
      seen.add(record.sourceFingerprint);
      roleRecords.push(record);
    }
    records.push(notice, ...roleRecords);
    offset += roleRecords.length + 2;
  }
  return records;
}

/** Upsert the generated cards, renew expiry, and retire cards that disappeared. */
export async function syncAiJobListingsFromRecords({
  db,
  source,
  records,
  now = () => new Date(),
  apply = false,
  allowSupersede = true,
} = {}) {
  if (!db?.collection) throw new TypeError('A connected MongoDB database is required.');
  if (!source?.sourceId) throw new TypeError('A resolved public PDF source is required.');
  const jobCollection = db.collection('jobPostings');
  const stamps = records.map((record) => record.sourceFingerprint);
  const existing = await jobCollection
    .find({ createdBy: AI_JOB_SOURCE, publicPdfSourceId: source.sourceId })
    .project({ sourceFingerprint: 1, status: 1 })
    .toArray();
  const existingSet = new Set(existing.map((row) => row.sourceFingerprint));
  const deletedSet = new Set(existing.filter((row) => row.status === 'deleted')
    .map((row) => row.sourceFingerprint));
  const superseded = allowSupersede
    ? existing
      .filter((row) => !stamps.includes(row.sourceFingerprint) && row.status === 'active')
      .map((row) => row.sourceFingerprint)
    : [];

  const summary = {
    ok: true,
    sourceId: source.sourceId,
    apply,
    total: records.length,
    notices: records.filter((record) => record.aiListingKind === 'notice').length,
    roles: records.filter((record) => record.aiListingKind === 'role').length,
    created: stamps.filter((fingerprint) => !existingSet.has(fingerprint)).length,
    renewed: stamps.filter((fingerprint) => existingSet.has(fingerprint) && !deletedSet.has(fingerprint)).length,
    suppressedDeleted: stamps.filter((fingerprint) => deletedSet.has(fingerprint)).length,
    superseded: superseded.length,
    supersedeSkipped: allowSupersede ? 0 : existing.filter((row) => row.status === 'active').length,
    allowSupersede,
    checkedAt: now(),
  };
  if (!apply) return summary;

  const changedAt = now();
  for (const record of records) {
    // PESO admin deletion is an explicit tombstone; periodic PDF rereads must
    // never bring a manually deleted card back into an active job feed.
    if (deletedSet.has(record.sourceFingerprint)) continue;
    const { createdAt: _createdAt, ...mutable } = record;
    await jobCollection.updateOne(
      { sourceFingerprint: record.sourceFingerprint },
      {
        $set: { ...mutable, updatedAt: changedAt },
        $setOnInsert: { createdAt: record.createdAt },
      },
      { upsert: true },
    );
  }
  if (superseded.length) {
    await jobCollection.updateMany(
      { sourceFingerprint: { $in: superseded } },
      { $set: { status: 'inactive', supersededAt: changedAt, updatedAt: changedAt } },
    );
  }
  return summary;
}

/**
 * Publish the AI listings stored on one source as feed cards.
 * Nothing is written when apply is false.
 */
export async function syncPublicPdfAiJobs({ db, sourceId, now = () => new Date(), apply = true } = {}) {
  if (!db?.collection) throw new TypeError('A connected MongoDB database is required.');
  const sourceDoc = await db.collection('publicInformationSources').findOne({ sourceId: String(sourceId || '') });
  if (!sourceDoc) throw new TypeError('The public PDF source is not registered.');
  const source = { sourceId: sourceDoc.sourceId, title: sourceDoc.title, url: sourceDoc.url };
  const listings = Array.isArray(sourceDoc.aiListings) ? sourceDoc.aiListings : [];
  if (sourceDoc.aiReusedFrom) {
    // This source hosts a byte-identical copy of a document another source already
    // read. Its pages are indexed for search, but publishing the same notices
    // again would show every job twice in the feed.
    return {
      ok: true,
      sourceId: source.sourceId,
      apply,
      skipped: true,
      reason: 'duplicate_of_read_source',
      duplicateOf: String(sourceDoc.aiReusedFrom),
      checkedAt: now(),
    };
  }
  if (!listings.length) {
    return {
      ok: false,
      sourceId: source.sourceId,
      apply,
      reason: 'no_ai_listings',
      aiErrorCode: sourceDoc.aiErrorCode || null,
      checkedAt: now(),
    };
  }
  const records = buildAiJobRecords({ source, listings, now: now() });
  return syncAiJobListingsFromRecords({
    db,
    source,
    records,
    now,
    apply,
    // Only a read that covered every page may retire cards: a partial read knows
    // nothing about the pages it did not see, and must not hide their jobs.
    allowSupersede: sourceDoc.aiComplete === true,
  });
}

export async function syncAllPublicPdfAiJobs({ db, now = () => new Date(), apply = true } = {}) {
  if (!db?.collection) throw new TypeError('A connected MongoDB database is required.');
  const rows = await db.collection('publicInformationSources')
    .find({}, { projection: { sourceId: 1 } })
    .toArray();
  const results = [];
  for (const row of rows) {
    results.push(await syncPublicPdfAiJobs({ db, sourceId: row.sourceId, now, apply }));
  }
  return {
    ok: results.every((result) => result.ok),
    results,
    published: results.filter((result) => result.ok && !result.skipped).length,
    checkedAt: now(),
  };
}

/**
 * The earlier feed used a hand-written card list. Those cards are retired rather
 * than deleted: job applications may reference them, and the feed only shows
 * active cards.
 */
export async function retireLegacyPublicPdfCards({ db, now = () => new Date(), apply = true } = {}) {
  if (!db?.collection) throw new TypeError('A connected MongoDB database is required.');
  const jobCollection = db.collection('jobPostings');
  const filter = { createdBy: 'public-pdf-importer', status: 'active' };
  const candidates = await jobCollection.countDocuments(filter);
  if (apply && candidates) {
    await jobCollection.updateMany(filter, {
      $set: {
        status: 'inactive',
        retiredAt: now(),
        retiredReason: 'replaced_by_gemini_pdf_reading',
        updatedAt: now(),
      },
    });
  }
  return { ok: true, apply, candidates, retired: apply ? candidates : 0, checkedAt: now() };
}
