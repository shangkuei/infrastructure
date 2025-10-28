# Research: Kubernetes Distribution Comparison

Date: 2025-10-18
Author: Infrastructure Team
Status: Completed

## Objective

Evaluate Kubernetes distributions to determine the best options for cloud (managed) and on-premise (self-hosted) deployments, balancing ease of use, cost, and production-readiness.

## Scope

### In Scope

- Managed Kubernetes services (DigitalOcean DOKS, AWS EKS, Azure AKS, GCP GKE)
- On-premise distributions (Talos Linux, k3s, kubeadm, Kind)
- Cost comparison for small companies
- Learning curve and operational overhead
- Hybrid cloud compatibility

### Out of Scope

- Enterprise Kubernetes platforms (OpenShift, Rancher, Tanzu)
- Edge computing distributions (K3s covered but not edge-specific)
- Kubernetes alternatives (Docker Swarm, Nomad - covered in separate research)

## Methodology

### Testing Approach

- Deployed clusters on DigitalOcean, AWS, Azure, GCP
- Installed Talos, k3s, and kubeadm on bare metal/VMs
- Measured setup time, complexity, and resource usage
- Tested application deployment workflows
- Evaluated operational maintenance requirements

### Evaluation Criteria

- **Cost**: Control plane fees + node pricing
- **Setup time**: Time from start to working cluster
- **Maintenance**: Upgrade process and operational overhead
- **Features**: Built-in capabilities and ecosystem
- **Learning**: Documentation quality and transferable skills

## Findings

### Managed Kubernetes Services

#### 1. DigitalOcean Kubernetes (DOKS)

**Specifications**:

```yaml
Control Plane: FREE
Nodes: Starting at $12/month (2 vCPU, 2GB RAM)
Setup Time: 5 minutes
Kubernetes Version: 1.28+ (auto-updates available)
High Availability: 3 control plane nodes (free)
```

**Pros**:

- ✅ Free control plane (vs. AWS $73/month)
- ✅ Simple, predictable pricing
- ✅ Excellent documentation
- ✅ Auto-scaling included
- ✅ Block storage integration
- ✅ Load balancer auto-provisioning
- ✅ 1-click cluster creation

**Cons**:

- ❌ Smaller ecosystem vs. AWS/GCP
- ❌ Fewer managed add-ons
- ❌ Limited to DigitalOcean regions

**Cost Example** (3-node production cluster):

```
Control Plane: $0
3x Standard Nodes ($12/node): $36
Load Balancer: $12
Block Storage (100GB): $10
TOTAL: $58/month
```

**Best for**: Small companies, learning, cost-sensitive production workloads

#### 2. Amazon EKS

**Specifications**:

```yaml
Control Plane: $73/month per cluster
Nodes: Starting at $15/month (t3.small)
Setup Time: 15-30 minutes
Kubernetes Version: 1.28+ (managed upgrades)
High Availability: Multi-AZ control plane
```

**Pros**:

- ✅ Deep AWS service integration (IAM, ALB, EBS, ECR)
- ✅ Enterprise features (Fargate, App Mesh)
- ✅ Largest ecosystem
- ✅ Compliance certifications (SOC2, ISO, HIPAA)

**Cons**:

- ❌ Expensive control plane ($73/month)
- ❌ Complex networking (VPC, subnets, security groups)
- ❌ Longer setup time
- ❌ AWS-specific knowledge required

**Cost Example** (3-node production cluster):

```
Control Plane: $73
3x t3.small ($15/node): $45
ALB: $22
EBS (100GB): $10
TOTAL: $150/month
```

**Best for**: AWS-heavy workloads, enterprise compliance needs

#### 3. Azure AKS

**Specifications**:

```yaml
Control Plane: FREE
Nodes: Starting at $15/month (B2s)
Setup Time: 10-20 minutes
Kubernetes Version: 1.28+ (managed upgrades)
High Availability: Multi-zone control plane (free)
```

**Pros**:

- ✅ Free control plane
- ✅ Azure service integration (AAD, ACR, Managed Disks)
- ✅ Good Windows container support
- ✅ Virtual nodes (serverless)

**Cons**:

- ❌ Azure-specific networking complexity
- ❌ Requires Azure expertise
- ❌ Fewer regions than AWS

**Cost Example** (3-node production cluster):

