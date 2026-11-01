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
test('show supported skill overlap without promising a job or hiring', () => {
  const f = fallbackJobFeedback(qualified, 'Welder');
  assert.equal(f.status, 'match');
  assert.equal(f.headline, 'Your skills may fit this job');
  assert.match(f.disclaimer, /do not decide if an employer will hire you/);
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
  assert.equal(partial.status, 'needs_review');
  assert.match(partial.explanation, /more details from the job post/i);
  assert.doesNotMatch(partial.headline, /Congratulations|Not a Match/i);
  const unknown = fallbackJobFeedback({score: 6, matchedOccupationFields: [],
    occupationFieldsToExplore: [], missingMandatory: []}, 'Unfamiliar Role');
  assert.equal(unknown.status, 'needs_review');
  const uncertainWithHighScore = fallbackJobFeedback({
    ...qualified, score: 100, confidence: 'low', roleCriteriaCount: 0,
    assessmentBasis: 'occupation_category_clues_only',
  }, 'Warehouseman');
  assert.equal(uncertainWithHighScore.status, 'needs_review');
});
test('unrelated career fields yield clear gentle feedback and preserve PESO applications', () => {
  const f = fallbackJobFeedback({
    ...qualified, score: 4, matchedOccupationFields: [],
    occupationFieldsToExplore: ['healthcare'], missingMandatory: [],
  }, 'Nurse');
  assert.equal(f.status, 'no_match');
  assert.match(f.explanation, /still apply/i);
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
test('beginners receive cautious trainee alternatives despite low occupation scores', () => {
  const rows = [
    { jobId: 'chosen', title: 'Architect', score: 6, matchedOccupationFields: [] },
    { jobId: 'trainee', title: 'Production Trainee', score: 6, confidence: 'low',
      opportunityRank: 24, opportunityPathway: 'training_pathway',
      matchedOccupationFields: [], missingMandatory: [] },
    { jobId: 'helper', title: 'Kitchen Helper', score: 6, confidence: 'low',
      opportunityRank: 24, opportunityPathway: 'training_pathway',
      matchedOccupationFields: [], missingMandatory: [] },
    { jobId: 'unrelated', title: 'Surgeon', score: 4, opportunityRank: 0,
      matchedOccupationFields: [], missingMandatory: [] },
    { jobId: 'licensed', title: 'Driver Helper', score: 60, opportunityRank: 64,
      opportunityPathway: 'training_pathway',
      matchedOccupationFields: [], missingMandatory: ['Verify driver license'] },
  ];
  const chosen = chooseRelatedJobs('chosen', rows);
  assert.deepEqual(chosen.map(x => x.jobId), ['helper', 'trainee']);
  assert.ok(chosen.every(x => x.reason.includes('what you need to apply')));
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

test('feedback is understandable in everyday English and offers an action', () => {
  const scenarios = [
    qualified,
    { ...qualified, confidence: 'low', roleCriteriaCount: 0,
      assessmentBasis: 'occupation_category_clues_only' },
    { ...qualified, score: 7, matchedOccupationFields: [],
      missingMandatory: ['driver_license'] },
    { score: 6, matchedOccupationFields: [], missingMandatory: [] },
    null,
  ];
  const jargon = /(?:ISCO|algorithm|inference|attribution|confidence score|occupational category|NSRP\/resume|Career Fit Needs Review|Not a Match Yet)/i;
  for (const model of scenarios) {
    const answer = fallbackJobFeedback(model, 'Example role');
    assert.ok(answer.headline.length < 45, answer.headline);
    assert.ok(answer.explanation.length < 260, answer.explanation);
    assert.doesNotMatch(answer.headline + ' ' + answer.explanation, jargon);
    assert.match(answer.explanation, /(apply|PESO|check|try again)/i);
    assert.doesNotMatch(answer.explanation, /(?:guaranteed|definitely qualified|you are rejected)/i);
  }
});
test('unsafe overconfident, jargon-heavy Gemini replies are ignored', () => {
  for (const explanation of [
    'You qualify for the position and you should start tomorrow. Your training matches the job.',
    'Your application is approved. You are now a confirmed hire at the company.',
    'You should not apply to this job. Your background may need more training.',
    'The ISCO-08 confidence score indicates strong fit. Please contact PESO for next steps.',
  ]) {
    assert.equal(safeGeminiFeedback(JSON.stringify({explanation})), '');
  }
});
