# PESO JobKonek

Flutter + React prototype for the PESO Montalban JobKonek flow. **Firebase Authentication is used for sign-in and identity only.** The authenticated Node.js API uses MongoDB Atlas for user profiles, registration/NSRP fields, AI profiles, preferences and assessment outcomes, and MongoDB GridFS for private resume/document files. The API verifies Firebase ID tokens before reading or writing user-owned records.

## Working notes

- SYSTEM_STATUS.md tracks source features, local test evidence, and what's still required for online production.
- GEMINI_GATEWAY_SETUP.md contains setup notes for the earlier Firebase Function Gemini gateway; the current local desktop data path is documented in backend/MONGODB_BACKEND_SETUP.md.
- ONBOARDING_DATA_SYNC.md and PATCH_README.md document the data-sync integration.
- docs/DEVELOPMENT_SETUP.md documents clean-clone setup, package-manager checks, and CI.
- docs/SECURITY_POSTURE.md explains Firebase client-key handling, server-side credentials, and access-control boundaries.
- compose.yaml and Dockerfiles provide a loopback-only local stack; see docs/DEVELOPMENT_SETUP.md.

## Explainable JobKonek career discovery

JobKonek uses **two complementary stages** rather than treating one AI score
as an employment decision:

1. The existing Go/ISCO-08 Mini-AI compares independently saved job-relevant
   NSRP/resume evidence with career categories and, where supported, each
   employer's attributable requirements. Unattributed vacancy notices must
   not create mandatory qualifications. Gemini may help with intake/explanations,
   but cannot invent qualifications or re-score a role.
2. The authenticated API adds an evidence-aware, transparent **career-discovery
   rank** using shared career fields, controlled transferable-skill relationships
   and explicitly named trainee/helper/apprentice roles. Every signal retains a
   reason, uncertainty, and any requirement gaps. This rank is NOT hiring
   probability, candidate eligibility, or a substitute for human review.
   Incomplete profiles may receive cautious training suggestions; all other
   published openings remain discoverable regardless of ranking.

The UI prioritizes supported career directions and labels uncertain results
as exploration paths. It never converts the discovery rank into a misleading
percentage match. The Go inference result is retained separately for audit.
The full job feed is evaluated in bounded batches rather than truncating to
the Go CLI's top 30 outputs.

**Evaluation:** Run Node tests in backend, Flutter tests at the root, and
read-only synthetic-applicant comparisons against active job listings (do not
create applicants or submit applications). Synthetic agreement is not real-world
matching accuracy. No model promotion should occur without human-verified
role requirements and applicant-outcome evaluation.

## Repeated job-seeker experience checks (development branch)

The matching development branch includes an automated test that plays **20
fictional job-seeker profiles** through **12 simulated openings**, repeated
**20 times** (400 profile runs; 4,800 role checks). Applicants include
people with no work history, apprentices, retail/food/office beginners,
technical workers changing careers, people with an explicit skills gap,
Tagalog/Taglish skill descriptions, and people with unrelated skills.

The tests check that the same facts produce the same results, protected
personal details do not affect ranking, beginners can explore relevant
training roles, unrelated jobs are not falsely promoted, and employers'
known requirements are not silently treated as met. They also check
that every job remains available and no misleading hiring percentages,
promises, or automatic disqualifications appear in the main advice.
The job-check dialog has phone/tablet/desktop and larger-text tests.

Feedback is intentionally short: **why this job, what to check next, and
whether the applicant can still apply**. Employers and PESO make
qualification decisions. The independent live-data audit previously
processed 244 eligible role records using only synthetic applicants;
synthetic tests do not establish real hiring outcomes or user
comprehension. Run the PR #15 checks and perform a signed-in review with
human readers before production release.

## Application data and AI backend

The primary desktop/local development path is the authenticated Node API in
backend/. It owns the MongoDB/Atlas and GridFS data path; Firebase is not the
profile/document database. Gemini credentials stay server-side and must never be
embedded in Flutter, React, .env examples, or committed files.

Follow backend/MONGODB_BACKEND_SETUP.md to configure the API and local
dependencies. The setup guide explains the required MongoDB URI, private
Firebase Admin credential file (used only to verify auth tokens/read legacy
profile data), local health checks, and the optional Gemini provider. The
launcher starts the API only when the local configuration, dependencies, and
credential file are present and its health endpoint confirms dependencies are
ready. It never generates credentials, prints .env values, or deploys cloud
services.

GEMINI_GATEWAY_SETUP.md documents the earlier Firebase Function gateway path;
use it only for that legacy/deployed integration, not as the source of truth for
profile/onboarding/outcome/document persistence. SYSTEM_STATUS.md,
ONBOARDING_DATA_SYNC.md, and PATCH_README.md retain related historical and
feature notes. No live backend deployment is performed by the desktop launcher.

## Windows desktop app-mode launcher

To open JobKonek in a separate desktop-style Edge window, double-click
`launch_peso_desktop.bat` from the project root (or run it from File Explorer).
The launcher starts or reuses only the verified local services required by this
project, waits for both to respond, and then opens the Edge app window.

Prerequisites are Flutter on `PATH`, Node.js/npm, the already-installed
`react_workspace/node_modules` packages, and Microsoft Edge. The launcher does
not install packages, call `dev.bat`, edit `.env`/Firebase settings, or change
global Git configuration.

