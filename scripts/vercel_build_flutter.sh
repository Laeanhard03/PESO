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
flutter build web --release \
  --dart-define=PESO_NSRP_WORKSPACE_URL=https://pesoaimatching.vercel.app/