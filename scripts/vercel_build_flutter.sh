#!/usr/bin/env bash
set -euo pipefail

FLUTTER_ROOT="${HOME}/.cache/peso-flutter-sdk/flutter"
if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
  echo "Pinned Flutter SDK missing; run scripts/vercel_install_flutter.sh first." >&2
  exit 1
fi
export PATH="${FLUTTER_ROOT}/bin:${PATH}"

# The NSRP and resume screens are bundled inside this Flutter website.
# GitHub main pushes deploy this one frontend through the peso Vercel project.
# Relative workspace URL follows the current preview or production domain.
DART_DEFINES=(
  --dart-define=PESO_NSRP_WORKSPACE_URL=/nsrp/
)

# This single Vercel project serves both Flutter and the Express API.
# Use the browser's current HTTPS origin for /api requests in production and
# preview deployments. Never use a stale external backend environment value.
# Local, non-Vercel builds may still override the API for development.
if [[ -z "${VERCEL_ENV:-}" && -n "${PESO_API_BASE_URL:-}" ]]; then
  DART_DEFINES+=(--dart-define="PESO_API_BASE_URL=${PESO_API_BASE_URL%/}")
fi

flutter build web --release "${DART_DEFINES[@]}"

# Bundle the existing NSRP form and resume editor inside the Flutter website.
# Vite's nested base keeps assets and its image worker under /nsrp/.
npm run build --prefix react_workspace -- --base=/nsrp/
mkdir -p build/web/nsrp
cp -R react_workspace/dist/. build/web/nsrp/