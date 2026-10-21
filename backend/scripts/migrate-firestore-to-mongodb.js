import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import dotenv from 'dotenv';
import { MongoClient, GridFSBucket } from 'mongodb';
import {
  applicationDefault,
  cert,
  initializeApp,
} from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

import { migrateLegacyData } from '../src/legacy-migration.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const backendRoot = path.resolve(__dirname, '..');
dotenv.config({ path: path.join(backendRoot, '.env') });

const PROJECT_ID = 'capstone-4th-year-peso-ai';
const DB_NAME = process.env.MONGODB_DB_NAME || 'peso_jobkonek';
const STORAGE_BUCKET = process.env.FIREBASE_STORAGE_BUCKET ||
  'capstone-4th-year-peso-ai.firebasestorage.app';

function readOptions(argv) {
  const apply = argv.includes('--apply');
  const confirm = argv.includes('--confirm-peso-migration');
  const dryRun = argv.includes('--dry-run');
  const limitArg = argv.find((arg) => arg.startsWith('--limit='));
  const limit = limitArg ? Number(limitArg.slice('--limit='.length)) : Infinity;

  if (apply && dryRun) throw new Error('Choose either dry-run or apply mode, not both.');
  if (apply && !confirm) {
    throw new Error('Apply mode requires both --apply and --confirm-peso-migration.');
  }
  if (!(limit === Infinity || (Number.isSafeInteger(limit) && limit > 0))) {
    throw new Error('--limit must be a positive integer.');
  }

  return { apply, limit };
}

async function main() {
  let mongoClient;
  let firebaseApp;

  try {
    const options = readOptions(process.argv.slice(2));
    const mongoUri = String(process.env.MONGODB_URI || '').trim();
    if (!mongoUri || !/^mongodb(\+srv)?:\/\//.test(mongoUri) ||
        mongoUri.includes('YOUR_CLUSTER_HOST') || mongoUri.includes('DB_USERNAME')) {
      throw new Error('MONGODB_URI is missing or still a placeholder in backend/.env.');
    }

    const configuredPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './service-account.json';
    const credentialPath = path.isAbsolute(configuredPath)
      ? configuredPath
      : path.resolve(backendRoot, configuredPath);

    let credential;
    if (fs.existsSync(credentialPath)) {
      credential = cert(JSON.parse(fs.readFileSync(credentialPath, 'utf8')));
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS &&
               fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
      credential = applicationDefault();
    } else {
      throw new Error('Firebase Admin credentials are missing. Add backend/service-account.json or configure GOOGLE_APPLICATION_CREDENTIALS.');
    }

    firebaseApp = initializeApp({
      credential,
      projectId: PROJECT_ID,
      storageBucket: STORAGE_BUCKET,
    });

    mongoClient = new MongoClient(mongoUri, {
      serverSelectionTimeoutMS: 10000,
      connectTimeoutMS: 10000,
      maxPoolSize: 5,
    });
    await mongoClient.connect();
    const db = mongoClient.db(DB_NAME);
    await db.command({ ping: 1 });

    const stats = await migrateLegacyData({
      firestore: getFirestore(firebaseApp),
      auth: getAuth(firebaseApp),
      mongoUsers: db.collection('users'),
      mongoArtifactFiles: db.collection('profileArtifacts.files'),
      gridfsBucket: new GridFSBucket(db, { bucketName: 'profileArtifacts' }),
      storageBucket: getStorage(firebaseApp).bucket(STORAGE_BUCKET),
      apply: options.apply,
      limit: options.limit,
    });

    console.log(JSON.stringify({
      mode: options.apply ? 'APPLY_COPY_ONLY' : 'DRY_RUN_NO_MONGODB_WRITES',
      projectId: PROJECT_ID,
      databaseName: DB_NAME,
      storageBucket: STORAGE_BUCKET,
      sourceFirestoreAndStorageModified: false,
      ...stats,
    }, null, 2));

    if (!options.apply) {
      console.log('Preview only: no MongoDB profile or GridFS writes were made.');
      console.log('Review the counts, then use --apply --confirm-peso-migration only after explicit approval.');
    } else {
      console.log('Copy pass finished. Legacy Firestore and Storage data were not deleted or modified.');
    }
  } catch (error) {
    // Error messages from database/auth providers may contain sensitive context.
    // Report only a stable error class; never print URIs, tokens, keys or user data.
    console.error('PESO legacy migration stopped (' + (error?.name || 'Error') + ').');
    console.error('Check local config, Atlas IP access, database-user permissions and Firebase Admin read access; credential values were not printed.');
    process.exitCode = 1;
  } finally {
    try {
      await mongoClient?.close();
    } catch {
      // Preserve the primary exit state.
    }
    if (firebaseApp) {
      try {
        const { deleteApp } = await import('firebase-admin/app');
        await deleteApp(firebaseApp);
      } catch {
        // The process is ending; preserve the primary exit state.
      }
    }
  }
}

await main();
