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
