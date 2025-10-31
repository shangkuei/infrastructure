# 15. Oracle Cloud as Primary Cloud Provider

Date: 2025-10-28

## Status

~~Accepted~~ → **Superseded by [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](0016-talos-unraid-primary.md)**

**Note**: Oracle Cloud remains a valuable option for future cloud migration when production needs arise. This ADR
documents the comprehensive analysis and continues to be relevant for cloud deployment decisions.

**Supersedes**: [ADR-0013: DigitalOcean as Primary Cloud Provider](0013-digitalocean-primary-cloud.md)

## Context

Following implementation of DigitalOcean infrastructure (ADR-0013), ongoing cost analysis revealed that the
**$90-120/month** baseline cost for a production-ready Kubernetes environment presents a significant financial burden
for small companies and personal projects, particularly during initial development and low-traffic phases.

Oracle Cloud's Always Free tier offers a compelling alternative with:

- **Zero monthly cost** for a complete Kubernetes infrastructure
- **Generous compute resources**: 4 OCPUs + 24GB RAM (Ampere A1 Arm processors)
- **Managed Kubernetes**: Oracle Kubernetes Engine (OKE) included in Always Free tier
- **Production-grade infrastructure**: Same quality and reliability as paid tiers
- **No time limits**: Always Free tier has no expiration (unlike trial credits)

This represents potential **annual savings of $1,200-1,440** while maintaining professional infrastructure quality suitable for production workloads.

### Cost Comparison (Monthly)

| Provider | Compute | Kubernetes | Storage | Load Balancer | Total |
|----------|---------|------------|---------|---------------|-------|
| **Oracle Cloud (Free)** | $0 (4 OCPU, 24GB) | $0 (OKE managed) | $0 (200GB) | $0 (Flexible NLB) | **$0** |
| **DigitalOcean** | $54 (3×2GB nodes) | $0 (DOKS managed) | ~$10 (100GB) | $10 | **$74** |
| **AWS (EKS)** | $60+ (t3.small×2) | $73 (control plane) | ~$10 (100GB EBS) | $16 (ALB) | **$159+** |
| **Azure (AKS)** | $50+ (B2s×2) | $0 (managed) | ~$8 (100GB disk) | $10 (LB) | **$68+** |
| **GCP (GKE)** | $48+ (e2-small×2) | $73 (Autopilot min) | ~$10 (100GB disk) | Included | **$131+** |

### Resource Comparison

| Provider | vCPUs | RAM | Storage | Bandwidth | Control Plane |
|----------|-------|-----|---------|-----------|---------------|
| **Oracle (Free)** | 4 | 24GB | 200GB | 10TB/mo free | Managed (HA) |
| **DigitalOcean** | 6 | 6GB | 180GB | 5TB/mo | Managed (HA) |
| **AWS (EKS)** | 2 | 4GB | ~100GB | Metered | Managed (HA) |
| **Azure (AKS)** | 2 | 4GB | ~100GB | Metered | Managed (HA) |
| **GCP (GKE)** | 2 | 4GB | ~100GB | Metered | Managed (HA) |

### Oracle Cloud Always Free Tier Specifications

**Compute (Ampere A1 - Arm-based)**:

- 4 OCPUs (Arm cores)
- 24 GB RAM
- 3,000 OCPU hours/month
- Can split across up to 4 VM instances
- Flexible shapes (VM.Standard.A1.Flex)

**Storage**:

- 200 GB Block Storage (SSD)
- 5 block volumes
- Automatic encryption at rest

**Networking**:

- 10 TB outbound data transfer per month
- Virtual Cloud Network (VCN) - free
- Flexible Network Load Balancer (1 instance @ 10 Mbps)
- DDoS protection included

**Kubernetes**:

- Oracle Kubernetes Engine (OKE) managed service
- Free control plane with Always Free compute
- VCN-Native Pod Networking CNI (recommended)
- Automatic upgrades and patching
- Integration with Oracle Cloud services

**Additional Resources**:

- Object Storage: 20 GB (with API compatibility)
- Archive Storage: 20 GB
- Autonomous Database: 2 databases (20GB each) - optional
- Monitoring, logging, notifications included

### Use Case Fit

Our infrastructure needs align perfectly with Oracle Cloud Always Free:

**Perfect Fit**:

- Small to medium development/testing workloads
- Cost-conscious production for low-traffic applications
- Learning and experimentation
- Proof of concept and MVP development
- Personal projects and side projects
- Small business applications (<1000 users)

