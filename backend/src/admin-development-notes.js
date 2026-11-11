import { randomUUID } from 'node:crypto';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { ObjectId } from 'mongodb';

const COLLECTION = 'adminDevelopmentNotes';
const NOTE_KINDS = new Set(['bug', 'improvement', 'task']);
const NOTE_STATUSES = new Set([
  'open', 'in_progress', 'blocked', 'fixed', 'implemented',
]);
const NOTE_PRIORITIES = new Set(['low', 'medium', 'high', 'critical']);
const MAX_TITLE_LENGTH = 140;
const MAX_DESCRIPTION_LENGTH = 10000;
const MAX_CHECKLIST_ITEMS = 100;
const MAX_COMMENTS = 100;
const MAX_ACTIVITY = 50;
const MAX_ATTACHMENTS = 10;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const IMAGE_TYPES = new Set([
  'image/jpeg', 'image/png', 'image/webp', 'image/gif',
]);

function httpError(status, code, message) {
  return Object.assign(new Error(message), { status, code, expose: true });
}

function cleanText(value, maximum, fallback = '') {
  return String(value ?? fallback).trim().slice(0, maximum);
}

function normalizeTags(value) {
  const values = Array.isArray(value)
    ? value
    : String(value ?? '').split(',');
  return [...new Set(values
    .map((tag) => cleanText(tag, 32))
    .filter(Boolean))]
    .slice(0, 12);
}

function actorFor(req) {
  const user = req.user || {};
  const email = cleanText(user.email, 254);
  const name = cleanText(user.name, 100) ||
    (email.includes('@') ? email.split('@')[0] : 'PESO Administrator');
  return {
    uid: cleanText(user.uid, 128),
    name,
    email,
  };
}

function activityEvent(req, action, message, details = {}) {
  return {
    id: randomUUID(),
    action,
    message: cleanText(message, 240),
    actor: actorFor(req),
    details,
    at: new Date(),
  };
}

function clientNote(note) {
  if (!note) return null;
  const { _id, ...safe } = note;
  return { ...safe, id: String(_id) };
}

function normalizeChecklist(input, actor) {
  if (!Array.isArray(input)) return [];
  return input.slice(0, MAX_CHECKLIST_ITEMS).map((entry) => {
    const text = cleanText(
      typeof entry === 'string' ? entry : entry?.text,
      300,
    );
    if (!text) return null;
    return {
      id: randomUUID(),
      text,
      completed: false,
      createdAt: new Date(),
      createdBy: actor,
      completedAt: null,
      completedBy: null,
    };
  }).filter(Boolean);
}

function deriveChecklistStatus(kind, checklist, currentStatus) {
  const items = Array.isArray(checklist) ? checklist : [];
  if (items.length > 0 && items.every((item) => item.completed === true)) {
    return kind === 'bug' ? 'fixed' : 'implemented';
  }
  if (currentStatus === 'fixed' || currentStatus === 'implemented') {
    return items.some((item) => item.completed === true) ? 'in_progress' : 'open';
  }
  if (items.some((item) => item.completed === true) && currentStatus === 'open') {
    return 'in_progress';
  }
  return currentStatus || 'open';
}

function validObjectId(value) {
  return typeof value === 'string' && ObjectId.isValid(value);
}

function safeImageName(value) {
  const leaf = String(value || 'screenshot').split(/[\\/]/).at(-1) || 'screenshot';
  const safe = leaf.replace(/[^A-Za-z0-9._ -]/g, '_').slice(0, 120);
  return safe || 'screenshot';
}

function decodeImage(body) {
  const raw = String(body?.base64 || '');
  const comma = raw.indexOf(',');
  const encoded = raw.startsWith('data:') && comma >= 0
    ? raw.slice(comma + 1)
    : raw;
  if (!encoded || encoded.length > Math.ceil(MAX_IMAGE_BYTES * 4 / 3) + 8 ||
      !/^[A-Za-z0-9+/]*={0,2}$/.test(encoded) || encoded.length % 4 === 1) {
    throw httpError(400, 'invalid_image_data', 'Choose a valid image file.');
  }
  const bytes = Buffer.from(encoded, 'base64');
  if (!bytes.length || bytes.length > MAX_IMAGE_BYTES) {
    throw httpError(413, 'image_too_large', 'Each screenshot must be 5 MB or smaller.');
  }
  return bytes;
}

