# Grafana Alloy

Unified telemetry agent for collecting metrics and logs from Docker hosts.

## Overview

Alloy collects:

- **Docker container logs** - via Docker socket, pushed to Loki
- **Host metrics** - from Node Exporter (CPU, memory, disk, network)
- **Container metrics** - from cAdvisor (container resource usage)

All data is pushed to centralized Prometheus and Loki instances via Tailscale.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Unraid Host                              │
│                                                                  │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────────┐│
│  │   Docker    │  │ Node Exporter│  │          Alloy           ││
│  │  Containers │  │   :9100      │  │  • Docker log discovery  ││
│  │             │  └──────┬───────┘  │  • Log processing        ││
│  └──────┬──────┘         │          │  • Metrics scraping      ││
│         │          ┌─────┴────┐     │    - node-exporter       ││
│         │          │ cAdvisor │     │    - cAdvisor            ││
│         └──────────│  :8080   │─────│    - self (:12345)       ││
│                    └──────────┘     └────────────┬─────────────┘│
│                                                  │              │
└──────────────────────────────────────────────────┼──────────────┘
                                                   │ Tailscale
                                   ┌───────────────┴───────────────┐
                                   │                               │
                            ┌──────▼──────┐               ┌───────▼───────┐
                            │    Loki     │               │  Prometheus   │
                            │   (logs)    │               │  (metrics)    │
                            └─────────────┘               └───────────────┘
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLUSTER_NAME` | `shangkuei-unraid` | Cluster identifier for multi-cluster support |
| `LOKI_URL` | `http://loki/loki/api/v1/push` | Loki push endpoint (via Tailscale) |
| `LOKI_TENANT_ID` | `shangkuei-lab` | Loki tenant ID for multi-tenancy |
| `PROMETHEUS_URL` | `http://prometheus:9090/api/v1/write` | Prometheus remote_write endpoint |
| `HOSTNAME` | `unraid` | Host identifier |
| `NODE_EXPORTER_URL` | `node-exporter:9100` | Node Exporter scrape target (via alloy-internal network) |
| `CADVISOR_URL` | `cadvisor:8080` | cAdvisor scrape target (via alloy-internal network) |

## Self-Monitoring

Alloy is configured to scrape its own metrics from `localhost:12345/metrics` for self-monitoring. This enables:

- **Component health tracking**: Monitor running/unhealthy components
- **Scrape statistics**: Track scrape success rates and durations
- **Resource usage**: CPU, memory, goroutines, GC metrics
- **Pipeline metrics**: Loki write and remote write statistics

### Key Metrics

| Metric | Description |
|--------|-------------|
| `alloy_component_controller_running_components` | Number of running components by health status |
| `alloy_component_evaluation_slow_seconds` | Slow component evaluations (used in alerts) |
| `alloy_resources_process_cpu_seconds_total` | CPU usage |
| `alloy_resources_process_resident_memory_bytes` | Memory (RSS) usage |
| `prometheus_target_scrape_*` | Scrape statistics per target |
| `loki_write_*` | Loki write pipeline metrics |

### Grafana Dashboards

Pre-built dashboards are available in the monitoring stack:

- **Alloy / Controller**: Component health and evaluation metrics
- **Alloy / Resources**: CPU, memory, GC, and goroutine metrics
- **Alloy / Prometheus Remote Write**: Remote write success/failure rates
- **Alloy / Loki**: Loki pipeline metrics

### Alerts

The following alerts are configured via PrometheusRules:

| Alert | Severity | Description |
|-------|----------|-------------|
| `UnhealthyComponents` | warning | Unhealthy components detected |
| `SlowComponentEvaluations` | warning | Component evaluations taking too long |
| `ClusterNotConverging` | warning | Cluster nodes disagree on peer count |
| `ClusterNodeUnhealthy` | warning | High gossip health score |

## Log Labels

Logs are enriched with the following labels:

| Label | Source | Description |
|-------|--------|-------------|
| `cluster` | `CLUSTER_NAME` env | Cluster identifier |
| `host` | `HOSTNAME` env | Host name |
| `container` | Docker metadata | Container name |
| `compose_project` | Docker label | Docker Compose project name |
| `compose_service` | Docker label | Docker Compose service name |
| `job` | Computed | `project/service` or container name |
| `image` | Docker metadata | Container image |
| `level` | Log content | Log level (if parseable) |

## Quick Start

```bash
# Navigate to overlay
cd docker/overlays/alloy/shangkuei-xyz-unraid

# Import Age key
make sops-import-key AGE_KEY_FILE=/path/to/key.txt

# Start services
make up
```

## Verify Logs in Loki

```bash
# Check Alloy is running
docker logs alloy

# Query logs in Grafana
# LogQL: {cluster="shangkuei-unraid"}
```

## Files

- `docker-compose.yml` - Base compose configuration
- `config.alloy` - Alloy configuration (log/metrics collection)

## Related

- [Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Docker Discovery](https://grafana.com/docs/alloy/latest/reference/components/discovery/discovery.docker/)
