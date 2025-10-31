# Oracle Cloud Infrastructure Technical Specification

## Document Information

- **Version**: 1.0
- **Last Updated**: 2025-10-28
- **Status**: Active
- **Owner**: Infrastructure Team

## Overview

This document provides detailed technical specifications for Oracle Cloud Infrastructure (OCI) components within the
Always Free tier, including resource sizing, networking configuration, security requirements, and integration
specifications.

**Primary Use Case**: Cost-effective Kubernetes infrastructure using Oracle Cloud Always Free tier ($0/month) with DigitalOcean as secondary provider for scaling and enterprise features.

## Always Free Tier Limits

### Compute Resources (Ampere A1)

| Resource | Always Free Limit | Unit | Notes |
|----------|-------------------|------|-------|
| **OCPUs** | 4 | Cores | Arm-based Ampere A1 |
| **Memory** | 24 | GB | Allocated with OCPUs |
| **OCPU Hours** | 3,000 | Hours/month | Sufficient for 4 always-on cores |
| **Instances** | Up to 4 | VMs | Flexible allocation |
| **Shape** | VM.Standard.A1.Flex | - | Flexible OCPU/memory ratio |

### Storage Resources

| Resource | Always Free Limit | Unit | Notes |
|----------|-------------------|------|-------|
| **Block Storage** | 200 | GB | SSD, encrypted at rest |
| **Block Volumes** | 5 | Volumes | Individual volumes |
| **Object Storage** | 20 | GB | S3-compatible API |
| **Archive Storage** | 20 | GB | Cold storage |
| **Backups** | 200 | GB | Same as block storage |

### Networking Resources

| Resource | Always Free Limit | Unit | Notes |
|----------|-------------------|------|-------|
| **Outbound Transfer** | 10 | TB/month | Per month |
| **VCNs** | Unlimited | - | Virtual Cloud Networks |
| **Load Balancers** | 1 | Instance | Flexible NLB @ 10 Mbps |
| **Public IPs** | 2 | Reserved | Ephemeral IPs free |

### Additional Services

| Service | Always Free Limit | Notes |
|---------|-------------------|-------|
| **Autonomous Database** | 2 databases × 20GB | OCPU limited, optional |
| **Monitoring** | 500M ingestion, 1B retrieval | Per month |
| **Notifications** | 1M per month | Email/SMS/HTTPS |
| **Logging** | 10GB/month | Audit and service logs |

## Infrastructure Requirements

### 1. OKE (Oracle Kubernetes Engine)

#### Cluster Specifications

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Cluster Name** | `production-cluster-phoenix-1` | Environment and region identifier |
| **Region** | us-phoenix-1 or us-ashburn-1 | Arm instance availability |
| **Kubernetes Version** | 1.28+ | LTS version with security patches |
| **Control Plane** | Managed (HA, Regional) | Oracle managed, free with Always Free |
| **Cluster Type** | Basic Cluster | Free tier compatible |
| **Kubernetes API Endpoint** | Public | Can be private if VPN configured |
| **CNI Plugin** | VCN-Native Pod Networking | Recommended for cloud integration |
| **Auto-upgrade** | Enabled (minor versions) | Security patches automatic |
| **Maintenance Window** | Tuesday 03:00-05:00 UTC | Low-traffic period |

#### Node Pool Specifications

**Production Node Pool (Always Free Configuration)**:

| Parameter | Value | Justification |
|-----------|-------|---------------|
| **Pool Name** | production-pool-a1 | Clear identifier |
| **Node Count** | 2 | Cost-free HA configuration |
| **Shape** | VM.Standard.A1.Flex | Arm-based, free tier |
| **OCPUs per Node** | 2 | Balanced configuration |
| **Memory per Node** | 12 GB | 1:6 OCPU:memory ratio |
| **Total Resources** | 4 OCPUs, 24 GB | Maximizes free tier |
| **Boot Volume** | 50 GB | Per node, from block storage quota |
| **Image** | Oracle Linux 8 (arm64) | OCI optimized, free tier compatible |
| **SSH Access** | Via SSH keys | Secure access only |
| **Placement** | Fault Domain distributed | Automatic HA |
| **Auto-scale** | Disabled | Fixed size within free tier |
| **Labels** | environment=production, arch=arm64 | Pod scheduling |
| **Taints** | None | General-purpose nodes |

