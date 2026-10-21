// Read-only readiness check. Never print API keys, secret values or applicant data.
import 'dotenv/config';
import { MongoClient } from 'mongodb';

const rawModel = String(process.env.GEMINI_MODEL || 'gemini-3.8-flash');
const output = {
  model: /^gemini-[a-z0-9.-]+$/i.test(rawModel) ? rawModel : 'invalid',
  legacyKeyConfigured: Boolean(
    process.env.GEMINI_API_KEY &&
    !process.env.GEMINI_API_KEY.includes('PASTE_NEW_GEMINI_KEY_HERE')),
  encryptionSecretConfigured: Boolean(process.env.GEMINI_KEY_ENCRYPTION_SECRET),
  fallbackModelConfigured: Boolean(process.env.GEMINI_FALLBACK_MODEL),
  managedKeyCount: null,
  managedEnabledKeyCount: null,
  managedPoolActivated: null,
};
let client;
try {
  client = new MongoClient(process.env.MONGODB_URI, {
    serverSelectionTimeoutMS: 7000, connectTimeoutMS: 7000,
  });
  await client.connect();
  const db = client.db(process.env.MONGODB_DB_NAME || 'peso_jobkonek');
  const [total, enabled, setting] = await Promise.all([
    db.collection('geminiApiKeys').countDocuments({}),
    db.collection('geminiApiKeys').countDocuments({ enabled: true }),
    db.collection('geminiKeySettings').findOne({ _id: 'singleton' }, {
      projection: { managedPoolActivated: 1 },
    }),
  ]);
  Object.assign(output, {
    managedKeyCount: total,
    managedEnabledKeyCount: enabled,
    managedPoolActivated: setting?.managedPoolActivated === true,
  });
} catch(error) {
  output.metadataProbeFailed = error?.name || 'ConnectionUnavailable';
} finally {
  await client?.close();
}
console.log(JSON.stringify(output));
