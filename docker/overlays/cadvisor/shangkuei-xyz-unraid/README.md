# cAdvisor - shangkuei-xyz-unraid

Container metrics exporter deployment for Unraid.

## Overview

This overlay deploys cAdvisor to collect Docker container metrics on the Unraid server. Metrics are scraped by Alloy via the internal network.

## Quick Start

```bash
# Start cAdvisor
make up

# Verify health
make test-health

# Check metrics
make test-metrics
```

## Verification

```bash
# Check container is running
docker ps | grep cadvisor

# View logs
make logs

# Test metrics endpoint (via docker exec)
docker exec cadvisor wget -qO- http://localhost:8080/metrics | grep container_cpu
```

## Unraid-Specific Configuration

This overlay includes fixes for Unraid compatibility:

- **No port exposure**: Ports are not exposed to host. Alloy scrapes via `alloy-internal` network.
- **Network**: Joins the `alloy-internal` network for metrics scraping by Alloy.

## Integration

cAdvisor metrics are scraped by Alloy via the shared `alloy-internal` network (internal port 8080). The metrics are forwarded to the central Prometheus instance.

## Files

- `Makefile` - Docker compose operations
- `docker-compose.override.yml` - Unraid-specific overrides
- `../../../base/cadvisor/docker-compose.yml` - Base configuration

## Related Issues

- [SHA-49](https://linear.app/shangkuei/issue/SHA-49) - Deploy cAdvisor container on Unraid
