# 19. Docker-Compose for Storage/GPU Workloads

Date: 2025-11-25

## Status

Accepted

**Complements**:

- [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](0016-talos-unraid-primary.md)
- [ADR-0005: Kubernetes as Container Platform](0005-kubernetes-container-platform.md)

## Context

While Kubernetes (via Talos Linux) serves as the primary container platform (ADR-0016), certain applications benefit significantly from running directly on dedicated hosts via docker-compose:

### Storage-Intensive Applications

Applications that manage large media libraries or repositories benefit from:

- Direct access to `/mnt/user/` array without network overhead
- Native support for Unraid's cache pools and mover
- No PV/PVC abstraction layer for multi-terabyte datasets
- Better I/O performance for sequential reads/writes

### GPU-Intensive Applications

Applications requiring GPU acceleration benefit from:

- Direct NVIDIA GPU passthrough without Kubernetes device plugins
- Simpler NVIDIA container toolkit integration
- Hardware transcoding without complex pod scheduling
- Lower latency for GPU operations

### Workload Distribution Analysis

| Application | Category | Primary Resource Need | Recommended Platform |
|-------------|----------|----------------------|---------------------|
| **Gitea** | Git hosting | Storage (large repos) | Unraid docker-compose |
| **Immich** | Photo management | Storage + GPU (ML inference) | Unraid docker-compose |
| **Plex** | Media server | Storage + GPU (transcoding) | Unraid docker-compose |
| **VS Code Server** | Development | Compute (stateless) | Kubernetes |
| **Vaultwarden** | Password manager | HA + Security | Kubernetes |
| **n8n** | Workflow automation | Compute (stateless, scalable) | Kubernetes |

### Why Not Everything in Kubernetes?

For storage/GPU workloads, Kubernetes adds unnecessary complexity:

1. **Storage overhead**: PV/PVC claims add abstraction for direct array access
2. **GPU scheduling**: Device plugins require additional configuration
3. **Network overhead**: Pod networking for local storage access
4. **Complexity**: Operators, CSI drivers, and device plugins for simple use cases

## Decision

We will use a **hybrid approach**:

1. **Unraid docker-compose** for storage-heavy and GPU-intensive applications (Gitea, Immich, Plex)
2. **Kubernetes** for stateless, cloud-native, and HA-requiring applications (VS Code Server, Vaultwarden, n8n)

### Docker-Compose Structure

Following the Kubernetes folder pattern with base configurations and environment overlays:

```
docker/
├── base/                           # Base docker-compose configurations
│   ├── gitea/
│   │   ├── docker-compose.yml      # Service definition
│   │   └── README.md               # Service documentation
│   ├── immich/
│   │   ├── docker-compose.yml
│   │   └── README.md
│   └── plex/
│       ├── docker-compose.yml
│       └── README.md
│
├── overlays/                       # Environment-specific configurations
│   ├── gitea/
│   │   └── shangkuei-xyz-unraid/   # Unraid host overlay
│   │       ├── .sops.yaml          # SOPS configuration
│   │       ├── docker-compose.override.yml
│   │       ├── .env.example
│   │       ├── .env.sops           # SOPS-encrypted environment
│   │       └── Makefile            # Secret management automation
│   ├── immich/
│   │   └── shangkuei-xyz-unraid/
│   │       └── ...
│   └── plex/
│       └── shangkuei-xyz-unraid/
│           └── ...
│
└── README.md                       # Docker-compose documentation
```

### Secrets Management

Using SOPS with Age encryption, consistent with Kubernetes secrets:

- Same Age key infrastructure as Flux CD secrets
- SOPS-encrypted `.env.sops` files for sensitive configuration
- Makefile automation for encrypt/decrypt operations
- `.env.example` templates for documentation

### Deployment Strategy

**GitHub Actions with Tailscale SSH**:

1. Triggered on changes to `docker/**` paths
2. Uses Tailscale GitHub Action for secure connectivity
3. Decrypts secrets via SOPS
4. Deploys using docker-compose-gitops-action
5. Supports manual workflow_dispatch for on-demand deployments

