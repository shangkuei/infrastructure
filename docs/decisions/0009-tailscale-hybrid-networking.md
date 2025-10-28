# 9. Tailscale for Hybrid Cloud Networking

Date: 2025-10-21

## Status

Accepted

## Context

Our hybrid cloud infrastructure spans multiple cloud providers (AWS, Azure, GCP, DigitalOcean) and on-premise data centers, creating complex networking challenges:

- **Multi-Cloud Connectivity**: Need secure, performant connections between different cloud providers
- **Hybrid Architecture**: On-premise infrastructure must communicate with cloud resources
- **Developer Access**: Team members need secure access to infrastructure across environments
- **Operational Overhead**: Traditional VPN solutions (OpenVPN, IPsec) require significant manual configuration and ongoing maintenance
- **Scalability**: Network must support hundreds of nodes across geographic regions
- **Security Requirements**: Zero-trust networking with identity-based access control
- **Cost Management**: VPN gateway costs and operational overhead impact budget

Our initial research ([Hybrid Cloud Networking](../research/0007-hybrid-cloud-networking.md)) identified WireGuard as a promising solution due to its performance and modern
cryptography. However, raw WireGuard requires extensive manual configuration that doesn't scale well:

- Manual peer configuration and key exchange
- Complex NAT traversal setup
- Manual DNS configuration
- Firewall rule management per node
- No centralized access control

We need a networking solution that:

- Provides WireGuard-level performance and security
- Scales from development to production (100+ nodes)
- Minimizes operational overhead and manual configuration
- Supports identity-based access control
- Works seamlessly across cloud providers and on-premise infrastructure
- Enables zero-trust security model

## Decision

We will adopt **Tailscale** as the primary networking solution for hybrid cloud connectivity and secure access.

Specifically:

- **Tailscale mesh network** will connect all cloud VPCs, Kubernetes clusters, and on-premise infrastructure
- **Subnet routing** will provide access to private subnets without requiring Tailscale on every node
- **ACL-based access control** will enforce least-privilege access based on user identity and resource tags
- **SSO integration** with GitHub will provide authentication for team access
- **MagicDNS** will enable service discovery and DNS resolution across the network
- **Managed Tailscale service** (not self-hosted Headscale) will be used initially for reduced operational overhead

## Consequences

### Positive

**Operational Efficiency**:

- ✅ **Zero-configuration networking**: Automatic NAT traversal, peer discovery, and encryption
- ✅ **Minimal maintenance**: ~1 hour/month vs. ~20 hours/month for raw WireGuard
- ✅ **Fast deployment**: 30 minutes to deploy vs. days for traditional VPN
- ✅ **Automatic key rotation**: No manual key management required

**Security**:

- ✅ **WireGuard foundation**: Modern, audited cryptography (Noise protocol)
- ✅ **Identity-based access**: SSO integration with GitHub eliminates shared secrets
- ✅ **Centralized ACLs**: GitOps-friendly access control with audit trail
- ✅ **Zero-trust model**: Every connection authenticated and authorized
- ✅ **Least privilege**: Granular access control by user, environment, and service

**Performance**:

- ✅ **Mesh architecture**: Direct peer-to-peer connections minimize latency
- ✅ **High throughput**: 900+ Mbps performance (WireGuard-equivalent)
- ✅ **Low latency**: 1-5ms overhead, negligible impact
- ✅ **Efficient NAT traversal**: >95% achieve direct connections

**Developer Experience**:

- ✅ **Simple setup**: Single command to join network (`tailscale up`)
- ✅ **MagicDNS**: Access services by name, not IP address
- ✅ **Cross-platform**: Works on all developer machines (macOS, Linux, Windows)
- ✅ **Mobile support**: iOS/Android apps for on-the-go access

**Cost**:

