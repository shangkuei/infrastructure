# Docker Metrics Configuration Skill

Add Prometheus metrics endpoints to Docker services and configure Grafana Alloy for scraping.

## When to Use

Use this skill when:

- Adding a new service that exposes Prometheus metrics
- Configuring Alloy to scrape metrics from Docker containers
- Setting up Bearer token authentication for metrics endpoints
- Assigning static IPs to services on the alloy-internal network

## Key Files

### Alloy Configuration

- Base config: `docker/base/alloy/config.alloy`
- Base compose: `docker/base/alloy/docker-compose.yml`
- Overlay env: `docker/overlays/alloy/shangkuei-xyz-unraid/.enc.env`
- Example env: `docker/overlays/alloy/shangkuei-xyz-unraid/.env.example`

### Service Overlay Structure

```text
docker/overlays/<service>/shangkuei-xyz-unraid/
├── docker-compose.override.yml          # Non-sensitive overrides
├── docker-compose.override.enc.yml      # SOPS-encrypted overrides
├── .enc.env                              # SOPS-encrypted environment
└── .env.example                          # Example environment template
```

## Workflow

### Step 1: Add Alloy Scrape Config

Edit `docker/base/alloy/config.alloy` to add a new scrape block:

```river
prometheus.scrape "<service_name>" {
  targets = [{
    __address__ = coalesce(env("<SERVICE_URL_VAR>"), ""),
  }]
  forward_to      = [prometheus.relabel.add_labels.receiver]
  job_name        = "<service_name>"
  scrape_interval = "30s"
  metrics_path    = "/metrics"

  // Optional: Add authorization for protected endpoints
  authorization {
    type        = "Bearer"
    credentials = coalesce(env("<SERVICE_TOKEN_VAR>"), "")
  }
}
```

**Important**: Use `coalesce()` instead of ternary operators - River syntax does not support `? :`.

### Step 2: Add Environment Variables

1. Update `docker/base/alloy/docker-compose.yml`:

   ```yaml
   environment:
     - <SERVICE_URL_VAR>=${<SERVICE_URL_VAR>:-}
     - <SERVICE_TOKEN_VAR>=${<SERVICE_TOKEN_VAR>:-}
   ```

2. Update `docker/overlays/alloy/shangkuei-xyz-unraid/.enc.env` (encrypted):

   ```bash
   <SERVICE_URL_VAR>=172.24.0.XX:PORT
   <SERVICE_TOKEN_VAR>=secret-token
   ```

3. Update `docker/overlays/alloy/shangkuei-xyz-unraid/.env.example`:

   ```bash
   <SERVICE_URL_VAR>=172.24.0.XX:PORT
   <SERVICE_TOKEN_VAR>=your-metrics-token
   ```

### Step 3: Configure Service Network

Add the service to the alloy-internal network with a static IP:

```yaml
# docker/overlays/<service>/shangkuei-xyz-unraid/docker-compose.override.yml
services:
  <service>:
    networks:
      <service_network>:
      alloy:
        ipv4_address: 172.24.0.XX  # Pick unused IP in 172.24.0.0/24

networks:
  <service_network>:
  alloy:
    external: true
    name: alloy-internal
```

### Step 4: Handle Tailscale Services

For services using Tailscale sidecar with `network_mode: service:tailscale`:

1. The service cannot directly join alloy-internal network
2. Override the main service's network configuration:

```yaml
# docker-compose.tailscale.override.yml
services:
  <service>:
    ports: !reset
    networks:
      <service_network>:
      alloy:
        ipv4_address: 172.24.0.XX

networks:
  <service_network>:
  alloy:
    external: true
    name: alloy-internal
```

### Step 5: Verify Metrics Collection

```bash
# Check Prometheus targets in Kubernetes
KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring deploy/prometheus-operator-kube-p-prometheus \
  -- wget -qO- 'localhost:9090/api/v1/query?query=up{job="<service_name>"}'

# Count metrics
KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring deploy/prometheus-operator-kube-p-prometheus \
  -- wget -qO- 'localhost:9090/api/v1/query?query=count({job="<service_name>"})'
```

## IP Address Allocation

Current allocations on alloy-internal (172.24.0.0/24):

| IP | Service |
|----|---------|
| 172.24.0.2 | alloy |
| 172.24.0.3 | node-exporter |
| 172.24.0.4-10 | reserved |
| 172.24.0.11 | immich |
| 172.24.0.12 | gitea |
| 172.24.0.13 | cloudflared |
| 172.24.0.14 | vaultwarden (vwmetrics) |
| 172.24.0.15 | plex (plex-media-server-exporter) |

## Grafana Dashboards

Dashboards are stored as GrafanaDashboard CRDs in Kubernetes:

| Dashboard | File | Folder |
|-----------|------|--------|
| Cloudflared | `grafanadashboard-cloudflared.yaml` | Cloudflare |
| Immich | `grafanadashboard-immich.yaml` | Unraid Applications |
| Gitea | `grafanadashboard-gitea.yaml` | Unraid Applications |
| Vaultwarden | `grafanadashboard-vaultwarden.yaml` | Unraid Applications |
| Plex | `grafanadashboard-plex.yaml` | Unraid Applications |

Location: `kubernetes/overlays/monitor-cluster/shangkuei-lab/grafanadashboards/`

## Metric Filtering

To reduce cardinality, add relabel filters that keep only dashboard-used metrics.

### Alloy Filter Example (config.alloy)

```river
prometheus.scrape "<service>" {
  targets = [{ __address__ = coalesce(env("<SERVICE_URL>"), "") }]
  forward_to      = [prometheus.relabel.<service>_filter.receiver]
  job_name        = "<service>"
}

prometheus.relabel "<service>_filter" {
  forward_to = [prometheus.relabel.add_labels.receiver]

  rule {
    source_labels = ["__name__"]
    regex         = "(metric1|metric2|metric3.*|up)"
    action        = "keep"
  }
}
```

### Kubernetes PodMonitor Filter Example

```yaml
metricRelabelings:
  - action: keep
    regex: (metric1|metric2|metric3.*|up)
    sourceLabels:
      - __name__
```

**Best Practice**: Use `keep` action with an explicit list of needed metrics rather than `drop` action. This ensures consistency between Docker and Kubernetes filtering.

## Common Issues

### River Syntax Errors

- **Wrong**: `condition ? value1 : value2`
- **Correct**: `coalesce(env("VAR"), "")`

### Tailscale Network Conflicts

Services using `network_mode: service:tailscale` cannot join additional networks. Instead, configure the main service to use both the service network and alloy network explicitly.

### Connection Refused Errors

If the Tailscale sidecar shows `dial tcp [::1]:PORT: connect: connection refused`:

1. Ensure the main service and Tailscale sidecar share a common network
2. Add `depends_on` in the encrypted compose file
3. Verify the service network is declared in networks section
