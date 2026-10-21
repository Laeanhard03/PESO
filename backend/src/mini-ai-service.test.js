import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  normalizeApplicantProfile, evidenceForGemini, verifyGeminiFacts,
  isRealVisibleJob, evaluateProfileAgainstJobs, runGoModel,
} from './mini-ai-service.js';

test('normalizes job-relevant PESO, NSRP and resume fields without demographic identity', () => {
  const applicant = normalizeApplicantProfile({
    displayName: 'Do Not Score This Name', educationLevel: 'Senior High School',
    aiProfile: { skills: ['Cash handling'], yearsExperience: 1 },
    pesoFormData: { entries: [
      { label: 'VII WORK EXPERIENCE', value: 'Retail staff' },
      { label: 'Sex', value: 'Male' }, { label: 'Mobile number', value: '9000000000' },
      { label: 'Other skills acquired', value: 'MS Excel' },
    ] },
  }, { driverLicense: 'Non-professional license' });
  assert.ok(!applicant.skills.includes('Cash handling'), 'unverified Gemini-only skill must not be trusted');
  assert.ok(applicant.skills.includes('MS Excel'));
  assert.deepEqual(applicant.licenses, [],
    'post-evaluation MRQ answers must NEVER affect applicant matching features');
  assert.ok(!JSON.stringify(applicant).includes('Do Not Score'));
  assert.ok(!JSON.stringify(applicant).includes('9000000000'));
  assert.ok(!evidenceForGemini({ pesoFormData: { entries: [
    { label: 'Religion', value: 'Not Relevant' },
    { label: 'Skills', value: 'Cash handling' },
  ] } }).includes('Not Relevant'));
});

test('modern saved NSRP essentials and resume fields survive Gemini partial review', () => {
  const applicant = normalizeApplicantProfile({
    aiProfile: { skills: ['Invented skill'] },
    aiMatchingExtraction: { status: 'needs_review', skills: [], certifications: [] },
    pesoFormData: {
      applicantEssentials: {
        education: 'Senior High School',
        experience: 'No previous work experience',
        skillsStage: 'Has skills or training to list',
        skills: 'MS Excel, Customer service',
        preferredOccupation: 'Office Clerk',
      },
    },
    resumeData: { fields: [{ label: 'Work experience', value: 'Retail cashier' }] },
  });
  assert.ok(applicant.skills.includes('MS Excel'));
  assert.ok(applicant.skills.includes('Customer service'));
  assert.ok(!applicant.skills.includes('Invented skill'));
  assert.equal(applicant.educationLevel, 'Senior High School');
  assert.equal(applicant.incomplete, false);
  assert.ok(Array.isArray(applicant.occupationCategories));
});

test('Gemini skills not found in source evidence are withheld for review', () => {
  const checked = verifyGeminiFacts(
    { skills: ['Microsoft Excel', 'Welding'], certifications: ['NC II'] },
    'The resume includes Microsoft Excel and customer service.',
  );
  assert.deepEqual(checked.skills, ['Microsoft Excel']);
  assert.equal(checked.status, 'needs_review');
  assert.ok(checked.rejectedCount >= 2);
});
test('synthetic and expired government jobs never enter inference', async () => {
  const input = [
    { _id: 'real1', status: 'active', category: 'walk_in_application', title: 'Cashier' },
    { _id: 'fake', status: 'active', isSynthetic: true, category: 'walk_in_application' },
    { _id: 'expired', status: 'active', category: 'local_recruitment_activity', expiresAt: '2020-01-01' },
  ];
  assert.equal(isRealVisibleJob(input[1]), false);
  assert.equal(isRealVisibleJob(input[2]), false);
  let received;
  const report = await evaluateProfileAgainstJobs({
    profile: { aiProfile: { skills: ['Cash handling'] } }, jobs: input,
    runner: async (a, jobs) => {
      received = jobs;
      return { modelVersion: 'test', results: [{ jobId: 'real1', score: 65 }] };
    },
  });
  assert.equal(received.length, 1);
  assert.equal(report.results[0].title, 'Cashier');
});
test('missing model does not break user workflow', async () => {
  const report = await evaluateProfileAgainstJobs({
    profile: {}, jobs: [{ id: 'a', title: 'Clerk', category: 'walk_in_application', status: 'active' }],
    runner: async () => { throw new Error('intentional unavailable model'); },
  });
  assert.equal(report.ok, true);
  assert.equal(report.status, 'unavailable');
  assert.deepEqual(report.results, []);
});
test('Go real model process returns versioned inference', async () => {
  const report = await runGoModel({ skills: ['sales'], yearsExperience: 1 },
    [{ _id: 'synthetic-test-id', title: 'Sales Associate', status: 'active', category: 'walk_in_application' }]);
  assert.equal(report.ok, true);
  assert.equal(report.results.length, 1);
  assert.equal(report.results[0].modelVersion, 'peso-mini-ai-v1');
  assert.ok(report.results[0].score >= 0 && report.results[0].score <= 100);
});

