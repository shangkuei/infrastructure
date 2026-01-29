# code-server

VS Code in the browser - a self-hosted development environment using the [LinuxServer.io](https://docs.linuxserver.io/images/docker-code-server) image.

## Overview

code-server provides a full VS Code experience accessible through any web browser, enabling remote development from any device.

This setup uses the LinuxServer.io image which includes S6 overlay, Docker mods support, and better integration with PUID/PGID for file permissions.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Docker Host                              │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │                    code-server Network                       ││
│  │                                                              ││
│  │  ┌─────────────────────┐    ┌─────────────────────────────┐ ││
│  │  │    code-server      │    │    process-exporter         │ ││
│  │  │    :8443 (web)      │    │    :9256 (metrics)          │ ││
│  │  │                     │    │    • CPU usage              │ ││
│  │  │  • VS Code UI       │    │    • Memory usage           │ ││
│  │  │  • Extensions       │    │    • File descriptors       │ ││
│  │  │  • Terminal         │    │    • Thread count           │ ││
│  │  │  • Docker Mods      │    │                             │ ││
│  │  └─────────────────────┘    └─────────────────────────────┘ ││
│  │                                                              ││
│  └──────────────────────────────────────────────────────────────┘│
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `UMASK` | `022` | File permission mask |
| `TZ` | `UTC` | Timezone |
| `PASSWORD` | - | Plain text password for web UI |
| `HASHED_PASSWORD` | - | Argon2 hashed password (preferred) |
| `SUDO_PASSWORD` | - | Password for sudo access in terminal |
| `SUDO_PASSWORD_HASH` | - | Hashed sudo password |
| `PROXY_DOMAIN` | - | Domain for proxy configuration |
| `DEFAULT_WORKSPACE` | `/workspace` | Default workspace path in container |
| `CODE_SERVER_PORT` | `8443` | External port mapping |
| `CODE_SERVER_WORKSPACE` | `./workspace` | Workspace directory mount |
| `DOCKER_MODS` | - | Pipe-separated list of Docker mods |
| `INSTALL_PACKAGES` | - | Space-separated packages to install |

## Metrics

Process-level metrics are collected via [process-exporter](https://github.com/ncabatoff/process-exporter):

| Metric | Description |
|--------|-------------|
| `namedprocess_namegroup_cpu_seconds_total` | CPU time consumed |
| `namedprocess_namegroup_memory_bytes` | Memory usage (resident, virtual) |
| `namedprocess_namegroup_open_filedesc` | Open file descriptors |
| `namedprocess_namegroup_num_procs` | Number of processes |
| `namedprocess_namegroup_num_threads` | Number of threads |
| `namedprocess_namegroup_read_bytes_total` | Disk read bytes |
| `namedprocess_namegroup_write_bytes_total` | Disk write bytes |

### Alloy Configuration

To scrape metrics, add to your Alloy environment:

```bash
CODE_SERVER_URL=172.24.0.xx:9256
```

## Quick Start

```bash
# Navigate to overlay
cd docker/overlays/code-server/shangkuei-xyz-unraid

# Import Age key
make sops-import-key AGE_KEY_FILE=/path/to/key.txt

# Start services
make up
```

## Docker Mods

LinuxServer.io supports [Docker Mods](https://mods.linuxserver.io/?mod=code-server) for extending functionality:

```bash
# Example: Add Go, Python, Rust support
DOCKER_MODS=linuxserver/mods:universal-git|linuxserver/mods:code-server-golang|linuxserver/mods:code-server-python3|linuxserver/mods:code-server-rust
```

Popular mods:

- `linuxserver/mods:universal-git` - Git with credential helpers
- `linuxserver/mods:universal-package-install` - Install additional packages via `INSTALL_PACKAGES`
- `linuxserver/mods:code-server-golang` - Go language support
- `linuxserver/mods:code-server-python3` - Python 3 support
- `linuxserver/mods:code-server-rust` - Rust language support

## Security Considerations

1. **Authentication**: Always set `PASSWORD` or `HASHED_PASSWORD`
2. **Network**: Keep on internal network, expose via Tailscale or reverse proxy
3. **HTTPS**: Use a reverse proxy (Traefik, Cloudflare Tunnel) for TLS termination
4. **File Access**: Be mindful of mounted directories - code-server has full access

### Generate Hashed Password

```bash
# Generate argon2 hash for password
echo -n "your-password" | argon2 saltysalt -e
```

## Files

- `docker-compose.yml` - Base compose configuration
- `process-exporter.yml` - Process exporter configuration for metrics
- `README.md` - This documentation

## Related

- [LinuxServer.io code-server](https://docs.linuxserver.io/images/docker-code-server)
- [Docker Mods](https://mods.linuxserver.io/?mod=code-server)
- [code-server Documentation](https://coder.com/docs/code-server)
- [process-exporter](https://github.com/ncabatoff/process-exporter)
