# 5. Kubernetes as Container Platform

Date: 2025-10-19

## Status

Accepted

## Context

Following our Infrastructure as Code approach ([ADR-0001](0001-infrastructure-as-code.md))
with Terraform ([ADR-0002](0002-terraform-primary-tool.md)) for provisioning,
we need a container orchestration platform for deploying and managing containerized applications
across our hybrid cloud environment.

For a small company, we need a platform that:

- **Industry standard**: Widely adopted with strong community and ecosystem
- **Portable**: Runs consistently across cloud providers and on-premise
- **Learning value**: Skills transferable to career growth
- **Manageable complexity**: Can start simple and grow
- **Cost-effective**: Free tier or affordable managed options available
- **Hybrid-ready**: Works across AWS, Azure, GCP, and on-premise

## Decision

We will use **Kubernetes** as our container orchestration platform, leveraging both **managed Kubernetes services** (EKS, AKS, GKE) and **self-managed clusters** where appropriate.

Specifically:

- **Cloud Kubernetes**: Use DigitalOcean Kubernetes (DOKS) as primary managed Kubernetes service
- **On-Premise Kubernetes**: Use Talos Linux for production-grade bare metal/VM deployments
- **Learning/Testing**: Use k3s for resource-constrained environments (Raspberry Pi, old hardware)
- **Future Expansion**: Support for AWS EKS, Azure AKS, GCP GKE when multi-cloud needed
- **Consistent tooling**: Same kubectl, Helm, and GitOps tools across all clusters
- **Cost-effective**: DOKS free control plane + simple, predictable pricing

## Consequences

### Positive

- **Industry standard**: Most popular container orchestration platform
- **Cloud portable**: Same tooling across DigitalOcean, on-premise, and future cloud providers
- **Cost-effective**: DigitalOcean DOKS has free control plane, simple pricing ($12/month per worker node)
- **Developer-friendly**: Simple setup and management, great documentation
- **Strong ecosystem**: Vast collection of tools, operators, and integrations
- **Career growth**: Valuable Kubernetes skills transferable across providers
- **Declarative**: Infrastructure as Code principles for application deployment
- **Self-healing**: Automatic restart, rescheduling, and scaling
- **Service discovery**: Built-in DNS and load balancing

### Negative

- **Complexity**: Steep learning curve for small teams
- **Overhead**: Resource requirements higher than simple VM deployments
- **Cost**: Managed Kubernetes services have control plane fees
- **Debugging difficulty**: Distributed system troubleshooting is harder
- **Version management**: Regular upgrades needed for security and features
- **Storage complexity**: Persistent storage requires careful planning

### Trade-offs

- **Complexity vs. Capability**: More moving parts but more powerful features
- **Managed vs. Self-hosted**: Convenience and cost vs. control and learning
- **Kubernetes vs. Simple VMs**: Orchestration overhead vs. manual management

## Alternatives Considered

### Docker Compose

**Description**: Simple multi-container orchestration for single hosts

**Why not chosen**:

- Limited to single-host deployments
- No auto-scaling or self-healing
- Not production-grade for distributed applications
- Good for local development, not production infrastructure

**Trade-offs**: Simplicity vs. production capabilities

**When to use**: Local development and testing

### Docker Swarm

**Description**: Docker's built-in orchestration mode

**Why not chosen**:

- Smaller community and ecosystem than Kubernetes
- Less tooling and third-party integrations
- Limited cloud provider support
- Declining adoption in industry

**Trade-offs**: Easier learning curve vs. industry momentum

### HashiCorp Nomad

**Description**: Lightweight orchestrator for containers and non-containers

**Why not chosen**:

- Smaller ecosystem than Kubernetes
- Less cloud provider integration
- Fewer learning resources
- While simpler, Kubernetes skills more transferable

**Trade-offs**: Simplicity vs. ecosystem and career value

### Amazon ECS/Fargate

**Description**: AWS-native container services

**Why not chosen**:

- AWS-only, creates cloud vendor lock-in
- Skills not transferable to other clouds
- Doesn't work for hybrid/multi-cloud
- Good for AWS-only shops, not our use case

**Trade-offs**: AWS integration vs. cloud portability

### Virtual Machines Only

**Description**: Deploy applications directly on VMs without containers

**Why not chosen**:

- Manual scaling and management
- Slower deployments and updates
- Less efficient resource utilization
- Missing modern DevOps patterns

**Trade-offs**: Simpler operations vs. modern practices

**When to use**: Legacy applications not ready for containerization

