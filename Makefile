REPO=blacktop
NAME=cgo-swift-demangle
CLI=github.com/blacktop/cgo-swift-demangle/cmd/demangle
CUR_VERSION=$(shell svu current)
NEXT_VERSION=$(shell svu patch)
SWIFT_VERSION=5.6.3-RELEASE

.PHONY: build-deps
build-deps: ## Install the build dependencies
	@echo " > Installing build deps"
	brew install go goreleaser
	go install golang.org/x/tools/cmd/stringer

.PHONY: build
build: ## Build demangle locally
	@echo " > Building locally"
	CGO_ENABLED=1 go build -o demangle.${CUR_VERSION} ./cmd/demangle

.PHONY: update
update: ## Update vendored source code
	@echo " > Updating vendored source code"
	mkdir swift-source || true
	cd swift-source; git clone https://github.com/apple/swift.git
	cd swift-source; swift/utils/update-checkout --clone
	cd swift-source/swift; git checkout swift-${SWIFT_VERSION}
	cd swift-source/swift; utils/build-script --skip-build
	python3 scripts/update.py swift-source

.PHONY: test
test: build ## Test demangle on hello-mte
	@echo " > demangling symbol\n"
	@./demangle.${CUR_VERSION} ''

.PHONY: dry_release
dry_release: ## Run goreleaser without releasing/pushing artifacts to github
	@echo " > Creating Pre-release Build ${NEXT_VERSION}"
	@GOROOT=$(shell go env GOROOT) goreleaser build -id darwin --rm-dist --snapshot --single-target --output dist/demangle

.PHONY: snapshot
snapshot: ## Run goreleaser snapshot
	@echo " > Creating Snapshot ${NEXT_VERSION}"
	@goreleaser --rm-dist --snapshot

.PHONY: release
release: ## Create a new release from the NEXT_VERSION
	@echo " > Creating Release ${NEXT_VERSION}"
	@hack/make/release ${NEXT_VERSION}
	@GOROOT=$(shell go env GOROOT) goreleaser --rm-dist

.PHONY: destroy
destroy: ## Remove release from the CUR_VERSION
	@echo " > Deleting Release ${CUR_VERSION}"
	git tag -d ${CUR_VERSION}
	git push origin :refs/tags/${CUR_VERSION}

.PHONY: cross
cross: ## Create xgo releases
	@echo " > Creating xgo releases"
	@mkdir -p dist/xgo
	@cd dist/xgo; xgo --targets=*/amd64 -go 1.16.5 -ldflags='-s -w' -out demangle-${NEXT_VERSION} ${CLI}

clean: ## Clean up artifacts
	@echo " > Cleaning"
	rm -rf dist
	rm demangle.v* || true

# Absolutely awesome: http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help