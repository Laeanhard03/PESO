import test from 'node:test';
import assert from 'node:assert/strict';
import { enrichCareerOpportunities } from './career-opportunity-ranker.js';
import { fallbackJobFeedback, chooseRelatedJobs } from './job-evaluation-feedback.js';

// Synthetic applicants and job descriptions only. No real applicant records or writes.
const opportunities = [
  ['training-a', 'Production Trainee', 'manufacturing_operations'],
  ['training-b', 'Kitchen Helper', 'hospitality_food'],
  ['training-c', 'Office Apprentice', 'office_administration'],
  ['retail', 'Retail Cashier', 'sales_retail'],
  ['warehouse', 'Warehouse Assistant', 'logistics_warehouse'],
  ['food', 'Food Service Crew', 'hospitality_food'],
  ['office', 'Data Entry Clerk', 'office_administration'],
  ['welding', 'Welder', 'construction_trades'],
  ['driver', 'Delivery Driver', 'driving_transport'],
  ['engineer', 'Civil Engineer', 'engineering'],
  ['care', 'Care Assistant', 'healthcare'],
  ['it', 'IT Support', 'technical_services'],
];
const jobs = opportunities.map(([id,title]) => ({ _id:id, title }));
const modelRows = opportunities.map(([id,title,field]) => ({
  jobId:id, title, company:'Example employer',score:95,confidence:'low',
  roleCriteriaCount:0,assessmentBasis:'occupation_category_clues_only',
  matchedOccupationFields:[],occupationFieldsToExplore:[field],
  matchedTitleClues:[],matchedSkills:[],missingMandatory:[],
}));
const personas = [
  {name:'first-time applicant',skills:[]},
  {name:'school leaver',skills:[],education:'Senior High School'},
  {name:'working student',skills:[],school:'College'},
  {name:'retail volunteer',skills:['customer service']},
  {name:'former cashier',skills:['cash handling','inventory']},
  {name:'food preparation beginner',skills:['food preparation','cleaning']},
  {name:'office beginner',skills:['data entry']},
  {name:'warehouse beginner',skills:['stock handling']},
  {name:'experienced welder',skills:['welding','fabrication']},
  {name:'driver changing careers',skills:['driving','customer service']},
  {name:'electrician seeking office jobs',skills:['electrical wiring','microsoft excel']},
  {name:'applicant with mixed skills',skills:['sales','inventory','food handling']},
  {name:'applicant with nonmatching skills',skills:['abstract painting']},
  {name:'applicant who explicitly lacks a skill',skills:['No customer service']},
];
const doRank=persona => enrichCareerOpportunities(persona,jobs,modelRows);
test('repeated synthetic job seekers keep every role, respect known facts and give consistent results', ()=>{
  for(let round=0;round<20;round++){
    for(const person of personas){
      const results=doRank({...person, age:round+19, sex:round%2?'X':'Y', address:'Not for matching'});
      assert.equal(results.length,jobs.length,person.name);
      assert.equal(new Set(results.map(r=>r.jobId)).size,jobs.length,person.name);
      for(const row of results){
        assert.ok(Number.isFinite(row.opportunityRank) && row.opportunityRank>=0 && row.opportunityRank<=100,person.name);
        assert.ok(typeof row.opportunityPathway==='string' && row.opportunityPathway.length>0);
        assert.equal(row.score,95,'underlying Go model score is preserved');
        assert.equal(row.confidence,'low','insufficient evidence cannot become verified');
      }
      assert.deepEqual(results,doRank(person),`protected traits must not change ranking for ${person.name}`);
    }
  }
});
test('newcomers see training possibilities, with no claim that they qualify',()=>{
  for(const person of personas.filter(p=>p.skills.length===0)){
    const rows=doRank(person);
    for(const id of ['training-a','training-b','training-c']){
      const row=rows.find(r=>r.jobId===id);
      assert.equal(row.opportunityPathway,'training_pathway');
      assert.ok(row.opportunityRank>0);
      const advice=fallbackJobFeedback(row,row.title);
      assert.equal(advice.status,'needs_review');
      assert.match(advice.explanation,/still apply|can still apply/i);
      assert.doesNotMatch(advice.headline,/qualified|congratulations/i);
    }
    const unrelated=rows.find(r=>r.jobId==='engineer');
    assert.equal(unrelated.opportunityRank,0);
  }
});
test('portable skills find adjacent careers even when model confidence is low',()=>{
  const expectations=[
    ['retail volunteer','food','transferable_skills'],
    ['former cashier','warehouse','transferable_skills'],
    ['food preparation beginner','food','transferable_skills'],
    ['office beginner','office','transferable_skills'],
    ['experienced welder','welding','transferable_skills'],
    ['driver changing careers','driver','transferable_skills'],
    ['electrician seeking office jobs','office','transferable_skills'],
  ];
  for(const [name,id,pathway] of expectations){
    const row=doRank(personas.find(p=>p.name===name)).find(r=>r.jobId===id);
    assert.equal(row.opportunityPathway,pathway,`${name}: ${id}`);
    assert.ok(row.opportunityRank>0,`${name}: ${id}`);
    const feedback=fallbackJobFeedback(row,row.title);
    assert.equal(feedback.status,'needs_review');
    assert.match(feedback.explanation,/more details/i);
  }
});
test('missing license and missing evidence never become a confirmed match',()=>{
  const driver={...modelRows.find(r=>r.jobId==='driver'),confidence:'moderate',
    roleCriteriaCount:2,assessmentBasis:'role_attributed_requirements',
    matchedOccupationFields:['driving_transport'],
    missingMandatory:['required driver license']};
  const applicant={skills:['Driving'],occupationCategories:[{field:'driving_transport'}]};
  const row=enrichCareerOpportunities(applicant,[jobs.find(j=>j._id==='driver')],[driver])[0];
  assert.equal(row.opportunityPathway,'review_requirements');
  assert.ok(row.opportunitySignals.includes('employer_requirement_review'));
  assert.equal(fallbackJobFeedback(row,row.title).status,'no_match');
  assert.match(fallbackJobFeedback(row,row.title).explanation,/still apply/i);
  assert.equal(chooseRelatedJobs('driver',[row]).length,0);
});
test('simulated unfamiliar and negated skills cannot create invented fit',()=>{
  for(const name of ['applicant with nonmatching skills','applicant who explicitly lacks a skill']){
    const rows=doRank(personas.find(p=>p.name===name));
    assert.equal(rows.find(r=>r.jobId==='food').opportunityRank,0,name);
    assert.equal(rows.find(r=>r.jobId==='retail').opportunityRank,0,name);
    assert.equal(rows.filter(r=>r.opportunityRank>0).length,3,name);
  }
});
