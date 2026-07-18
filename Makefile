# MenuVibe — developer convenience targets.
# `swift build` / `swift run` work directly; these just wrap the common flows.

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Debug build of the executable
	swift build

.PHONY: run
run: ## Build and run from the terminal (Ctrl-C to quit)
	swift run

.PHONY: release
release: ## Release build of the executable
	swift build -c release

.PHONY: app
app: ## Assemble dist/MenuVibe.app (release, ad-hoc signed)
	./Scripts/build-app.sh release

.PHONY: dmg
dmg: app ## Build the app and package dist/MenuVibe.dmg
	./Scripts/make-dmg.sh

.PHONY: test
test: ## Run the test suite
	swift test

.PHONY: clean
clean: ## Remove build artifacts
	swift package clean
	rm -rf .build dist
