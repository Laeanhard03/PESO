import { ObjectId } from 'mongodb';

import {
  encryptApiKey,
  maskApiKey,
  publicKeyMetadata,
  validateApiKeyInput,
} from './gemini-key-vault.js';

const SETTINGS_ID = 'singleton';
const MAX_LABEL_LENGTH = 80;
const SAFE_ERROR_CATEGORIES = new Set([
  'encryption_error',
  'invalid_key',
  'transient_upstream_failure',
  'quota_limited',
  'provider_permission_denied',
  'invalid_request',
  'unknown_upstream_failure',
  'test_success',
  'test_failed',
]);

function validRecordId(value) {
  const id = String(value || '');
  return /^[a-f0-9]{24}$/i.test(id) ? new ObjectId(id) : null;
}

function safeActorUid(value) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > 128) {
    throw new Error('Verified administrator identity is required.');
  }
  return value.trim();
}

function validateLabel(value) {
  if (typeof value !== 'string') throw new Error('A key label is required.');
  const label = value.trim();
  if (!label || label.length > MAX_LABEL_LENGTH || /[\u0000-\u001f\u007f]/.test(label)) {
    throw new Error('Key label must be 1 to 80 printable characters.');
  }
  return label;
}

function safeCategory(value) {
  const category = typeof value === 'string' ? value.trim() : '';
  return SAFE_ERROR_CATEGORIES.has(category) ? category : 'unknown_upstream_failure';
}

function resolveSecret(secretSource) {
  const value = typeof secretSource === 'function'
    ? secretSource()
    : (secretSource ?? process.env.GEMINI_KEY_ENCRYPTION_SECRET ?? '');
  return typeof value === 'string' ? value : '';
}

function cursorFrom(settings) {
  const value = Number(settings?.roundRobinCursor);
  return Number.isSafeInteger(value) && value >= 0 ? value : 0;
}

function toPublicOrNull(record) {
  return record ? publicKeyMetadata(record) : null;
}

