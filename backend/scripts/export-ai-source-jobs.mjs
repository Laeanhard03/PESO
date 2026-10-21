// Read-only snapshot of the jobs the existing /api/jobs feed uses. Never writes to MongoDB.
import dotenv from 'dotenv';
import { MongoClient } from 'mongodb';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const backend = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
dotenv.config({ path: path.join(backend, '.env') });
const uri = String(process.env.MONGODB_URI || '').trim();
if (!uri) throw new Error('MONGODB_URI is not configured');
const client = new MongoClient(uri, { serverSelectionTimeoutMS: 10000, maxPoolSize: 2 });
try {
  await client.connect();
  const db = client.db(process.env.MONGODB_DB_NAME || 'peso_jobkonek');
  const rows = await db.collection('jobPostings').find({ status: 'active', isPublicPdfListing: true }).sort({ sourceFingerprint: 1 }).toArray();
  const seen = new Set();
  const records = rows.filter(row => {
    const key = String(row.sourceFingerprint || row._id);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  }).map(row => ({
    id: String(row._id), title: String(row.title || ''), company: String(row.company || ''),
    location: String(row.location || ''), salary: String(row.salary || ''),
    employmentType: String(row.employmentType || ''), description: String(row.description || '').slice(0, 4000),
    requirements: Array.isArray(row.requirements) ? row.requirements.map(String).slice(0, 60) : [],
    category: String(row.category || ''), sourceFingerprint: String(row.sourceFingerprint || ''),
    publicPdfSourceId: String(row.publicPdfSourceId || ''), parentFingerprint: String(row.parentFingerprint || ''),
    sourceTitle: String(row.sourceTitle || ''), sourceUrl: String(row.sourceUrl || ''),
    sourcePageStart: row.sourcePageStart ?? null, sourcePageEnd: row.sourcePageEnd ?? null,
    aiListingKind: String(row.aiListingKind || ''), isSynthetic: false,
    status: 'active', sourceLastSuccessfulSyncAt: row.sourceLastSuccessfulSyncAt || null,
  }));
  const target = path.resolve(backend, '..', 'mini_ai', 'data', 'source_jobs_v1.json');
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, JSON.stringify({ schemaVersion: 1, kind: 'read_only_live_job_snapshot', capturedAt: new Date().toISOString(), total: records.length, records }, null, 2) + '\n');
  const roles = records.filter(r => r.aiListingKind === 'role');
  console.log(JSON.stringify({ snapshot: target, rows: records.length, roles: roles.length, withRequirements: roles.filter(r => r.requirements.length > 2).length, withSourceUrl: records.filter(r => r.sourceUrl).length }, null, 2));
} finally { await client.close(); }