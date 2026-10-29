# PESO JobKonek development setup

This guide is for a fresh clone. It uses the committed lockfiles and does not require production credentials for unit tests or the static web build.

## Toolchain

- Flutter stable 3.47.1 (the version used by the Vercel build script).
- Node.js 22 and npm.
- Go 1.23 or newer for the mini_ai module.
- Git.
- A Firebase service-account file and a reachable MongoDB database are needed only for authenticated local API flows, not for offline unit tests.

## Install dependencies from the repository root

    flutter pub get
    npm ci --prefix backend
    npm ci --prefix functions
    npm ci --prefix react_workspace

Do not run npm install in the repository root: there is no root Node application or root package manifest. Each Node service owns its own package.json and package-lock.json. The Go mini_ai module currently uses only the Go standard library, so go.mod is sufficient and a go.sum is not required.

## Run checks

    bash scripts/ci_flutter_analyze.sh
    flutter test --no-pub
    npm run check --prefix backend
    npm run lint --prefix functions
    npm test --prefix functions
    npm run lint --prefix react_workspace
    npm test --prefix react_workspace
    npm run build --prefix react_workspace -- --base=/nsrp/
    cd mini_ai
    go test ./...
    go vet ./...

The analyzer gate fails on Dart errors and warnings. The current project has an existing backlog of informational lints; these are reported separately so they do not hide real errors or prevent all CI checks from running. Reduce that backlog gradually in focused changes rather than mixing hundreds of formatting edits into feature work.

The dependency-audit job now fails on moderate, high, or critical npm advisories across the backend, Firebase Functions, and React workspace. Firebase Admin 14.5.0 and Firebase Functions 7.4.0 are pinned in the respective lockfiles; the full npm audit currently reports zero vulnerabilities for all three workspaces. The backend requires Node.js 22 or newer to match the current Firebase Admin SDK.

GitHub Actions runs these checks for pushes and pull requests targeting main. Dependency updates are proposed by Dependabot for each tracked package manager and for GitHub Actions. Review and test each update before merging; dependency automation does not silently update the production deployment.

## Local authenticated API setup

1. Copy backend/.env.example to backend/.env.
2. Replace the MongoDB placeholder with a least-privilege URI for the peso_jobkonek database.
3. Place the Firebase Admin service-account JSON in backend/service-account.json or set GOOGLE_APPLICATION_CREDENTIALS to a protected path. Do not commit this file.
4. Set FILE_LINK_SECRET and any required Gemini settings using local-only values. The Gemini provider is optional for core profile storage.
5. From backend, run npm run check and then npm run dev.
6. Verify http://localhost:3000/api/health. The health endpoint reports readiness, not credentials.

The existing desktop launcher can start the local Flutter and React front ends. Its root .env.example is retained only for legacy local helper compatibility; the real API configuration is backend/.env. Production settings remain in the existing Vercel project's server-side environment.

## One-command local stack with Docker Compose

Docker Desktop with Docker Compose v2 is optional. It runs the same Flutter shell, embedded React form, Node API, and a local MongoDB instance without replacing the existing Vercel deployment.

1. Create backend/service-account.json from the Firebase Admin service account for the intended development project. Keep it private and never commit it.
2. Copy docker-compose.env.example to .env.compose.
3. Replace both MongoDB passwords and both signing secrets in .env.compose with unique local-only values. The Mongo application password must be at least 32 alphanumeric characters so it is safe in the URI. Never reuse production credentials.
4. Start the stack from the repository root:

       docker compose --env-file .env.compose up --build

5. Open http://localhost:8080. The Flutter shell is served at the root and the React NSRP/resume workspace is under /nsrp/. The local API is also reachable at http://localhost:3000/api/health.
6. Stop the stack with docker compose --env-file .env.compose down. MongoDB data persists in a named volume. Use docker compose --env-file .env.compose down -v only when you intentionally want to delete that local database.

The web and API ports are bound to loopback only. MongoDB initializes a root account for administration and a separate readWrite-only account for the peso_jobkonek database. The root credentials are for this local container and must never be reused in production. The Compose API disables automatic public-PDF job synchronization to avoid publishing or renewing records as a side effect of starting a development environment. The optional Gemini provider remains unavailable until local Gemini and key-encryption settings are configured.

The Mongo initialization script runs only when the named volume is first created. If you previously ran an older unauthenticated Compose setup with important local data, back up that volume and migrate its users before reusing it; do not delete the volume just to make startup pass. The Firebase service-account file is required for authenticated API flows. The stack should not be used to connect to production MongoDB; Compose supplies its own local database URI. Do not mount a production service-account file into a shared or publicly reachable container.
## Production web build

The single Vercel project builds the Flutter shell, embeds the React forms under /nsrp/, and serves the Express API under /api/. Use scripts/vercel_install_flutter.sh and scripts/vercel_build_flutter.sh as the canonical production build steps. Do not create separate Vercel projects for React or the API.

## Clean-clone acceptance checklist

- All package managers install from their committed lockfiles without modifying those lockfiles.
- Backend, Functions, React, Flutter, and Go checks pass without requiring production secrets.
- The production web build contains build/web/index.html and build/web/nsrp/index.html.
- A configured local API returns its readiness state from /api/health.
- Protected API routes still reject unauthenticated requests.
- No local .env, service-account JSON, or QA credential file is added to Git.