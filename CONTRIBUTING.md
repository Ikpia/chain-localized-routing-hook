# Contributing

## Setup
```bash
make bootstrap
npm install
```

## Before PR
```bash
make build
make test
make coverage
./scripts/verify_dependencies.sh
```

## Style
- Root-level Foundry structure (`src`, `test`, `script`, `lib`).
- Keep dependency versions pinned and consistent.
- Add tests for any behavior change, especially policy allow/deny logic.
