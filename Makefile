#
PWD := $(shell pwd)
GOPATH := $(shell go env GOPATH)
LDFLAGS := $(shell go run buildscripts/gen-ldflags.go)

GOARCH := $(shell go env GOARCH)
GOOS := $(shell go env GOOS)

VERSION ?= $(shell git describe --tags || echo "latest")
TAG ?= "minio/minio:$(VERSION)"

#
.DEFAULT_GOAL := help

.PHONY: help
help: Makefile
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

#
tidy: ## Tidy up
	@go mod tidy
	@go fmt ./...
	@go vet ./...
#
all: build

checks:
	@echo "Checking dependencies"
	@(env bash $(PWD)/buildscripts/checkdeps.sh)

getdeps: ## Get all dependencies
	@mkdir -p ${GOPATH}/bin
	@which golangci-lint 1>/dev/null || (echo "Installing golangci-lint" && curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(GOPATH)/bin v1.56.2)
	@which msgp 1>/dev/null || (echo "Installing msgp" && go install github.com/tinylib/msgp@latest)
	@which stringer 1>/dev/null || (echo "Installing stringer" && go install golang.org/x/tools/cmd/stringer@latest)
	@which ruleguard 1>/dev/null || (echo "Installing ruleguard" && go install github.com/quasilyte/go-ruleguard/cmd/ruleguard@latest)

crosscompile:
	@(env bash $(PWD)/buildscripts/cross-compile.sh)

verifiers: getdeps lint check-gen

check-gen:
	@go generate ./... >/dev/null
	@(! git diff --name-only | grep '_gen.go$$') || (echo "Non-committed changes in auto-generated code is detected, please commit them to proceed." && false)

lint: getdeps ## Lint
	@echo "Running $@ check"
	@GO111MODULE=on ${GOPATH}/bin/golangci-lint cache clean
	@GO111MODULE=on ${GOPATH}/bin/golangci-lint run --build-tags kqueue --timeout=10m --config ./.golangci.yml

# Builds minio, runs the verifiers then runs the tests.
check: test
test: verifiers build ## Run verifiers and tests
	@echo "Running unit tests"
	@GOGC=25 GO111MODULE=on CGO_ENABLED=0 go test -tags kqueue ./... #1>/dev/null

test-race: verifiers build ## Run verifiers and tests with race
	@echo "Running unit tests under -race"
	@(env bash $(PWD)/buildscripts/race.sh)

# Verify minio binary
verify: ## Verify build with race
	@echo "Verifying build with race"
	@GO111MODULE=on CGO_ENABLED=1 go build -tags kqueue -trimpath --ldflags "$(LDFLAGS)" -o $(PWD)/minio #1>/dev/null
	@(env bash $(PWD)/buildscripts/verify-build.sh)

# Verify healing of disks with minio binary
verify-healing: ## Verify healing with race
	@echo "Verify healing build with race"
	@GO111MODULE=on CGO_ENABLED=1 go build -race -tags kqueue -trimpath --ldflags "$(LDFLAGS)" -o $(PWD)/minio #1>/dev/null
	@(env bash $(PWD)/buildscripts/verify-healing.sh)

# Builds minio locally.
build: checks ## Build minio locally
	@echo "Building minio binary to './minio'"
	@GO111MODULE=on CGO_ENABLED=0 go build -tags kqueue -trimpath --ldflags "$(LDFLAGS)" -o $(PWD)/minio #1>/dev/null

hotfix-vars:
	$(eval LDFLAGS := $(shell MINIO_RELEASE="RELEASE" MINIO_HOTFIX="hotfix.$(shell git rev-parse --short HEAD)" go run buildscripts/gen-ldflags.go $(shell git describe --tags --abbrev=0 | \
    sed 's#RELEASE\.\([0-9]\+\)-\([0-9]\+\)-\([0-9]\+\)T\([0-9]\+\)-\([0-9]\+\)-\([0-9]\+\)Z#\1-\2-\3T\4:\5:\6Z#')))
	$(eval TAG := "minio/minio:$(shell git describe --tags --abbrev=0).hotfix.$(shell git rev-parse --short HEAD)")
hotfix: hotfix-vars install

docker-hotfix: hotfix checks
	@echo "Building minio docker image '$(TAG)'"
	@docker build -t $(TAG) . -f Dockerfile.dev

docker: build checks ## Build docker image '$(TAG)'
	@echo "Building minio docker image '$(TAG)'"
	@docker build -t $(TAG) . -f Dockerfile.dev

# Builds minio and installs it to $GOPATH/bin.
install: build ## Build and install to $GOPATH/bin
	@echo "Installing minio binary to '$(GOPATH)/bin/minio'"
	@mkdir -p $(GOPATH)/bin && cp -f $(PWD)/minio $(GOPATH)/bin/minio
	@echo "Installation successful. To learn more, try \"minio --help\"."

clean: ## Clean up
	@echo "Cleaning up all the generated files"
	@find . -name '*.test' | xargs rm -fv
	@find . -name '*~' | xargs rm -fv
	@rm -rvf minio
	@rm -rvf build
	@rm -rvf release
	@rm -rvf .verify*
