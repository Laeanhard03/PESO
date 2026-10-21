/** Read-only audit: do not change MongoDB records or use applicant data. */
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import { MongoClient } from 'mongodb';
import { linkedRolesForNotice } from '../src/notice-role-linkage.js';
import { evaluateProfileAgainstJobs } from '../src/mini-ai-service.js';
import { isJobPostingVisible } from '../src/job_postings.js';
const here = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(here, '..', '.env'), quiet: true });
const uri = String(process.env.MONGODB_URI || '').trim();
if (!uri || uri.includes('YOUR_CLUSTER_HOST')) throw new Error('mongodb_not_configured');
const client = new MongoClient(uri, { serverSelectionTimeoutMS: 8000, maxPoolSize: 2 });
try {
  await client.connect();
  const db = client.db(process.env.MONGODB_DB_NAME || 'peso_jobkonek');
  const fields = { _id: 1, aiListingKind: 1, status: 1, isPublicPdfListing: 1,
    isSynthetic: 1, title: 1, company: 1, sourceFingerprint: 1,
    parentFingerprint: 1, publicPdfSourceId: 1, sourceUrl: 1, sourcePageStart: 1,
    sourcePageEnd: 1, sourceRoleCount: 1, requirementScope: 1, requirements: 1,
    unattributedRequirements: 1, createdAt: 1, expiresAt: 1, category: 1 };
  const now = new Date();
  const rows = (await db.collection('jobPostings').find({ status: 'active' },
    { projection: fields }).sort({ createdAt: -1 }).limit(1000).toArray())
    .filter(job => isJobPostingVisible(job, now));
  const notices = rows.filter(x => x.aiListingKind === 'notice');
  const roles = rows.filter(x => x.aiListingKind === 'role');
  const items = notices.map(notice => ({
    notice,
    associated: linkedRolesForNotice(notice, roles, now),
  }));
  const jcrcc = items.filter(x => /JCRCC|RODRIGUEZ CONSTRUCTION/i.test(
    String(x.notice.title || '') + ' ' + String(x.notice.company || '')))
    .map(x => ({ notice: String(x.notice.title || ''), sourcePage: x.notice.sourcePageStart,
      claimedRoleCount: x.notice.sourceRoleCount,
      linkedPositions: x.associated.map(y => ({ title: String(y.title || ''),
        requirementScope: y.requirementScope || 'unknown',
        reviewRequired: !['explicit_role', 'single_role'].includes(y.requirementScope) ||
          (y.unattributedRequirements || []).length > 0 })) }));
  // Read-only real-role inference with a fictional QA applicant. No user records,
  // labels or job postings are accessed or written beyond this projected read.
  const sourceLinkedJcrcc = items.find(x => /JCRCC|RODRIGUEZ CONSTRUCTION/i.test(
    String(x.notice.title || '') + ' ' + String(x.notice.company || '')));
  let jcrccInference = { status: 'no_jcrcc_notice' };
  if (sourceLinkedJcrcc?.associated.length) {
    const result = await evaluateProfileAgainstJobs({
      profile: { skills: ['Welding', 'Construction'], educationLevel: 'Senior High School',
        yearsExperience: 0 },
      jobs: sourceLinkedJcrcc.associated,
    });
    const expected = new Set(sourceLinkedJcrcc.associated.map(x => String(x._id)));
    const returned = result.results || [];
    jcrccInference = {
      status: result.status,
      modelVersion: result.modelVersion || null,
      requestedRoles: expected.size,
      returnedDistinctRoleResults: new Set(returned.map(x => String(x.jobId))).size,
      allResultsCorrespondToSelectedRoles: returned.every(x => expected.has(String(x.jobId))),
      lowConfidence: returned.filter(x => x.confidence === 'low').length,
      requiringHumanReview: returned.filter(x => (x.needsReview || []).length > 0).length,
      aggregateNoticeScored: returned.some(x => String(x.jobId) === String(sourceLinkedJcrcc.notice._id)),
    };
  }
  const summary = {
    inspectedAt: now.toISOString(), activeVisibleRecords: rows.length,
    notices: notices.length, roles: roles.length,
    linkedNotices: items.filter(x => x.associated.length > 0).length,
    noticesWithoutVerifiedLinks: items.filter(x => !x.associated.length).length,
    linkedRoleAssignments: items.reduce((n,x)=>n+x.associated.length, 0),
    rolesWithUnattributedRequirements: roles.filter(x =>
      (x.unattributedRequirements || []).length > 0).length,
    rolesWithoutAttributedRequirementScope: roles.filter(x =>
      !['explicit_role', 'single_role'].includes(x.requirementScope)).length,
    jcrcc, jcrccInference,
  };
  console.log(JSON.stringify(summary, null, 2));
} finally { await client.close(); }
