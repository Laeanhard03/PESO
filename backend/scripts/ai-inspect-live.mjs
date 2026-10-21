import dotenv from 'dotenv';
import { MongoClient } from 'mongodb';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
dotenv.config({ path: path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '.env') });
const uri = process.env.MONGODB_URI;
if (!uri || uri.includes('YOUR_CLUSTER')) { console.log(JSON.stringify({ connected: false, reason: 'mongodb_unconfigured' })); process.exit(0); }
const client = new MongoClient(uri, { serverSelectionTimeoutMS: 9000, connectTimeoutMS: 9000, maxPoolSize: 2 });
try {
  await client.connect();
  const db = client.db(process.env.MONGODB_DB_NAME || 'peso_jobkonek');
  const jobs = db.collection('jobPostings');
  const sources = db.collection('publicInformationSources');
  const sourceRows = await sources.find({}, { projection: { _id: 0, sourceId: 1, title: 1, url: 1, syncStatus: 1, pagesExtracted: 1, chunkCount: 1, aiComplete: 1, aiListings: 1, aiErrorCode: 1, lastSuccessfulSyncAt: 1 } }).toArray();
  const groups = await jobs.aggregate([{ $group: { _id: { category: '$category', status: '$status', origin: '$createdBy' }, count: { $sum: 1 } } }, { $sort: { count: -1 } }, { $limit: 25 }]).toArray();
  const sample = await jobs.find({}, { projection: { _id: 0, title: 1, company: 1, category: 1, description: 1, requirements: 1, sourceUrl: 1, sourceTitle: 1, sourcePageStart: 1, sourcePageEnd: 1, aiListingKind: 1, status: 1 } }).limit(7).toArray();
  const result = { connected: true, counts: { jobs: await jobs.estimatedDocumentCount(), publicSources: await sources.estimatedDocumentCount(), jobPdfLinks: await db.collection('jobPdfLinks').estimatedDocumentCount(), users: await db.collection('users').estimatedDocumentCount(), applications: await db.collection('jobApplications').estimatedDocumentCount() }, groups: groups.map(x => ({ ...x, _id: x._id })), sources: sourceRows.map(({ aiListings, ...x })=>({ ...x, aiListingsCount: Array.isArray(aiListings) ? aiListings.length : 0, aiFirstListingKeys: aiListings?.[0] ? Object.keys(aiListings[0]) : [] })), sample: (await jobs.find({ status: 'active', aiListingKind: 'role' }, { projection: { _id: 0, title: 1, company: 1, category: 1, description: 1, requirements: 1, sourceUrl: 1, sourcePageStart: 1, aiListingKind: 1 } }).limit(9).toArray()).map(x => ({ ...x, description: String(x.description || '').slice(0, 120) })) };
  console.log(JSON.stringify(result, null, 2));
} catch (e) { console.log(JSON.stringify({connected:false, code: e?.name || 'connection_error'})); }
finally { await client.close(); }