- Flutter Web shell: `http://127.0.0.1:5237/`
- Embedded NSRP form: `http://localhost:5173/`
- Embedded resume builder: `http://localhost:5173/resume`
- Launcher state: `%LOCALAPPDATA%\PESOJobKonek\launcher-state.json`
- Service logs: `%LOCALAPPDATA%\PESOJobKonek\logs\`

All launcher services bind to loopback only. The optional MongoDB API uses
port 3000 when configured; the Flutter shell uses 5237 and the React forms use
5173. If an enabled port is occupied by a process the launcher cannot verify as
belonging to this exact project, launch stops without terminating or adopting
that process. Review the port owner and the relevant log before trying again;
do not kill broad process-name matches.

**This is an interim Edge app-mode launcher, not a native Windows `.exe`.**
A native Flutter Windows build still needs the Visual Studio “Desktop
development with C++” workload and a validated native strategy for the embedded
React forms.


## Single-project Vercel deployment

The only public PESO frontend is the Vercel project `peso`, at
`https://peso-psi.vercel.app/`. It connects to `Laeanhard03/PESO` and
publishes pushes to `main` automatically. The GitHub branch `backup/stable`
is a static rollback checkpoint, not a production branch.

The source folder `react_workspace/` is **not** a separate Vercel project:
it provides the NSRP and resume screens embedded inside the Flutter app.
`scripts/vercel_install_flutter.sh` installs Flutter, React and backend Node dependencies;
`scripts/vercel_build_flutter.sh` builds Flutter into `build/web`, builds Vite
with `/nsrp/` as its public base and copies the generated assets into
`build/web/nsrp`. The site serves the forms at `/nsrp/` and
`/nsrp/resume`, with the parent Flutter app as their same-origin host.
The Node/Express backend runs as a Vercel Function in this same `peso` project,
via `api/index.mjs` and the root `vercel.json` route `/api/:path*`.
Production paths are `/` (Flutter), `/nsrp/` (React) and `/api/` (Express).
`PESO_API_BASE_URL` and `PUBLIC_API_BASE_URL` are both the same HTTPS origin.
MongoDB, Firebase service account and Gemini credentials are kept only in the
Vercel project's Production environment, never in Flutter build code or Git.
The Linux Go inference binary and unchanged trained model are shipped under
`backend/mini_ai_runtime/` and loaded into the Function's writable `/tmp`.

Review tests and selectively stage source changes before pushing to `main`.
Do not deploy local QA builds that contain Firebase Auth Emulator flags.

If Vercel does not react to a push, verify the commit author email belongs to
the GitHub account connected to the Vercel Hobby project. Placeholder Git
identities are not reliable deployment authors.

### One-project release check and rollback

1. Commit only reviewed, tested files on `main`, then `git push origin main`.
   The existing Vercel project `peso` follows that branch; no second project
   or manual upload is needed when GitHub webhooks are healthy.
2. In `peso` Deployments, confirm the new Git commit is **Ready** and assigned
   to `peso-psi.vercel.app`. Verify `/`, `/nsrp/` and `/api/health`; unauthorized
   `/api/jobs` and `/api/admin/users` should still respond with HTTP 401.
3. To undo a bad deploy without rewriting Git history, use `git revert <bad-sha>`
   on `main`, re-run tests and push the resulting revert commit. For a series
   of commits, review each change and use an explicit restore commit based on
   `backup/stable` if necessary. Never force-push `main` or automatically move
   the `backup/stable` branch. Uncommitted local changes must be preserved.
4. Backend secrets are configured in **the existing `peso` Vercel project**;
   environment edits require a new deployment. The original
   standalone backend project `peso-jobkonek-api` has been deleted after the live
   same-origin API health and authentication-boundary checks (2026-10-22).
   Do not recreate separate React or backend Vercel projects. Authenticated
   admin and applicant acceptance requires an owner-account browser test;
   an unauthenticated HTTP 401 alone verifies access protection only.


## Admin Development Notepad

The Admin dashboard includes a shared Development Notepad for the PESO programming team. Administrators can record bugs, improvements, and development tasks; assign a programmer; set priority and tags; add step-by-step checklists; attach private screenshots; discuss findings in comments; and archive or restore resolved items. Completing every checklist item automatically marks bugs as Fixed and improvements/tasks as Implemented. The workspace stores notes in MongoDB, screenshots in private GridFS storage, and uses revision checks to prevent concurrent edits from silently overwriting one another. The Admin view refreshes shared notes every 20 seconds when no search term is active. See backend/ADMIN_API.md for the protected API contract.


## Vercel pause and failover status (2026-11-12)

The Vercel dashboard project is yey10/peso; https://peso-psi.vercel.app/ is its production app domain. The dashboard showed the yey10 team paused since November 11, 2026 for **Fluid Active CPU** Hobby fair-use overage (not CDN bandwidth), with a displayed pause end date of December 11, 2026. The public app domain and multiple production/preview deployment URLs returned HTTP 402 (DEPLOYMENT_DISABLED) during the November 12 check. The team-level pause banner was also visible on the team's other projects.

A redirect script served by the paused Vercel deployment cannot recover this outage: Vercel returns HTTP 402 before serving the app's HTML, so browser JavaScript never runs. A second deployment in the same yey10 team is not an independent fallback; the team's deployments are paused together. The Vercel project dashboard URL is not a second application URL.

**Failover is not yet deployed.** No independent working PESO deployment URL was found in the yey10 team's project deployments or the other currently connected Vercel account. A resilient entry point requires an independent host/router and an independently available app/API origin, or moving the project to an eligible active Vercel team. The peso-psi.vercel.app hostname itself cannot be redirected by code inside the paused deployment. Do not claim failover is active until an external entry point and fallback origin are configured and tested.

The Render integration is connected. A local render.yaml now defines a free Singapore web service on the dedicated deploy/render-failover branch, with a same-origin Flutter/NSRP/Express build and an external health-checked failover router. The Render account exposes one workspace named My Workspace; no Render service has been created yet because the workspace must be confirmed. Secret values remain outside Git and must be configured in Render.


