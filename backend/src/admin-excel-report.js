/// A single live export source for every registered job seeker (with or
/// without an application) and every saved application status.
/// Normalization is pure for regression testing without a database.

const STATUS_LABELS = Object.freeze({
  submitted: 'Submitted',
  under_review: 'Under Review',
  matched: 'Matched',
  accepted: 'Accepted',
  rejected: 'Needs Support (not selected)',
});

const ANSWER_COLUMNS = Object.freeze([
  ['experience', 'Experience'],
  ['availability', 'Availability'],
  ['willingToWork', 'Willing to work'],
  ['interviewWilling', 'Interview willingness'],
  ['driverLicense', 'Driving license'],
  ['certificate', 'Certificate'],
  ['education', 'Education'],
  ['computerSkills', 'Computer skills'],
  ['workLocation', 'Work location preference'],
  ['schedule', 'Work schedule preference'],
  ['skills', 'Task familiarity'],
  ['interview', 'Interview readiness'],
  ['officeTools', 'Office and digital tools'],
  ['customerService', 'Customer service'],
  ['handsOn', 'Hands-on experience'],
  ['support', 'Requested PESO support'],
  ['preference', 'Job priorities'],
  // Post-evaluation MRQ items are additional PESO application details,
  // never inputs to the occupation AI scoring process.
  ['roleRequirements', 'Role requirements reviewed'],
  ['workArrangement', 'Preferred work arrangement'],
  ['learning', 'Interest in additional training'],
]);

const COLUMNS = Object.freeze([
  'Applicant Name', 'Email', 'Barangay / Location', 'Phone', 'Years Experience',
  'Job Title', 'Employer', 'Job Location', 'Match Score', 'Application Status',
  'Pipeline Category', 'Submitted Date', 'Registered Date',
  ...ANSWER_COLUMNS.map(([, label]) => label),
]);

function excelSafe(value) {
  const text = String(value ?? '').slice(0, 32000);
  // Cell strings beginning with Excel formula triggers must remain text.
  return /^[=+\-@\t\r]/.test(text) ? "'" + text : text;
}

function when(value) {
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'number') return new Date(value).toISOString();
  return String(value ?? '');
}

function category(status, hasApplication) {
  if (!hasApplication) return 'Not Yet Applied';
  if (status === 'matched' || status === 'accepted') return 'Successful';
  if (status === 'rejected' || status === 'not_matched') return 'Needs Support';
  return 'Under Review';
}

export function buildAdminWorkbookRows({ profiles = [], applications = [] } = {}) {
  const profileByUid = new Map(
    profiles.filter((p) => p && p.uid && p.role !== 'admin' && p.firebaseAuthAccountDeleted !== true)
      .map((profile) => [String(profile.uid), profile]),
  );
  const matchedUids = new Set();
  const rows = [];

  for (const app of applications) {
    if (!app) continue;
    const uid = String(app.uid || app.applicantUid || '');
    const profile = profileByUid.get(uid) || {};
    const answerData = app.answers && typeof app.answers === 'object' && !Array.isArray(app.answers)
      ? app.answers : {};
    const status = String(app.status || 'submitted');
    const classified = category(status, true);
    rows.push([
      excelSafe(app.applicantName || profile.displayName || profile.email || ''),
      excelSafe(app.email || profile.email),
      excelSafe(profile.location || app.location || ''),
      excelSafe(profile.phoneNumber),
      Number.isFinite(Number(profile.yearsExperience)) && String(profile.yearsExperience ?? '') !== ''
        ? Number(profile.yearsExperience) : '',
      excelSafe(app.jobTitle), excelSafe(app.employer), excelSafe(app.location),
      Number.isFinite(Number(app.matchScore)) && app.matchScore != null
        ? Number(app.matchScore) : '',
      STATUS_LABELS[status] || excelSafe(status),
      classified,
      excelSafe(when(app.submittedAt)),
      excelSafe(when(profile.createdAt)),
      ...ANSWER_COLUMNS.map(([key]) => excelSafe(answerData[key])),
    ]);
    if (uid) matchedUids.add(uid);
  }

  for (const [uid, profile] of profileByUid) {
    if (matchedUids.has(uid)) continue;
    rows.push([
      excelSafe(profile.displayName ||
        [profile.firstName, profile.lastName].filter(Boolean).join(' ') ||
        profile.email || ''),
      excelSafe(profile.email),
      excelSafe(profile.location),
      excelSafe(profile.phoneNumber),
      Number.isFinite(Number(profile.yearsExperience)) && String(profile.yearsExperience ?? '') !== ''
        ? Number(profile.yearsExperience) : '',
      excelSafe(profile.professionalTitle || ''),
      '', '', '', 'Not Yet Applied', 'Not Yet Applied', '',
      excelSafe(when(profile.createdAt)), ...ANSWER_COLUMNS.map(() => ''),
    ]);
  }

  const rank = { Successful: 0, 'Under Review': 1, 'Needs Support': 2, 'Not Yet Applied': 3 };
  rows.sort((a, b) => (rank[a[10]] ?? 9) - (rank[b[10]] ?? 9) ||
    String(a[0]).localeCompare(String(b[0])) ||
    String(a[5]).localeCompare(String(b[5])));

  const sections = {
    'All Applicants': rows,
    Successful: rows.filter((row) => row[10] === 'Successful'),
    'Under Review': rows.filter((row) => row[10] === 'Under Review'),
    'Needs Support': rows.filter((row) => row[10] === 'Needs Support'),
    'Not Yet Applied': rows.filter((row) => row[10] === 'Not Yet Applied'),
  };
  return { headers: [...COLUMNS], sections };
}

export async function generateAdminWorkbookBuffer(data) {
  const XLSX = await import('xlsx');
  const report = buildAdminWorkbookRows(data);
  const workbook = XLSX.utils.book_new();
  for (const [name, rows] of Object.entries(report.sections)) {
    const sheet = XLSX.utils.aoa_to_sheet([report.headers, ...rows]);
    sheet['!cols'] = report.headers.map((header) => ({
      wch: Math.max(18, Math.min(header.length + 5, 38)),
    }));
    sheet['!autofilter'] = {
      ref: 'A1:' + XLSX.utils.encode_col(report.headers.length - 1) + (rows.length + 1),
    };
    XLSX.utils.book_append_sheet(workbook, sheet, name);
  }
  return XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
}
