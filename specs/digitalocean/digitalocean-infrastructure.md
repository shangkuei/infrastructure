# DigitalOcean Infrastructure Technical Specification

## Document Information

- **Version**: 1.0
- **Last Updated**: 2025-10-21
- **Status**: Active
- **Owner**: Infrastructure Team

## Overview

This document provides detailed technical specifications for DigitalOcean infrastructure components, including resource sizing, networking configuration, security requirements, and integration specifications.

## Infrastructure Requirements

### 1. DOKS (DigitalOcean Kubernetes Service)

#### Cluster Specifications

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Cluster Name** | `production-cluster-nyc3` | Environment and region identifier |
| **Region** | NYC3 (New York City 3) | Low latency for North America users |
| **Kubernetes Version** | 1.28+ | LTS version with security patches |
| **Control Plane** | Managed (HA) | DigitalOcean managed, free tier |
| **Auto-upgrade** | Minor versions only | Prevent breaking changes |
| **Maintenance Window** | Tuesday 03:00-05:00 UTC | Low-traffic period |
| **VPC** | production-vpc-nyc3 | Private networking |

#### Node Pool Specifications

**Production Node Pool**:

| Parameter | Value | Justification |
|-----------|-------|---------------|
| **Pool Name** | production-pool | Clear identifier |
| **Node Count** | 3 | HA quorum (odd number) |
| **Instance Type** | s-2vcpu-2gb | Cost-effective for small workloads |
| **vCPU** | 2 per node | Sufficient for containerized apps |
| **Memory** | 2GB per node | Adequate for typical services |
| **Disk** | 60GB SSD per node | Operating system and ephemeral storage |
| **Auto-scale** | Disabled (manual) | Predictable costs, manual control |
| **Min Nodes** | 3 | Maintain HA |
| **Max Nodes** | 10 | Scale limit to prevent cost overruns |
| **Labels** | environment=production, workload=general | Pod scheduling and organization |
| **Taints** | None | General-purpose nodes |

**Future Node Pools** (planned):

| Pool Name | Instance Type | Use Case | Auto-scale |
|-----------|---------------|----------|------------|
| high-memory-pool | s-2vcpu-4gb | Memory-intensive apps | Yes |
| compute-pool | c-4 (4 vCPU) | CPU-intensive apps | Yes |
| spot-pool | s-2vcpu-2gb | Stateless workloads | Yes |

#### Networking Specifications

| Network | CIDR Range | Purpose | Access |
|---------|------------|---------|--------|
| **VPC** | 10.100.0.0/16 | Private cloud network | Internal |
| **Pod Network** | 10.244.0.0/16 | Kubernetes pod IPs | Internal |
| **Service Network** | 10.245.0.0/16 | Kubernetes service IPs | Internal |
| **Node Subnet** | 10.100.0.0/24 | Worker node IPs | Limited public |

#### Add-ons and Integrations

| Component | Version | Configuration | Purpose |
|-----------|---------|---------------|---------|
| **CNI** | Cilium (DO managed) | Default | Pod networking |
| **CSI** | DigitalOcean Block Storage | v4.x | Persistent volumes |
| **CoreDNS** | 1.9+ | Default | Service discovery |
| **Metrics Server** | Latest | Enabled | Resource metrics |
| **DO Monitoring** | N/A | Enabled | Basic cluster metrics |

### 2. Virtual Private Cloud (VPC)

#### VPC Configuration

```hcl
resource "digitalocean_vpc" "production" {
  name        = "production-vpc-nyc3"
  region      = "nyc3"
  description = "Production VPC for Kubernetes and databases"
  ip_range    = "10.100.0.0/16"
}
```

**Specifications**:

| Parameter | Value | Notes |
|-----------|-------|-------|
| **IP Range** | 10.100.0.0/16 | 65,534 usable IPs |
| **Region** | NYC3 | Same as cluster |
| **Subnets** | Auto-managed | DigitalOcean assigns |
| **DNS** | DigitalOcean managed | Automatic |
| **Routing** | Private | No internet gateway needed |

#### Subnet Allocation