**Scaling Path**:

- Start with Always Free (0-100 users)
- Add paid resources as needed (100-1000 users)
- Migrate to DigitalOcean for simplicity at scale (1000+ users)
- Use hybrid approach for geographic distribution

## Decision

We will use **Oracle Cloud** as our primary cloud provider, with **DigitalOcean** as secondary for scaling and disaster recovery.

### Oracle Cloud - Primary (Always Free Tier)

**Core Services**:

1. **OKE (Oracle Kubernetes Engine)**
   - Managed Kubernetes clusters (free control plane)
   - VCN-Native Pod Networking CNI (direct pod routing)
   - 2-4 node configurations within free tier limits
   - Automatic control plane upgrades
   - Integration with Oracle Cloud services
   - Kubernetes 1.28+ support

2. **Compute (VM.Standard.A1.Flex)**
   - Ampere A1 Arm processors
   - Flexible instance sizing
   - Up to 4 OCPUs + 24GB RAM total
   - Custom OCPU/memory ratios
   - Always-on availability

3. **Virtual Cloud Network (VCN)**
   - Private networking (free)
   - Subnets, route tables, security lists
   - NAT Gateway for private subnet internet access
   - Internet Gateway for public-facing services
   - DDoS protection included

4. **Block Storage**
   - 200 GB total SSD storage
   - Persistent volumes for Kubernetes
   - Encryption at rest (automatic)
   - Backup and snapshot support
   - Volume expansion without downtime

5. **Object Storage**
   - 20 GB storage (S3-compatible API)
   - Application file storage
   - Container image registry (OCIR)
   - Integration with Kubernetes CSI driver

6. **Load Balancer**
   - Flexible Network Load Balancer (Layer 4)
   - 1 instance @ 10 Mbps (free)
   - Health checks and failover
   - Kubernetes Service integration
   - SSL/TLS passthrough

### DigitalOcean - Secondary (On-Demand)

**Use Cases**:

- **Scaling Beyond Free Tier**: When workload exceeds 4 OCPU + 24GB RAM
- **Geographic Expansion**: Additional regions for global presence
- **Disaster Recovery**: Backup infrastructure for high availability
- **Simplified Operations**: When operational simplicity outweighs cost savings
- **Enterprise Features**: Advanced monitoring, compliance, dedicated support

**Services** (as needed):

- DOKS (DigitalOcean Kubernetes)
- Managed databases
- Additional geographic regions
- Advanced networking (VPC peering, private links)
- Enhanced monitoring and alerting

### Integration Strategy

**Hybrid Cloud Architecture**:

```
┌─────────────────────────────────────────────────────────┐
│  Cloudflare (Edge Layer)                                │
│  - DNS Management                                       │
│  - CDN & DDoS Protection                                │
│  - SSL/TLS Termination                                  │
│  - Load Balancing & Failover                            │
└─────────────────┬───────────────────────────────────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
┌───────▼────────┐   ┌──────▼────────┐
│ Oracle Cloud   │   │ DigitalOcean  │
│ (Primary)      │   │ (Secondary)   │
│                │   │               │
│ • OKE Cluster  │   │ • DOKS (DR)   │
│ • Always Free  │   │ • Scaling     │
│ • Development  │   │ • Production  │
│ • Low Traffic  │   │ • Enterprise  │
└────────────────┘   └───────────────┘
```

**Traffic Routing**:

- Cloudflare DNS directs traffic to Oracle Cloud by default
- Automatic failover to DigitalOcean if Oracle Cloud unavailable
- Load balancing across both clouds for high-traffic scenarios
- Geographic routing: Oracle (primary region), DigitalOcean (other regions)

### Regional Strategy

**Oracle Cloud**:

- **Primary Region**: Phoenix (us-phoenix-1) or Ashburn (us-ashburn-1)
  - Arm instance availability
  - Low latency to North America
  - All Always Free services available

**DigitalOcean** (backup):

- **Secondary Region**: NYC3 (existing infrastructure)
- **Disaster Recovery**: SFO3 or AMS3 for geographic diversity

### CNI Plugin Selection

**Oracle Cloud - VCN-Native Pod Networking (Recommended)**:

- Pods receive real VCN IP addresses from subnet
- Direct pod-to-pod communication without overlay
- Better integration with Oracle Cloud services
- Support for Virtual Node Pools (serverless)
- Lower latency, no encapsulation overhead
- Direct routing from on-premise via VPN/peering

