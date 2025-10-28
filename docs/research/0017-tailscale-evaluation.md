# Research: Tailscale for Hybrid Cloud Networking

Date: 2025-10-21
Author: Infrastructure Team
Status: Accepted

## Objective

Evaluate Tailscale as a mesh VPN solution for connecting hybrid cloud infrastructure, comparing it against alternative networking solutions for security, performance, ease of use, and operational overhead.

## Executive Summary

Tailscale is a modern mesh VPN built on WireGuard that provides zero-configuration networking
with automatic NAT traversal, centralized access control, and seamless integration across cloud
providers and on-premise infrastructure. It offers significant operational advantages over
traditional VPN solutions while maintaining high security and performance standards.

**Recommendation**: Adopt Tailscale as the primary solution for hybrid cloud networking.

## What is Tailscale?

Tailscale is a mesh VPN service built on the WireGuard® protocol that creates a secure network
overlay connecting devices across different networks, cloud providers, and geographic locations.
Unlike traditional VPN solutions, Tailscale:

- **Zero-configuration**: Automatically handles NAT traversal, peer discovery, and connection
  establishment
- **Mesh architecture**: Direct peer-to-peer connections between nodes (not hub-and-spoke)
- **Identity-based access**: Integrates with SSO providers (Google, GitHub, Okta, etc.)
- **MagicDNS**: Automatic DNS resolution for all nodes on the network
- **Subnet routing**: Access entire networks through gateway nodes
- **Cross-platform**: Works on Linux, macOS, Windows, iOS, Android, and embedded systems

## Architecture

