# Makefile for building Grafana dashboards from kube-prometheus jsonnet
# Prerequisites:
#   - go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
#   - go install github.com/google/go-jsonnet/cmd/jsonnet@latest
#   - jq (brew install jq)

.PHONY: all build clean deps help

# Default target
all: build

# Install jsonnet dependencies
deps:
	@echo "==> Installing jsonnet dependencies..."
	jb install

# Build dashboards from jsonnet and generate GrafanaDashboard CRs
build: deps
	@echo "==> Building dashboards..."
	./build-dashboards.sh

# Clean generated files
clean:
	@echo "==> Cleaning generated files..."
	rm -rf output/
	rm -rf vendor/
	rm -f jsonnetfile.lock.json
	rm -f ../grafana-dashboards-kube-prometheus.yaml

# Update jsonnet dependencies
update:
	@echo "==> Updating jsonnet dependencies..."
	jb update

help:
	@echo "Available targets:"
	@echo "  all     - Build dashboards (default)"
	@echo "  build   - Build dashboards from jsonnet"
	@echo "  deps    - Install jsonnet dependencies"
	@echo "  clean   - Remove generated files"
	@echo "  update  - Update jsonnet dependencies"
	@echo ""
	@echo "Prerequisites:"
	@echo "  go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest"
	@echo "  go install github.com/google/go-jsonnet/cmd/jsonnet@latest"
	@echo "  jq (brew install jq)"
