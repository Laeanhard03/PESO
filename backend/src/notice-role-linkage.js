import { isRealVisibleJob } from './mini-ai-service.js';

/**
 * Provenance-only association between a PDF employer notice and its actual role
 * cards. Similar employer names/titles are never sufficient. Never scores notice.
 */
export function linkedRolesForNotice(notice, jobs, now = new Date()) {
  if (!notice || notice.aiListingKind !== 'notice' ||
      notice.isPublicPdfListing !== true || notice.isSynthetic === true ||
      notice.status !== 'active') return [];
  const fingerprint = String(notice.sourceFingerprint || '').trim();
  const sourceId = String(notice.publicPdfSourceId || '').trim();
  const sourceUrl = String(notice.sourceUrl || '').trim();
  const company = String(notice.company || '').replace(/\s+/g, ' ').trim().toLowerCase();
  const start = Number(notice.sourcePageStart);
  const end = Number(notice.sourcePageEnd || notice.sourcePageStart);
  if (!fingerprint || !sourceId || !sourceUrl || !company ||
      !Number.isInteger(start) || start < 1 ||
      !Number.isInteger(end) || end < start) return [];
  const ids = new Set();
  return (Array.isArray(jobs) ? jobs : []).filter((role) => {
    if (!isRealVisibleJob(role, now) ||
        role.aiListingKind !== 'role' || role.isPublicPdfListing !== true ||
        String(role.parentFingerprint || '') !== fingerprint ||
        String(role.publicPdfSourceId || '') !== sourceId ||
        String(role.sourceUrl || '') !== sourceUrl ||
        String(role.company || '').replace(/\s+/g, ' ').trim().toLowerCase() !== company ||
        Number(role.sourcePageStart) !== start ||
        Number(role.sourcePageEnd || role.sourcePageStart) !== end) return false;
    const id = String(role._id ?? role.id ?? '');
    if (!id || ids.has(id)) return false;
    ids.add(id);
    return true;
  });
}
