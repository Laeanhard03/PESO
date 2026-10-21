# PESO JobKonek ? Functionality and Verification Status

Last review: 2026-10-16

**Status labels:** **Implemented, not live-verified** means source/configuration is present but the deployed service or real data path has not been tested. **Locally verified** means the named local test/build passed. **Demo/mock** means the screen is illustrative or changes remain local/in-memory and should not be described as production functionality.

## Authentication, profiles, and documents

- **Implemented, not live-verified:** Firebase Authentication integration for email/password and Google sign-in; email password reset; account profile creation and profile persistence. Phone numbers are optional profile data only; SMS authentication is removed.
- **Implemented, not live-verified:** Firestore user profiles under users/{uid}, profile editing, saved preferences, resume/NSRP form intake, AI profile fields, and assessment outcomes.
- **Implemented, not live-verified:** Firebase Storage uploads and per-user artifact metadata for PDF/JPEG/PNG documents. The actual project bucket, deployed rules, and a real upload/download round trip still need testing.
- **Implemented, not live-verified:** Firestore and Storage rule files are present. Confirm their deployed versions and test cross-user isolation before production.
- **Removed:** The mistaken end-user notepad UI and its Firestore read/write methods are removed. The intended feature is this functionality/verification note, not an in-app personal notepad.

## Admin security gate and images

- **Implemented in source; Firebase verification pending:** AdminDashboard stays locked until either a fresh Firebase email/password sign-in or verification of the already-authenticated Firebase session succeeds and a refreshed ID token contains the `admin: true` custom claim. A missing claim denies access. Admin logout signs out of Firebase. The `admin/admin` debug shortcut only opens the lock screen and cannot bypass this blocker.
- **Implemented:** `lib/assets/josh.png`, `edward.png`, and `cesneros.png` are registered as Flutter assets and mapped to Josh Lander Ferrera, Edward Marcelino, and John Paul Cesneros on the Project Developers cards. Lovely Anne C. Ilaya uses initials until a matching named photo is supplied; unrelated placeholder portraits were removed.
- **Implemented in source:** Network images share a cache manager configured for a 365-day stale period and 500 cached objects. On native builds, a background preloader downloads the app's built-in public images in small batches after startup. The Flutter web app registers `web/peso-image-cache-worker.js`, which pre-caches built-in public imagery and caches later public cross-origin image requests, excluding token/signed-URL query strings. The separate React workspace has its own registered worker at `react_workspace/public/peso-image-cache-worker.js` for the resume-builder portrait set and subsequent public image requests.
- **Locally verified:** Flutter analyze passes with 27 info-level style/deprecation lints, both Flutter widget tests pass including the Admin security gate, React lint/build pass, and both image-worker scripts pass `node --check`. **Not yet verified end-to-end:** Confirm offline image rendering in a browser after each service worker activates and on a native target after images download. A first-ever visit still needs a connection to fetch remote imagery; bundled developer photos are always local. Browser storage can be cleared or evicted by the platform.
## Gemini service and credential security

- **Implemented, not live-verified:** Firebase Functions v2 geminiGateway source with server-side GEMINI_API_KEY Secret Manager binding. The app source no longer bundles .env or secrets.json and no longer uses the old source-coded AES key.
- **Implemented, not live-verified:** Firebase ID-token verification, request validation, 8 MB overall JSON request limit, supported PDF/JPEG/PNG attachment validation, per-user application request limit of 20 requests per rolling hour, and bounded retry/backoff for transient network/502/503/504 errors.
- **Implemented, not live-verified:** Profile-extraction and generic query operations; model instructions are separated from untrusted user content.
- **Policy:** Gemini 429 quota responses are returned with retry guidance. The gateway does not rotate coworkers' personal API keys or switch projects to evade project-level quota limits.
- **Not done:** No API key was created, read, published, or inserted by this task. The cloud function was not deployed and no live Gemini request was made. Revoke any old key that may have been stored with the old client-side cipher; deleting it from the latest source does not remove historic Git blobs.
- **Not yet verified:** Production origin allowlist, Secret Manager setup, billing, App Check, quota/cost alerts, live auth rejection, usage limits, transient retry behavior, and live profile extraction/query responses.

## Admin registered-user management

