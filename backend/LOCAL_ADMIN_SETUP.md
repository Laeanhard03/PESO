# PESO local Admin and MongoDB setup

Canonical project: C:\Users\Admin\Desktop\Prototype

This setup keeps Firebase Authentication for Google sign-in and signed ID tokens. The Node API verifies those tokens using Google's published Secure Token signing certificates, without a Firebase Admin service-account key for the normal Admin/profile path. MongoDB is authoritative for PESO application roles, profiles, account app-access status, and GridFS artifacts.

## 1. Prepare Atlas access

Use the existing Cluster0 cluster.

- Add only this PC's current public IP as a single-host /32 entry under Network Access. Never use 0.0.0.0/0.
- Create a dedicated database user for PESO with readWrite on the peso_jobkonek database only. Do not use the Atlas administrator account for the application.
- Use a new URI for this application. Do not reuse credentials that may have been shared or saved in source files.
- The database and collections can be created by MongoDB at first write. The API expects the database name peso_jobkonek.

## 2. Configure the local backend

Open PowerShell and run:

    Set-Location C:\Users\Admin\Desktop\Prototype\backend
    powershell -NoProfile -ExecutionPolicy Bypass -File .\configure-backend-admin.ps1

Enter the dedicated app user's MongoDB URI at the hidden prompt. Secret values are never printed. If backend/.env already exists, replacement requires typing YES; the script preserves other settings, creates and verifies an access-restricted backup in the current Windows user's local app-data folder, and atomically replaces the file only after validation.

If the rest of backend/.env is already configured and only the managed-key vault secret is missing, use the narrower helper instead:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ensure-gemini-key-encryption.ps1 -ConfirmAddEncryptionSecret

It changes only `GEMINI_KEY_ENCRYPTION_SECRET`; its explicit switch is a live-change guard. It creates a verified access-restricted backup and atomically updates the environment file. It never prints the secret, and subsequent runs are idempotent when the value is already valid.

The script also creates `GEMINI_KEY_ENCRYPTION_SECRET` as base64 of exactly 32 cryptographically random bytes when absent, or validates and preserves the existing value. If an existing .env has no such secret, it asks for the exact phrase `GENERATE NEW ENCRYPTION SECRET` because changing a key after managed Gemini credentials exist would make those ciphertexts unreadable. Do not regenerate or discard this secret after saving managed keys; keep the restricted backup safe.

## Gemini key manager

After the API and verified Google Admin session are working, open **Admin → Gemini API Keys**. Add, label, replace, enable/disable, test, or delete keys there. Saved key values are encrypted by the backend with AES-256-GCM and are not returned by the API; the UI shows only a masked suffix and health metadata. The first successfully saved managed key activates a persistent managed pool, so the legacy `GEMINI_API_KEY` fallback does not silently return if all managed keys are later disabled or deleted.

The **Test Key** action makes exactly one small request and has a confirmation dialog because it can consume Google API quota or incur usage. It does not automatically retry. Do not rotate keys to evade quota/rate limits. Automated tests use mocked provider calls and never call Google.

## 3. Start and verify the API

From the backend folder:

    npm run check
    npm run dev

Open http://127.0.0.1:3000/api/health and confirm:

- mongoDbConnected is true
- firebaseTokenVerificationReady is true
- databaseName is peso_jobkonek

The first successful API request made with a verified Google sign-in for the address configured in `INITIAL_ADMIN_EMAIL` bootstraps a MongoDB users document with role admin. The email must be verified and the provider must be `google.com`. That bootstrap occurs only after MongoDB is connected. The source fallback, `admin@example.invalid`, is deliberately non-routable; set `INITIAL_ADMIN_EMAIL` to the owner-controlled, verified Google address before first admin use.

## 4. Test the real Admin screen

1. Open the local PESO app and sign in with the verified Google address configured in `backend/.env` (`INITIAL_ADMIN_EMAIL`).
2. Refresh the Admin screen after the backend is connected so the bootstrap role is read from MongoDB.
3. Check the account list, edit a safe test user's profile, and test the enable/disable control against a test account.
4. Confirm that disabling or deleting a user revokes PESO API access; it does not disable or delete their Firebase Auth identity.

The Admin list enumerates MongoDB PESO profile documents, not every account in the Firebase Authentication directory. Profiles are written to MongoDB as users use profile APIs. Existing legacy profiles and documents still stored only in Firestore/Storage are not automatically imported by this setup.

## 5. Legacy data migration is separate

The migration script under scripts/migrate-firestore-to-mongodb.js reads legacy Firestore and Storage data using a privileged migration credential/ADC. That is not needed for MongoDB-based Admin role checks, profile editing, app-access status, or GridFS cleanup for files already migrated into MongoDB. Do not run migration apply mode without reviewing the dry-run counts and obtaining explicit approval for the data copy.

## Security and current status

- Do not put MongoDB URIs, Firebase ID tokens, private keys, or credential contents in Flutter, Git, or chat.
- Do not deploy Firebase rules/functions, change billing, publish credentials, or add a broad Atlas network rule for this local setup.
- Verified 2026-10-18: backend/.env exists and the live API health endpoint reports MongoDB connected and Firebase token verification ready. `GEMINI_KEY_ENCRYPTION_SECRET` is not configured yet, so managed Gemini key creation is blocked until the local secret is added and the API is reloaded. No managed keys have been stored and no real Gemini Test Key request has been sent.
