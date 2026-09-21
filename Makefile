test-node:
	npm test

test: test-node

lint-shell:
	shellcheck prepare-dev/*.sh src/*.sh release-pr/*.sh validate-fixture-version/*.sh rename-dependabot-pr/*.sh

lint: lint-shell