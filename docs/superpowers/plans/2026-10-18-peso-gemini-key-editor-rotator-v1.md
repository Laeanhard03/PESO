# Implementation Plan — PESO Admin Gemini API Key Editor and Bounded Rotator

**Date:** 2026-10-18  
**Workspace:** `C:\Users\Admin\Desktop\Prototype`  
**Design:** `docs/superpowers/specs/2026-10-18-peso-gemini-key-editor-rotator-v1.md`  
**Status:** Awaiting separate user approval on the live board. Implementation has not started.

## Objective and done test

Add the approved Admin-only Gemini key manager and a single bounded rotator used by the active local Express endpoints. Full key material is accepted only over authenticated HTTPS/local API input, encrypted in MongoDB with AES-256-GCM, decrypted only in backend memory for an upstream call, and never returned or logged. Fail over across distinct keys for timeout/network, transient 5xx, or verified key-specific credential errors, with a strict maximum of three attempts. Stop on 429/RESOURCE_EXHAUSTED and respect retry guidance rather than rotating around quota limits.

Verified baseline (2026-10-18): Flutter tests 53/53; backend `npm run check` 36/36; live `/api/health` reports MongoDB connected, Firebase token verification ready, roles in MongoDB, database `peso_jobkonek`; unauthenticated `GET /api/admin/users?limit=1` returns 401.

## Preflight and scope protection

Before any implementation begins:
1. Re-read live board and task notes; verify the active project path and API health.
2. Capture hashes and repository status/diffs for each target file. Preserve all current user/peer edits and backups; never replace a large shared file from a truncated read.
3. Coordinate if a peer is currently modifying a shared target. Use existing guarded edit/backup flow.
4. Use built-in Node `node:test` and injected/mock providers. Automated tests must never call Google.
5. Never print/read `.env` values into output, commit credentials, test a real key automatically, change Firebase Functions or deploy.
6. Do not install dependencies unless current source/test investigation proves this necessary.

## Phase 1 — Encrypted key vault (TDD)

**Files:** new `backend/src/gemini-key-vault.js`, new `backend/src/gemini-key-vault.test.js`.

1. Write failing tests first for AES-256-GCM encrypt/decrypt round trip, unique 12-byte IVs, 16-byte auth tag, AAD bound to record ID and schema version, tamper/wrong-AAD/wrong-version/malformed-ciphertext rejection, missing or invalid secret rejection, and proof that stored/public JSON contains no plaintext.
2. Run the tests and verify RED for the intended assertions.
3. Implement pure vault helpers using Node built-in crypto. `GEMINI_KEY_ENCRYPTION_SECRET` must decode from documented base64 to exactly 32 random bytes. Never derive it from `FILE_LINK_SECRET`, Mongo URI, or a Gemini key.
4. Add strict key/label validation and masked-suffix metadata helpers. Reject control chars/newlines and out-of-range inputs; do not silently rewrite internal key characters.
5. Verify focused tests GREEN, `node --check`, and read back the complete new files.

## Phase 2 — Bounded rotator (TDD)

**Files:** new `backend/src/gemini-key-rotator.js`, new `backend/src/gemini-key-rotator.test.js`, provider adapter helper only if required.

1. Add failing tests with injected provider, clock and delay; no live network.
2. Classify provider outcomes using status and structured reason codes: success, timeout/network, transient 5xx, key-specific invalid credential, quota 429, permanent bad request/content error. A generic 403/project-permission failure must not automatically quarantine a key.
3. Select enabled keys not under cooldown or `attention_required`; fairly advance a persisted round-robin cursor with atomic MongoDB operations. Verify installed driver return semantics. Distinct requests may concurrently use the same key; one request must never retry the same key ID.
4. Cap at **3 provider attempts total per request**. Each attempt is time-bounded; delay/backoff is short and bounded.
5. Timeout/network/transient 5xx and verified key-specific invalid credentials can mark that key cooling/quarantined and attempt another distinct eligible key. Persist only safe error categories and timestamps.
6. For 429/RESOURCE_EXHAUSTED, stop on the first attempt, honor bounded `Retry-After`/provider retry guidance, mark cooldown, and return a safe 429. Never rotate to another key in the same request for quota exhaustion.
7. Permanent input/content errors stop without rotation. Exhaustion returns generic safe 502/503 plus request ID.
8. Verify RED→GREEN: first-key success, timeout/network failover, transient 5xx failover, invalid-key quarantine then distinct-key success, all-key failure, disabled/cooling keys skipped, three-attempt ceiling, no repeated key, 429 single attempt/no alternate selection, permanent 400 single attempt, fair selection, and no secret in errors/log metadata.

