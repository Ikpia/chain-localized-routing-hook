# Overview

Chain-Localized Routing Hook is a Uniswap v4 hook primitive for chain-aware execution policy enforcement. Pools can enforce different behavior by chain profile (Base/Optimism/Arbitrum) without relying on offchain routers for correctness.

Core elements:
- Hook-level enforcement in `beforeSwap`.
- Registry-driven policy state.
- Deterministic checks and reason-coded outcomes.
- Foundry demo and test suites for judge-friendly reproducibility.
