#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

scripts/bootstrap.sh

echo "[demo-profiles] Executing profile-specific hook behavior tests"
forge test --match-contract ChainLocalizedRoutingHookTest -vv
forge test --match-contract ProfileLifecycleIntegrationTest -vvv

echo "[demo-profiles] Completed profile demonstrations"
