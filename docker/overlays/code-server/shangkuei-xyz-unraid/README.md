# code-server - shangkuei-xyz-unraid

Docker overlay for code-server deployment on Unraid with Tailscale access.

## Overview

This overlay deploys code-server (VS Code in the browser) with:

- **Tailscale sidecar**: Secure access via hostname `code`
- **Process exporter**: Prometheus metrics at `:9256/metrics`
- **SOPS encryption**: Secrets encrypted with Age

## Quick Start

```bash
# Import Age key (first time only)
make sops-import-key AGE_KEY_FILE=/path/to/key.txt

# Encrypt plaintext files
make encrypt

# Start with Tailscale
make up
```

## Files

| File | Description |
|------|-------------|
| `.enc.env` | Encrypted environment variables |
| `docker-compose.tailscale.override.yml` | Raw override (ports reset, alloy network) |
| `docker-compose.tailscale.override.enc.yml` | Encrypted Tailscale sidecar config |
| `tailscale-serve.json` | Tailscale serve proxy configuration |

## Access

Once deployed, code-server is accessible at:

- **Tailscale**: `https://code.<tailnet-name>.ts.net`

## Metrics

Process-exporter metrics available at `172.24.0.16:9256/metrics` on the alloy-internal network.

Configure in Alloy by setting:

```bash
CODE_SERVER_URL=172.24.0.16:9256
```

## Configuration

Edit encrypted files:

```bash
make edit-env        # Edit .enc.env
make edit-tailscale  # Edit Tailscale override
```