- ✅ **Predictable pricing**: $6/user/month for Team plan
- ✅ **No gateway costs**: Eliminates AWS VPN Gateway costs ($0.05/hour = $36/month each)
- ✅ **Lower TCO**: Reduced operational overhead saves engineering time
- ✅ **Free tier available**: 20 devices for initial testing

**Multi-Cloud Support**:

- ✅ **Vendor-neutral**: Works across AWS, Azure, GCP, DigitalOcean, on-premise
- ✅ **No lock-in**: Avoids cloud provider-specific VPN solutions
- ✅ **Unified management**: Single control plane for entire hybrid infrastructure

### Negative

**Dependencies**:

- ❌ **Internet dependency**: Requires internet connectivity for coordination (though established tunnels work offline)
- ❌ **Control plane trust**: Must trust Tailscale coordination server with connection metadata (not data)
- ❌ **SSO dependency**: Authentication relies on GitHub availability

**Limitations**:

- ❌ **No Layer 2 support**: Cannot bridge Ethernet networks (rarely needed)
- ❌ **UDP-based**: May face issues in networks that block UDP (can use DERP relay as fallback)
- ❌ **Managed service model**: Less infrastructure control than self-hosted solutions

**Costs**:

- ❌ **Subscription cost**: $600/month for 100 users (though justified by operational savings)
- ❌ **Vendor billing**: Ongoing SaaS expense vs. one-time infrastructure cost

**Migration Effort**:

- ❌ **Learning curve**: Team needs to learn Tailscale concepts (though minimal compared to alternatives)
- ❌ **ACL migration**: Need to translate existing firewall rules to Tailscale ACLs
- ❌ **Cutover risk**: Migration from existing networking requires careful planning

### Trade-offs

**Managed Service vs. Full Control**:

- **Choice**: Using managed Tailscale instead of self-hosted Headscale
- **Rationale**: Operational simplicity and enterprise features outweigh control requirements
- **Mitigation**: Can migrate to Headscale later if data sovereignty becomes critical

**Cost vs. Operational Efficiency**:

- **Choice**: Paying $600/month for 100 users vs. free raw WireGuard
- **Rationale**: Engineering time savings ($24,000/year at $100/hour) far exceed subscription cost
- **Calculation**: 19 hours/month saved × $100/hour × 12 months = $22,800/year savings

**Simplicity vs. Configurability**:

- **Choice**: Accepting Tailscale's opinionated design vs. full WireGuard flexibility
- **Rationale**: Standardization and simplicity more valuable than edge-case flexibility
- **Mitigation**: Tailscale supports most required use cases; raw WireGuard still available for edge cases

**Cloud vs. On-Premise Control**:

- **Choice**: Using cloud-based coordination server vs. fully on-premise solution
- **Rationale**: Hybrid model (data encrypted end-to-end, only metadata in cloud) acceptable for our threat model
- **Mitigation**: Headscale migration path available if requirements change

## Alternatives Considered

### Raw WireGuard (Manual Configuration)

**Why not chosen**:

- Requires 30-60 minutes of manual configuration per peer
- No automatic NAT traversal or peer discovery
- Manual key distribution and rotation (security risk)
- No centralized access control or audit logging
- Doesn't scale beyond ~20 nodes practically
- Estimated 20+ hours/month operational overhead for 100 nodes

**Trade-off**: Free but extremely high operational cost that doesn't scale.

### OpenVPN

**Why not chosen**:

- Hub-and-spoke architecture creates single point of failure and bottleneck
- Complex certificate management and PKI infrastructure required
- Lower performance (400-600 Mbps vs. 900+ Mbps with WireGuard)
- Higher latency (all traffic through central server)
- Older cryptography (OpenSSL vs. modern Noise protocol)
- Steep learning curve and ongoing maintenance burden

**Trade-off**: Mature and widely adopted but outclassed by modern solutions.

### ZeroTier

**Why not chosen**:

- Custom protocol (not WireGuard) with smaller security audit surface
- Less mature enterprise features compared to Tailscale
- Weaker SSO integration options
- Smaller community and ecosystem
- Layer 2 support not needed for our use cases

**Trade-off**: Excellent product but Tailscale's WireGuard foundation and enterprise features preferred.

### Netmaker

**Why not chosen**:

- Self-hosted only (no managed service option)
- Higher operational overhead than Tailscale managed service
- Less mature product with smaller community
- Requires maintaining server infrastructure
- More complex Kubernetes integration setup

**Trade-off**: Good for teams wanting full control, but operational overhead not justified for our needs.

### Cloud-Native VPN (AWS VPN Gateway, Azure VPN Gateway)

**Why not chosen**:

- Vendor-specific, creates multi-cloud complexity
- Requires separate VPN gateway in each cloud ($36/month each)
- Complex routing table and security group configuration
- High data transfer costs
- Vendor lock-in prevents hybrid flexibility
- No unified management across providers

**Trade-off**: Native cloud integration but vendor lock-in and complexity make it unsuitable for hybrid cloud.

### Self-Hosted Tailscale (Headscale)

**Why not chosen initially** (but may reconsider later):

- Less mature than commercial Tailscale service
- Requires maintaining coordination server infrastructure
- Missing some enterprise features (SCIM, advanced audit logging)
- Operational overhead higher than managed service
- Limited official support and documentation

**Trade-off**: Full control and data sovereignty at cost of operational complexity. Will revisit if data residency requirements change.

## Implementation Plan

### Phase 1: Development Environment (Week 1-2)

1. **Setup Tailscale Organization**
   - Create Tailscale account with GitHub SSO
   - Define initial ACL policies for development environment
   - Configure MagicDNS settings

2. **Deploy Subnet Routers**
   - AWS development VPC subnet router
   - On-premise development subnet router
   - Test connectivity and performance

3. **Team Onboarding**
   - Developer machines join network
   - Test access to development resources
   - Validate ACL policies

### Phase 2: Staging Environment (Week 3-4)

1. **Staging Infrastructure**
   - Deploy subnet routers in staging VPCs (AWS, Azure)
   - Configure ACLs for staging environment tags
   - Set up monitoring and alerting

2. **Testing and Validation**
   - Performance benchmarking (throughput, latency)
   - Failover testing (subnet router redundancy)
   - Security testing (ACL validation, penetration testing)

### Phase 3: Production Rollout (Week 5-8)

1. **Production Deployment**
   - Deploy subnet routers in production VPCs (all clouds)
   - Configure production ACLs with strict least-privilege
   - Enable audit logging and monitoring

2. **Migration from Existing Solutions**
   - Parallel run with existing VPN solutions
   - Gradual migration of services and users
   - Decommission legacy VPN infrastructure

3. **Documentation and Training**
   - Create operational runbooks
   - Train SRE team on Tailscale operations
   - Document troubleshooting procedures

### Success Criteria

- ✅ All cloud VPCs and on-premise infrastructure connected via Tailscale
- ✅ Developers can access all environments through SSO authentication
- ✅ ACL policies enforce least-privilege access by environment
- ✅ Performance meets requirements (>500 Mbps throughput, <20ms latency)
- ✅ Monitoring and alerting operational
- ✅ Documentation complete for common operations
- ✅ Legacy VPN infrastructure decommissioned

## Monitoring and Success Metrics

### Key Performance Indicators

- **Connection Success Rate**: >99% of nodes successfully connected
- **Direct Connection Ratio**: >95% direct connections (vs. DERP relay)
- **Mean Time to Connect**: <10 seconds for new nodes
- **Network Latency**: <20ms p99 between nodes (vs. baseline without Tailscale)
- **Throughput**: >500 Mbps between nodes (validated via iperf3)

### Operational Metrics