**Alternative - Flannel CNI**:

- Simple overlay network
- Doesn't consume VCN IP addresses
- Isolated pod network
- Only for simple dev/test environments

## Consequences

### Positive

- **Cost Elimination**: $0/month vs $90-120/month = **$1,200-1,440 annual savings**
  - Zero compute costs (Always Free tier)
  - Zero Kubernetes control plane costs
  - Zero storage costs (within 200GB)
  - Zero load balancer costs
  - Zero outbound transfer costs (within 10TB)

- **Better Resources**: More capacity within free tier
  - 4 OCPUs vs 2 vCPUs (DO equivalent)
  - 24GB RAM vs 6GB RAM (3×DO nodes)
  - 200GB storage vs ~100GB
  - Modern Arm processors (Ampere A1)
  - Better performance per core

- **Managed Kubernetes**: Still fully managed (OKE)
  - Same quality as paid managed Kubernetes
  - Automatic control plane updates
  - Integration with Oracle Cloud services
  - Production-ready and reliable

- **Future-Proof Scaling**: Clear path to growth
  - Start free, add paid resources as needed
  - Keep DigitalOcean for enterprise features
  - Hybrid cloud provides redundancy
  - No forced migration under time pressure

- **Learning Opportunity**: Expand cloud provider expertise
  - Gain Oracle Cloud experience
  - Understand multi-cloud architecture
  - Build portable infrastructure patterns
  - Improve cloud-agnostic design

- **No Time Pressure**: Always Free has no expiration
  - Unlike trial credits that expire
  - No surprise charges after trial
  - Stable long-term planning
  - Can grow at natural pace

### Negative

- **Account Provisioning Challenges**: High demand for free tier
  - Arm instances can be difficult to provision in some regions
  - May require trying multiple regions
  - Account verification process can be strict
  - Oracle may review/restrict suspicious activity

- **Oracle Cloud Complexity**: Steeper learning curve than DigitalOcean
  - More complex UI and console
  - Different terminology and concepts
  - IAM and networking more complex
  - Documentation less beginner-friendly

- **Arm Architecture Considerations**: Some compatibility concerns
  - Not all container images support Arm (arm64)
  - May need to build multi-arch images
  - Some legacy software may not work
  - Testing required for compatibility

- **Free Tier Limitations**: Resource constraints
  - Hard limit of 4 OCPUs + 24GB RAM
  - Can't burst beyond free tier without charges
  - 200GB storage limit
  - 10TB bandwidth limit (generous but not unlimited)

- **Community and Ecosystem**: Smaller than hyperscalers
  - Less community content and tutorials
  - Fewer third-party integrations
  - Smaller marketplace
  - Less Stack Overflow coverage

- **Support Limitations**: Free tier has limited support
  - Community support only
  - No SLA for free tier
  - Ticket response times longer
  - No dedicated support representatives

### Trade-offs

- **Cost vs. Complexity**: Significant savings justify learning curve
  - Accept complexity for $1,200+/year savings
  - Can always migrate back to DigitalOcean if needed
  - Learning Oracle Cloud is valuable skill

- **Free Tier vs. Enterprise Features**: Appropriate for project phase
  - Always Free perfect for development/testing
  - Scale to DigitalOcean when revenue justifies cost
  - Hybrid approach provides best of both worlds

- **Arm Architecture vs. Compatibility**: Manageable with planning
  - Most modern images support multi-arch
  - Can build custom images if needed
  - Testing catches compatibility issues early

## Alternatives Considered

### Stay with DigitalOcean Only

**Why not chosen**:

- **Cost**: $90-120/month for small workloads is expensive
- **No Free Tier**: Trial credits expire after 60 days
- **Limited Scaling**: No clear path to reduce costs
- **Missed Opportunity**: Free tier from Oracle Cloud unused

**When to reconsider**: When operational simplicity more valuable than cost savings (enterprise scale)

### Use AWS Free Tier

**Why not chosen**:

- **Time Limited**: 12 months only, then full charges
- **EKS Not Free**: $73/month for control plane
- **Resource Limits**: Only t3.micro (1 vCPU, 1GB RAM) × 750 hours
- **Complexity**: Highest complexity of all providers
- **Poor Fit**: Not suitable for Always Free Kubernetes

### Use Azure Free Tier

**Why not chosen**:

- **Time Limited**: 12 months only, then charges
- **Resource Limits**: Very limited compute in free tier
- **AKS Costs**: Node compute charges apply
- **Complexity**: Medium-high complexity
- **No Always Free**: No permanent free tier like Oracle