test('source evidence normalization, uncertain years, and partial review', () => {
  const reviewed = verifyGeminiFacts({
    skills: ['MS-Excel', 'Welding', 'Graphic Design'],
    education: ['Senior High School'],
    certifications: ['NC-II', 'CPA'],
    yearsExperience: 9,
  }, 'Senior high school graduate. Experienced with MS Excel and graphic design. NC II certified. No welding.');
  assert.deepEqual(reviewed.skills, ['MS-Excel', 'Graphic Design']);
  assert.deepEqual(reviewed.education, ['Senior High School']);
  assert.deepEqual(reviewed.certifications, ['NC-II']);
  assert.equal(reviewed.yearsExperience, 0);
  assert.equal(reviewed.status, 'needs_review');
  const applicant = normalizeApplicantProfile({
    aiProfile: { skills: ['MS-Excel', 'Welding'], education: ['MBA'], certifications: ['CPA'], yearsExperience: 9 },
    aiMatchingExtraction: reviewed, skills: ['MS-Excel', 'Welding'],
  });
  assert.deepEqual(applicant.skills, ['MS-Excel', 'Graphic Design']);
  assert.equal(applicant.yearsExperience, 0);
  assert.equal(applicant.certifications.includes('CPA'), false);
  assert.equal(applicant.educationLevel, 'Senior High School');
});

test('updated applicant-owned NSRP evidence can resolve rejected Gemini review without trusting the rejected claim', () => {
  const reviewed = verifyGeminiFacts({ skills: ['Invented skill'] }, 'No verified skills are stated.');
  const source = {
    education: 'Senior High School',
    experience: 'No previous work experience',
    skillsStage: 'Has skills or training to list',
    skills: 'Welding',
  };
  const form = {
    applicantEssentials: source,
    entries: [
      { label: 'Highest education attained', value: source.education },
      { label: 'Work experience status', value: source.experience },
      { label: 'Other skills acquired', value: source.skills },
    ],
  };
  const profile = {
    aiProfile: { skills: ['Invented skill'], yearsExperience: 10 },
    aiMatchingExtraction: reviewed, pesoFormData: form,
  };
  const normalized = normalizeApplicantProfile(profile);
  assert.deepEqual(normalized.skills, ['Welding']);
  assert.equal(normalized.educationLevel, 'Senior High School');
  assert.equal(normalized.yearsExperience, 0);
  assert.equal(normalized.incomplete, false);

  const uncertain = normalizeApplicantProfile({
    ...profile,
    pesoFormData: { ...form, applicantEssentials: { ...source, experience: 'Prefer to discuss with PESO' } },
  });
  assert.equal(uncertain.incomplete, true);
  const trainee = normalizeApplicantProfile({
    ...profile,
    pesoFormData: {
      applicantEssentials: { ...source, skillsStage: 'New entrant / still learning', skills: '' },
      entries: [{ label: 'Highest education attained', value: source.education }],
    },
  });
  assert.deepEqual(trainee.skills, []);
  assert.equal(trainee.incomplete, true);
});

test('notices are never passed to model even when active, while actual roles remain', async () => {
  const jobs = [
    { id: 'notice', status: 'active', aiListingKind: 'notice', category: 'walk_in_application' },
    { id: 'role', status: 'active', aiListingKind: 'role', title: 'Welder', category: 'walk_in_application' },
    { id: 'regular', status: 'active', title: 'Office Clerk', category: 'walk_in_application' },
    { id: 'inactive', status: 'inactive', category: 'walk_in_application' },
  ];
  assert.equal(isRealVisibleJob(jobs[0]), false);
  let selected;
  const result = await evaluateProfileAgainstJobs({ profile: {}, jobs, runner: async (_a, input) => {
    selected = input.map(j => j.id);
    return { modelVersion: 'test', results: input.map(j => ({ jobId: j.id, score: 55 })) };
  } });
  assert.deepEqual(selected, ['role', 'regular']);
  assert.deepEqual(result.results.map(r => r.jobId), ['role', 'regular']);
});

test('subprocess missing binary and timeout are safe and do not invent match scores', async () => {
  const { executeGoInference } = await import('./mini-ai-service.js');
  await assert.rejects(executeGoInference('nonexistent-peso-model-executable-xyz', [], { input: '{}' }));
  const timeout = await evaluateProfileAgainstJobs({
    profile: {}, jobs: [{ id: 'one', title: 'Cashier', status: 'active', category: 'walk_in_application' }],
    runner: async () => { throw new Error('go_model_timeout'); },
  });
  assert.equal(timeout.status, 'unavailable');
  assert.deepEqual(timeout.results, []);
});

