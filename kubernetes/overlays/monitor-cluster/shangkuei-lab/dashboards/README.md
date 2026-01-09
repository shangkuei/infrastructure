# Grafana Dashboards from kube-prometheus

This directory contains tooling to build Grafana dashboards from the [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) jsonnet source and additional mixins.

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

**kube-prometheus jsonnet** (Kubernetes monitoring)

- Official Prometheus Operator dashboards
- Comprehensive kubernetes-mixin dashboards
- Node Exporter dashboards (Linux only - Windows/AIX/Darwin filtered out)

**CoreDNS mixin** (DNS monitoring)

- CoreDNS dashboard from [povilasv/coredns-mixin](https://github.com/povilasv/coredns-mixin)

**Loki mixin** (Log monitoring)

- Loki operational dashboards from [grafana/loki](https://github.com/grafana/loki)
- Includes: reads, writes, chunks, retention, deletion, bloom, and more

## Updating Dashboards

To update the dashboards:

```bash
cd dashboards
make update  # Update jsonnet dependencies
make build   # Rebuild dashboards
```

Then commit the regenerated `grafana-dashboards-kube-prometheus.yaml`.

## Customization

Edit `dashboards.jsonnet` to:

- Add new mixins
- Filter dashboards by name pattern
- Customize mixin configuration
