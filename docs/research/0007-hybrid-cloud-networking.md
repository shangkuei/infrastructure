# Research: Hybrid Cloud Networking

Date: 2025-10-19
Last Updated: 2025-10-21
Author: Infrastructure Team
Status: Completed

## Objective

Research networking strategies to connect on-premise infrastructure with cloud resources securely and efficiently.

## Scope

- VPN solutions (WireGuard, OpenVPN, IPSec)
- Mesh networking solutions (Tailscale, ZeroTier, Netmaker)
- SD-WAN vs traditional VPN
- Cloud interconnect options
- DNS and service discovery across environments

## Methodology

Testing WireGuard, OpenVPN, Tailscale, and cloud-native VPN solutions for latency, throughput, ease of configuration, and operational overhead.

## Findings

**WireGuard (Raw)**:

- Excellent performance (900+ Mbps throughput, <5ms latency)
- Modern cryptography (Noise protocol)
- Manual configuration required (doesn't scale well)
- No built-in NAT traversal or peer discovery
- Best for: Small deployments (<20 nodes) where full control needed

**OpenVPN**:

- Mature and widely supported
- Hub-and-spoke architecture (single point of failure)
- Lower performance (400-600 Mbps)
- Complex certificate management
- Best for: Legacy environments requiring broad client support

**Tailscale** ⭐ (Preferred):

- Built on WireGuard (same performance, modern cryptography)
- Zero-configuration mesh networking with automatic NAT traversal
- Centralized ACL-based access control
- SSO integration (GitHub, Google, Okta)
- MagicDNS for service discovery
- Scales to 1000+ nodes with minimal operational overhead
- Best for: Modern hybrid cloud deployments requiring operational simplicity

**Cloud VPN (AWS VPN Gateway, Azure VPN Gateway)**:

- Provider-specific, creates vendor lock-in
- Complex multi-cloud connectivity
- Costly ($36/month per gateway + data transfer)
- Best for: Single-cloud deployments only

## Current Recommendation

**Tailscale** for hybrid cloud networking due to:

- **WireGuard Performance**: Same excellent performance as raw WireGuard (900+ Mbps, <5ms latency)
- **Zero Configuration**: Automatic NAT traversal, peer discovery, and mesh networking
- **Operational Simplicity**: Minimal maintenance (~1 hour/month vs. ~20 hours/month for raw WireGuard)
- **Enterprise Features**: SSO integration, centralized ACL management, audit logging
- **Scalability**: Proven to scale to 1000+ nodes with minimal overhead
- **Multi-Cloud Support**: Vendor-neutral, works across AWS, Azure, GCP, and on-premise
- **Cost-Effective**: Lower total cost of ownership when operational overhead is factored in

### Why Tailscale Over Raw WireGuard

While WireGuard provides excellent performance and security, Tailscale adds critical operational features:

- **Automatic Configuration**: No manual key exchange or peer configuration
- **NAT Traversal**: Works through complex network topologies without manual setup
- **Centralized Management**: GitOps-friendly ACL management instead of per-node firewall rules
- **Identity Integration**: SSO-based access control instead of shared secrets
- **Service Discovery**: MagicDNS eliminates manual DNS configuration

For detailed analysis, see [Research: Tailscale Evaluation](tailscale-evaluation.md).

## Implementation

See [ADR-0009: Tailscale for Hybrid Cloud Networking](../decisions/0009-tailscale-hybrid-networking.md) for the architectural decision and implementation plan.

Technical details in [Tailscale Mesh Network Specification](../../specs/network/tailscale-mesh-network.md).

## Next Steps

- [x] ~~Research SD-WAN solutions (Tailscale, Netmaker)~~ - Completed
- [x] ~~Evaluate Tailscale for hybrid cloud connectivity~~ - Completed, documented in ADR-0009
- [ ] Deploy Tailscale in development environment (Pilot)
- [ ] Configure ACL policies and test access control
- [ ] Deploy subnet routers in staging and production
- [ ] Migrate from existing VPN solutions
- [ ] Document operational runbooks

## References

- [Tailscale Evaluation Research](tailscale-evaluation.md)
- [ADR-0009: Tailscale for Hybrid Cloud Networking](../decisions/0009-tailscale-hybrid-networking.md)
- [Technical Spec: Tailscale Mesh Network](../../specs/network/tailscale-mesh-network.md)
- [WireGuard Documentation](https://www.wireguard.com/)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [Hybrid Cloud Networking Best Practices](https://cloud.google.com/architecture/hybrid-and-multi-cloud-network-topologies)
