#!/usr/bin/env bash
set -euo pipefail

FLUTTER_ROOT="${HOME}/.cache/peso-flutter-sdk/flutter"
if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
  echo "Pinned Flutter SDK missing; run scripts/vercel_install_flutter.sh first." >&2
  exit 1
fi
export PATH="${FLUTTER_ROOT}/bin:${PATH}"

# The React/Vite workspace is deployed independently on peso_aimatching.
# Explicit origin keeps the Flutter-to-React postMessage bridge allowlisted.
DART_DEFINES=(
  --dart-define=PESO_NSRP_WORKSPACE_URL=https://pesoaimatching.vercel.app/
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