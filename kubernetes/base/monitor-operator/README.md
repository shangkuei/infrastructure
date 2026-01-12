# kube-prometheus-stack

Prometheus Operator deployment using the [kube-prometheus-stack](https://github.com/prometheus-operator/kube-prometheus) Helm chart in **operator-only mode**.

## Architecture

This base provides **only the Prometheus Operator**. All monitoring resources are managed separately for better GitOps control:

| Component | Managed By | Location |
|-----------|------------|----------|
| **Prometheus Operator** | This chart (Helm) | `monitor-operator` overlay |
| **Prometheus CR** | Explicit CR (GitOps) | `monitor-cluster` overlay |
| **Alertmanager CR** | Explicit CR (GitOps) | `monitor-cluster` overlay |
| **ServiceMonitors** | Explicit CRs (GitOps) | `monitor-cluster` overlay (6 CRs) |
| **PrometheusRules** | Explicit CRs (GitOps) | `monitor-cluster` overlay (30 CRs) |
| **Grafana** | grafana-operator | `monitor-cluster` overlay |
| **node-exporter** | Standalone HelmRelease | `monitor-operator` base |
| **kube-state-metrics** | Standalone HelmRelease | `monitor-operator` base |

## Configuration

### Base Configuration

The base configuration provides **only the Prometheus Operator**:

- **Prometheus Operator**: Manages Prometheus/Alertmanager CRDs
- **CRDs**: Automatically managed via `crds: CreateReplace`
- **No default resources**: ServiceMonitors, PrometheusRules, and CRs are disabled

### Why Operator-Only Mode?

**Benefits of explicit CRs**:

- Full version control of monitoring configuration
- Easy customization of rules and scrape configs
- Clear separation: operator (Helm) vs configuration (Kustomize)
- No label selector workarounds needed
- Prometheus/Alertmanager configuration fully visible in Git

### Disabled Chart Features

All monitoring resources are disabled in the base chart and managed explicitly:

**Disabled CRs** (managed in `monitor-cluster` overlay):

- `prometheus.enabled: false` - Prometheus CR managed explicitly
- `alertmanager.enabled: false` - Alertmanager CR managed explicitly

**Disabled ServiceMonitors** (managed in `monitor-cluster` overlay):

- `kubeApiServer.enabled: false`
- `kubelet.enabled: false`
- `coreDns.enabled: false`
- `kubeControllerManager.enabled: false` (not accessible on Talos)
- `kubeScheduler.enabled: false` (not accessible on Talos)
- `kubeEtcd.enabled: false` (not accessible on Talos)
- `kubeProxy.enabled: false` (using Cilium replacement)

**Disabled Rules**:

- `defaultRules.create: false` - All PrometheusRules managed explicitly

### Storage Configuration

Storage is configured in the explicit Prometheus/Alertmanager CRs in `monitor-cluster` overlay, not in the chart values. Example:

```yaml
# In monitor-cluster overlay: prometheus.yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus
spec:
  storage:
    volumeClaimTemplate:
      spec:
        storageClassName: openebs-mayastor
        resources:
          requests:
            storage: 200Gi
```

## Cluster Overlays

| Cluster | Storage Class | Notes |
|---------|---------------|-------|
| shangkuei-lab | openebs-mayastor | 3-replica NVMe-oF storage |

## Monitoring Resources (monitor-cluster overlay)

Since this base only provides the operator, all monitoring resources are in `monitor-cluster` overlay:

**Prometheus/Alertmanager CRs**:

- `prometheus.yaml` - Prometheus instance configuration (storage, retention, selectors)
- `alertmanager.yaml` - Alertmanager instance configuration

**ServiceMonitors** (6 CRs):

- `servicemonitors/prometheus-alertmanager.yaml` - Alertmanager metrics
- `servicemonitors/prometheus-apiserver.yaml` - Kubernetes API server metrics
- `servicemonitors/prometheus-coredns.yaml` - CoreDNS metrics
- `servicemonitors/prometheus-kubelet.yaml` - Kubelet and cAdvisor metrics
- `servicemonitors/prometheus-operator.yaml` - Prometheus Operator metrics
- `servicemonitors/prometheus-prometheus.yaml` - Prometheus self-monitoring

**PrometheusRules** (30 CRs in `prometheusrules/`):

- Alerting rules: `kubernetes-apps.yaml`, `node-exporter.yaml`, etc.
- Recording rules: `k8s.rules.container-resource.yaml`, `k8s.rules.pod-owner.yaml`, etc.

All resources include:

- Label: `app.kubernetes.io/managed-by: kustomize` (for selector filtering)
- Cluster label relabelings for multi-cluster support
- Cardinality reduction via metricRelabelings

## Access

Services created by explicit CRs (not the chart):

### Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
```

### Alertmanager

```bash
kubectl port-forward -n monitoring svc/alertmanager-operated 9093:9093
```

### Grafana

Managed by grafana-operator in `monitor-cluster` overlay:

```bash
kubectl port-forward -n monitoring svc/grafana-service 3000:3000
```

Credentials are managed via SOPS-encrypted secrets in cluster overlays.

## Metrics Strategy

### Local vs Cloud Metrics

This stack is designed as the **central metrics repository** for full observability:

| Tier | Storage | Metrics | Purpose |
|------|---------|---------|---------|
| **Local (this stack)** | Prometheus | All metrics (~50-85K series) | Full observability, debugging, dashboards |
| **Grafana Cloud** (optional) | Remote write | Critical alerting metrics only | Cross-cluster alerting, long-term trends |

### Grafana Cloud Cost Optimization

If integrating with Grafana Cloud in the future, **only push critical metrics** to control costs.

Configure remote write in the Prometheus CR (`monitor-cluster` overlay):

```yaml
# In monitor-cluster overlay: prometheus.yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
spec:
  remoteWrite:
    - url: https://prometheus-prod-xx.grafana.net/api/prom/push
      basicAuth:
        username:
          name: grafana-cloud-credentials
          key: username
        password:
          name: grafana-cloud-credentials
          key: password
      writeRelabelConfigs:
        # Only send metrics used by alerting rules
        - sourceLabels: [__name__]
          regex: (up|kube_pod_status_phase|kube_deployment_status_replicas.*|node_cpu_seconds_total|node_memory_MemAvailable_bytes|container_memory_working_set_bytes|container_cpu_usage_seconds_total)
          action: keep
```

**Estimated series for alerting-only remote write**: ~2-5K series (vs 50-85K full)

This approach keeps:

- Full metrics locally for debugging and dashboards
- Minimal metrics in Grafana Cloud for cross-cluster alerting
- Costs manageable as clusters scale

## Adding ServiceMonitors

To monitor your applications, create ServiceMonitor resources in `monitor-cluster` overlay.

The Prometheus CR uses label selectors to discover ServiceMonitors, so ensure your ServiceMonitor includes the required label:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: monitoring
  labels:
    app.kubernetes.io/managed-by: kustomize  # Required for discovery
spec:
  selector:
    matchLabels:
      app: my-app
  namespaceSelector:
    matchNames:
      - default
  endpoints:
    - port: metrics
      interval: 30s
```

Add ServiceMonitors to `kubernetes/overlays/monitor-cluster/<cluster-name>/` for version control.

## References

- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Documentation](https://grafana.com/docs/)
