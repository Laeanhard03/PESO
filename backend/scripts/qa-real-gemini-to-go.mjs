/**
 * One bounded live Google Gemini extraction -> source facts verification ->
 * existing Go model integration, entirely in memory with fictional records.
 * No Firebase identity, real applicant data, or Mongo job/profile writes.
 */
import 'dotenv/config';
import { MongoClient } from 'mongodb';
import { createMongoGeminiKeyStore } from '../src/gemini-key-store.js';
import { decryptApiKey } from '../src/gemini-key-vault.js';
import { createGeminiKeyRotator } from '../src/gemini-key-rotator.js';
import { createGeminiProvider } from '../src/gemini-provider.js';
import { verifyGeminiFacts, evaluateProfileAgainstJobs } from '../src/mini-ai-service.js';
const model = 'gemini-3.8-flash';
const source = [
  'Fictional QA applicant, not a real person.',
  'Completed education: Senior High School.',
  'Skills: MS Excel, Data Entry, Computer Typing.',
  'No previous job experience. No certificates listed.',
].join(' ');
if (!process.env.MONGODB_URI || !process.env.GEMINI_KEY_ENCRYPTION_SECRET) {
  throw new Error('Managed Gemini pool not securely configured');
}
const client = new MongoClient(process.env.MONGODB_URI, {
  serverSelectionTimeoutMS:6000,maxPoolSize:2,
});
const output = {probe:'REAL_GEMINI_TO_GO',realProvider:true,
  fictionalSource:true,applicantWrites:0,jobWrites:0,model};
try {
  await client.connect();
  const db = client.db(process.env.MONGODB_DB_NAME || 'peso_jobkonek');
  const store = createMongoGeminiKeyStore(db, {
    encryptionSecret:()=>process.env.GEMINI_KEY_ENCRYPTION_SECRET,
  });
  const quota = await store.getModelQuotaStatus(model);
  if (quota?.retryAfterSeconds>0) {
    Object.assign(output,{ok:false,stage:'quota_guard',code:'model_quota_active',
      retryAfterSeconds:quota.retryAfterSeconds});
    process.exitCode=2;
  } else {
    const rotator = createGeminiKeyRotator({
      store,
      decryptKey: record => decryptApiKey({
        record,encryptionSecret:process.env.GEMINI_KEY_ENCRYPTION_SECRET,
        recordId:String(record._id||''),
      }),
      providerCall:createGeminiProvider({timeoutMs:30000}),
      legacyApiKey:'',fallbackModel:'',maxAttempts:1,totalBudgetMs:38000,
    });
    const started = Date.now();
    const extracted = await rotator.generate({
      operation:'profile_extraction',model,
      payload:{parts:[{text:source}]},
    });
    output.elapsedMs = Date.now()-started;
    output.attempts = Number(extracted.attempts||0);
    if (!extracted.ok) {
      Object.assign(output,{ok:false,stage:'gemini_extraction',
        httpStatus:Number(extracted.statusCode||0),
        code:String(extracted.code||'unknown').slice(0,65),
        retryAfterSeconds:extracted.retryAfterSeconds??null});
      process.exitCode=3;
    } else {
      const proposed = extracted.result?.profile || {};
      const verification = verifyGeminiFacts(proposed, source);
      const profile = {
        aiProfile:proposed,
        aiMatchingExtraction:verification,
        educationLevel:'Senior High School',
        // Independently entered user-only field rather than Gemini suggestion.
        skills:['MS Excel','Data Entry','Computer Typing'],
      };
      const job = {
        id:'qa-memory-only-data-entry-20261021',
        title:'Data Entry Clerk',
        status:'active',
        category:'walk_in_application',
        company:'FICTIONAL QA employer',
        requirements:['MS Excel','Data Entry'],
      };
      const matched = await evaluateProfileAgainstJobs({profile,jobs:[job]});
      Object.assign(output,{
        ok:matched.status==='ready' && matched.results?.length===1,
        stage:'complete',
        extractionShapeValid:typeof proposed==='object' && !Array.isArray(proposed),
        extractionVerificationStatus:verification.status,
        sourceSupportedSkills:verification.skills?.length||0,
        rejectedGeminiClaims:verification.rejectedCount,
        matchingStatus:matched.status,
        modelVersion:matched.modelVersion||null,
        resultCount:matched.results?.length||0,
        jobIdMatches:matched.results?.[0]?.jobId===job.id,
        confidence:matched.results?.[0]?.confidence||null,
        reviewFlagCount:matched.results?.[0]?.needsReview?.length||0,
      });
      if (!output.ok) process.exitCode=4;
    }
  }
} catch(error) {
  // Never print external provider or credential error content.
  Object.assign(output,{ok:false,stage:'exception',type:String(error?.name||'Error').slice(0,65)});
  process.exitCode=5;
} finally {
  await client.close();
  console.log(JSON.stringify(output));
}
