#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PINNED_V4_PERIPHERY_COMMIT="3779387e5d296f39df543d23524b050f89a62917"

cd "$ROOT_DIR"

if ! git -C lib/v4-periphery rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[verify-deps] ERROR: lib/v4-periphery is not initialized" >&2
  exit 1
fi

ACTUAL_V4_PERIPHERY_COMMIT="$(git -C lib/v4-periphery rev-parse HEAD)"
if [ "$ACTUAL_V4_PERIPHERY_COMMIT" != "$PINNED_V4_PERIPHERY_COMMIT" ]; then
  echo "[verify-deps] ERROR: v4-periphery mismatch expected=${PINNED_V4_PERIPHERY_COMMIT} actual=${ACTUAL_V4_PERIPHERY_COMMIT}" >&2
  exit 1
fi

if [ -f "package-lock.json" ]; then
  if command -v npm >/dev/null 2>&1; then
    npm ci --ignore-scripts --dry-run >/dev/null
  elif [ -x "${ROOT_DIR}/.tooling/node/bin/npm" ]; then
    PATH="${ROOT_DIR}/.tooling/node/bin:${PATH}" npm ci --ignore-scripts --dry-run >/dev/null
  else
    echo "[verify-deps] ERROR: npm not found and package-lock.json exists" >&2
    exit 1
  fi
fi

echo "[verify-deps] OK"
