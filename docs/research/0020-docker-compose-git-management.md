# Research: Docker-Compose Git Version Control

Date: 2025-11-25
Author: Infrastructure Team
Status: Accepted

## Objective

Evaluate approaches for managing docker-compose configurations with Git version control, enabling GitOps
workflows for storage-heavy and GPU-intensive applications that run on dedicated hosts rather than in Kubernetes.

## Executive Summary

Docker-compose on dedicated hosts provides a lightweight orchestration layer for applications that benefit from
direct access to storage arrays, GPU passthrough, or hardware transcoding capabilities. This research evaluates
Git-based version control strategies and GitOps automation options for managing these workloads alongside the
existing Kubernetes infrastructure.

**Recommendation**: Adopt a hybrid approach where storage/GPU-intensive applications (Gitea, Immich, Plex) run
on dedicated hosts via docker-compose with Git-versioned configurations, while stateless/cloud-native applications
(VS Code Server, Vaultwarden, n8n) run on Kubernetes.

## Background

### Current Architecture

The infrastructure uses a Kubernetes-first approach with Talos Linux on Unraid VMs (ADR-0016). However, certain workloads benefit from running directly on the Unraid host:

**Storage-Intensive Applications**:

- Direct access to `/mnt/user/` array without network overhead
- Native support for Unraid's cache pools and mover
- No PV/PVC abstraction layer for large media libraries

**GPU-Intensive Applications**:

- Direct GPU passthrough without Kubernetes device plugins
- Simpler NVIDIA container toolkit integration
- Hardware transcoding without complex scheduling

**Candidate Applications**:

| Application | Type | Unraid Benefit | Platform |
|-------------|------|----------------|----------|
| Gitea | Git hosting | Large repo storage on array | Unraid |
| Immich | Photo management | GPU ML inference, large storage | Unraid |
| Plex | Media server | Hardware transcoding, media storage | Unraid |
| VS Code Server | Development | Stateless, benefits from K8s | Kubernetes |
| Vaultwarden | Password manager | HA, encrypted secrets in K8s | Kubernetes |
| n8n | Workflow automation | Stateless, scales in K8s | Kubernetes |

## Docker-Compose on Unraid

### Installation Methods

#### 1. Docker Compose Manager Plugin (Recommended)

The official plugin for Unraid that installs docker-compose CLI:

- **Installation**: Unraid Community Applications → Docker Compose Manager
- **Includes**: Docker Compose v2 CLI (`docker compose` command)
- **No configuration**: Plugin provides CLI only, no UI management

#### 2. Manual Installation

```bash
# Install docker-compose v2 manually
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64 \
  -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
```

### Recommended Directory Structure