## Phase 3 — Mongo records and Admin API (TDD)

**Files:** `backend/server.js`, new `backend/test/gemini-key-routes.test.js`, and Phase 1/2 helpers.

**Mongo collections**
- `geminiApiKeys`: `_id`, label, masked suffix, ciphertext, IV, auth tag, format/key version, enabled/health/cooldown state, last-used/tested times, safe last error category, server-derived created/updated actor UID and timestamps. Never store plaintext or provider response bodies.
- `geminiKeySettings` singleton: `managedPoolActivated` and round-robin cursor/version. Set activation permanently on the first successfully saved managed key. Removing/disabling all managed keys must not silently reactivate `GEMINI_API_KEY`.
- Optional safe audit events contain action, record ID, actor UID, timestamp and sanitized result only.

1. Add failing tests for missing/invalid Firebase token (401), non-admin Mongo role (403), Mongo/encryption unavailable (503), list secrecy, create/replace validation, enable/disable, deletion, test-key one-attempt behavior using a mock, audit metadata, and no plaintext/ciphertext in public responses.
2. Extend Express Mongo test fixtures minimally for the new collections; preserve current admin middleware and role checks.
3. Add routes with exact guard order `requireAuth`, `requireAdmin`, `requireMongo`:
   - `GET /api/admin/gemini-keys`
   - `POST /api/admin/gemini-keys`
   - `PUT /api/admin/gemini-keys/:id`
   - `PATCH /api/admin/gemini-keys/:id/status`
   - `DELETE /api/admin/gemini-keys/:id`
   - `POST /api/admin/gemini-keys/:id/test`
4. Validate ObjectId, label/key sizes, booleans, body allowlist and request limits. Never accept UID/role/actor from the request body. Return metadata only—never ciphertext, IV, tag, or full key.
5. The Test Key endpoint uses a fixed, harmless prompt and one upstream attempt without failover. Automated tests inject a mock and make no provider request. If the SDK cannot enforce a token cap, document that limitation and use the least-cost supported request.
6. Run focused route tests; do not create a real key or call Google.

## Phase 4 — Integrate active Express AI routes (TDD)

**Files:** `backend/server.js`, new `backend/test/gemini-ai-routes.test.js` and existing helper/rotator tests.

1. Write failing regression tests for `POST /api/ai/profile` with mocked provider: preserve payload limits, resume attachment allowlist, safe profile JSON, Mongo updates, and sanitized failure responses.
2. Write failing tests for `POST /api/ai/query`: auth required, prompt validation, safe output `{ok:true,text:string}`, public-service system instruction, and bounded timeout/error response.
3. Implement one provider adapter using existing `@google/genai`; remove the existing inline same-key retry loop to prevent nested retry loops multiplying attempts.
4. Keep profile extraction schema, sensitive-ID omission and file handling unchanged. Add `/api/ai/query` because `PesoApiClient.queryAi` already calls it but the Express server currently has no matching route.
5. Use legacy `GEMINI_API_KEY` only before `managedPoolActivated` is true. After activation, if no managed keys are eligible, return unavailable with retry guidance; never silently fall back to a legacy key that an Admin thought was removed.
6. Keep `/api/health` compatible; expose only non-sensitive readiness/count status, if needed.
7. Run focused AI tests and all backend checks.

## Phase 5 — Config generation and documentation

**Files:** `backend/configure-backend-admin.ps1`, `backend/.env.example`, `backend/ADMIN_API.md`, `backend/LOCAL_ADMIN_SETUP.md`, focused `backend/test/local-setup-safety.test.js` additions.

