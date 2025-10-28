# Network Specifications

This directory contains network architecture and configuration specifications.

## Overview

Network specifications define the network topology, connectivity, security, and performance characteristics of the infrastructure.

## Specifications

### Core Networking

- [VPC Architecture](vpc-architecture.md) - Virtual network design across cloud providers
- [Subnetting and IPAM](subnetting-ipam.md) - IP address allocation and management
- [Routing](routing.md) - Route tables and internet gateway configurations
- [DNS and Service Discovery](dns-service-discovery.md) - Name resolution strategy

### Connectivity

- [Tailscale Mesh Network](tailscale-mesh-network.md) - ⭐ Primary solution for hybrid cloud connectivity
- [Hybrid Cloud Connectivity](hybrid-connectivity.md) - Cross-cloud and on-premise connections
- [VPN Specifications](vpn-specs.md) - Site-to-site and client VPN configurations
- [Direct Connect / ExpressRoute](direct-connect.md) - Dedicated network connections
- [Peering](peering.md) - VPC/VNet peering and transit gateway

### Load Balancing and Traffic Management

- [Load Balancer Configuration](load-balancers.md) - Application and network load balancers
- [Ingress Controllers](ingress-controllers.md) - Kubernetes ingress specifications
- [Traffic Management](traffic-management.md) - Traffic splitting and routing policies
- [CDN Configuration](cdn.md) - Content delivery network setup

### Network Security

- [Security Groups](security-groups.md) - Instance-level firewall rules
- [Network ACLs](network-acls.md) - Subnet-level firewall rules
- [Network Policies](network-policies.md) - Kubernetes network policies
- [WAF Configuration](waf.md) - Web application firewall rules
- [DDoS Protection](ddos-protection.md) - DDoS mitigation strategies

### Performance and Monitoring

- [Bandwidth Requirements](bandwidth-requirements.md) - Network capacity planning
- [Latency Requirements](latency-requirements.md) - Performance targets
- [Network Monitoring](network-monitoring.md) - Monitoring and alerting setup

## Key Concepts

### Network Segmentation

Infrastructure is segmented into multiple tiers:

- **Public Subnets**: Internet-facing resources (load balancers, NAT gateways)
- **Private Subnets**: Application workloads (Kubernetes nodes, application servers)
- **Data Subnets**: Databases and stateful services
- **Management Subnets**: Bastion hosts, monitoring, logging

### IP Address Allocation

#### Cloud Provider IP Ranges

- **AWS VPCs**: 10.0.0.0/8 range
- **Azure VNets**: 10.128.0.0/9 range
- **GCP VPCs**: 10.64.0.0/10 range
- **On-Premise**: 192.168.0.0/16 range

#### Subnet Sizing

- **/24 subnets**: Standard application subnets (254 hosts)
- **/26 subnets**: Small service subnets (62 hosts)
- **/28 subnets**: Management subnets (14 hosts)

### High Availability

Network architecture ensures high availability through:

- **Multi-AZ Deployment**: Resources spread across availability zones
- **Redundant Paths**: Multiple network paths for critical connections
- **Load Balancer Health Checks**: Automatic failure detection and routing
- **Failover Mechanisms**: Automatic failover for critical services

### Security Zones

Network security is enforced through security zones:

- **Internet Zone**: Public internet access
- **DMZ Zone**: Edge services with limited internal access
- **Application Zone**: Internal application workloads
- **Data Zone**: Databases with restricted access
- **Management Zone**: Administrative access with strict controls

## Architecture Diagrams

### Multi-Cloud Network Topology

```
┌────────────────────────────────────────────────────────────────┐
│                         Internet                                │
└────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
    ┌─────▼─────┐      ┌─────▼─────┐      ┌─────▼─────┐
    │    AWS    │      │   Azure   │      │    GCP    │
    │  Region   │      │  Region   │      │  Region   │
    └─────┬─────┘      └─────┬─────┘      └─────┬─────┘
          │                   │                   │
    ┌─────▼─────┐      ┌─────▼─────┐      ┌─────▼─────┐
    │    VPC    │──────│   VNet    │──────│    VPC    │
    │ 10.0.0.0/8│      │10.128.0.0/9│     │ 10.64.0.0/10│
    └───────────┘      └───────────┘      └───────────┘
          │                   │                   │
          └───────────────────┼───────────────────┘
                              │
                      ┌───────▼────────┐
                      │  On-Premise DC │
                      │ 192.168.0.0/16 │
                      └────────────────┘
```

### VPC Subnet Architecture

```
┌──────────────────────────────────────────────────────────┐
│                      VPC (10.0.0.0/16)                   │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Public Subnets (10.0.0.0/20)                     │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │ │
│  │  │   ALB/NLB   │  │ NAT Gateway │  │  Bastion   │ │ │
│  │  └─────────────┘  └─────────────┘  └────────────┘ │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Private Subnets (10.0.16.0/20)                   │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │ │
│  │  │ K8s Nodes   │  │  App Tier   │  │  Services  │ │ │
│  │  └─────────────┘  └─────────────┘  └────────────┘ │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Data Subnets (10.0.32.0/20)                      │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │ │
│  │  │  Databases  │  │   Cache     │  │  Storage   │ │ │
│  │  └─────────────┘  └─────────────┘  └────────────┘ │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

## Configuration Standards

### Security Group Naming

Format: `{environment}-{tier}-{service}-{direction}-sg`

Examples:

- `prod-app-web-ingress-sg`
- `staging-data-postgres-egress-sg`

### Subnet Naming

Format: `{environment}-{tier}-{az}-subnet`

Examples:

- `prod-public-us-east-1a-subnet`
- `dev-private-us-west-2b-subnet`

### Route Table Naming

Format: `{environment}-{type}-{purpose}-rt`

Examples:

- `prod-public-internet-rt`
- `staging-private-nat-rt`

## Compliance Requirements

### Data Sovereignty

- Data must remain within specific geographic regions
- Cross-region replication requires encryption
- Compliance with GDPR, CCPA regulations

### Network Isolation

- Production networks isolated from non-production
- PCI workloads in separate network segments
- Healthcare data in HIPAA-compliant segments

### Encryption Requirements

- TLS 1.2 minimum for all traffic
- IPsec for VPN connections
- Encryption in transit for cross-region traffic

## Change Management

### Network Change Process

1. Document proposed change in specification
2. Create ADR if architecture decision required
3. Review with infrastructure team
4. Test in development environment
5. Apply to staging with validation
6. Schedule production change window
7. Apply to production with rollback plan
8. Validate and monitor

### Emergency Changes

- Follow expedited approval process
- Document in incident report
- Update specifications retroactively
- Post-mortem and lessons learned

## Related Documentation

- [Security Specifications](../security/) - Security controls and requirements
- [Compute Specifications](../compute/) - Kubernetes and compute resources
- [ADR-0009: Tailscale for Hybrid Cloud Networking](../../docs/decisions/0009-tailscale-hybrid-networking.md)
- [Research: Tailscale Evaluation](../../docs/research/0017-tailscale-evaluation.md)
- [Research: Hybrid Cloud Networking](../../docs/research/0007-hybrid-cloud-networking.md)
