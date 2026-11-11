import test from 'node:test';
import assert from 'node:assert/strict';
import { enrichCareerOpportunities } from './career-opportunity-ranker.js';
import { normalizeApplicantProfile } from './mini-ai-service.js';

const a = skills => ({ skills, occupationCategories: [] });
const job = (id, title) => ({ _id: id, title });
const evidence = (id, fields = [], overrides = {}) => ({
  jobId: id, score: 100, confidence: 'low',
  assessmentBasis: 'occupation_category_clues_only',
  roleCriteriaCount: 0, matchedOccupationFields: [],
  occupationFieldsToExplore: fields, matchedTitleClues: [],
  matchedSkills: [], missingMandatory: [], ...overrides,
});
const score = (applicant, jobs, rows) => enrichCareerOpportunities(applicant, jobs, rows);

test('a newcomer can discover explicitly named training/helper pathways without inventing qualifications', () => {
  const jobs = [job('a', 'Production Trainee'), job('b', 'Electrical Engineer'),
    job('c', 'Kitchen Helper')];
  const result = score(a([]), jobs, jobs.map(j => evidence(j._id)));
  const map = Object.fromEntries(result.map(x => [x.jobId, x]));
  assert.equal(map.a.opportunityPathway, 'training_pathway');
  assert.equal(map.c.opportunityPathway, 'training_pathway');
  assert.ok(map.a.opportunityRank > map.b.opportunityRank);
  assert.equal(map.b.opportunityRank, 0);
  assert.equal(map.a.missingMandatory.length, 0);
  assert.ok(map.a.opportunitySignals.includes('requirements_unverified'));
});

test('cross-field transferable skills reveal adjacent jobs without falsely asserting qualifications', () => {
  const related = score(a(['Customer service']),
    [job('w', 'Service Waiter'), job('x', 'Civil Engineer')],
    [evidence('w', ['hospitality_food']), evidence('x', ['engineering'])]);
  assert.equal(related[0].jobId, 'w');
  assert.equal(related[0].opportunityPathway, 'transferable_skills');
  assert.deepEqual(related[0].opportunitySkillClues, ['customer service']);
  assert.equal(related[1].opportunityRank, 0);
  assert.equal(related[0].confidence, 'low');
  assert.equal(related[0].score, 100, 'original trained model score is immutable');
});

test('direct verified career field outranks transferable career bridge', () => {
  const person = { skills: ['Inventory'], occupationCategories: [
    { field: 'office_administration', iscoMajorGroup: '4' },
  ] };
  const roles = [job('a', 'Office Clerk'), job('b', 'Warehouseman')];
  const rows = [evidence('a', [], { matchedOccupationFields: ['office_administration'] }),
    evidence('b', ['logistics_warehouse'])];
  const scored = score(person, roles, rows);
  assert.ok(scored[0].opportunityRank > scored[1].opportunityRank);
  assert.equal(scored[0].opportunityPathway, 'related_career_field');
});

test('verified employer qualification gap is an explicit warning and lowers discovery priority', () => {
  const role = job('a', 'Delivery Driver');
  const baseline = evidence('a', [], { score: 73, confidence: 'medium',
    assessmentBasis: 'role_attributed_requirements', roleCriteriaCount: 2,
    matchedOccupationFields: ['driving_transport'] });
  const person = { skills: ['Driving'], occupationCategories: [
    { field: 'driving_transport', iscoMajorGroup: '8' },
  ] };
  const clear = score(person, [role], [baseline])[0];
  const gap = score(person, [role], [{
    ...baseline, missingMandatory: ['Verify required license: driver_license'],
  }])[0];
  assert.equal(gap.opportunityPathway, 'review_requirements');
  assert.ok(gap.opportunityRank < clear.opportunityRank);
  assert.ok(gap.opportunitySignals.includes('employer_requirement_review'));
});

test('irrelevant personal demographic fields do not change career-discovery ranking', () => {
  const role = job('a', 'Sales Associate');
  const base = a(['Sales']);
  const row = evidence('a', ['sales_retail']);
  const baseline = score(base, [role], [row])[0];
  const protectedVariant = score({
    ...base, gender:'female', age:61, religion:'none', disability:'unspecified',
    fullName:'Fictional Test Person', homeAddress:'Not scored',
  }, [role], [row])[0];
  assert.deepEqual(protectedVariant, baseline);
});

test('denials cannot generate transferable skill evidence or expose arbitrary source text', () => {
  const row = evidence('w', ['hospitality_food']);
  const [negated] = score(a(['No customer service']),
    [job('w', 'Service Waiter')], [row]);
  assert.equal(negated.opportunityRank, 0);
  const [privateText] = score(a(['Customer service; unrelated personal remarks']),
    [job('w', 'Service Waiter')], [row]);
  assert.deepEqual(privateText.opportunitySkillClues, ['customer service']);
});

test('missing skill statements and later confirmed training are handled separately', () => {
  const roles = [job('food', 'Food Service Crew')];
  const clues = [evidence('food', ['hospitality_food'])];
  for (const claim of [
    'No customer service',
    'without any customer service',
    'not skilled in customer service',
    'no experience with customer service',
  ]) {
    const output = score(a([claim]), roles, clues)[0];
    assert.equal(output.opportunityRank, 0, claim);
    assert.deepEqual(output.opportunitySkillClues, [], claim);
  }
  for (const claim of [
    'Completed customer service training',
    'No customer service but later gained customer service experience',
  ]) {
    const output = score(a([claim]), roles, clues)[0];
    assert.ok(output.opportunityRank > 0, claim);
    assert.equal(output.opportunityPathway, 'transferable_skills');
  }
});

test('specific Tagalog and Taglish skills help without treating denials as skills', () => {
  const jobs = [job('food','Food Crew'), job('driving','Delivery Driver'),
    job('retail','Retail Clerk')];
  const rows = [
    evidence('food',['hospitality_food']),
    evidence('driving',['driving_transport']),
    evidence('retail',['sales_retail']),
  ];
  const findRank = (skill,id) => score(a([skill]),jobs,rows)
    .find(item => item.jobId === id).opportunityRank;
  for (const [skill,id] of [
    ['pagluluto','food'],
    ['paghahanda ng pagkain','food'],
    ['pagbebenta','retail'],
    ['pagmamaneho','driving'],
    ['pagtanggap ng bayad','retail'],
    ['pag aasikaso ng customer','retail'],
  ]) {
    assert.ok(findRank(skill,id)>0,skill);
  }
  for (const [skill,id] of [
    ['hindi marunong magluto','food'],
    ['walang karanasan sa pagluluto','food'],
    ['hindi marunong sa pagbebenta','retail'],
    ['walang karanasan sa pagmamaneho','driving'],
  ]) {
    assert.equal(findRank(skill,id),0,skill);
  }
});

test('unverified Gemini-only claimed skill is never promoted into transferable opportunity', () => {
  const applicant = normalizeApplicantProfile({
    aiProfile: { skills: ['Customer Service'] },
    aiMatchingExtraction: { status: 'needs_review', skills: [],
      rejectedCount: 1, occupationCategories: [] },
    pesoFormData: { applicantEssentials: {
      education: 'High School', experience: 'No previous work experience',
      skillsStage: 'New entrant / still learning', skills: '',
    } },
  });
  const output = score(applicant, [job('a', 'Service Waiter')],
    [evidence('a', ['hospitality_food'])])[0];
  assert.equal(output.opportunityPathway, 'explore');
  assert.equal(output.opportunityRank, 0);
});
