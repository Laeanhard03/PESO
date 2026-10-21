# One-time Firebase profile and artifact migration

This utility copies legacy PESO data from Firebase into the local MongoDB Atlas database.
Firebase Authentication remains the sign-in service. The utility does not delete or update
Firestore documents or Firebase Storage objects.

## What it migrates

- User profiles in Firestore collection users, using verified Firebase Auth identity data.
- Private artifacts whose metadata is in users/{uid}/artifacts/{artifactId} and whose bytes
  are in Firebase Storage at the exact path users/{uid}/artifacts/{artifactId}.
- Supported file types only: PDF, JPEG, PNG. Files must be no larger than 20 MiB and the
  Firestore MIME type must match the Storage object's MIME type.
- GridFS metadata records the verified owner UID and source Storage path.

Existing MongoDB profiles are never updated. Existing artifacts already copied from a source
path are skipped. This makes sequential reruns safe after partial failures. User documents
whose Firebase Auth identity no longer exists are not migrated. Unsupported, missing or
oversized artifacts are summarized without printing user names, UIDs, file names or contents.

## Prerequisites

1. Complete the separate local backend setup in MONGODB_BACKEND_SETUP.md.
2. Ensure Atlas Network Access allows the current PC's public IP and the database user can
   read/write the peso_jobkonek database.
3. Provide Firebase Admin credentials with read access to the legacy Firestore users
   collection and Firebase Storage objects. The default is backend/service-account.json;
   alternatively configure GOOGLE_APPLICATION_CREDENTIALS to a local credential file.
4. Keep the .env and service-account file local and ignored by Git.

## Run a read-only preview first

From PowerShell:

    Set-Location C:\Users\Admin\Desktop\Prototype\backend
    node .\scripts\migrate-firestore-to-mongodb.js

This is dry-run mode by default. It reads the old metadata and Storage object metadata, checks
the MongoDB destination for duplicate records, and prints summary counts only. It does not
write any MongoDB profiles or GridFS objects, download document bytes, or modify Firebase.

For a small rehearsal, limit the preview to the first five Firestore user documents:

    node .\scripts\migrate-firestore-to-mongodb.js --limit=5

Review the preview counts and fix missing/unsupported sources before applying a full pass.

## Copy data after explicit approval

Only after the preview is reviewed and the owner has approved the live data copy:

    node .\scripts\migrate-firestore-to-mongodb.js --apply --confirm-peso-migration

The two flags are both required for write mode. The copy pass only inserts missing profiles
and copies missing artifacts to GridFS. The source Firebase data remains intact for rollback.
A rerun skips MongoDB profiles and GridFS files already migrated from the same source path.

## After the copy

1. Verify the API health endpoint shows mongoDbConnected: true and
   firebaseAdminReady: true.
2. Sign in and test profile, assessment outcomes, Admin account listing, and a sample migrated
   artifact download from the owner account.
3. Compare counts and spot-check artifacts before deciding what to do with the legacy data.
   Do not delete legacy Firestore/Storage data until the owner independently approves a
   separate cleanup after the migration is validated.
