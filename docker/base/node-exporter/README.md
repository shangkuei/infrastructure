# Prometheus Node Exporter

Host-level metrics exporter for Prometheus.

## Overview

Node Exporter exposes hardware and OS metrics from the host system. It runs as a container with access to host namespaces and filesystems to collect accurate metrics.

## Metrics Exposed

| Metric Prefix | Description |
|---------------|-------------|
| `node_cpu_*` | CPU usage statistics |
| `node_memory_*` | Memory usage statistics |
| `node_disk_*` | Disk I/O statistics |
| `node_filesystem_*` | Filesystem usage |
| `node_network_*` | Network interface statistics |
| `node_load*` | System load averages |
| `node_boot_time_seconds` | System boot time |
| `node_uname_info` | System information |

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `:9100/metrics` | Prometheus metrics endpoint |
| `:9100/` | Landing page with link to metrics |

## Quick Start

```bash
# Navigate to overlay
cd docker/overlays/node-exporter/shangkuei-xyz-unraid

# Start services
make up

# Verify metrics
curl http://localhost:9100/metrics | head -50
```

## Verify Metrics

```bash
# Check node-exporter is running
docker logs node-exporter

# Query specific metrics
curl -s http://localhost:9100/metrics | grep node_cpu_seconds_total | head -5
curl -s http://localhost:9100/metrics | grep node_memory_MemTotal_bytes
curl -s http://localhost:9100/metrics | grep node_filesystem_size_bytes | head -5
```

## Integration with Alloy

Node Exporter metrics can be scraped by Alloy and forwarded to Prometheus:

```alloy
prometheus.scrape "node_exporter" {
  targets = [{
    __address__ = "node-exporter:9100",
  }]
  forward_to = [prometheus.remote_write.default.receiver]
  job_name   = "node-exporter"
}
```

## Container Configuration

The container uses:

- `pid: host` - Access to host PID namespace for process metrics
- `/:/host:ro,rslave` - Read-only access to host filesystem
- `--path.rootfs=/host` - Tell node_exporter where host root is mounted

## Files

- `docker-compose.yml` - Base compose configuration

## Related

- [Node Exporter GitHub](https://github.com/prometheus/node_exporter)
- [Node Exporter Collectors](https://github.com/prometheus/node_exporter#collectors)
- [Prometheus Node Exporter Guide](https://prometheus.io/docs/guides/node-exporter/)