| Subnet | CIDR | Purpose | Size |
|--------|------|---------|------|
| Kubernetes Nodes | 10.100.0.0/24 | DOKS worker nodes | 254 IPs |
| Databases | 10.100.10.0/24 | Managed databases | 254 IPs |
| Reserved | 10.100.20.0/22 | Future expansion | 1,022 IPs |
| Unallocated | 10.100.24.0/19 | Growth | ~8,000 IPs |

### 3. Load Balancer

#### Load Balancer Specifications

| Parameter | Value | Configuration |
|-----------|-------|---------------|
| **Type** | DigitalOcean Managed | Automatic via K8s Service |
| **Algorithm** | Round robin | Default, can be changed |
| **Forwarding Rules** | HTTP (80), HTTPS (443) | Defined in Service |
| **Health Check Protocol** | HTTP | Configurable |
| **Health Check Path** | /healthz | Application endpoint |
| **Health Check Interval** | 10 seconds | Default |
| **Health Check Timeout** | 5 seconds | Default |
| **Unhealthy Threshold** | 3 failures | Mark node unhealthy |
| **Healthy Threshold** | 2 successes | Mark node healthy |
| **Sticky Sessions** | Disabled | Stateless applications |
| **Proxy Protocol** | Disabled | Not needed with Cloudflare |
| **SSL Termination** | Disabled | Handled by Cloudflare |

#### Kubernetes Service Annotations

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  annotations:
    service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-algorithm: "round_robin"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-port: "80"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-path: "/healthz"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-interval-seconds: "10"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-timeout-seconds: "5"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-unhealthy-threshold: "3"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-healthy-threshold: "2"
spec:
  type: LoadBalancer
  ports:
    - name: http
      port: 80
      targetPort: 80
    - name: https
      port: 443
      targetPort: 443
  selector:
    app.kubernetes.io/name: ingress-nginx
```

### 4. Managed Database (PostgreSQL)

#### Database Cluster Specifications

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Engine** | PostgreSQL | Application requirement |
| **Version** | 15.x | Latest stable version |
| **Size** | db-s-1vcpu-1gb | Cost-effective for small workloads |
| **Node Count** | 1 (2 for HA) | Single node initially, upgrade if needed |
| **vCPU** | 1 | Sufficient for low-traffic apps |
| **Memory** | 1GB | Basic tier |
| **Storage** | 10GB | Auto-expands as needed |
| **Max Connections** | 25 | Basic tier limit |
| **Region** | NYC3 | Same as cluster |
| **VPC** | production-vpc-nyc3 | Private networking |

#### High Availability Configuration

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Standby Node** | Optional | +$15/month |
| **Failover** | Automatic | <60 seconds |
| **Replication** | Synchronous | No data loss on failover |
| **Read Replicas** | 0 | Add if read-heavy workload |

#### Backup Configuration

| Parameter | Value | Configuration |
|-----------|-------|---------------|
| **Backup Frequency** | Daily | Automated |
| **Backup Time** | 02:00-04:00 UTC | Low-traffic period |
| **Retention** | 7 days | Basic tier |
| **Point-in-Time Recovery** | Available | Last 7 days |
| **Backup Location** | Same region | Automatic |
| **Manual Backups** | Supported | Via API/CLI |

#### Connection Pool Configuration

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Pooler** | PgBouncer | Built-in |
| **Mode** | Transaction | Default |
| **Max Client Connections** | 25 | Same as database |
| **Pool Size** | 20 | Per user |
| **Reserve Pool** | 5 | Emergency connections |

#### Security Configuration

| Parameter | Value | Enforcement |
|-----------|-------|-------------|
| **TLS** | Required | Enforced |
| **TLS Version** | 1.2+ | Minimum |
| **Certificate Verification** | CA verified | Recommended |
| **Firewall** | VPC only | No public access |
| **Allowed Sources** | DOKS cluster | Kubernetes nodes only |
| **User Authentication** | Password | Strong passwords enforced |

#### Connection String Format

```
# Standard connection
postgresql://username:password@host:25060/database?sslmode=require

# Connection pool
postgresql://username:password@host:25061/database?sslmode=require

