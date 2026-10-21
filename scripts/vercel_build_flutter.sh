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

# A browser user's localhost is their own device, not the cloud API. Require
# an HTTPS API origin on production builds instead of silently shipping a loopback fallback.
if [[ "${VERCEL_ENV:-}" == "production" && -z "${PESO_API_BASE_URL:-}" ]]; then
  echo "PESO_API_BASE_URL is required for production; configure it to the backend HTTPS URL." >&2
  exit 1
fi

if [[ -n "${PESO_API_BASE_URL:-}" ]]; then
  API_BASE_URL="${PESO_API_BASE_URL%/}"
  if [[ "${VERCEL_ENV:-}" == "production" && "${API_BASE_URL}" != https://* ]]; then
    echo "PESO_API_BASE_URL must use HTTPS in production." >&2
    exit 1
  fi
  DART_DEFINES+=(--dart-define="PESO_API_BASE_URL=${API_BASE_URL}")
fi

flutter build web --release "${DART_DEFINES[@]}"

# Bundle the existing NSRP form and resume editor inside the Flutter website.
# Vite's nested base keeps assets and its image worker under /nsrp/.
npm run build --prefix react_workspace -- --base=/nsrp/
mkdir -p build/web/nsrp
cp -R react_workspace/dist/. build/web/nsrp/