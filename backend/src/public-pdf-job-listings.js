import { JOB_POSTING_CATEGORIES } from './job_postings.js';

const DAY_MS = 24 * 60 * 60 * 1000;

const WALK_IN_SOURCE = Object.freeze({
  sourceId: 'montalban-walk-in-official',
  title: 'Walk-in Compilation — Montalban official website',
  url: 'https://montalban.gov.ph/wp-content/uploads/2020/07/walk-in-compilation.pdf',
});

const LRA_SOURCE = Object.freeze({
  sourceId: 'montalban-para-sa-montalbeno',
  title: 'Para sa Montalbeño — PESO Montalban hiring compilation',
  url: 'https://dev.montalban.gov.ph/wp-content/uploads/2020/07/PARA-SA-MONTALBENO.pdf',
});

const availabilityNote =
  'Current availability is not confirmed by this compilation. Contact PESO Montalban to verify that these openings remain available before travelling or applying. Salary and vacancy counts are not stated unless explicitly shown in the source.';

function listing({
  fingerprint,
  source,
  category,
  title,
  company,
  location = 'Work locations vary by role; verify details with PESO Montalban',
  pages,
  roles,
  requirements = [],
}) {
  const roleText = roles.join(', ');
  const sourceMarker = '[PESO_PUBLIC_PDF_LISTING|title=' + source.title + '|url=' + source.url + '|pages=' + pages[0] + '-' + pages[1] + ']';
  const categoryIntro = category === JOB_POSTING_CATEGORIES.WALK_IN
    ? 'Walk-in applicant opportunities'
    : 'Local recruitment activity listing';
  return Object.freeze({
    sourceFingerprint: 'public-pdf-job-feed:' + fingerprint,
    publicPdfSourceId: source.sourceId,
    sourceTitle: source.title,
    sourceUrl: source.url,
    sourcePageStart: pages[0],
    sourcePageEnd: pages[1],
    isPublicPdfListing: true,
    listingLabel: 'Multiple roles',
    availabilityNote,
    title,
    company,
    location,
    salary: 'Not stated in source',
    employmentType: 'Varies by role',
    description:
      sourceMarker + '\n' + categoryIntro + '. Roles visible in the cited pages: ' + roleText + '. ' +
      'This is a source-backed grouping of roles, not confirmation that each vacancy is still open. ' +
      'The PDF does not establish a current closing date. ' +
      'The source directs interested applicants to the PESO Montalban office, 2nd floor, Montalban Municipal Hall, and asks applicants to bring at least two resume copies where that instruction appears. ' +
      availabilityNote,
    requirements: [
      'Role-specific qualifications differ; consult the cited pages in the official source PDF.',
      'Confirm current availability, location, schedule and requirements with PESO Montalban before applying.',
      ...requirements,
    ],
    imageUrl: '',
    category,
    status: 'active',
    createdBy: 'public-pdf-importer',
    sourceLastSuccessfulSyncAt: null,
  });
}

