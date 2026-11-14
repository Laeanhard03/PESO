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

## Admin account management (2026-10-30)

- **Implemented:** The production admin account page lists Firebase Authentication identities joined with MongoDB PESO profiles through the same-origin Node/Express API. The API verifies Firebase ID tokens and authorizes admin operations from the MongoDB admin role.
- **Implemented:** Editing profile details, changing PESO access, and promoting roles remain protected for administrator accounts and the currently signed-in administrator.
- **Implemented:** User Management can delete another account even when its role is `admin`, including the configured bootstrap administrator. The delete button is disabled only for the currently signed-in UID, an empty UID, an account operation already in progress, or an unavailable MongoDB profile store; the target's admin role alone does not disable deletion.
- **Implemented:** The User Management confirmation identifies administrator deletion and states that its Firebase Authentication account, PESO profile, and stored documents will also be removed.
- **Implemented:** The Admin top-bar settings and profile icons navigate to dedicated Admin Settings and My Administrator Profile pages. Settings displays session/security information and links to Profile and sign-out. Profile displays the Firebase identity and provides a confirmed `Delete your account` action.
- **Implemented:** `DELETE /api/admin/users/:uid` deletes another account; `DELETE /api/account/me` is the self-service administrator deletion route. Both use the shared server-side deletion routine: revoke PESO access, scrub private MongoDB profile fields, delete the Firebase Authentication user through Firebase Admin SDK, and remove owned GridFS documents. A failed Firebase deletion leaves a retryable pending tombstone; incomplete document cleanup remains visible to another administrator for retry. A self-deleting admin is signed out after Firebase deletion is confirmed.
- **Safety behavior:** Self-deletion is intentionally not available from the User Management row. The current administrator uses My Profile instead. A non-admin cannot call the self-deletion endpoint, and an administrator cannot delete a different account through the self endpoint.
- **Locally verified:** Backend admin-route tests cover deleting another admin, deleting the bootstrap admin by a different admin, self-deletion, rejecting non-admin self-deletion, and retry after Firebase or GridFS cleanup failure. Flutter tests cover Settings/Profile actions, destructive confirmation, and the account-action policy that permits deleting another admin while retaining edit/access restrictions.
- **Deployment boundary:** Source changes are committed to `main` and automatically deploy through the existing `peso` Vercel project. Live authenticated acceptance still requires an owner-account test with a disposable administrator account; no real administrator account is deleted during automated tests.

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

## Admin Development Notepad (2026-11-11)

- Implemented in source: A shared Admin-only Development Notepad for bug reports, improvements, and development tasks, integrated into the existing Flutter Admin navigation.
- Implemented in source: MongoDB-backed notes with title/description, type, priority, assignee, tags, initial and editable checklists, comments, activity history, archive/restore, and revision-based conflict protection.
- Implemented in source: Checklist completion derives the parent status (fixed for bugs; implemented for improvements/tasks). Reopening checklist items moves the note back to in_progress or open.
- Implemented in source: Screenshot upload, private GridFS storage, admin-only inline retrieval, and removal. Accepted formats: JPEG, PNG, WEBP, GIF; 5 MB per image and up to 10 screenshots per note. Shared note screenshots intentionally do not use applicant metadata.ownerUid, so deleting an administrator account does not purge shared team evidence.
- Implemented in source: The Flutter view polls every 20 seconds while the search field is empty, applies local successful changes immediately, and reloads after stale-revision conflicts.
- Locally verified: New backend regression suite backend/test/admin-development-notes.test.js passes 9/9, including admin-only authorization, create/list data, automatic status transitions, stale-write rejection, comments, private screenshot upload/read/delete, archive/restore, and validation.
- Locally verified: Full backend suite passed with MongoDB deliberately isolated to 127.0.0.1:1 and automatic job synchronization disabled. Targeted Flutter analysis completed with zero errors/warnings; informational lints remain. Admin navigation and workspace responsive tests passed.
- Not yet verified: Production MongoDB behavior, authenticated browser acceptance with multiple real administrator sessions, production deployment, and Vercel failover behavior. No commit, push, or deployment is implied by these local checks.


## Vercel pause and failover diagnosis (2026-11-12)

