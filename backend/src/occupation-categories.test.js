import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  CAREER_FIELDS, ISCO_MAJOR_GROUPS, classifyJobOccupation,
  verifyOccupationCategories, deriveCategoriesFromVerifiedFacts,
} from './occupation-categories.js';
import { verifyGeminiFacts, evaluateProfileAgainstJobs, runGoModel } from './mini-ai-service.js';

test('occupation foundation covers 10 ISCO major groups with multi-domain coverage', () => {
  assert.equal(Object.keys(ISCO_MAJOR_GROUPS).length, 10);
  assert.ok(Object.keys(CAREER_FIELDS).length >= 25);
  for (const major of Object.keys(ISCO_MAJOR_GROUPS)) {
    assert.ok(Object.values(CAREER_FIELDS).some(f => f.iscoMajorGroups.includes(major)),
      'Missing major group ' + major);
  }
});
test('newly ingested jobs use existing global occupation fields without Gemini', () => {
  const titles = [
    ['Full Stack Software Developer', 'software_technology'],
    ['Staff Nurse', 'healthcare'],
    ['Electrician', 'electrical_trades'],
    ['Bulldozer Driver', 'driving_transport'],
    ['Restaurant Cook', 'hospitality_food'],
    ['Secondary School Teacher', 'education'],
    ['Bookkeeper', 'accounting_finance'],
    ['Carpenter', 'construction_trades'],
    ['Sales Cashier', 'sales_retail'],
    ['General Cleaner', 'facility_services'],
    ['Agricultural Farmer', 'agriculture'],
    ['Human Resources Staff', 'human_resources'],
    ['Warehouse Inventory Staff', 'logistics_warehouse'],
    ['School Principal Manager', 'management'],
    ['Medical Researcher', 'healthcare'],
  ];
  for (const [title, field] of titles) {
    assert.ok(classifyJobOccupation(title).some(x => x.field === field),
      title + ' was not categorized as ' + field);
  }
  assert.deepEqual(classifyJobOccupation('Rare Unrecognized Zyxologist'), []);
});
test('Gemini occupational proposals require source quote and actual matching domain', () => {
  const source = 'Fictional applicant worked as a welder and uses MS Excel for inventory.';
  const result = verifyOccupationCategories([
    { field: 'construction_trades', iscoMajorGroup: '7', evidenceQuote: 'welder' },
    { field: 'software_technology', iscoMajorGroup: '2', evidenceQuote: 'MS Excel' },
    { field: 'office_administration', iscoMajorGroup: '4', evidenceQuote: 'MS Excel' },
    { field: 'healthcare', iscoMajorGroup: '2', evidenceQuote: 'nurse' },
    { field: 'construction_trades', iscoMajorGroup: '7', evidenceQuote: 'Female applicant' },
  ], source);
  assert.deepEqual(result.map(x => x.field), ['construction_trades','office_administration']);
  assert.equal(result[0].provenance, 'source_corroborated_gemini_category');
  const verified = verifyGeminiFacts({
    skills: ['welder', 'MS Excel'], occupationCategories: [
      { field: 'construction_trades', iscoMajorGroup: '7', evidenceQuote: 'welder' },
    ],
  }, source);
  assert.ok(verified.occupationCategories.some(x => x.field === 'construction_trades'));
  assert.equal(verified.occupationCategories.some(x => x.field === 'software_technology'), false);
  assert.ok(deriveCategoriesFromVerifiedFacts(['welding']).some(x => x.field === 'construction_trades'));
});
test('MRQ answers never modify the applicant facts passed to Go', async () => {
  const profile = { skills: ['Welding'], educationLevel: 'Senior High School',
    aiMatchingExtraction: { status: 'verified', occupationCategories: [
      { field: 'construction_trades', iscoMajorGroup: '7' },
    ] } };
  const jobs = [{ id: 'qa-welder', title: 'Welder', status:'active',category:'walk_in_application',
    requirements: ['Must have trade experience'] }];
  const observed = [];
  const runner = async (applicant, inputs) => {
    observed.push(structuredClone(applicant));
    return { modelVersion:'test', results:inputs.map(job=>({jobId:job.id,score:50})) };
  };
  await evaluateProfileAgainstJobs({ profile, jobs, answers: {
    driverLicense:'Professional license', certificate:'Yes, current',
  }, runner });
  await evaluateProfileAgainstJobs({ profile, jobs, answers: {
    driverLicense:'None yet', certificate:'Not yet', skills:'I am an expert',
  }, runner });
  assert.equal(observed.length, 2);
  assert.deepEqual(observed[0], observed[1]);
  assert.deepEqual(observed[0].licenses, []);
  assert.deepEqual(observed[0].occupationCategories,
    [{ field:'construction_trades',iscoMajorGroup:'7' }]);
});
test('promoted Go occupation model distinguishes same specialty from unrelated fields', async () => {
  const jobs = [
    {id:'qa-welder',title:'Welder',status:'active',category:'walk_in_application'},
    {id:'qa-nurse',title:'Staff Nurse',status:'active',category:'walk_in_application'},
  ];
  const applicant = {skills:['welding'], educationLevel:'Senior High School',
    occupationCategories:[{field:'construction_trades',iscoMajorGroup:'7'}]};
  const answer = await runGoModel(applicant,jobs);
  assert.equal(answer.ok,true);
  const byId = new Map(answer.results.map(x=>[x.jobId,x]));
  assert.ok(byId.get('qa-welder').score > byId.get('qa-nurse').score);
  assert.deepEqual(byId.get('qa-welder').matchedOccupationFields,['construction_trades']);
  assert.equal(byId.get('qa-nurse').confidence,'low');
});
