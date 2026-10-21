import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { isJobPostingVisible } from './job_postings.js';
import {
  verifyOccupationCategories, deriveCategoriesFromVerifiedFacts,
  classifyJobOccupation,
} from './occupation-categories.js';

export function executeGoInference(executable, args, { input, timeout = 8500, maxBuffer = 2 * 1024 * 1024 } = {}) {
  return new Promise((resolve, reject) => {
    let child;
    try {
      child = spawn(executable, args, { windowsHide: true, shell: false, stdio: ['pipe', 'pipe', 'pipe'] });
    } catch {
      reject(new Error('go_model_start_failed'));
      return;
    }
    let settled = false;
    const chunks = [];
    let bytes = 0;
    const finish = (error, result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (error) reject(error);
      else resolve(result);
    };
    const timer = setTimeout(() => {
      finish(new Error('go_model_timeout'));
      child.kill();
    }, timeout);
    child.on('error', () => finish(new Error('go_model_start_failed')));
    child.stdout.on('data', chunk => {
      bytes += chunk.length;
      if (bytes > maxBuffer) {
        finish(new Error('go_model_output_limit'));
        child.kill();
      } else if (!settled) {
        chunks.push(chunk);
      }
    });
    // Drain diagnostics without collecting or logging potentially private resume text.
    child.stderr.resume();
    child.on('close', code => {
      if (code !== 0) return finish(new Error('go_model_process_failed'));
      finish(null, { stdout: Buffer.concat(chunks).toString('utf8') });
    });
    child.stdin.on('error', () => {});
    child.stdin.end(input ?? '');
  });
}
const backend = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const project = path.resolve(backend, '..');
const defaultBinary = path.join(project, 'mini_ai', 'bin',
  process.platform === 'win32' ? 'peso-mini-ai.exe' : 'peso-mini-ai');
const defaultModel = path.join(project, 'mini_ai', 'data', 'model_v1.json');

// Backend Vercel deployments have root directory /backend, not the sibling
// /mini_ai project. The Linux build and exact trained model are shipped under
// backend/mini_ai_runtime and copied to writable /tmp once per function instance.
// Static file URL arguments make both assets visible to Vercel's file tracer.
// No Go compiler, Windows executable, source profile or model retraining is needed.
let packagedRuntime;
function packagedAsset(sourceUrl, filename) {
  // Bundlers may relocate the compiled server entrypoint. Try the original
  // source-relative path and the includeFiles root without relying on cwd alone.
  const candidates = [
    fileURLToPath(sourceUrl),
    path.join(process.cwd(), 'mini_ai_runtime', filename),
    path.join(backend, 'mini_ai_runtime', filename),
    path.join(path.dirname(fileURLToPath(import.meta.url)), 'mini_ai_runtime', filename),
  ];
  const found = candidates.find(candidate => fs.existsSync(candidate));
  if (!found) throw new Error('go_model_bundle_missing');
  return found;
}
function preparePackagedGoRuntime() {
  if (packagedRuntime) return packagedRuntime;
  const sourceBinary = packagedAsset(
    new URL('../mini_ai_runtime/peso-mini-ai', import.meta.url), 'peso-mini-ai');
  const sourceModel = packagedAsset(
    new URL('../mini_ai_runtime/model_v1.json', import.meta.url), 'model_v1.json');
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'peso-mini-ai-'));
  const executable = path.join(temp, 'peso-mini-ai');
  const model = path.join(temp, 'model_v1.json');
  fs.copyFileSync(sourceBinary, executable);
  fs.chmodSync(executable, 0o700);
  fs.copyFileSync(sourceModel, model);
  packagedRuntime = { executable, model };
  return packagedRuntime;
}
const jobRelated = /skill|experience|education|course|train|vocation|certif|license|occupation|employment|qualification|professional|work history|work experience|college|graduate|computer|technology/i;
const protectedOrContact = /name|email|phone|mobile|address|gender|sex|birth|age|religion|civil status|marital|disab|nationality|ethnic|sss|tin\b|philhealth|passport|government id|household|parent|spouse|height|weight/i;

// Compare source claims, verified facts, and legacy mirrors in the same
// conservative form. Preserve the original text for display and audit.
function canonicalMatchingFact(value) {
  return String(value ?? '').toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();
}

