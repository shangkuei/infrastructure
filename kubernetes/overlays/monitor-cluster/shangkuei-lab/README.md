# Monitor Cluster - shangkuei-lab

This overlay deploys a complete monitoring stack for the shangkuei-lab environment using GitOps principles.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Monitoring Stack                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐           │
│  │  Prometheus  │───▶│ Alertmanager │    │   Grafana    │           │
│  │   cluster    │    │   cluster    │    │   grafana    │           │
│  │  (metrics)   │    │  (alerts)    │    │ (dashboards) │           │
│  └──────────────┘    └──────────────┘    └──────────────┘           │
│         │                                       │                    │
│         │            ┌──────────────┐           │                    │
│         └───────────▶│     Loki     │◀──────────┘                    │
│                      │   (logs)     │                                │
│                      └──────────────┘                                │
│                             ▲                                        │
│                      ┌──────────────┐                                │
│                      │    Alloy     │                                │
│                      │ (collector)  │                                │
│                      └──────────────┘                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Kind | Name | Pod Name | Storage |
|-----------|------|------|----------|---------|
| Prometheus | Prometheus | cluster | prometheus-cluster-0 | 200Gi |
| Alertmanager | Alertmanager | cluster | alertmanager-cluster-0 | 5Gi |
| Grafana | Grafana | grafana | grafana-deployment-xxx | 10Gi |
| Alloy | HelmRelease | alloy | alloy-xxx | - |
| Loki | (via monitor-operator) | - | - | S3 |

## Directory Structure

```
shangkuei-lab/
├── README.md                    # This file
├── CLAUDE.md                    # AI agent guidance
├── kustomization.yaml           # Main kustomization
├── .sops.yaml                   # SOPS encryption config
├── Makefile                     # Build automation
│
├── # Core CRs (kind-name.yaml pattern)
├── prometheus-cluster.yaml      # Prometheus CR
├── alertmanager-cluster.yaml    # Alertmanager CR
├── grafana-grafana.yaml         # Grafana CR
│
├── # Grafana Resources
├── grafanadatasource-prometheus.yaml
├── grafanadatasource-loki.yaml
├── grafanadashboard-kube-prometheus.yaml  # Auto-generated
│
├── # Prometheus/Alertmanager RBAC
├── serviceaccount-prometheus.yaml
├── serviceaccount-alertmanager.yaml
├── clusterrole-prometheus.yaml
├── clusterrole-alertmanager.yaml
├── clusterrolebinding-prometheus.yaml
├── clusterrolebinding-alertmanager.yaml
│
├── # Services
├── service-prometheus.yaml
├── service-alertmanager.yaml
│
├── # Storage
├── persistentvolumeclaim-grafana.yaml
├── persistentvolumeclaim-prometheus.yaml
│
├── # Alloy (log collector)
├── helmrelease-alloy.yaml
├── configmap-alloy.yaml
│
├── # Prometheus Rules
├── prometheusrule-loki-mixin.yaml
├── prometheusrules/             # Migrated from kube-prometheus-stack
│   ├── prometheusrule-alertmanager.yaml
│   ├── prometheusrule-general.yaml
│   └── ...
│
├── # ServiceMonitors
├── servicemonitors/             # Migrated from kube-prometheus-stack
│   ├── servicemonitor-alertmanager.yaml
│   ├── servicemonitor-prometheus.yaml
│   └── ...
│
└── dashboards/                  # Dashboard build tooling
    ├── Makefile
    ├── dashboards.jsonnet
    └── build-dashboards.sh
```

## Label Convention

All resources use the standard Kubernetes recommended labels:

| Label | Description | Example |
|-------|-------------|---------|
| `app.kubernetes.io/name` | Application name | `prometheus`, `alertmanager`, `grafana` |
| `app.kubernetes.io/instance` | Instance identifier | `cluster`, `grafana` |
| `app.kubernetes.io/component` | Component role | `server`, `exporter` |
| `app.kubernetes.io/part-of` | Higher-level app | `monitoring` |
| `app.kubernetes.io/managed-by` | Tool managing resource | `kustomize` |

**Removed labels** (legacy Helm labels):

- `app: kube-prometheus-stack-*`
- `chart: kube-prometheus-stack-*`
- `heritage: Helm`
- `release: prometheus-operator`

## File Naming Convention

Files follow the `{kind}-{name}.yaml` pattern:

- Kind is lowercase (e.g., `prometheus`, `service`, `configmap`)
- Name is the resource's `metadata.name`
- CRD kinds use lowercase without hyphens (e.g., `grafanadatasource`, `prometheusrule`)

Examples:

- `prometheus-cluster.yaml` - Prometheus CR named "cluster"
- `service-prometheus.yaml` - Service named "prometheus"
- `grafanadatasource-loki.yaml` - GrafanaDatasource named "loki"

## Dependencies

This overlay depends on:

1. **monitor-operator** overlay - Deploys:
   - prometheus-operator (kube-prometheus-stack with only operator enabled)
   - grafana-operator
   - loki
   - kube-state-metrics
   - node-exporter

## Customization

### Dashboards

Dashboards are generated from jsonnet sources:

```bash
cd dashboards
make update    # Update jsonnet dependencies
make build     # Generate GrafanaDashboard CRs
```

### Adding ServiceMonitors

1. Create a new file: `servicemonitors/servicemonitor-{name}.yaml`
2. Add required labels:

   ```yaml
   labels:
     app.kubernetes.io/managed-by: kustomize
   ```

3. Add to `kustomization.yaml`

### Adding PrometheusRules

1. Create a new file: `prometheusrules/prometheusrule-{name}.yaml`
2. Add required labels:

   ```yaml
   labels:
     app.kubernetes.io/managed-by: kustomize
   ```

3. Add to `kustomization.yaml`

## Selectors

### Prometheus selects resources with

- **ServiceMonitors**: `app.kubernetes.io/managed-by: kustomize`
- **PrometheusRules**: `app.kubernetes.io/managed-by: kustomize`

### Grafana selects resources with

- **Dashboards**: `instanceSelector.matchLabels.dashboards: grafana`
- **Datasources**: `instanceSelector.matchLabels.datasources: grafana`

## Endpoints

| Service | Port | URL (in-cluster) |
|---------|------|------------------|
| Prometheus | 9090 | http://prometheus.monitoring:9090 |
| Alertmanager | 9093 | http://alertmanager.monitoring:9093 |
| Grafana | 3000 | http://grafana-service.monitoring:3000 |
| Loki | 80 | http://loki-gateway.monitoring |

## Migration Notes

This configuration was migrated from kube-prometheus-stack Helm chart to explicit CRs for:

- Full GitOps control over monitoring configuration
- Cleaner separation between operator (Helm) and configuration (Kustomize)
- Explicit version control of all monitoring resources

The prometheus-operator helm chart is still used to deploy the operator itself, but all Prometheus, Alertmanager, ServiceMonitor, and PrometheusRule resources are managed via Kustomize.
