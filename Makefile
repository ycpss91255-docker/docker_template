.PHONY: test lint coverage migrate migrate-list clean help

test: ## Run full CI (ShellCheck + Bats + Kcov) via docker compose
	./ci.sh

lint: ## Run ShellCheck only
	./ci.sh --lint-only

coverage: ## Run tests with Kcov coverage
	./ci.sh --coverage

migrate: ## Migrate all repos to docker_template
	./migrate.sh --all

migrate-list: ## List repos and their migration status
	./migrate.sh --list

migrate-dry-run: ## Dry-run migration for all repos
	./migrate.sh --dry-run --all

clean: ## Remove coverage reports
	rm -rf coverage/

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*##"}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
