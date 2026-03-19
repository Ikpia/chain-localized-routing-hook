# Architecture

## Components
- `ChainLocalizedRoutingHook`: swap-hook gate + context builder.
- `RoutingPolicyRegistry`: profile/policy state + allow/deny decisions.
- `LimitsModule`: deterministic impact approximation.
- `FeePolicyModule`: optional dynamic fee override signaling.

## Execution Rule
`PoolManager -> Hook -> Registry -> allow/deny -> PoolManager`.

## Invariants
- Hook entrypoints callable only by PoolManager.
- Registry validation callable only by authorized hook addresses.
- Owner-gated policy mutation.
