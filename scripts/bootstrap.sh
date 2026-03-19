#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PINNED_V4_PERIPHERY_COMMIT="3779387e5d296f39df543d23524b050f89a62917"

cd "$ROOT_DIR"

echo "[bootstrap] Syncing submodules"
git submodule sync --recursive

echo "[bootstrap] Initializing submodules"
git submodule update --init --recursive

if ! git -C lib/v4-periphery rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[bootstrap] ERROR: lib/v4-periphery is missing or not initialized" >&2
  exit 1
fi

echo "[bootstrap] Pinning v4-periphery to ${PINNED_V4_PERIPHERY_COMMIT}"
git -C lib/v4-periphery fetch origin
# detached HEAD for reproducibility
if ! git -C lib/v4-periphery checkout --detach "${PINNED_V4_PERIPHERY_COMMIT}"; then
  echo "[bootstrap] ERROR: failed to checkout pinned commit ${PINNED_V4_PERIPHERY_COMMIT}" >&2
  exit 1
fi

echo "[bootstrap] Initializing nested submodules (v4-core + permit2)"
git -C lib/v4-periphery submodule sync --recursive
git -C lib/v4-periphery submodule update --init --recursive

ACTUAL_V4_PERIPHERY_COMMIT="$(git -C lib/v4-periphery rev-parse HEAD)"
if [ "$ACTUAL_V4_PERIPHERY_COMMIT" != "$PINNED_V4_PERIPHERY_COMMIT" ]; then
  echo "[bootstrap] ERROR: commit mismatch. expected=${PINNED_V4_PERIPHERY_COMMIT} actual=${ACTUAL_V4_PERIPHERY_COMMIT}" >&2
  exit 1
fi

echo "[bootstrap] OK: v4-periphery pinned to ${ACTUAL_V4_PERIPHERY_COMMIT}"
