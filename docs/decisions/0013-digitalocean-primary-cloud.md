# 13. Digital Ocean as Primary Cloud Provider

Date: 2025-10-21

## Status

Accepted

## Context

For a hybrid cloud infrastructure supporting small companies and personal projects, we need a cloud provider that offers:

- **Cost-Effective Infrastructure**: Predictable, affordable pricing for compute, storage, and networking
- **Managed Kubernetes**: Kubernetes cluster without control plane costs
- **Simple Operations**: Easy to understand and manage services
- **Infrastructure as Code Support**: Mature Terraform provider for automation
- **Learning-Friendly**: Good documentation and low complexity for skill development
- **Production-Ready**: Reliable enough for production workloads
- **Hybrid Cloud Support**: Ability to integrate with on-premise infrastructure

Based on [Research: Cloud Provider Evaluation](../research/0003-cloud-provider-evaluation.md), we evaluated DigitalOcean, AWS, Azure, and GCP for suitability in our use case.

### Cost Comparison

For a typical 3-node Kubernetes cluster with load balancer and storage:

| Provider | Monthly Cost | Free Tier | Control Plane Cost |
|----------|--------------|-----------|-------------------|
| **DigitalOcean** | $58 | $200/60 days | $0 (free) |
| **AWS (EKS)** | $150 | 12 months limited | $73/month |
| **Azure (AKS)** | $68 | $200/30 days | $0 (free) |
| **GCP (GKE)** | $60 | $300/90 days | $73/month |

### Learning Curve Assessment

- **DigitalOcean**: Low complexity, straightforward services, excellent documentation
- **AWS**: High complexity, steep learning curve, extensive services can be overwhelming
- **Azure**: Medium complexity, Microsoft-centric ecosystem
- **GCP**: Medium complexity, strong on data/ML, less general-purpose documentation

### Use Case Fit

Our infrastructure needs:

- Small to medium production workloads
- Development and learning environment
- Hybrid cloud with on-premise integration
- Budget consciousness
- Infrastructure as Code (Terraform) automation
- Room to grow without massive complexity

## Decision

We will use **DigitalOcean** as our primary cloud provider for the following services:

### Core Services

1. **DOKS (DigitalOcean Kubernetes Service)**
   - Managed Kubernetes clusters
   - Free control plane (save $73/month vs AWS EKS)
   - Auto-scaling support
   - Integrated with DO ecosystem
   - 1-click cluster creation
   - Automatic upgrades available

2. **Droplets (Virtual Machines)**
   - When Kubernetes is overkill
   - Simple VM instances for specific workloads
   - Various sizes from $4/month to high-memory options
   - Team collaboration features
   - Snapshot and backup support

3. **Spaces (Object Storage)**
   - S3-compatible API
   - $5/month for 250GB + 1TB outbound transfer
   - Terraform state backend
   - Application file storage
   - CDN integration available

4. **Managed Databases**
   - PostgreSQL, MySQL, Redis, MongoDB
   - Automated backups (daily)
   - Point-in-time recovery
   - High availability clusters
   - Automatic minor version updates
   - Connection pooling built-in

5. **Load Balancers**
   - $10/month per load balancer
   - SSL/TLS termination
   - Health checks
   - Sticky sessions
   - Kubernetes integration

6. **Container Registry**
   - Private Docker registry
   - $5/month for 500GB storage
   - Vulnerability scanning
   - Integration with DOKS
   - Garbage collection

7. **VPC (Virtual Private Cloud)**
   - Private networking (free)
   - Network isolation
   - Security groups
   - Firewall rules

8. **Block Storage (Volumes)**
   - SSD volumes for persistent storage
   - $0.10/GB/month
   - Resize without downtime
   - Snapshot support
   - Kubernetes CSI driver

### Regional Strategy

**Primary Region**: NYC3 (New York City 3)

- Low latency to target users (North America)
- All services available
- Good reliability track record

**Secondary Region**: SFO3 (San Francisco 3) or AMS3 (Amsterdam 3)

- For future geographic distribution
- Disaster recovery failover

### Integration Points

- **Cloudflare**: DNS, CDN, DDoS protection (see ADR-0004)
- **Tailscale**: Hybrid cloud networking to on-premise (see ADR-0009)
- **GitHub Actions**: CI/CD pipeline integration (see ADR-0006)
- **Terraform**: Infrastructure as Code (see ADR-0002)

## Consequences

### Positive

- **Cost Savings**: ~60% cheaper than AWS for equivalent infrastructure
  - Free Kubernetes control plane saves $73/month
  - Predictable pricing model
  - Free egress within same datacenter
  - Free VPC networking

- **Simplicity**: Easier to learn and operate
  - Fewer service options means less decision paralysis
  - Consistent UI and API design
  - Straightforward documentation
  - Good default configurations

- **Developer Experience**: Excellent for small teams
  - Fast provisioning times (minutes, not hours)
  - Clean, modern web console
  - Comprehensive CLI (`doctl`)
  - Great API and Terraform support