- **Confirmed in the owner's Chrome session:** Vercel project yey10/peso; production app domain https://peso-psi.vercel.app/; production deployment peso-fzkg7yeee-yey10.vercel.app (commit c035ef2, branch main, marked Ready before the pause).
- **Pause cause:** The Vercel dashboard states the team exceeded the Hobby fair-use limit for **Fluid Active CPU**, paused November 11, 2026, with a displayed pause end date of December 11, 2026. This is not the CDN bandwidth limit the user initially suspected.
- **HTTP verification:** The custom production domain, both listed production deployment URLs, and multiple preview deployment URLs returned HTTP 402 (Payment Required) during the November 12 check.
- **Scope:** The pause banner is team-level and is also shown on other projects in the yey10 team. A second deployment URL in the same team is not an independent failover target.
- **Other connected Vercel account:** The ferrerajoshlander-1268 team currently lists no projects through the connected Vercel account. No separate active PESO deployment was found.
- **Architecture constraint:** A client-side redirect in web/index.html cannot handle this pause because the Vercel edge returns HTTP 402 before delivering HTML/JavaScript. The vercel.com/yey10/peso URL is the project dashboard, not a second public app URL. The existing *.vercel.app hostname cannot be rerouted by code inside the paused project.
- **Not performed:** No Vercel redeployment was attempted, no project was transferred, no push/merge to main was made, no DNS or domain ownership was changed, and no billing-plan/payment change was made. The independent Render deployment source was pushed only to deploy/render-failover.
- **Next requirement:** Supply a genuinely independent, working PESO app URL or authorize an independent host. Render integration is connected. The local failover source and render.yaml are committed and pushed on deploy/render-failover. The only listed Render workspace is My Workspace, and user confirmation is pending before any service is created. Before live failover, validate MongoDB Atlas connectivity, Firebase Admin credentials, allowed CORS origins, Firebase authorized domains, and the unchanged Go inference runtime on the fallback host.
- **Deployment status:** Failover remains **not implemented/live** until the independent entry point and backup app/API origin are configured and externally verified.


## Final local web bundle verification (2026-11-12)

- **Passed:** Flutter production web build after the Development Notepad integration (flutter build web --release --no-pub --no-wasm-dry-run).
- **Passed:** React NSRP/resume production build (npm run build --prefix react_workspace -- --base=/nsrp/) and copied the generated Vite output into build/web/nsrp.
- **Verified:** build/web/index.html exists, build/web/nsrp/index.html exists, and the compiled Flutter bundle contains the Development Notepad label.
- **Boundary:** This is a local production bundle only. It has not been pushed to GitHub or deployed to the paused Vercel team.


## Independent Render failover preparation (2026-11-12)

- Implemented in source: an external-origin failover middleware checks both the primary Vercel page and its /api/health endpoint. It only returns traffic to Vercel when the page is healthy, MongoDB is connected, and required feature flags are present.
- Implemented in source: Render fallback sessions are pinned with a secure, HttpOnly session cookie; API requests are never redirected. The fallback serves the existing Flutter bundle, React NSRP/resume workspace, and Express API from one same-origin web service.
- Implemented in source: /healthz reports readiness only when the MongoDB connection and GridFS bucket are available. The Render health check uses this endpoint.
- Implemented in source: the Vercel /api/health response advertises adminDevelopmentNotes so the gateway does not redirect users to an older Vercel build that lacks the Admin Development Notepad.
- Implemented in source: render.yaml defines a Free Singapore web service on branch deploy/render-failover, builds the existing Flutter and React applications, and disables automatic public-PDF background re-reading to avoid duplicating CPU-heavy work on the backup.
- Locally verified: failover-router unit tests cover healthy-primary redirects, Vercel 402 fallback, MongoDB readiness, required feature gates, API bypass, session pinning, cache behavior, network failure, and invalid/unset primary URLs. New failover and Notepad backend tests pass 18/18.
- Locally verified: the full backend suite passes 298/298 with MongoDB isolated to 127.0.0.1:1 and automatic job synchronization disabled.
- Not yet done: the Render Blueprint is created and its first sync is planned, but no Render service has been applied; no production secrets have been copied; no MongoDB Atlas allowlist or Firebase authorized-domain change has been made; no Vercel deployment has been triggered. The deploy/render-failover branch is pushed to GitHub.
- Required before deploy: confirm the Render workspace (the only listed workspace is My Workspace), provide the existing server-side environment values through Render's secret fields, allow Render outbound IPs in MongoDB Atlas, and add the new Render hostname to Firebase Authentication authorized domains.
- Availability caveat: Render Free web services spin down after 15 minutes idle and take about one minute to wake; they also have a monthly 750 free instance-hour workspace limit. This is a no-cost backup, not an always-on service.


