# Plex Media Server

Plex is a media server for organizing and streaming personal media collections.

## Why Docker-Compose (Not Kubernetes)

- **Large media library**: Direct access to storage arrays for multi-TB media collections
- **Hardware transcoding**: Native GPU/iGPU passthrough for real-time transcoding
- **Simplified hardware access**: No Kubernetes device plugins for GPU/Quick Sync
- **Performance**: Direct I/O for streaming large video files

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PLEX_VERSION` | Plex version tag | `latest` |
| `PLEX_PORT` | Web UI port | `32400` |
| `TZ` | Timezone | `UTC` |
| `PLEX_CLAIM` | Claim token for server setup | Empty |
| `PLEX_UID` | User ID for file permissions | `1000` |
| `PLEX_GID` | Group ID for file permissions | `1000` |
| `PLEX_ADVERTISE_IP` | Advertised IP for remote access | Auto-detected |

### Volumes

- `plex_config`: Plex configuration and metadata database
- `plex_transcode`: Temporary transcoding files (use SSD/RAM)
- Media libraries: Mounted in overlay (read-only recommended)

### Hardware Transcoding (Override)

Enable GPU in environment overlay:

```yaml
services:
  plex:
    devices:
      # NVIDIA GPU
      - /dev/nvidia0:/dev/nvidia0
      - /dev/nvidiactl:/dev/nvidiactl
      - /dev/nvidia-uvm:/dev/nvidia-uvm
      # Intel Quick Sync
      - /dev/dri:/dev/dri
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
```

## Deployment

```bash
# With overlay
docker compose \
  -f docker-compose.yml \
  -f ../../overlays/plex/<environment>/docker-compose.override.yml \
  up -d
```

## Getting a Claim Token

1. Go to https://www.plex.tv/claim/
2. Sign in to your Plex account
3. Copy the claim token (valid for 4 minutes)
4. Set `PLEX_CLAIM` in your environment

## References

- [Plex Documentation](https://support.plex.tv/)
- [Plex Docker Hub](https://hub.docker.com/r/plexinc/pms-docker)
