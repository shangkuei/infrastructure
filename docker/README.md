# Docker Compose Infrastructure

This directory contains docker-compose configurations for storage-heavy and GPU-intensive applications running directly on Unraid, managed via GitOps workflows.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Infrastructure Repository                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────┐       ┌─────────────────────────────┐  │
│  │     kubernetes/     │       │         docker/             │  │
│  │                     │       │                             │  │
│  │  • Stateless apps   │       │  • Storage-heavy apps       │  │
│  │  • HA workloads     │       │  • GPU-intensive apps       │  │
│  │  • Cloud-native     │       │  • Direct array access      │  │
│  │                     │       │                             │  │
│  │  VS Code Server     │       │  Gitea, Immich, Plex        │  │
│  │  Vaultwarden, n8n   │       │                             │  │
│  └─────────────────────┘       └─────────────────────────────┘  │
│           │                               │                      │
│           ▼                               ▼                      │
│  ┌─────────────────────┐       ┌─────────────────────────────┐  │
│  │  Talos Kubernetes   │       │     Unraid Docker Host      │  │
│  │  (Flux CD GitOps)   │       │   (docker-compose GitOps)   │  │
│  └─────────────────────┘       └─────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
docker/
├── base/                           # Base docker-compose configurations
│   ├── gitea/                      # Git hosting service
│   │   ├── docker-compose.yml
│   │   └── README.md
│   ├── immich/                     # Photo management
│   │   ├── docker-compose.yml
│   │   └── README.md
│   └── plex/                       # Media server
│       ├── docker-compose.yml
│       └── README.md
│
├── overlays/                       # Environment-specific configurations
│   ├── gitea/
│   │   └── shangkuei-xyz-unraid/   # Unraid host overlay
│   │       ├── .sops.yaml
│   │       ├── docker-compose.override.yml
│   │       ├── .env.example
│   │       ├── .env.sops
│   │       └── Makefile
│   ├── immich/
│   │   └── shangkuei-xyz-unraid/
│   └── plex/
│       └── shangkuei-xyz-unraid/
│
└── README.md                       # This file
```

## Workload Distribution

| Application | Platform | Reason |
|-------------|----------|--------|
| **Gitea** | Docker (Unraid) | Large repository storage on array |
| **Immich** | Docker (Unraid) | GPU ML inference, photo storage |
| **Plex** | Docker (Unraid) | Hardware transcoding, media library |
| **VS Code Server** | Kubernetes | Stateless, benefits from K8s features |
| **Vaultwarden** | Kubernetes | HA, encrypted secrets management |
| **n8n** | Kubernetes | Stateless, scalable workflows |

## Quick Start

### Prerequisites

- Unraid with Docker Compose Manager plugin
- SOPS and Age for secrets management
- Tailscale for secure access

### Deploy a Service

```bash
# Navigate to service overlay
cd docker/overlays/gitea/shangkuei-xyz-unraid

# Decrypt secrets (requires Age key)
make decrypt

# Deploy with base + overlay
docker compose \
  -f ../../base/gitea/docker-compose.yml \
  -f docker-compose.override.yml \
  up -d
```

### Manage Secrets

```bash
# Import Age key and generate .sops.yaml
make import-age-key AGE_KEY_FILE=/path/to/age-key.txt

# Encrypt environment file
make encrypt

# Decrypt for local development
make decrypt

# Validate encrypted secrets
make validate
```

## Secrets Management

Secrets are managed using SOPS with Age encryption, consistent with Kubernetes secrets:

### Files

- `.env.example` - Template with placeholder values (versioned)
- `.env.sops` - SOPS-encrypted actual values (versioned)
- `.env` - Decrypted values for deployment (gitignored)
- `.sops.yaml` - SOPS configuration with Age public key

### Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Edit .env.example with new variables                         │
└────────────────┬────────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Create/update .env with actual values                        │
└────────────────┬────────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. Encrypt: make encrypt                                        │
│    • Creates .env.sops from .env                                │
│    • Safe to commit to Git                                      │
└────────────────┬────────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. Commit .env.sops and .env.example                            │
│    • .env stays in .gitignore                                   │
└────────────────┬────────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. CI/CD decrypts and deploys                                   │
│    • GitHub Actions with Tailscale SSH                          │
│    • Decrypts .env.sops → .env                                  │
│    • Runs docker compose up                                     │
└─────────────────────────────────────────────────────────────────┘
```

## GitOps Deployment

### Automated Deployment

Changes to `docker/**` trigger GitHub Actions:

1. Checkout repository
2. Connect via Tailscale SSH
3. Decrypt secrets with SOPS
4. Deploy with docker-compose

### Manual Deployment

```bash
# On Unraid host
cd /mnt/user/appdata/infrastructure/docker

# Pull latest changes
git pull origin main

# Deploy specific service
cd overlays/gitea/shangkuei-xyz-unraid
make decrypt
docker compose \
  -f ../../../base/gitea/docker-compose.yml \
  -f docker-compose.override.yml \
  up -d
```

## Storage Conventions

### Unraid Paths

```yaml
volumes:
  # Configuration (SSD/Cache preferred)
  - /mnt/user/appdata/${SERVICE}:/config

  # Application data
  - /mnt/user/data/${SERVICE}:/data

  # Media library (read-only where applicable)
  - /mnt/user/media:/media:ro
```

### Data Persistence

- **Configuration**: Small files, frequently accessed → Cache/SSD
- **Application data**: Medium files, mixed access → Cache with mover
- **Media**: Large files, sequential access → Array

## Related Documentation

- [ADR-0019: Docker-Compose for Storage/GPU Workloads](../docs/decisions/0019-docker-compose-workloads.md)
- [Research: Docker-Compose Git Version Control](../docs/research/0020-docker-compose-git-management.md)
- [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](../docs/decisions/0016-talos-unraid-primary.md)

## References

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [SOPS Documentation](https://github.com/getsops/sops)
- [Unraid Docker Management](https://docs.unraid.net/unraid-os/manual/docker-management/)
