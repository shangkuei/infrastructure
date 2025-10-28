# Research: Log Aggregation Solutions

Date: 2025-10-18
Author: Infrastructure Team
Status: Completed

## Objective

Evaluate centralized logging solutions for Kubernetes and infrastructure.

## Findings

| Solution | Cost | Complexity | Storage | Best For |
|----------|------|------------|---------|----------|
| **Loki** | Free | Low | S3/Spaces | Grafana users |
| **ELK Stack** | Free | High | Elasticsearch | Full-text search |
| **Fluentd + Loki** | Free | Medium | S3/Spaces | Cloud-native |

## Recommendation

**Grafana Loki**:

- Integrates with Grafana (same UI as metrics)
- Cost-effective (S3/Spaces storage)
- LogQL query language
- Low operational overhead

**Deployment**:

```bash
# Install Loki + Promtail
helm install loki grafana/loki-stack \
  --set grafana.enabled=false \
  --set prometheus.enabled=false
```

**Why not ELK**:

- Elasticsearch resource-intensive (2GB+ RAM)
- Complex to operate
- Expensive at scale

## Outcome

Deployed Loki for centralized logging.

## References

- [Grafana Loki](https://grafana.com/oss/loki/)
