# Testing

## Coverage Matrix
- Unit: policy state and access controls.
- Edge cases: boundaries and invalid policy updates.
- Fuzz: amount and gas ceiling constraints.
- Invariant: max amount rule cannot be bypassed.
- Integration: profile-specific lifecycle outcomes on hooked pool swaps.

## Commands
```bash
make test
make coverage
```
