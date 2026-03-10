#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

scripts/bootstrap.sh

echo "[demo-local] Running full profile lifecycle integration demo on local Foundry state"
forge test --match-test testProfileSpecificOutcomes -vvv

echo "[demo-local] Running policy edge/fuzz/invariant checks"
forge test --match-contract RoutingPolicyRegistryTest -vv
forge test --match-contract RoutingPolicyRegistryFuzzTest -vv
forge test --match-contract RoutingPolicyRegistryInvariantTest -vv

echo "[demo-local] Demo complete"