## Independent Render backup and failover gateway

The source now includes a Render deployment definition at render.yaml. It is designed as one same-origin Node web service that builds the existing Flutter app and React NSRP/resume workspace, then runs the existing Express API and serves the generated build/web assets. The backup uses the same MongoDB database, Firebase project, and packaged Go matching runtime; it does not create a second database or separate API.

The planned Render service is peso-jobkonek-failover-jlf-2026 in Singapore on the Free plan. Its public entry point will be https://peso-jobkonek-failover-jlf-2026.onrender.com if that service name is available. The service checks both the primary Vercel page and /api/health; it only redirects to Vercel when the site, MongoDB connection, and required adminDevelopmentNotes feature are healthy. Otherwise it serves the Render copy. A session cookie keeps the current browser on the fallback while its Flutter, NSRP, and API requests are in progress. API requests are never redirected.

The required-feature check prevents the gateway from sending users back to an older Vercel build that does not yet contain the Development Notepad. Once the Vercel deployment includes the feature and reports it from /api/health, new browser sessions can automatically return to Vercel.

The Render backup disables automatic public-PDF background re-reading with PESO_SKIP_AUTOMATIC_JOB_SYNC=1; already stored public recruitment data remains available, while the backup avoids duplicating the CPU-heavy scheduled ingestion that contributed to the Vercel team's pause. Manual refresh remains available through the Admin workflow.

Before the first live deploy, configure these server-side values in Render without committing them: a freshly rotated MONGODB_URI, FIREBASE_ADMIN_SERVICE_ACCOUNT_B64, INITIAL_ADMIN_EMAIL, and GEMINI_KEY_ENCRYPTION_SECRET. Render generates independent FILE_LINK_SECRET and PESO_EXPORT_SECRET values. GEMINI_API_KEY is not required when the existing MongoDB managed-key pool is active; the encryption secret must remain identical to the one used for the existing encrypted records. Also allow the Render service's outbound IP addresses in MongoDB Atlas and add the Render hostname to Firebase Authentication's authorized domains.

The Free web service sleeps after 15 minutes without inbound traffic and takes about one minute to wake. Render documents 750 free instance hours per workspace per calendar month. This is a cost-free backup tier, not an always-on production guarantee. The old peso-psi.vercel.app hostname cannot redirect while Vercel returns HTTP 402 before serving application code; once the backup is deployed, users must enter through the new Render URL during the pause. The deploy/render-failover branch has been pushed to GitHub; no Render resource, DNS change, paid plan, or Vercel deployment has been applied yet.


## Production credential discovery and safe Render handoff

The Vercel yey10/peso Production environment has the required database, Firebase Admin, admin-email, file-link, Gemini API, and Gemini encryption variables. These are Vercel Secret-type values. The Vercel API and CLI list their names but explicitly return no decrypted values; Vercel's Secret type is designed not to be readable after saving. Do not try to recover them from deployment logs or expose them through a temporary endpoint.

The local backend/.env MongoDB URI still connects to the existing peso_jobkonek database, but the setup documentation flags the previous URI as exposed in chat. It must not be copied into Render. Create a separate least-privilege MongoDB Atlas database user for Render (readWrite on peso_jobkonek only), or rotate the existing user after all consumers are ready to migrate. Keep the old Vercel credential intact until the new URI is safely configured in Render and Vercel.

A read-only audit confirmed the local Firebase Admin service-account JSON is valid for capstone-4th-year-peso-ai; INITIAL_ADMIN_EMAIL matches the existing MongoDB admin account; and the local GEMINI_KEY_ENCRYPTION_SECRET decrypts both existing encrypted Gemini key records. The MongoDB managed key pool is active with two enabled records; both are currently cooling_down with expired cooldown timestamps and can be retried. No database documents were modified by this audit.

The Render Blueprint generates new FILE_LINK_SECRET and PESO_EXPORT_SECRET values, so they do not need to be copied from Vercel. GEMINI_API_KEY is not required for the Render backup while the MongoDB managed-key pool remains active. The remaining manual Render inputs are MONGODB_URI, FIREBASE_ADMIN_SERVICE_ACCOUNT_B64, INITIAL_ADMIN_EMAIL, and GEMINI_KEY_ENCRYPTION_SECRET.

## Render failover deployment update (2026-11-12)

This section supersedes earlier status notes that described the Render failover as planned or not yet deployed. The failover is now deployed and passed its production smoke checks.

- **Live service:** https://peso-jobkonek-failover-jlf-2026-tlgb.onrender.com
- **Render service:** `peso-jobkonek-failover-jlf-2026-tlgb` (`srv-dbqbn6142hec73cvcotg`)
- **Blueprint:** `exs-dbqanl08v5cc739k9jq0`
- **Region / plan:** Singapore / Free
- **Source:** GitHub `Laeanhard03/PESO`, branch `deploy/render-failover`
- **Deployed code commit:** `4687ddb` (`Fix Render React build dependency install`)
- **Health check:** `/healthz`

### Database and credentials

A dedicated Atlas database user, `peso_render_failover`, was created with `readWrite` access scoped to the `peso_jobkonek` database. Existing administrator and `peso_app_user` accounts were not modified. The Render service uses the same existing Atlas cluster and database; no data migration or second database was created.

The service environment is configured with the MongoDB URI, Firebase Admin service-account credential, existing administrator email, Gemini key-encryption secret, and Blueprint-generated file/export secrets. The Render hostname was added to Firebase Authentication's authorized domains.

Render's Singapore shared outbound ranges (`74.220.52.0/24` and `74.220.60.0/24`) were added to the Atlas IP access list. The pre-existing `0.0.0.0/0` rule was deliberately retained because the Vercel Hobby primary still relies on dynamic egress. Consequently, the network allowlist is not yet restrictive; the database account's database-scoped permissions remain the principal access boundary. Revisit this when Vercel can use static/private egress.

