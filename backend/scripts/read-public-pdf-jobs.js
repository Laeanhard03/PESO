/**
 * Reads the configured public PESO compilations with Gemini and publishes the
 * resulting job cards.
 *
 * Usage:
 *   node scripts/read-public-pdf-jobs.js                # dry run: plan + stored status
 *   node scripts/read-public-pdf-jobs.js --apply        # download, read, publish
 *   node scripts/read-public-pdf-jobs.js --apply --source montalban-walk-in-official
 *
 * Reading a 64-page scanned compilation can take several minutes per page range,
 * so progress is printed as each source finishes. Nothing is published until the
 * read for that source has completed.
 */
import dotenv from 'dotenv';
import { MongoClient } from 'mongodb';
import { createGeminiProvider } from '../src/gemini-provider.js';
import { createGeminiKeyRotator } from '../src/gemini-key-rotator.js';
import { createMongoGeminiKeyStore } from '../src/gemini-key-store.js';
import { decryptApiKey } from '../src/gemini-key-vault.js';
import { createPublicPdfIngestion } from '../src/public-pdf-ingestion.js';
import { createPublicPdfAiReaderFromRotator } from '../src/gemini-public-pdf-reader.js';
import {
  retireLegacyPublicPdfCards,
  syncAllPublicPdfAiJobs,
  syncPublicPdfAiJobs,
} from '../src/public-pdf-ai-listings.js';

dotenv.config({ quiet: true });

const apply = process.argv.includes('--apply');
const forceAiRead = process.argv.includes('--force');
const sourceFlagIndex = process.argv.indexOf('--source');
const onlySource = sourceFlagIndex >= 0 ? String(process.argv[sourceFlagIndex + 1] || '').trim() : '';
const uri = String(process.env.MONGODB_URI || '').trim();
const databaseName = String(process.env.MONGODB_DB_NAME || 'peso_jobkonek').trim();
const model = String(process.env.GEMINI_PDF_MODEL || process.env.GEMINI_MODEL || 'gemini-3.8-flash').trim();

if (!uri || uri.includes('YOUR_CLUSTER_HOST') || uri.includes('DB_USERNAME')) {
  console.error('MongoDB is not configured; no documents were read.');
  process.exit(2);
}

const client = new MongoClient(uri, {
  serverSelectionTimeoutMS: 10000,
  connectTimeoutMS: 10000,
  maxPoolSize: 2,
});

try {
  await client.connect();
  const db = client.db(databaseName);
  await db.command({ ping: 1 });

  const store = createMongoGeminiKeyStore(db, {
    encryptionSecret: () => process.env.GEMINI_KEY_ENCRYPTION_SECRET || '',
  });
  const provider = createGeminiProvider();
  const rotator = createGeminiKeyRotator({
    store,
    decryptKey: (record) => decryptApiKey({
      record,
      encryptionSecret: process.env.GEMINI_KEY_ENCRYPTION_SECRET || '',
      recordId: String(record?._id || ''),
    }),
    providerCall: (args) => provider(args),
    legacyApiKey: String(process.env.GEMINI_API_KEY || '').trim(),
    maxAttempts: 2,
    totalBudgetMs: 700_000,
  });
  const aiReader = createPublicPdfAiReaderFromRotator({
    rotator,
    model,
    // The upload and every batch must use the same key: Gemini rejects another
    // key's Files API document with 403.
    generateWithKey: ({ apiKey, model: modelName, parts }) => provider({
      apiKey,
      operation: 'public_pdf_jobs',
      model: modelName,
      payload: { parts },
    }),
    logger: {
      info: (message) => console.log(String(message || '').slice(0, 300)),
      warn: (message) => console.warn(String(message || '').slice(0, 300)),
    },
  });
  const ingestion = createPublicPdfIngestion({
    db,
    aiReader,
    logger: { warn: (message) => console.warn(String(message || '').slice(0, 300)) },
  });

  const before = await ingestion.getStatus();
  console.log(JSON.stringify({
    ok: true,
    mode: apply ? 'apply' : 'dry-run',
    database: databaseName,
    model,
    sources: before.map((source) => ({
      sourceId: source.sourceId,
      syncStatus: source.syncStatus,
      aiListingsCount: source.aiListingsCount,
      aiPagesRead: source.aiPagesRead,
      aiPageCount: source.aiPageCount,
      aiComplete: source.aiComplete,
      aiErrorCode: source.aiErrorCode,
    })),
  }, null, 2));

  if (!apply) {
    console.log('\nDry run only. Re-run with --apply to read the PDFs with Gemini and publish job cards.');
  } else {
    const targets = onlySource
      ? before.filter((source) => source.sourceId === onlySource)
      : before;
    if (!targets.length) throw new Error('No configured source matched ' + (onlySource || '(all)'));

    for (const target of targets) {
      const startedAt = Date.now();
      console.log('\nReading ' + target.sourceId + ' with Gemini…');
      const result = await ingestion.syncSource({ sourceId: target.sourceId }, { forceAiRead });
      console.log(JSON.stringify({
        sourceId: result.sourceId,
        status: result.status,
        pagesExtracted: result.pagesExtracted,
        aiListings: result.aiListings,
        aiPagesRead: result.aiPagesRead,
        aiComplete: result.aiComplete,
        aiErrorCode: result.aiErrorCode,
        seconds: Math.round((Date.now() - startedAt) / 1000),
      }, null, 2));

      const published = onlySource
        ? await syncPublicPdfAiJobs({ db, sourceId: target.sourceId, apply: true })
        : null;
      if (published) {
        console.log(JSON.stringify({
          published: {
            total: published.total,
            notices: published.notices,
            roles: published.roles,
            created: published.created,
            renewed: published.renewed,
            superseded: published.superseded,
          },
        }, null, 2));
      }
    }

    if (!onlySource) {
      const published = await syncAllPublicPdfAiJobs({ db, apply: true });
      console.log('\nPublished:');
      console.log(JSON.stringify(published, null, 2));
    }
    const retired = await retireLegacyPublicPdfCards({ db, apply: true });
    console.log('\nLegacy cards retired: ' + retired.retired + ' (of ' + retired.candidates + ' candidates).');

    const after = await ingestion.getStatus();
    console.log('\nFinal source state:');
    console.log(JSON.stringify(after.map((source) => ({
      sourceId: source.sourceId,
      syncStatus: source.syncStatus,
      aiListingsCount: source.aiListingsCount,
      aiPagesRead: source.aiPagesRead,
      aiPageCount: source.aiPageCount,
      aiComplete: source.aiComplete,
      aiGaps: source.aiGaps,
      aiErrorCode: source.aiErrorCode,
    })), null, 2));
  }
} catch (error) {
  console.error(JSON.stringify({
    ok: false,
    errorName: error?.name || 'Error',
    errorCode: typeof error?.code === 'string' || typeof error?.code === 'number' ? error.code : null,
    message: String(error?.message || '').slice(0, 300),
  }));
  process.exitCode = 1;
} finally {
  await client.close().catch(() => {});
}
