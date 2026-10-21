# PESO Admin Gemini API Key Editor and Bounded Rotator — Design

**Date:** 2026-10-18  
**Workspace:** `C:\Users\Admin\Desktop\Prototype`  
**Design approval:** User approved design request #7755 in the current ChatGPT turn and explicitly instructed Agent 3 to treat that response as a live-board message; acknowledgement recorded on the board as #7759.  
**Status:** Awaiting user review of this written specification.  
**Implementation status:** Not started. This document does not authorize product-code changes, dependency installation, backend restarts, Firebase Functions deployment, or real Gemini test requests.

## 1. Goal and done test

Add an administrator-managed Gemini API key pool in PESO's existing Admin dashboard and integrate it with the local Node/Express Gemini backend. Administrators can add, label, enable/disable, replace, test, and remove keys without being able to retrieve their full value after submission. For an AI request, the backend must fail over to another distinct enabled key after a bounded timeout, network error, transient upstream error, or key-specific credential/configuration failure. Each request has a strict attempt ceiling and safe user-facing errors.

The change is done when:
- An authenticated PESO administrator can manage key metadata and supply key material in the Admin UI.
- A non-admin, anonymous caller, or forged client role cannot read or mutate key metadata or submit/manage keys.
- MongoDB stores the key material only as authenticated ciphertext; APIs/UI/logs never return or print plaintext keys.
- The currently used Express AI extraction path uses the shared rotator, and the Flutter client's existing AI query call has a working corresponding Express route using that same rotator.
- Mock-provider tests prove failover, cooldown, no duplicate key attempts, max attempts, 429 handling, bad-key handling, and secret non-disclosure without contacting Google.
- Existing Flutter and backend regression suites pass, and the local API health/admin security checks remain green.

## 2. Verified baseline and runtime path

- The local API is `backend/server.js`; it verifies Firebase ID tokens and reads application roles/status from MongoDB. `requireAdmin` checks the MongoDB-backed PESO role after Firebase token verification.
- The current live `/api/health` response was verified as `ok=true`, `mongoDbConnected=true`, `firebaseTokenVerificationReady=true`, `appRolesStoredIn=mongodb`, `databaseName=peso_jobkonek`.
- Recent baseline checks passed: `flutter test --no-pub` 53/53; `backend/npm run check` 36/36.
- `POST /api/ai/profile` currently reads one `GEMINI_API_KEY` from `backend/.env` and retries the same credential up to four times for some transient errors.
- `PesoApiClient.extractProfile` calls `POST /api/ai/profile`. `PesoApiClient.queryAi` calls `POST /api/ai/query`, but the current Express server has no matching route, so the client query path needs to be completed in this feature.
- `functions/index.js` has a separate Firebase Functions gateway using Firebase Secret Manager. The current Flutter calls inspected in this project use the local `PesoApiClient` Express API for the active profile/query methods. **V1 will not modify or deploy Firebase Functions, Secret Manager configuration, or cloud rules.** A future cloud-gateway migration would be a separately reviewed task.

## 3. Admin UI

Add a new `Gemini API Keys` navigation item and an isolated section widget under `lib/peso_ui/Admin/`.

The screen should provide:
- Add key: required label and one-time plaintext input; HTTPS/API boundary sends it only to the authenticated backend. Clear the field after a successful save.
- Replace key: accept a new value and re-encrypt it server-side. Never prefill the existing value.
- Enable/disable: changes whether the key is eligible for selection, without deleting the encrypted value.
- Remove: explicit confirmation, removes ciphertext from the active key collection, and keeps only a metadata-only audit event with no key material.
- Test key: separate confirmation warning that a real request goes to Google and may consume quota or incur charges. At most one small/non-sensitive request, no retries; display pass/fail, sanitized provider category, and timestamp.
- Key state table: label, masked suffix (for example `••••1234`), enabled/disabled, health state, last used, last tested, cooldown expiry, last error category, and created/updated metadata. The server returns metadata only.
- Show the legacy environment key only as a masked, read-only fallback state (configured/missing; optional last four); it cannot be copied, replaced, enabled, or deleted through the UI.
- Accessible loading, save, confirmation, success, empty, and error states; responsive at compact, tablet, and desktop widths.

The frontend must never persist key values to local storage, browser storage, Firebase profile documents, build-time `--dart-define` values, crash reports, analytics, or logs.

## 4. Backend API contract and authorization

All key-management APIs must apply `requireAuth`, `requireAdmin`, and `requireMongo` in that order.

