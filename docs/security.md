# Security

## Threat Model
- Trusted: Uniswap v4 PoolManager execution correctness.
- Adversarial: traders, routers, MEV bots, malformed hookData callers.
- Semi-trusted: registry owner/governance.

## Main Attack Surfaces
- Router bypass attempts.
- Cooldown griefing.
- Admin policy abuse.
- Policy misconfiguration DoS.

## Mitigations
- onlyPoolManager for hook entrypoints.
- onlyAuthorizedHook for registry evaluation.
- owner-gated writes + bounded policy fields.
- evented reason codes for transparent behavior.

## Residual Risks
- Governance/admin trust remains.
- Approximate impact model may not equal exact realized price impact.
- Any overly restrictive policy can degrade UX.
