/**
 * Real Gemini Files API -> PDF role proposal -> independent PDF.js quote check
 * -> existing Go Mini-AI, using a one-page fictional PDF only.
 * Never persists a job, sends real applicant data or invents authentication.
 */
import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { MongoClient } from 'mongodb';
import { createMongoGeminiKeyStore } from '../src/gemini-key-store.js';
import { decryptApiKey } from '../src/gemini-key-vault.js';
import { createGeminiKeyRotator } from '../src/gemini-key-rotator.js';
import { createGeminiProvider } from '../src/gemini-provider.js';
import { createPublicPdfAiReaderFromRotator } from '../src/gemini-public-pdf-reader.js';
import { countPdfPages, extractPdfPages } from '../src/public-pdf-ingestion.js';
import { buildAiJobRecords } from '../src/public-pdf-ai-listings.js';
import { evaluateProfileAgainstJobs } from '../src/mini-ai-service.js';

const fixture = new URL('../../docs/qa_browser/qa-fictitious-role-notice-20261021.pdf',import.meta.url);
const model = 'gemini-3.8-flash';
const outcome = {probe:'REAL_PDF_TO_GO',model,fictionalDocument:true,
  realProvider:true,jobWrites:0,applicantWrites:0};
const client = new MongoClient(process.env.MONGODB_URI, {serverSelectionTimeoutMS:6000,maxPoolSize:2});
try {
  if (!process.env.GEMINI_KEY_ENCRYPTION_SECRET) throw new Error('key_config_missing');
  const bytes = await readFile(fixture);
  const pageCount = await countPdfPages(bytes);
  const pages = await extractPdfPages(bytes, {maxPages:4});
  outcome.pdfPages = pageCount;
  outcome.localTextVerified = pageCount===1 && pages.length===1 &&
    pages[0].text.includes('EHS Staff: Must have workplace safety training') &&
    pages[0].text.includes('Welder: Welding NC II certificate preferred');
  if (!outcome.localTextVerified) throw new Error('local_pdf_text_unreadable');

  await client.connect();
  const store = createMongoGeminiKeyStore(
    client.db(process.env.MONGODB_DB_NAME||'peso_jobkonek'),
    {encryptionSecret:()=>process.env.GEMINI_KEY_ENCRYPTION_SECRET});
  const quota = await store.getModelQuotaStatus(model);
  if (quota?.retryAfterSeconds>0) {
    Object.assign(outcome,{ok:false,stage:'quota_guard',code:'model_quota_active',
      retryAfterSeconds:quota.retryAfterSeconds});
    process.exitCode=2;
  } else {
    const provider = createGeminiProvider({timeoutMs:50000});
    const rotator = createGeminiKeyRotator({
      store,
      decryptKey: record=>decryptApiKey({
        record,encryptionSecret:process.env.GEMINI_KEY_ENCRYPTION_SECRET,
        recordId:String(record._id||'')}),
      providerCall:provider,legacyApiKey:'',fallbackModel:'',maxAttempts:1,
    });
    const reader = createPublicPdfAiReaderFromRotator({
      rotator,model,batchPages:1,
      generateWithKey:({apiKey,model,parts})=>provider({
        apiKey,model,operation:'public_pdf_jobs',payload:{parts}}),
      logger:{warn:()=>{},info:()=>{}},
    });
    const started=Date.now();
    const extracted = await reader.readDocument({
      bytes,pageCount,sourceTitle:'Fictional role notice for software QA'});
    outcome.elapsedMs = Date.now()-started;
    outcome.documentComplete = extracted.complete;
    outcome.gapCodes = (extracted.gaps||[]).map(x=>String(x.code).slice(0,55));
    const listings = Array.isArray(extracted.listings)?extracted.listings:[];
    const proposals=listings.flatMap(x=>Array.isArray(x.roleRequirements)?x.roleRequirements:[]);
    const correlated = proposals.filter(x=>x.status==='source_text_correlated');
    outcome.listingCount = listings.length;
    outcome.proposedRoleRequirements = proposals.length;
    outcome.correlatedRoleRequirements=correlated.length;
    outcome.requirementsNeedingReview=proposals.filter(x=>x.status==='needs_source_review').length;
    outcome.protectedExcluded=proposals.filter(x=>x.status==='excluded_protected').length;

    const records = buildAiJobRecords({
      source:{sourceId:'qa-memory-only-fake-pdf',title:'Fictional QA Source',
        url:'https://example.invalid/qa-fake-notice.pdf'},
      listings,now:new Date(),
    });
    const roles=records.filter(x=>x.aiListingKind==='role').map((role,index)=>({
      ...role,id:'qa-only-job-'+index,
    }));
    outcome.noticeCount = records.filter(x=>x.aiListingKind==='notice').length;
    outcome.roleCount = roles.length;
    outcome.roleScopes = roles.map(x=>({
      title: String(x.title).split(' - ')[0].slice(0,80),
      scope:x.requirementScope,correlated:x.roleRequirementEvidence?.correlatedSourceText||0,
    }));
    outcome.noCrossRoleRequirementBleed = roles.every(role=>{
      const title = role.title.toLowerCase();
      const other = title.includes('ehs staff')?'welder':title.includes('welder')?'ehs staff':null;
      return !other || (role.requirements||[]).every(x=>!String(x).toLowerCase().startsWith(other+':'));
    });
    if (roles.length) {
      const go = await evaluateProfileAgainstJobs({
        profile:{skills:['workplace safety training'],educationLevel:'Senior High School',
          yearsExperience:0},jobs:roles,
      });
      outcome.goStatus=go.status;
      outcome.goModelVersion=go.modelVersion||null;
      outcome.goResultCount=go.results?.length||0;
    }
    outcome.ok=Boolean(outcome.documentComplete && outcome.localTextVerified &&
      outcome.roleCount>=2 && outcome.noCrossRoleRequirementBleed &&
      outcome.goStatus==='ready' && outcome.goResultCount===outcome.roleCount);
    outcome.roleSpecificExtractionVerified=correlated.length>=2;
    if (!outcome.ok) process.exitCode=3;
  }
} catch(error) {
  // Sanitize all potentially private provider details.
  Object.assign(outcome,{ok:false,stage:'exception',
    type:String(error?.name||'Error').slice(0,65),
    code:String(error?.code||'read_failed').slice(0,65)});
  process.exitCode=4;
} finally {
  await client.close();
  console.log(JSON.stringify(outcome));
}
