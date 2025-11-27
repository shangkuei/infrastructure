# Immich - Photo and Video Management

Immich is a self-hosted photo and video backup solution with machine learning capabilities.

## Why Docker-Compose (Not Kubernetes)

- **Large photo/video storage**: Direct access to storage arrays for multi-TB media libraries
- **GPU acceleration**: Native NVIDIA container toolkit for ML inference (face recognition, search)
- **Simplified GPU access**: No Kubernetes device plugins required
- **Performance**: Direct I/O for large media files

## Components

| Service | Description |
|---------|-------------|
| `immich-server` | Main API server and web interface (port 2283) |
| `immich-machine-learning` | ML inference (face detection, smart search) |
| `redis` | Job queue and caching |
| `database` | PostgreSQL with pgvecto-rs for vector search |

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `IMMICH_VERSION` | Immich version tag | `release` |
| `DB_USERNAME` | PostgreSQL username | `postgres` |
| `DB_PASSWORD` | PostgreSQL password | **Required** |
| `DB_DATABASE_NAME` | PostgreSQL database | `immich` |

### Volumes (Base)

- `model-cache`: Machine learning model cache

### Volumes (Override)

Environment-specific overlays should configure:

- Photo library storage paths
- Database data location
- Tailscale state directory (if used)

### GPU Support (Override)

Enable GPU in environment overlay for hardware transcoding and ML acceleration:

```yaml
services:
  immich-server:
    runtime: nvidia
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu, compute, video]

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}-cuda
    runtime: nvidia
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

## Network Architecture

The base configuration creates an internal network (`immich-internal`) for inter-service communication.

Overlays can add:

- **Traefik network**: For public HTTPS access via reverse proxy
- **Tailscale sidecar**: For private network access

## Deployment

Use the Makefile in environment overlays to manage secrets, then deploy with docker compose:

```bash
cd overlays/immich/<environment>/

# View merged configuration
make config

# Deploy (example with all overlays)
docker compose \
  -f ../../../base/immich/docker-compose.yml \
  -f docker-compose.override.yml \
  -f docker-compose.traefik.override.yml \
  -f docker-compose.tailscale.override.yml \
  up -d
```

## References

- [Immich Documentation](https://immich.app/docs)
- [Immich GitHub](https://github.com/immich-app/immich)
- [Immich Releases](https://github.com/immich-app/immich/releases)
