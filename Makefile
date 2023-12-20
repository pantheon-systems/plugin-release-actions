test-node:
	npm test

test: test-node

lint-shell:
	shellcheck prepare-dev/*.sh prepare-dev/src/*.sh

lint: lint-shell