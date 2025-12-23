# Stash - Base Configuration

Adult media organizer and video streaming service with a focus on organization and metadata management.

## Overview

[Stash](https://stashapp.cc/) is an open-source, self-hosted web-based media manager and player for adult content. It provides:

- **Media Organization**: Tag, filter, and organize your media collection
- **Metadata Scraping**: Automatic metadata retrieval from various sources
- **Video Streaming**: Built-in video player with streaming support
- **Scene Detection**: Automatic scene fingerprinting and identification
- **Plugin System**: Extensible through community plugins

## Container Details

| Setting | Value |
|---------|-------|
| Image | `stashapp/stash:latest` |
| Default Port | `9999` |
| Web UI | `http://localhost:9999` |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `STASH_VERSION` | Stash image tag | `latest` |
| `STASH_PORT` | Web UI port | `9999` |
| `STASH_STASH` | Media root path (internal) | `/data/` |
| `STASH_GENERATED` | Generated files path | `/generated/` |
| `STASH_METADATA` | Metadata storage path | `/metadata/` |
| `STASH_CACHE` | Cache directory path | `/cache/` |

## Volume Mappings

The base configuration expects overlays to provide:

| Container Path | Purpose |
|----------------|---------|
| `/root/.stash` | Configuration and database |
| `/data` | Media library (videos/images) |
| `/metadata` | Scraped metadata |
| `/cache` | Temporary cache files |
| `/blobs` | Binary blob storage |
| `/generated` | Generated thumbnails/previews |

## Network Modes

### Standard Mode (Default)

- Direct port binding on `9999`
- Suitable for local network access

### DLNA Mode

If DLNA functionality is needed, the overlay should use `network_mode: host` instead of port mapping.

## Usage

This is a base configuration. Use with environment-specific overlays:

```bash
docker compose \
  -f base/stash/docker-compose.yml \
  -f overlays/stash/<environment>/docker-compose.override.enc.yml \
  up -d
```

## Initial Setup

1. Access the web UI at `http://<host>:9999`
2. Complete the setup wizard:
   - Configure library paths
   - Set up scanning preferences
   - Configure metadata scrapers
3. Run initial library scan

## Resources

- [Documentation](https://docs.stashapp.cc/)
- [GitHub Repository](https://github.com/stashapp/stash)
- [Community Plugins](https://github.com/stashapp/CommunityScripts)
