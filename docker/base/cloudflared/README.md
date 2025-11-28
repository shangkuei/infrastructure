# Cloudflare Tunnel (cloudflared)

Secure ingress for Docker Compose services via Cloudflare Tunnel without exposing ports to the internet.

## Overview

Cloudflare Tunnel creates an outbound-only connection to Cloudflare's edge, allowing secure access to internal services without opening firewall ports or exposing services directly.

## Architecture

```text
Internet → Cloudflare Edge → Tunnel → cloudflared container → Internal services
                                              ↓
                                    Docker network access to:
                                    - Gitea (gitea-internal)
                                    - Immich (immich-internal)
                                    - Plex (plex-internal)
```

## Prerequisites

1. **Cloudflare Account** with a domain
2. **Tunnel Token** from Cloudflare Zero Trust dashboard or Terraform
3. **Tunnel Configuration** (ingress rules) managed in Cloudflare dashboard or via Terraform

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `TUNNEL_TOKEN` | Cloudflare Tunnel token | Yes |

### Network Connectivity

The cloudflared container needs network access to services it proxies. Add external networks in the overlay:

```yaml
networks:
  gitea-internal:
    external: true
  immich-internal:
    external: true
```

## Tunnel Management

### Option 1: Terraform (Recommended)

Use the `terraform/modules/cloudflared` module to manage tunnel and ingress rules as code.

### Option 2: Cloudflare Dashboard

1. Go to Cloudflare Zero Trust → Networks → Tunnels
2. Create tunnel and copy the token
3. Configure ingress rules in the dashboard

## Ingress Rules Example

When configuring the tunnel (in Terraform or dashboard), use Docker network DNS:

```yaml
# For Gitea on gitea-internal network
hostname: git.example.com
service: http://gitea_server:3000

# For Immich on immich-internal network
hostname: photos.example.com
service: http://immich_server:2283
```

## Deployment

```bash
cd docker/overlays/cloudflared/shangkuei-xyz-unraid

# Decrypt secrets
make decrypt

# Deploy
make up
```

## Dependency Hierarchy

Per [ADR-0020](../../../docs/decisions/0020-infrastructure-dependency-hierarchy.md):

- **Tier**: Docker-Compose (Tier 3)
- **Depends on**: External SaaS (Cloudflare) only
- **Does NOT depend on**: Talos cluster services

This ensures Unraid services can be accessed even if the Kubernetes cluster is down.

## References

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [cloudflared Docker Image](https://hub.docker.com/r/cloudflare/cloudflared)
- [ADR-0020: Infrastructure Dependency Hierarchy](../../../docs/decisions/0020-infrastructure-dependency-hierarchy.md)