function hasValidImageSignature(bytes, mimeType) {
  if (mimeType === 'image/jpeg') {
    return bytes.length >= 3 && bytes[0] === 0xff &&
      bytes[1] === 0xd8 && bytes[2] === 0xff;
  }
  if (mimeType === 'image/png') {
    return bytes.length >= 8 &&
      bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  }
  if (mimeType === 'image/webp') {
    return bytes.length >= 12 &&
      bytes.toString('ascii', 0, 4) === 'RIFF' &&
      bytes.toString('ascii', 8, 12) === 'WEBP';
  }
  if (mimeType === 'image/gif') {
    const signature = bytes.toString('ascii', 0, 6);
    return signature === 'GIF87a' || signature === 'GIF89a';
  }
  return false;
}

function noteCollection(state) {
  return state.db.collection(COLLECTION);
}

async function findActiveNote(state, id) {
  if (!validObjectId(id)) return null;
  const note = await noteCollection(state).findOne({ _id: new ObjectId(id) });
  if (!note || note.archived === true) return null;
  return note;
}

async function updateWithRevision({
  state, note, changes, req, action, message, details = {},
}) {
  const expectedRevision = Number(changes.expectedRevision);
  if (!Number.isInteger(expectedRevision) || expectedRevision < 1) {
    throw httpError(400, 'revision_required', 'Refresh the note and retry your change.');
  }
  if (expectedRevision !== Number(note.revision || 1)) {
    throw httpError(409, 'note_revision_conflict',
      'This note changed in another session. Refresh it before editing again.');
  }
  const { expectedRevision: _ignored, ...setChanges } = changes;
  const now = new Date();
  const result = await noteCollection(state).updateOne(
    {
      _id: note._id,
      revision: expectedRevision,
      archived: note.archived === true ? true : { $ne: true },
    },
    {
      $set: { ...setChanges, updatedAt: now, updatedBy: actorFor(req) },
      $inc: { revision: 1 },
      $push: {
        activity: {
          $each: [activityEvent(req, action, message, details)],
          $slice: -MAX_ACTIVITY,
        },
      },
    },
  );
  if (result.matchedCount !== 1) {
    throw httpError(409, 'note_revision_conflict',
      'This note changed in another session. Refresh it before editing again.');
  }
  return noteCollection(state).findOne({ _id: note._id });
}

