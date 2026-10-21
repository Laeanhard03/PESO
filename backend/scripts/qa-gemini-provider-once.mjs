// Minimal one-request provider probe. No applicant data, no writes,
// no secret output, no retries and no real user flow. Run only from backend.
import 'dotenv/config';
import { MongoClient } from 'mongodb';
import { createMongoGeminiKeyStore } from '../src/gemini-key-store.js';
import { decryptApiKey } from '../src/gemini-key-vault.js';
import { createGeminiProvider } from '../src/gemini-provider.js';
import { classifyGeminiFailure } from '../src/gemini-key-rotator.js';

const model = String(process.env.GEMINI_MODEL || 'gemini-3.8-flash');
const report = {
  operation: 'minimal_connectivity_only',
  model: /^gemini-[a-z0-9.-]+$/i.test(model) ? model : 'invalid',
  keysTested: 0,
  status: 'not_started',
};
let client;
try {
  if (report.model === 'invalid') throw new Error('Invalid model configuration');
  client = new MongoClient(process.env.MONGODB_URI, {
    serverSelectionTimeoutMS: 7000, connectTimeoutMS: 7000,
  });
  await client.connect();
  const db = client.db(process.env.MONGODB_DB_NAME || 'peso_jobkonek');
  const store = createMongoGeminiKeyStore(db);
  const pool = await store.getPoolSettings();
  if (!pool.managedPoolActivated) {
    report.status = 'skipped_managed_pool_inactive';
  } else {
    const quota = await store.getModelQuotaStatus(model);
    if (quota?.retryAfterSeconds > 0) {
      report.status = 'skipped_known_model_quota';
      report.quotaScope = quota.scope;
      report.quotaMetric = quota.metric;
      report.retryAfterSeconds = quota.retryAfterSeconds;
    } else {
      const publicRecords = await store.listPublicKeys();
      const eligible = publicRecords.find((item) => (
        item.enabled === true &&
        item.health !== 'disabled' &&
        item.health !== 'attention_required' &&
        item.health !== 'configuration_error' &&
        (!item.cooldownUntil || new Date(item.cooldownUntil).getTime() < Date.now())
      ));
      if (!eligible) {
        report.status = 'skipped_no_ready_key';
      } else {
        const record = await store.getKeyRecord(String(eligible.id));
        const apiKey = decryptApiKey({
          record,
          encryptionSecret: process.env.GEMINI_KEY_ENCRYPTION_SECRET || '',
          recordId: String(record._id),
        });
        const provider = createGeminiProvider({ timeoutMs: 25000 });
        report.keysTested = 1;
        try {
          const result = await provider({
            apiKey, model, operation: 'key_test', payload: {},
          });
          report.status = result.text.trim() === 'OK'
            ? 'provider_ok'
            : 'provider_responded_nonexact';
        } catch (error) {
          const safe = classifyGeminiFailure(error);
          report.status = 'provider_error';
          report.failureCategory = safe.category;
          report.publicCode = safe.publicCode;
          report.httpStatus = Number(error.status || 0);
          if (safe.quotaScope) report.quotaScope = safe.quotaScope;
          if (safe.quotaMetric) report.quotaMetric = safe.quotaMetric;
          if (safe.retryAfterSeconds) report.retryAfterSeconds = safe.retryAfterSeconds;
        }
      }
    }
  }
} catch (error) {
  // Never print raw exception messages or traces from credential operations.
  report.status = 'local_probe_failed';
  report.failureType = String(error?.name || 'Error').slice(0, 40);
} finally {
  await client?.close();
}
console.log(JSON.stringify(report));
