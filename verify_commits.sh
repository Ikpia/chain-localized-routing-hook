#!/usr/bin/env bash
set -euo pipefail

EXPECTED_COUNT="${1:-58}"
ACTUAL_COUNT="$(git rev-list --count HEAD)"

if [ "$ACTUAL_COUNT" != "$EXPECTED_COUNT" ]; then
  echo "[verify-commits] ERROR: expected ${EXPECTED_COUNT}, got ${ACTUAL_COUNT}" >&2
  exit 1
fi

echo "[verify-commits] OK: ${ACTUAL_COUNT} commits"