export function createMongoGeminiKeyStore(db, {
  encryptionSecret,
  now = () => new Date(),
} = {}) {
  if (!db || typeof db.collection !== 'function') {
    throw new TypeError('A connected MongoDB database is required.');
  }
  const keys = db.collection('geminiApiKeys');
  const settings = db.collection('geminiKeySettings');
  const audit = db.collection('geminiKeyAudit');
  // Model-level quotas are project-scoped. Conservatively treat the managed
  // pool as one project unless keys can be securely linked to separate projects.
  const modelQuotas = db.collection('geminiModelQuotas');

  function safeModelName(model) {
    const value = String(model || '').trim();
    return /^gemini-[a-z0-9.-]{1,72}$/i.test(value) ? value : null;
  }

  async function getModelQuotaStatus(model, at = now()) {
    const safeModel = safeModelName(model);
    if (!safeModel) return null;
    const record = await modelQuotas.findOne({ _id: safeModel });
    const until = record?.until instanceof Date ? record.until : null;
    if (!until || until.getTime() <= new Date(at).getTime()) return null;
    return {
      model: safeModel, retryAfterSeconds: Math.max(1,
        Math.ceil((until.getTime() - new Date(at).getTime()) / 1000)),
      quotaUntil: until.toISOString(),
      scope: ['minute','daily'].includes(record.scope) ? record.scope : 'unknown',
      metric: ['RPM','TPM','RPD'].includes(record.metric) ? record.metric : 'unspecified',
      observedAt: record.observedAt instanceof Date ? record.observedAt.toISOString() : null,
    };
  }

  async function markModelQuota({ model, retryAfterSeconds, scope = 'unknown',
    metric = 'unspecified', at = now() } = {}) {
    const safeModel = safeModelName(model);
    if (!safeModel) return null;
    const wait = Math.max(1, Math.min(86_400,
      Math.ceil(Number(retryAfterSeconds) || 60)));
    const stamp = new Date(at);
    const until = new Date(stamp.getTime() + wait * 1000);
    await modelQuotas.updateOne({ _id: safeModel }, { $set: {
      until,
      scope: ['minute','daily'].includes(scope) ? scope : 'unknown',
      metric: ['RPM','TPM','RPD'].includes(metric) ? metric : 'unspecified',
      observedAt: stamp,
    } }, { upsert: true });
    return getModelQuotaStatus(safeModel, stamp);
  }


  async function writeAudit(action, { actorUid, keyId = null, at = now(), result = 'completed' }) {
    try {
      await audit.insertOne({
        action,
        keyId: keyId == null ? null : String(keyId),
        actorUid: safeActorUid(actorUid),
        result: String(result).slice(0, 32),
        at,
      });
    } catch {
      // Audit metadata is best-effort so an audit collection outage does not
      // turn a completed key mutation into an ambiguous client-side failure.
    }
  }

  async function getKeyRecord(id) {
    const objectId = validRecordId(id);
    if (!objectId) return null;
    return keys.findOne({ _id: objectId });
  }

  async function getPoolSettings() {
    const record = await settings.findOne({ _id: SETTINGS_ID });
    return {
      managedPoolActivated: record?.managedPoolActivated === true,
      roundRobinCursor: cursorFrom(record),
      updatedAt: record?.updatedAt || null,
    };
  }

  async function listPublicKeys() {
    const records = await keys.find({}).sort({ createdAt: -1, _id: -1 }).toArray();
    return records.map(publicKeyMetadata);
  }

  async function getPublicKey(id) {
    return toPublicOrNull(await getKeyRecord(id));
  }

  async function createKey({ label, apiKey, actorUid }) {
    const actor = safeActorUid(actorUid);
    const safeLabel = validateLabel(label);
    const key = validateApiKeyInput(apiKey);
    const id = new ObjectId();
    const idString = id.toHexString();
    const stamp = now();
    const encrypted = encryptApiKey({
      apiKey: key,
      encryptionSecret: resolveSecret(encryptionSecret),
      recordId: idString,
    });
    const record = {
      _id: id,
      label: safeLabel,
      ...encrypted,
      enabled: true,
      health: 'ready',
      cooldownUntil: null,
      lastErrorCategory: null,
      lastAttemptAt: null,
      lastUsedAt: null,
      lastSuccessAt: null,
      lastTestedAt: null,
      createdAt: stamp,
      updatedAt: stamp,
      createdBy: actor,
      updatedBy: actor,
    };

    await keys.insertOne(record);
    try {
      await settings.updateOne(
        { _id: SETTINGS_ID },
        {
          $set: { managedPoolActivated: true, updatedAt: stamp },
          $setOnInsert: { createdAt: stamp, roundRobinCursor: 0 },
        },
        { upsert: true },
      );
    } catch {
      await keys.deleteOne({ _id: id });
      throw new Error('Gemini managed key pool could not be activated.');
    }
    await writeAudit('create', { actorUid: actor, keyId: idString, at: stamp });
    return publicKeyMetadata(record);
  }

  async function updateKey(id, changes = {}) {
    const objectId = validRecordId(id);
    if (!objectId) return null;
    const current = await keys.findOne({ _id: objectId });
    if (!current) return null;
    if (!changes || typeof changes !== 'object' || Array.isArray(changes)) {
      throw new Error('Key update must be an object.');
    }
    const actor = safeActorUid(changes.actorUid);
    const set = {
      updatedAt: now(),
      updatedBy: actor,
    };
    if (Object.hasOwn(changes, 'label')) set.label = validateLabel(changes.label);
    if (Object.hasOwn(changes, 'apiKey')) {
      const key = validateApiKeyInput(changes.apiKey);
      Object.assign(set, encryptApiKey({
        apiKey: key,
        encryptionSecret: resolveSecret(encryptionSecret),
        recordId: objectId.toHexString(),
      }));
      set.health = current.enabled === true ? 'ready' : 'disabled';
      set.cooldownUntil = null;
      set.lastErrorCategory = null;
    }
    if (Object.keys(set).length <= 2) {
      throw new Error('Provide a key label or replacement key.');
    }
    await keys.updateOne({ _id: objectId }, { $set: set });
    if (Object.hasOwn(changes, 'apiKey')) {
      await writeAudit('replace', { actorUid: actor, keyId: objectId.toHexString(), at: set.updatedAt });
    } else {
      await writeAudit('update_label', { actorUid: actor, keyId: objectId.toHexString(), at: set.updatedAt });
    }
    return getPublicKey(objectId.toHexString());
  }

  async function setEnabled(id, enabled, actorUid) {
    const objectId = validRecordId(id);
    if (!objectId) return null;
    if (typeof enabled !== 'boolean') throw new Error('Enabled must be a boolean.');
    const actor = safeActorUid(actorUid);
    const current = await keys.findOne({ _id: objectId });
    if (!current) return null;
    const stamp = now();
    const nextHealth = enabled
      ? (current.health === 'disabled' ? 'ready' : current.health)
      : 'disabled';
    await keys.updateOne({ _id: objectId }, {
      $set: {
        enabled,
        health: nextHealth,
        cooldownUntil: enabled ? current.cooldownUntil ?? null : null,
        updatedAt: stamp,
        updatedBy: actor,
      },
    });
    await writeAudit(enabled ? 'enable' : 'disable', {
      actorUid: actor,
      keyId: objectId.toHexString(),
      at: stamp,
    });
    return getPublicKey(objectId.toHexString());
  }

  async function deleteKey(id, actorUid) {
    const objectId = validRecordId(id);
    if (!objectId) return false;
    const actor = safeActorUid(actorUid);
    const result = await keys.deleteOne({ _id: objectId });
    if (result.deletedCount !== 1) return false;
    await writeAudit('delete', {
      actorUid: actor,
      keyId: objectId.toHexString(),
      at: now(),
    });
    return true;
  }

  async function reserveNextKey({ excludeIds = [], now: requestedNow = now(), model = '' } = {}) {
    const exclusions = excludeIds
      .map(validRecordId)
      .filter(Boolean);
    const record = await keys.findOneAndUpdate({
      ...(model ? { $and: [{
        $or: [
          { quotaModel: { $ne: model } },
          { quotaUntil: { $exists: false } },
          { quotaUntil: null },
          { quotaUntil: { $lte: requestedNow } },
        ],
      }] } : {}),
      enabled: true,
      health: { $nin: ['attention_required', 'configuration_error', 'disabled'] },
      _id: { $nin: exclusions },
      $or: [
        { cooldownUntil: { $exists: false } },
        { cooldownUntil: null },
        { cooldownUntil: { $lte: requestedNow } },
      ],
    }, {
      $set: {
        lastAttemptAt: requestedNow,
        health: 'ready',
        cooldownUntil: null,
      },
    }, {
      sort: { lastAttemptAt: 1, lastUsedAt: 1, createdAt: 1, _id: 1 },
      returnDocument: 'after',
      includeResultMetadata: false,
    });
    return record || null;
  }

  async function markUsed(id, at = now()) {
    const objectId = validRecordId(id);
    if (!objectId) return false;
    const result = await keys.updateOne({ _id: objectId }, {
      $set: { lastUsedAt: at, updatedAt: at },
      $inc: { attemptCount: 1 },
    });
    return result.matchedCount === 1;
  }

  async function markSuccess(id, at = now(), model = '') {
    const objectId = validRecordId(id);
    if (!objectId) return false;
    // Fallback model success must not erase a separate model's daily quota.
    const current = await keys.findOne({ _id: objectId });
    const otherModelLimited = current?.quotaUntil instanceof Date &&
      current.quotaUntil > at && current.quotaModel &&
      current.quotaModel !== model;
    const result = await keys.updateOne({ _id: objectId }, {
      $set: {
        health: otherModelLimited ? 'cooling_down' : 'ready',
        cooldownUntil: null,
        lastErrorCategory: otherModelLimited ? 'quota_limited' : null,
        lastSuccessAt: at,
        lastUsedAt: at,
        updatedAt: at,
      },
      ...(!otherModelLimited ? { $unset: {
        quotaUntil: '', quotaModel: '', quotaScope: '', quotaMetric: '',
      } } : {}),
      $inc: { successCount: 1 },
    });
    return result.matchedCount === 1;
  }

  async function markFailure(id, failure = {}) {
    const objectId = validRecordId(id);
    if (!objectId) return false;
    const category = safeCategory(failure.category);
    const health = ['cooling_down', 'attention_required', 'configuration_error'].includes(failure.health)
      ? failure.health
      : 'cooling_down';
    const at = failure.at instanceof Date ? failure.at : now();
    const extraQuota = category === 'quota_limited' && failure.quotaUntil instanceof Date
      ? {
          quotaUntil: failure.quotaUntil,
          quotaModel: String(failure.quotaModel || '').slice(0, 80),
          quotaScope: ['minute', 'daily'].includes(failure.quotaScope) ? failure.quotaScope : 'unknown',
          quotaMetric: ['RPM', 'TPM', 'RPD'].includes(failure.quotaMetric) ? failure.quotaMetric : 'unspecified',
          lastQuotaAt: at,
        } : {};
    const result = await keys.updateOne({ _id: objectId }, {
      $set: {
        health,
        cooldownUntil: failure.cooldownUntil instanceof Date ? failure.cooldownUntil : null,
        lastErrorCategory: category,
        lastFailedAt: at,
        updatedAt: at,
        ...extraQuota,
      },
      $inc: { failureCount: 1 },
    });
    return result.matchedCount === 1;
  }

  async function recordTestResult(id, { ok, category = null, retryAfterSeconds = null,
    quotaScope = 'unknown', quotaMetric = 'unspecified', model = '' } = {}) {
    const objectId = validRecordId(id);
    if (!objectId) return null;
    const current = await keys.findOne({ _id: objectId });
    if (!current) return null;
    const stamp = now();
    let health = current.enabled === true ? current.health : 'disabled';
    let cooldownUntil = current.cooldownUntil ?? null;
    let safeLastCategory = category == null ? null : safeCategory(category);
    if (ok === true) {
      health = current.enabled === true ? 'ready' : 'disabled';
      cooldownUntil = null;
      safeLastCategory = null;
    } else if (safeLastCategory === 'invalid_key') {
      health = 'attention_required';
      cooldownUntil = null;
    } else if (safeLastCategory === 'quota_limited') {
      health = 'cooling_down';
      const seconds = Math.max(1, Math.min(86_400, Math.ceil(Number(retryAfterSeconds) || 30)));
      cooldownUntil = new Date(stamp.getTime() + seconds * 1000);
    } else if (['provider_permission_denied', 'invalid_request'].includes(safeLastCategory)) {
      // Permanent configuration failures should stay out of the live key pool
      // until an administrator corrects/replaces the key and a retest passes.
      health = current.enabled === true ? 'configuration_error' : 'disabled';
      cooldownUntil = null;
    }
    await keys.updateOne({ _id: objectId }, {
      $set: {
        lastTestedAt: stamp,
        lastTestResult: ok === true ? 'passed' : 'failed',
        lastErrorCategory: safeLastCategory,
        health,
        cooldownUntil,
        ...(safeLastCategory === 'quota_limited' ? {
          quotaUntil: cooldownUntil,
          quotaModel: String(model).slice(0, 80),
          quotaScope: ['daily','minute'].includes(quotaScope) ? quotaScope : 'unknown',
          quotaMetric: ['RPD','RPM','TPM'].includes(quotaMetric) ? quotaMetric : 'unspecified',
          lastQuotaAt: stamp,
        } : {}),
        updatedAt: stamp,
      },
      ...(ok === true ? { $unset: {
        quotaUntil: '', quotaModel: '', quotaScope: '', quotaMetric: '',
      } } : {}),
    });
    return getPublicKey(objectId.toHexString());
  }

  return Object.freeze({
    getPoolSettings,
    getModelQuotaStatus,
    markModelQuota,
    listPublicKeys,
    getPublicKey,
    getKeyRecord,
    createKey,
    updateKey,
    setEnabled,
    deleteKey,
    reserveNextKey,
    markUsed,
    markSuccess,
    markFailure,
    recordTestResult,
  });
}
