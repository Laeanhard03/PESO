#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.47.1"
FLUTTER_PARENT="${HOME}/.cache/peso-flutter-sdk"
FLUTTER_ROOT="${FLUTTER_PARENT}/flutter"
ARCHIVE="${TMPDIR:-/tmp}/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
ARCHIVE_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
EXPECTED_SHA256="a1d8166c0309267cb7dc99f1424eecf08b86946ad3b50723c6f59945964aea45"

if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
  mkdir -p "${FLUTTER_PARENT}"
  echo "Downloading pinned Flutter ${FLUTTER_VERSION} SDK..."
  curl --fail --location --retry 3 --retry-delay 2 "${ARCHIVE_URL}" --output "${ARCHIVE}"
  echo "${EXPECTED_SHA256}  ${ARCHIVE}" | sha256sum --check
  tar -xf "${ARCHIVE}" -C "${FLUTTER_PARENT}"
  rm -f "${ARCHIVE}"
fi

export PATH="${FLUTTER_ROOT}/bin:${PATH}"
flutter config --no-analytics --enable-web
flutter precache --web
flutter pub get