### Storage Paths

Applications use Unraid's native storage structure:

```yaml
volumes:
  # Configuration (SSD/Cache)
  - /mnt/user/appdata/${SERVICE}:/config

  # Data (Array or Cache)
  - /mnt/user/data/${SERVICE}:/data

  # Media (Array - large datasets)
  - /mnt/user/media:/media:ro
```

## Consequences

### Positive

- **Optimal resource utilization**: Each workload runs on the best platform for its needs
- **Simplified storage access**: Direct array access without Kubernetes abstraction
- **GPU efficiency**: Native container toolkit integration without device plugins
- **Consistent GitOps**: Same SOPS/Age secrets management across both platforms
- **Familiar patterns**: Docker-compose structure mirrors Kubernetes organization
- **Lower complexity**: No Kubernetes operators for simple docker workloads

### Negative

- **Two orchestration systems**: Must maintain both Kubernetes and docker-compose
- **No native HA**: Docker-compose workloads are single-host only
- **Manual scaling**: No HPA or automatic scaling for docker-compose services
- **Split monitoring**: May need separate monitoring for docker vs Kubernetes

### Trade-offs

- **Simplicity vs. Uniformity**: Sacrificing single-platform simplicity for optimal workload placement
- **HA vs. Performance**: Storage/GPU workloads prioritize performance over high availability
- **GitOps coverage**: Both platforms use Git-based deployment, maintaining operational consistency

## Alternatives Considered

### All Kubernetes

**Why not chosen**:

- Unnecessary complexity for storage-heavy workloads
- GPU device plugins add configuration overhead
- PV/PVC abstraction not needed for local array access
- Overkill for non-HA personal media applications

**When to reconsider**: If workloads need multi-node scaling or high availability

### All Docker-Compose

**Why not chosen**:

- Loses Kubernetes benefits for cloud-native applications
- No automatic scaling or self-healing
- Harder to integrate with cloud resources
- Misses GitOps tooling (Flux, ArgoCD)

**When to reconsider**: If Kubernetes overhead outweighs benefits for remaining workloads

### Docker Swarm

**Why not chosen**:

- Limited adoption and ecosystem
- Fewer features than Kubernetes
- Still requires network abstraction for storage
- No significant advantage over docker-compose for single-host

### Podman Compose

**Why not chosen**:

- Less mature than docker-compose
- Unraid natively supports Docker
- Limited plugin ecosystem
- No significant advantage for this use case

## Implementation Plan

### Phase 1: Repository Structure (Week 1)

1. Create `docker/` directory structure
2. Set up base configurations for Gitea, Immich, Plex
3. Configure SOPS/Age encryption for overlays
4. Document deployment procedures

### Phase 2: CI/CD Integration (Week 1-2)

1. Create GitHub Actions workflow for docker-compose deployment
2. Configure Tailscale SSH access
3. Test automated deployments
4. Add manual dispatch triggers

### Phase 3: Migration (Week 2-3)

1. Convert existing Unraid Docker templates to docker-compose
2. Test each service migration
3. Validate storage and GPU access
4. Update monitoring and alerting

### Phase 4: Documentation (Week 3)

1. Create runbooks for common operations
2. Document troubleshooting procedures
3. Update architecture diagrams
4. Cross-reference with Kubernetes documentation

## Success Metrics

- **Deployment automation**: All docker-compose changes deployed via GitOps
- **Secret security**: Zero plaintext secrets in repository
- **Service uptime**: >99% availability for docker-compose services
- **Storage performance**: No degradation vs. Unraid Docker templates
- **GPU utilization**: Hardware transcoding/ML inference working correctly

## References

- [Research: Docker-Compose Git Version Control](../research/0020-docker-compose-git-management.md)
- [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](0016-talos-unraid-primary.md)
- [ADR-0008: Secret Management Strategy](0008-secret-management.md)
- [Docker Compose GitOps Action](https://github.com/FarisZR/docker-compose-gitops-action)
- [Managing Docker on Unraid](https://mikesolin.com/2024/12/18/managing-docker-on-unraid/)