### Build correction

The first Render build reached the React bundle step but failed because `NODE_ENV=production` caused npm to omit Vite, which is a build-time devDependency. `scripts/vercel_install_flutter.sh` now runs `npm ci --include=dev --prefix react_workspace`. This preserves the existing package lock and build flow while ensuring build tooling is installed in Render's production build environment.

### Production verification

- Render build and deployment: **successful / live**
- `/healthz`: HTTP 200; database reports ready
- `/api/health`: HTTP 200; `mongoDbConnected=true`, `firebaseTokenVerificationReady=true`, `geminiConfigured=true`, and `adminDevelopmentNotes=true`
- `/` and `/nsrp/`: HTTP 200
- Unauthenticated `/api/jobs` and `/api/admin/users`: HTTP 401 as expected
- Vercel primary `https://peso-psi.vercel.app/`: HTTP 402 at verification time; Render backup root: HTTP 200, confirming the fallback can serve while the primary is unavailable
- React workspace: 17 tests passed; ESLint passed; production NSRP bundle built successfully

The Render Free instance may spin down after inactivity; its first request after sleep can have a cold-start delay. The Vercel primary remains unchanged.

## Independent Vercel primary deployment (2026-11-12)

- Created the independent Vercel project `peso-jobkonek` under the `ferrerajoshlander-1268` Hobby team. Production domain: `https://peso-jobkonek.vercel.app/`; project dashboard: `https://vercel.com/ferrerajoshlander-1268/peso-jobkonek`.
- Connected GitHub `Laeanhard03/PESO` and set `deploy/render-failover` as the Vercel production branch. The deployed source is commit `9dc1718` (`Merge main into Render failover deployment`) in Singapore (`sin1`). Production is public; preview deployments retain Vercel SSO protection.
- The single-project build publishes Flutter at `/`, React NSRP/resume at `/nsrp/` and `/nsrp/resume`, and the Express API through `api/index.mjs` under `/api/*`. The API function is configured for a 300-second maximum duration.
- Verified from the public production domain: `/`, `/nsrp/`, and `/nsrp/resume` return HTTP 200; `/api/health` returns JSON; unauthenticated `/api/jobs` and `/api/admin/users` return HTTP 401.
- **Backend readiness is incomplete:** the latest `/api/health` check reports `mongoDbConnected=false`, `databaseName=null`, and `geminiConfigured=false`. Vercel Production still needs `MONGODB_URI`, `FIREBASE_ADMIN_SERVICE_ACCOUNT_B64`, `INITIAL_ADMIN_EMAIL`, and `GEMINI_KEY_ENCRYPTION_SECRET`. The current environment already contains `FIREBASE_PROJECT_ID`, `MONGODB_DB_NAME`, `PESO_PUBLIC_PDF_OCR_LANGS`, and `CLIENT_ALLOWED_ORIGINS`.
- `FILE_LINK_SECRET` and `PESO_EXPORT_SECRET` were generated as new shared signing secrets and configured in both Vercel Production and Render. Previously issued signed file/export links may need to be regenerated after this coordinated secret rotation.
- Updated Render's `PESO_FAILOVER_PRIMARY_URL` to `https://peso-jobkonek.vercel.app`. The Render gateway redirects new visitors to Vercel only when the primary page, MongoDB-backed `/api/health`, and required `adminDevelopmentNotes` feature are healthy. Otherwise it serves the Render fallback. Use the Render service URL as the independent entry point; a failed Vercel deployment cannot redirect requests that go directly to its own unavailable hostname.
- **Credential safety:** do not reuse the old `backend/.env` MongoDB URI; the previous URI was exposed and must be rotated. Configure a fresh least-privilege Atlas URI for `peso_jobkonek`. The Firebase Admin service-account JSON and Gemini encryption secret were validated locally; transfer them to Vercel through its Production environment settings without pasting secrets into chat.
- **Release gate:** after the remaining Production variables are configured, redeploy Vercel and require `/api/health` to report MongoDB connected and Gemini configured. Then verify that the Render gateway returns HTTP 302 to Vercel when healthy and serves the Render copy when Vercel is unhealthy.

## Vercel environment follow-up (2026-11-12)

- `INITIAL_ADMIN_EMAIL` is now configured in Vercel Production and matches the existing MongoDB admin account.
- `FILE_LINK_SECRET` and `PESO_EXPORT_SECRET` are configured as sensitive Production variables in Vercel and synchronized to Render using the same newly generated values.
- The remaining Vercel Production blockers are exactly: `MONGODB_URI`, `FIREBASE_ADMIN_SERVICE_ACCOUNT_B64`, and `GEMINI_KEY_ENCRYPTION_SECRET`.
- The current Vercel production deployment for commit `bcebfaa` is Ready. Public checks: `/`, `/nsrp/`, `/nsrp/resume`, and `/api/health` return HTTP 200; unauthenticated `/api/jobs` and `/api/admin/users` return HTTP 401.
- Latest Vercel API health remains `mongoDbConnected=false`, `databaseName=null`, `geminiConfigured=false`; Render remains healthy with MongoDB, Gemini, and `adminDevelopmentNotes` enabled. The Render gateway therefore correctly continues to serve the backup until Vercel's database-backed health check passes.

## Vercel primary activation and dual-host recovery (2026-11-12)

This section supersedes the earlier Vercel-pause deployment status for the new **peso-jobkonek** project. The legacy **peso-psi.vercel.app** project remains paused and returned HTTP 402 during the final check. Use the new production hostname below.

### New production primary