- **Local smoke-test note:** A brief local Express startup loaded the existing backend/.env because an empty MONGODB_URI did not override dotenv. Startup ran the existing idempotent ensureJobFeedIndexes routine, which creates five named job/application indexes if absent. No applicant, job, or application records were written. The process was stopped. Future local smoke tests use a non-empty isolated MongoDB URI.


## Credential discovery for Render deployment (2026-11-12)

- **Local files found:** root .env, backend/.env, backend/.env.example, and a Firebase Admin service-account JSON file referenced by backend/.env. The service-account JSON exists, parses correctly, contains a private key, and its project_id matches capstone-4th-year-peso-ai. It can be base64-encoded for Render without displaying or committing the private key.
- **Local MongoDB URI:** the local backend/.env URI connects to the peso_jobkonek database, but backend/MONGODB_BACKEND_SETUP.md explicitly warns that the previous connection string was exposed in chat and instructs the owner to rotate the Atlas database user's password. Do not copy this URI into Render; retrieve the current Vercel Production value through the owner account or use a newly rotated least-privilege Atlas URI.
- **Local file-link secret:** backend/.env contains the documented REPLACE_WITH_RANDOM_SECRET placeholder and must not be reused. The Render Blueprint now uses generateValue for FILE_LINK_SECRET and PESO_EXPORT_SECRET so Render creates independent stable secrets.
- **Gemini managed pool:** a read-only MongoDB audit confirmed managedPoolActivated=true, two enabled Gemini key records, and both records decrypt successfully using the local GEMINI_KEY_ENCRYPTION_SECRET. Both records are currently in cooling_down state with expired cooldown timestamps; the app can retry them. GEMINI_API_KEY is therefore not a required Render secret while the managed pool remains active. No database documents were changed.
- **Admin identity:** the local INITIAL_ADMIN_EMAIL matches an existing MongoDB admin account.
- **Required Render manual values after reducing the Blueprint:** MONGODB_URI (freshly rotated/current production value), FIREBASE_ADMIN_SERVICE_ACCOUNT_B64 (from the validated local service-account file), INITIAL_ADMIN_EMAIL (validated against MongoDB), and GEMINI_KEY_ENCRYPTION_SECRET (validated against both encrypted MongoDB key records).
- **Vercel access:** the browser is signed into the correct laeanhard03 account and shows the Production variables. The Vercel MCP connector's linked accounts do not own team yey10. A Vercel CLI device-auth flow is waiting for owner approval so the production MONGODB_URI can be retrieved using the supported CLI path. Device code was shown in chat for owner approval; no Vercel environment values have been changed.


## Vercel Secret retrieval and MongoDB credential safety (2026-11-12)

- Vercel CLI authenticated as laeanhard03, team yey10; local repo linked to existing project yey10/peso. .vercel/ and .env.local are ignored by Git.
- Production env audit: 15 Vercel Production environment records were listed. MONGODB_URI, FIREBASE_ADMIN_SERVICE_ACCOUNT_B64, INITIAL_ADMIN_EMAIL, FILE_LINK_SECRET, GEMINI_API_KEY, and GEMINI_KEY_ENCRYPTION_SECRET exist as sensitive Secret-type variables. Vercel's current API returns decrypted=false for the sensitive records, and the CLI reports that 13 Secret values cannot be pulled. No secret values were extracted or printed.
- Firebase Admin: local service-account JSON exists, parses, has a private key, and matches Firebase project capstone-4th-year-peso-ai.
- Admin identity: local INITIAL_ADMIN_EMAIL matches an existing MongoDB admin record.
- Gemini encryption: read-only MongoDB audit passed. geminiKeySettings.managedPoolActivated=true; two enabled geminiApiKeys records are present; both decrypt successfully with local GEMINI_KEY_ENCRYPTION_SECRET. Both are in cooling_down with expired cooldown timestamps. No database documents were modified.
- MongoDB credential warning: local backend/.env MONGODB_URI connects successfully but is not safe to reuse because backend/MONGODB_BACKEND_SETUP.md says the prior connection string was exposed in chat and must be rotated. No password rotation was recorded in prior project history. Do not copy the local URI into Render.
- Blueprint reduced to four manual variables: MONGODB_URI, FIREBASE_ADMIN_SERVICE_ACCOUNT_B64, INITIAL_ADMIN_EMAIL, GEMINI_KEY_ENCRYPTION_SECRET. Render generates FILE_LINK_SECRET and PESO_EXPORT_SECRET; no standalone GEMINI_API_KEY is required while the managed key pool remains active.
- Latest pushed branch commit: a3ffe13 Prepare Render secrets and credential-safe failover. Render Blueprint re-plan succeeded with this commit and still proposes one Free Singapore web service only.
- Remaining blocker: create or rotate a MongoDB Atlas database user to obtain a fresh URI for the backup. The MongoDB Atlas login page is open in Chrome but not authenticated. No Atlas account changes have been made.

