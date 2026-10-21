# PESO JobKonek

Flutter + React prototype for the PESO Montalban JobKonek flow. **Firebase Authentication is used for sign-in and identity only.** The authenticated Node.js API uses MongoDB Atlas for user profiles, registration/NSRP fields, AI profiles, preferences and assessment outcomes, and MongoDB GridFS for private resume/document files. The API verifies Firebase ID tokens before reading or writing user-owned records.

## Working notes

- SYSTEM_STATUS.md tracks source features, local test evidence, and what's still required for online production.
- GEMINI_GATEWAY_SETUP.md contains setup notes for the earlier Firebase Function Gemini gateway; the current local desktop data path is documented in backend/MONGODB_BACKEND_SETUP.md.
- ONBOARDING_DATA_SYNC.md and PATCH_README.md document the data-sync integration.

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
