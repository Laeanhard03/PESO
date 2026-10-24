import assert from 'node:assert/strict';
import test from 'node:test';

import { buildAdminWorkbookRows, generateAdminWorkbookBuffer } from './admin-excel-report.js';

const profiles = [
  { uid: 'a', role: 'job_seeker', displayName: 'Worker One', email: 'one@example.org', createdAt: '2026-10-20' },
  { uid: 'b', role: 'job_seeker', displayName: '=danger()', email: 'two@example.org', createdAt: '2026-10-19' },
  { uid: 'admin', role: 'admin', displayName: 'Admin', email: 'admin@example.org' },
];

test('workbook includes all registered seekers and all applications', () => {
  const report = buildAdminWorkbookRows({
    profiles,
    applications: [
      { uid: 'a', jobTitle: 'Data Encoder', status: 'matched', submittedAt: '2026-10-20' },
      { uid: 'a', jobTitle: 'Store Assistant', status: 'rejected', submittedAt: '2026-10-19' },
    ],
  });
  assert.equal(report.sections['All Applicants'].length, 3);
  assert.equal(report.sections.Successful.length, 1);
  assert.equal(report.sections['Needs Support'].length, 1);
  assert.equal(report.sections['Not Yet Applied'].length, 1);
  assert.equal(report.sections['Under Review'].length, 0);
  assert.ok(report.sections['Not Yet Applied'][0][0].startsWith("'="));
  assert.ok(!report.sections['All Applicants'].some((row) => row[0] === 'Admin'));
});

test('Barangay / Location prefers the saved barangay for applications and registered-only profiles', () => {
  const report = buildAdminWorkbookRows({
    profiles: [
      { uid: 'applicant', role: 'job_seeker', displayName: 'Applicant', barangay: 'San Isidro', location: 'Montalban, Rizal' },
      { uid: 'registered-only', role: 'job_seeker', displayName: 'Registered Only', barangay: 'Mascap', location: 'Rodriguez, Rizal' },
    ],
    applications: [
      { uid: 'applicant', jobTitle: 'Store Assistant', location: 'Employer site', status: 'submitted', answers: { experience: 'New entrant' } },
    ],
  });
  const barangayColumn = report.headers.indexOf('Barangay / Location');
  assert.notEqual(barangayColumn, -1);
  assert.equal(report.sections['Under Review'][0][barangayColumn], 'San Isidro');
  assert.equal(report.sections['Not Yet Applied'][0][barangayColumn], 'Mascap');
});

test('xlsx contains five categorized sheets and applicant records', async () => {
  const buffer = await generateAdminWorkbookBuffer({ profiles, applications: [] });
  assert.ok(Buffer.isBuffer(buffer));
  const xlsx = await import('xlsx');
  const parsed = xlsx.read(buffer, { type: 'buffer' });
  assert.deepEqual(parsed.SheetNames, [
    'All Applicants', 'Successful', 'Under Review', 'Needs Support', 'Not Yet Applied',
  ]);
  assert.equal(xlsx.utils.sheet_to_json(parsed.Sheets['All Applicants']).length, 2);
});

test('PESO Excel export includes all ten post-AI MRQ answers separately from model inputs', () => {
  const answers = {
    experience: 'Training experience',
    workLocation: 'Local jobs',
    availability: 'Immediately',
    schedule: 'Daytime work',
    skills: 'Basic task familiarity',
    support: 'Interview coaching',
    preference: 'Stable hours',
    roleRequirements: 'Need employer clarification',
    workArrangement: 'Full-time on-site',
    learning: 'Short training',
  };
  const report = buildAdminWorkbookRows({ profiles, applications: [
    { uid: 'a', jobTitle: 'QA Construction Assistant',
      status: 'submitted', answers, submittedAt: '2026-10-21' },
  ] });
  const row = report.sections['Under Review'][0];
  for (const [label, value] of Object.entries({
    'Experience': answers.experience,
    'Work location preference': answers.workLocation,
    'Availability': answers.availability,
    'Work schedule preference': answers.schedule,
    'Task familiarity': answers.skills,
    'Requested PESO support': answers.support,
    'Job priorities': answers.preference,
    'Role requirements reviewed': answers.roleRequirements,
    'Preferred work arrangement': answers.workArrangement,
    'Interest in additional training': answers.learning,
  })) {
    const col = report.headers.indexOf(label);
    assert.notEqual(col, -1, label + ' header absent');
    assert.equal(row[col], value, label + ' was not exported');
  }
});

test('Excel preserves unexpected questionnaire answers and readable ongoing status', () => {
  const report = buildAdminWorkbookRows({
    profiles: [{ uid: 'a', role: 'job_seeker', displayName: 'Applicant A', barangay: 'San Isidro' }],
    applications: [{
      uid: 'a', jobTitle: 'Office Associate', status: 'ongoing',
      answers: { interviewWilling: 'Yes', companySpecificTraining: 'Willing to attend' },
    }],
  });
  const row = report.sections['Under Review'][0];
  assert.equal(row[report.headers.indexOf('Application Status')], 'Ongoing');
  assert.equal(row[report.headers.indexOf('Interview willingness')], 'Yes');
  assert.equal(row[report.headers.indexOf('Barangay / Location')], 'San Isidro');
  assert.equal(
    row[report.headers.indexOf('Additional screening responses')],
    'companySpecificTraining: Willing to attend',
  );
  assert.equal(row.length, report.headers.length);
});