### Use GCP Free Tier

**Why not chosen**:

- **Time Limited**: 90-day trial or $300 credit
- **GKE Costs**: $73/month for Autopilot minimum
- **Resource Limits**: e2-micro only (0.25 vCPU, 1GB)
- **Not Always Free**: No permanent Kubernetes option
- **Cost**: Similar to DigitalOcean after credits expire

### Self-Hosted Kubernetes Only (On-Premise)

**Why not chosen** (reaffirmed from ADR-0013):

- **No High Availability**: Single point of failure
- **No Geographic Distribution**: Can't serve global users with low latency
- **Maintenance Burden**: Hardware, power, network management
- **No Free Tier Advantage**: Still need cloud for production edge services

**Hybrid Approach**: Use Oracle Cloud for public-facing, on-premise for internal (continues ADR-0009 strategy)

## Implementation Plan

### Phase 1: Oracle Cloud Foundation (Week 1)

1. **Account Setup**
   - Create Oracle Cloud account
   - Complete account verification (ID verification may be required)
   - Enable 2FA and security settings
   - Set up billing alerts (even for free tier monitoring)

2. **Region Selection**
   - Test Arm instance availability across regions
   - Choose region with best availability (us-phoenix-1 or us-ashburn-1)
   - Document region selection rationale

3. **Terraform Integration**
   - Set up Oracle Cloud Infrastructure (OCI) provider
   - Configure authentication (API keys, instance principal)
   - Create base VCN infrastructure
   - Test resource provisioning

4. **Resource Provisioning**
   - Create VCN with public/private subnets
   - Provision Ampere A1 compute instances (test sizing)
   - Set up security lists and route tables
   - Configure NAT and Internet Gateways

### Phase 2: Kubernetes Cluster Setup (Week 1-2)

1. **OKE Cluster Creation**
   - Create managed OKE cluster (free control plane)
   - Configure node pool with VM.Standard.A1.Flex shape
   - Choose VCN-Native Pod Networking CNI
   - Set up 2-node initial configuration (2 OCPU, 12GB each)

2. **Cluster Configuration**
   - Configure kubectl access
   - Install cluster add-ons (metrics-server, CSI drivers)
   - Set up persistent storage (block volumes)
   - Configure cluster networking and policies

3. **Service Integration**
   - Configure Flexible Network Load Balancer
   - Set up ingress controller (nginx)
   - Install cert-manager for SSL/TLS
   - Test external access and routing

4. **Monitoring Setup**
   - Enable OCI Monitoring (free tier)
   - Set up logging (OCI Logging)
   - Configure alerts for free tier limits
   - Install Prometheus/Grafana (optional)

### Phase 3: Application Migration (Week 2-3)

1. **Container Image Compatibility**
   - Audit existing images for Arm support
   - Build multi-arch images (amd64 + arm64)
   - Test applications on Arm architecture
   - Update CI/CD pipelines for multi-arch builds

2. **Application Deployment**
   - Deploy test applications to OKE
   - Verify functionality and performance
   - Test persistent storage and networking
   - Validate SSL/TLS and ingress

3. **Data Migration**
   - Set up object storage in OCI
   - Migrate small datasets for testing
   - Configure backup/restore procedures
   - Test data access and APIs

4. **DNS Cutover Planning**
   - Document DNS change procedures
   - Plan rollback strategy
   - Set low TTLs for fast switching
   - Coordinate with team

### Phase 4: Hybrid Cloud Integration (Week 3-4)

1. **Cloudflare Configuration**
   - Update DNS to point to Oracle Cloud Load Balancer
   - Configure health checks and failover to DigitalOcean
   - Set up load balancing rules
   - Test failover scenarios

2. **DigitalOcean Secondary Setup**
   - Keep existing DOKS cluster for disaster recovery
   - Configure cross-cloud backup strategy
   - Set up data replication (if needed)
   - Test failover procedures

3. **Network Integration**
   - Configure Tailscale for hybrid networking
   - Test connectivity between Oracle Cloud and on-premise
   - Set up VPN or peering if needed
   - Document network topology

4. **Final Testing and Validation**
   - End-to-end testing of entire stack
   - Performance benchmarking
   - Load testing and stress testing
   - Security scanning and vulnerability assessment

### Phase 5: Production Cutover (Week 4)