- **ACL Update Frequency**: Track changes to access policies
- **Unauthorized Access Attempts**: Monitor denied connections
- **Node Inventory Drift**: Alert on unexpected nodes or missing nodes
- **Time to Onboard New User**: <5 minutes from account creation to network access
- **Operational Time**: <2 hours/month for ongoing maintenance

### Cost Metrics

- **Monthly Subscription Cost**: Track against budget
- **Operational Time Savings**: Compare to previous VPN solution maintenance
- **Gateway Cost Savings**: Decommissioned VPN gateways ($36/month each)
- **Total Cost of Ownership**: Overall cost including operational overhead

## Security and Compliance

### Security Measures

- **ACL Version Control**: All ACL changes tracked in Git
- **Regular Access Reviews**: Quarterly audit of user access and permissions
- **Audit Log Monitoring**: Alert on suspicious connection patterns
- **Least Privilege Enforcement**: No overly permissive ACL rules
- **SSO Integration**: Leverage GitHub's 2FA and security features

### Compliance Considerations

- **SOC 2**: Tailscale is SOC 2 Type II compliant
- **Audit Trail**: Complete connection and ACL change history
- **Data Sovereignty**: Evaluate Headscale if data residency becomes requirement
- **Encryption Standards**: WireGuard uses approved modern cryptography

## Rollback Plan

If Tailscale fails to meet requirements:

1. **Immediate Rollback** (if critical issues in production):
   - Keep existing VPN infrastructure operational during migration
   - DNS failover to bypass Tailscale subnet routers
   - Revert to direct VPN connections
   - Estimated rollback time: <1 hour

2. **Alternative Solutions**:
   - **Short-term**: Revert to enhanced WireGuard setup with better automation
   - **Long-term**: Evaluate Headscale (self-hosted) or Netmaker if control requirements change

3. **Lessons Learned**:
   - Document issues encountered
   - Conduct post-mortem analysis
   - Update decision record with new information

## Future Considerations

### Potential Enhancements

- **Headscale Migration**: If data sovereignty becomes critical requirement
- **Advanced Monitoring**: Integration with existing observability stack (Prometheus, Grafana)
- **Kubernetes Operator**: Deploy Tailscale via operator for better Kubernetes integration
- **Terraform Provider**: Manage Tailscale configuration as infrastructure-as-code
- **Exit Nodes**: Consider using for remote access scenarios

### Re-evaluation Triggers

- **Cost Escalation**: If user count grows >500 and cost becomes prohibitive
- **Data Sovereignty Requirements**: Regulatory requirements for data residency
- **Performance Issues**: If Tailscale fails to meet performance SLAs
- **Feature Gaps**: If critical features are unavailable in Tailscale
- **Vendor Concerns**: Tailscale acquisition or significant product changes

This decision will be reviewed annually or when triggered by significant changes in requirements, cost structure, or available alternatives.

## References

- [Research: Tailscale Evaluation](../research/0017-tailscale-evaluation.md)
- [Research: Hybrid Cloud Networking](../research/0007-hybrid-cloud-networking.md)
- [Technical Spec: Tailscale Mesh Network](../../specs/network/tailscale-mesh-network.md)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [WireGuard Protocol](https://www.wireguard.com/)
- [Zero Trust Networking](https://www.cloudflare.com/learning/security/glossary/what-is-zero-trust/)
- [ADR-0004: Cloudflare DNS and Edge Services](0004-cloudflare-dns-services.md)

## Related Decisions

- [ADR-0001: Infrastructure as Code](0001-infrastructure-as-code.md) - Tailscale ACLs managed as code
- [ADR-0005: Kubernetes as Container Platform](0005-kubernetes-container-platform.md) - Tailscale enables multi-cluster networking
- [ADR-0007: GitOps Workflow](0007-gitops-workflow.md) - ACL configuration follows GitOps principles
- [ADR-0008: Secret Management Strategy](0008-secret-management.md) - Tailscale auth keys stored in secret management system
