# PESO Admin API

The Flutter app uses Firebase Authentication for Google sign-in. The Node API verifies Firebase ID tokens with Google's published Secure Token signing certificates; the regular Admin/profile API does **not** need a Firebase Admin service-account JSON.

## Ownership and authorization

- **Firebase Authentication:** Google sign-in and signed ID tokens. The API checks the token signature, project audience/issuer, subject, and time claims.
- **MongoDB Atlas:** authoritative PESO application roles, account/profile fields, onboarding data, job-seeker summaries, application access status, and private artifacts in GridFS.
- **Flutter:** passes the current Firebase ID token to the API. It never receives MongoDB credentials and cannot set its own role.

The first verified Google sign-in for the address configured in `INITIAL_ADMIN_EMAIL` bootstraps a users document with role set to admin once MongoDB is connected. The source fallback, `admin@example.invalid`, is deliberately non-routable; set `INITIAL_ADMIN_EMAIL` to the owner-controlled, verified Google address before first admin use. The bootstrap requires the token email to be verified and its provider to be google.com. The server writes the role; profile payloads cannot set role, uid, or identity fields.

## Admin endpoints

All admin endpoints require a valid Firebase ID token and an admin role read from MongoDB. They fail closed when MongoDB is unavailable.

- **GET /api/admin/users?limit=100&pageToken=...** — joins Firebase Auth identities with MongoDB PESO profiles when privileged Auth access is configured, including Firebase-only accounts and pending cleanup. Otherwise falls back to MongoDB profiles and returns `authProviderMutationsAvailable: false`.
- **PATCH /api/admin/users/:uid/profile** — updates allowlisted profile fields in MongoDB and records the server-side updater; pending-deletion accounts cannot be edited.
- **PATCH /api/admin/users/:uid/status** — enables/disables **PESO application access** by changing the MongoDB profile. It does not disable the Firebase Auth identity; pending-deletion accounts cannot be re-enabled.
- **DELETE /api/admin/users/:uid** — revokes PESO access, scrubs profile fields, deletes the Firebase Auth identity when privileged Auth access is configured, and removes owned GridFS artifacts. A failed cleanup leaves a visible pending-deletion record for retry; only completed cleanup receives a final tombstone.

Admins cannot edit, disable, or delete their own account or another admin profile. The admin list never returns raw resumes or full AI-profile JSON.

## Gemini API Key Management

The Admin dashboard has a **Gemini API Keys** section backed by these Firebase-authenticated, MongoDB-admin-protected routes:

- `GET /api/admin/gemini-keys` — list only labels, masked suffixes, enabled/health/cooldown status, timestamps, and boolean configuration status.
- `POST /api/admin/gemini-keys` — add a key; plaintext is accepted for this request only and encrypted before MongoDB insertion.
- `PUT /api/admin/gemini-keys/:id` — change the label and/or replace the key. The previous value is never returned.
- `PATCH /api/admin/gemini-keys/:id/status` — enable or disable a managed key.
- `DELETE /api/admin/gemini-keys/:id` — remove the encrypted value and record metadata-only audit information.
- `POST /api/admin/gemini-keys/:id/test` — requires `{ "confirm": true }` and sends exactly one small `generateContent` request using `GEMINI_MODEL` (default `gemini-3.8-flash`) without automatic retry. It may consume API quota or incur usage; the UI presents a confirmation dialog.

Every route applies the existing Firebase token verification, MongoDB-backed `role=admin` check, and Mongo readiness gate. A request body cannot set the actor UID or role. Responses never include the plaintext API key, ciphertext, IV, authentication tag, or raw provider response. Do not put Gemini keys in Flutter build defines, source control, Firebase profile documents, screenshots, task notes, or logs.

### Key encryption and pool behavior