**Alternative Configurations**:

| Configuration | Nodes | OCPU/Node | Memory/Node | Use Case |
|---------------|-------|-----------|-------------|----------|
| **High Density** | 1 | 4 | 24 GB | Single large node |
| **Balanced** | 2 | 2 | 12 GB | Recommended (HA) |
| **Distributed** | 3 | 1-2 | 6-8 GB | More failure domains |
| **Max Nodes** | 4 | 1 | 6 GB | Testing/development |

#### Networking Specifications

| Network | CIDR Range | Purpose | Access |
|---------|------------|---------|--------|
| **VCN** | 10.0.0.0/16 | Private cloud network | Internal |
| **K8s Subnet (Public)** | 10.0.10.0/24 | Worker nodes | Internet via IGW |
| **K8s Subnet (Private)** | 10.0.20.0/24 | Worker nodes (optional) | NAT Gateway |
| **Pod Network (CNI)** | 10.244.0.0/16 | Pod IPs (VCN-Native) | Internal |
| **Service Network** | 10.96.0.0/16 | Service IPs | Internal |
| **Load Balancer Subnet** | 10.0.30.0/24 | Public LB | Internet via IGW |

#### CNI Plugin Configuration

**VCN-Native Pod Networking (Recommended)**:

```yaml
cni_type: OCI_VCN_IP_NATIVE
pod_subnet: 10.244.0.0/16
security_list: allow_all_internal
service_lb_subnet: 10.0.30.0/24
```

**Advantages**:

- Pods get real VCN IP addresses
- Direct routing, no overlay overhead
- Integration with OCI services
- Support for Network Security Groups
- Lower latency and better performance

**Flannel CNI (Alternative)**:

```yaml
cni_type: FLANNEL_OVERLAY
pod_cidr: 10.244.0.0/16
```

**Use Cases**:

- IP address conservation
- Simple development environments
- Isolated pod network

#### Add-ons and Integrations

| Component | Version | Configuration | Purpose |
|-----------|---------|---------------|---------|
| **CNI** | VCN-Native | Default | Pod networking |
| **CSI** | OCI Block Volume | v2.0+ | Persistent volumes |
| **CoreDNS** | 1.9+ | Default | Service discovery |
| **Metrics Server** | Latest | Enabled | Resource metrics |
| **OCI Monitoring** | Built-in | Enabled | Cluster metrics (free) |
| **OCI Logging** | Built-in | Enabled | Cluster logs (free) |

### 2. Virtual Cloud Network (VCN)

#### VCN Configuration

```hcl
resource "oci_core_vcn" "production" {
  compartment_id = var.compartment_id
  display_name   = "production-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "production"
}
```

**Specifications**:

| Parameter | Value | Notes |
|-----------|-------|-------|
| **CIDR Block** | 10.0.0.0/16 | 65,534 usable IPs |
| **Region** | us-phoenix-1 | Always Free Arm availability |
| **DNS Label** | production | Internal DNS |
| **IPv6** | Disabled | Not required |
| **Internet Gateway** | Enabled | Public subnet access |
| **NAT Gateway** | Optional | Private subnet internet |
| **Service Gateway** | Enabled | OCI services access |

#### Subnet Allocation

| Subnet | CIDR | Type | Purpose | Size |
|--------|------|------|---------|------|
| **Kubernetes Nodes** | 10.0.10.0/24 | Public | Worker nodes | 254 IPs |
| **Kubernetes Pods** | 10.244.0.0/16 | Virtual | Pod IPs (VCN-Native CNI) | 65,534 IPs |
| **Load Balancer** | 10.0.30.0/24 | Public | LB frontend | 254 IPs |
| **Database** | 10.0.40.0/24 | Private | Autonomous DB (optional) | 254 IPs |
| **Reserved** | 10.0.50.0/22 | - | Future expansion | 1,022 IPs |

