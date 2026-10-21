// Admin-only document lookup. Uses the same GridFS files as the AI Profile.
import { ObjectId } from 'mongodb';
// Never identify private documents by a matching name or email address.
const CATEGORIES = Object.freeze({
  resume: ['resume_upload', 'resume_builder', 'resume_pdf', 'resume', 'legacy_resume'],
  nsrp: ['nsrp_form', 'nsrp_pdf', 'nsrp', 'peso_form', 'employment_form', 'legacy_nsrp_form'],
});
const MAX_BATCH = 100;

function savedEntries(value) {
  return value && typeof value === 'object' &&
    !Array.isArray(value) && Object.keys(value).some((key) =>
      !['pendingDraft', 'draftOnly', 'draftUpdatedAt'].includes(key));
}

export function installAdminApplicantDocumentRoutes({
  app, requireAuth, requireAdmin, requireMongo, state, usersCollection,
  artifactFromGridFs, isAllowedMimeType, safeFileName,
}) {
  const files = () => state.db.collection('profileArtifacts.files');

  async function statuses(uids) {
    const profiles = await usersCollection().find({ uid: { $in: uids } }).toArray();
    const byUid = new Map(profiles.map((item) => [String(item.uid), item]));
    const artifacts = await files().find({
      'metadata.ownerUid': { $in: uids },
      'metadata.category': { $in: [...CATEGORIES.resume, ...CATEGORIES.nsrp] },
    }).sort({ uploadDate: -1 }).toArray();
    const latest = new Map();
    for (const file of artifacts) {
      const uid = String(file.metadata?.ownerUid || '');
      const category = String(file.metadata?.category || '');
      if (!uids.includes(uid)) continue;
      const kind = CATEGORIES.resume.includes(category) ? 'resume'
        : CATEGORIES.nsrp.includes(category) ? 'nsrp' : null;
      if (kind && !latest.has(uid + ':' + kind)) latest.set(uid + ':' + kind, file);
    }
    const records = Object.create(null);
    for (const uid of uids) {
      const profile = byUid.get(uid);
      const record = Object.create(null);
      for (const kind of ['resume', 'nsrp']) {
        const file = latest.get(uid + ':' + kind);
        const hasStructured = kind === 'resume'
          ? savedEntries(profile?.resumeData) ||
            Boolean(String(profile?.resumeFileName || '').trim())
          : savedEntries(profile?.pesoFormData);
        record[kind] = file
          ? { status: 'available', artifact: artifactFromGridFs(file) }
          : { status: hasStructured ? 'saved_data_only' : 'not_submitted' };
      }
      records[uid] = record;
    }
    return records;
  }

  // Batch status prevents one request per table row and checks actual GridFS
  // records, not unrelated AI completion or matching flags.
  app.post('/api/admin/users/document-status',
    requireAuth, requireAdmin, requireMongo, async (req, res, next) => {
      try {
        const raw = req.body?.uids;
        if (!Array.isArray(raw) || raw.length < 1 || raw.length > MAX_BATCH ||
            raw.some((uid) => typeof uid !== 'string' || !uid.trim() || uid.length > 128)) {
          return res.status(400).json({ ok: false, error: 'invalid_document_uids' });
        }
        const uids = [...new Set(raw)];
        return res.json({ ok: true, records: await statuses(uids) });
      } catch (error) { return next(error); }
    });

  // Canonical metadata contract also used by residency onboarding and the
  // admin UI. Keep it on this shared route rather than registering duplicates.
  app.get('/api/admin/users/:uid/documents',
    requireAuth, requireAdmin, requireMongo, async (req, res, next) => {
      try {
        const uid = String(req.params.uid || '').trim();
        if (!uid || uid.length > 128) {
          return res.status(400).json({ ok: false, error: 'invalid_uid' });
        }
        const profile = await usersCollection().findOne({ uid });
        const allFiles = await state.bucket.find({ 'metadata.ownerUid': uid })
          .sort({ uploadDate: -1 }).toArray();
        if (!profile && !allFiles.length) {
          return res.status(404).json({ ok: false, error: 'user_not_found' });
        }
        const records = await statuses([uid]);
        const types = allFiles.map((file) =>
          String(file.metadata?.category || '').toLowerCase());
        return res.json({
          ok: true, uid,
          resumeSubmitted: Boolean(profile?.resumeSubmitted ||
            savedEntries(profile?.resumeData) || profile?.resumeFileName ||
            profile?.documentSummary?.resumeSubmitted ||
            types.some((c) => c.includes('resume'))),
          formSubmitted: Boolean(profile?.formSubmitted ||
            savedEntries(profile?.pesoFormData) ||
            profile?.documentSummary?.formSubmitted ||
            types.some((c) => c.includes('nsrp') || c.includes('peso_form') ||
              c.includes('employment_form'))),
          resumeCount: types.filter((c) => c.includes('resume')).length,
          nsrpCount: types.filter((c) => c.includes('nsrp') ||
            c.includes('peso_form') || c.includes('employment_form')).length,
          artifacts: allFiles.map(artifactFromGridFs),
          documents: records[uid],
        });
      } catch (error) { return next(error); }
    });

  app.get('/api/admin/users/:uid/documents/:kind/content',
    requireAuth, requireAdmin, requireMongo, async (req, res, next) => {
      try {
        const uid = String(req.params.uid || '');
        const kind = String(req.params.kind || '');
        if (!uid || uid.length > 128 || !Object.hasOwn(CATEGORIES, kind)) {
          return res.status(404).json({ ok: false, error: 'document_not_found' });
        }
        // Even when a file ID is supplied, it must belong to this exact UID
        // and document category. Prevents mixed-up rows and arbitrary file reads.
        const artifactId = String(req.query?.artifactId || '').trim();
        if (artifactId && !ObjectId.isValid(artifactId)) {
          return res.status(404).json({ ok: false, error: 'document_not_found' });
        }
        const selector = {
          'metadata.ownerUid': uid,
          'metadata.category': { $in: CATEGORIES[kind] },
          ...(artifactId ? { _id: new ObjectId(artifactId) } : {}),
        };
        const file = await files().findOne(selector, { sort: { uploadDate: -1 } });
        if (!file) return res.status(404).json({
          ok: false, error: 'document_not_found',
          message: 'No saved PDF/file exists for this applicant and document type.',
        });
        const mime = isAllowedMimeType(file.metadata?.mimeType)
          ? file.metadata.mimeType : 'application/octet-stream';
        res.setHeader('Content-Type', mime);
        res.setHeader('Content-Disposition', 'inline; filename="' +
          safeFileName(file.metadata?.originalFileName || file.filename || 'document.pdf') + '"');
        res.setHeader('Cache-Control', 'private, no-store, max-age=0');
        res.setHeader('X-Content-Type-Options', 'nosniff');
        const stream = state.bucket.openDownloadStream(file._id);
        stream.on('error', () => {
          if (!res.headersSent) res.status(404).end();
          else res.destroy();
        });
        stream.pipe(res);
      } catch (error) { return next(error); }
    });
}