test('unsupported Gemini-only skill cannot reenter through punctuation or case variants of the legacy top-level mirror', () => {
  const review = verifyGeminiFacts({ skills: ['MS-Excel'] }, 'No verified skills are stated.');
  assert.equal(review.status, 'needs_review');
  assert.equal(review.rejectedCount, 1);
  assert.deepEqual(review.skills, []);
  const aliases = ['MS Excel', 'ms.excel', 'Ms___eXcEl', ' MS : EXCEL ', 'ms-- excel', 'ms\tEXCEL'];
  for (const alias of aliases) {
    const applicant = normalizeApplicantProfile({
      skills: [alias, 'Cash Handling'],
      aiProfile: { skills: ['MS-Excel'], yearsExperience: 9 },
      aiMatchingExtraction: review,
    });
    assert.deepEqual(applicant.skills, ['Cash Handling'], 'leaked unsupported alias ' + alias);
    assert.equal(applicant.yearsExperience, 0);
  }
  // Mirror comparison must be symmetric across the AI and stored representations.
  const reverse = normalizeApplicantProfile({
    skills: ['mS-ExCeL'],
    aiProfile: { skills: ['MS Excel'] },
    aiMatchingExtraction: review,
  });
  assert.deepEqual(reverse.skills, []);
});

test('supported Gemini facts and independent PESO/NSRP/resume skill evidence survive canonical mirror filtering', () => {
  const verified = verifyGeminiFacts({ skills: ['MS-Excel'] }, 'Uses ms excel for budgeting.');
  assert.equal(verified.status, 'verified');
  assert.deepEqual(verified.skills, ['MS-Excel']);
  const confirmed = normalizeApplicantProfile({
    skills: ['mS. EXCEL'],
    aiProfile: { skills: ['MS-Excel'] },
    aiMatchingExtraction: verified,
  });
  assert.ok(confirmed.skills.includes('mS. EXCEL'), 'source-supported canonical variant must remain');

  const unsupported = verifyGeminiFacts({ skills: ['MS-Excel', 'Welding'] }, 'No verified skills.');
  const fromSource = normalizeApplicantProfile({
    skills: ['MS Excel', 'weLDing'],
    aiProfile: { skills: ['MS-Excel', 'WELDING'] },
    aiMatchingExtraction: unsupported,
    pesoFormData: { entries: [{ label: 'Other skills acquired', value: 'MS.Excel' }] },
    resumeData: { fields: [{ label: 'Technical Skills', value: 'Welding' }] },
  });
  assert.ok(fromSource.skills.includes('MS.Excel'), 'independent NSRP evidence must be kept');
  assert.ok(fromSource.skills.includes('Welding'), 'independent resume evidence must be kept');
});

test('long public employer requirements reach Go intact while applicant skills remain bounded', async () => {
  const line = 'Branch Manager: Female or Male Applicant; Graduate of a four-year college course; ' +
    'With supervisory and sales experience; With relevant retail operations experience; ' +
    'Must know inventory management and customer service; Required communication skills';
  assert.ok(line.length > 150, 'fixture must reproduce the former 150-character truncation');
  let received;
  await runGoModel({ skills: ['sales'] }, [{
    id: 'fictional-composite', title: 'Branch Manager', aiListingKind: 'role',
    requirementScope: 'explicit_role', sourceRoleCount: 4,
    requirements: [line], unattributedRequirements: [line],
  }], { execImpl: async (_executable, _args, options) => {
    received = JSON.parse(options.input);
    return { stdout: JSON.stringify({ ok: true, results: [] }) };
  } });
  assert.equal(received.jobs[0].requirements[0], line);
  assert.equal(received.jobs[0].unattributedRequirements[0], line);
});

test('legacy NSRP work and skill facts create occupation fields without another Gemini request', () => {
  const applicant = normalizeApplicantProfile({
    educationLevel: 'Senior High School',
    aiProfile: { skills: ['Unverified nurse license'], professionalTitle: 'Nurse' },
    pesoFormData: { entries: [
      { section: 'Applicant information', label: 'Occupation', value: 'Construction carpenter' },
      { section: 'Training', label: 'Skills', value: 'Welding' },
      { label: 'Sex', value: 'Male' },
    ] },
  });
  assert.ok(applicant.occupationCategories.some(c => c.field === 'construction_trades'));
  assert.equal(applicant.occupationCategories.some(c => c.field === 'healthcare'), false);
  assert.deepEqual(applicant.licenses, []);
  assert.equal(applicant.skills.includes('Unverified nurse license'), false);
});