#### Route Tables

**Public Subnet Route Table**:

| Destination | Target | Description |
|-------------|--------|-------------|
| 0.0.0.0/0 | Internet Gateway | Internet access |
| OCI Services | Service Gateway | OCI service access |

**Private Subnet Route Table** (optional):

| Destination | Target | Description |
|-------------|--------|-------------|
| 0.0.0.0/0 | NAT Gateway | Outbound internet |
| OCI Services | Service Gateway | OCI service access |

### 3. Compute Instances (VM.Standard.A1.Flex)

#### Instance Specifications

**Shape Details**:

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Processor** | Ampere Altra (Arm Neoverse N1) | 3.0 GHz |
| **Architecture** | arm64 (aarch64) | 64-bit Arm |
| **OCPU** | 1-4 (free tier) | Flexible allocation |
| **Memory** | 1-24 GB (free tier) | 1:6 ratio typical |
| **Network** | Up to 4 Gbps | Per instance |
| **Boot Volume** | 50 GB (default) | From block storage quota |

#### OS Images (Arm64)

| Operating System | Version | Use Case |
|------------------|---------|----------|
| **Oracle Linux** | 8.x, 9.x | Recommended, OCI optimized |
| **Ubuntu** | 20.04, 22.04 LTS | Popular, well-supported |
| **CentOS Stream** | 8, 9 | RHEL-compatible |
| **Rocky Linux** | 8, 9 | RHEL-compatible |

#### Instance Configuration

```yaml
shape: VM.Standard.A1.Flex
shape_config:
  ocpus: 2
  memory_in_gbs: 12

boot_volume:
  size_in_gbs: 50
  vpus_per_gb: 10  # Balanced performance

metadata:
  ssh_authorized_keys: <public_key>
  user_data: <cloud-init>

availability_config:
  recovery_action: RESTORE_INSTANCE  # Auto-recovery
```

### 4. Block Storage (Block Volumes)

#### Volume Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Total Capacity** | 200 GB | Always Free limit |
| **Volume Count** | 5 | Maximum volumes |
| **Volume Type** | Block Volume | SSD-backed |
| **Performance** | Balanced (10 VPUs/GB) | Default tier |
| **IOPS** | ~3,000 | Per volume (approximate) |
| **Throughput** | ~48 MB/s | Per volume (approximate) |
| **Encryption** | Automatic | Oracle-managed keys |
| **Backups** | Manual | From block storage quota |

#### Volume Performance Tiers

| Tier | VPU/GB | Use Case | IOPS | Throughput |
|------|--------|----------|------|------------|
| **Lower Cost** | 0 | Backups, archives | ~300 | ~6 MB/s |
| **Balanced** | 10 | General purpose (default) | ~3,000 | ~48 MB/s |
| **Higher Performance** | 20 | Databases, high I/O | ~6,000 | ~96 MB/s |
| **Ultra High Performance** | 30+ | Not in free tier | N/A | N/A |

**Note**: Always Free tier includes Balanced (10 VPU/GB) performance.

#### StorageClass Configuration

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: oci-bv
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: blockvolume.csi.oraclecloud.com
parameters:
  attachment-type: "paravirtualized"
  vpusPerGB: "10"
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

#### Volume Usage Guidelines

| Use Case | Recommended Size | Access Mode | Reclaim Policy | Performance |
|----------|------------------|-------------|----------------|-------------|
| **Boot Volumes** | 50 GB | N/A | Retain | Balanced |
| **Database** | 30-50 GB | ReadWriteOnce | Retain | Balanced |
| **Application Data** | 20-40 GB | ReadWriteOnce | Delete | Balanced |
| **Logs** | 10-20 GB | ReadWriteOnce | Delete | Lower Cost |
| **Shared Storage** | Not supported | - | - | - |

**Free Tier Allocation Example**:

- 2× 50GB boot volumes (nodes) = 100 GB
- 1× 50GB database volume = 50 GB
- 1× 30GB application volume = 30 GB
- 1× 20GB logs volume = 20 GB
- **Total**: 200 GB (at limit)

### 5. Object Storage

#### Object Storage Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Storage Capacity** | 20 GB | Always Free limit |
| **Storage Tier** | Standard | Default tier |
| **Redundancy** | Multi-AZ | Automatic replication |
| **Durability** | 99.999999999% (11 nines) | Oracle SLA |
| **Availability** | 99.9% | Oracle SLA |
| **API** | S3-compatible | Swift and OCI native APIs |
| **Encryption** | Automatic | Oracle-managed keys |
| **Versioning** | Supported | Optional |
| **Lifecycle Policies** | Supported | Auto-tiering to Archive |

#### Bucket Configuration

**Application Data Bucket**:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| **Name** | app-data-phoenix-1 | User uploads, assets |
| **Tier** | Standard | Frequent access |
| **Visibility** | Private | Pre-authenticated requests |
| **Versioning** | Disabled | Space optimization |
| **Lifecycle** | 90 days → Archive | Cost optimization |
| **Size Estimate** | 10-15 GB | Within free tier |

**Backup Bucket**:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| **Name** | k8s-backups-phoenix-1 | Velero backups |
| **Tier** | Standard | Active backups |
| **Visibility** | Private | Secure access |
| **Versioning** | Enabled | Backup integrity |
| **Lifecycle** | 30 days → Delete | Retention policy |
| **Size Estimate** | 5-10 GB | Compressed backups |

#### S3-Compatible Access

```python
# Example using boto3 (AWS SDK)
import boto3

s3_client = boto3.client(
    's3',
    endpoint_url='https://objectstorage.us-phoenix-1.oraclecloud.com',
    aws_access_key_id='<access_key>',
    aws_secret_access_key='<secret_key>',
    region_name='us-phoenix-1'
)
```

### 6. Flexible Network Load Balancer

#### Load Balancer Specifications

| Parameter | Value | Configuration |
|-----------|-------|---------------|
| **Type** | Flexible Network Load Balancer | Layer 4 |
| **Shape** | Flexible | 10 Mbps minimum (free) |
| **Bandwidth** | 10 Mbps - 8 Gbps | Pay for >10 Mbps |
| **Always Free** | 1 instance @ 10 Mbps | Included |
| **Protocol** | TCP, UDP | Layer 4 only |
| **Visibility** | Public or Private | Configurable |
| **IP Address** | Reserved Public IP | From free tier quota |
| **Health Checks** | TCP/HTTP/HTTPS | Configurable |
| **Session Persistence** | Source IP | 5-tuple hash |

#### Backend Set Configuration

```yaml
backend_set:
  name: k8s-nodes
  policy: FIVE_TUPLE  # Source IP + Port + Dest IP + Port + Protocol
  health_checker:
    protocol: HTTP
    port: 10256  # kube-proxy health
    url_path: /healthz
    interval_ms: 10000
    timeout_ms: 5000
    retries: 3
  backends:
    - ip: 10.0.10.10  # Node 1
      port: 80
      weight: 1
    - ip: 10.0.10.11  # Node 2
      port: 80
      weight: 1
```

#### Listener Configuration

| Protocol | Port | Backend Port | SSL | Notes |
|----------|------|--------------|-----|-------|
| TCP | 80 | 80 (NodePort) | No | HTTP traffic |
| TCP | 443 | 443 (NodePort) | Passthrough | HTTPS traffic |
| TCP | 6443 | 6443 | Passthrough | Kubernetes API (optional) |

#### Kubernetes Service Integration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  annotations:
    service.beta.kubernetes.io/oci-load-balancer-shape: "flexible"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-min: "10"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-max: "10"
    oci.oraclecloud.com/load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
    - name: https
      port: 443
      targetPort: 443
      protocol: TCP
  selector:
    app.kubernetes.io/name: ingress-nginx
