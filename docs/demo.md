# Demo

## Local Judge Flow
1. `make demo-local`
2. Observe integration test where:
- swap succeeds under Base profile
- same swap fails under Optimism profile
- allowlist gating differs under Arbitrum profile
3. `make demo-profiles` for additional profile/edge checks.

## Testnet Flow
1. `RPC_URL=<rpc> PRIVATE_KEY=<pk> make demo-testnet`
2. Use printed addresses in frontend (`frontend/`) to configure policies.
3. Execute profile transitions and monitor event logs.