- **Implemented in source; deployment/live test pending:** The admin account page now uses paginated Firebase Authentication user records joined with profile fields.
- **Implemented in source; deployment/live test pending:** Callable functions require the verified Firebase Authentication custom claim `admin: true`. The deployed admin UID must be explicitly configured; a Firestore profile role alone is not sufficient. User-facing clients cannot set their own custom claim.
- **Implemented in source; deployment/live test pending:** Edit name/email/phone/location/education/employment/title/bio; disable or enable a job-seeker account; permanently delete a job-seeker auth account and attempt to clean its Storage prefix and Firestore document tree.
- **Safety behavior:** The current administrator cannot delete or edit their own account from this screen. Accounts with the admin role/custom claim cannot be edited or deleted through these endpoints. Role changes are intentionally excluded from the edit payload.
- **Local UI-only preview:** Flutter debug runs accept username admin and password admin only to open the Admin security gate. Firebase verification is still required before any Admin tab appears; the shortcut creates no Firebase session and is disabled in release builds.
- **Not yet verified:** These admin functions require deployment before they can be called. The existing administrator must have the Firebase Authentication custom claim `admin: true`. Run the one-time claim script only from a trusted workstation with credentials authorized to administer the project. No real account has been edited, disabled, or deleted as part of the source implementation. Deletion can return a cleanup warning if Cloud Storage or Firestore cleanup fails; review audit logs if that happens.

## UI areas that still contain demo or in-memory behavior

- **Demo/mock:** Applicant KPIs, candidate records, concerns/feedback, job-ingestion batch history, DOLE SPRS export, and several platform analytics values are seeded or simulated in the current admin UI. The visible toast for generating an Excel export is not proof an Excel file was written; the handoff action is local state.
- **Demo/mock:** Some job-feed/matching values shown by the UI may come from local samples rather than live marketplace queries. Verify each source before treating displayed counts as real production metrics.
- **Locally verified:** The React workspace lint and production build pass after registering the resume-builder public-image worker. The build retains a Vite advisory that the largest JavaScript chunk is about 680 kB.
- **Known build note:** The React production build previously warned that the main JavaScript bundle exceeded Vite's 500 kB advisory threshold. That warning is a performance optimization concern, not proof the build failed.

## Still required before production

1. Rotate any Gemini key previously exposed by the old client-side key flow.
2. In a trusted terminal, set GEMINI_API_KEY interactively with firebase functions:secrets:set GEMINI_API_KEY; do not put it in source, .env, command arguments, chat, or GitHub.
3. Set GEMINI_MODEL and GEMINI_ALLOWED_ORIGINS to approved values in the ignored project-specific Functions parameter file.
4. Confirm Firebase project ownership, plan/billing, enabled APIs, budgets and quota expectations; deploy Functions only after that review.
5. Deploy the current Functions and Firestore/Storage rules. Confirm that the intended administrator has the Firebase Authentication custom claim `admin: true`, then test list/edit/disable/enable/delete on a disposable test account.
6. Run the app's auth, profile, React bridge, artifact upload/download, gateway and deletion flows against the deployed Firebase project.
7. Replace/complete mock admin analytics, concerns, ingestion, export and job-feed data paths before presenting them as live operational functions.
8. Review AI consent, resume-processing notice, retention/deletion behavior, monitoring and billing alerts.

## Recent local verification record

Verified locally on 2026-10-16 after the admin-gate and offline-image-cache changes:

- **Passed:** `functions`: `npm test` (16/16 tests), `npm run lint`, and module export checks for `geminiGateway`, `adminListUsers`, `adminUpdateUser`, and `adminDeleteUser`. The gateway and Flutter client timeouts now allow the bounded three-attempt upstream retry window.
- **Passed:** `flutter analyze --no-fatal-infos` after the admin/cache edits (27 info-level style/deprecation lints remain; no errors or warnings were reported).
- **Passed:** `flutter test` (2/2 widget tests, including the Admin Firebase security-gate test).
- **Passed:** Fresh `flutter build web --release --no-wasm-dry-run` after the security-gate and image-cache changes; the built output contains `peso-image-cache-worker.js` and the three named developer portraits.
- **Passed:** `git diff --check` for task-owned changes when excluding the pre-existing, out-of-scope `watcher.ps1` edit.
- **Passed:** targeted source scan found no legacy notepad references or old cipher-key marker in tracked source. Both image-worker scripts pass `node --check`, and both workers were copied into their respective built web outputs. No files named `.env`, `secrets.json`, service-account key, or PEM files were found in the earlier fresh Flutter web output. Browser offline integration is still pending.
- **Not done:** No Firebase Functions deployment, live Gemini request, admin-claim grant, real-user edit/deletion, Firestore rules deployment, or Storage test was performed. These require separate production/project verification.
- **Environment note:** Local Node was v25.2.1 while `functions/package.json` targets Node 22. Unit/lint checks passed locally; use Node 22 for deployment/runtime parity.

A local pass does not establish that Firebase Functions, Gemini, Authentication providers, Firestore, or Storage are deployed and working online.