#!/usr/bin/env bash
set -euo pipefail

report="$(mktemp)"
trap 'rm -f "$report"' EXIT

if ! dart analyze --format machine >"$report"; then
  cat "$report"
  exit 1
fi

if grep -E '^(ERROR|WARNING)\|' "$report"; then
  echo "Dart analysis failed: errors or warnings must be fixed." >&2
  exit 1
fi

info_count="$(grep -c '^INFO|' "$report" || true)"
echo "Dart analysis passed: no errors or warnings; $info_count informational lint(s) remain."