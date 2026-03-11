# Deployment

## Bootstrap
```bash
make bootstrap
```

## Local Lifecycle Proof
```bash
make demo-local
```

## Single-Chain Testnet Workflow (Unichain Sepolia)
```bash
make demo-testnet
```

This runs:
1. Deploy/reuse `RoutingPolicyRegistry` + `ChainLocalizedRoutingHook`.
2. Configure Base/Optimism/Arbitrum policy profiles.
3. Execute allowlist/denylist admin transactions.
4. Print tx hashes and explorer URLs.

## Multi-Chain Deployment Pipeline (Base / OP / Arb Sepolia + Polygon)
```bash
make deploy-multichain
```

This script deploys (or reuses if code exists) on:
- Base Sepolia (`84532`)
- Arbitrum Sepolia (`421614`)
- Polygon (`137`)

Optimism Sepolia (`11155420`) is opt-in:
- set `DEPLOY_OPTIMISM_SEPOLIA=true`
- provide explicit v4 infra addresses (below)

### Required Env
- `PRIVATE_KEY` (or `ACCOUNT` + `SENDER`)

### Optional Env Overrides
- `BASE_SEPOLIA_RPC_URL` (default: `https://sepolia.base.org`)
- `OPTIMISM_SEPOLIA_RPC_URL` (default: `https://sepolia.optimism.io`)
- `ARBITRUM_SEPOLIA_RPC_URL` (default: `https://sepolia-rollup.arbitrum.io/rpc`)
- `POLYGON_RPC_URL` (default: `https://polygon-bor-rpc.publicnode.com`)

### Infra Address Config
The script validates chain-specific infra addresses onchain before deployment:
- `BASE_SEPOLIA_POOL_MANAGER_ADDRESS`
- `BASE_SEPOLIA_POSITION_MANAGER_ADDRESS`
- `BASE_SEPOLIA_UNIVERSAL_ROUTER_ADDRESS`
- `ARBITRUM_SEPOLIA_POOL_MANAGER_ADDRESS`
- `ARBITRUM_SEPOLIA_POSITION_MANAGER_ADDRESS`
- `ARBITRUM_SEPOLIA_UNIVERSAL_ROUTER_ADDRESS`

Optimism Sepolia (only when enabled):
- `OPTIMISM_SEPOLIA_POOL_MANAGER_ADDRESS`
- `OPTIMISM_SEPOLIA_POSITION_MANAGER_ADDRESS`
- `OPTIMISM_SEPOLIA_UNIVERSAL_ROUTER_ADDRESS`

Polygon:
- `POLYGON_POOL_MANAGER_ADDRESS`
- `POLYGON_POSITION_MANAGER_ADDRESS`
- `POLYGON_UNIVERSAL_ROUTER_ADDRESS`
- `DEPLOY_POLYGON` (default `true`; skips when deployer has zero MATIC)

### Outputs
1. `.env` updates:
- `BASE_SEPOLIA_REGISTRY`
- `BASE_SEPOLIA_HOOK_ADDRESS`
- `OPTIMISM_SEPOLIA_REGISTRY`
- `OPTIMISM_SEPOLIA_HOOK_ADDRESS`
- `ARBITRUM_SEPOLIA_REGISTRY`
- `ARBITRUM_SEPOLIA_HOOK_ADDRESS`
- `POLYGON_REGISTRY`
- `POLYGON_HOOK_ADDRESS`

2. Deployment registry file:
- `shared/constants/deployments.multichain.json`

3. Console logs:
- tx hashes
- per-chain explorer URLs