1. **Pre-Cutover Checklist**
   - All applications tested and validated
   - Backup and rollback procedures documented
   - Team trained on Oracle Cloud operations
   - Monitoring and alerting configured

2. **DNS Cutover**
   - Update Cloudflare DNS to Oracle Cloud (primary)
   - Monitor traffic and error rates
   - Verify all services operational
   - Keep DigitalOcean as secondary/backup

3. **Post-Cutover Monitoring**
   - 24-hour intensive monitoring
   - Track performance metrics
   - Monitor costs (should be $0)
   - Gather team feedback

4. **Documentation and Knowledge Transfer**
   - Update all runbooks for Oracle Cloud
   - Create troubleshooting guides
   - Document lessons learned
   - Train team on new infrastructure

### Phase 6: Cost Optimization (Ongoing)

1. **Resource Right-Sizing**
   - Monitor actual resource usage
   - Adjust node sizing within free tier limits
   - Optimize container resource requests/limits
   - Clean up unused resources

2. **DigitalOcean Optimization**
   - Scale down or pause DigitalOcean resources
   - Keep minimal DR infrastructure
   - Consider spot instances for non-critical workloads
   - Document cost savings

3. **Free Tier Monitoring**
   - Set up alerts for approaching free tier limits
   - Monitor storage usage (200GB limit)
   - Track bandwidth usage (10TB limit)
   - Plan for scaling if limits approached

## Success Metrics

### Cost Metrics

- **Monthly Cloud Spend**: $0 for Oracle Cloud (target), monitor DigitalOcean secondary costs
- **Annual Savings**: $1,200-1,440 compared to DigitalOcean baseline
- **Cost Per User**: Track as user base grows
- **Unexpected Charges**: Zero (strict free tier adherence)

### Performance Metrics

- **Cluster Uptime**: >99.9% (same as DigitalOcean SLO)
- **API Response Times**: <200ms (p95) - comparable or better
- **Application Performance**: No regression from DigitalOcean
- **Arm Compatibility**: >95% of workloads run without modification

### Operational Metrics

- **Provisioning Time**: <1 hour for new resources (vs minutes on DO)
- **Deployment Success Rate**: >95% (same as DigitalOcean)
- **Incident Response Time**: <15 minutes (same as DigitalOcean)
- **Mean Time to Recovery (MTTR)**: <1 hour

### Learning Metrics

- **Team Proficiency**: Team comfortable with Oracle Cloud within 2 months
- **Documentation Coverage**: Complete runbooks for all operations within 1 month
- **Successful DR Drill**: Complete disaster recovery test within 2 months
- **Multi-Cloud Competency**: Demonstrated ability to manage hybrid cloud

### Business Metrics

- **Feature Velocity**: No decrease in delivery speed due to platform change
- **User Satisfaction**: No negative impact from infrastructure change
- **Resource Utilization**: Efficient use of free tier resources (>50% utilization)
- **Scaling Preparedness**: Clear plan for growth beyond free tier

## Security Considerations

### Access Control

- **API Keys**: Secure storage in GitHub Secrets and Ansible Vault
- **IAM Policies**: Least privilege principle for all users and services
- **MFA Enforcement**: Required for all human users
- **Service Accounts**: Separate credentials for automation vs manual access
- **Key Rotation**: Quarterly rotation of API keys and tokens

### Network Security

- **VCN Isolation**: Private VCN for all internal communication
- **Security Lists**: Default deny, explicit allow rules
- **Network Security Groups**: Fine-grained pod-level controls
- **DDoS Protection**: Cloudflare + OCI DDoS protection
- **VPN/Peering**: Secure connectivity to on-premise (via Tailscale)

### Data Security

- **Encryption at Rest**: Automatic for block storage, object storage
- **Encryption in Transit**: TLS 1.2+ for all communication
- **Secrets Management**: Kubernetes Secrets + External Secrets Operator
- **Backup Encryption**: Encrypted backups with access control
- **Key Management**: OCI Vault for encryption key management (if needed)

### Compliance

- **Security Scanning**: Trivy for container image vulnerabilities
- **CIS Benchmarks**: Apply to OKE clusters and VCN
- **Audit Logging**: Enable OCI audit logs for all infrastructure changes
- **Vulnerability Management**: Regular scanning and patching
- **Policy Enforcement**: OPA (Open Policy Agent) for Kubernetes policies

### Free Tier Security Considerations