## Implementation Notes

### Small Company Considerations

**DigitalOcean Kubernetes (DOKS)** - Primary Cloud Provider:

- **Control Plane**: FREE (no charge for Kubernetes control plane)
- **Worker Nodes**: Starting at $12/month per node (2 vCPU, 2GB RAM)
- **Minimum Cluster**: 2 nodes = $24/month for production-ready cluster
- **Auto-scaling**: Free, scales nodes based on resource usage
- **Load Balancer**: $12/month (automatically provisioned for LoadBalancer services)
- **Block Storage**: $0.10/GB/month for persistent volumes
- **Free Credits**: Often $200 credit for 60 days for new accounts
- **Setup Time**: ~5 minutes to create cluster via Terraform or UI
- **Terraform Provider**: Official `digitalocean/digitalocean` provider

**Cost Comparison** (Small 2-node cluster):

- **DOKS**: $24/month (2 nodes) + $12/month (LB) = $36/month
- **AWS EKS**: $73/month (control plane) + $30/month (2 t3.small) = $103/month
- **Azure AKS**: $0 (control plane) + $30/month (2 B2s) = $30/month
- **GKE**: $0 (1 free cluster) + $25/month (1 e2-small) = $25/month (limited to 1 cluster)

**Why DigitalOcean**:

- Simplest pricing structure (no hidden costs)
- Free control plane (vs. AWS $73/month)
- Great for learning and small production workloads
- Excellent documentation and developer experience
- Easy migration path to other clouds later

**On-Premise Kubernetes**:

**Talos Linux** (Recommended for production-grade on-premise):

- Immutable, minimal OS designed for Kubernetes
- API-driven (no SSH, no shell by default)
- Secure by default (runs in RAM, all API calls via mTLS)
- Terraform provider for declarative provisioning
- Perfect for bare metal servers, VMs (Proxmox, ESXi, Hyper-V)
- Automatic updates and self-healing
- Unified control plane and worker node configuration

**k3s** (Alternative for resource-constrained environments):

- Lightweight Kubernetes (< 512MB RAM)
- Single binary, easy to install
- Built-in load balancer (Traefik ingress controller)
- Perfect for Raspberry Pi clusters or old laptops
- Good for learning and testing before Talos

**Kind** (Kubernetes in Docker):

- Local development only
- Multi-node clusters in Docker containers
- Good for testing and CI/CD pipelines

### Cost Management

**DigitalOcean DOKS**:

- **Control Plane**: Always FREE
- **Worker Nodes**: Start with 2x basic nodes ($12/month each = $24/month)
- **Load Balancer**: $12/month (created automatically for LoadBalancer services)
- **Storage**: $0.10/GB/month for block storage volumes
- **Free Credits**: Sign up for $200/60-day credit for new accounts
- **Cost Optimization**:
  - Use smallest node size for dev/testing ($6/month per node)
  - Delete unused load balancers when not needed
  - Use node auto-scaling to match demand
  - Monitor costs via DigitalOcean dashboard

**Monthly Cost Estimates**:

- **Dev/Testing**: 1 node ($12) + optional LB ($12) = $12-24/month
- **Production**: 2-3 nodes ($24-36) + LB ($12) = $36-48/month
- **High Availability**: 3 nodes ($36) + LB ($12) + storage ($10) = ~$58/month

**On-Premise (Talos)**:

- **Hardware Cost**: One-time investment in servers or repurpose existing hardware
- **Electricity**: Ongoing operational cost
- **Maintenance**: Time investment
- **Free Software**: Talos Linux is completely free and open source

**Storage**:

- Delete unused PVCs to avoid orphaned volumes
- Use DigitalOcean Snapshots for backups ($0.05/GB/month)
- Consider object storage (Spaces) for cheaper long-term storage

**Monitoring**:

- DigitalOcean Monitoring: Free basic metrics
- Prometheus + Grafana: Free, self-hosted on-cluster
- Avoid expensive commercial observability platforms initially

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [DigitalOcean Kubernetes (DOKS) Documentation](https://docs.digitalocean.com/products/kubernetes/)
- [DigitalOcean Pricing Calculator](https://www.digitalocean.com/pricing/calculator)
- [DigitalOcean Terraform Provider](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)
- [Talos Linux Documentation](https://www.talos.dev/latest/)
- [Talos Terraform Provider](https://registry.terraform.io/providers/siderolabs/talos/latest/docs)
- [k3s Documentation](https://k3s.io/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/)
