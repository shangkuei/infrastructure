# Immich - shangkuei-xyz-unraid Environment

Environment-specific overlay for Immich on Unraid with dual access:

- **Traefik**: Public HTTPS access via `immich.shangkuei.xyz`
- **Tailscale**: Private access via Tailscale network

## Features

- NVIDIA GPU acceleration for ML inference and transcoding
- SOPS-encrypted secrets management
- Dual access (Traefik + Tailscale)

## Prerequisites

1. Age key for SOPS encryption
2. Tailscale auth key (for Tailscale access)
3. Traefik reverse proxy running (for public access)
4. NVIDIA container toolkit installed

## Quick Start

```bash
# 1. Import age key
make import-age-key AGE_KEY_FILE=/path/to/age-key.txt

# 2. Create .env from example
cp .env.example .env
# Edit .env with actual values

# 3. Encrypt secrets
make encrypt

# 4. View merged config
make config
```

## File Structure

```text
.
├── .env.example                          # Environment template
├── .env                                  # Encrypted secrets (SOPS)
├── .gitignore                            # Git ignore rules
├── .sops.yaml                            # SOPS configuration
├── Makefile                              # Management commands
├── docker-compose.override.yml           # Base overlay (volumes, GPU)
├── docker-compose.traefik.override.yml   # Traefik labels
├── docker-compose.tailscale.override.yml # Tailscale sidecar
├── docker-compose.tailscale.override.raw.yml # Tailscale raw config
└── tailscale-serve.json                  # Tailscale serve config
```

## Management Commands

```bash
make help           # Show all commands
make validate       # Validate encrypted secrets
make env            # Show decrypted .env
make config         # Show merged compose config
make edit           # Interactive edit menu
make edit-env       # Edit .env
make edit-override  # Edit base override
make edit-traefik   # Edit Traefik config
make edit-tailscale # Edit Tailscale config
```

## Storage Paths

| Path | Description |
|------|-------------|
| `/mnt/user/photo/library` | Photo library |
| `/mnt/user/photo/upload` | Upload directory |
| `/mnt/user/photo/encoded-video` | Transcoded videos |
| `/mnt/user/thumb` | Thumbnails |
| `/mnt/user/appdata/immich/postgres` | Database |
| `/mnt/user/appdata/immich/tailscale` | Tailscale state |

## Network Architecture

```text
                    ┌─────────────────┐
                    │    Internet     │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              │
        ┌──────────┐  ┌──────────┐         │
        │ Traefik  │  │Tailscale │         │
        │  :443    │  │  :443    │         │
        └────┬─────┘  └────┬─────┘         │
             │             │               │
             │    ┌────────┘               │
             │    │                        │
             ▼    ▼                        │
        ┌──────────────┐                   │
        │immich-server │◄──────────────────┘
        │    :2283     │     (direct port for local access)
        └──────┬───────┘
               │
    ┌──────────┼──────────┐
    │          │          │
    ▼          ▼          ▼
┌───────┐ ┌────────┐ ┌──────────┐
│ redis │ │database│ │   ML     │
└───────┘ └────────┘ └──────────┘
```

## Troubleshooting

### GPU not detected

```bash
# Check NVIDIA runtime
docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi
```

### Tailscale not connecting

```bash
# Check Tailscale container logs
docker logs immich_tailscale

# Verify auth key is valid
make edit-env  # Check TS_AUTHKEY
```

### Database connection failed

```bash
# Check database health
docker logs immich_postgres

# Verify DB_PASSWORD matches
make env | grep DB_PASSWORD
```