## 2026-11-12 - Render failover live

- Created and deployed `peso-jobkonek-failover-jlf-2026-tlgb` on Render Singapore Free; service ID `srv-dbqbn6142hec73cvcotg`; Blueprint `exs-dbqanl08v5cc739k9jq0`.
- Pushed `4687ddb` on `deploy/render-failover`. Fixed production build omission of Vite by adding `--include=dev` to the React workspace `npm ci` command in `scripts/vercel_install_flutter.sh`.
- Added dedicated Atlas user `peso_render_failover` with `readWrite` on `peso_jobkonek` only; no existing DB users changed. Configured Render's MongoDB, Firebase Admin, admin-email, Gemini encryption, and generated file/export secrets. Added Render hostname to Firebase Auth authorized domains.
- Added Render Singapore shared egress ranges `74.220.52.0/24` and `74.220.60.0/24` to Atlas. Kept existing `0.0.0.0/0` for Vercel Hobby dynamic egress; network allowlist therefore remains broad and is a known follow-up hardening item.
- Verified `/healthz` reports database ready; `/api/health` reports MongoDB connected, Firebase token verification ready, Gemini configured, and `adminDevelopmentNotes` enabled. `/` and `/nsrp/` return HTTP 200; unauthenticated `/api/jobs` and `/api/admin/users` return HTTP 401.
- At verification time Vercel primary returned HTTP 402 while the Render backup returned HTTP 200. Vercel was not modified.
- React tests 17/17 passed, ESLint passed, production NSRP bundle passed. Render Free cold-start delay remains expected after inactivity.
## 2026-11-01 ? Job-seeker matching robustness audit (isolated review branch)

- Used **read-only** MongoDB access to inspect 326 active job records: 81 hiring notices and 244 currently model-eligible, visible roles (one additional non-notice record is excluded from the current eligible feed). No real applicant record or application was read or modified.
- Tested five **fictional** candidate profiles against all 244 eligible roles using the shipped Go occupation model, in bounded batches. No-skill entrant: 244 low-confidence outputs and no scores >=50; retail novice: 59 scores >=90; office applicant: 83; trades: 14; food service novice: 58. Scores are career-category similarity, **not qualification accuracy**.
- Root causes: 132 roles lack safely attributable employer qualifications; low-confidence category similarities sometimes score 100/100; the frontend previously displayed these as `100% Match` and feedback could incorrectly congratulate or discourage seekers. Existing Go inference CLI truncates each invocation to 30, so a single all-jobs call omitted most roles.
- Isolated implementation: a neutral `needs_review` feedback outcome for uncertain evidence, explicit verification wording, non-probabilistic badges, discovery inclusion without eligibility claims, and API-side bounded batches to retain the current Go model while evaluating **every** role. No model retraining or production writes.
- Verified on the development workstation: 244 unique roles returned from one API-level call in about 1.6 s; targeted backend and Flutter regressions passed; full Flutter suite 263 passed. Full backend suite passes with explicit expected test bootstrap admin and Go paths.
- **Evaluation limitations:** no human-verified employer-qualification labels, real candidate outcome labels, or prospective hiring outcomes; synthetic held-out F1 cannot establish real matching performance. Production changes require dedicated acceptance review and release; branch is not deployed.

## 2026-11-01 ? Continued Mini-AI career-discovery improvement

- Continued the same isolated matching branch after the initial audit; no new trained
  model artifacts or replacement versions were created.
- Added a transparent post-model career rank (direct fields, controlled portable
  skill links, and explicitly advertised trainee/helper titles). The score from
  the trained Go model stays unchanged; the discovery rank never claims
  eligibility. A verified mandatory gap remains a warning, not an auto-rejection.