- `GET /api/admin/gemini-keys`: list managed key metadata only; no encrypted or plaintext material.
- `POST /api/admin/gemini-keys`: validate label and key input, encrypt the key, store it, audit safe metadata, and return metadata only.
- `PUT /api/admin/gemini-keys/:id`: replace label and/or key; key changes require a new value and fresh encryption. An empty value never means “keep old key” unless the contract explicitly leaves the field out.
- `PATCH /api/admin/gemini-keys/:id/status`: enable or disable one managed key.
- `DELETE /api/admin/gemini-keys/:id`: remove a managed secret and record a metadata-only audit event.
- `POST /api/admin/gemini-keys/:id/test`: perform one explicitly requested provider test with no automatic provider retries; sanitize all errors and never echo provider response bodies or credentials.

All endpoints return non-sensitive metadata, stable error codes, and generic messages. Missing/invalid admin identity gets 401/403; missing Mongo or encryption configuration fails closed with 503. Request bodies have strict key/label size limits. Use server-side ownership and audit identity from the verified token, never a submitted UID or role.

The existing Admin middleware and Firebase/MongoDB access-control model remain authoritative. No endpoint may promote users, bypass `requireAdmin`, or expose credentials to ordinary users.

## 5. Secret storage and configuration

Use a new `backend/src/gemini-key-vault.js` module with Node's built-in crypto:
- AES-256-GCM authenticated encryption for each managed API key.
- A fresh cryptographically random 12-byte IV per encryption, a 16-byte authentication tag, and explicit encryption schema/key version fields.
- A dedicated `GEMINI_KEY_ENCRYPTION_SECRET` supplied only through the ignored `backend/.env`; derive/parse exactly 32 key bytes from a documented format (for example base64 encoding of 32 random bytes). Do not reuse `FILE_LINK_SECRET`, `MONGODB_URI`, or a Gemini key as the encryption key.
- Authentication associated data should bind ciphertext to the managed key record ID and format version so encrypted records cannot be moved between records unnoticed.
- Mongo documents contain label, masked suffix, IV, ciphertext, auth tag, key version, enabled/health/cooldown fields, counters/timestamps, and created/updated-by UIDs. No plaintext or reversible encoding of the API key is stored.
- Decrypt only in backend memory immediately before a provider attempt. Do not log request objects, exception objects, provider response bodies, decrypted keys, or environment values.
- Extend `backend/.env.example`, `backend/configure-backend-admin.ps1` and setup documentation to generate/configure the encryption secret without printing it. Back up the ignored env file through the existing secure local workflow; never overwrite unrelated configuration silently.
- If the encryption secret is absent or invalid, fail closed for managed-key writes/reads that require decryption. Explain that losing the secret renders existing ciphertext undecryptable; retain a secure backup and document how a future planned encryption-key migration would work.

### Legacy key transition

`GEMINI_API_KEY` remains a compatibility fallback while no managed keys have been registered. Once the first managed-key record is saved, the managed pool becomes authoritative; if all managed keys are disabled/unusable, the service returns a sanitized unavailable response rather than silently reverting to a legacy key an administrator thought was removed. The Admin UI reports whether the environment fallback is active but cannot reveal/edit it. A separate migration to import the legacy key into encrypted Mongo storage is not automatic.

## 6. Key selection and bounded failover policy

Add `backend/src/gemini-key-rotator.js`, separated from route handlers and testable with an injected provider function and fake clock/sleep. Every provider attempt receives one distinct key; the same request never retries the same key.

Selection:
1. Obtain enabled, decryptable managed keys not under a temporary cooldown. Choose fairly (round-robin/least-recent-attempt using atomic MongoDB updates so concurrent requests do not all select a single key).
2. Where no managed key has ever been registered, use the legacy `GEMINI_API_KEY` fallback if configured.
3. Maximum of **3 provider attempts per user request** by default, with per-attempt timeout and short bounded exponential delay/jitter. A request can never cycle through the same key twice.
4. Network failure/timeout, HTTP 408, transient 5xx/unavailable/overloaded conditions may cool the attempted key and fail over to a different eligible key until success or the attempt ceiling. A timed-out request may have completed upstream, so duplicate work/quota is possible; the ceiling is mandatory.
5. Key-specific invalid credential or permission errors (for example verified invalid-key/unauthorized classifications) mark that key `attention_required`/quarantined, then may try a different enabled key. Do not persist raw error text.
6. On HTTP 429 or `RESOURCE_EXHAUSTED`, stop immediately, honor the upstream `Retry-After`/retry guidance, record a sanitized cooldown/error category, and return 429 with safe retry information. **Do not rotate to another API key to bypass a provider/project quota, RPM/TPM limit, or billing restriction.** Multiple keys are failover reliability, not quota-evasion.
7. Do not retry permanent bad-input/content errors (most 4xx) against another key. Return a clear safe error.
8. If a request exhausts all eligible keys, return a generic 502/503-style response with an operation/request ID and optional retry guidance. Logs contain only request ID, selected key record ID (not key), attempt number, duration, and a bounded error category.
9. Keep health state visible: ready, disabled, cooling down, attention required, or decrypt/configuration error. Expose no raw provider message.

