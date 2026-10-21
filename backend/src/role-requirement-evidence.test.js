import test from 'node:test';
import assert from 'node:assert/strict';

import {
  inspectRoleRequirements, attributedRequirementsForRole,
} from './role-requirement-evidence.js';
import { normalizeBatchAnswer, createPublicPdfAiReader } from './gemini-public-pdf-reader.js';
import { buildAiJobRecords } from './public-pdf-ai-listings.js';
import { evaluateProfileAgainstJobs } from './mini-ai-service.js';

const source = {
  sourceId: 'qa-only-source',
  title: 'QA official publication',
  url: 'https://montalban.gov.ph/wp-content/uploads/2020/07/example.pdf',
};
const proposal = {
  role: 'EHS Staff',
  requirement: 'Must have workplace safety training',
  evidenceQuote: 'EHS Staff: Must have workplace safety training',
  page: 2,
  kind: 'mandatory',
};
function documentWith(proposals, overrides = {}) {
  return {
    pages: [{ page: 2, summary: 'Two real roles on this page.' }],
    listings: [{
      page: 2, company: 'Test Employer',
      roles: ['EHS Staff', 'Welder'],
      requirements: ['PESO should verify employer requirements'],
      roleRequirements: proposals,
      category: 'walk_in_application',
      ...overrides,
    }],
  };
}
const independentPages = [
  { pageNumber: 2, text: [
    'NOW HIRING. EHS Staff: Must have workplace safety training',
    'Welder: Welding qualification preferred',
  ].join('\n') },
];

test('Gemini status never becomes independent verification without matching real PDF text', () => {
  const returned = normalizeBatchAnswer(documentWith([
    { ...proposal, status: 'source_text_correlated', approved: true, verified: true },
  ]), { start: 2, end: 2 });
  assert.equal(returned.listings.length, 1);
  assert.equal(returned.listings[0].roleRequirements[0].status, 'needs_source_review');
  assert.equal(returned.listings[0].roleRequirements[0].verified, undefined);
  const records = buildAiJobRecords({ source, listings: returned.listings });
  const role = records.find(x => x.aiListingKind === 'role' && x.title.startsWith('EHS Staff'));
  assert.equal(role.requirementScope, 'unattributed_notice');
  assert.equal(role.roleRequirementEvidence.sourceReviewNeeded, 1);
  assert.ok(!role.requirements.some(x => x.includes('Must have workplace safety training')));
  assert.ok(role.unattributedRequirements.includes(proposal.requirement));
});

test('role-specific line corroborated in independent local PDF text becomes a bounded role requirement', () => {
  const returned = normalizeBatchAnswer(documentWith([
    proposal,
    { role: 'Welder', requirement: 'Welding qualification preferred',
      evidenceQuote: 'Welder: Welding qualification preferred',
      page: 2, kind: 'preferred' },
  ]), { start: 2, end: 2, sourceEvidencePages: independentPages });
  assert.equal(returned.listings[0].roleRequirements[0].status, 'source_text_correlated');
  const records = buildAiJobRecords({ source, listings: returned.listings });
  const ehs = records.find(x => x.title.startsWith('EHS Staff'));
  const welder = records.find(x => x.title.startsWith('Welder'));
  assert.equal(ehs.requirementScope, 'explicit_role');
  assert.equal(ehs.roleRequirementEvidence.correlatedSourceText, 1);
  assert.equal(ehs.roleRequirementEvidence.independentlyValidatedByEmployer, false);
  assert.ok(ehs.requirements.some(x => x.includes('EHS Staff: Must have workplace safety training required')));
  assert.ok(!ehs.requirements.some(x => x.startsWith('Welder:')));
  assert.equal(welder.requirementScope, 'explicit_role');
  assert.ok(welder.requirements.some(x => x.includes('Welding qualification preferred')));
  assert.ok(!welder.requirements.some(x => x.includes('Must have workplace safety training')));
});

test('never accept source quote for an unrelated role, wrong PDF page, missing text, or protected hiring criterion', () => {
  const base = documentWith([
    proposal,
    { ...proposal, role: 'Security Guard', requirement: 'Must have workplace safety training' },
    { ...proposal, page: 3, requirement: 'Must have workplace safety training' },
    { ...proposal, requirement: 'Male applicants only', evidenceQuote: 'EHS Staff: Male applicants only', kind: 'mandatory' },
    { ...proposal, requirement: 'NC II certificate',
      evidenceQuote: 'EHS Staff: NC II certificate', kind: 'mandatory' },
    { ...proposal, requirement: 'Must have driving license',
      evidenceQuote: 'Welder: Must have driving license', kind: 'mandatory' },
  ]);
  const results = normalizeBatchAnswer(base, {
    start: 2, end: 2,
    sourceEvidencePages: independentPages,
  }).listings[0].roleRequirements;
  assert.equal(results.length, 4, 'unknown role and out-of-range page are dropped');
  assert.equal(results[0].status, 'source_text_correlated');
  assert.equal(results[1].status, 'excluded_protected');
  assert.equal(results[2].status, 'needs_source_review');
  assert.equal(results[3].status, 'needs_source_review');
  assert.deepEqual(attributedRequirementsForRole({ roleRequirements: results }, 'EHS Staff').accepted,
    ['EHS Staff: Must have workplace safety training required']);
});