- Integrated ranking with the authenticated job-recommendations flow, visible
  job-feed ordering and badges, and alternative-job feedback. Unverified Gemini
  claims, demographic facts and raw applicant-provided skill text are not
  introduced as recommendations.
- Read-only DB evaluation on 326 active records and 244 model-eligible visible
  roles: 9 beginner training pathways, 95 retail, 110 office, 27 construction,
  and 87 food-service positions with at least one career-discovery signal.
  These figures are *candidate exploration signals*, not validated matches
  and not equivalent to real-world accuracy or confirmed vacancies.
- The existing model, database, applicant records and production deployment are
  unchanged. Acceptance on the real signed-in job-seeker screen and expert
  evaluation of employer requirements remain necessary before production rollout.

## 2026-11-12 ΓÇö Vercel primary restored; Render failback verified

- New primary: **https://peso-jobkonek.vercel.app** (Vercel project **peso-jobkonek**, owner **ferrerajoshlander-1268**).
- Production deployment **dpl_DPXLeUbUwgmJ8VGjqjFt59fV8HUW** is **READY**, built from **deploy/render-failover** commit **3758dfe81dd8dff3f58692fdae727972d7d73434**.
- Configured 11 Vercel Production variables, including a new Atlas **peso_vercel_primary** credential with **readWrite** only on **peso_jobkonek**, Firebase Admin credential, Gemini encryption key, and canonical public API URL. No secret values are included here.
- Firebase Auth authorized domain **peso-jobkonek.vercel.app** added; previous domains preserved. Atlas AI-client App Connections access was disabled after provisioning and verified Off after reload.
- Vercel **/api/health** HTTP 200: MongoDB connected, Firebase token verification ready, Gemini configured, Development Notepad enabled. **/** and **/nsrp/** HTTP 200. Anonymous protected jobs/admin routes return 401.
- Render **/healthz** and **/api/health** HTTP 200. Render root and **/nsrp/** redirect to the new Vercel primary when healthy; API requests stay on Render. Prior fallback test confirmed Render serves when Vercel returns 402. Local failover-router tests: 9/9 pass.
- Legacy **peso-psi.vercel.app** remains HTTP 402; use **peso-jobkonek.vercel.app**.
- Read-only admin identity check passed (verified Google Firebase account, matching MongoDB UID, admin role, active account). Authenticated admin API acceptance remains pending the owner-approved read-only check; no applicant test data or application writes were made in production.
- Known hardening item: Atlas still retains the broad **0.0.0.0/0** access-list rule for Vercel dynamic egress. Do not remove until a stable/private Vercel egress path is available.
- Existing uncommitted worktree changes were preserved; no reset, commit, push, or production data mutation was performed.

## 2026-11-12 ΓÇö Authenticated production administrator acceptance passed

- Owner-approved read-only check used a temporary Firebase custom token for the existing verified Google administrator. Firebase Admin verified the exchanged ID token and confirmed its UID matches the existing administrator record before API calls.
- Production GET checks: /api/jobs?limit=1 **200** (1 record); /api/admin/jobs?limit=1 **200** (1 record); /api/admin/development-notes?limit=1 **200** (0 notes); /api/admin/users?limit=500 **200** (13 users, source firebase_auth+mongodb, matching administrator UID and role); /api/admin/applications?limit=1 **200** (1 record).
- All responses returned ok=true and the expected production CORS origin. **5/5 passed; zero failures.**
- Read-only only: no applicants created, no production records edited/deleted, no Privacy Notice acknowledgement submitted, and no temporary token written to disk or printed.
## 2026-11-14 - Implementation in progress; checklist intentionally open

- Continued the existing PESO project in place; no replacement project or parallel prototype was created.
- Shared Admin Development Notepad: exactly 2/14 checklist entries completed (verified administrator account and Admin session-restoration regression fix). The remaining 12 entries are implementation work in this pass; their statuses remain open for independent developer verification after implementation.
- Applied local changes across NSRP Form 1 alignment/validation, resume photo gating, password policy, administrator presence, job image upload/validation, and job-card layout consistency.
- Verification: backend 305/305; React 25/25, ESLint passed, Vite build passed; Flutter 270/270; focused Admin restoration 5/5.
- Flutter release web build passed and includes the React NSRP workspace at build/web/nsrp. Flutter analyzer reports zero errors/warnings and 104 info-level lints.
- Known build note: Vite reports the main JS bundle at approximately 736 kB before gzip; build still succeeds.
- No commit, push, Vercel deployment, or Render deployment was performed. The 12 open checklist items remain intentionally unchecked while their implementations are completed for subsequent peer verification.
- NSRP reference: https://aritao.gov.ph/wp-content/uploads/2020/09/NSRP_Form1-2020.pdf


## 2026-11-14 - Implementation continuation after source synchronization

- Fast-forwarded deploy/render-failover from 72d6482 to 3758dfe after preserving the prior local worktree in a retained stash. Restored the local changes and resolved overlapping files without discarding either the newer upstream work or the local implementation.
- The 12 remaining Admin Development Notepad checklist entries are being implemented in this pass and remain unchecked for subsequent independent developer verification.
- NSRP browser E2E: all official required fields completed; under-18 submission blocked; exact age-18 submission accepted; two-page PDF exported; Flutter bridge payload emitted; saved form reopened and prefilled; mobile selection remained stable; no JavaScript errors.
- Signature pointer regression: mouse and touch single-tap, ink capture, and clear all passed.
- Native keyboard selection: desktop, tablet, and phone widths passed; desktop NSRP PDF export passed.
- Resume photo gate fixed and browser-verified: export disabled until a verified applicant portrait exists; applicant name/email prefill correctly; no sample-name warning or JavaScript errors. Failed replacement upload preserves the previous verified photo.
- Change Password now enforces the shared 8-character, uppercase, and special-character policy in the account dialog, displays the complete requirement, and distinguishes missing current password from mismatched confirmation.
- Backend: 325/325 tests passed. React: 25/25 passed; ESLint and Vite build passed. Flutter: 287/287 passed.
- Flutter analyze --no-fatal-infos passed with 105 info-level findings, zero warnings, and zero errors.
- Flutter release web build passed. React NSRP/resume workspace copied to build/web/nsrp; both root and nested index files verified. Vite's 733 kB pre-gzip main chunk warning is non-fatal.
- Read the new Admin Development Notepad report `bug fixes ilaya` and reviewed its attached mobile screenshot. Implemented both unchecked items locally: responsive saved-document cards, wrapped header pills, and validated Go Mini-AI field-similarity percentages with an explicit non-hiring-probability tooltip. Added regression tests across 320/360/390/560/768/1366px and score evidence gating. Both new bug checkboxes and note status remain unchanged.
- No commit, push, Vercel deployment, or Render deployment was performed.

## 2026-11-14 - Deployment result and acceptance boundary

- Commit e30a5b2 pushed to deploy/render-failover. Vercel production READY on e30a5b2; /api/health, /api/public/jobs, and /nsrp/ returned HTTP 200. Production bundle string checks confirmed the field-similarity percentage, admin presence, job/company image uploads, strong password policy, NSRP Form 1, verified-photo gate, and removal of the legacy sample-name warning.
- Render failover remains healthy but is still on 9dc1718. Service auto-deploy is configured for commits, but no Render deployment event appeared after the push. Health endpoints return HTTP 200; failover code synchronization and production acceptance remain open. No manual redeploy was forced.
- Read-only admin audit: 7 distinct admin emails resolve to verified Firebase Auth accounts; marcelinoedward4@gmail.com is already an active verified Google admin. One extra MongoDB profile is a stale duplicate old UID for an already-active email; no data cleanup performed.
- Original checklist: 2/14 complete, 12/14 unchecked. Additional bug note bug fixes ilaya: both items implemented, both unchecked. No Admin Notepad statuses were changed.
- Agent 1 MCP server and primary tunnel client are running and health-checked on 8765 and 8766.

## 2026-11-14 - Render failover synchronized and production smoke-tested

- Supersedes the preceding stale-Render deployment note. Vercel primary and Render failover now both run deploy/render-failover commit 4939dd63e7f6882040482ec18b1771cb5eda1abd. Vercel deployment dpl_35K5vUWkfG41GEynUB9EGZsHLvCe READY; Render deployment dep-dbrqrbbl550s73eiirdg LIVE.
- Render auto-deploy did not create a deployment after the branch push. After confirming no automatic deploy existed and verifying the exact branch/commit, a manual deployment was started. Render checked out the correct commit, built successfully, and activated the new instance.
- Both hosts: /api/health HTTP 200 with MongoDB connected to peso_jobkonek; /api/public/jobs HTTP 200 with 30 jobs; /nsrp/ HTTP 200. Render /healthz HTTP 200.
- Both deployed asset bundles contain field-similarity percentage UI, Admin presence, job image/company logo uploads, strong password policy, September 2020 NSRP Form 1, verified-resume-photo gate and accessible requirement; legacy sample-name warning absent.
- Render build: Flutter web compilation passed; NSRP export guard passed (two original sheets); React 25/25 passed; ESLint passed; Vite build passed. Non-fatal Vite chunk warning: 733.35 kB before gzip. npm audit reports one low-severity dependency vulnerability; no broad upgrade applied.
- Full local tests: backend 325/325, React 25/25, Flutter 287/287; Flutter analyze --no-fatal-infos passed with 105 info-level findings, zero warnings/errors.
- Agent 1 MCP 127.0.0.1:8765 healthy/authenticated; tunnel UI 127.0.0.1:8766 HTTP 200.
- Original checklist remains 2/14 completed, 12/14 unchecked. Additional bug note bug fixes ilaya remains open, both items unchecked. No checklist/status fields modified.
- 11 feature items and both additional bug items implemented and deployed. The seven-admin read-only production API access matrix has passed on Vercel and Render using ephemeral custom-token sessions for existing UIDs. Independent peer acceptance of real human administrator sign-in/role persistence remains open.
- marcelinoedward4@gmail.com is an enabled, verified Google administrator. Read-only audit: 7 distinct verified/enabled admin identities across 8 MongoDB profiles; one duplicate stale old-UID profile left untouched.
- Git commit 4939dd6 was the previous live baseline on both hosts. The original worktree stash remains retained. Unrelated untracked files were not staged. Later release and verification outcomes are recorded in the dated entries below.


## 2026-11-14 - Backend dependency security patch

- Patched backend lockfile transitive fast-xml-parser to 5.12.1 using npm audit fix. backend/package.json unchanged. Backend tests 325/325 passed; npm audit zero vulnerabilities.
- Commit 2813b528f3de053b1323b88073b2f79f873c3c3f pushed to deploy/render-failover.
- Vercel production dpl_9t54Qphx8vX9KeFyw4j6tjEuCZmg READY on the patch commit.
- Render dep-dbrqvoei0phs73b8bdv0 LIVE on the patch commit; Flutter web compile, NSRP two-sheet guard, React tests and npm audit zero vulnerabilities. This is the sole new Render deployment for this commit; the prior deployment was deactivated.
- Both production hosts smoke-tested after the patch: /api/health HTTP 200 with MongoDB connected, /api/public/jobs HTTP 200 with 30 jobs, /nsrp/ HTTP 200.
- Production Admin access matrix passed for all 7 distinct administrator identities on BOTH Vercel and Render: 7/7 verified/enabled Firebase accounts, 7/7 custom-token exchanges, 7/7 ID-token UID claims matched, 7/7 `/api/profile` responses confirmed matching UID plus `admin` role, and 7/7 protected `/api/admin/development-notes` requests were authorized on each host. The initial QA false negative expected a `localId` field that the Firebase `signInWithCustomToken` REST response does not return; the reusable QA script now validates the ID token `user_id`/`sub` claim. Tokens were ephemeral, not logged or persisted; all seven sign-ins returned isNewUser=false, no Firebase accounts were created, and no account records changed.
- Original checklist 2/14 complete, 12/14 unchecked. bug fixes ilaya 0/2 complete. No checklist or note status changed.


## 2026-11-14 - Final production verification and Admin QA harness correction

- Corrected backend/scripts/qa_live_authenticated_api.mjs to validate the Firebase ID token user_id/sub claim. The signInWithCustomToken REST response does not include localId.
- Corrected authenticated production matrix passed on BOTH Vercel and Render: 7/7 verified/enabled admin identities, 7/7 token UID matches, 7/7 /api/profile role=admin checks, and 7/7 protected /api/admin/development-notes requests authorized per host. Tokens were ephemeral; no user records changed.
- UID reconciliation: all 7 distinct admin emails have a matching MongoDB UID profile and a verified/enabled Firebase Auth account. One duplicate old-UID profile was left untouched. marcelinoedward4@gmail.com is an active verified Google administrator.
- Vercel dpl_9t54Qphx8vX9KeFyw4j6tjEuCZmg READY; Render dep-dbrqvoei0phs73b8bdv0 LIVE; both run commit 2813b528f3de053b1323b88073b2f79f873c3c3f.
- Both hosts: /api/health HTTP 200 with MongoDB connected to peso_jobkonek; /api/public/jobs HTTP 200 with 30 jobs; /nsrp/ HTTP 200. Both deployed bundles contain the intended updated UI features and verified NSRP/resume content.
- Backend fast-xml-parser 5.12.1 patch; npm audit zero vulnerabilities. Tests: backend 325/325, React 25/25, Flutter 287/287. ESLint and Flutter/Vite release builds passed. Flutter analyzer: 105 info-level findings, zero warnings/errors.
- Vite non-fatal main bundle warning: 733.35 kB before gzip. Agent 1 MCP 8765 and tunnel UI 8766 remain healthy.
- Original checklist 2/14 complete, 12/14 unchecked. Additional bug fixes ilaya 0/2 complete. No Admin Notepad statuses were modified. All 11 original features and both new bug fixes implemented and deployed; items remain open for independent peer verification.


## 2026-11-14 - Enhanced read-only Admin production matrix (final)

- Enhanced `backend/scripts/qa_live_authenticated_api.mjs` to use Firebase Admin SDK `verifyIdToken(idToken, true)` for signature, audience/issuer/expiry, revocation and disabled-account verification; verify MongoDB UID + `role=admin`; check CORS preflight and CORS response headers.
- Final run exit code 0: 7/7 verified/enabled Firebase identities; 7/7 matching MongoDB admin profiles; 7/7 custom-token exchanges; 7/7 cryptographically verified matching ID-token UID/email claims; zero unexpected new accounts (`isNewUser=false` for all).
- On BOTH Vercel and Render: 7/7 `/api/profile` role/UID checks; 7/7 protected Admin Development Notepad GET requests; CORS preflight passed (HTTP 204, origin/credentials/GET/Authorization); 7/7 profile CORS responses and 7/7 Admin CORS responses. Zero failures.
- Read-only run only; no account, profile, job, or Notepad data changed. Tokens were neither logged nor persisted. The QA harness is tracked test-only code and is not invoked by the production runtime. At this checkpoint Vercel was READY on commit 3430c4847af4e3fc009ebb7624074eec0a0bea78; Render was LIVE on commit 2813b528f3de053b1323b88073b2f79f873c3c3f.
- Separate peer acceptance of real human administrator sign-in remains open. Admin Notepad remains 2/14 complete and `bug fixes ilaya` remains 0/2; no checklist state was modified.

## 2026-11-14 - Green surface texture implementation

- Created a reusable static texture layer with dark/brand/pale tones; organic contour paths and sparse grain are painted at runtime and ignore pointer input.
- Integrated across public landing/services, jobseeker shared headers and cards, authentication, Admin verification/sidebar, AI onboarding, privacy notice, and readiness/outcome surfaces. Original palette and layout retained.
- Regression coverage added for all tones, disabled mode, and interaction pass-through. Full Flutter suite: **289/289 passed**. Flutter analyzer: **0 warnings, 0 errors**; 105 info-level lints remain.
- Local browser preview at 1440x1000 and 390x844: HTTP 200, zero JavaScript exceptions. Release build outputs include Flutter root and `/nsrp/` workspace; React NSRP tests 25/25 and ESLint pass.
- Production baseline before release: Vercel READY and Render LIVE on `f49b057`. Texture release push/deployment is the remaining step.

## 2026-11-14 - Production release confirmation

- Vercel production: **READY**, deployment `dpl_EApfNH5tWeyWcsh9qRNJXMvNvoRT`, commit `e6f5f6d99ac88e43139269d778a8c3c00b5b1c4b`, alias `peso-jobkonek.vercel.app`. Homepage, public jobs, API health, and `/nsrp/` all return HTTP 200. MongoDB, Firebase verification, and Gemini are ready; desktop/mobile browser smoke has zero JavaScript errors and failed requests.
- Render failover remains healthy on `f49b057` and redirects its root to Vercel while the primary is healthy. Render reports `autoDeploy=yes`, but no deployment event for `e6f5f6d` was created after the push; the backup UI is not yet synchronized. No manual deployment was forced while automatic deployment is enabled.
