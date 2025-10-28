# Infrastructure Overview

High-level architecture diagram showing the hybrid cloud infrastructure setup.

## Architecture Diagram

```mermaid
graph TB
    subgraph "External"
        Users[Users]
        Developers[Developers]
    end

    subgraph "DNS & CDN"
        Cloudflare[Cloudflare DNS]
    end

    subgraph "DigitalOcean Cloud"
        DOKS[DOKS Cluster<br/>Kubernetes 1.28+]
        DOSpaces[DO Spaces<br/>Object Storage]
        DODB[(DO Database<br/>PostgreSQL)]
        DORegistry[DO Registry<br/>Container Images]
    end

    subgraph "On-Premise"
        Talos[Talos Cluster<br/>Kubernetes 1.28+]
        Storage[Local Storage<br/>Persistent Volumes]
    end

    subgraph "CI/CD"
        GitHub[GitHub Actions]
        ArgoCD[ArgoCD<br/>GitOps]
    end

    subgraph "Monitoring"
        Prometheus[Prometheus]
        Grafana[Grafana]
        Loki[Loki Logs]
    end

    Users -->|HTTPS| Cloudflare
    Cloudflare -->|Load Balance| DOKS
    Cloudflare -->|Failover| Talos

    Developers -->|Push Code| GitHub
    GitHub -->|Deploy| DOKS
    GitHub -->|Deploy| Talos

    DOKS -->|State| DOSpaces
    DOKS -->|Data| DODB
    DOKS -->|Images| DORegistry
    DOKS -->|Metrics| Prometheus
    DOKS -->|Logs| Loki

    Talos -->|Sync| DOKS
    Talos -->|Storage| Storage
    Talos -->|Metrics| Prometheus

    ArgoCD -->|Manage| DOKS
    ArgoCD -->|Manage| Talos

    Prometheus --> Grafana
    Loki --> Grafana

    style DOKS fill:#0080ff,color:#fff
    style Talos fill:#ff6600,color:#fff
    style Cloudflare fill:#f48120,color:#fff
    style GitHub fill:#333,color:#fff
```

## Components

### Cloud Infrastructure (DigitalOcean)

**Purpose**: Primary production environment for public-facing services

**Components**:

- **DOKS (DigitalOcean Kubernetes)**: Managed Kubernetes cluster
  - 3-node cluster (production)
  - Free control plane
  - Auto-scaling enabled
  - NYC3 region

- **DO Spaces**: S3-compatible object storage
  - Terraform state backend
  - Application file storage
  - Backup storage

- **DO Database**: Managed PostgreSQL
  - Automated backups
  - Point-in-time recovery
  - High availability

- **DO Container Registry**: Private Docker registry
  - Application images
  - Base images
  - Vulnerability scanning

### On-Premise Infrastructure

**Purpose**: Internal services, development, and disaster recovery

**Components**:

- **Talos Linux Cluster**: Immutable Kubernetes
  - Production-grade security
  - API-driven management
  - Automatic updates

- **Local Storage**: Persistent volumes
  - NFS/Ceph for shared storage
  - Local SSDs for performance

### DNS & CDN

**Cloudflare**:

- DNS management
- DDoS protection
- SSL/TLS termination
- Global CDN
- Load balancing between cloud/on-prem

### CI/CD Pipeline

**GitHub Actions**:

- Terraform plan/apply
- Ansible playbooks
- Container builds
- Security scanning

**ArgoCD**:

- GitOps deployment
- Automatic synchronization
- Rollback capabilities

### Monitoring & Observability

**Prometheus Stack**:

- Metrics collection
- Alerting
- Node exporter
- kube-state-metrics

**Grafana**:

- Visualization dashboards
- Alert management
- Unified UI for metrics and logs

**Loki**:

- Log aggregation
- Cost-effective storage (S3)
- LogQL queries

## Data Flow

### Deployment Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GHA as GitHub Actions
    participant Argo as ArgoCD
    participant K8s as Kubernetes

    Dev->>GH: Push code
    GH->>GHA: Trigger workflow
    GHA->>GHA: Run tests
    GHA->>GHA: Build image
    GHA->>GH: Push to registry
    GHA->>GH: Update manifests
    GH->>Argo: Webhook
    Argo->>K8s: Deploy application
    K8s->>K8s: Rolling update
    Argo->>Argo: Verify health
```

### User Request Flow

```mermaid
sequenceDiagram
    participant User
    participant CF as Cloudflare
    participant Ingress as Ingress Controller
    participant Svc as Service
    participant Pod
    participant DB as Database

    User->>CF: HTTPS Request
    CF->>Ingress: Forward (TLS terminated)
    Ingress->>Svc: Route by host/path
    Svc->>Pod: Load balance
    Pod->>DB: Query data
    DB->>Pod: Return data
    Pod->>Svc: Response
    Svc->>Ingress: Response
    Ingress->>CF: Response
    CF->>User: Response (cached)
```

## Network Architecture

- **Cloud Network**: DigitalOcean VPC (10.100.0.0/16)
- **On-Prem Network**: Private network (192.168.0.0/16)
- **Hybrid Connectivity**: WireGuard VPN tunnel
- **Public Access**: Via Cloudflare load balancer

## Security

- **TLS Everywhere**: Cloudflare → Ingress → Services
- **Network Policies**: Pod-to-pod traffic control
- **RBAC**: Kubernetes role-based access control
- **Secrets Management**: Multi-layered approach (see ADR-0008)
- **Vulnerability Scanning**: Trivy for containers and IaC

## Disaster Recovery

- **Backups**: Velero for cluster state, automated DB backups
- **Failover**: Cloudflare can route to on-prem if cloud fails
- **RTO**: 2-4 hours for full cluster recovery
- **RPO**: 24 hours for cluster state, 1 hour for databases

## Scaling Strategy

### Horizontal Scaling

- Application pods: HPA based on CPU/memory
- Cluster nodes: Manual or cluster autoscaler

### Vertical Scaling

- Upgrade node sizes via Terraform
- Database tier upgrades for increased load

## Cost Optimization

- **Free Control Plane**: DOKS saves $73/month vs AWS EKS
- **Spot Instances**: Not yet implemented (future optimization)
- **Auto-scaling**: Scale down during low-traffic periods
- **Resource Limits**: Prevent waste via pod resource quotas

## Future Enhancements

- [ ] Multi-region deployment (if global user base grows)
- [ ] Service mesh (Linkerd) for advanced traffic management
- [ ] Automated cluster backups to multiple regions
- [ ] Cost monitoring and optimization automation
- [ ] Zero-trust networking with Cilium

## References

- [ADR-0001: Infrastructure as Code](../decisions/0001-infrastructure-as-code.md)
- [ADR-0005: Kubernetes as Container Platform](../decisions/0005-kubernetes-container-platform.md)
- [Network Topology](network-topology.md)
