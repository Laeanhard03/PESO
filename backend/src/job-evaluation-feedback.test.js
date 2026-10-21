import test from 'node:test';
import assert from 'node:assert/strict';
import {
  classifyJobFeedback, fallbackJobFeedback, safeGeminiFeedback,
  geminiFeedbackPrompt, chooseRelatedJobs,
} from './job-evaluation-feedback.js';
import { createGeminiProvider } from './gemini-provider.js';

const qualified = {
  jobId: 'job1', title: 'Welder', company: 'Example',
  score: 90, confidence: 'moderate',
  assessmentBasis: 'role_attributed_requirements', roleCriteriaCount: 2,
  matchedOccupationFields: ['construction_trades'],
  missingMandatory: [],
};
test('congratulate on evidence-based occupational overlap, never promise hiring', () => {
  const f = fallbackJobFeedback(qualified, 'Welder');
  assert.equal(f.status, 'match');
  assert.match(f.headline, /Congratulations/);
  assert.match(f.disclaimer, /not a hiring decision/);
});
test('missing attributed mandatory criteria override even a high occupation similarity score', () => {
  const f = fallbackJobFeedback({
    ...qualified, score: 100, missingMandatory: ['required professional driver license'],
  }, 'Bulldozer Driver');
  assert.equal(f.status, 'no_match');
  assert.equal(f.requirementsToReview.length, 1);
  assert.doesNotMatch(f.headline, /Congratulations/);
});
test('unknown mandatory criteria and missing profile do not become false disqualification', () => {
  const partial = fallbackJobFeedback({
    ...qualified, confidence: 'low', assessmentBasis: 'occupation_category_clues_only',
    roleCriteriaCount: 0,
  }, 'Medical Specialist');
  assert.equal(partial.status, 'match');
  assert.match(partial.explanation, /exact qualifications/i);
  const unknown = fallbackJobFeedback({score: 6, matchedOccupationFields: [],
    occupationFieldsToExplore: [], missingMandatory: []}, 'Unfamiliar Role');
  assert.equal(unknown.status, 'no_match');
});
test('unrelated career fields yield clear gentle feedback and preserve PESO applications', () => {
  const f = fallbackJobFeedback({
    ...qualified, score: 4, matchedOccupationFields: [],
    occupationFieldsToExplore: ['healthcare'], missingMandatory: [],
  }, 'Nurse');
  assert.equal(f.status, 'no_match');
  assert.match(f.explanation, /still send your application to PESO/i);
});
test('Gemini can only provide brief explanation; invented eligibility assertions are dropped', () => {
  assert.equal(safeGeminiFeedback(JSON.stringify({
    explanation: 'Congratulations, all requirements met and you are definitely eligible.',
  })), '');
  assert.equal(safeGeminiFeedback('not-json'), '');
  const accepted = 'Your listed welding skills relate to this occupation. PESO can review the role requirements with you.';
  assert.equal(safeGeminiFeedback(JSON.stringify({ explanation: accepted })), accepted);
  const prompt = geminiFeedbackPrompt(qualified, fallbackJobFeedback(qualified, 'Welder'));
  assert.ok(prompt.includes('"statusFixedByGoRules":"match"'));
  assert.ok(!prompt.includes('MRQ'));
  assert.ok(!prompt.includes('email'));
});
test('only jobs with actual shared occupation fields and no missing mandatory gaps are recommended', () => {
  const rows = [
    { ...qualified, jobId: 'current' },
    { ...qualified, jobId: 'skill1', title: 'Metal Worker', score: 88 },
    { ...qualified, jobId: 'skill2', title: 'Fabricator', score: 70, confidence: 'low' },
    { ...qualified, jobId: 'missing', title: 'Driver', missingMandatory: ['license'] },
    { ...qualified, jobId: 'unrelated', title: 'Nurse', matchedOccupationFields: [] },
  ];
  assert.deepEqual(chooseRelatedJobs('current', rows).map(x => x.jobId),
    ['skill1', 'skill2']);
});
test('Gemini explanation operation uses a strict JSON response with short deadline', async () => {
  let requestBody;
  const provider = createGeminiProvider({fetchImpl: async (_url, request) => {
    requestBody = JSON.parse(request.body);
    return {
      ok: true, status:200, headers: {get: () => null},
      json: async () => ({
        candidates: [{content: {parts: [{text: JSON.stringify({
          explanation: 'Your recorded background connects to this field. PESO can confirm the posted qualifications.',
        })}]}, finishReason:'STOP'}],
      }),
    };
  }});
  const answer = await provider({
    apiKey:'fake-test-key', model:'gemini-3.8-flash',
    operation:'job_evaluation_explanation',
    payload: {prompt:'Test safe evidence summary'},
  });
  assert.match(answer.text, /recorded background/);
  assert.equal(requestBody.generationConfig.responseMimeType, 'application/json');
  assert.equal(requestBody.generationConfig.maxOutputTokens, 350);
  assert.match(requestBody.systemInstruction.parts[0].text, /never/i);
});
