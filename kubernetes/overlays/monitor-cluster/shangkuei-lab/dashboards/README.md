# Grafana Dashboards from kube-prometheus

This directory contains tooling to build Grafana dashboards from the [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) jsonnet source.

## Prerequisites

Install jsonnet tooling:

```bash
# Jsonnet bundler (dependency manager)
go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest

# Jsonnet compiler
go install github.com/google/go-jsonnet/cmd/jsonnet@latest
```

## Usage

```bash
# Build dashboards and generate GrafanaDashboard CRs
make build

# Clean generated files
make clean

# Update kube-prometheus to latest version
make update
```

## Generated Files

- `output/` - Individual dashboard JSON files (gitignored)
- `../grafana-dashboards-kube-prometheus.yaml` - GrafanaDashboard CRs for grafana-operator

## Dashboard Sources

We use two dashboard sources for comparison:

1. **dotdc/grafana-dashboards-kubernetes** (`grafana-dashboards-kubernetes.yaml`)
   - Modern, actively maintained dashboards
   - Published on grafana.com (IDs: 15757-15762, 19105, 1860)
   - Simpler, more focused views

2. **kube-prometheus jsonnet** (`grafana-dashboards-kube-prometheus.yaml`)
   - Official Prometheus Operator dashboards
   - Comprehensive kubernetes-mixin dashboards
   - Generated from jsonnet source

## Updating Dashboards

To update the kube-prometheus dashboards:

```bash
cd dashboards
make update  # Update jsonnet dependencies
make build   # Rebuild dashboards
```

Then commit the regenerated `grafana-dashboards-kube-prometheus.yaml`.