```
Control Plane: $0
3x B2s ($15/node): $45
Load Balancer: $18
Managed Disks (100GB): $5
TOTAL: $68/month
```

**Best for**: Azure ecosystem, Windows containers, Microsoft stack

#### 4. Google GKE

**Specifications**:

```yaml
Control Plane: FREE (1 cluster per billing account)
Nodes: Starting at $12.50/month (e2-small)
Setup Time: 5-10 minutes
Kubernetes Version: 1.28+ (auto-upgrades)
High Availability: Multi-zone control plane
```

**Pros**:

- ✅ Created by Google (Kubernetes origin)
- ✅ Best Kubernetes integration
- ✅ Free autopilot mode
- ✅ Advanced features (Anthos, Istio integration)
- ✅ Fast setup

**Cons**:

- ❌ Free tier limited to 1 cluster
- ❌ Requires GCP expertise
- ❌ Can be expensive at scale

**Cost Example** (3-node production cluster):

```
Control Plane: $0 (first cluster)
3x e2-small ($12.50/node): $37.50
Load Balancer: $18
Persistent Disk (100GB): $4
TOTAL: $59.50/month
```

**Best for**: Google Cloud users, Kubernetes purists, single-cluster needs

### On-Premise Distributions

#### 1. Talos Linux

**Specifications**:

```yaml
Cost: FREE (open source)
Setup Time: 30-60 minutes
OS: Immutable Linux (runs in RAM)
Management: API-only (no SSH)
Platform: Bare metal, VMs (Proxmox, ESXi, Hyper-V)
```

**Pros**:

- ✅ Production-grade security (immutable, no shell)
- ✅ Minimal attack surface
- ✅ API-driven (Terraform support)
- ✅ Automatic updates
- ✅ Unified control plane/worker config
- ✅ Self-healing
- ✅ Excellent documentation

**Cons**:

- ❌ No SSH access (debugging different)
- ❌ Learning curve for API-driven model
- ❌ Requires understanding of Talos-specific concepts

**Setup Example**:

```bash
# Generate cluster configuration
talosctl gen config my-cluster https://control-plane.example.com:6443

# Apply configuration
talosctl apply-config --nodes 192.168.1.10 --file controlplane.yaml

# Bootstrap cluster
talosctl bootstrap --nodes 192.168.1.10

# Get kubeconfig
talosctl kubeconfig
```

**Resource Requirements**:

- Control Plane: 2 vCPU, 4GB RAM, 10GB disk
- Worker Node: 2 vCPU, 2GB RAM, 10GB disk
- Recommended: 3 control plane + N workers

**Best for**: Security-focused on-premise, immutable infrastructure, bare metal

#### 2. k3s

**Specifications**:

```yaml
Cost: FREE (open source)
Setup Time: 5-10 minutes
OS: Any Linux distribution
Management: Standard Linux tools
Platform: Raspberry Pi, VMs, bare metal, edge devices
```

**Pros**:

- ✅ Lightweight (<512MB RAM)
- ✅ Single binary, easy install
- ✅ Built-in load balancer (Traefik)
- ✅ Included storage (local-path)
- ✅ Perfect for learning
- ✅ ARM support (Raspberry Pi)
- ✅ Fast startup

**Cons**:

- ❌ Less production-hardened than Talos
- ❌ Manual security hardening needed
- ❌ Traditional OS maintenance required

**Setup Example**:

```bash
# Install k3s (single command)
curl -sfL https://get.k3s.io | sh -

# Get kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Add worker nodes
curl -sfL https://get.k3s.io | K3S_URL=https://server:6443 K3S_TOKEN=xxx sh -
```

**Resource Requirements**:

- Server: 1 vCPU, 512MB RAM, 5GB disk
- Agent: 1 vCPU, 512MB RAM, 5GB disk
- Minimal: Raspberry Pi 3B+ (1GB RAM)

**Best for**: Learning, resource-constrained environments, edge computing, home labs

#### 3. kubeadm (Vanilla Kubernetes)

**Specifications**:

```yaml
Cost: FREE (open source)
Setup Time: 1-2 hours
OS: Ubuntu, Debian, CentOS, etc.
Management: Manual (kubeadm, kubectl)
Platform: Any Linux environment
```

**Pros**:

- ✅ Official Kubernetes tool
- ✅ Full control over configuration
- ✅ Transferable skills
- ✅ No vendor lock-in

**Cons**:

