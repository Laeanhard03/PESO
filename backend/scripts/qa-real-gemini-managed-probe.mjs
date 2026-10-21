/**
 * One bounded real Gemini provider probe using the app's managed encrypted
 * key pool. Owner-authorized machine only. No applicant data or secret output.
 * Does not create users, post jobs, or modify public hiring records.
 */
import 'dotenv/config';
import { MongoClient } from 'mongodb';
import { createMongoGeminiKeyStore } from '../src/gemini-key-store.js';
import { decryptApiKey } from '../src/gemini-key-vault.js';
import { createGeminiKeyRotator } from '../src/gemini-key-rotator.js';
import { createGeminiProvider } from '../src/gemini-provider.js';
const model = 'gemini-3.8-flash';
const uri = process.env.MONGODB_URI;
if (!uri || !process.env.GEMINI_KEY_ENCRYPTION_SECRET) {
  console.log(JSON.stringify({probe:'REAL_PROVIDER',ok:false,stage:'configuration',code:'missing_secure_key_configuration'}));
  process.exit(2);
}
const client = new MongoClient(uri, {serverSelectionTimeoutMS:6000,maxPoolSize:2});
try {
  await client.connect();
  const db = client.db(process.env.MONGODB_DB_NAME || 'peso_jobkonek');
  const store = createMongoGeminiKeyStore(db, {encryptionSecret:()=>process.env.GEMINI_KEY_ENCRYPTION_SECRET});
  const pool = await store.getPoolSettings();
  const quota = await store.getModelQuotaStatus(model);
  const publicKeys = await store.listPublicKeys();
  if (!pool.managedPoolActivated || !publicKeys.some(k=>k.enabled===true)) {
    console.log(JSON.stringify({probe:'REAL_PROVIDER',ok:false,stage:'configuration',code:'no_enabled_managed_keys'}));
    process.exitCode=2;
  } else if (quota?.retryAfterSeconds>0) {
    console.log(JSON.stringify({probe:'REAL_PROVIDER',ok:false,stage:'quota_guard',code:'model_quota_active',
      retryAfterSeconds:quota.retryAfterSeconds,scope:quota.scope||null,metric:quota.metric||null}));
    process.exitCode=3;
  } else {
    const rotator = createGeminiKeyRotator({
      store,
      decryptKey: (record) => decryptApiKey({
        record,encryptionSecret:process.env.GEMINI_KEY_ENCRYPTION_SECRET,
        recordId:String(record._id||''),
      }),
      providerCall: createGeminiProvider({timeoutMs:22000}),
      legacyApiKey:'',fallbackModel:'',maxAttempts:1,totalBudgetMs:29000,
    });
    const started = Date.now();
    const result = await rotator.generate({model,operation:'key_test',payload:{}});
    const safe = {
      probe:'REAL_PROVIDER',model,
      ok:result.ok===true,attempts:Number(result.attempts||0),
      elapsedMs:Date.now()-started,
      statusCode:result.ok?200:Number(result.statusCode||0),
      code:result.ok?'provider_success':String(result.code||'unknown_provider_error').slice(0,80),
      isExpectedOK:result.ok ? /^OK\.?$/i.test(String(result.result?.text||'').trim()) : false,
      retryAfterSeconds:result.ok?null:(result.retryAfterSeconds??null),
    };
    console.log(JSON.stringify(safe));
    if (!safe.ok) process.exitCode=4;
  }
} catch(error) {
  // Never print raw upstream error bodies, raw keys, tokens or request details.
  console.log(JSON.stringify({probe:'REAL_PROVIDER',ok:false,stage:'exception',
    errorType:String(error?.name||'Error').slice(0,64)}));
  process.exitCode=5;
} finally {
  await client.close();
}
