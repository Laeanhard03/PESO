// Shared, read-only job-feed queries.
import { JOB_POSTING_CATEGORIES, isJobPostingVisible, publicJobPosting } from './job_postings.js';
import { linkedRolesForNotice } from './notice-role-linkage.js';

const LRA = JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY;
// Time is compared in Asia/Manila without relying on host timezone.
const PH_OFFSET = 8 * 3600000;

export function manilaCalendarDay(now = new Date()) {
  return new Date(new Date(now).getTime() + PH_OFFSET).toISOString().slice(0, 10);
}

/** Avoid retrieving all historical or expired roles on every request.
 * Legacy LRA records lacking scheduled dates expire on their PH publication day.
 */
export function activeJobMongoFilter(now = new Date()) {
  const today = manilaCalendarDay(now);
  const startOfTodayUtc = new Date(Date.parse(today + 'T00:00:00Z') - PH_OFFSET);
  return {
    status: 'active',
    $or: [
      { category: { $ne: LRA } },
      { category: LRA, recruitmentEndDate: { $gte: today } },
      { category: LRA, recruitmentEndDate: { $in: [null, ''] }, recruitmentDate: { $gte: today } },
      { category: LRA, recruitmentEndDate: { $in: [null, ''] },
        recruitmentDate: { $in: [null, ''] }, createdAt: { $gte: startOfTodayUtc },
        isPublicPdfListing: { $ne: true } },
      { category: LRA, recruitmentEndDate: { $in: [null, ''] },
        recruitmentDate: { $in: [null, ''] }, createdAt: { $exists: false },
        expiresAt: { $gt: now }, isPublicPdfListing: { $ne: true } },
    ],
  };
}

function validationError(code) {
  return Object.assign(new Error(code), { status: 400, code });
}

export function parseJobFeedQuery(query = {}, { defaultLimit = 60, maxLimit = 100 } = {}) {
  const limitInput = query.limit == null ? String(defaultLimit) : String(query.limit);
  if (!/^[1-9][0-9]{0,3}$/.test(limitInput)) throw validationError('invalid_limit');
  const limit = Number(limitInput);
  if (limit > maxLimit) throw validationError('invalid_limit');
  const pageToken = query.pageToken == null ? '0' : String(query.pageToken);
  if (!/^(0|[1-9][0-9]{0,7})$/.test(pageToken)) throw validationError('invalid_page_token');
  const offset = Number(pageToken);
  const category = String(query.category || '').trim();
  if (category && ![
    LRA,
    JOB_POSTING_CATEGORIES.WALK_IN,
    JOB_POSTING_CATEGORIES.SEAP,
    JOB_POSTING_CATEGORIES.GIP,
  ].includes(category)) {
    throw validationError('invalid_job_category');
  }
  const search = String(query.q || '').trim();
  if (search.length > 100) throw validationError('search_too_long');
  const employmentType = String(query.type || '').trim();
  if (employmentType.length > 80) throw validationError('invalid_employment_type');
  return { offset, limit, category, search, employmentType };
}

export function visibleJobFilter(options, now = new Date()) {
  const clauses = [activeJobMongoFilter(now)];
  if (options.category) clauses.push({ category: options.category });
  if (options.employmentType) clauses.push({ employmentType: options.employmentType });
  if (options.search) {
    const escaped = options.search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(escaped, 'i');
    clauses.push({ $or: ['title', 'company', 'location', 'description', 'employmentType']
      .map((field) => ({ [field]: { $regex: regex } })) });
  }
  return clauses.length === 1 ? clauses[0] : { $and: clauses };
}

export async function fetchStoredJobPage(collection, query = {}, {
  defaultLimit = 60, maxLimit = 100, now = new Date(),
} = {}) {
  const options = parseJobFeedQuery(query, { defaultLimit, maxLimit });
  const docs = await collection.find(visibleJobFilter(options, now))
    .sort({ createdAt: -1, _id: -1 })
    .skip(options.offset)
    .limit(options.limit + 1)
    .toArray();
  const hasMore = docs.length > options.limit;
  const page = docs.slice(0, options.limit).filter((job) => isJobPostingVisible(job, now));

  // Resolve links for matching notices with one bounded role query (no N+1
  // requests). A similar employer name without provenance is never enough.
  const fingerprints = [...new Set(page.filter((job) =>
    job.aiListingKind === 'notice' && job.isPublicPdfListing === true)
    .map((job) => String(job.sourceFingerprint || ''))
    .filter(Boolean))];
  let possibleRoles = [];
  if (fingerprints.length) {
    possibleRoles = await collection.find({
      status: 'active', aiListingKind: 'role',
      parentFingerprint: { $in: fingerprints },
    }).limit(1000).toArray();
  }
  const jobs = page.map((job) => {
    const result = publicJobPosting(job);
    if (job.aiListingKind === 'notice') {
      const roles = linkedRolesForNotice(job, possibleRoles, now);
      result.linkedRoleIds = roles.map((role) => String(role._id ?? role.id));
      // Selected notices remain usable when linked role cards are on a later page.
      result.linkedRoles = roles.map(publicJobPosting);
    }
    return result;
  });
  return { ok: true, jobs,
    nextPageToken: hasMore ? String(options.offset + options.limit) : null };
}

/** Idempotent secondary indexes for the saved-job feed and owner-scoped status
 * history. Call on Mongo initialization; none require destructive migrations.
 */
export async function ensureJobFeedIndexes(db) {
  const indexes = [
    ['jobPostings', { status: 1, createdAt: -1, _id: -1 }, 'peso_job_feed_latest'],
    ['jobPostings', { status: 1, category: 1, createdAt: -1, _id: -1 }, 'peso_job_feed_category'],
    ['jobPostings', { status: 1, aiListingKind: 1, parentFingerprint: 1 }, 'peso_job_notice_roles'],
    ['jobApplications', { uid: 1, submittedAt: -1, _id: -1 }, 'peso_application_owner_history'],
    ['jobApplications', { uid: 1, updatedAt: -1, _id: -1 }, 'peso_notification_owner_updates'],
  ];
  await Promise.all(indexes.map(async ([collection, specification, name]) => {
    await db.collection(collection).createIndex(specification, { name });
  }));
}
