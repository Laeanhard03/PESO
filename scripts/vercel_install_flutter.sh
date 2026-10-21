#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.47.1"
FLUTTER_PARENT="${HOME}/.cache/peso-flutter-sdk"
FLUTTER_ROOT="${FLUTTER_PARENT}/flutter"
FLUTTER_REPO="https://github.com/flutter/flutter.git"
EXPECTED_COMMIT="6655482ec06e547f90abf8ae7590466f4415978d"

if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
  mkdir -p "${FLUTTER_PARENT}"
  echo "Cloning pinned Flutter ${FLUTTER_VERSION} SDK..."
  GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "${FLUTTER_VERSION}" "${FLUTTER_REPO}" "${FLUTTER_ROOT}"
fi

ACTUAL_COMMIT="$(git -C "${FLUTTER_ROOT}" rev-parse HEAD)"
if [[ "${ACTUAL_COMMIT}" != "${EXPECTED_COMMIT}" ]]; then
  echo "Unexpected Flutter SDK commit; expected ${EXPECTED_COMMIT}, got ${ACTUAL_COMMIT}." >&2
  exit 1
fi

export PATH="${FLUTTER_ROOT}/bin:${PATH}"
flutter --version
flutter config --no-analytics --enable-web
flutter precache --web
flutter pub get