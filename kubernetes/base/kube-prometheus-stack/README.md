# kube-prometheus-stack

Complete Kubernetes monitoring stack using the [kube-prometheus-stack](https://github.com/prometheus-operator/kube-prometheus) Helm chart.

## Components

| Component | Description |
|-----------|-------------|
| **Prometheus Operator** | Manages Prometheus and Alertmanager instances via CRDs |
| **Prometheus** | Metrics collection and storage |
| **Grafana** | Visualization dashboards |
| **Alertmanager** | Alert routing and management |
| **node-exporter** | Host-level metrics (CPU, memory, disk, network) |
| **kube-state-metrics** | Kubernetes object state metrics |

## Configuration

### Base Configuration

The base configuration provides:

- Prometheus with 15-day retention and 45GB storage limit
- Grafana with default Kubernetes dashboards
- Alertmanager for alert management
- ServiceMonitor/PodMonitor discovery across all namespaces
- Default alerting rules for Kubernetes components

### Storage

Storage is **disabled by default** in the base configuration. Enable persistent storage via cluster overlays:

```yaml
patches:
  - patch: |-
      - op: add
        path: /spec/values/prometheus/prometheusSpec/storageSpec
        value:
          volumeClaimTemplate:
            spec:
              storageClassName: your-storage-class
              resources:
                requests:
                  storage: 50Gi
    target:
      kind: HelmRelease
      name: kube-prometheus-stack
```

### Disabled Components

Some components are disabled by default for Talos Linux compatibility:

- `kubeControllerManager`: Not accessible on Talos
- `kubeScheduler`: Not accessible on Talos
- `kubeEtcd`: Not accessible on Talos
- `kubeProxy`: Using Cilium kube-proxy replacement

## Cluster Overlays

| Cluster | Storage Class | Notes |
|---------|---------------|-------|
| shangkuei-lab | openebs-mayastor | 3-replica NVMe-oF storage |

## Access

### Grafana

Credentials are managed via SOPS-encrypted secrets in cluster overlays.

To generate credentials for a cluster overlay:

```bash
cd kubernetes/overlays/kube-prometheus-stack/<cluster-name>
make secret-grafana-admin
```

Port-forward to access locally:

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

### Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

### Alertmanager

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

## Metrics Strategy

### Local vs Cloud Metrics

This stack is designed as the **central metrics repository** for full observability:

| Tier | Storage | Metrics | Purpose |
|------|---------|---------|---------|
| **Local (this stack)** | Prometheus | All metrics (~50-85K series) | Full observability, debugging, dashboards |
| **Grafana Cloud** (optional) | Remote write | Critical alerting metrics only | Cross-cluster alerting, long-term trends |

### Grafana Cloud Cost Optimization

If integrating with Grafana Cloud in the future, **only push critical metrics** to control costs:

```yaml
# Example: Remote write only alerting-critical metrics
prometheus:
  prometheusSpec:
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

To monitor your applications, create ServiceMonitor resources:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: monitoring
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

## References

- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Documentation](https://grafana.com/docs/)