- **Account Protection**: Strong password, MFA, account monitoring
- **Resource Limits**: Alerts when approaching free tier limits
- **Cost Alerts**: Monitor for unexpected charges
- **Access Monitoring**: Regular review of access logs
- **Abuse Prevention**: Follow Oracle Cloud acceptable use policy

## Migration Strategy

### Migration from DigitalOcean to Oracle Cloud

**Timeline**: 4 weeks (phased approach)

**Steps**:

1. **Parallel Infrastructure** (Week 1-2): Build Oracle Cloud in parallel
2. **Application Testing** (Week 2-3): Test all workloads on Oracle Cloud
3. **Gradual Traffic Shift** (Week 3): Route percentage of traffic to Oracle Cloud
4. **Full Cutover** (Week 4): Move all traffic, keep DigitalOcean as backup
5. **Cleanup** (Week 4+): Scale down DigitalOcean, keep DR only

**Rollback Plan**:

- Keep DigitalOcean infrastructure operational during migration
- Cloudflare DNS allows instant traffic switching
- Document rollback procedures before cutover
- Test rollback in development environment

### Scaling Beyond Free Tier

When workload exceeds Always Free limits:

**Option 1: Add Paid Oracle Cloud Resources**

- Add paid compute instances (same region, easy integration)
- Upgrade to larger OKE cluster with paid nodes
- Add paid block storage beyond 200GB
- Cost: Competitive with DigitalOcean at similar scale

**Option 2: Hybrid Approach (Recommended)**

- Keep Always Free tier for development/testing
- Use DigitalOcean for production scaling
- Use Oracle Cloud for cost-effective workloads
- Use both for geographic distribution

**Option 3: Migrate Back to DigitalOcean**

- If simplicity becomes more valuable than cost savings
- If Oracle Cloud complexity hinders operations
- Terraform makes migration feasible
- Estimated effort: 1-2 weeks

### Geographic Expansion Strategy

**Multi-Region Approach**:

- **Oracle Cloud**: Primary region (us-phoenix-1 or us-ashburn-1)
- **DigitalOcean**: Additional regions (NYC3, SFO3, AMS3, etc.)
- **Cloudflare**: Global DNS and load balancing
- **Use Case**: Serve users globally with low latency

## Future Considerations

### Optimization Opportunities

- **Virtual Node Pools**: Serverless Kubernetes nodes (when available in free tier regions)
- **Autonomous Database**: Consider 2 free Autonomous DB instances for applications
- **OCI Functions**: Serverless compute for event-driven workloads
- **Service Mesh**: Istio or Linkerd for advanced traffic management
- **GitOps**: ArgoCD or Flux for continuous deployment

### Monitoring Enhancements

- **OCI Monitoring**: Utilize built-in monitoring (free tier)
- **Logging Analytics**: Centralized log management
- **Application Performance Monitoring**: Add APM when needed
- **Cost Monitoring**: Track resource usage against free tier limits

### Multi-Cloud Best Practices

- **Terraform Modules**: Abstract provider-specific details
- **Kubernetes Workloads**: Keep manifests cloud-agnostic
- **Storage Abstraction**: Use S3-compatible APIs (Cloudflare R2)
- **Networking**: Standardize on common patterns (Tailscale mesh)

### Long-Term Strategy

- **Month 1-3**: Stabilize on Oracle Cloud, build operational knowledge
- **Month 3-6**: Optimize for performance and cost efficiency
- **Month 6-12**: Evaluate scaling needs, hybrid cloud maturity
- **Year 1+**: Decide on long-term cloud strategy based on business needs

## References

- [Oracle Cloud Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- [Oracle Kubernetes Engine (OKE) Documentation](https://docs.oracle.com/en-us/iaas/Content/ContEng/home.htm)
- [OCI VCN-Native Pod Networking](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengpodnetworking_topic-OCI_CNI_plugin.htm)
- [Oracle Cloud Ampere A1 Compute](https://www.oracle.com/cloud/compute/arm/)
- [Oracle Cloud Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [ADR-0013: DigitalOcean as Primary Cloud Provider](0013-digitalocean-primary-cloud.md) (Superseded)
- [ADR-0004: Cloudflare DNS and Edge Services](0004-cloudflare-dns-services.md)
- [ADR-0005: Kubernetes as Container Platform](0005-kubernetes-container-platform.md)
- [ADR-0009: Tailscale for Hybrid Cloud Networking](0009-tailscale-hybrid-networking.md)
- [Cost Analysis: Oracle Cloud vs DigitalOcean](../research/0004-oracle-vs-digitalocean-cost.md) (to be created)
