# Stash - shangkuei-xyz-unraid Overlay

Host-specific configuration for Stash on the Unraid server with Tailscale private access.

## Overview

This overlay configures Stash with:

- Local volume mounts on Unraid appdata shares
- Tailscale sidecar for private network access
- SOPS encryption for sensitive configuration

## Directory Structure

```
shangkuei-xyz-unraid/
├── .env.example                           # Environment template
├── .enc.env                               # Encrypted environment (after setup)
├── .gitignore                             # Git exclusions
├── .sops.yaml                             # SOPS encryption config
├── docker-compose.override.enc.yml        # Host volumes (encrypted)
├── docker-compose.tailscale.override.yml  # Port reset (raw YAML)
├── docker-compose.tailscale.override.enc.yml  # Tailscale sidecar (encrypted)
├── tailscale-serve.json                   # Tailscale serve config
├── Makefile                               # Management commands
└── README.md                              # This file
```

## Initial Setup

### 1. Import Age Key

```bash
make import-age-key AGE_KEY_FILE=/path/to/age-key.txt
```

### 2. Create Environment File

```bash
cp .env.example .enc.env
# Edit .enc.env with actual values
```

### 3. Encrypt Configuration

```bash
make encrypt
```

### 4. Validate Encryption

```bash
make validate
```

## Usage

### Start with Tailscale (Private Access)

```bash
make up
```

This starts Stash accessible via Tailscale at `https://stash.tail-xxxxx.ts.net`.

### View Logs

```bash
make logs
```

### Stop Services

```bash
make down
```

### Edit Encrypted Files

```bash
make edit           # Interactive menu
make edit-env       # Edit .enc.env
make edit-override  # Edit docker-compose.override.enc.yml
make edit-tailscale # Edit docker-compose.tailscale.override.enc.yml
```

## Volume Paths

| Container Path | Host Path | Purpose |
|----------------|-----------|---------|
| `/root/.stash` | `/mnt/user/appdata/stash/config` | Configuration and database |
| `/data` | `/mnt/user/media/stash` | Media library |
| `/metadata` | `/mnt/user/appdata/stash/metadata` | Scraped metadata |
| `/cache` | `/mnt/user/appdata/stash/cache` | Cache files |
| `/blobs` | `/mnt/user/appdata/stash/blobs` | Binary blob storage |
| `/generated` | `/mnt/user/appdata/stash/generated` | Thumbnails/previews |
| Tailscale state | `/mnt/user/appdata/stash/tailscale` | Tailscale persistence |

## Tailscale Configuration

The Tailscale sidecar provides:

- Private access via your Tailnet
- Automatic HTTPS with Tailscale certificates
- No port exposure to the public network

### Tailscale Serve

The `tailscale-serve.json` configures:

- HTTPS on port 443
- Proxy to Stash on port 9999
- Funnel disabled (Tailnet-only access)

### Getting Auth Key

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
2. Generate an auth key (reusable, ephemeral recommended)
3. Add to `.enc.env` as `TS_AUTHKEY`

## Accessing Stash

1. Connect to your Tailnet
2. Navigate to `https://stash.tail-xxxxx.ts.net`
3. Complete initial setup wizard on first access

## Troubleshooting

### Check Container Status

```bash
make ps
```

### View Tailscale Logs

```bash
docker logs stash_tailscale
```

### Verify Tailscale Connection

```bash
docker exec stash_tailscale tailscale status
```

### Reset Tailscale State

If you need to re-authenticate:

```bash
make down
rm -rf /mnt/user/appdata/stash/tailscale/*
make up
```
