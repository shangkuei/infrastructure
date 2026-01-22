# Node Exporter - shangkuei-xyz-unraid

Host metrics exporter deployment for Unraid.

## Overview

This overlay deploys Prometheus Node Exporter to collect host-level metrics (CPU, memory, disk, network) on the Unraid server. Metrics are scraped by Alloy via the internal network.

## Quick Start

```bash
# Start Node Exporter
make up

# Check metrics
make test-metrics
```

## Verification

```bash
# Check container is running
docker ps | grep node-exporter

# View logs
make logs

# Test metrics endpoint (via docker exec)
docker exec node-exporter wget -qO- http://localhost:9100/metrics | grep node_cpu
```

## Unraid-Specific Configuration

This overlay includes fixes for Unraid compatibility:

- **Volume mounts**: Overrides the base `rslave` mount propagation which isn't supported on Unraid. Uses individual mounts for `/proc`, `/sys`, and `/` instead.
- **No port exposure**: Ports are not exposed to host. Alloy scrapes via `alloy-internal` network.

## Integration

Node Exporter metrics are scraped by Alloy via the shared `alloy-internal` network. The metrics are forwarded to the central Prometheus instance.

## Files

- `Makefile` - Docker compose operations
- `docker-compose.override.yml` - Unraid-specific overrides
- `../../../base/node-exporter/docker-compose.yml` - Base configuration

## Related Issues

- [SHA-48](https://linear.app/shangkuei/issue/SHA-48) - Install Node Exporter on Unraid