- **Primary URL:** https://peso-jobkonek.vercel.app
- **Vercel project:** **peso-jobkonek** (project ID **prj_sgDlHa6OgqMfpIFVKHcMRHhxi7kS**), owner/team **ferrerajoshlander-1268**
- **Production deployment:** **dpl_DPXLeUbUwgmJ8VGjqjFt59fV8HUW** ΓÇö **READY**
- **Deployed source:** GitHub **Laeanhard03/PESO**, branch **deploy/render-failover**, commit **3758dfe81dd8dff3f58692fdae727972d7d73434** (Align Render gateway with Vercel primary)
- **Build:** successful; React NSRP tests 17/17 passed; ESLint passed; Flutter and NSRP production bundles built successfully.

### Production environment and database

- Configured 11 Production environment variables in the new Vercel project. Sensitive values are stored as Vercel secrets and are not recorded in this file.
- Added a dedicated MongoDB Atlas account, **peso_vercel_primary**, with **readWrite** limited to **peso_jobkonek**. The existing **peso_render_failover**, **peso_app_user**, and administrator accounts were not changed.
- Added the server-side Firebase Admin service-account payload for **capstone-4th-year-peso-ai**, the existing 32-byte Gemini key-encryption secret, and **PUBLIC_API_BASE_URL=https://peso-jobkonek.vercel.app**.
- Firebase Authentication authorized domains now include **peso-jobkonek.vercel.app**. The prior eight domains were preserved, including the Render failover and legacy Vercel hostnames.
- Atlas AI-client access was temporarily enabled for provisioning, then restricted again. After a page reload the organization setting reported Off, and ChatGPT/Codex CLI entries showed Restricted. This setting affects user-delegated Atlas App Connections, not the application's Atlas programmatic connection.

### Production smoke checks

- **GET /api/health:** HTTP 200; **mongoDbConnected=true**; **firebaseTokenVerificationReady=true**; **geminiConfigured=true**; **features.adminDevelopmentNotes=true**; database **peso_jobkonek**.
- **/** and **/nsrp/**: HTTP 200.
- Anonymous **/api/jobs**, **/api/admin/users**, and **/api/admin/development-notes**: HTTP 401 (missing_bearer_token) as expected.
- Browser smoke: Flutter view loaded at desktop and mobile widths; the first-visit Privacy Notice / Terms tab dialog rendered; no JavaScript errors or failed network requests. The notice was not accepted by automation.
- Read-only administrator identity check: Firebase account exists, email verified, Google provider present; MongoDB user record exists with matching UID and **role=admin**, and is not disabled/deleted. A separate authenticated production admin-API request check remains pending owner approval; no production applicant or application records were created or changed.

### Failover and known limits

