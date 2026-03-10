# API

## ChainLocalizedRoutingHook
- `getHookPermissions()`
- `allowedSwaps(poolId)`
- `blockedSwaps(poolId)`
- `beforeSwap(...)` / `afterSwap(...)` core hooks

## RoutingPolicyRegistry
- `setChainProfile(chainId, profile)`
- `setPoolPolicy(chainId, poolId, policy)`
- `setRouterAllowlist(chainId, poolId, router, allowed)`
- `setActorDenylist(chainId, poolId, actor, denied)`
- `validateAndRecordSwap(context)`
- `seedDefaultPolicy(chainId, poolId, liquidityReference)`