export const PUBLIC_PDF_JOB_LISTINGS = Object.freeze([
  listing({
    fingerprint: 'walk-in-applicants-pages-1-13-v1',
    source: WALK_IN_SOURCE,
    category: JOB_POSTING_CATEGORIES.WALK_IN,
    title: 'Walk-in Applicant Opportunities — Multiple Employers',
    company: 'Various employers listed by PESO Montalban',
    pages: [1, 13],
    roles: [
      'Sales Associate',
      'Field Officer',
      'Branch Marketing Staff',
      'Inventory Staff',
      'Utility Staff',
      'Mechanic',
      'Branch Manager',
      'CI/Collector',
      'Field Marketing Associate',
      'Stock Custodian',
      'Telecollector',
      'Repossessor',
      'Field Collector',
      'Liaison Officer',
      'Driver/Technician',
    ],
  }),
  listing({
    fingerprint: 'para-sa-montalbeno-sm-supermarket-p2-v1',
    source: LRA_SOURCE,
    category: JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY,
    title: 'SM Supermarket — Hiring Notices',
    company: 'SM Supermarket',
    pages: [2, 2],
    roles: [
      'Accounting Clerk',
      'Bagger',
      'Cashier',
      'Clerk',
      'Customer Assistant',
      'Technical Clerk',
    ],
  }),
  listing({
    fingerprint: 'para-sa-montalbeno-xentro-pages-5-16-v1',
    source: LRA_SOURCE,
    category: JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY,
    title: 'Xentro Inc. — Multiple Positions',
    company: 'Xentro Inc.',
    pages: [5, 16],
    roles: [
      'Retail Sales Agent',
      'Electrical Design Engineer',
      'Sales Officer',
      'Account Management',
      'Building Admin/Facilities Officer',
      'Assistant ICT Manager',
      'Operations Assistant',
      'Store Supervisor',
      'Paralegal',
      'Elevator/Escalator Technician',
      'Gen-set Technician',
      'Aircon Technician',
    ],
  }),
  listing({
    fingerprint: 'para-sa-montalbeno-jcrcc-p17-v1',
    source: LRA_SOURCE,
    category: JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY,
    title: 'Construction and Heavy Equipment — Hiring Notices',
    company: 'J.C. Rodriguez Construction Corporation',
    pages: [17, 17],
    location: 'Confirm project site and assignment with PESO Montalban',
    roles: [
      'Auto Electrician',
      'Pumpcrete Crew',
      'Auto Painter',
      'Service Truck Driver',
      'Bulldozer Operator',
      'Truck Mechanic',
      'EHS Staff',
      'Vibro Operator',
      'Electrical Engineer',
      'Warehouseman',
      'Heavy Equipment Mechanic',
      'Welder',
      'Hydraulic Mechanic',
      'Industrial Electrician',
      'Machinist',
      'Mixer Driver',
    ],
  }),
  listing({
    fingerprint: 'para-sa-montalbeno-miescor-pages-20-25-v1',
    source: LRA_SOURCE,
    category: JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY,
    title: 'Telecommunications Field Roles — Hiring Notices',
    company: 'MIESCOR Logistics, Inc.',
    pages: [20, 25],
    location: 'Source lists Anonas, Quezon City; verify the current project site',
    roles: [
      'Project Supervisor',
      'Rigger',
      'Lineman',
      'Driver/Technician',
      'Leadman Lineman',
      'Basket Truck Operator',
    ],
  }),
  listing({
    fingerprint: 'para-sa-montalbeno-upskill-p47-v1',
    source: LRA_SOURCE,
    category: JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY,
    title: 'Production-Line Hiring Notice',
    company: 'UpSkill (as identified in source text)',
    pages: [47, 47],
    roles: [
      'Production-line assembly and packing duties (the exact role title is not fully legible in OCR)',
    ],
  }),
  listing({
    fingerprint: 'para-sa-montalbeno-mixed-posters-pages-48-53-63-64-v1',
    source: LRA_SOURCE,
    category: JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY,
    title: 'Other PESO Hiring Posters — Multiple Roles',
    company: 'Multiple employers; some employer names are not legible in the scanned source',
    pages: [48, 64],
    roles: [
      'Admin Assistant',
      'Business Department Staff',
      'Field Collector',
      'Liaison Officer',
      'Paralegal',
      'Repossesor',
      'Telecollector',
      'Area Technical Coordinator',
      'Chef de Partie',
      'Cost Control Specialist',
      'Driver/Stockman',
      'Electrician',
      'Facilities and Maintenance Supervisor',
      'Finance Analyst',
      'HR Officer — Training and Development',
      'Internal Auditor',
      'IT Asset Administrator',
      'IT Infrastructure Manager',
      'Junior Architect',
      'Laboratory Technician',
      'Line Leader',
      'Machine Operator',
      'Production Supervisor',
      'QC Analyst',
      'Regulatory Affairs Pharmacist',
      'Resident Veterinarian',
      'Product Manager',
      'Sales Manager',
      'Social Media Specialist',
      'Janitor',
      'Warehouseman',
      'Promodiser',
      'Driver',
      'Fryer',
      'Area Manager',
      'Brand Manager',
      'Photographer',
      'Field Auditor',
      'Studio Photographer',
    ],
    requirements: [
      'Some employer names and role details are OCR-uncertain; use the linked PDF pages to confirm the original poster.',
    ],
  }),
  listing({
    fingerprint: 'para-sa-montalbeno-microfinance-pages-54-55-v1',
    source: LRA_SOURCE,
    category: JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY,
    title: 'Microfinance Positions',
    company: 'Sustainable Community Microfinance Corp.',
    pages: [54, 55],
    roles: [
      'Microfinance Account Officer',
      'Microfinance Branch Manager',
    ],
  }),
]);