Based on community best practices from [Mike Solin's guide](https://mikesolin.com/2024/12/18/managing-docker-on-unraid/):

```
/mnt/user/appdata/
├── __docker-compose.yml        # Main compose file (underscores sort to top)
├── gitea/
│   ├── config.env              # Non-sensitive configuration
│   ├── secrets.env             # Sensitive credentials (gitignored)
│   └── data/                   # Persistent data (gitignored)
├── immich/
│   ├── config.env
│   ├── secrets.env
│   └── data/
└── plex/
    ├── config.env
    ├── secrets.env
    └── data/
```

**Key Principles**:

- **Underscores prefix**: `__docker-compose.yml` sorts to top in file managers
- **DNS-compliant names**: Service folders use lowercase, hyphen-separated names
- **Environment separation**: `config.env` (versioned) vs `secrets.env` (gitignored)
- **Data isolation**: `data/` directories excluded from Git

## Git Version Control Strategies

### Strategy 1: Dedicated Repository

Create a separate repository for Unraid docker-compose configurations:

```
unraid-compose/
├── .gitignore
├── .sops.yaml                  # SOPS configuration for secrets
├── README.md
├── docker-compose.yml          # Main compose file
├── .env.example                # Template for environment variables
├── .env.sops                   # SOPS-encrypted actual environment
└── services/
    ├── gitea/
    │   ├── config.env
    │   └── config.env.sops     # Encrypted secrets
    ├── immich/
    │   └── ...
    └── plex/
        └── ...
```

**Pros**:

- Clean separation from Kubernetes infrastructure
- Independent deployment cycles
- Simpler CI/CD pipelines

**Cons**:

- Multiple repositories to manage
- Separate secrets management
- Fragmented infrastructure view

### Strategy 2: Monorepo Integration (Recommended)

Integrate docker-compose configs into the existing infrastructure repository, following the Kubernetes folder pattern
with base configurations and environment overlays:

```
infrastructure/
├── docker/
│   ├── base/                           # Base docker-compose configurations
│   │   ├── gitea/
│   │   │   ├── docker-compose.yml      # Service definition
│   │   │   └── README.md               # Service documentation
│   │   ├── immich/
│   │   │   ├── docker-compose.yml
│   │   │   └── README.md
│   │   └── plex/
│   │       ├── docker-compose.yml
│   │       └── README.md
│   │
│   ├── overlays/                       # Environment-specific configurations
│   │   ├── gitea/
│   │   │   └── shangkuei-xyz-unraid/   # Host-specific overlay
│   │   │       ├── .sops.yaml          # SOPS configuration
│   │   │       ├── docker-compose.override.yml
│   │   │       ├── .env.example
│   │   │       ├── .env.sops           # SOPS-encrypted environment
│   │   │       └── Makefile            # Secret management automation
│   │   ├── immich/
│   │   │   └── shangkuei-xyz-unraid/
│   │   └── plex/
│   │       └── shangkuei-xyz-unraid/
│   │
│   └── README.md                       # Docker-compose documentation
│
├── kubernetes/                          # Existing K8s manifests (same pattern)
│   ├── base/
│   └── overlays/
├── terraform/                           # Existing Terraform configs
└── ansible/
    └── roles/
        └── docker-compose-deploy/       # Deployment automation
```

**Pros**:

- Single source of truth for all infrastructure
- Unified secrets management (SOPS/Age)
- Consistent tooling and workflows
- Shared documentation and patterns

**Cons**:

- Larger repository
- Mixed concerns (K8s + Docker)

### Files to Version Control

**Include**:

```gitignore
# Version controlled
docker-compose.yml
docker-compose.*.yml
*.env.example
*.env.sops
config.env
*.sops.yaml
README.md
```

**Exclude (.gitignore)**:

```gitignore
# Secrets (unencrypted)
.env
secrets.env
*.secret

# Runtime data
data/
logs/
*.log

# Temporary files
*.tmp
*.bak

# Override files (local development)
docker-compose.override.yml
```

## Secrets Management

### Option 1: SOPS with Age (Recommended)

Consistent with existing Kubernetes secrets management:

```yaml
# .sops.yaml
creation_rules:
  - path_regex: \.env\.sops$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - path_regex: secrets\.env\.sops$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Encryption workflow**:

```bash
# Encrypt secrets
sops --encrypt .env > .env.sops

# Decrypt for deployment
sops --decrypt .env.sops > .env
```

### Option 2: Environment Template Pattern

For simpler setups without encryption at rest:

```bash
# .env.example (versioned)
POSTGRES_PASSWORD=changeme
ADMIN_TOKEN=changeme

# .env (gitignored, actual values)
POSTGRES_PASSWORD=actual_secure_password
ADMIN_TOKEN=actual_token
```

### Option 3: External Secret Store

Integration with Vaultwarden or other secret managers:

```yaml
services:
  app:
    environment:
      - DATABASE_URL=file:///run/secrets/db_url
    secrets:
      - db_url

secrets:
  db_url:
    external: true
```

## GitOps Automation Options

### Option 1: Composed (Simple GitOps Script)

[Pelski/composed](https://github.com/Pelski/composed) - Lightweight GitOps for docker-compose:

**Features**:

- Pulls from Git repository on schedule
- Detects changes in docker-compose files
- Restarts affected services
- Discord notifications

**Setup**:

```bash
# Clone composed script
git clone https://github.com/Pelski/composed.git /mnt/user/appdata/composed

# Configure deployments directory
export DEPLOYMENTS_DIR=/mnt/user/appdata

# Run via cron (User Scripts plugin)
*/5 * * * * /mnt/user/appdata/composed/composed.sh
```

**Disable specific services**:

```yaml
#disabled
services:
  disabled-service:
    image: ...
```

### Option 2: GitHub Actions with Tailscale SSH

[docker-compose-gitops-action](https://github.com/FarisZR/docker-compose-gitops-action) - CI/CD deployment:

```yaml
# .github/workflows/deploy-docker-compose.yml
name: Deploy Docker Compose

on:
  push:
    branches: [main]
    paths:
      - 'docker/**'
  workflow_dispatch:
    inputs:
      service:
        description: 'Service to deploy (gitea, immich, plex, or all)'
        required: true
        default: 'all'

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [gitea, immich, plex]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Tailscale
        uses: tailscale/github-action@v2
        with:
          oauth-client-id: ${{ secrets.TS_OAUTH_CLIENT_ID }}
          oauth-secret: ${{ secrets.TS_OAUTH_SECRET }}
          tags: tag:ci

      - name: Decrypt secrets
        run: |
          cd docker/overlays/${{ matrix.service }}/shangkuei-xyz-unraid
          sops --decrypt .env.sops > .env

      - name: Deploy to host
        uses: FarisZR/docker-compose-gitops-action@v1
        with:
          remote_docker_host: root@unraid
          tailscale_ssh: true
          compose_file_path: docker/base/${{ matrix.service }}/docker-compose.yml
          upload_directory: true
          docker_compose_directory: docker/overlays/${{ matrix.service }}/shangkuei-xyz-unraid
          args: >-
            -f /tmp/docker-compose/docker-compose.yml
            -f docker-compose.override.yml
            -p ${{ matrix.service }}
            up -d --remove-orphans
```

**Benefits**:

- Integrates with existing Tailscale network
- No SSH keys to manage (Tailscale SSH)
- Automated deployments on push
- Consistent with Flux CD workflow pattern

### Option 3: Ansible Playbook (Infrastructure as Code)

```yaml
# ansible/roles/docker-compose-deploy/tasks/main.yml
---
- name: Ensure docker-compose directory exists
  file:
    path: "{{ compose_dir }}"
    state: directory
    mode: '0755'

- name: Copy docker-compose files
  template:
    src: "{{ item }}"
    dest: "{{ compose_dir }}/{{ item | basename | regex_replace('\\.j2$', '') }}"
  loop: "{{ lookup('fileglob', 'templates/*.j2', wantlist=True) }}"
  notify: Restart docker-compose

- name: Decrypt and copy secrets
  shell: |
    sops --decrypt {{ secrets_file }} > {{ compose_dir }}/.env
  when: secrets_file is defined

- name: Pull latest images
  command: docker compose pull
  args:
    chdir: "{{ compose_dir }}"

- name: Deploy services
  command: docker compose up -d --remove-orphans
  args:
    chdir: "{{ compose_dir }}"
```

### Option 4: User Scripts + Cron (Simplest)

Unraid User Scripts plugin with scheduled Git pull:

```bash
#!/bin/bash
# /boot/config/plugins/user.scripts/scripts/docker-compose-sync/script

COMPOSE_DIR="/mnt/user/appdata/docker-compose"
GIT_REPO="git@github.com:username/infrastructure.git"
COMPOSE_PATH="docker/unraid"

# Pull latest changes
cd "$COMPOSE_DIR" || exit 1
git fetch origin main
git reset --hard origin/main

# Decrypt secrets if using SOPS
if [ -f ".env.sops" ]; then
    sops --decrypt .env.sops > .env
fi

# Update containers
docker compose pull
docker compose up -d --remove-orphans

# Cleanup old images
docker image prune -a -f --filter "until=168h"

# Log completion
echo "$(date): Docker compose sync completed" >> /var/log/docker-compose-sync.log
```

**Schedule**: Run daily or on-demand via Unraid User Scripts plugin

## Comparison Matrix

| Feature | Composed | GitHub Actions | Ansible | User Scripts |
|---------|----------|----------------|---------|--------------|
| **Setup Complexity** | Low | Medium | Medium | Low |
| **Automation Level** | High | High | High | Medium |
| **Tailscale Integration** | Manual | Native | Manual | Manual |
| **Secret Management** | External | SOPS | Ansible Vault/SOPS | SOPS |
| **Notifications** | Discord | GitHub | Custom | Custom |
| **Rollback Support** | Git | Git | Git + Ansible | Git |
| **Audit Trail** | Git log | GitHub Actions | Git + Ansible logs | Git log |
| **Consistency with K8s** | Low | High | Medium | Low |

## Recommended Implementation

### Phase 1: Repository Structure

Add docker-compose configuration following the Kubernetes base/overlay pattern:

```
docker/
├── base/                           # Base docker-compose configurations
│   ├── gitea/
│   │   ├── docker-compose.yml      # Service definition
│   │   └── README.md
│   ├── immich/
│   │   ├── docker-compose.yml
│   │   └── README.md
│   └── plex/
│       ├── docker-compose.yml
│       └── README.md
│
├── overlays/                       # Environment-specific configurations
│   ├── gitea/
│   │   └── shangkuei-xyz-unraid/
│   │       ├── .sops.yaml
│   │       ├── docker-compose.override.yml
│   │       ├── .env.example
│   │       ├── .env.sops
│   │       ├── .gitignore
│   │       └── Makefile
│   ├── immich/
│   │   └── shangkuei-xyz-unraid/
│   └── plex/
│       └── shangkuei-xyz-unraid/
│
└── README.md
```

### Phase 2: Secrets Management

Use SOPS with Age key (consistent with Kubernetes secrets):

```yaml
# docker/overlays/gitea/shangkuei-xyz-unraid/.sops.yaml
creation_rules:
  - path_regex: \.env\.sops$
    age: age1... # Same key as kubernetes/overlays/flux-instance
```

Each overlay includes a Makefile for secret management automation:

```bash
make import-age-key AGE_KEY_FILE=/path/to/age-key.txt  # Import Age key
make encrypt                                            # Encrypt .env to .env.sops
make decrypt                                            # Decrypt .env.sops to .env
make up                                                 # Deploy service
make down                                               # Stop service
```

### Phase 3: Deployment Automation

Implement GitHub Actions with Tailscale SSH:

1. Create workflow triggered on `docker/**` path changes
2. Use Tailscale GitHub Action for secure connectivity
3. Deploy via docker-compose-gitops-action with base + overlay
4. Add manual workflow_dispatch trigger for on-demand deployments

**Deployment command pattern**:

```bash
docker compose \
  -f base/gitea/docker-compose.yml \
  -f overlays/gitea/shangkuei-xyz-unraid/docker-compose.override.yml \
  up -d
```

### Phase 4: Monitoring Integration

- Add container health checks to docker-compose
- Export metrics via Prometheus node exporter
- Integrate with existing Grafana dashboards

## Security Considerations

### Network Security

- **Tailscale only**: No direct SSH exposure to internet
- **Service isolation**: Use Docker networks to isolate services
- **Port exposure**: Minimize exposed ports, use Tailscale for access

### Secret Security

- **Encryption at rest**: SOPS-encrypted secrets in Git
- **Age keys**: Separate keys for Unraid vs Kubernetes (optional)
- **No plaintext secrets**: Never commit unencrypted `.env` files

### Container Security

- **Image sources**: Use official images or verified publishers
- **Version pinning**: Pin image versions, avoid `latest` tag
- **Read-only mounts**: Use `:ro` for config files where possible
- **Resource limits**: Set memory and CPU limits

## Migration Path

### From Unraid Docker Templates

1. Export existing container configurations
2. Convert to docker-compose format (use [composerize](https://github.com/llalon/unraid-plugin-composerize))
3. Test docker-compose configuration
4. Remove original Unraid docker template
5. Deploy via docker-compose

### Rollback Strategy

```bash
# Rollback to previous version
cd /mnt/user/appdata/docker-compose
git log --oneline -5  # Find previous commit
git checkout <commit-hash>
docker compose up -d --remove-orphans

# Or use GitHub Actions to redeploy specific commit
```

## Limitations and Trade-offs

### Limitations

1. **No built-in HA**: Docker-compose is single-host only
2. **Manual health management**: No automatic container restart on failure (use `restart: always`)
3. **Limited scheduling**: No native scheduling like Kubernetes CronJobs
4. **No service mesh**: No native service discovery or load balancing

### Trade-offs

| Aspect | Docker-Compose | Kubernetes |
|--------|----------------|------------|
| **Complexity** | Simple | Complex |
| **Storage Access** | Direct | PV/PVC abstraction |
| **GPU Support** | Native | Device plugins |
| **High Availability** | No | Yes |
| **Scaling** | Manual | Automatic |
| **Resource Overhead** | Low | Higher |

## Conclusion

For storage-heavy and GPU-intensive applications, docker-compose with Git version control provides a practical
solution that balances simplicity with GitOps principles. The recommended approach:

- Integrates docker-compose configurations into the existing infrastructure repository
- Follows the Kubernetes base/overlay pattern for consistency
- Uses SOPS for secrets management (same Age keys as Kubernetes)
- Leverages GitHub Actions with Tailscale for automated deployments

This hybrid approach allows:

- **Optimal workload placement**: Storage/GPU apps on Unraid, cloud-native apps on Kubernetes
- **Unified infrastructure management**: Single repository, consistent tooling
- **GitOps workflows**: Version-controlled, automated deployments
- **Security**: Encrypted secrets, Tailscale-only access

## References

- [Docker Compose Manager Plugin](https://forums.unraid.net/topic/114415-plugin-docker-compose-manager/)
- [Managing Docker on Unraid](https://mikesolin.com/2024/12/18/managing-docker-on-unraid/)
- [compose-on-unraid Guide](https://github.com/neoKushan/compose-on-unraid)
- [Docker Compose GitOps Action](https://github.com/FarisZR/docker-compose-gitops-action)
- [Composed - Simple GitOps](https://github.com/Pelski/composed)
- [Unraid Docker Management](https://docs.unraid.net/unraid-os/manual/docker-management/)
- [SOPS Documentation](https://github.com/getsops/sops)

## Related Documentation

- [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](../decisions/0016-talos-unraid-primary.md)
- [ADR-0019: Docker-Compose for Storage/GPU Workloads](../decisions/0019-docker-compose-workloads.md)
- [Research: Tailscale Evaluation](0017-tailscale-evaluation.md)
