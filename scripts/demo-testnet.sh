#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -z "${RPC_URL:-}" ]; then
  echo "[demo-testnet] ERROR: set RPC_URL" >&2
  exit 1
fi

if [ -z "${PRIVATE_KEY:-}" ] && [ -z "${ACCOUNT:-}" ]; then
  echo "[demo-testnet] ERROR: set PRIVATE_KEY or ACCOUNT" >&2
  exit 1
fi

scripts/bootstrap.sh

CHAIN_ID="$(cast chain-id --rpc-url "$RPC_URL")"

echo "[demo-testnet] Deploying registry + hook"
if [ -n "${PRIVATE_KEY:-}" ]; then
  forge script script/00_DeployHook.s.sol:DeployHookScript \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast
else
  if [ -z "${SENDER:-}" ]; then
    echo "[demo-testnet] ERROR: set SENDER when using ACCOUNT" >&2
    exit 1
  fi

  forge script script/00_DeployHook.s.sol:DeployHookScript \
    --rpc-url "$RPC_URL" \
    --account "$ACCOUNT" \
    --sender "$SENDER" \
    --broadcast
fi

RUN_FILE="broadcast/00_DeployHook.s.sol/${CHAIN_ID}/run-latest.json"
if [ ! -f "$RUN_FILE" ]; then
  echo "[demo-testnet] ERROR: missing broadcast file: $RUN_FILE" >&2
  exit 1
fi

REGISTRY_ADDR="$(jq -r '.transactions[] | select(.contractName == "RoutingPolicyRegistry") | .contractAddress' "$RUN_FILE" | tail -n1)"
HOOK_ADDR="$(jq -r '.transactions[] | select(.contractName == "ChainLocalizedRoutingHook") | .contractAddress' "$RUN_FILE" | tail -n1)"

echo "[demo-testnet] RoutingPolicyRegistry: ${REGISTRY_ADDR}"
echo "[demo-testnet] ChainLocalizedRoutingHook: ${HOOK_ADDR}"

echo "[demo-testnet] Transactions"
TX_HASHES="$(jq -r '.transactions[] | .hash // empty' "$RUN_FILE")"

EXPLORER_BASE=""
case "$CHAIN_ID" in
  84532) EXPLORER_BASE="https://sepolia.basescan.org/tx/" ;;
  11155420) EXPLORER_BASE="https://sepolia-optimism.etherscan.io/tx/" ;;
  421614) EXPLORER_BASE="https://sepolia.arbiscan.io/tx/" ;;
  *) EXPLORER_BASE="" ;;
esac

while IFS= read -r tx; do
  [ -z "$tx" ] && continue
  if [ -n "$EXPLORER_BASE" ]; then
    echo "- ${tx} -> ${EXPLORER_BASE}${tx}"
  else
    echo "- ${tx}"
  fi
done <<< "$TX_HASHES"

echo "[demo-testnet] Deployment complete. Use scripts or frontend to configure pool policies and execute swaps."