### How Tailscale Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    Tailscale Control Plane                       │
│                  (Coordination Server)                           │
│  - Node registration & authentication                           │
│  - Key exchange & coordination                                  │
│  - ACL management                                               │
│  - MagicDNS configuration                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ (Control messages only)
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼────────┐    ┌──────▼───────┐    ┌───────▼────────┐
│   AWS VPC      │    │  Azure VNet  │    │  On-Premise    │
│                │    │              │    │                │
│ ┌────────────┐ │    │ ┌──────────┐ │    │ ┌────────────┐ │
│ │ Tailscale  │◄├────┤►│Tailscale │◄├────┤►│ Tailscale  │ │
│ │ Node       │ │    │ │ Node     │ │    │ │ Node       │ │
│ └────────────┘ │    │ └──────────┘ │    │ └────────────┘ │
│                │    │              │    │                │
│ (Subnet Router)│    │(Subnet Router│    │(Subnet Router) │
│  10.0.0.0/16   │    │10.128.0.0/16 │    │192.168.0.0/16  │
└────────────────┘    └──────────────┘    └────────────────┘
         ▲                    ▲                    ▲
         │                    │                    │
         └────────────────────┴────────────────────┘
              Direct WireGuard encrypted tunnels
              (peer-to-peer, no relay unless needed)
```

### Key Components

1. **Tailscale Nodes**: Devices/VMs running the Tailscale client
2. **Control Plane**: Coordination server (managed by Tailscale or self-hosted Headscale)
3. **DERP Relays**: Encrypted relay servers for NAT traversal fallback
4. **Subnet Routers**: Nodes that advertise access to entire subnets
5. **Exit Nodes**: Nodes that route internet traffic (optional)

### Network Flow

1. **Node Registration**: Node authenticates with control plane via SSO
2. **Key Exchange**: Control plane coordinates WireGuard key exchange
3. **NAT Traversal**: Nodes attempt direct peer-to-peer connection
4. **DERP Fallback**: If direct connection fails, encrypted relay is used
5. **Data Transfer**: Encrypted WireGuard tunnels between nodes

## Comparison with Alternatives

### Tailscale vs. WireGuard (Raw)

| Aspect | Tailscale | Raw WireGuard |
|--------|-----------|---------------|
| **Setup Complexity** | Automatic, ~5 minutes | Manual, ~30-60 minutes per peer |
| **Configuration** | Zero-config, centralized ACLs | Manual config files on each peer |
| **NAT Traversal** | Automatic | Manual port forwarding required |
| **Key Management** | Automatic rotation | Manual key distribution |
| **Peer Discovery** | Automatic | Manual IP configuration |
| **DNS** | MagicDNS (automatic) | Manual DNS setup |
| **Access Control** | Centralized ACLs | Firewall rules per node |
| **Scalability** | Excellent (1000+ nodes) | Poor (manual doesn't scale) |
| **SSO Integration** | Yes (Google, GitHub, Okta, etc.) | No |
| **Management UI** | Web-based admin console | None (CLI only) |
| **Cost** | Free tier: 20 devices, paid: $6/user/month | Free and open source |
| **Performance** | Same (both use WireGuard) | Same |
| **Security** | WireGuard + identity layer | WireGuard only |

**Verdict**: Tailscale provides WireGuard performance with significantly better operational experience.

### Tailscale vs. OpenVPN

| Aspect | Tailscale | OpenVPN |
|--------|-----------|---------|
| **Architecture** | Mesh (peer-to-peer) | Hub-and-spoke (centralized) |
| **Setup Complexity** | Very simple | Complex (certificates, config files) |
| **Performance** | Excellent (~1 Gbps+) | Good (~400-600 Mbps) |
| **Latency** | Very low (direct connections) | Higher (through central server) |
| **Protocol** | WireGuard (UDP) | TCP/UDP (configurable) |
| **Cryptography** | Modern (Noise protocol) | Older (OpenSSL) |
| **Certificate Management** | Not needed (WireGuard keys) | Required (PKI infrastructure) |
| **Firewall Traversal** | Excellent (automatic) | Good (but requires config) |
| **Scalability** | Excellent | Limited by central server |
| **Maturity** | Newer (2019) | Very mature (2001) |
| **Enterprise Features** | Yes (SSO, ACLs, audit logs) | Yes (with Access Server) |
| **Cost** | Free/Paid tiers | Free (Community) or paid (Access Server) |

**Verdict**: Tailscale offers superior performance, simplicity, and modern architecture.

### Tailscale vs. ZeroTier

| Aspect | Tailscale | ZeroTier |
|--------|-----------|----------|
| **Underlying Protocol** | WireGuard | Custom protocol |
| **Performance** | Excellent | Very good |
| **Setup Complexity** | Very simple | Simple |
| **NAT Traversal** | Excellent | Excellent |
| **Network Topology** | Mesh | Mesh + SDN features |
| **DNS** | MagicDNS | Built-in DNS |
| **Access Control** | Tag-based ACLs | Network-based rules |
| **SSO Integration** | Yes | Limited |
| **Layer 2 Support** | No | Yes (Ethernet bridging) |
| **Self-hosting** | Yes (Headscale) | Yes (controller) |
| **Open Source** | Client: Yes, Server: Headscale | Yes (full stack) |
| **Enterprise Features** | Strong | Good |
| **Community** | Growing rapidly | Established |
| **Cost** | Free tier: 20 devices | Free tier: 25 devices |

**Verdict**: Both excellent, Tailscale preferred for WireGuard foundation and stronger enterprise features.

### Tailscale vs. Netmaker

| Aspect | Tailscale | Netmaker |
|--------|-----------|----------|
| **Underlying Protocol** | WireGuard | WireGuard |
| **Architecture** | Managed service + self-host option | Self-hosted |
| **Setup Complexity** | Very simple (managed) | Moderate (self-hosted) |
| **Management UI** | Excellent | Good |
| **Kubernetes Integration** | Good | Excellent (operator, ingress) |
| **Access Control** | Tag-based ACLs | Node groups, ACLs |
| **SSO Integration** | Yes | Yes |
| **DNS** | MagicDNS | CoreDNS integration |
| **Self-hosting** | Yes (Headscale) | Primary model |
| **Automation** | REST API | REST API |
| **Cost** | Free/Paid (managed) | Free (self-hosted) + Enterprise |
| **Operational Overhead** | Very low (managed) | Higher (self-hosted) |

**Verdict**: Tailscale preferred for managed service benefits and lower operational overhead.

### Tailscale vs. Cloud-Native VPN (AWS VPN, Azure VPN Gateway)

| Aspect | Tailscale | Cloud-Native VPN |
|--------|-----------|------------------|
| **Multi-cloud** | Yes (vendor-neutral) | No (vendor-specific) |
| **Setup Complexity** | Very simple | Complex (routing tables, gateways) |
| **Cross-cloud Connectivity** | Native | Requires additional setup |
| **Performance** | Excellent | Good |
| **Cost** | Predictable per-user pricing | Variable (data transfer, gateway hours) |
| **Vendor Lock-in** | None | High |
| **Hybrid Cloud** | Excellent | Good (per provider) |
| **Management** | Unified | Per-cloud console |
| **Access Control** | Centralized | Per-cloud policies |
| **Failover** | Automatic | Manual configuration |

**Verdict**: Tailscale strongly preferred for hybrid/multi-cloud environments to avoid vendor lock-in.

## Key Features and Benefits

### 1. Zero-Configuration Mesh Network

- **Automatic peer discovery**: Nodes find each other without manual configuration
- **NAT traversal**: Works through firewalls, NAT, and complex network topologies
- **Self-healing**: Automatically recovers from network changes and failures
- **Direct connections**: Peer-to-peer tunnels minimize latency

### 2. Identity-Based Security

- **SSO Integration**: Google Workspace, GitHub, Okta, Azure AD, SAML
- **No shared secrets**: Each node has unique WireGuard keys
- **Device authorization**: Granular control over which devices can join
- **User-centric model**: Access tied to identity, not IP addresses

### 3. Centralized Access Control (ACLs)

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["group:developers"],
      "dst": ["tag:development:*"]
    },
    {
      "action": "accept",
      "src": ["group:sre"],
      "dst": ["tag:production:*"]
    }
  ]
}
```

- **Tag-based policies**: Organize nodes by tags (environment, role, region)
- **GitOps-friendly**: ACLs stored as JSON, version-controlled
- **Granular rules**: Control access by user, group, tag, and port
- **Audit logging**: Track all access and policy changes

### 4. MagicDNS

- **Automatic DNS**: Each node gets a DNS name (e.g., `server1.tail-abc123.ts.net`)
- **Split DNS**: Override DNS for specific domains
- **HTTPS certificates**: Let's Encrypt integration for HTTPS
- **Service discovery**: Access services by name, not IP

### 5. Subnet Routing

- **Gateway nodes**: Advertise access to entire subnets
- **Selective routing**: Only Tailscale traffic goes through VPN
- **Multiple subnets**: Single node can route multiple networks
- **Fallback**: Automatic failover between subnet routers

### 6. Exit Nodes

- **Internet routing**: Route all internet traffic through specific nodes
- **Geographic selection**: Choose exit node by location
- **Use cases**: Remote access, privacy, accessing geo-restricted content
- **Optional**: Not required for subnet routing

### 7. Cross-Platform Support

- **Operating Systems**: Linux, macOS, Windows, FreeBSD, OpenBSD
- **Mobile**: iOS, Android
- **Containers**: Docker, Kubernetes
- **Embedded**: Synology, QNAP, Ubiquiti
- **Cloud**: Easy deployment on AWS, Azure, GCP, DigitalOcean

## Use Cases for Hybrid Cloud Infrastructure

### 1. Multi-Cloud Connectivity

**Scenario**: Connect AWS VPC, Azure VNet, and GCP VPC without complex VPN gateways.

**Solution**:

- Deploy Tailscale subnet routers in each cloud
- Each router advertises its cloud network
- All clouds can communicate directly

**Benefits**:

- No VPN gateway costs ($0.05/hour = $36/month savings per gateway)
- No data transfer charges through gateways
- Unified access control across clouds
- Simple configuration

### 2. On-Premise to Cloud

**Scenario**: Connect on-premise data center to cloud resources securely.

**Solution**:

- Deploy Tailscale on on-premise gateway
- Advertise on-premise subnet (192.168.0.0/16)
- Cloud resources access on-premise services directly

**Benefits**:

- No site-to-site VPN configuration
- No IPsec complexity
- Modern WireGuard encryption
- Easy disaster recovery

### 3. Developer Access

**Scenario**: Developers need secure access to development, staging, and production environments.

**Solution**:

- Developers authenticate via SSO (GitHub/Google)
- ACLs control access based on environment tags
- MagicDNS provides easy service discovery

**Benefits**:

- No VPN client complexity
- SSO reduces password fatigue
- Granular access control
- Audit trail for compliance

### 4. Kubernetes Networking

**Scenario**: Connect Kubernetes clusters across clouds and on-premise.

**Solution**:

- Deploy Tailscale as DaemonSet or sidecar
- Enable subnet routing for pod networks
- Access pods and services across clusters

**Benefits**:

- Multi-cluster service mesh alternative
- No complex network overlays
- Works with any CNI plugin
- Simple disaster recovery failover

### 5. Database Access

**Scenario**: Secure access to databases without exposing to internet.

**Solution**:

- Databases in private subnets
- Tailscale subnet router advertises database subnet
- Developers/apps access via MagicDNS

**Benefits**:

- No bastion hosts needed
- No security group complexity
- Encrypted connections
- Access control via ACLs

## Performance Characteristics

### Throughput

- **Direct connections**: 900+ Mbps (limited by WireGuard, not Tailscale)
- **DERP relay**: 200-400 Mbps (fallback only when direct connection fails)
- **Multi-gigabit**: Possible with newer WireGuard implementations

### Latency

- **Direct connections**: ~1-5ms overhead (negligible)
- **DERP relay**: ~50-100ms additional latency (geographic dependent)
- **NAT traversal success**: >95% achieve direct connections

### Scalability

- **Network size**: Supports 1000+ nodes per network
- **Subnet routers**: Multiple routers per subnet for high availability
- **ACL complexity**: Thousands of rules without performance impact
- **Connection establishment**: Typically <5 seconds

### Resource Usage

- **CPU**: Minimal (<1% idle, 5-10% under load)
- **Memory**: ~50MB per node
- **Bandwidth**: Only active traffic (no keepalive overhead)
- **Battery**: Optimized for mobile devices

## Security Considerations

### Strengths

1. **WireGuard Foundation**: Proven, audited, modern cryptography
2. **Identity-Based**: Access tied to verified identities, not shared secrets
3. **Key Rotation**: Automatic key rotation and management
4. **Least Privilege**: Granular ACLs enforce principle of least privilege
5. **Audit Logging**: Complete audit trail of connections and changes
6. **End-to-End Encryption**: Data encrypted in transit between all nodes
7. **No Trust in Relay**: DERP relays cannot decrypt traffic
8. **Open Source Client**: Client code is fully auditable

### Considerations

1. **Control Plane Trust**: Must trust Tailscale coordination server (or self-host Headscale)
2. **Metadata Visibility**: Coordination server sees node list and connection metadata (not data)
3. **Internet Dependency**: Requires internet connectivity for coordination (not for established tunnels)
4. **SSO Dependency**: Authentication relies on SSO provider availability

### Threat Model

**What Tailscale Protects Against**:

- Man-in-the-middle attacks
- Network eavesdropping
- Unauthorized access to private networks
- IP address scanning/discovery
- Replay attacks

**What Tailscale Does NOT Protect Against**:

- Compromised endpoints (malware on nodes)
- Compromised SSO accounts
- Application-level vulnerabilities
- Data exfiltration by authorized users

### Compliance

- **SOC 2 Type II**: Tailscale is SOC 2 compliant
- **GDPR**: Compliant with data protection requirements
- **HIPAA**: Can be used in HIPAA-compliant architectures
- **Data Residency**: Self-hosted Headscale for data sovereignty

## Cost Analysis

### Tailscale Pricing (as of 2024)

| Tier | Cost | Features |
|------|------|----------|
| **Personal (Free)** | $0 | 20 devices, 1 user, community support |
| **Personal Pro** | $48/year | 100 devices, 1 user, email support |
| **Team** | $6/user/month | Unlimited devices, SSO, priority support |
| **Enterprise** | Custom | SCIM, custom SLA, dedicated support |

### Cost Comparison (100-node deployment)

**Scenario**: 100 nodes across AWS, Azure, and on-premise

| Solution | Monthly Cost | Annual Cost | Notes |
|----------|--------------|-------------|-------|
| **Tailscale** | $600 | $7,200 | 100 users @ $6/month |
| **AWS VPN Gateway** | $216 + data | $2,592+ | 3 gateways @ $0.05/hour + data transfer |
| **OpenVPN Access Server** | $1,500 | $18,000 | 100 connections @ $15/connection |
| **Raw WireGuard** | $0 | $0 | Free but high operational cost |
| **Netmaker (self-hosted)** | $200 | $2,400 | Infrastructure + management overhead |

**Additional Considerations**:

- **Operational overhead**: Tailscale: ~1 hour/month, WireGuard: ~20 hours/month
- **Engineer time cost**: At $100/hour, WireGuard costs $24,000/year in management
- **Total Cost of Ownership**: Tailscale often cheaper when factoring in operational costs

### Self-Hosting with Headscale

- **Headscale**: Open-source Tailscale control plane implementation
- **Cost**: Infrastructure only (~$10-50/month for server)
- **Trade-off**: No managed service features, higher operational burden
- **Best for**: Data sovereignty requirements, cost-sensitive deployments

## Implementation Complexity

### Setup Time

- **Tailscale managed**: 30 minutes for full deployment
- **Headscale self-hosted**: 4-8 hours for initial setup
- **Raw WireGuard**: 40+ hours for 100-node network
- **OpenVPN**: 20+ hours with certificate infrastructure

### Learning Curve

- **Tailscale**: Very low, intuitive UI and concepts
- **WireGuard**: Moderate, need to understand cryptography and routing
- **OpenVPN**: High, complex PKI and networking knowledge required

### Ongoing Maintenance

- **Tailscale**: Minimal (~1 hour/month for ACL updates)
- **Headscale**: Low (~4 hours/month for updates and monitoring)
- **WireGuard**: High (~20 hours/month for key rotation, troubleshooting)
- **OpenVPN**: High (~15 hours/month for certificate management)

### Integration Effort

| Integration | Tailscale | Alternatives |
|-------------|-----------|--------------|
| **Terraform** | Native provider available | Limited or none |
| **Kubernetes** | Operator, Helm chart | Manual or limited |
| **CI/CD** | API-friendly | Complex |
| **Monitoring** | Prometheus metrics | Manual instrumentation |
| **SSO** | Native integration | Complex LDAP/RADIUS |

## Limitations and Trade-offs

### Limitations

1. **No Layer 2**: Cannot bridge Ethernet networks (ZeroTier can)
2. **Control Plane Dependency**: Needs coordination server for initial setup
3. **Limited Protocol Support**: UDP-based (some corporate firewalls may block)
4. **Headscale Maturity**: Self-hosted option less mature than commercial product
5. **ACL Complexity**: Very large ACL files can be difficult to manage

### Trade-offs

1. **Managed vs. Control**: Convenience of managed service vs. full infrastructure control
2. **Cost vs. Features**: Free tier limited, enterprise features require paid plan
3. **Simplicity vs. Flexibility**: Less configurability than raw WireGuard
4. **Cloud vs. On-Premise**: Optimal for cloud, may be overkill for simple site-to-site

### Not Recommended For

- **Layer 2 Bridging**: Use ZeroTier instead
- **Air-Gapped Networks**: No internet = no coordination
- **Extreme Cost Sensitivity**: Raw WireGuard cheaper (if operational cost ignored)
- **UDP Blocked Networks**: May need DERP relay or alternative solution

## Migration Path

### From Existing WireGuard

1. Keep existing WireGuard during transition
2. Deploy Tailscale subnet routers in parallel
3. Migrate clients incrementally
4. Update ACLs and firewall rules
5. Decommission WireGuard once validated

**Timeline**: 2-4 weeks for 100-node deployment

### From OpenVPN

1. Document existing access patterns and users
2. Configure Tailscale ACLs matching current access
3. Deploy Tailscale subnet routers
4. Migrate users in phases (dev → staging → production)
5. Parallel run for 1 month before decommissioning OpenVPN

**Timeline**: 4-6 weeks for 100-user deployment

### From Cloud VPN Gateways

1. Deploy Tailscale in each cloud VPC
2. Configure subnet routing for each network
3. Test connectivity between clouds
4. Update application configurations
5. Decommission VPN gateways

**Timeline**: 2-3 weeks for multi-cloud setup

## Testing and Validation

### Performance Testing

```bash
# Throughput test between Tailscale nodes
iperf3 -c <remote-tailscale-ip>

# Latency test
ping <remote-tailscale-hostname>

# DNS resolution test
nslookup <service-name>.tail-abc123.ts.net
```

### Security Testing

- **ACL validation**: Test that unauthorized access is blocked
- **Encryption verification**: Capture packets and verify encryption
- **SSO integration**: Test login, logout, and session expiration
- **Audit log review**: Verify all access is logged

### Reliability Testing

- **Failover testing**: Simulate subnet router failure
- **Network partition**: Test behavior during internet connectivity loss
- **Scaling test**: Add/remove 100+ nodes rapidly
- **Geographic latency**: Test connections across regions

## Monitoring and Observability

### Metrics to Monitor

- **Connection status**: Are all nodes connected?
- **Connection type**: Direct vs. DERP relay percentage
- **Latency**: Round-trip time between nodes
- **Throughput**: Bandwidth utilization
- **ACL denials**: Unauthorized access attempts
- **Node inventory**: Active vs. expected nodes

### Integration Points

- **Prometheus**: Export metrics via Tailscale exporter
- **Grafana**: Dashboards for network health
- **PagerDuty/Opsgenie**: Alerts for connectivity issues
- **Logging**: Ship Tailscale logs to centralized logging system

## Conclusion

Tailscale provides a compelling solution for hybrid cloud networking that combines the performance and security of WireGuard with the operational simplicity of a managed service.

### When to Choose Tailscale

✅ **Highly Recommended For**:

- Hybrid cloud and multi-cloud deployments
- Organizations prioritizing operational simplicity
- Teams wanting modern zero-trust networking
- Remote/distributed infrastructure
- Developer productivity and secure access

✅ **Recommended For**:

- Cost-conscious deployments (vs. managed VPN services)
- Kubernetes multi-cluster networking
- Startups to enterprises (scales with organization)

### When to Consider Alternatives

⚠️ **Consider Alternatives If**:

- Strict air-gapped network requirements (no internet)
- Layer 2 Ethernet bridging required (use ZeroTier)
- Extreme cost sensitivity with high operational capacity (raw WireGuard)
- Complete infrastructure control required (Headscale or WireGuard)

### Final Recommendation

**For this infrastructure project, Tailscale is the recommended solution** because:

1. **Multi-cloud support**: Seamlessly connects AWS, Azure, GCP, and on-premise
2. **Operational efficiency**: Minimal ongoing maintenance compared to alternatives
3. **Security**: Modern cryptography with identity-based access control
4. **Developer experience**: Simple setup and usage improves productivity
5. **Cost-effective**: Lower total cost of ownership than managed alternatives
6. **Future-proof**: Active development, strong community, modern architecture

The combination of WireGuard's performance with Tailscale's operational simplicity makes it the optimal choice for hybrid cloud networking at scale.

## Next Steps

1. **Pilot Deployment**: Deploy Tailscale in development environment
2. **ACL Design**: Define access control policies based on roles and environments
3. **Subnet Router Setup**: Configure subnet routers in each cloud and on-premise
4. **SSO Integration**: Connect with existing identity provider (GitHub/Google/Okta)
5. **Monitoring Setup**: Configure metrics collection and alerting
6. **Documentation**: Create runbooks for common operations
7. **Migration Planning**: Plan migration from existing VPN solutions
8. **Security Audit**: Review ACLs and security configurations
9. **Production Rollout**: Gradual rollout to staging then production

## References

- [Tailscale Documentation](https://tailscale.com/kb/)
- [WireGuard Protocol](https://www.wireguard.com/protocol/)
- [Headscale (Open Source Implementation)](https://github.com/juanfont/headscale)
- [Tailscale Architecture](https://tailscale.com/blog/how-tailscale-works/)
- [Tailscale vs. Alternatives Comparison](https://tailscale.com/compare/)
- [Zero Trust Networking Principles](https://www.cloudflare.com/learning/security/glossary/what-is-zero-trust/)
- [Hybrid Cloud Networking Best Practices](https://cloud.google.com/architecture/hybrid-and-multi-cloud-network-topologies)
- [WireGuard Performance Analysis](https://www.wireguard.com/performance/)

## Related Documentation

- [ADR-0009: Tailscale for Hybrid Cloud Networking](../decisions/0009-tailscale-hybrid-networking.md)
- [Technical Spec: Tailscale Mesh Network](../../specs/network/tailscale-mesh-network.md)
- [Research: Hybrid Cloud Networking](0007-hybrid-cloud-networking.md)
- [Runbook: Cloudflare Operations](../runbooks/0001-cloudflare-operations.md)
