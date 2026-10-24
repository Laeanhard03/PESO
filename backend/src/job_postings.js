const WALK_IN = 'walk_in_application';
const LOCAL_RECRUITMENT_ACTIVITY = 'local_recruitment_activity';
const SEAP = 'seap';
const GIP = 'gip';
const MANILA_OFFSET_MS = 8 * 60 * 60 * 1000;

// A scheduled recruitment day closes at 23:59:59.999 Philippine time.
// Input dates are calendar dates, never inferred from the viewer's timezone.
export function lraEndOfDayUtc(value) {
  const raw = value instanceof Date ? value.toISOString() : String(value || '').trim();
  const match = /^(\d{4}-\d{2}-\d{2})(?:$|T)/.exec(raw);
  if (!match) return null;
  const date = new Date(`${match[1]}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== match[1]) return null;
  return new Date(date.getTime() + 24 * 60 * 60 * 1000 - MANILA_OFFSET_MS - 1);
}

function manilaDateString(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return new Date(date.getTime() + MANILA_OFFSET_MS).toISOString().slice(0, 10);
}

export const JOB_POSTING_CATEGORIES = Object.freeze({
  WALK_IN,
  LOCAL_RECRUITMENT_ACTIVITY,
  SEAP,
  GIP,
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
 * A Local Recruitment Activity expires at the end of its final scheduled
 * recruitment day in Asia/Manila. Walk-in postings have no time-based expiry.
 */
export function createJobPostingRecord(body, createdBy, now = new Date()) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw invalid('A job posting object is required.');
  }

  const category = String(body.category || '').trim();
  if (![WALK_IN, LOCAL_RECRUITMENT_ACTIVITY, SEAP, GIP].includes(category)) {
    throw invalid('Choose Walk-in Application, Local Recruitment Activity, SEAP, or GIP.');
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
  const recruitmentDate = category === LOCAL_RECRUITMENT_ACTIVITY
    ? String(body.recruitmentDate || body.eventDate || manilaDateString(createdAt)).trim()
    : null;
  const recruitmentEndDate = category === LOCAL_RECRUITMENT_ACTIVITY
    ? String(body.recruitmentEndDate || recruitmentDate).trim()
    : null;
  const expiresAt = category === LOCAL_RECRUITMENT_ACTIVITY
    ? lraEndOfDayUtc(recruitmentEndDate)
    : null;
  if (category === LOCAL_RECRUITMENT_ACTIVITY &&
      (!expiresAt || !lraEndOfDayUtc(recruitmentDate) || recruitmentEndDate < recruitmentDate)) {
    throw invalid('Enter valid recruitment dates in YYYY-MM-DD format.');
  }
  if (category === LOCAL_RECRUITMENT_ACTIVITY && expiresAt <= createdAt) {
    throw invalid('The scheduled recruitment day has already ended in Philippine time.');
  }

  const imageUrl = typeof body.imageUrl === 'string' ? body.imageUrl.trim() : '';
  const logoUrl = typeof body.logoUrl === 'string' ? body.logoUrl.trim() : '';
  for (const [field, url] of [['imageUrl', imageUrl], ['logoUrl', logoUrl]]) {
    if (!url) continue;
    let parsed;
    try { parsed = new URL(url); } catch {
      throw invalid(field + ' must be a valid HTTP or HTTPS URL.');
    }
    if (!['http:', 'https:'].includes(parsed.protocol) || url.length > 2048) {
      throw invalid(field + ' must be a valid HTTP or HTTPS URL.');
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
    logoUrl,
    vacancies,
    category,
    status: 'active',
    createdAt,
    recruitmentDate,
    recruitmentEndDate,
    expiresAt,
    createdBy: String(createdBy || '').slice(0, 128),
    updatedAt: createdAt,
  };
}

export function isJobPostingVisible(job, now = new Date()) {
  if (!job || (job.status && job.status !== 'active')) return false;
  if (job.category !== LOCAL_RECRUITMENT_ACTIVITY) return true;
  // Old public PDF compilations are evidence of historical notices, not
  // proof that an unscheduled recruitment event is open today.
  if (job.isPublicPdfListing === true &&
      !job.recruitmentDate && !job.recruitmentEndDate) return false;

  // Legacy records without an event day use the Philippine publication day.
  const scheduledDay = job.recruitmentEndDate || job.recruitmentDate ||
    (job.createdAt ? manilaDateString(job.createdAt) : null);
  let expiresAt = scheduledDay ? lraEndOfDayUtc(scheduledDay) : null;
  // Only undated legacy records use their previous stored expiry.
  if (!expiresAt && job.expiresAt) {
    const legacy = new Date(job.expiresAt);
    if (!Number.isNaN(legacy.getTime())) expiresAt = legacy;
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
    logoUrl: String(job?.logoUrl ?? job?.companyLogoUrl ?? ''),
    vacancies: job?.isPublicPdfListing ? null : Number(job?.vacancies ?? 1),
    category: String(job?.category ?? WALK_IN),
    status: String(job?.status ?? 'active'),
    createdAt: isoOrNull(job?.createdAt),
    expiresAt: isoOrNull(job?.category === LOCAL_RECRUITMENT_ACTIVITY
      ? (lraEndOfDayUtc(job?.recruitmentEndDate || job?.recruitmentDate ||
          (job?.createdAt ? manilaDateString(job.createdAt) : null)) || job?.expiresAt)
      : job?.expiresAt),
    recruitmentDate: job?.recruitmentDate || null,
    recruitmentEndDate: job?.recruitmentEndDate || null,
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