# Read replica (if configured)
postgresql://username:password@replica-host:25060/database?sslmode=require
```

### 5. Spaces (Object Storage)

#### Spaces Configuration

**Terraform State Space**:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| **Name** | terraform-state-nyc3 | Terraform backend |
| **Region** | NYC3 | Same as cluster |
| **ACL** | Private | No public access |
| **Versioning** | Enabled | State history |
| **Lifecycle** | None | Keep all versions |
| **Size Limit** | 250GB | Included in $5/mo |
| **CDN** | Disabled | Not needed |

**Application Data Space**:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| **Name** | app-data-nyc3 | User uploads, assets |
| **Region** | NYC3 | Same as cluster |
| **ACL** | Private | Signed URLs for access |
| **Versioning** | Disabled | Not needed |
| **Lifecycle** | 90 days | Delete old files |
| **Size Limit** | 250GB | Included in $5/mo |
| **CDN** | Enabled | Faster delivery |
| **CORS** | Configured | Web access |

**Backup Space**:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| **Name** | backups-nyc3 | Velero backups |
| **Region** | NYC3 | Same as cluster |
| **ACL** | Private | No public access |
| **Versioning** | Enabled | Backup integrity |
| **Lifecycle** | 30 days | Auto-delete old backups |
| **Size Limit** | 250GB | Included in $5/mo |
| **CDN** | Disabled | Not needed |

#### CORS Configuration (App Data Space)

```json
{
  "CORSRules": [
    {
      "AllowedOrigins": ["https://example.com"],
      "AllowedMethods": ["GET", "PUT", "POST"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3600
    }
  ]
}
```

#### Lifecycle Policy (App Data Space)

```json
{
  "Rules": [
    {
      "ID": "delete-old-files",
      "Status": "Enabled",
      "Prefix": "uploads/",
      "Expiration": {
        "Days": 90
      }
    }
  ]
}
```

### 6. Container Registry

#### Registry Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Name** | production-registry | Unique identifier |
| **Region** | NYC3 | Same as cluster |
| **Tier** | Basic | $5/month |
| **Storage** | 500GB | Included in tier |
| **Additional Storage** | $0.02/GB/month | If needed |
| **Vulnerability Scanning** | Enabled | Trivy integration |
| **Garbage Collection** | Weekly | Clean unused images |
| **Access** | Private | Token-based auth |

#### Image Naming Convention

```
registry.digitalocean.com/production-registry/[app-name]:[tag]

Examples:
- registry.digitalocean.com/production-registry/web-app:v1.2.3
- registry.digitalocean.com/production-registry/api-server:main-abc123
- registry.digitalocean.com/production-registry/worker:latest
```

#### Garbage Collection Policy

| Policy | Value | Purpose |
|--------|-------|---------|
| **Schedule** | Weekly (Sunday 02:00 UTC) | Off-peak time |
| **Retention** | Keep last 10 tags | Rollback capability |
| **Untagged** | Delete after 7 days | Clean dangling images |
| **Failed Scans** | Keep | Manual review |

### 7. Block Storage (Volumes)

#### Volume Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Type** | SSD | Default |
| **Minimum Size** | 1GB | DO minimum |
| **Maximum Size** | 16TB | Per volume |
| **Pricing** | $0.10/GB/month | Standard rate |
| **Snapshot Pricing** | $0.05/GB/month | Backup copies |
| **IOPS** | Best effort | No guaranteed IOPS |
| **Throughput** | Shared | Not dedicated |
| **Encryption** | At rest | Automatic |

#### StorageClass Configuration

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: do-block-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: dobs.csi.digitalocean.com
parameters:
  type: pd-ssd
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

#### Volume Usage Guidelines

| Use Case | Recommended Size | Access Mode | Reclaim Policy |
|----------|------------------|-------------|----------------|
| **Database** | 20-100GB | ReadWriteOnce | Retain |
| **Application Data** | 10-50GB | ReadWriteOnce | Delete |
| **Logs** | 10-20GB | ReadWriteOnce | Delete |
| **Media** | 50-500GB | ReadWriteOnce | Retain |

### 8. Cloud Firewalls

#### Firewall Rules Specifications

**Kubernetes Cluster Firewall**:

| Direction | Protocol | Port Range | Source/Destination | Purpose |
|-----------|----------|------------|-------------------|---------|
| **Inbound** | TCP | 80 | 0.0.0.0/0, ::/0 | HTTP traffic |
| **Inbound** | TCP | 443 | 0.0.0.0/0, ::/0 | HTTPS traffic |
| **Inbound** | TCP | 22 | Management IPs | SSH (emergency) |
| **Inbound** | TCP | 1-65535 | tag:kubernetes | Inter-node communication |
| **Inbound** | UDP | 1-65535 | tag:kubernetes | Inter-node communication |
| **Inbound** | ICMP | N/A | tag:kubernetes | Health checks |
| **Outbound** | TCP | 1-65535 | 0.0.0.0/0, ::/0 | All outbound |
| **Outbound** | UDP | 1-65535 | 0.0.0.0/0, ::/0 | All outbound |

**Database Firewall**:

| Direction | Protocol | Port Range | Source/Destination | Purpose |
|-----------|----------|------------|-------------------|---------|
| **Inbound** | TCP | 25060 | k8s:cluster-id | PostgreSQL from cluster |
| **Inbound** | DENY | ALL | ALL | Deny all other traffic |

## Performance Requirements

### Service Level Objectives (SLOs)

| Service | Metric | Target | Measurement |
|---------|--------|--------|-------------|
| **Kubernetes API** | Availability | 99.9% | Monthly uptime |
| **Kubernetes API** | Latency (p95) | <500ms | API response time |
| **Worker Nodes** | Availability | 99.9% | Per node uptime |
| **Load Balancer** | Availability | 99.99% | DigitalOcean SLA |
| **Database** | Availability | 99.9% (99.99% with HA) | Monthly uptime |
| **Database** | Latency (p95) | <100ms | Query response time |
| **Object Storage** | Availability | 99.9% | Monthly uptime |
| **Object Storage** | Throughput | >10MB/s | Upload/download speed |

### Resource Limits

| Resource | Limit | Enforcement | Action on Breach |
|----------|-------|-------------|------------------|
| **Cluster Nodes** | 10 nodes | Manual | Require approval |
| **Load Balancers** | 5 LBs | Manual | Require approval |
| **Databases** | 5 clusters | Manual | Require approval |
| **Spaces** | 5 spaces | Manual | Require approval |
| **Block Storage** | 1TB total | Monitoring | Alert at 800GB |
| **Monthly Cost** | $500 | Billing alerts | Alert at $400 |

## Security Requirements

### Access Control

| Component | Authentication | Authorization | Encryption |
|-----------|----------------|---------------|------------|
| **Kubernetes API** | Certificate-based | RBAC | TLS 1.2+ |
| **Database** | Password | PostgreSQL roles | TLS required |
| **Spaces** | API token | Bucket policies | HTTPS only |
| **Container Registry** | API token | Registry permissions | HTTPS only |
| **doctl CLI** | API token | Account-level | HTTPS only |

### Network Security

| Layer | Control | Implementation |
|-------|---------|----------------|
| **Perimeter** | Cloudflare WAF/DDoS | DNS-level protection |
| **Network** | Cloud Firewalls | IP-based filtering |
| **VPC** | Private networking | Isolated VPC |
| **Pod** | Network Policies | Kubernetes NetworkPolicy |
| **Application** | TLS | Certificate-based |

### Compliance

| Requirement | Implementation | Verification |
|-------------|----------------|--------------|
| **Encryption at Rest** | Enabled for all services | DigitalOcean default |
| **Encryption in Transit** | TLS 1.2+ mandatory | Configuration enforcement |
| **Access Logging** | Enabled for critical services | Kubernetes audit logs |
| **Vulnerability Scanning** | Enabled for container images | Trivy in registry |
| **Secret Management** | Kubernetes Secrets + Sealed Secrets | Git encryption |
| **Backup Encryption** | Enabled | Automatic |

## Integration Specifications

### Cloudflare Integration

| Integration Point | Configuration | Purpose |
|-------------------|---------------|---------|
| **DNS** | A records point to LB IP | Domain resolution |
| **Proxy** | Enabled (orange cloud) | DDoS protection, CDN |
| **SSL/TLS Mode** | Full (Strict) | End-to-end encryption |
| **Load Balancing** | Failover to on-premise | Disaster recovery |
| **Firewall** | WAF rules enabled | Application security |

### GitHub Actions Integration

| Integration | Configuration | Authentication |
|-------------|---------------|----------------|
| **DOKS Access** | kubeconfig in secrets | Service account token |
| **Registry Access** | Token in secrets | DigitalOcean API token |
| **Terraform** | State in DO Spaces | Spaces access key |
| **Deployments** | ArgoCD webhook | GitHub App |

### Tailscale Integration

| Component | Configuration | Purpose |
|-----------|---------------|---------|
| **Kubernetes Nodes** | Tailscale sidecar | Hybrid connectivity |
| **VPC** | Subnet routes advertised | On-premise access |
| **ACLs** | Allow on-premise → cluster | Secure access |

## Monitoring and Observability

### Metrics Collection

| Source | Collector | Storage | Retention |
|--------|-----------|---------|-----------|
| **Cluster** | Prometheus | PVC | 30 days |
| **Nodes** | node-exporter | Prometheus | 30 days |
| **Pods** | cAdvisor | Prometheus | 30 days |
| **Database** | postgres-exporter | Prometheus | 30 days |

### Logging

| Source | Collector | Storage | Retention |
|--------|-----------|---------|-----------|
| **Application** | Loki | DO Spaces | 60 days |
| **Kubernetes** | Loki | DO Spaces | 60 days |
| **Ingress** | Loki | DO Spaces | 30 days |

### Alerting

| Alert | Severity | Threshold | Action |
|-------|----------|-----------|--------|
| **Node Down** | Critical | 1 node | Page on-call |
| **High CPU** | Warning | 80% for 5min | Notify team |
| **High Memory** | Warning | 80% for 5min | Notify team |
| **Database Down** | Critical | Connection failure | Page on-call |
| **High Costs** | Warning | >$400/month | Email team |

## Disaster Recovery

### Backup Specifications

| Component | Method | Frequency | Retention | Location |
|-----------|--------|-----------|-----------|----------|
| **Cluster State** | Velero | Daily | 30 days | DO Spaces |
| **Database** | Managed backups | Daily | 7 days | Same region |
| **Database (manual)** | pg_dump | Weekly | 30 days | DO Spaces |
| **Terraform State** | Versioned | On change | All versions | DO Spaces |

### Recovery Objectives

| Scenario | RTO | RPO | Procedure |
|----------|-----|-----|-----------|
| **Single Node Failure** | 5 minutes | 0 | Auto-recovery |
| **Database Failure** | 2 minutes | 0 | Auto-failover (HA) |
| **Cluster Failure** | 2-4 hours | 24 hours | Velero restore |
| **Region Outage** | 4-8 hours | 24 hours | Failover to on-premise |

## Cost Management

### Budget Allocation

| Component | Monthly Budget | Notes |
|-----------|----------------|-------|
| **DOKS Cluster** | $54 | 3 nodes × $18 |
| **Load Balancer** | $10 | 1 LB |
| **Database** | $15-30 | Basic or HA |
| **Container Registry** | $5 | Basic tier |
| **Spaces** | $15 | 3 spaces × $5 |
| **Block Storage** | $2-10 | Variable usage |
| **Bandwidth** | $0 | Included (5TB) |
| **Total** | **$101-121** | Production baseline |

### Cost Optimization

| Strategy | Savings | Implementation |
|----------|---------|----------------|
| **Free Control Plane** | $73/month | Use DOKS not EKS |
| **Right-sized Nodes** | $20-40/month | Start small, scale up |
| **Lifecycle Policies** | $5-10/month | Auto-delete old data |
| **Reserved Instances** | N/A | Not available on DO |
| **Spot Instances** | N/A | Not available on DO |

## References

- [ADR-0013: DigitalOcean as Primary Cloud Provider](../../docs/decisions/0013-digitalocean-primary-cloud.md)
- [Architecture: DigitalOcean Infrastructure](../../docs/architecture/0002-digitalocean-infrastructure.md)
- [Runbook: DigitalOcean Operations](../../docs/runbooks/0006-digitalocean-operations.md)
- [DigitalOcean API Documentation](https://docs.digitalocean.com/reference/api/)
- [DOKS Specifications](https://docs.digitalocean.com/products/kubernetes/details/pricing/)
- [Database Specifications](https://docs.digitalocean.com/products/databases/postgresql/)
- [Spaces Specifications](https://docs.digitalocean.com/products/spaces/)
