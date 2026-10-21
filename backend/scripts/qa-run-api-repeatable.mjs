// Repeatable, QA-only integration replay. Never connects to Atlas or production.
// Preserves the simulated quota test but prevents one run poisoning the next.
import { MongoClient } from 'mongodb';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const QA_DB = 'peso_e2e_browser_20261020';
const QA_TAG = 'QA_ISOLATED_NOT_REAL_APPLICANT';
const client = new MongoClient('mongodb://127.0.0.1:27117/?directConnection=true', {
  serverSelectionTimeoutMS: 5000, maxPoolSize: 2,
});
const filename = fileURLToPath(import.meta.url);
const main = path.join(path.dirname(filename), 'qa-api-e2e.mjs');
async function qaIsUp() {
  const response = await fetch('http://127.0.0.1:3003/api/health', {
    signal: AbortSignal.timeout(4000),
  });
  if (!response.ok) throw new Error('QA API must be healthy on port 3003');
}
async function clearOnlyLocalSimulation(db) {
  const fixtures = await db.collection('jobPostings').countDocuments({
    qaTag: QA_TAG,
  });
  if (fixtures < 2 || db.databaseName !== QA_DB) {
    throw new Error('Refusing quota cleanup outside validated QA fixture environment');
  }
  const result = await db.collection('geminiModelQuotas').deleteOne({
    _id: 'gemini-3.8-flash',
  });
  console.log('QA_SIMULATED_QUOTA_CLEANUP', result.deletedCount);
}
await client.connect();
const db = client.db(QA_DB);
let failed = false;
try {
  await qaIsUp();
  await clearOnlyLocalSimulation(db);
  const exitCode = await new Promise((resolve,reject) => {
    const child = spawn(process.execPath, [main], {
      cwd: path.dirname(filename), env: process.env,
      stdio: 'inherit', windowsHide: true,
    });
    child.once('error', reject);
    child.once('exit', code => resolve(code ?? 1));
  });
  if (exitCode !== 0) failed = true;
} finally {
  await clearOnlyLocalSimulation(db);
  await client.close();
}
if (failed) process.exitCode = 1;