The rotator will be the single owner of provider retry behavior. Remove/replace the existing inline same-key retry loop so retry layers cannot multiply attempts beyond the configured ceiling.

## 7. Gemini operation integration

- Refactor `POST /api/ai/profile` to invoke the shared rotator. Preserve its current input validation, resume-file rules, profile JSON schema, Mongo profile update behavior, and safe errors.
- Implement `POST /api/ai/query` because `PesoApiClient.queryAi` already expects it. Validate prompt length, use a bounded public-service assistant system instruction, treat the user's text as untrusted input, and return a predictable `{ok:true,text:string}` schema compatible with current app services. It must use the same key rotator, request limit, and safe error policy.
- No key is sent to Flutter. The only configured endpoint is the existing local Express API; do not compile provider credentials into Flutter or route the new admin key API to Firebase Functions in this scope.
- Don't add model/provider switching beyond current `GEMINI_MODEL` unless required to make both existing operations work.

## 8. Testing strategy

Use Node's built-in test runner with mocked/injected provider calls; tests never call Google or send any real Gemini request.

Backend tests:
- AES-GCM encrypt/decrypt round-trip, unique IVs, tamper/AAD/version/invalid-secret rejection, and proof plaintext never appears in stored record or API JSON.
- Every key-management route rejects missing/invalid/non-admin identities and Mongo/encryption-not-ready conditions as appropriate.
- Add/list/replace/enable/disable/remove and audit metadata preserve key secrecy.
- Masking and legacy-fallback status never disclose full key.
- Selection fairness under sequential and concurrent picks; disabled/quarantined/cooling keys are not selected.
- Timeout/network/5xx fail over to a second distinct key; first-key success makes one attempt; invalid key quarantines and can fail over; all-key failure returns generic error; the maximum attempt ceiling is honoured; a key is never repeated within one request.
- 429/RESOURCE_EXHAUSTED produces one attempt only, honors Retry-After, records cooldown, and does not select another key in the same request.
- Permanent input errors do not rotate; no secret appears in logs/error response.
- Profile extraction still validates its payload and saves the expected profile; AI query route validates and returns the expected response shape.

Flutter tests:
- Admin navigation and section render across compact/medium/desktop widths.
- Add/replace fields are obscured and cleared after success; confirmation is required for remove/test; display responses and sanitized state.
- No key plaintext is displayed in listing, errors, or logs; API errors do not create a fake successful state.

Final validation after an implementation plan is separately approved:
- Focused backend tests then `backend/npm run check`.
- Focused Flutter tests then full `flutter test --no-pub`.
- `flutter analyze --no-pub` and `flutter build web --release`.
- Read back changed files and inspect diff/hash.
- Live health remains green. A no-token attempt at key-management endpoints returns 401; a regular authenticated user returns 403. Only a signed-in administrator can add a disposable test key.
- No actual Gemini request occurs in automated tests. The optional Admin-triggered “Test key” action is a real provider call and will be marked as potentially billable/quotad; do not trigger it during unattended validation.

## 9. Out of scope / safety boundaries

- No changes to Firebase Functions, Secret Manager, Firestore/Storage rules, Firebase Auth providers, SMS flow, or account/session architecture.
- No Firebase deployment, cloud deployment, production hosting changes, Atlas user/IP/network configuration changes, or database deletion/migration.
- No credentials in source control, Flutter bundles, test fixtures, screenshots, task notes, or collaboration messages.
- No bypassing Google quota/billing/rate-limit policies by rotating keys; 429 and quota responses respect retry guidance.
- No real provider tests unless the administrator explicitly initiates the UI test action with a warning; automated tests must remain mocked.
- Do not edit `login_ui.dart`, `auth_service.dart`, or other unrelated agent task files for this feature.

## 10. Review checklist

- [ ] User agrees that local Express is the v1 runtime and Firebase Functions stays unchanged.
- [ ] User agrees on AES-256-GCM encrypted Mongo storage with a separate env-backed encryption secret.
- [ ] User agrees that timeouts/transient/key-invalid errors can fail over, but 429/quota exhaustion stops and waits instead of rotating around the limit.
- [ ] User agrees the legacy `GEMINI_API_KEY` env value remains fallback only until the first managed key is registered.
- [ ] User agrees “Test key” requires an explicit confirmation and makes one real provider request that may consume quota or incur usage.
- [ ] User agrees with the API endpoints, UI scope, and acceptance tests above.

Approval of this specification authorizes the next activity only: preparing a separate detailed implementation plan for review. Production code/config edits still require approval of that plan.
