# PESO JobKonek

Flutter + React prototype for the PESO Montalban JobKonek flow. **Firebase Authentication is used for sign-in and identity only.** The authenticated Node.js API uses MongoDB Atlas for user profiles, registration/NSRP fields, AI profiles, preferences and assessment outcomes, and MongoDB GridFS for private resume/document files. The API verifies Firebase ID tokens before reading or writing user-owned records.

## Working notes

- SYSTEM_STATUS.md tracks source features, local test evidence, and what's still required for online production.
- GEMINI_GATEWAY_SETUP.md contains setup notes for the earlier Firebase Function Gemini gateway; the current local desktop data path is documented in backend/MONGODB_BACKEND_SETUP.md.
- ONBOARDING_DATA_SYNC.md and PATCH_README.md document the data-sync integration.
- docs/DEVELOPMENT_SETUP.md documents clean-clone setup, package-manager checks, and CI.
- docs/SECURITY_POSTURE.md explains Firebase client-key handling, server-side credentials, and access-control boundaries.
- compose.yaml and Dockerfiles provide a loopback-only local stack; see docs/DEVELOPMENT_SETUP.md.

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