function toDate(value) {
  if (!value) return null;
  const result = value instanceof Date ? new Date(value) : new Date(value);
  return Number.isNaN(result.getTime()) ? null : result;
}

/**
 * Upserts source-backed grouped job cards without changing existing expiries.
 * An ordinary WALK_IN_APPLICATION remains visible until deactivated. The
 * existing app lifecycle intentionally expires LOCAL_RECRUITMENT_ACTIVITY
 * listings after 24 hours.
 */
export async function syncPublicPdfJobListings({ db, now = () => new Date(), apply = false } = {}) {
  if (!db?.collection) throw new TypeError('A connected MongoDB database is required.');

  const sourceCollection = db.collection('publicInformationSources');
  const jobCollection = db.collection('jobPostings');
  const checkedAt = toDate(now()) || new Date();
  const results = [];

  for (const seed of PUBLIC_PDF_JOB_LISTINGS) {
    const source = await sourceCollection.findOne({ sourceId: seed.publicPdfSourceId });
    const indexed = Boolean(
      source &&
      ['ready', 'unchanged'].includes(source.syncStatus) &&
      Number(source.pagesExtracted || 0) > 0 &&
      Number(source.chunkCount || 0) > 0 &&
      source.lastSuccessfulSyncAt,
    );

    if (!indexed) {
      results.push({
        sourceFingerprint: seed.sourceFingerprint,
        title: seed.title,
        ok: false,
        reason: 'source_not_successfully_indexed',
      });
      continue;
    }

    const existing = await jobCollection.findOne({ sourceFingerprint: seed.sourceFingerprint });
    const createdAt = checkedAt;
    const expiresAt = seed.category === JOB_POSTING_CATEGORIES.LOCAL_RECRUITMENT_ACTIVITY
      ? new Date(createdAt.getTime() + DAY_MS)
      : null;
    const record = {
      ...seed,
      sourceLastSuccessfulSyncAt: toDate(source.lastSuccessfulSyncAt),
      sourceContentSha256: source.contentSha256 || null,
      createdAt,
      updatedAt: createdAt,
      expiresAt,
      // Counts are intentionally unknown; the UI displays listingLabel instead.
      vacancies: null,
    };

    if (!apply) {
      results.push({
        sourceFingerprint: seed.sourceFingerprint,
        title: seed.title,
        ok: true,
        action: existing ? 'already_imported' : 'would_import',
        category: seed.category,
        sourceUrl: seed.sourceUrl,
        sourcePageStart: seed.sourcePageStart,
        sourcePageEnd: seed.sourcePageEnd,
      });
      continue;
    }

    await jobCollection.updateOne(
      { sourceFingerprint: seed.sourceFingerprint },
      { $setOnInsert: record },
      { upsert: true },
    );
    results.push({
      sourceFingerprint: seed.sourceFingerprint,
      title: seed.title,
      ok: true,
      action: existing ? 'already_imported' : 'imported',
      category: seed.category,
      sourceUrl: seed.sourceUrl,
      sourcePageStart: seed.sourcePageStart,
      sourcePageEnd: seed.sourcePageEnd,
    });
  }

  return {
    ok: results.every((item) => item.ok),
    checkedAt,
    apply,
    results,
    importedOrExistingCount: results.filter((item) => item.ok).length,
    failedCount: results.filter((item) => !item.ok).length,
  };
}
