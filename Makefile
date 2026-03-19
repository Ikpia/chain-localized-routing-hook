.PHONY: bootstrap deps-verify build test coverage clean demo-local demo-testnet demo-profiles deploy-multichain frontend-install frontend-dev frontend-build verify-commits

bootstrap:
	./scripts/bootstrap.sh

deps-verify:
	./scripts/verify_dependencies.sh

build:
	forge build

test:
	forge test

coverage:
	forge coverage --report summary --report lcov --exclude-tests --no-match-coverage "script/*"

clean:
	forge clean
	docker image prune -f >/dev/null 2>&1 || true

demo-local:
	./scripts/demo-local.sh

demo-testnet:
	./scripts/demo-testnet.sh

demo-profiles:
	./scripts/demo-profiles.sh

deploy-multichain:
	./scripts/deploy-multichain.sh

frontend-install:
	npm install

frontend-dev:
	npm run dev --workspace frontend

frontend-build:
	npm run build --workspace frontend

verify-commits:
	./verify_commits.sh
