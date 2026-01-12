# Makefile for building Grafana dashboards and PrometheusRules from kube-prometheus jsonnet
# Prerequisites:
#   - go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
#   - go install github.com/google/go-jsonnet/cmd/jsonnet@latest
#   - jq (brew install jq)
#   - yq (brew install yq)

.PHONY: all build clean deps help update

# Default target
all: build

# Install jsonnet dependencies
deps:
	@echo "==> Installing jsonnet dependencies..."
	jb install

# Build dashboards and rules from jsonnet
build: deps
	@echo "==> Building dashboards and rules..."
	./build-dashboards.sh

# Clean generated files
clean:
	@echo "==> Cleaning generated files..."
	rm -rf output/
	rm -rf output-alerts/
	rm -rf vendor/
	rm -f jsonnetfile.lock.json

# Update jsonnet dependencies
update:
	@echo "==> Updating jsonnet dependencies..."
	jb update

help:
	@echo "Available targets:"
	@echo "  all     - Build dashboards and rules (default)"
	@echo "  build   - Build dashboards and rules from jsonnet"
	@echo "  deps    - Install jsonnet dependencies"
	@echo "  clean   - Remove generated files"
	@echo "  update  - Update jsonnet dependencies"
	@echo ""
	@echo "Prerequisites:"
	@echo "  go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest"
	@echo "  go install github.com/google/go-jsonnet/cmd/jsonnet@latest"
	@echo "  jq (brew install jq)"
	@echo "  yq (brew install yq)"
