# 20. Infrastructure Dependency Hierarchy

Date: 2025-11-28

## Status

Accepted

**Related**:

- [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](0016-talos-unraid-primary.md)
- [ADR-0019: Docker-Compose for Storage/GPU Workloads](0019-docker-compose-workloads.md)

## Context

The current infrastructure already follows a dependency hierarchy that prevents circular dependencies.
This ADR formalizes and documents this existing pattern to ensure it remains consistent as the infrastructure evolves.

In a self-hosted infrastructure with multiple interconnected services, circular dependencies create significant operational risks:

### The Circular Dependency Problem

Without clear dependency rules, infrastructure components can become interdependent in problematic ways:

```text
❌ Circular Dependency Example:
Unraid → depends on → Talos DNS → depends on → Unraid storage
```

**Consequences of circular dependencies**:

- **Bootstrap failures**: Cannot start system after complete outage
- **Cascading failures**: One component failure brings down everything
- **Complex recovery**: Unclear order for service restoration
- **Maintenance windows**: Cannot safely update any component
- **Debugging complexity**: Hard to isolate root causes

### Current Infrastructure Layers

| Layer | Component | Role |
|-------|-----------|------|
| Primary | Unraid Server | Host OS, VMs, storage, docker-compose workloads |
| Secondary | Talos Cluster | Kubernetes workloads, cloud-native services |
| External | Cloudflare, Tailscale | Edge services, networking (SaaS) |

### Dependency Direction Principle

Dependencies should flow in one direction only:

```text
✅ Correct Flow:
External Services (no internal dependencies)
         ↑
    Talos Cluster (can depend on Unraid, external)
         ↑
    Unraid Server (depends only on external services)
```

## Decision

We formalize the **existing dependency hierarchy** that is already in place:

### Current State Compliance

The current infrastructure correctly implements this hierarchy:

- **Unraid**: Operates independently, depends only on external SaaS (Cloudflare, Tailscale)
- **Docker-compose services**: Depend on Unraid storage only, no Talos dependencies
- **Talos cluster**: Depends on Unraid as VM host, uses Unraid NFS for some storage

This decision documents these existing patterns to prevent future drift.

### Tier 1: Unraid (Golden Server)

**Unraid is the foundation and MUST NOT depend on any self-managed services.**

**Allowed dependencies**:

- External SaaS services (Cloudflare DNS, Tailscale coordination)
- Hardware (power, network, physical infrastructure)

**Prohibited dependencies**:

- Talos cluster services (DNS, auth, storage, etc.)
- Docker-compose services running on Unraid
- Any service that could create circular dependencies

**Rationale**: Unraid must boot and operate independently. After a complete infrastructure failure, Unraid recovery should require only:

1. Power
2. Internet connectivity (for external SaaS)
3. Local configuration (stored on Unraid itself)

### Tier 2: Talos Cluster (Secondary)

**Talos cluster MAY depend on Unraid, but dependencies should be minimal.**

**Allowed dependencies**:

- Unraid NFS/SMB storage for persistent volumes
- Unraid as VM host platform
- External SaaS services

**Minimization guidelines**:

- Prefer local storage (OpenEBS, local-path-provisioner) over Unraid NFS
- Use external services (Cloudflare DNS) instead of cluster-internal DNS for external resolution
- Keep cluster bootable with degraded functionality if Unraid storage is unavailable
- Store critical cluster configuration in Git, not on Unraid storage

### Tier 3: Docker-Compose Workloads

**Docker-compose services on Unraid follow the same rules as Unraid itself.**

**Allowed dependencies**:

- Unraid storage and resources
- External SaaS services

**Prohibited dependencies**:

- Talos cluster services

### Dependency Matrix

| Component | Can Depend On | Cannot Depend On |
|-----------|--------------|------------------|
| Unraid | External SaaS | Talos, Docker-compose services |
| Talos Cluster | Unraid (minimal), External SaaS | - |
| Docker-Compose | Unraid, External SaaS | Talos |

### Bootstrap Order

After complete infrastructure failure:

```text
1. Hardware/Network      → Power on, network connectivity
2. External Services     → Cloudflare, Tailscale (already running)
3. Unraid                → Boot, array starts, VMs available
4. Docker-Compose        → Services start with Unraid
5. Talos VMs             → Boot, form cluster
6. Kubernetes Services   → Deploy workloads
```

## Consequences

### Positive

- **Reliable recovery**: Clear bootstrap sequence after failures
- **Independent layers**: Each tier can operate if higher tiers fail
- **Simpler debugging**: Dependency direction clarifies failure analysis
- **Safe maintenance**: Can update Talos without affecting Unraid operations
- **No deadlocks**: Circular dependency elimination prevents bootstrap deadlocks

### Negative

- **Feature limitations**: Some convenient integrations cannot be implemented
  - No cluster-internal DNS for Unraid
  - No cluster-managed authentication for Unraid services
- **Duplication**: May need external services for both tiers (e.g., DNS from Cloudflare rather than cluster CoreDNS)
- **Design constraints**: Must evaluate each new feature against dependency rules

### Trade-offs

- **Convenience vs. reliability**: Sacrificing some integration convenience for operational reliability
- **Self-hosting vs. external**: Using external SaaS for foundational services rather than self-hosting everything

## Implementation Guidelines

### When Adding New Services

1. **Identify the tier**: Which layer will host this service?
2. **Map dependencies**: What does this service need to function?
3. **Check direction**: Do dependencies flow downward (allowed) or upward (prohibited)?
4. **Validate bootstrap**: Can the service start in correct order after cold boot?

### Examples

**✅ Allowed**:

- Talos pods using Unraid NFS for media storage
- Docker-compose Gitea using Unraid array storage
- Talos ingress using Cloudflare DNS for external resolution

**❌ Prohibited**:

- Unraid using Talos-hosted DNS server
- Docker-compose services using Talos-hosted authentication
- Unraid depending on Talos-hosted backup service

### Exception Process

If a prohibited dependency is truly necessary:

1. Document the specific need in an ADR
2. Implement redundancy/fallback for the dependency
3. Document manual recovery procedures
4. Accept increased operational complexity

## Alternatives Considered

### Flat Architecture (No Hierarchy)

**Why not chosen**:

- Risk of circular dependencies
- Unclear recovery order
- Complex failure modes

### Full External Dependencies

**Why not chosen**:

- Higher costs for external services
- Internet dependency for all operations
- Reduced self-hosting benefits

### Kubernetes-First (Talos as Primary)

**Why not chosen**:

- Kubernetes adds complexity for simple workloads
- Storage-heavy apps better served by direct Unraid access
- VM management still requires Unraid as host

## References

- [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](0016-talos-unraid-primary.md)
- [ADR-0019: Docker-Compose for Storage/GPU Workloads](0019-docker-compose-workloads.md)
- [Dependency Inversion Principle](https://en.wikipedia.org/wiki/Dependency_inversion_principle)
