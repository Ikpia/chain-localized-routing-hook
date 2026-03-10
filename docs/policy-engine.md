# Policy Engine

## Policy Struct
`PoolPolicy` stores enabled state, limit thresholds, list controls, and fee mode flags.

## Evaluation Order
1. enabled check
2. denylist check
3. allowlist check
4. max amount
5. gas price ceiling
6. impact estimate check
7. cooldown
8. swaps-per-block
9. fee override computation

## Reason Codes
- `0 ALLOWED`
- `1 POLICY_DISABLED`
- `2 SWAP_TOO_LARGE`
- `3 PRICE_IMPACT_TOO_HIGH`
- `4 COOLDOWN_ACTIVE`
- `5 SWAPS_PER_BLOCK_EXCEEDED`
- `6 ROUTER_NOT_ALLOWLISTED`
- `7 ACTOR_DENIED`
- `8 GAS_PRICE_TOO_HIGH`