- **Free Tier**: Generous trial for testing
  - $200 credit for 60 days
  - No credit card required for trial
  - Full service access during trial

- **Managed Services Quality**: High quality with reasonable pricing
  - Databases are production-ready
  - Kubernetes integrates well with other DO services
  - Load balancers are simple and reliable

- **Community**: Strong community and ecosystem
  - Extensive tutorials and guides
  - Active community forums
  - Third-party integrations

### Negative

- **Limited Geographic Reach**: Fewer regions than AWS/Azure/GCP
  - 15 datacenters vs AWS's 30+ regions
  - May not have presence in all markets
  - Potential latency for distant users

- **Fewer Managed Services**: Limited compared to hyperscalers
  - No managed Kafka, Elasticsearch clusters
  - No native serverless compute (Functions in beta)
  - No managed ML/AI services
  - No managed Kubernetes mesh options

- **Service Maturity**: Some services less mature
  - App Platform (PaaS) still evolving
  - Functions in beta (not production-ready)
  - Monitoring/alerting is basic

- **Enterprise Features**: Less enterprise-focused
  - No fine-grained IAM like AWS
  - Limited compliance certifications vs AWS/Azure
  - No dedicated support tiers for small accounts
  - SLA is 99.99% but enforcement unclear on lower tiers

- **Vendor Lock-in Risk**: Smaller company than hyperscalers
  - Acquisition risk
  - Service discontinuation risk
  - Migration complexity if needed

- **Advanced Networking**: Less sophisticated than AWS
  - No Transit Gateway equivalent
  - Limited VPN options (Tailscale fills gap)
  - No PrivateLink equivalent

### Trade-offs

- **Simplicity vs. Features**: Intentional trade-off for maintainability
  - We accept fewer features for operational simplicity
  - Can always migrate specific workloads to AWS/GCP if needed

- **Cost vs. Scale**: Optimized for small-medium workloads
  - Very cost-effective up to ~$500-1000/month
  - At larger scale, hyperscaler discounts may compete
  - Our use case is well within sweet spot

- **Regional Availability vs. Simplicity**: Fewer regions but easier management
  - Acceptable for North America-focused workloads
  - Can add multi-cloud if global presence needed

## Alternatives Considered

### Amazon Web Services (AWS)

**Why not chosen as primary**:

- **Cost**: 2-3x more expensive for equivalent infrastructure
  - EKS control plane: $73/month
  - More complex pricing with hidden costs
  - Data transfer costs add up quickly
- **Complexity**: Steep learning curve
  - Overwhelming service portfolio (200+ services)
  - Complex IAM and networking
  - Significant operational overhead
- **When to use**: Specific AWS services needed (Lambda, SageMaker, etc.)

**Migration Path**: Terraform makes migration feasible if requirements change

### Microsoft Azure (AKS)

**Why not chosen as primary**:

- **Cost**: ~17% more expensive than DigitalOcean
- **Complexity**: Medium complexity, Microsoft ecosystem focus
- **Learning Curve**: Steeper than DigitalOcean
- **When to use**: Windows workloads, Active Directory integration, .NET stack

**Migration Path**: Kubernetes workloads portable, infrastructure code adaptable

### Google Cloud Platform (GCP)

**Why not chosen as primary**:

- **Cost**: Similar to DigitalOcean but with control plane costs
  - GKE control plane: $73/month
  - Better free tier but limited duration
- **Complexity**: Medium complexity
- **When to use**: Data/ML workloads, BigQuery, Kubernetes Engine features
- **Strengths**: Good Kubernetes experience, excellent data services

**Migration Path**: Strong Terraform support enables migration

### Self-Hosted Only (On-Premise)

**Why not chosen**:

- **No High Availability**: Single point of failure for home infrastructure
- **No Geographic Distribution**: Can't serve users globally with low latency
- **Maintenance Burden**: Hardware failures, power outages, network issues
- **Cost**: Internet bandwidth costs, hardware replacement, electricity
- **Scalability**: Limited by home infrastructure capacity

**Hybrid Approach**: Use DigitalOcean for public-facing, on-premise for internal (see ADR-0009)

## Implementation Plan

### Phase 1: Foundation (Week 1)

1. **Account Setup**
   - Create DigitalOcean account
   - Enable 2FA
   - Configure billing alerts
   - Create team access

2. **Terraform Integration**
   - Set up DigitalOcean provider
   - Configure remote state in DO Spaces
   - Create base network infrastructure (VPC)
   - Document provider configuration

3. **Initial Resources**
   - Create VPC for production workloads
   - Set up Container Registry
   - Configure firewall rules

### Phase 2: Kubernetes Cluster (Week 1-2)

1. **DOKS Cluster Creation**
   - Create 3-node production cluster
   - Configure node pools
   - Set up auto-scaling policies
   - Install cert-manager