- ❌ Manual setup complexity
- ❌ Requires deep Kubernetes knowledge
- ❌ Manual maintenance (upgrades, certificates)
- ❌ No built-in HA or load balancing

**Best for**: Learning deep Kubernetes internals, full customization needs

#### 4. Kind (Kubernetes in Docker)

**Specifications**:

```yaml
Cost: FREE (open source)
Setup Time: 2 minutes
OS: Any (runs in Docker)
Management: kind CLI
Platform: Local development only
```

**Pros**:

- ✅ Fastest local cluster setup
- ✅ Multi-node clusters in containers
- ✅ Perfect for CI/CD testing
- ✅ Easy teardown/recreation

**Cons**:

- ❌ Development/testing only
- ❌ Not for production
- ❌ Docker dependency

**Best for**: Local development, testing, CI/CD pipelines

## Analysis

### Cost Comparison (Annual, 3-node cluster)

| Distribution | Control Plane | Nodes | Add-ons | **Total/Year** |
|--------------|---------------|-------|---------|----------------|
| DOKS | $0 | $432 | $264 | **$696** |
| EKS | $876 | $540 | $384 | **$1,800** |
| AKS | $0 | $540 | $276 | **$816** |
| GKE | $0* | $450 | $264 | **$714** |
| Talos | $0 | $0** | $0 | **$0** |
| k3s | $0 | $0** | $0 | **$0** |

\*First cluster only
\**Hardware/electricity costs not included

### Recommendation Matrix

| Use Case | Recommended | Alternative | Reasoning |
|----------|-------------|-------------|-----------|
| **Learning** | k3s | Kind | Lightweight, fast setup |
| **Cloud Production** | DOKS | GKE | Cost-effective, simple |
| **AWS-Native** | EKS | - | Deep AWS integration |
| **On-Premise Production** | Talos | kubeadm | Security, maintainability |
| **Resource-Constrained** | k3s | - | Minimal footprint |
| **Local Development** | Kind | k3s | Fast iteration |
| **Enterprise** | EKS/AKS | GKE | Compliance, support |

### Trade-offs

**Managed vs. Self-Hosted**:

- Managed: Higher cost → Less operational burden
- Self-hosted: Hardware investment → Full control

**Simplicity vs. Features**:

- k3s: Simplicity → Fewer built-in features
- Full K8s: Power → Complexity

**Security vs. Familiarity**:

- Talos: Immutable security → Different operational model
- Traditional: Familiar tools → Manual hardening needed

## Recommendations

### Primary: DigitalOcean Kubernetes (DOKS)

**For cloud deployments**:

1. Free control plane saves $876/year vs. EKS
2. Simple pricing: $36/month for 3-node cluster
3. Excellent for small companies
4. Easy migration to other clouds later

### Secondary: Talos Linux

**For on-premise production**:

1. Production-grade security by default
2. API-driven matches cloud paradigm
3. Automatic updates reduce maintenance
4. Perfect for bare metal or Proxmox/ESXi

### Tertiary: k3s

**For learning and resource-constrained environments**:

1. Fastest path to working cluster
2. Raspberry Pi compatible
3. Great for home labs
4. Can graduate to Talos when ready

## Action Items

1. **Immediate**:
   - [ ] Create DOKS cluster via Terraform
   - [ ] Deploy test application
   - [ ] Configure kubectl access

2. **Short-term** (1-3 months):
   - [ ] Set up Talos cluster on-premise
   - [ ] Implement GitOps workflow (ArgoCD/Flux)
   - [ ] Configure monitoring (Prometheus)

3. **Long-term** (6-12 months):
   - [ ] Evaluate multi-cluster management
   - [ ] Assess service mesh needs
   - [ ] Plan disaster recovery

## Follow-up Research Needed

1. **Service Mesh**: Istio vs. Linkerd vs. Consul
2. **GitOps**: ArgoCD vs. Flux comparison
3. **Multi-cluster**: Federation and management strategies

## References

- [DOKS Documentation](https://docs.digitalocean.com/products/kubernetes/)
- [Talos Linux](https://www.talos.dev/)
- [k3s Documentation](https://k3s.io/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

## Outcome

This research led to **[ADR-0005: Kubernetes as Container Platform](../decisions/0005-kubernetes-container-platform.md)**,
which adopted DigitalOcean Kubernetes for cloud and Talos Linux for on-premise deployments.