- Render backup remains live at https://peso-jobkonek-failover-jlf-2026-tlgb.onrender.com.
- Render **/healthz** and **/api/health**: HTTP 200 with MongoDB, Firebase token verification, Gemini, and **adminDevelopmentNotes** ready.
- With Vercel healthy, Render **/** and **/nsrp/** return HTTP 302 to the new **peso-jobkonek.vercel.app** primary. API and health requests are never redirected. The earlier HTTP 402 outage test verified that Render serves the fallback when the primary is unavailable; the failover-router regression suite passed 9/9 in this final run.
- The legacy **peso-psi.vercel.app** hostname still returns HTTP 402. Do not use it as the new primary URL.
- The Render Free instance can cold-start after inactivity.
- Atlas network access remains broader than ideal because the Vercel Hobby primary uses dynamic egress; the existing **0.0.0.0/0** rule was not changed in this deployment pass. Revisit only when a stable/private egress option is available.
- Existing uncommitted local project work was preserved. This deployment was a redeploy of the recorded Git commit; no Git reset, commit, push, or destructive data operation was performed in this pass.

### Authenticated production administrator acceptance (2026-11-12)

The owner-approved, read-only production acceptance check completed successfully using a temporary Firebase custom token for the existing verified administrator. Firebase Admin verified the exchanged ID token and confirmed its UID matches the existing MongoDB administrator record before any API requests were sent.

All five production GET checks returned HTTP 200 with ok=true and the expected CORS origin (https://peso-jobkonek.vercel.app):

- /api/jobs?limit=1 ΓÇö authenticated job feed returned one record.
- /api/admin/jobs?limit=1 ΓÇö administrator job management returned one record.
- /api/admin/development-notes?limit=1 ΓÇö shared Development Notepad list returned successfully (zero notes at the time of the check).
- /api/admin/users?limit=500 ΓÇö 13 users returned from firebase_auth+mongodb; the existing administrator UID and role=admin were present.
- /api/admin/applications?limit=1 ΓÇö administrator applications read returned one record.

**Result: 5/5 checks passed; zero failures.** The check used GET requests only. It created no applicants, modified no user/job/application records, and did not accept the Privacy Notice on the user's behalf. Temporary Firebase tokens were not written to files or printed.
## Local implementation pass - 2026-11-14 (implementation in progress; checklist intentionally open)

This entry records the local continuation of the shared Admin Development Notepad checklist. It does not replace earlier deployment notes and does not imply a production release.

### Checklist boundary
- Exactly 2 of 14 checklist entries are marked complete: the verified Firebase/MongoDB administrator account and the Admin session-restoration regression fix.
- The remaining 12 entries are implementation work in this pass. They remain unchecked so fellow developers can independently verify the completed implementation afterward, including production acceptance.
- No checklist item is marked complete merely because a local implementation or automated test passed.

### Local changes applied
- Admin dashboard restores an existing Firebase session only after the protected MongoDB Admin API confirms the administrator role.
- Digital NSRP Form 1 follows the September 2020 reference structure and two-page layout, including OFW details, education, vocational training, eligibility, work experience, other skills, certification, and PESO-only referrals.
- Civil status uses a single-select radio group; cellphone input warns on incomplete Philippine mobile numbers; NSRP completion enforces age 18+ in both client and server.
- NSRP signature and date controls are bottom-aligned.
- Email registration and password changes require at least 8 characters, an uppercase letter, and a special character.
- Resume generation requires a verified applicant portrait. The exported applicant resume no longer receives the sample-content warning; a previously verified photo remains usable if a replacement upload fails.
- Admin account list includes Online/Offline presence and refreshes the presence snapshot periodically. Jobseeker sessions send a heartbeat; backend presence is derived from a bounded last-seen window.
- Admin job management supports authenticated JPG/PNG/WEBP company-logo and job-image uploads into private GridFS storage. Images are served publicly only when linked to an active job. Google Photos sharing URLs are rejected.
- Landing and Admin job cards reserve consistent image/content space and use minimum card heights to reduce uneven rows.

### Verification
- Backend npm test: 305/305 passed.
- React NSRP/resume npm test: 25/25 passed; ESLint passed; Vite production build passed.
- Flutter full test suite: 270/270 passed.
- Focused Admin session-restoration tests: 5/5 passed.
- Flutter release web build passed. React output was copied into build/web/nsrp; both build/web/index.html and build/web/nsrp/index.html exist.
- Flutter analyzer: 0 errors, 0 warnings, 104 info-level lint findings remain in the project.
- Vite build emits a non-fatal main JavaScript chunk-size warning (approximately 736 kB before gzip); build completed successfully.

### Peer review and release boundary
- The 12 open checklist entries are being implemented in this pass. They remain unchecked so fellow developers can independently verify the completed work against real accounts, browsers, and deployment targets; they are not delegated implementation tasks.
- No Git commit, push, Vercel deployment, or Render deployment was performed in this pass.
- Production acceptance and failover verification remain pending.

### NSRP reference
- September 2020 NSRP Form 1 reference PDF (LGU-hosted copy): https://aritao.gov.ph/wp-content/uploads/2020/09/NSRP_Form1-2020.pdf


## 2026-11-14 - Implementation continuation after source synchronization

- Fast-forwarded the existing deploy/render-failover branch from 72d6482 to 3758dfe. Preserved the original worktree in a Git stash, restored its changes, and reconciled the overlapping README, status, backend, landing-card, and NSRP-test edits. No local work was discarded; the stash remains retained until final verification.
- Continued the existing 12 open Admin Development Notepad implementation tasks. They remain unchecked for independent developer verification; none are delegated to peers.
- NSRP browser flow passed: 20 required fields initially flagged; all official fields and applicant career basics completed; signature captured; under-18 completion blocked; exact age-18 boundary accepted; two-page PDF downloaded; bridge payload saved; form reopened and prefilled; mobile career selectors retained their values. No browser JavaScript errors.
- Pointer regression passed for mouse and touch: single tap creates signature ink and Clear signature resets the canvas.
- Native keyboard selector regression passed at 1260px, 510px, and 390px. The desktop flow downloaded NSRP_Form1.pdf after all official fields and signature were completed.
- Fixed the resume photo gate: PDF export is now disabled until a verified portrait is available, while a previously verified photo remains usable if a replacement upload fails. The button exposes the photo requirement through aria-describedby.
- Fixed Change Password validation so the account dialog enforces the same shared 8-character, uppercase, and special-character rule as registration and AuthService. The dialog now explains the rule and separately reports missing current password or mismatched confirmation.
- Resume browser check passed: registered first/last name and email prefill correctly, export stays disabled without a verified photo, the old sample-name warning is absent, and no JavaScript errors occur.
- Backend suite: 325/325 passed. React/NSRP/resume: 25/25 passed; ESLint and Vite production build passed. Flutter suite: 287/287 passed.
- Flutter analyze --no-fatal-infos passed with 105 info-level lint findings and no warnings or errors.
- Flutter release web build passed. The latest React workspace bundle is copied into build/web/nsrp; the Flutter root and NSRP workspace indexes are present.
- Vite reports a non-fatal main JavaScript chunk of approximately 733 kB before gzip. Build succeeds.
- Read the new Admin Development Notepad report `bug fixes ilaya` and its attached mobile screenshot. Implemented both unchecked items locally: saved-document cards now use a stacked mobile layout and horizontal tablet/desktop layout with wrapped filenames/actions; shared header pills now wrap safely; validated Go Mini-AI role-attributed field-similarity scores are displayed as percentages with a non-hiring-probability explanation. Added regression coverage at 320, 360, 390, 560, 768 and 1366 logical pixels, plus score-evidence gating tests. The new note's two checkboxes and status were not changed.
- No Git commit, push, Vercel deployment, or Render deployment was performed.

## 2026-11-14 - Deployment result and acceptance boundary

- Commit e30a5b2 was pushed to deploy/render-failover. Vercel production is READY on e30a5b2; live API health, public jobs, and the /nsrp/ workspace returned HTTP 200. The deployed Flutter bundle includes the new field-similarity percentage, admin presence, job/company image upload controls, and strong password policy. The deployed React bundle includes the September 2020 NSRP title and the verified-photo resume gate, with the legacy sample-name warning absent.
- Render failover remains healthy but is still running 9dc1718. Its service reports auto-deploy on commit, but no Render deployment event appeared after the push. The current failover health endpoints return HTTP 200; code synchronization and production acceptance remain open until Render runs e30a5b2. No manual redeploy was forced.
- Read-only administrator audit: 7 distinct administrator emails all resolve to verified Firebase Auth accounts; the requested marcelinoedward4@gmail.com account is already a verified Google administrator. MongoDB has one additional stale profile with an old UID duplicating an active admin email; no user records were modified.
- The original Admin Development Notepad remains 2/14 completed and 12/14 unchecked. The new bug fixes ilaya note still has both items unchecked. No Notepad note, checkbox, or status field was changed.
- Agent 1 MCP server and primary tunnel client are running and health-checked on ports 8765 and 8766 respectively.

## 2026-11-14 - Render failover synchronized and production smoke-tested

This entry supersedes the immediately preceding Render-stale deployment note. It does not change any Admin Development Notepad checklist status.

- Vercel primary and Render failover are both deployed from branch deploy/render-failover at commit 4939dd63e7f6882040482ec18b1771cb5eda1abd. Vercel production deployment dpl_35K5vUWkfG41GEynUB9EGZsHLvCe is READY. Render deployment dep-dbrqrbbl550s73eiirdg is LIVE.
- Render initially did not auto-deploy after the branch push. After verifying the branch, commit and service configuration, a manual deployment was started because no automatic deployment had been created. Render checked out commit 4939dd63e7f6882040482ec18b1771cb5eda1abd, built successfully, and activated the new service instance.
- Both public production hosts returned HTTP 200 for /api/health (MongoDB connected to peso_jobkonek), /api/public/jobs (30 jobs), and /nsrp/. Render /healthz also returned HTTP 200.
- Production asset inspection on BOTH Vercel and Render confirmed: field-similarity percentage UI, Online/Offline Admin presence, job image upload, company logo upload, strong password policy, September 2020 NSRP Form 1 title, verified-resume-photo gate and accessible requirement text; legacy sample-name warning absent.
- Render build verification: Flutter web compilation passed; NSRP export guard confirmed exactly two original sheets; React node test suite 25/25 passed; ESLint passed; Vite production build passed. Non-fatal warnings: Vite's main JavaScript chunk is 733.35 kB before gzip; npm audit reported one low-severity vulnerability in the installed frontend dependencies. No automatic dependency upgrade was applied.
- Local full verification remains backend 325/325, React 25/25, Flutter 287/287; Flutter analyze --no-fatal-infos passed with 105 info-level findings and zero warnings/errors.
- Agent 1 MCP server is authenticated and healthy on 127.0.0.1:8765; primary tunnel client/UI is healthy on 127.0.0.1:8766.
- The original Admin Development Notepad remains 2/14 completed and 12/14 unchecked. The additional bug note bug fixes ilaya remains open with both of its items unchecked. No note, checklist item, or status field was changed.
- The 11 feature implementation items and both additional bug items have been implemented and deployed. The read-only seven-admin production API access matrix has since passed on both hosts using ephemeral custom-token sessions for the existing UIDs. Independent peer acceptance of real human sign-in and role persistence remains a separate open checklist item; no identity records were changed.
- Requested administrator marcelinoedward4@gmail.com is already an enabled, verified Google administrator. Read-only audit found 7 distinct verified/enabled admin identities across 8 MongoDB admin profiles; one duplicate old-UID profile was left untouched.
- Git deployment commit 4939dd6 is live on both hosts. The original local worktree stash remains retained; unrelated untracked local files were not staged. README and SYSTEM_STATUS have been extended locally after deployment; this status addendum is not committed/pushed.


## 2026-11-14 - Backend dependency security patch

- Updated the backend lockfile's transitive fast-xml-parser dependency from 5.11.2 to 5.12.1 through npm audit fix. The backend manifest was unchanged; the package tree was checked and the backend suite passed 325/325. npm audit now reports zero vulnerabilities.
- Commit 2813b528f3de053b1323b88073b2f79f873c3c3f (Patch low-severity XML parser dependency) was pushed to deploy/render-failover.
- Vercel production deployment dpl_9t54Qphx8vX9KeFyw4j6tjEuCZmg is READY on this commit.
- Render deployment dep-dbrqvoei0phs73b8bdv0 is LIVE on this commit and passed its Flutter web compilation, NSRP two-sheet build guard, React tests and npm audit (zero vulnerabilities). It is the sole new Render deployment for this commit; the prior deployment was deactivated after the update.
- Final public smoke tests after the dependency patch: both Vercel and Render returned HTTP 200 for /api/health (MongoDB connected to peso_jobkonek), /api/public/jobs (30 jobs), and /nsrp/.
- Production Admin access matrix passed for all 7 distinct administrator identities on BOTH Vercel and Render: 7/7 verified/enabled Firebase accounts; 7/7 custom-token exchanges; 7/7 ID-token UID claims matched; 7/7 `/api/profile` responses returned the matching UID and `admin` role; 7/7 protected `/api/admin/development-notes` requests were authorized on each host. The first QA attempt was a false negative because the Firebase `signInWithCustomToken` REST response does not return `localId`; the corrected reusable QA script validates the ID token's `user_id`/`sub` claim instead. Tokens were ephemeral and never logged or persisted; all seven sign-ins returned isNewUser=false, no Firebase accounts were created, and no user records changed.
- Original checklist remains 2/14 complete, 12/14 unchecked. Additional bug note bug fixes ilaya remains 0/2 complete. No note/checklist/status field was modified.


## 2026-11-14 - Final production verification and Admin QA harness correction

- Corrected backend/scripts/qa_live_authenticated_api.mjs. Firebase signInWithCustomToken's REST response does not include localId; the QA harness now validates the returned ID token's user_id/sub claim against the Firebase Admin UID, then exercises both /api/profile and the protected /api/admin/development-notes endpoint on both production hosts.
- The corrected read-only production access matrix passed: 7/7 distinct administrator identities verified/enabled, 7/7 token exchanges succeeded, 7/7 token UID claims matched, 7/7 profile responses confirmed matching UID plus role=admin, and 7/7 protected Admin endpoint requests were authorized on BOTH Vercel and Render. No tokens were persisted or logged; no user records changed.
- Admin UID reconciliation: all 7 distinct administrator emails have at least one MongoDB profile matching the Firebase Auth UID; all are verified and enabled. One extra duplicate old-UID profile remains untouched. marcelinoedward4@gmail.com is an active verified Google administrator.
- Vercel deployment dpl_9t54Qphx8vX9KeFyw4j6tjEuCZmg is READY on commit 2813b528f3de053b1323b88073b2f79f873c3c3f. Render deployment dep-dbrqvoei0phs73b8bdv0 is LIVE on the same commit.
- Both production hosts returned HTTP 200 for /api/health with MongoDB connected to peso_jobkonek, /api/public/jobs with 30 jobs, and /nsrp/. Both deployed Flutter bundles contain field-similarity percentage UI, admin Online/Offline presence, job/company image upload controls, and strong-password policy. Both deployed React bundles contain the September 2020 NSRP Form 1 and verified-resume-photo gate; the legacy sample-name warning is absent.
- Backend transitive fast-xml-parser is patched to 5.12.1; npm audit reports zero vulnerabilities. Backend tests 325/325; React tests 25/25; Flutter tests 287/287. ESLint passed. flutter analyze --no-fatal-infos passed with 105 info-level findings, zero warnings/errors. Flutter web and Vite release builds passed.
- Known non-fatal build note: Vite's main JavaScript chunk is 733.35 kB before gzip. No broad dependency upgrade was applied.
- Agent 1 MCP server remains authenticated/healthy on 127.0.0.1:8765; primary tunnel UI remains HTTP 200 on 127.0.0.1:8766.
- Original Admin Development Notepad checklist remains 2/14 completed, 12/14 unchecked. Additional bug note bug fixes ilaya remains 0/2 completed. No checklist item, note status, or bug checkbox was changed.
- All 11 original feature implementations and both additional bug fixes are deployed to both production environments. The remaining 12 original checklist entries and 2 new bug entries are left unchecked for independent peer verification.


## 2026-11-14 - Enhanced read-only Admin production matrix (final)

- Re-ran the corrected QA harness after strengthening it to verify every returned Firebase ID token cryptographically with Firebase Admin SDK (`verifyIdToken(..., true)`), including revocation/disabled-account checks, rather than decoding JWT claims only.
- Result: exit code 0. All 7 distinct admin identities were verified/enabled in Firebase; all 7 matched a MongoDB profile with the same UID and `role=admin`; all 7 ephemeral custom-token exchanges succeeded; all 7 ID tokens passed signature/revocation verification and matched the expected UID/email; `isNewUser` was false for all 7 (zero new Firebase accounts).
- BOTH production hosts passed all 7 `/api/profile` role/UID checks and all 7 protected `/api/admin/development-notes?limit=1` GET requests. CORS OPTIONS preflight passed on each host (HTTP 204, exact allowed origin, credentials, GET method and Authorization header); CORS response headers passed for all 7 profile responses and all 7 protected Admin responses per host. Failures: 0.
- The run performed read-only MongoDB queries, Firebase token exchange/verification, CORS preflight, and authenticated GET requests only. No account/profile/Notepad data was modified; no token was logged or persisted.
- `backend/scripts/qa_live_authenticated_api.mjs` is a tracked test-only harness; it is not invoked by the application runtime and does not change production authentication behavior. At this checkpoint Vercel had already deployed commit 3430c4847af4e3fc009ebb7624074eec0a0bea78, while Render was still running commit 2813b528f3de053b1323b88073b2f79f873c3c3f. The enhanced harness and aligned release record are included in the follow-up commit.
- This verifies API authorization for test sessions representing the existing admin UIDs. It does not replace the separate peer acceptance requirement for each administrator to sign in interactively with their own credentials. Admin Notepad checklist remains 2/14 complete; `bug fixes ilaya` remains 0/2 complete. No checklist state was changed.

## 2026-11-14 - Shared green surface texture treatment

- Added `lib/peso_ui/Reusable_Designs/peso_green_texture.dart`, a shared Flutter CustomPainter overlay with three calibrated tones: dark, brand, and pale. The pattern combines low-contrast organic contour rings and sparse micro-grain; it uses no raster assets, animation, blur, or pointer interception.
- Applied the texture to the shared jobseeker page header, public landing hero and jobs introduction, public PESO services section, scrolled navigation bars, login/registration backdrop, admin verification backdrop and sidebar, privacy-notice header, AI onboarding ambience/orb, job-feed search panel, account profile panel, outcomes cards, and readiness recommendation panels.
- Preserved the existing PESO green palette, typography, logos, control labels, content, and responsive layouts. Rounded surfaces clip the texture to their existing edges; interactive controls remain tappable.
- Added `test/peso_green_texture_test.dart` to verify all three tones, disabled rendering, and button hit testing through the overlay.
- Verification: Flutter tests 289/289 passed; `flutter analyze --no-fatal-infos --no-pub` exited successfully with 105 existing info-level lint findings and zero warnings/errors. Desktop (1440px) and mobile (390px) local browser previews returned HTTP 200 with no JavaScript errors.
- Release build: pinned Flutter 3.47.1 web build passed. React NSRP workspace tests 25/25 passed, ESLint passed, and Vite production build passed with the required `/nsrp/` asset base. `build/web/index.html` and `build/web/nsrp/index.html` are present.
- The pre-change production baseline is Vercel deployment `dpl_3G7fzRAdLoM3Duz5v2sFHyAiKh1W` and Render deployment `dep-dbrrphe1egvs73c2mjc0`, both on commit `f49b057`. The texture changes are locally verified and awaiting the release push.