function stringList(value, limit = 30, itemChars = 150) {
  return (Array.isArray(value) ? value : typeof value === 'string' ? value.split(/[,;\n]/) : [])
    .filter(v => typeof v === 'string')
    .map(s => s.trim().slice(0, itemChars)).filter(Boolean).slice(0, limit);
}
function meaningfulFields(structured, key) {
  const entries = Array.isArray(structured?.[key]) ? structured[key] : [];
  return entries.filter(x => x && typeof x === 'object').map(x => ({
    label: [x.section, x.label].filter(Boolean).join(' '),
    value: typeof x.value === 'string' ? x.value.slice(0, 600) : '',
  })).filter(x => x.value && jobRelated.test(x.label) && !protectedOrContact.test(x.label));
}
function extractEvidence(profile) {
  const fromNsrp = meaningfulFields(profile?.pesoFormData, 'entries');
  const fromResume = meaningfulFields(profile?.resumeData, 'fields');
  return [...fromNsrp, ...fromResume].slice(0, 100);
}
function safeYears(value) {
  const years = Number(value);
  return Number.isFinite(years) && years >= 0 && years <= 70 ? Math.round(years) : 0;
}
export function normalizeApplicantProfile(profile = {}) {
  const ai = profile?.aiProfile && typeof profile.aiProfile === 'object' ? profile.aiProfile : {};
  const verification = profile?.aiMatchingExtraction;
  // Verified and partly verified extracts both contain individually supported facts.
  // The unfiltered Gemini profile is retained for review, never for model features.
  const trusted = verification && ['verified', 'needs_review'].includes(verification.status)
    ? verification : {};
  const fields = extractEvidence(profile);
  const evidenceSkills = fields.filter(x => /skill|certif|training|qualification|technology|computer/i.test(x.label))
    .flatMap(x => stringList(x.value, 15));
  // Modern NSRP stores some user-confirmed essentials separately from entries.
  // They are independently entered source facts, not unchecked Gemini guesses.
  const sources = [profile?.pesoFormData?.applicantEssentials,
    profile?.resumeData?.applicantEssentials].filter(x =>
    x && typeof x === 'object' && !Array.isArray(x));
  const essentialSkills = sources.flatMap(source =>
    source.skillsStage === 'Has skills or training to list'
      ? stringList(source.skills, 15) : []);
  const essentialEducation = sources.map(source => String(source.education || '').trim())
    .filter(Boolean).slice(0, 5);
  const evidenceEducation = fields.filter(x => /education|course|college|graduate|vocation/i.test(x.label))
    .map(x => x.value).slice(0, 8);
  const evidenceExperience = fields.filter(x => /work experience|employment history|occupation/i.test(x.label))
    .map(x => x.value).slice(0, 10);
  const trustedSkills = stringList(trusted.skills);
  const geminiSkills = new Set(stringList(ai.skills).map(canonicalMatchingFact).filter(Boolean));
  const supportedSkills = new Set([...trustedSkills, ...evidenceSkills, ...essentialSkills]
    .map(canonicalMatchingFact).filter(Boolean));
  // The top-level list may mirror Gemini's unverified claims. Discard matching
  // aliases unless individually verified or present in independent form/resume
  // evidence; those source fields are also added below in their original form.
  const formSkills = stringList(profile.skills).filter(value => {
    const fact = canonicalMatchingFact(value);
    return Boolean(fact) && (!geminiSkills.has(fact) || supportedSkills.has(fact));
  });
  const education = [...stringList(trusted.education, 8), ...evidenceEducation, ...essentialEducation];
  const skills = [...formSkills, ...trustedSkills, ...evidenceSkills, ...essentialSkills];
  const certs = [...stringList(trusted.certifications),
    ...fields.filter(x => /certif|license|training/i.test(x.label)).map(x => x.value)];
  // License/certificate evidence must originate in the saved NSRP or resume,
  // never from post-evaluation application screening answers.
  const licenses = [...new Set([
    ...fields.filter(x => /driving licen[sc]e|professional licen[sc]e/i.test(x.label))
      .map(x => x.value),
  ])].slice(0, 15);
  // Gemini years are never established; only a separately entered numeric profile value counts.
  const experienceYears = safeYears(profile.yearsExperience);
  const explicitEducation = String(profile.educationLevel || '').trim();
  // Independently entered and saved applicant essentials can resolve a
  // partially rejected Gemini extraction. Rejected Gemini-only claims never
  // count, and a first-time job seeker without skills remains incomplete.
  const independentlyComplete = sources.some(source => {
    const experience = String(source.experience || '').trim();
    return Boolean(String(source.education || '').trim()) &&
      ['No previous work experience', 'Has work experience'].includes(experience) &&
      source.skillsStage === 'Has skills or training to list' &&
      Boolean(String(source.skills || '').trim()) &&
      essentialSkills.length > 0;
  });
  // Retrofit older saved NSRP/resume profiles that predate the Gemini
  // occupation categories. This is the same fact-grounded intake mapper,
  // not new per-job AI extraction, and never adds imagined qualifications.
  const formTitles = [
    ...evidenceExperience,
    ...sources.map(x => String(x.occupation || x.previousWork || '').slice(0, 150)),
    // Never promote an AI-only mirrored title without independent source proof.
    (canonicalMatchingFact(profile.professionalTitle) !== canonicalMatchingFact(ai.professionalTitle) ||
      fields.some(x => canonicalMatchingFact(x.value) === canonicalMatchingFact(profile.professionalTitle)))
      ? String(profile.professionalTitle || '').trim() : '',
  ].filter(Boolean);
  const preparedFields = deriveCategoriesFromVerifiedFacts(
    [...skills, ...certs, ...education, ...formTitles], '',
  );
  const savedFields = Array.isArray(trusted.occupationCategories)
    ? trusted.occupationCategories.filter(category =>
      category && typeof category.field === 'string' &&
      typeof category.iscoMajorGroup === 'string')
    : [];
  const seenField = new Set();
  const occupationCategories = [...savedFields, ...preparedFields]
    .filter(category => {
      if (seenField.has(category.field)) return false;
      seenField.add(category.field);
      return true;
    })
    .slice(0, 5)
    .map(item => ({ field: item.field, iscoMajorGroup: item.iscoMajorGroup }));
  const result = {
    id: 'current-applicant',
    skills: [...new Set(skills)].slice(0, 45),
    educationLevel: explicitEducation || education[0] || '',
    yearsExperience: experienceYears,
    certifications: [...new Set(certs)].slice(0, 25),
    licenses, professionalTitle: String(profile.professionalTitle || '').slice(0, 150),
    resumeText: fields.filter(x => /skill|experience|training/i.test(x.label))
      .map(x => x.value).join('; ').slice(0, 1800),
    incomplete: skills.length === 0 || (!explicitEducation && education.length === 0) ||
      (Boolean(profile.aiProfile) && verification?.status !== 'verified' && !independentlyComplete),
    isSynthetic: false,
    // Saved, intake-time occupational categories are distinct from training or
    // application MRQ data; do not call Gemini when evaluating a new job.
    occupationCategories,
  };
  return result;
}
export function evidenceForGemini(profile = {}) {
  const fields = extractEvidence(profile);
  return fields.map(x => `${x.label}: ${x.value}`).join('\n').slice(0, 8500);
}
export function verifyGeminiFacts(extracted, sourceText) {
  if (!extracted || typeof extracted !== 'object' || Array.isArray(extracted)) {
    return { status: 'needs_review', skills: [], education: [], certifications: [], yearsExperience: 0, rejectedCount: 0 };
  }
  const normalized = canonicalMatchingFact(sourceText);
  let rejectedCount = 0;
  const supported = (values, limit) => stringList(values, limit).filter(value => {
    const term = canonicalMatchingFact(value);
    if (term.length >= 3 && (' ' + normalized + ' ').includes(' ' + term + ' ')) {
      // A bare denial is not evidence of a qualification.
      const index = (' ' + normalized + ' ').indexOf(' ' + term + ' ');
      const preceding = normalized.slice(Math.max(0, index - 75), index);
      if (!/(?:no|not|without|lacks|never|untrained in|unqualified for)\s+$/.test(preceding)) return true;
    }
    rejectedCount++;
    return false;
  });
  const skills = supported(extracted.skills, 15);
  const education = supported(extracted.education, 6);
  const certifications = supported(extracted.certifications, 8);
  // Gemini may categorize skills at intake only; its category requires an
  // exact supporting source quote and a matching occupational field hint.
  // Independently verified extracted skills provide safe fallback categories.
  const proposed = verifyOccupationCategories(extracted.occupationCategories, sourceText);
  const verifiedTitle = String(extracted.professionalTitle || '').trim();
  const title = verifiedTitle && canonicalMatchingFact(sourceText)
    .includes(canonicalMatchingFact(verifiedTitle)) ? verifiedTitle : '';
  const derived = deriveCategoriesFromVerifiedFacts(skills, title);
  const seen = new Set();
  const occupationCategories = [...proposed, ...derived].filter(category => {
    if (seen.has(category.field)) return false;
    seen.add(category.field);
    return true;
  }).slice(0, 5);
  // Numeric years extracted by Gemini cannot be substantiated from the source
  // without contextual date arithmetic; do not promote it to an established fact.
  return {
    status: rejectedCount || (Number(extracted.yearsExperience) > 0) ? 'needs_review' : 'verified',
    skills, education, certifications, yearsExperience: 0, rejectedCount,
    occupationCategories,
  };
}
export function isRealVisibleJob(job, now = new Date()) {
  if (!job || job.isSynthetic === true || job.status !== 'active' ||
      String(job.aiListingKind || '').toLowerCase() === 'notice') return false;
  return isJobPostingVisible(job, now);
}
function safeJob(job) {
  return {
    id: String(job._id ?? job.id ?? ''), title: String(job.title || '').slice(0, 160),
    company: String(job.company || '').slice(0, 160),
    description: String(job.description || '').slice(0, 4000),
    requirements: stringList(job.requirements, 60, 600),
    category: String(job.category || ''),
    sourceUrl: String(job.sourceUrl || ''),
    sourcePageStart: Number(job.sourcePageStart || 0),
    aiListingKind: String(job.aiListingKind || ''),
    requirementScope: String(job.requirementScope || ''),
    sourceRoleCount: Number(job.sourceRoleCount || 0),
    unattributedRequirements: stringList(job.unattributedRequirements, 60, 600),
    // Categorize each newly ingested job locally, without any per-evaluation
    // Gemini call or invented mandatory qualifications.
    occupationCategories: classifyJobOccupation(job.title),
    isSynthetic: false,
  };
}
export async function runGoModel(applicant, jobs, { executable, model, execImpl = executeGoInference } = {}) {
  // Windows developers keep using the existing .exe. Linux/serverless uses the
  // bundled Go executable and its corresponding model, never a missing sibling.
  const packaged = process.platform === 'linux' && !executable &&
    !process.env.PESO_GO_AI_BIN ? preparePackagedGoRuntime() : null;
  const binaryPath = executable || process.env.PESO_GO_AI_BIN ||
    packaged?.executable || defaultBinary;
  const modelPath = model || process.env.PESO_GO_AI_MODEL ||
    packaged?.model || defaultModel;
  const input = JSON.stringify({ applicant, jobs: jobs.map(safeJob) });
  // Pass JSON via stdin, never as a command argument or shell interpolation.
  const { stdout } = await execImpl(binaryPath, ['predict', '-model', modelPath], {
    input, timeout: 8500, maxBuffer: 2 * 1024 * 1024,
    windowsHide: true, shell: false,
  });
  const output = JSON.parse(stdout);
  if (!output?.ok || !Array.isArray(output.results)) throw new Error('invalid_go_model_response');
  return output;
}
export async function evaluateProfileAgainstJobs({ profile, jobs, runner = runGoModel }) {
  const applicant = normalizeApplicantProfile(profile);
  const available = jobs.filter(job => isRealVisibleJob(job) && job.aiListingKind !== 'notice');
  if (available.length === 0) return { ok: true, status: 'no_live_jobs', results: [], applicant };
  try {
    const response = await runner(applicant, available);
    const indexed = new Map(available.map(job => [String(job._id ?? job.id), job]));
    const results = response.results.filter(row => indexed.has(String(row.jobId))).map(row => ({
      ...row, title: String(indexed.get(String(row.jobId)).title || ''),
      company: String(indexed.get(String(row.jobId)).company || ''),
      category: String(indexed.get(String(row.jobId)).category || ''),
      sourceTitle: String(indexed.get(String(row.jobId)).sourceTitle || ''),
    }));
    return { ok: true, status: 'ready', modelVersion: response.modelVersion,
      applicant: { skills: applicant.skills, educationLevel: applicant.educationLevel,
        yearsExperience: applicant.yearsExperience, profileIncomplete: applicant.incomplete },
      results, disclaimer: response.disclaimer };
  } catch (error) {
    return { ok: true, status: 'unavailable', modelVersion: null, results: [],
      applicant: { skills: applicant.skills, educationLevel: applicant.educationLevel,
        yearsExperience: applicant.yearsExperience, profileIncomplete: applicant.incomplete },
      message: 'The trained matching service is temporarily unavailable; registration and applications remain available.',
      diagnostic: String(error?.code || 'model_unavailable').slice(0, 48) };
  }
}