export function installAdminDevelopmentNotesRoutes({
  app, requireAuth, requireAdmin, requireMongo, state,
}) {
  const guard = [requireAuth, requireAdmin, requireMongo];

  app.get('/api/admin/development-notes', ...guard, async (req, res, next) => {
    try {
      const query = cleanText(req.query.q, 120);
      const kind = cleanText(req.query.kind, 24);
      const status = cleanText(req.query.status, 24);
      const archived = req.query.archived === '1';
      const limit = Math.max(1, Math.min(200, Number.parseInt(req.query.limit, 10) || 200));
      const filter = { archived: archived ? true : { $ne: true } };
      if (NOTE_KINDS.has(kind)) filter.kind = kind;
      if (NOTE_STATUSES.has(status)) filter.status = status;
      if (query) {
        const escaped = query.replace(/[.*+?^$()|[\]\\{}]/g, '\\$&');
        const pattern = new RegExp(escaped, 'i');
        filter.$or = [
          { title: pattern },
          { description: pattern },
          { assignee: pattern },
          { tags: pattern },
        ];
      }
      const notes = await noteCollection(state)
        .find(filter)
        .sort({ updatedAt: -1, createdAt: -1 })
        .limit(limit)
        .toArray();
      return res.json({ ok: true, notes: notes.map(clientNote), count: notes.length });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/api/admin/development-notes', ...guard, async (req, res, next) => {
    try {
      const body = req.body || {};
      const title = cleanText(body.title, MAX_TITLE_LENGTH);
      if (!title) {
        return res.status(400).json({
          ok: false, error: 'note_title_required',
          message: 'Add a short title before saving this item.',
        });
      }
      const kind = NOTE_KINDS.has(body.kind) ? body.kind : 'bug';
      const priority = NOTE_PRIORITIES.has(body.priority) ? body.priority : 'medium';
      const actor = actorFor(req);
      const now = new Date();
      const note = {
        title,
        description: cleanText(body.description, MAX_DESCRIPTION_LENGTH),
        kind,
        priority,
        status: 'open',
        assignee: cleanText(body.assignee, 120),
        tags: normalizeTags(body.tags),
        checklist: normalizeChecklist(body.checklist, actor),
        attachments: [],
        comments: [],
        activity: [activityEvent(req, 'created', 'Created this development item.')],
        createdBy: actor,
        updatedBy: actor,
        createdAt: now,
        updatedAt: now,
        archived: false,
        revision: 1,
      };
      const result = await noteCollection(state).insertOne(note);
      const saved = await noteCollection(state).findOne({ _id: result.insertedId });
      return res.status(201).json({ ok: true, note: clientNote(saved) });
    } catch (error) {
      return next(error);
    }
  });

  app.patch('/api/admin/development-notes/:id', ...guard, async (req, res, next) => {
    try {
      if (!validObjectId(req.params.id)) {
        return res.status(404).json({ ok: false, error: 'note_not_found' });
      }
      const id = new ObjectId(req.params.id);
      const note = await noteCollection(state).findOne({ _id: id });
      if (!note) return res.status(404).json({ ok: false, error: 'note_not_found' });
      const body = req.body || {};
      if (note.archived === true && body.archived !== false) {
        return res.status(409).json({ ok: false, error: 'note_archived',
          message: 'Restore this note before editing it.' });
      }
      const changes = { expectedRevision: body.expectedRevision };
      if (Object.hasOwn(body, 'title')) {
        changes.title = cleanText(body.title, MAX_TITLE_LENGTH);
        if (!changes.title) {
          return res.status(400).json({ ok: false, error: 'note_title_required' });
        }
      }
      if (Object.hasOwn(body, 'description')) {
        changes.description = cleanText(body.description, MAX_DESCRIPTION_LENGTH);
      }
      if (Object.hasOwn(body, 'kind')) {
        if (!NOTE_KINDS.has(body.kind)) {
          return res.status(400).json({ ok: false, error: 'invalid_note_kind' });
        }
        changes.kind = body.kind;
      }
      if (Object.hasOwn(body, 'priority')) {
        if (!NOTE_PRIORITIES.has(body.priority)) {
          return res.status(400).json({ ok: false, error: 'invalid_note_priority' });
        }
        changes.priority = body.priority;
      }
      if (Object.hasOwn(body, 'status')) {
        if (!NOTE_STATUSES.has(body.status)) {
          return res.status(400).json({ ok: false, error: 'invalid_note_status' });
        }
        changes.status = body.status;
      }
      if (Object.hasOwn(body, 'assignee')) {
        changes.assignee = cleanText(body.assignee, 120);
      }
      if (Object.hasOwn(body, 'tags')) changes.tags = normalizeTags(body.tags);
      if (Object.hasOwn(body, 'archived')) {
        if (typeof body.archived !== 'boolean') {
          return res.status(400).json({ ok: false, error: 'invalid_archive_value' });
        }
        changes.archived = body.archived;
      }
      if (Object.keys(changes).length === 1) {
        return res.status(400).json({ ok: false, error: 'empty_note_update' });
      }
      const kind = changes.kind || note.kind;
      if (changes.status === undefined && changes.kind !== undefined) {
        changes.status = deriveChecklistStatus(kind, note.checklist, note.status);
      }
      const action = changes.archived === true
        ? 'archived'
        : changes.archived === false
          ? 'restored'
          : 'updated';
      const updated = await updateWithRevision({
        state, note, changes, req, action,
        message: action === 'archived' ? 'Archived this item.'
          : action === 'restored' ? 'Restored this item.'
            : 'Updated the development item.',
        details: { fields: Object.keys(changes).filter((key) => key !== 'expectedRevision') },
      });
      return res.json({ ok: true, note: clientNote(updated) });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/api/admin/development-notes/:id/checklist', ...guard, async (req, res, next) => {
    try {
      const note = await findActiveNote(state, req.params.id);
      if (!note) return res.status(404).json({ ok: false, error: 'note_not_found' });
      const text = cleanText(req.body?.text, 300);
      if (!text) return res.status(400).json({ ok: false, error: 'checklist_text_required' });
      if ((note.checklist || []).length >= MAX_CHECKLIST_ITEMS) {
        return res.status(413).json({ ok: false, error: 'checklist_limit_reached' });
      }
      const checklist = [...(note.checklist || []), {
        id: randomUUID(),
        text,
        completed: false,
        createdAt: new Date(),
        createdBy: actorFor(req),
        completedAt: null,
        completedBy: null,
      }];
      const status = deriveChecklistStatus(note.kind, checklist, note.status);
      const updated = await updateWithRevision({
        state, note,
        changes: { expectedRevision: req.body?.expectedRevision, checklist, status },
        req, action: 'checklist_item_added',
        message: 'Added a checklist item.',
        details: { itemText: text },
      });
      return res.status(201).json({ ok: true, note: clientNote(updated) });
    } catch (error) {
      return next(error);
    }
  });

  app.patch('/api/admin/development-notes/:id/checklist/:itemId', ...guard, async (req, res, next) => {
    try {
      const note = await findActiveNote(state, req.params.id);
      if (!note) return res.status(404).json({ ok: false, error: 'note_not_found' });
      if (typeof req.body?.completed !== 'boolean') {
        return res.status(400).json({ ok: false, error: 'invalid_checklist_state' });
      }
      const checklist = [...(note.checklist || [])];
      const index = checklist.findIndex((item) => item.id === req.params.itemId);
      if (index < 0) return res.status(404).json({ ok: false, error: 'checklist_item_not_found' });
      const item = { ...checklist[index], completed: req.body.completed };
      item.completedAt = req.body.completed ? new Date() : null;
      item.completedBy = req.body.completed ? actorFor(req) : null;
      checklist[index] = item;
      const status = deriveChecklistStatus(note.kind, checklist, note.status);
      const updated = await updateWithRevision({
        state, note,
        changes: { expectedRevision: req.body?.expectedRevision, checklist, status },
        req,
        action: req.body.completed ? 'checklist_item_completed' : 'checklist_item_reopened',
        message: req.body.completed ? 'Completed a checklist item.' : 'Reopened a checklist item.',
        details: { itemId: req.params.itemId, itemText: item.text },
      });
      return res.json({ ok: true, note: clientNote(updated) });
    } catch (error) {
      return next(error);
    }
  });

  app.delete('/api/admin/development-notes/:id/checklist/:itemId', ...guard, async (req, res, next) => {
    try {
      const note = await findActiveNote(state, req.params.id);
      if (!note) return res.status(404).json({ ok: false, error: 'note_not_found' });
      const checklist = (note.checklist || []).filter((item) => item.id !== req.params.itemId);
      if (checklist.length === (note.checklist || []).length) {
        return res.status(404).json({ ok: false, error: 'checklist_item_not_found' });
      }
      const status = deriveChecklistStatus(note.kind, checklist, note.status);
      const updated = await updateWithRevision({
        state, note,
        changes: { expectedRevision: req.body?.expectedRevision, checklist, status },
        req, action: 'checklist_item_removed',
        message: 'Removed a checklist item.',
        details: { itemId: req.params.itemId },
      });
      return res.json({ ok: true, note: clientNote(updated) });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/api/admin/development-notes/:id/comments', ...guard, async (req, res, next) => {
    try {
      const note = await findActiveNote(state, req.params.id);
      if (!note) return res.status(404).json({ ok: false, error: 'note_not_found' });
      const message = cleanText(req.body?.message, 3000);
      if (!message) return res.status(400).json({ ok: false, error: 'comment_required' });
      const comment = {
        id: randomUUID(),
        message,
        actor: actorFor(req),
        at: new Date(),
      };
      const now = new Date();
      const result = await noteCollection(state).updateOne(
        { _id: note._id, archived: { $ne: true } },
        {
          $set: { updatedAt: now, updatedBy: actorFor(req) },
          $inc: { revision: 1 },
          $push: {
            comments: { $each: [comment], $slice: -MAX_COMMENTS },
            activity: {
              $each: [activityEvent(req, 'commented', 'Added a comment.')],
              $slice: -MAX_ACTIVITY,
            },
          },
        },
      );
      if (result.matchedCount !== 1) {
        return res.status(409).json({ ok: false, error: 'note_changed',
          message: 'Refresh the note and retry your comment.' });
      }
      const updated = await noteCollection(state).findOne({ _id: note._id });
      return res.status(201).json({ ok: true, note: clientNote(updated) });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/api/admin/development-notes/:id/attachments', ...guard, async (req, res, next) => {
    let uploadedId = null;
    try {
      const note = await findActiveNote(state, req.params.id);
      if (!note) return res.status(404).json({ ok: false, error: 'note_not_found' });
      const expectedRevision = Number(req.body?.expectedRevision);
      if (!Number.isInteger(expectedRevision) || expectedRevision < 1) {
        throw httpError(400, 'revision_required', 'Refresh the note and retry the screenshot upload.');
      }
      if (expectedRevision !== Number(note.revision || 1)) {
        throw httpError(409, 'note_revision_conflict',
          'This note changed in another session. Refresh it before uploading screenshots.');
      }
      if ((note.attachments || []).length >= MAX_ATTACHMENTS) {
        return res.status(413).json({ ok: false, error: 'attachment_limit_reached',
          message: 'A development item can have up to 10 screenshots.' });
      }
      const mimeType = cleanText(req.body?.mimeType, 80).toLowerCase();
      if (!IMAGE_TYPES.has(mimeType)) {
        return res.status(415).json({ ok: false, error: 'unsupported_image_type',
          message: 'Attach a PNG, JPEG, WEBP or GIF image.' });
      }
      const bytes = decodeImage(req.body);
      if (!hasValidImageSignature(bytes, mimeType)) {
        return res.status(415).json({ ok: false, error: 'invalid_image_signature',
          message: 'The selected file does not match its image type.' });
      }
      const fileName = safeImageName(req.body?.fileName);
      const upload = state.bucket.openUploadStream(fileName, {
        contentType: mimeType,
        metadata: {
          category: 'admin_dev_note_attachment',
          noteId: String(note._id),
          uploadedByUid: req.user.uid,
          mimeType,
          originalFileName: fileName,
        },
      });
      uploadedId = upload.id;
      await pipeline(Readable.from([bytes]), upload);
      const attachment = {
        id: String(uploadedId),
        fileName,
        mimeType,
        sizeBytes: bytes.length,
        uploadedAt: new Date(),
        uploadedBy: actorFor(req),
      };
      const now = new Date();
      const result = await noteCollection(state).updateOne(
        { _id: note._id, revision: expectedRevision, archived: { $ne: true } },
        {
          $set: { updatedAt: now, updatedBy: actorFor(req) },
          $inc: { revision: 1 },
          $push: {
            attachments: attachment,
            activity: {
              $each: [activityEvent(req, 'attachment_added', 'Attached a screenshot.',
                { fileName })],
              $slice: -MAX_ACTIVITY,
            },
          },
        },
      );
      if (result.matchedCount !== 1) {
        throw httpError(409, 'note_revision_conflict', 'The item changed while the screenshot was uploading. Refresh it and retry.');
      }
      const updated = await noteCollection(state).findOne({ _id: note._id });
      return res.status(201).json({ ok: true, note: clientNote(updated) });
    } catch (error) {
      if (uploadedId && state.bucket) {
        try { await state.bucket.delete(uploadedId); } catch { /* preserve the original error */ }
      }
      return next(error);
    }
  });

  app.get('/api/admin/development-notes/:id/attachments/:attachmentId/content',
    ...guard, async (req, res, next) => {
      try {
        if (!validObjectId(req.params.id) || !validObjectId(req.params.attachmentId)) {
          return res.status(404).json({ ok: false, error: 'attachment_not_found' });
        }
        const note = await noteCollection(state).findOne({
          _id: new ObjectId(req.params.id),
          'attachments.id': req.params.attachmentId,
        });
        const attachment = note?.attachments?.find((item) => item.id === req.params.attachmentId);
        if (!attachment) return res.status(404).json({ ok: false, error: 'attachment_not_found' });
        res.setHeader('Content-Type', attachment.mimeType);
        res.setHeader('Content-Disposition',
          'inline; filename="' + safeImageName(attachment.fileName) + '"');
        res.setHeader('Cache-Control', 'private, no-store, max-age=0');
        res.setHeader('X-Content-Type-Options', 'nosniff');
        res.setHeader('Content-Length', String(attachment.sizeBytes));
        const download = state.bucket.openDownloadStream(new ObjectId(req.params.attachmentId));
        download.on('error', () => {
          if (!res.headersSent) res.status(404).end();
          else res.destroy();
        });
        return download.pipe(res);
      } catch (error) {
        return next(error);
      }
    });

  app.delete('/api/admin/development-notes/:id/attachments/:attachmentId',
    ...guard, async (req, res, next) => {
      try {
        if (!validObjectId(req.params.id) || !validObjectId(req.params.attachmentId)) {
          return res.status(404).json({ ok: false, error: 'attachment_not_found' });
        }
        const note = await noteCollection(state).findOne({
          _id: new ObjectId(req.params.id),
          'attachments.id': req.params.attachmentId,
        });
        if (!note) return res.status(404).json({ ok: false, error: 'attachment_not_found' });
        const attachments = (note.attachments || []).filter(
          (item) => item.id !== req.params.attachmentId,
        );
        const updated = await updateWithRevision({
          state, note,
          changes: { expectedRevision: req.body?.expectedRevision, attachments },
          req, action: 'attachment_removed',
          message: 'Removed a screenshot.',
          details: { attachmentId: req.params.attachmentId },
        });
        let cleanupPending = false;
        try {
          await state.bucket.delete(new ObjectId(req.params.attachmentId));
        } catch {
          cleanupPending = true;
        }
        return res.json({ ok: true, note: clientNote(updated), cleanupPending });
      } catch (error) {
        return next(error);
      }
    });
}

export {
  deriveChecklistStatus,
  hasValidImageSignature,
  normalizeChecklist,
  normalizeTags,
};