```

### 7. Security Lists and Network Security

#### Security List Configuration

**Kubernetes Nodes Security List (Public Subnet)**:

| Direction | Protocol | Source/Dest | Port Range | Purpose |
|-----------|----------|-------------|------------|---------|
| **Ingress** | TCP | 0.0.0.0/0 | 80 | HTTP traffic |
| **Ingress** | TCP | 0.0.0.0/0 | 443 | HTTPS traffic |
| **Ingress** | TCP | Admin CIDR | 22 | SSH (restricted) |
| **Ingress** | TCP | 10.0.0.0/16 | All | Inter-VCN |
| **Ingress** | UDP | 10.0.0.0/16 | All | Inter-VCN |
| **Ingress** | ICMP | 10.0.0.0/16 | 3, 4 | Path MTU discovery |
| **Egress** | All | 0.0.0.0/0 | All | Allow all outbound |

**Load Balancer Security List**:

| Direction | Protocol | Source/Dest | Port Range | Purpose |
|-----------|----------|-------------|------------|---------|
| **Ingress** | TCP | 0.0.0.0/0 | 80 | HTTP |
| **Ingress** | TCP | 0.0.0.0/0 | 443 | HTTPS |
| **Egress** | TCP | 10.0.10.0/24 | 30000-32767 | NodePort range |

#### Network Security Groups (NSGs)

**Kubernetes Control Plane NSG**:

```hcl
resource "oci_core_network_security_group_security_rule" "k8s_api" {
  network_security_group_id = oci_core_network_security_group.k8s_control_plane.id
  direction                 = "INGRESS"
  protocol                  = "6"  # TCP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}
```

**Pod-to-Pod NSG** (VCN-Native CNI):

| Rule | Source | Destination | Protocol | Purpose |
|------|--------|-------------|----------|---------|
| Allow | Pod CIDR | Pod CIDR | All | Pod communication |
| Allow | Service CIDR | Pod CIDR | All | Service to Pod |
| Allow | Node CIDR | Pod CIDR | All | Node to Pod |

## Performance Requirements

### Service Level Objectives (SLOs)

| Service | Metric | Target | Measurement |
|---------|--------|--------|-------------|
| **OKE Control Plane** | Availability | 99.9% | Monthly uptime (Oracle managed) |
| **OKE API** | Latency (p95) | <500ms | API response time |
| **Worker Nodes** | Availability | 99.5% | Per node uptime (our responsibility) |
| **Network Load Balancer** | Availability | 99.9% | Oracle SLA |
| **Block Storage** | Availability | 99.9% | Oracle SLA |
| **Block Storage** | Latency (p95) | <10ms | I/O response time |
| **Object Storage** | Availability | 99.9% | Oracle SLA |
| **Object Storage** | Latency (p95) | <100ms | API response time |

### Resource Limits and Monitoring

| Resource | Free Tier Limit | Alert Threshold | Action on Approach |
|----------|----------------|-----------------|---------------------|
| **Compute OCPUs** | 4 | 90% (3.6 OCPUs) | Review workload optimization |
| **Memory** | 24 GB | 85% (20.4 GB) | Review memory usage |
| **Block Storage** | 200 GB | 85% (170 GB) | Clean up unused data |
| **Object Storage** | 20 GB | 80% (16 GB) | Archive or delete old files |
| **Outbound Transfer** | 10 TB/month | 80% (8 TB) | Review data transfer patterns |
| **Load Balancer** | 10 Mbps | N/A | Upgrade if needed (paid) |

## Security Requirements

### Access Control

| Component | Authentication | Authorization | Encryption |
|-----------|----------------|---------------|------------|
| **OKE API** | Certificate-based | RBAC | TLS 1.2+ |
| **Compute Instances** | SSH key-based | IAM policies | SSH protocol |
| **Object Storage** | API keys / Auth tokens | Bucket policies | HTTPS only |
| **OCI Console** | IAM user/password + MFA | IAM policies | HTTPS only |
| **OCI CLI** | API keys | IAM policies | HTTPS only |

### IAM Configuration

**Compartment Structure**:

```
root_compartment/
  └── production/
      ├── networking/     # VCN, subnets, security lists
      ├── compute/        # Compute instances, OKE
      ├── storage/        # Block volumes, object storage
      └── identity/       # IAM users, groups, policies
```

**IAM Policies** (Least Privilege):

```
# Allow OKE to manage networking
Allow service OKE to manage vcns in compartment production:networking
Allow service OKE to manage subnets in compartment production:networking
Allow service OKE to use security-lists in compartment production:networking

# Allow compute to use block storage
Allow group k8s-admins to manage volume-family in compartment production:storage

# Allow CI/CD to deploy
Allow group ci-cd to manage cluster-node-pools in compartment production:compute
Allow group ci-cd to read repos in tenancy
```

### Network Security

| Layer | Control | Implementation |
|-------|---------|----------------|
| **Edge** | Cloudflare WAF/DDoS | DNS-level protection |
| **Perimeter** | Security Lists | VCN-level filtering |
| **Network** | NSGs | Instance-level filtering |
| **Pod** | Network Policies | Kubernetes-level filtering |
| **Application** | TLS | Certificate-based encryption |

### Data Security

| Data Type | At Rest | In Transit | Backup |
|-----------|---------|------------|--------|
| **Block Volumes** | AES-256 (auto) | TLS 1.2+ | Encrypted |
| **Object Storage** | AES-256 (auto) | HTTPS only | Encrypted |
| **Secrets** | Kubernetes Secrets + Sealed Secrets | TLS 1.2+ | Encrypted in etcd |
| **Logs** | Encrypted | TLS 1.2+ | Encrypted |

### Compliance and Monitoring

| Requirement | Implementation | Verification |
|-------------|----------------|--------------|
| **Encryption at Rest** | Enabled by default | OCI audit logs |
| **Encryption in Transit** | TLS 1.2+ enforced | Configuration enforcement |
| **Access Logging** | OCI Audit Logs enabled | Log analysis |
| **Vulnerability Scanning** | Trivy for containers | CI/CD pipeline |
| **Secret Management** | Sealed Secrets + External Secrets Operator | Git repository encryption |
| **Backup Encryption** | Automatic | Oracle-managed |

## Integration Specifications

### Cloudflare Integration

| Integration Point | Configuration | Purpose |
|-------------------|---------------|---------|
| **DNS** | A records point to OCI NLB IP | Domain resolution |
| **Proxy** | Enabled (orange cloud) | DDoS protection, CDN |
| **SSL/TLS Mode** | Full (Strict) | End-to-end encryption |
| **Load Balancing** | Failover to DigitalOcean | Disaster recovery |
| **Firewall** | WAF rules enabled | Application security |
| **Health Checks** | Monitor OCI + DO | Automatic failover |

### GitHub Actions Integration

| Integration | Configuration | Authentication |
|-------------|---------------|----------------|
| **OKE Access** | kubeconfig in secrets | Instance principal or API key |
| **Terraform** | State in Cloudflare R2 | OCI API key in secrets |
| **Container Registry** | OCIR (Oracle Registry) | Auth token |
| **Deployments** | Direct kubectl or ArgoCD | Service account token |

### Tailscale Integration (Hybrid Cloud)

| Component | Configuration | Purpose |
|-----------|---------------|---------|
| **Compute Instances** | Tailscale agent | Hybrid connectivity |
| **VCN Routes** | Advertise subnets | On-premise access |
| **ACLs** | Allow on-premise → OCI | Secure access |
| **Mesh Network** | OCI + DO + On-prem | Unified networking |

## Monitoring and Observability

### OCI Monitoring (Free Tier)

| Metric Type | Source | Retention | Queries/Month |
|-------------|--------|-----------|---------------|
| **Compute** | Instance metrics | 90 days | Included (500M) |
| **Networking** | VCN metrics | 90 days | Included |
| **Block Storage** | Volume metrics | 90 days | Included |
| **OKE** | Cluster metrics | 90 days | Included |

**Key Metrics**:

- CPU utilization (per instance, per OCPU)
- Memory utilization
- Disk I/O (IOPS, throughput)
- Network I/O (bytes in/out)
- Load balancer connections

### OCI Logging (Free Tier)

| Log Type | Retention | Size Limit | Purpose |
|----------|-----------|------------|---------|
| **Audit Logs** | 365 days | 10 GB/month | Compliance, security |
| **Service Logs** | Custom | 10 GB/month | Troubleshooting |
| **Custom Logs** | Custom | 10 GB/month | Application logs |

### Third-Party Monitoring (Optional)

| Tool | Purpose | Deployment | Cost |
|------|---------|------------|------|
| **Prometheus** | Metrics collection | In-cluster | Free (uses storage quota) |
| **Grafana** | Visualization | In-cluster | Free (uses storage quota) |
| **Loki** | Log aggregation | In-cluster or external | Free/minimal |
| **Alert Manager** | Alerting | In-cluster | Free |

## Disaster Recovery

### Backup Strategy

| Component | Method | Frequency | Retention | Storage Location |
|-----------|--------|-----------|-----------|------------------|
| **OKE Cluster** | Velero | Daily | 7 days | OCI Object Storage |
| **Block Volumes** | OCI Backups | Weekly | 4 weeks | OCI (from quota) |
| **Object Storage** | Versioning | On change | 30 days | Same bucket |
| **Terraform State** | R2 versioning | On change | All versions | Cloudflare R2 |
| **Databases** | Manual dumps | Weekly | 4 weeks | OCI Object Storage |

### Recovery Objectives

| Scenario | RTO | RPO | Procedure |
|----------|-----|-----|-----------|
| **Single Node Failure** | 5 minutes | 0 | OKE auto-recovery |
| **Cluster Failure** | 2-4 hours | 24 hours | Velero restore |
| **Region Outage** | 4-8 hours | 24 hours | Failover to DigitalOcean |
| **Data Corruption** | 2-4 hours | 7 days | Restore from backup |

### Multi-Cloud Disaster Recovery

**Failover Targets**:

1. **Primary**: Oracle Cloud (OCI) - us-phoenix-1
2. **Secondary**: DigitalOcean (DO) - NYC3
3. **Tertiary**: On-premise (if available)

**Failover Mechanism**:

- Cloudflare Health Checks monitor OCI availability
- Automatic DNS failover to DigitalOcean if OCI down
- Manual failover to on-premise if both clouds unavailable

## Cost Management

### Always Free Tier Compliance

**Zero-Cost Target**:

| Resource | Usage | Free Limit | Status |
|----------|-------|------------|--------|
| **Compute** | 4 OCPUs, 24 GB RAM | 4 OCPUs, 24 GB | ✅ At limit |
| **Block Storage** | ~200 GB | 200 GB | ✅ At limit |
| **Object Storage** | ~15 GB | 20 GB | ✅ Within limit |
| **Outbound Transfer** | ~1-2 TB/month | 10 TB/month | ✅ Well within |
| **Load Balancer** | 1 @ 10 Mbps | 1 @ 10 Mbps | ✅ At limit |
| **Monitoring** | <100M data points | 500M ingestion | ✅ Within limit |
| **Logging** | <5 GB/month | 10 GB/month | ✅ Within limit |

**Total Monthly Cost**: **$0**

### Scaling Cost Estimates

**Scenario 1: Add 1 Paid Compute Node** (beyond free tier):

- 1× VM.Standard.A1.Flex (2 OCPU, 12 GB): ~$10-15/month
- Total: **$10-15/month** (still 85% cheaper than DigitalOcean)

**Scenario 2: Upgrade Load Balancer** (to 100 Mbps):

- Flexible NLB @ 100 Mbps: ~$10-15/month
- Total: **$10-15/month** (still within budget)

**Scenario 3: Add Block Storage** (50 GB):

- Block storage beyond 200 GB: $0.0255/GB/month × 50 GB = $1.28/month
- Total: **$1.28/month** (negligible)

**Break-Even Analysis**:

- Oracle Cloud remains cheaper than DigitalOcean up to ~8-10 paid nodes
- At that scale, consider hybrid approach or evaluate DigitalOcean migration

### Cost Monitoring and Alerts

**OCI Cost Analysis**:

```bash
# View monthly cost summary
oci usage-api usage-summary request-summarized-usages \
  --tenant-id <tenancy_ocid> \
  --time-usage-started <start_date> \
  --time-usage-ended <end_date> \
  --granularity MONTHLY

# Set up budget alert
oci budgets budget create \
  --compartment-id <compartment_ocid> \
  --amount 10 \
  --reset-period MONTHLY \
  --target-type COMPARTMENT \
  --targets '["<compartment_ocid>"]'
```

**Alert Thresholds**:

- Warning: >$5/month (unexpected charges)
- Critical: >$20/month (investigate immediately)
- Review: Monthly cost analysis regardless of amount

## Architecture Diagrams

### Network Architecture

```
                    ┌──────────────────────────────────────────┐
                    │   Cloudflare (Edge Layer)               │
                    │   - DNS, CDN, WAF, DDoS Protection      │
                    │   - Load Balancing & Failover           │
                    └─────────────────┬────────────────────────┘
                                      │
                    ┌─────────────────┴────────────────────────┐
                    │                                           │
     ┌──────────────▼─────────────┐          ┌────────────────▼────────────┐
     │  Oracle Cloud (Primary)    │          │  DigitalOcean (Secondary)   │
     │  us-phoenix-1              │          │  NYC3                        │
     ├────────────────────────────┤          ├─────────────────────────────┤
     │  VCN: 10.0.0.0/16          │          │  VPC: 10.100.0.0/16         │
     │                            │          │                             │
     │  ┌──────────────────────┐  │          │  ┌───────────────────────┐  │
     │  │ OKE Cluster          │  │          │  │ DOKS Cluster (DR)     │  │
     │  │ - 2 nodes (Arm)      │  │          │  │ - 2-3 nodes (standby) │  │
     │  │ - 4 OCPUs, 24GB RAM  │  │          │  │ - Scaled down         │  │
     │  │ - VCN-Native CNI     │  │          │  │ - Ready for failover  │  │
     │  └──────────────────────┘  │          │  └───────────────────────┘  │
     │                            │          │                             │
     │  ┌──────────────────────┐  │          │  ┌───────────────────────┐  │
     │  │ Flexible NLB         │  │          │  │ DO Load Balancer      │  │
     │  │ - 10 Mbps (free)     │  │          │  │ - Standby             │  │
     │  └──────────────────────┘  │          │  └───────────────────────┘  │
     │                            │          │                             │
     │  Storage:                  │          │  Storage:                   │
     │  - Block: 200 GB           │          │  - Block: Minimal           │
     │  - Object: 20 GB           │          │  - Spaces: Backups          │
     └────────────────────────────┘          └─────────────────────────────┘
                    │                                      │
                    └──────────────┬───────────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │  Tailscale Mesh Network     │
                    │  - Hybrid connectivity      │
                    │  - Secure VPN mesh          │
                    └──────────────┬──────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │  On-Premise (Optional)      │
                    │  - Talos Kubernetes         │
                    │  - Internal services        │
                    └─────────────────────────────┘
```

## References

- [ADR-0015: Oracle Cloud as Primary Provider](../../docs/decisions/0015-oracle-cloud-primary.md)
- [Oracle Cloud Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- [Oracle Kubernetes Engine Documentation](https://docs.oracle.com/en-us/iaas/Content/ContEng/home.htm)
- [OCI VCN-Native Pod Networking](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengpodnetworking_topic-OCI_CNI_plugin.htm)
- [OCI Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [OCI CLI Reference](https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/)
- [Ampere A1 Compute](https://www.oracle.com/cloud/compute/arm/)
- [DigitalOcean Infrastructure Spec](../digitalocean/digitalocean-infrastructure.md) (Secondary provider)
