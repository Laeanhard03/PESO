const WALK_IN = 'walk_in_application';
const LOCAL_RECRUITMENT_ACTIVITY = 'local_recruitment_activity';
const DAY_MS = 24 * 60 * 60 * 1000;

export const JOB_POSTING_CATEGORIES = Object.freeze({
  WALK_IN,
  LOCAL_RECRUITMENT_ACTIVITY,
});

function invalid(message) {
  return Object.assign(new Error(message), { status: 400 });
}

function requiredText(body, field, maxLength) {
  const value = typeof body[field] === 'string' ? body[field].trim() : '';
  if (!value) throw invalid(field + ' is required.');
  if (value.length > maxLength) throw invalid(field + ' is too long.');
  return value;
}

function isoOrNull(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

/**
 * Validate an admin-supplied job and assign lifecycle timestamps on the server.
 * A Local Recruitment Activity is visible for 24 hours. A Walk-in Application
 * has no time-based expiry and remains visible until an admin deactivates it.
 */
export function createJobPostingRecord(body, createdBy, now = new Date()) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw invalid('A job posting object is required.');
  }

  const category = String(body.category || '').trim();
  if (![WALK_IN, LOCAL_RECRUITMENT_ACTIVITY].includes(category)) {
    throw invalid('Choose Walk-in Application or Local Recruitment Activity.');
  }

  const vacancies = Number(body.vacancies ?? 1);
  if (!Number.isInteger(vacancies) || vacancies < 1 || vacancies > 100000) {
    throw invalid('vacancies must be a positive whole number.');
  }

  const employmentType = requiredText(body, 'employmentType', 80);
  const description = requiredText(body, 'description', 12000);
  const requirementsRaw = Array.isArray(body.requirements)
    ? body.requirements
    : typeof body.requirements === 'string'
      ? body.requirements.split(',')
      : [];
  const requirements = requirementsRaw
    .map((item) => String(item).trim())
    .filter(Boolean)
    .slice(0, 30)
    .map((item) => item.slice(0, 200));

  const createdAt = new Date(now);
  if (Number.isNaN(createdAt.getTime())) {
    throw invalid('The job creation timestamp is invalid.');
  }
  const expiresAt = category === LOCAL_RECRUITMENT_ACTIVITY
    ? new Date(createdAt.getTime() + DAY_MS)
    : null;

  const imageUrl = typeof body.imageUrl === 'string' ? body.imageUrl.trim() : '';
  if (imageUrl) {
    let parsedImageUrl;
    try {
      parsedImageUrl = new URL(imageUrl);
    } catch {
      throw invalid('imageUrl must be a valid HTTP or HTTPS URL.');
    }
    if (!['http:', 'https:'].includes(parsedImageUrl.protocol) || imageUrl.length > 2048) {
      throw invalid('imageUrl must be a valid HTTP or HTTPS URL.');
    }
  }

  return {
    title: requiredText(body, 'title', 160),
    company: requiredText(body, 'company', 160),
    location: requiredText(body, 'location', 240),
    salary: requiredText(body, 'salary', 120),
    employmentType,
    description,
    requirements,
    imageUrl,
    vacancies,
    category,
    status: 'active',
    createdAt,
    expiresAt,
    createdBy: String(createdBy || '').slice(0, 128),
    updatedAt: createdAt,
  };
}

export function isJobPostingVisible(job, now = new Date()) {
  if (!job || (job.status && job.status !== 'active')) return false;
  if (job.category !== LOCAL_RECRUITMENT_ACTIVITY) return true;

  let expiresAt = job.expiresAt ? new Date(job.expiresAt) : null;
  if ((!expiresAt || Number.isNaN(expiresAt.getTime())) && job.createdAt) {
    const createdAt = new Date(job.createdAt);
    if (!Number.isNaN(createdAt.getTime())) {
      expiresAt = new Date(createdAt.getTime() + DAY_MS);
    }
  }
  return Boolean(expiresAt && !Number.isNaN(expiresAt.getTime()) && expiresAt.getTime() > new Date(now).getTime());
}

function publicDescription(job) {
  const description = String(job?.description ?? '');
  if (!job?.isPublicPdfListing) return description;
  return description.replace(/^\[PESO_PUBLIC_PDF_LISTING\|title=[^\]]*\]\s*/, '');
}
export function publicJobPosting(job) {
  return {
    id: String(job?._id ?? job?.id ?? ''),
    title: String(job?.title ?? ''),
    company: String(job?.company ?? ''),
    location: String(job?.location ?? ''),
    salary: String(job?.salary ?? ''),
    employmentType: String(job?.employmentType ?? ''),
    description: publicDescription(job),
    requirements: Array.isArray(job?.requirements) ? job.requirements.map(String) : [],
    imageUrl: String(job?.imageUrl ?? ''),
    vacancies: job?.isPublicPdfListing ? null : Number(job?.vacancies ?? 1),
    category: String(job?.category ?? WALK_IN),
    status: String(job?.status ?? 'active'),
    createdAt: isoOrNull(job?.createdAt),
    expiresAt: isoOrNull(job?.expiresAt),
    isPublicPdfListing: Boolean(job?.isPublicPdfListing),
    ...(job?.isPublicPdfListing ? {
      listingLabel: String(job.listingLabel || 'Multiple roles'),
      sourceTitle: String(job.sourceTitle || ''),
      sourceUrl: String(job.sourceUrl || ''),
      sourcePageStart: Number(job.sourcePageStart || 1),
      sourcePageEnd: Number(job.sourcePageEnd || job.sourcePageStart || 1),
      availabilityNote: String(job.availabilityNote || ''),
      sourceLastSuccessfulSyncAt: isoOrNull(job.sourceLastSuccessfulSyncAt),
      aiListingKind: job.aiListingKind === 'notice' || job.aiListingKind === 'role'
        ? job.aiListingKind
        : null,
      // Linked role IDs are resolved server-side; internal fingerprints stay private.
      requirementScope: String(job.requirementScope || ''),
      sourceRoleCount: Number(job.sourceRoleCount || 0),
      parentFingerprint: job.parentFingerprint ? String(job.parentFingerprint) : null,
      parentTitle: job.parentTitle ? String(job.parentTitle) : null,
    } : {}),
  };
}