2. **Cluster Integrations**
   - Install ingress controller
   - Configure load balancer
   - Set up persistent storage (CSI driver)
   - Deploy monitoring stack

3. **CI/CD Integration**
   - Connect GitHub Actions to DOKS
   - Configure image push to Container Registry
   - Set up deployment workflows
   - Test end-to-end deployment

### Phase 3: Managed Services (Week 2-3)

1. **Database Setup**
   - Create managed PostgreSQL cluster
   - Configure backups and retention
   - Set up read replicas if needed
   - Test failover procedures

2. **Object Storage**
   - Create Spaces for application data
   - Configure CDN if needed
   - Set up lifecycle policies
   - Test backup/restore

3. **Monitoring Setup**
   - Enable DigitalOcean monitoring
   - Configure alerts
   - Integrate with Prometheus/Grafana
   - Set up log aggregation

### Phase 4: Hybrid Integration (Week 3-4)

1. **Network Connectivity**
   - Configure Tailscale mesh network
   - Connect DigitalOcean VPC to on-premise
   - Test connectivity and latency
   - Document network topology

2. **Disaster Recovery**
   - Set up cross-region backups
   - Test failover to on-premise
   - Document recovery procedures
   - Schedule regular DR drills

3. **Documentation**
   - Create runbooks for common operations
   - Document architecture diagrams
   - Write troubleshooting guides
   - Create onboarding documentation

## Success Metrics

### Cost Metrics

- Monthly cloud spend under $100 for production workloads
- Cost per application/service tracked
- No surprise charges or billing spikes

### Performance Metrics

- Cluster uptime >99.9%
- API response times <200ms (p95)
- Application deployment time <5 minutes
- Database query performance within acceptable ranges

### Operational Metrics

- Incident response time <15 minutes
- Mean time to recovery (MTTR) <1 hour
- Successful deployments >95%
- Backup success rate 100%

### Learning Metrics

- Team proficiency with DigitalOcean services within 1 month
- Runbook coverage for all critical operations
- Successful DR drill within 2 months

## Security Considerations

### Access Control

- Use API tokens with minimal required permissions
- Rotate API tokens quarterly
- Enable 2FA for all team members
- Use separate tokens for CI/CD vs manual operations
- Store tokens in GitHub Secrets, never in code

### Network Security

- Use private VPC for all internal communication
- Configure firewall rules (default deny, explicit allow)
- Use Cloudflare for DDoS protection
- Enable DigitalOcean Cloud Firewalls
- Regular security audit of network rules

### Data Security

- Enable encryption at rest for databases
- Use TLS for all data in transit
- Configure backup encryption
- Regular backup testing
- Secrets management via sealed secrets (see ADR-0008)

### Compliance

- Regular security scanning with Trivy
- Vulnerability assessment of container images
- Security patch management for cluster nodes
- Audit logging enabled where available
- Regular access review

## Migration Strategy

If migration from DigitalOcean becomes necessary:

### Migration to AWS/GCP/Azure

1. **Application Layer**: Kubernetes manifests are portable
2. **Infrastructure Layer**: Terraform modules need provider updates
3. **Data Layer**: Database migration via replication or backup/restore
4. **DNS Layer**: Update Cloudflare to point to new provider
5. **Estimated Effort**: 2-4 weeks for full migration

### Multi-Cloud Strategy (Future)

- Use Terraform modules to abstract provider specifics
- Standardize on Kubernetes for compute workloads
- Use S3-compatible APIs for object storage
- Consider Crossplane for multi-cloud orchestration

## Future Considerations

### Monitoring and Optimization

- Evaluate DigitalOcean App Platform for simple applications
- Consider DigitalOcean Functions when GA (serverless)
- Implement cost optimization automation
- Set up resource right-sizing recommendations

### Scaling Plans

- Add regional presence if user base expands globally
- Evaluate DigitalOcean Database read replicas for scale
- Consider cluster autoscaling for variable loads
- Plan for multi-region architecture if needed

### Service Expansion

- Explore DigitalOcean Managed Kafka when available
- Evaluate CDN Spaces for static content delivery
- Consider DO Monitoring for centralized observability
- Test new services as they become GA

## References

- [Research: Cloud Provider Evaluation](../research/0003-cloud-provider-evaluation.md)
- [DigitalOcean Pricing](https://www.digitalocean.com/pricing)
- [DigitalOcean Kubernetes (DOKS)](https://www.digitalocean.com/products/kubernetes)
- [DigitalOcean Terraform Provider](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)
- [DigitalOcean Documentation](https://docs.digitalocean.com/)
- [ADR-0004: Cloudflare DNS and Edge Services](0004-cloudflare-dns-services.md)
- [ADR-0005: Kubernetes as Container Platform](0005-kubernetes-container-platform.md)
- [ADR-0009: Tailscale for Hybrid Cloud Networking](0009-tailscale-hybrid-networking.md)