test('claimed mandatory qualification without an explicit statement stays pending human review', () => {
  const proposals = [
    { role: 'EHS Staff', requirement: 'OSH NC II', evidenceQuote: 'EHS Staff: OSH NC II',
      kind: 'mandatory', page: 2 },
  ];
  const inspected = inspectRoleRequirements({ roles: ['EHS Staff'], roleRequirements: proposals }, {
    start: 2, end: 2,
    independentPages: [{ pageNumber: 2, text: 'EHS Staff: OSH NC II' }],
  });
  assert.equal(inspected[0].status, 'needs_source_review');
  assert.deepEqual(attributedRequirementsForRole({ roleRequirements: inspected }, 'EHS Staff').accepted, []);
});

test('does not generate extra Gemini requests and attempts independent verification only once per PDF', async () => {
  let providerReads = 0;
  let evidenceReads = 0;
  const reader = createPublicPdfAiReader({
    batchPages: 1,
    upload: async () => ({ name: 'files/qa', uri: 'https://generativelanguage.googleapis.com/v1beta/files/qa' }),
    remove: async () => {},
    sourceEvidenceExtractor: async () => {
      evidenceReads += 1;
      return independentPages;
    },
    readRange: async ({ start }) => {
      providerReads += 1;
      return {
        pages: [{ page: start, summary: 'Source notice' }],
        listings: [{
          page: start, company: 'Test Employer', roles: ['EHS Staff', 'Welder'],
          roleRequirements: [{ ...proposal, page: start }],
          category: 'walk_in_application',
        }],
      };
    },
  });
  const read = await reader.readDocument({
    pageCount: 2, bytes: new Uint8Array(10), sourceTitle: 'QA source',
  });
  assert.equal(providerReads, 2);
  assert.equal(evidenceReads, 1);
  assert.equal(read.complete, true);
  assert.equal(read.listings[1].roleRequirements[0].status, 'source_text_correlated');
  assert.equal(read.listings[0].roleRequirements[0].status, 'needs_source_review');
});

test('old Go Mini-AI model scores only the role-specific verified requirements', async () => {
  const batch = normalizeBatchAnswer(documentWith([proposal]), {
    start: 2, end: 2, sourceEvidencePages: independentPages,
  });
  const records = buildAiJobRecords({ source, listings: batch.listings });
  const ehs = records.find(x => x.title.startsWith('EHS Staff'));
  ehs.id = 'real-role-qa-local-not-in-mongo';
  const match = await evaluateProfileAgainstJobs({
    profile: { skills: ['workplace safety'], yearsExperience: 0, educationLevel: 'Senior High School' },
    jobs: [ehs],
  });
  assert.equal(match.status, 'ready');
  assert.equal(match.modelVersion, 'peso-mini-ai-v1');
  assert.equal(match.results.length, 1);
  assert.equal(match.results[0].jobId, ehs.id);
  assert.ok(match.results[0].matchedSkills.includes('safety'));
});

test('not-required phrasing never becomes a mandatory requirement, even with matching PDF text', () => {
  const quote = 'EHS Staff: NC II certificate is not required';
  const result = inspectRoleRequirements({
    roles: ['EHS Staff'],
    roleRequirements: [{
      role: 'EHS Staff', requirement: 'NC II certificate is not required',
      evidenceQuote: quote, page: 2, kind: 'mandatory',
    }],
  }, { start: 2, end: 2, independentPages: [{ pageNumber: 2, text: quote }] });
  assert.equal(result[0].status, 'needs_source_review');
  assert.deepEqual(attributedRequirementsForRole({ roleRequirements: result }, 'EHS Staff').accepted, []);
});

test('a newly added manually entered real job is scored by the existing Go model without training', async () => {
  // Local memory only; this is not a fabricated live MongoDB job record.
  const incoming = {
    id: 'qa-only-new-admin-job',
    status: 'active',
    category: 'walk_in_application',
    title: 'Warehouse Inventory Clerk',
    company: 'Private local test employer',
    description: 'Inventory management',
    requirements: ['Must be experienced in inventory handling'],
  };
  const result = await evaluateProfileAgainstJobs({
    profile: { skills: ['Inventory'], yearsExperience: 1, educationLevel: 'High School' },
    jobs: [incoming],
  });
  assert.equal(result.status, 'ready');
  assert.equal(result.modelVersion, 'peso-mini-ai-v1');
  assert.equal(result.results[0].jobId, incoming.id);
});

test('a quote that spans another named role cannot contaminate the first role requirements', () => {
  const text = 'EHS Staff: Must have workplace safety training; Welder: Must have NC II certificate';
  const results = inspectRoleRequirements({
    roles: ['EHS Staff', 'Welder'],
    roleRequirements: [{
      role: 'EHS Staff', requirement: 'Must have NC II certificate',
      evidenceQuote: text, page: 2, kind: 'mandatory',
    }],
  }, {
    start: 2, end: 2, independentPages: [{ pageNumber: 2, text }],
  });
  assert.equal(results[0].status, 'needs_source_review');
});
