# Demo

## One-Command Workflow

Run the end-to-end demo script with phase logs:

```bash
./scripts/demo-workflow.sh --all
```

Available modes:

- `--multi-chain`: read existing multi-chain deployment registry and print addresses + tx URLs
- `--local`: local deterministic proof only
- `--testnet`: Unichain Sepolia proof using existing deployed contracts + profile configuration
- `--profiles`: local profile proof + testnet profile configuration (if `RPC_URL` is set)
- `--all`: local + testnet

## User Perspective Flow (What Judges Should See)

1. Connect wallet in `frontend/` dashboard.
2. Select profile (`Base`, `Optimism`, `Arbitrum`).
3. Apply policy updates (pool policy + optional allowlist/denylist).
4. Observe different enforcement outcomes for the same logical trade intent:
- Base allows higher throughput settings.
- Optimism blocks stricter cases (size/cooldown/impact).
- Arbitrum enables allowlist-oriented behavior and dynamic-fee mode.
5. Validate events and transaction traces from printed explorer URLs.

## Local Proof Phases

`--local` runs:

1. Dependency bootstrap.
2. Profile lifecycle integration test.
3. Hook behavior tests.
4. Registry edge tests.
5. Registry fuzz/invariant tests.

## Testnet Proof Phases (Unichain Sepolia)

`--testnet` runs:

1. Loads `.env`, validates RPC/signer, resolves chain context.
2. Requires existing `REGISTRY` + `HOOK_ADDRESS` from `.env` and verifies onchain bytecode.
3. Configures Base/Optimism/Arbitrum profile policies on `POOL_ID`.
4. Executes allowlist/denylist admin transactions.
5. Prints all tx hashes + explorer URLs.
6. Prints onchain snapshots for active profile and pool policy state.

Explorer link format used on chain `1301`:

- `https://sepolia.uniscan.xyz/tx/<tx_hash>`

## Required Environment

The script reads `.env`. Minimum required for testnet phase:

- `RPC_URL`
- `PRIVATE_KEY` (or `ACCOUNT` + `SENDER`)
- `OWNER_ADDRESS` (recommended; auto-derived when using `PRIVATE_KEY`)

Optional but recommended:

- `REGISTRY`
- `HOOK_ADDRESS`
- `POOL_ID`

If `REGISTRY` and `HOOK_ADDRESS` are missing, `--testnet` fails fast.

## Reactive Network Note

This repository does not integrate Reactive Network. Do not add or rely on `REACTIVE_*` environment variables for this demo workflow.
