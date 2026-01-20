# Grafana Alloy

Unified telemetry agent for collecting metrics and logs from Docker hosts.

## Overview

Alloy collects:

- **Docker container logs** - via Docker socket
- **Metrics** - from node_exporter, cAdvisor, and services (future)

All data is pushed to centralized Prometheus and Loki instances via Tailscale.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Unraid Host                              │
│                                                               │
│  ┌─────────────┐     ┌──────────────────────────────────┐   │
│  │   Docker    │     │           Alloy                   │   │
│  │  Containers │────▶│  • Docker log discovery           │   │
│  │             │     │  • Log processing & enrichment    │   │
│  └─────────────┘     │  • Metrics scraping (future)      │   │
│                      └──────────────┬───────────────────┘   │
│                                     │                        │
└─────────────────────────────────────┼────────────────────────┘
                                      │ Tailscale
                      ┌───────────────┴───────────────┐
                      │                               │
               ┌──────▼──────┐               ┌───────▼───────┐
               │    Loki     │               │  Prometheus   │
               │  (logs)     │               │  (metrics)    │
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
