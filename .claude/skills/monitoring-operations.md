# Monitoring Operations Skill

Kubernetes and Docker monitoring stack operations for the hybrid cloud infrastructure.

## When to Use

Use this skill when:

- Verifying metrics collection in Prometheus
- Debugging scrape target issues
- Checking Flux reconciliation status
- Investigating monitoring stack health

## Environment Setup

KUBECONFIG is configured in `.claude/settings.local.json`:

```bash
export KUBECONFIG=/Users/shangkuei/dev/shangkuei/infrastructure/terraform/environments/talos-cluster-shangkuei-lab/generated/kubeconfig
```

## Prometheus Operations

### Check Scrape Targets

```bash
# List all targets
KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring deploy/prometheus-operator-kube-p-prometheus \
  -- wget -qO- 'localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Check specific job
KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring deploy/prometheus-operator-kube-p-prometheus \
  -- wget -qO- 'localhost:9090/api/v1/query?query=up{job="<job_name>"}'
```

### Query Metrics

```bash
# Check if metrics are being collected
KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring deploy/prometheus-operator-kube-p-prometheus \
  -- wget -qO- 'localhost:9090/api/v1/query?query=up{job="<job_name>"}'

# Count metrics for a job
KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring deploy/prometheus-operator-kube-p-prometheus \
  -- wget -qO- 'localhost:9090/api/v1/query?query=count({job="<job_name>"})'

# List metric names
KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring deploy/prometheus-operator-kube-p-prometheus \
  -- wget -qO- 'localhost:9090/api/v1/label/__name__/values' | jq '.data[] | select(startswith("<prefix>"))'
```

### Prometheus Resources

```bash
# Get Prometheus pods
KUBECONFIG=$KUBECONFIG kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Check ServiceMonitors
KUBECONFIG=$KUBECONFIG kubectl get servicemonitors -A

# Check PodMonitors
KUBECONFIG=$KUBECONFIG kubectl get podmonitors -A

# Describe scrape config
KUBECONFIG=$KUBECONFIG kubectl get prometheus -n monitoring -o yaml | grep -A 20 serviceMonitor
```

## Grafana Operations

### Dashboard Management

```bash
# Get GrafanaDashboard CRs
KUBECONFIG=$KUBECONFIG kubectl get grafanadashboards -n monitoring

# Describe dashboard
KUBECONFIG=$KUBECONFIG kubectl describe grafanadashboard <name> -n monitoring

# Check dashboard sync status
KUBECONFIG=$KUBECONFIG kubectl get grafanadashboards -n monitoring -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.NoMatchingInstances}{"\n"}{end}'
```

### Grafana Instance

```bash
# Get Grafana pods
KUBECONFIG=$KUBECONFIG kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Port forward for local access
KUBECONFIG=$KUBECONFIG kubectl port-forward -n monitoring svc/grafana 3000:80
```

## Alloy (Unraid Metrics Collector)

### Docker Compose Management

```bash
# On Unraid server
cd /mnt/user/appdata/alloy
docker compose logs -f alloy

# Restart Alloy
docker compose restart alloy

# Check Alloy targets
curl -s http://172.24.0.2:12345/api/v0/web/targets | jq
```

### Remote Write Verification

```bash
# Check Alloy remote write metrics
curl -s http://172.24.0.2:12345/metrics | grep prometheus_remote_storage

# Verify connection to remote Prometheus
curl -s http://172.24.0.2:12345/api/v0/web/targets | jq '.[] | select(.job | contains("remote"))'
```

## Flux Monitoring

### Check Kustomization Status

```bash
# All Flux resources
KUBECONFIG=$KUBECONFIG flux get all

# Specific kustomization
KUBECONFIG=$KUBECONFIG flux get kustomization monitoring

# Check for errors
KUBECONFIG=$KUBECONFIG flux logs --level=error
```

### Force Reconciliation

```bash
# Reconcile monitoring stack
KUBECONFIG=$KUBECONFIG flux reconcile kustomization monitoring --with-source

# Reconcile dashboards
KUBECONFIG=$KUBECONFIG flux reconcile kustomization grafana-dashboards --with-source
```

## Common Debugging

### Scrape Target Down

1. Check target health:

   ```bash
   KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring deploy/prometheus-operator-kube-p-prometheus \
     -- wget -qO- 'localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.job=="<job>") | {health, lastError}'
   ```

2. Verify service endpoint:

   ```bash
   KUBECONFIG=$KUBECONFIG kubectl get endpoints -A | grep <service>
   ```

3. Check ServiceMonitor selector:

   ```bash
   KUBECONFIG=$KUBECONFIG kubectl get servicemonitor <name> -n <namespace> -o yaml | grep -A 10 selector
   ```

### Missing Metrics

1. Verify scrape interval hasn't elapsed:

   ```bash
   KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring deploy/prometheus-operator-kube-p-prometheus \
     -- wget -qO- 'localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.job=="<job>") | .lastScrape'
   ```

2. Check metric exists at source:

   ```bash
   # For Kubernetes services
   KUBECONFIG=$KUBECONFIG kubectl port-forward svc/<service> -n <namespace> 8080:<metrics-port>
   curl localhost:8080/metrics | grep <metric_name>
   ```

3. Verify relabeling isn't dropping metrics:

   ```bash
   KUBECONFIG=$KUBECONFIG kubectl get servicemonitor <name> -n <namespace> -o yaml | grep -A 30 metricRelabelings
   ```

### Dashboard Not Loading

1. Check GrafanaDashboard CR status:

   ```bash
   KUBECONFIG=$KUBECONFIG kubectl describe grafanadashboard <name> -n monitoring
   ```

2. Verify datasource configuration:

   ```bash
   KUBECONFIG=$KUBECONFIG kubectl get grafanadatasources -n monitoring
   ```

3. Check Grafana operator logs:

   ```bash
   KUBECONFIG=$KUBECONFIG kubectl logs -n monitoring -l app.kubernetes.io/name=grafana-operator
   ```

## Metrics Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                        │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │   Prometheus    │◄───│ ServiceMonitors │                     │
│  │   (Thanos)      │    │  PodMonitors    │                     │
│  └────────▲────────┘    └─────────────────┘                     │
│           │                                                      │
│           │ remote_write                                         │
└───────────┼─────────────────────────────────────────────────────┘
            │
┌───────────┼─────────────────────────────────────────────────────┐
│           │              Unraid Server                           │
│  ┌────────┴────────┐                                            │
│  │  Grafana Alloy  │──── scrapes ───► Docker containers         │
│  │  (172.24.0.2)   │                  - node-exporter (host)     │
│  └─────────────────┘                  - cadvisor (containers)    │
│                                       - immich (172.24.0.11)     │
│   alloy-internal network              - gitea (172.24.0.12)      │
│   (172.24.0.0/24)                     - cloudflared (172.24.0.13)│
│                                       - vaultwarden (172.24.0.14)│
│                                       - plex (172.24.0.15)       │
└─────────────────────────────────────────────────────────────────┘
```

## Related Skills

- [docker-metrics](docker-metrics.md) - Adding new Docker metrics targets
- [grafana-dashboards](grafana-dashboards.md) - Managing Grafana dashboards
- [docker-sops-overlay](docker-sops-overlay.md) - Docker Compose secrets management