1. Add cryptographic generation of a 32-byte base64 `GEMINI_KEY_ENCRYPTION_SECRET` in the setup helper and validate decoded size. Never echo the generated value or include it in error text.
2. Preserve existing hidden Mongo URI input and all valid unrelated env fields. Back up the existing `.env` through the established secure-backups flow before any edit; never print contents, replace blindly, or regenerate the DB URI as a side effect.
3. Add only a placeholder to `.env.example`. Document backup/loss consequences and that changing the encryption secret without planned re-encryption makes stored keys unavailable.
4. Tests must validate script parsing, placeholder content, preservation of unrelated settings, and absence of secret output. Recheck the live board and guarded command safety immediately before modifying actual `.env`; that live configuration write is not included in plan approval unless the approved step explicitly describes it.

## Phase 6 — Flutter Admin adapter and UI (TDD)

**Files:** `lib/peso_services/peso_api_client.dart`, new `lib/peso_ui/Admin/gemini_api_key_management_section.dart`, `lib/peso_ui/Admin/admin_ui.dart`, new `test/gemini_api_key_management_section_test.dart`.

1. Define an injectable/fakeable Dart management API interface; default adapter calls typed `PesoApiClient` methods. Tests must not require Firebase/network.
2. Add typed client methods for list/create/replace/enable-disable/delete/test. Key plaintext may only exist in transient request body and live form controller; never persist locally or echo it in exceptions.
3. Write failing widgets tests first at 360/768/1366 widths for loading/empty/error/success, add/replace, input masking, form-clearing, toggles/reload, delete confirmation, explicit Test Key cost/quota confirmation, response sanitization, and navigation.
4. Add a protected Admin tab/section. List metadata only (masked suffix, label, enabled and health state, cooldown, last use/test, safe last error category, created/updated time). Environment fallback is read-only and status-only. Never prefill existing values. Clear secret controllers after success, cancel and dispose.
5. Test Key must display a cost/quota warning and make exactly one upstream call only after affirmative user confirmation. Do not click it during automated or unattended verification.
6. Run focused widget tests, then full Flutter tests.

## Phase 7 — Verification, live checks, and rollback

1. Run focused vault, rotator, key-route and AI-route tests; then `cd backend && npm run check`, focused Flutter key-section test, `flutter test --no-pub`, `flutter analyze --no-pub`, and `flutter build web --release`.
2. Inspect every changed file's hash/diff; inspect whole new files and changed portions of shared files. Run `git diff --check` if Git is available. Search only source/tests/docs for committed key literals or secret leaks; never scan/print `.env` contents.
3. Live verification, only when safe: health remains green; no-token key-list request returns 401; tests verify regular-user 403; mocked tests verify admin operations. Use a real provider only when an Admin explicitly confirms Test Key in the UI, not during deployment/tests.
4. Preserve previous file backups. If code regresses, restore only the affected source files from verified backups; never overwrite current `.env`, Mongo data, or peer edits. Managed pool activation stays authoritative after first managed key; disable keys rather than silently falling back. Losing the encryption secret means keys cannot be decrypted; restore secure backup or request a separately reviewed migration.

## Explicitly out of scope

No Firebase Functions/Secret Manager edits or deployment, no Firebase Auth/session/SMS changes, no Atlas account/IP/database changes, no production deployment, no database deletion/migration, no automatic real Gemini calls, no quota evasion, and no edits to unrelated agent task files.

## Plan self-review and approval boundary

- [ ] Targets, APIs, collection schema, and phase sequence are explicit.
- [ ] New behavior starts with failing tests before source implementation.
- [ ] Automated tests use only mock provider calls.
- [ ] All secret routes verify Firebase identity, MongoDB role and DB readiness.
- [ ] Key material never appears in API responses, logs, UI list state, local storage or source control.
- [ ] 429 stops and respects retry guidance; max attempts is three with no repeated key.
- [ ] Persistent pool activation prevents silent legacy-key fallback after the Admin begins managing keys.
- [ ] Query route gap, env helper/docs, UI, verification and rollback are covered.
- [ ] This plan does not itself authorize production changes; those begin only after separate user approval.
