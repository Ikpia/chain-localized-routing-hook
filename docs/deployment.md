# Deployment

## Bootstrap
```bash
make bootstrap
```

## Local
```bash
make demo-local
```

## Testnet
```bash
RPC_URL=<rpc> PRIVATE_KEY=<pk> make demo-testnet
```

This deploys `RoutingPolicyRegistry` + `ChainLocalizedRoutingHook`, then prints tx hashes and explorer links for Base Sepolia / OP Sepolia / Arbitrum Sepolia when recognized.