- `GEMINI_KEY_ENCRYPTION_SECRET` must be base64 encoding of exactly 32 random bytes. It is used only by the local server for AES-256-GCM; it must not be shared with `FILE_LINK_SECRET`, a MongoDB URI/password, or a provider key.
- Each managed key has a fresh random 12-byte IV, a 16-byte authentication tag, record-bound additional authenticated data, and a schema/key version. The MongoDB document stores only ciphertext and safe metadata.
- Keep an access-restricted backup of `GEMINI_KEY_ENCRYPTION_SECRET`. Losing it makes managed key records undecryptable. Do not casually regenerate it or delete the only secure backup; changing it after keys exist requires a separate reviewed re-encryption procedure.
- `GEMINI_API_KEY` remains a compatibility fallback only until the first managed key is successfully registered. That first save activates a persistent managed-pool setting. Disabling or removing every managed key does **not** silently reactivate the old environment fallback.
- Profile extraction (`POST /api/ai/profile`) and the AI query route (`POST /api/ai/query`) share the same bounded rotator. Each request tries at most three distinct eligible managed keys for timeout/network/transient upstream failures or a key-specific invalid credential. A key is not repeated within one request.
- HTTP 429 / `RESOURCE_EXHAUSTED` stops that request immediately and respects retry guidance; keys must not be rotated to bypass provider/project quotas, RPM/TPM limits, or billing restrictions. Timeout failover can duplicate upstream work if a completed response was lost, which is why attempts are bounded.
- Quota is recorded on the key without a cooldown, so the key stays usable for another model. When the primary model's quota is spent, `GEMINI_FALLBACK_MODEL` (for example `gemini-3.7-flash`) is tried once on the same keys; Gemini quotas are per model, so this restores registration/matching without bypassing the project quota. The provider's `RetryInfo` window (usually the daily reset) is returned as `Retry-After` when the fallback is also exhausted. Unset `GEMINI_FALLBACK_MODEL` to disable the retry.
- Automated tests use an injected mock provider and do not call Google. A real “Test Key” action is opt-in and may consume usage.

### Firebase Admin account synchronization

Normal PESO sign-in verification and MongoDB role checks can work without Firebase Admin access. Full account reconciliation and actual Firebase Auth deletion need privileged Firebase Auth access configured for the backend. A local Windows deployment can use a protected service-account JSON stored outside the repository and the GOOGLE_APPLICATION_CREDENTIALS environment variable, or supported Application Default Credentials/workload identity in managed deployments. Restart the API after configuring it, then verify the admin users response returns authProviderMutationsAvailable=true. The health endpoint only confirms ID-token verification readiness.

Without Firebase Admin access, the Admin UI warns that it can show MongoDB profiles only. Firebase-only identities cannot be enumerated or deleted in that mode. Deletion of a profile-backed account immediately revokes PESO API access, scrubs personal profile fields, and keeps the account marked Deletion pending when Auth or document cleanup cannot be confirmed; it can be retried after access is configured. Do not manually remove user documents as a substitute for the Admin deletion flow, which writes a completed tombstone after cleanup.

## Local run and verification

1. Create a dedicated Atlas database user with readWrite only on peso_jobkonek; do not use an Atlas administrator account for the app.
2. Run backend/configure-backend-admin.ps1 and enter that user's MongoDB URI through the hidden prompt. The script writes the URI and file-link signing secret to the gitignored backend/.env. Never paste connection strings into chat.
3. From backend, run npm ci, npm run check, and npm run dev.
4. Open http://127.0.0.1:3000/api/health. Confirm mongoDbConnected is true, firebaseTokenVerificationReady is true, and databaseName is peso_jobkonek.
5. Sign in to PESO with the verified Google address configured in `backend/.env` (`INITIAL_ADMIN_EMAIL`); the API bootstraps its MongoDB admin role after MongoDB is connected. Refresh the Admin screen and test listing, profile edits, and PESO app disable/restore with a safe test account.

The standard Admin API does not require backend/service-account.json. That file or ADC is only relevant to legacy Firestore/Storage migration tooling or privileged Firebase Auth administration, which are outside the MongoDB-only Admin path. Do not commit .env, service credentials, or other secrets.

## Tests

Run npm run check from backend; the test command explicitly targets test/*.test.js and src/*.test.js so temporary scripts and non-test files are not auto-discovered.
