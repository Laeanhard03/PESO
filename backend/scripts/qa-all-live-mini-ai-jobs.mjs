/**
 * Read-only QA of every listing shown by the authenticated PESO job feed.
 * Runs the shipped Go mini-AI against in-memory, fictional test profiles.
 * No Firebase login, Gemini API call, resume/customer data, or DB writes.
 *
 * Run from any directory: node backend/scripts/qa-all-live-mini-ai-jobs.mjs
 */
import path from 'node:path';
import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import { MongoClient } from 'mongodb';
import { evaluateProfileAgainstJobs, isRealVisibleJob } from '../src/mini-ai-service.js';
import { isJobPostingVisible } from '../src/job_postings.js';

const backend = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = path.resolve(backend, '..');
dotenv.config({ path: path.join(backend, '.env') });
const connection = String(process.env.MONGODB_URI || '').trim();
if (!connection || connection.includes('YOUR_CLUSTER_HOST')) {
  console.log('AUDIT_ERROR mongodb_not_configured');
  process.exitCode = 2;
} else {
  const personas = Object.freeze({
    beginner: Object.freeze({ skills: [], educationLevel: '', yearsExperience: 0 }),
    construction_demo: Object.freeze({
      skills: ['Construction', 'Welding', 'Heavy Equipment', 'Workplace Safety'],
      educationLevel: 'Senior High School', yearsExperience: 2,
      // Fictional, already-categorized intake evidence: NO per-job Gemini call.
      aiMatchingExtraction: {
        status: 'verified', skills: ['Construction', 'Welding', 'Heavy Equipment', 'Workplace Safety'],
        occupationCategories: [
          { field: 'construction_trades', iscoMajorGroup: '7' },
          { field: 'environment_safety', iscoMajorGroup: '3' },
          { field: 'manufacturing_operations', iscoMajorGroup: '8' },
        ],
      },
    }),
    office_demo: Object.freeze({
      skills: ['Microsoft Excel', 'Data Entry', 'Customer Service', 'Inventory'],
      educationLevel: 'College Graduate', yearsExperience: 2,
      aiMatchingExtraction: {
        status: 'verified', skills: ['Microsoft Excel', 'Data Entry', 'Customer Service', 'Inventory'],
        occupationCategories: [
          { field: 'office_administration', iscoMajorGroup: '4' },
          { field: 'data_services', iscoMajorGroup: '4' },
          { field: 'sales_retail', iscoMajorGroup: '5' },
          { field: 'logistics_warehouse', iscoMajorGroup: '4' },
        ],
      },
    }),
  });
  const projection = {
    _id: 1, status: 1, title: 1, company: 1, createdAt: 1, expiresAt: 1,
    category: 1, description: 1, requirements: 1, isSynthetic: 1,
    aiListingKind: 1, requirementScope: 1, sourceRoleCount: 1,
    unattributedRequirements: 1, sourceUrl: 1, sourceTitle: 1, sourcePageStart: 1,
  };
  const client = new MongoClient(connection, {
    serverSelectionTimeoutMS: 8500, connectTimeoutMS: 8500, maxPoolSize: 2,
  });
  const faults = [];
  const failures = [];
  const now = new Date();
  const id = (job) => String(job._id ?? job.id ?? '');
  const fail = (job, scenario, problem, diagnostic = '') => {
    faults.push({
      id: id(job), title: String(job.title || '').slice(0, 160),
      scenario, problem, diagnostic: String(diagnostic).slice(0, 75),
    });
  };
  const validResult = (result, input, scenario) => {
    const expectedIds = new Set(input.map(id));
    if (result.status !== 'ready') {
      for (const job of input) fail(job, scenario, 'model_not_ready', result.status);
      return [];
    }
    const results = Array.isArray(result.results) ? result.results : [];
    if (results.length !== input.length) {
      fail(input[0], scenario, 'result_count_mismatch',
        String(results.length) + '_instead_of_' + String(input.length));
    }
    const seen = new Set();
    for (const row of results) {
      const jobId = String(row.jobId || '');
      if (!expectedIds.has(jobId)) {
        fail(input[0], scenario, 'foreign_job_id', jobId);
        continue;
      }
      if (seen.has(jobId)) fail(input[0], scenario, 'duplicate_job_id', jobId);
      seen.add(jobId);
      if (!Number.isInteger(row.score) || row.score < 0 || row.score > 100) {
        fail(input[0], scenario, 'invalid_score', jobId);
      }
      if (!row.readiness || !['low', 'medium', 'moderate'].includes(row.confidence)) {
        fail(input[0], scenario, 'missing_readiness_or_confidence', jobId);
      }
      if (row.modelVersion !== 'peso-mini-ai-v1') {
        fail(input[0], scenario, 'unexpected_model_version', String(row.modelVersion));
      }
    }
    for (const job of input) {
      if (!seen.has(id(job))) fail(job, scenario, 'missing_job_result');
    }
    return results;
  };
  const stats = (results) => {
    const nums = results.map(x => x.score).filter(Number.isFinite).sort((a, b) => a - b);
    const median = nums.length ? nums[Math.floor((nums.length - 1) / 2)] : null;
    const distinctScores = new Set(nums);
    return {
      resultCount: results.length, scoreMin: nums[0] ?? null,
      scoreMedian: median, scoreMax: nums.at(-1) ?? null,
      distinctScoreCount: distinctScores.size,
      lowConfidence: results.filter(x => x.confidence === 'low').length,
      needsHumanReview: results.filter(x => (x.needsReview || []).length > 0).length,
      mandatoryGaps: results.filter(x => (x.missingMandatory || []).length > 0).length,
      excludedProtectedRequirements: results.filter(x => (x.excludedRequirements || []).length > 0).length,
      incompleteEmployerEvidence: results.filter(x => (x.needsReview || []).some(
        s => /incomplete|unverified|not confirmed|unattributed/i.test(s))).length,
      roleAttributedComparisons: results.filter(x => x.assessmentBasis === 'role_attributed_requirements').length,
      jobTitleCluesOnly: results.filter(x => x.assessmentBasis === 'job_title_clues_only').length,
      jobDetailsUnverified: results.filter(x => x.assessmentBasis === 'job_details_unverified').length,
      titleClueMatches: results.filter(x => (x.matchedTitleClues || []).length > 0).length,
      broadOccupationMatches: results.filter(x => (x.matchedOccupationFields || []).length > 0).length,
      broadOccupationFieldsToExplore: results.filter(x => (x.occupationFieldsToExplore || []).length > 0).length,
    };
  };
  try {
    await client.connect();
    const database = client.db(process.env.MONGODB_DB_NAME || 'peso_jobkonek');
    // Exactly the backend feed's selection order/limit; projection excludes account PII.
    const raw = await database.collection('jobPostings')
      .find({ status: 'active' }, { projection })
      .sort({ createdAt: -1 }).limit(1000).toArray();
    const feed = raw.filter(job => isJobPostingVisible(job, now));
    const eligible = feed.filter(job => isRealVisibleJob(job, now));
    const notices = feed.filter(job => String(job.aiListingKind || '').toLowerCase() === 'notice');
    const excludedOther = feed.filter(job => !isRealVisibleJob(job, now) &&
      String(job.aiListingKind || '').toLowerCase() !== 'notice');
    const singleResults = Array(eligible.length);
    const durations = Array(eligible.length);
    let next = 0;
    const worker = async () => {
      while (next < eligible.length) {
        const index = next++;
        const job = eligible[index];
        const start = performance.now();
        const result = await evaluateProfileAgainstJobs({ profile: personas.beginner, jobs: [job] });
        durations[index] = Math.round(performance.now() - start);
        const rows = validResult(result, [job], 'individual_beginner');
        singleResults[index] = rows[0] ?? null;
        if ((index + 1) % 60 === 0) {
          console.log('AUDIT_PROGRESS individual ' + (index + 1) + '/' + eligible.length);
        }
      }
    };
    await Promise.all(Array.from({ length: 6 }, () => worker()));
    console.log('AUDIT_PROGRESS individual complete ' + eligible.length + '/' + eligible.length);
    const scenarioResults = { beginner: singleResults.filter(Boolean) };
    for (const [scenario, profile] of Object.entries(personas)) {
      if (scenario === 'beginner') continue;
      const rows = [];
      for (let i = 0; i < eligible.length; i += 25) {
        const part = eligible.slice(i, i + 25);
        const result = await evaluateProfileAgainstJobs({ profile, jobs: part });
        rows.push(...validResult(result, part, 'chunk_' + scenario));
      }
      scenarioResults[scenario] = rows;
      console.log('AUDIT_PROGRESS ' + scenario + ' ' + rows.length + '/' + eligible.length);
    }
    let noticesCorrectlyExcluded = 0;
    for (const notice of notices) {
      const result = await evaluateProfileAgainstJobs({ profile: personas.beginner, jobs: [notice] });
      if (result.status === 'no_live_jobs' && Array.isArray(result.results) && result.results.length === 0) {
        noticesCorrectlyExcluded++;
      } else fail(notice, 'notice', 'aggregate_notice_was_scored', result.status);
    }
    const byId = {};
    for (const [scenario, rows] of Object.entries(scenarioResults)) {
      byId[scenario] = new Map(rows.map(row => [String(row.jobId), row]));
    }
    // Metamorphic check on real live listings: remove every protected
    // requirement identified by the Go model from a temporary in-memory copy.
    // Qualification scores, readiness, confidence and mandatory gaps must be
    // unaffected. Only review/provenance notes may legitimately change.
    const sensitiveJobs = eligible.filter(job =>
      (byId.beginner.get(id(job))?.excludedRequirements || []).length > 0);
    let protectedInvarianceComparisons = 0;
    for (const scenario of ['beginner', 'construction_demo']) {
      const profile = personas[scenario];
      for (let i = 0; i < sensitiveJobs.length; i += 25) {
        const originals = sensitiveJobs.slice(i, i + 25);
        const stripped = originals.map(job => {
          const excluded = new Set(
            (byId[scenario].get(id(job))?.excludedRequirements || [])
              .map(text => String(text).trim()));
          // Preserve legitimate clauses in mixed lines while removing only
          // the protected segments reported by Go. Rebuild the role prefix
          // so the sanitized job retains the same role-specific attribution.
          const stripExcluded = value => {
            const original = String(value || '').trim();
            if (!original || excluded.has(original)) return [];
            const role = String(job.title || '').split(' — ')[0].trim();
            const colon = original.indexOf(':');
            const rolePrefix = colon > 0 && original.slice(0, colon).trim().toLowerCase() === role.toLowerCase()
              ? original.slice(0, colon + 1) : '';
            const text = rolePrefix ? original.slice(colon + 1) : original;
            const parts = text.split(/[,;]/).map(x => x.trim()).filter(Boolean);
            const remaining = parts.filter(part => !excluded.has(part));
            if (remaining.length === parts.length) return [original];
            // One separated qualification per string: retaining the original
            // compound sentence would change "required" vs "preferred" parsing.
            return remaining.map(part => (rolePrefix ? rolePrefix + ' ' : '') + part);
          };
          const safe = list => Array.isArray(list)
            ? list.flatMap(stripExcluded) : [];
          return { ...job, requirements: safe(job.requirements),
            unattributedRequirements: safe(job.unattributedRequirements) };
        });
        const result = await evaluateProfileAgainstJobs({ profile, jobs: stripped });
        const responses = validResult(result, stripped, 'protected_removed_' + scenario);
        const lookup = new Map(responses.map(x => [String(x.jobId), x]));
        for (const job of originals) {
          const reference = byId[scenario].get(id(job));
          const current = lookup.get(id(job));
          if (!reference || !current) continue;
          protectedInvarianceComparisons++;
          for (const key of ['score', 'readiness', 'confidence', 'matchedSkills',
            'missingMandatory', 'featureContributions']) {
            if (JSON.stringify(reference[key]) !== JSON.stringify(current[key])) {
              fail(job, 'protected_invariance_' + scenario, 'protected_requirement_changed_' + key);
            }
          }
        }
      }
    }
    console.log('AUDIT_PROGRESS protected-invariance ' + protectedInvarianceComparisons);
    const perJob = eligible.map((job, index) => {
      const results = Object.fromEntries(Object.entries(byId).map(([scenario, lookup]) => {
        const row = lookup.get(id(job));
        return [scenario, row ? {
          score: row.score, readiness: row.readiness, confidence: row.confidence,
          assessmentBasis: row.assessmentBasis, roleCriteriaCount: row.roleCriteriaCount,
          matchedTitleClueCount: (row.matchedTitleClues || []).length,
          matchedOccupationFields: row.matchedOccupationFields || [],
          occupationFieldsToExplore: row.occupationFieldsToExplore || [],
          skillsToExploreCount: (row.skillsToExplore || []).length,
          missingMandatoryCount: (row.missingMandatory || []).length,
          reviewCount: (row.needsReview || []).length,
          excludedCount: (row.excludedRequirements || []).length,
        } : { status: 'unavailable_or_not_returned' }];
      }));
      return {
        id: id(job), title: String(job.title || '').slice(0, 160),
        kind: String(job.aiListingKind || 'ordinary'), category: job.category,
        requirementScope: String(job.requirementScope || ''),
        sourceRoleCount: Number(job.sourceRoleCount || 0),
        unattributedCount: Array.isArray(job.unattributedRequirements) ?
          job.unattributedRequirements.length : 0,
        individualInferenceMs: durations[index], results,
      };
    });
    const summary = {
      at: now.toISOString(),
      scope: 'Active authenticated /api/jobs feed, latest 1000 records; DB reads only',
      model: 'Shipped peso-mini-ai-v1 model, independent local Go subprocesses',
      disclaimer: 'Fictional applicants are QA fixtures. Scores are not validated hiring decisions or real-world accuracy.',
      feed: {
        activeRead: raw.length, visible: feed.length, eligibleRoles: eligible.length,
        aggregateNotices: notices.length, otherExcluded: excludedOther.length,
        noticesCorrectlyExcluded,
      },
      throughput: {
        individualRuns: eligible.length,
        maxIndividualMs: Math.max(0, ...durations),
        medianIndividualMs: durations.length ?
          [...durations].sort((a, b) => a - b)[Math.floor(durations.length / 2)] : null,
        batchRuns: 2 * Math.ceil(eligible.length / 25),
        protectedInvarianceComparisons,
        protectedInvarianceRoles: sensitiveJobs.length,
      },
      quality: {
        rolesWithUnattributedRequirements: eligible.filter(x =>
          Array.isArray(x.unattributedRequirements) && x.unattributedRequirements.length > 0).length,
        rolesMissingSourceUrl: eligible.filter(x => !String(x.sourceUrl || '').startsWith('https://')).length,
        rolesMissingTitle: eligible.filter(x => !String(x.title || '').trim()).length,
        rolesMissingRequirements: eligible.filter(x => !Array.isArray(x.requirements) || !x.requirements.length).length,
        noticeNamesOnly: notices.map(x => String(x.title || '').slice(0, 120)),
      },
      scenarioStats: Object.fromEntries(Object.entries(scenarioResults).map(
        ([scenario, rows]) => [scenario, stats(rows)])),
      faultCount: faults.length, faults,
    };
    const report = { summary, perJob };
    const file = path.join(root, 'docs', 'MINI_AI_ALL_JOBS_AUDIT_2026-10-20.json');
    await fs.mkdir(path.dirname(file), { recursive: true });
    await fs.writeFile(file, JSON.stringify(report, null, 2), { encoding: 'utf8' });
    console.log('AUDIT_REPORT ' + file);
    console.log('AUDIT_SUMMARY ' + JSON.stringify({
      ...summary, quality: { ...summary.quality, noticeNamesOnlyCount: notices.length,
        noticeNamesOnly: undefined }, faults: faults.slice(0, 15),
    }));
    if (faults.length) process.exitCode = 1;
  } catch (error) {
    failures.push({ kind: String(error?.name || 'Error'), code: String(error?.code || '') });
    console.log('AUDIT_ABORT ' + JSON.stringify(failures));
    process.exitCode = 2;
  } finally {
    await client.close();
  }
}
