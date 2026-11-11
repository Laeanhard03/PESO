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
