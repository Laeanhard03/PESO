import dotenv from 'dotenv';
import { MongoClient } from 'mongodb';
import { syncPublicPdfJobListings } from '../src/public-pdf-job-listings.js';

dotenv.config({ quiet: true });

const apply = process.argv.includes('--apply');
const uri = String(process.env.MONGODB_URI || '').trim();
const databaseName = String(process.env.MONGODB_DB_NAME || 'peso_jobkonek').trim();

if (!uri || uri.includes('YOUR_CLUSTER_HOST') || uri.includes('DB_USERNAME')) {
  console.error('MongoDB is not configured; no job listings were changed.');
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

  const report = await syncPublicPdfJobListings({ db, apply });
  console.log(JSON.stringify({
    ok: report.ok,
    mode: apply ? 'apply' : 'dry-run',
    database: databaseName,
    importedOrExistingCount: report.importedOrExistingCount,
    failedCount: report.failedCount,
    results: report.results,
  }, null, 2));

  if (report.failedCount > 0) process.exitCode = 1;
} catch (error) {
  console.error(JSON.stringify({
    ok: false,
    errorName: error?.name || 'Error',
    errorCode: typeof error?.code === 'string' || typeof error?.code === 'number' ? error.code : null,
  }));
  process.exitCode = 1;
} finally {
  await client.close().catch(() => {});
}
