# cAdvisor

Container Advisor for analyzing resource usage and performance of running containers.

## Overview

cAdvisor (Container Advisor) provides container users an understanding of the resource usage and
performance characteristics of their running containers. It is a daemon that collects, aggregates,
processes, and exports information about running containers.

## Metrics Exposed

| Metric Prefix | Description |
|---------------|-------------|
| `container_cpu_*` | Container CPU usage |
| `container_memory_*` | Container memory usage |
| `container_network_*` | Container network I/O |
| `container_fs_*` | Container filesystem usage |
| `container_spec_*` | Container specifications |
| `machine_*` | Host machine metrics |

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `:8080/` | Web UI for browsing containers |
| `:8080/metrics` | Prometheus metrics endpoint |
| `:8080/healthz` | Health check endpoint |
| `:8080/api/v1.3/containers` | JSON API for container info |

## Quick Start

```bash
# Navigate to overlay
cd docker/overlays/cadvisor/shangkuei-xyz-unraid

# Start services
make up

# Verify metrics
curl http://localhost:8080/healthz
curl http://localhost:8080/metrics | head -50
```

## Verify Metrics

```bash
# Check cAdvisor is running
docker logs cadvisor

# Query specific metrics
curl -s http://localhost:8080/metrics | grep container_cpu_usage_seconds_total | head -5
curl -s http://localhost:8080/metrics | grep container_memory_usage_bytes | head -5
```

## Integration with Alloy

cAdvisor metrics can be scraped by Alloy and forwarded to Prometheus. Add the following to your Alloy configuration:

```alloy
prometheus.scrape "cadvisor" {
  targets = [{
    __address__ = "cadvisor:8080",
  }]
  forward_to = [prometheus.remote_write.default.receiver]
  job_name   = "cadvisor"
  metrics_path = "/metrics"
}
```

## Files

- `docker-compose.yml` - Base compose configuration

## Related

- [cAdvisor GitHub](https://github.com/google/cadvisor)
- [cAdvisor Metrics](https://github.com/google/cadvisor/blob/master/docs/storage/prometheus.md)
- [Prometheus cAdvisor Metrics](https://prometheus.io/docs/guides/cadvisor/)
