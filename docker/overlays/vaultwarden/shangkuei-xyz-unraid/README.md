# Vaultwarden - shangkuei-xyz-unraid Overlay

Environment-specific configuration for Vaultwarden on the shangkuei-xyz Unraid server.

## Quick Start

```bash
# 1. Import Age key and generate .sops.yaml
make import-age-key AGE_KEY_FILE=/path/to/your/age-key.txt

# 2. Copy .env.example to .env and fill in values
cp .env.example .env
# Edit .env with your actual values

# 3. Encrypt sensitive files
make encrypt

# 4. Start services
make up
```

## Files

| File | Purpose | Encrypted |
|------|---------|-----------|
| `docker-compose.override.yml` | Unraid-specific paths | Yes (volumes) |
| `docker-compose.tailscale.override.yml` | Tailscale sidecar | Yes (auth keys) |
| `docker-compose.tailscale.override.raw.yml` | Non-sensitive Tailscale config | No |
| `.env` | Environment variables | Yes |
| `.env.example` | Template for .env | No |
| `tailscale-serve.json` | Tailscale HTTPS serve config | No |
| `.sops.yaml` | SOPS encryption config | No |
| `age-key.txt` | Age private key | **Never commit** |

## Configuration

### Domain

- **Public URL**: `https://vaultwarden.shangkuei.xyz`
- **Tailscale**: `https://vaultwarden.{tailnet}.ts.net`

### Features Enabled

- PostgreSQL database backend
- Gmail SMTP for email notifications
- Yubico 2FA support
- Push notifications (Bitwarden-compatible)
- Admin panel (token-protected)
- Signups disabled (invitation-only)

### Data Paths (Unraid)

- **App Data**: `/mnt/user/appdata/vaultwarden/`
- **PostgreSQL**: `/mnt/user/appdata/vaultwarden/postgres/`
- **Tailscale State**: `/mnt/user/appdata/vaultwarden/tailscale/`

## Make Commands

```bash
make help              # Show available commands
make import-age-key    # Import Age key and generate .sops.yaml
make encrypt           # Encrypt plaintext files
make edit-env          # Edit .env with sops
make edit-override     # Edit docker-compose.override.yml
make edit-tailscale    # Edit docker-compose.tailscale.override.yml
make validate          # Validate encrypted files
make env               # Show decrypted .env
make config            # Show merged docker-compose config
make up                # Start services
make down              # Stop services
make logs              # View logs
make ps                # Show container status
make restart           # Restart services
make pull              # Pull latest images
```

## Migration from Kubernetes

This configuration was migrated from the Flux/Kubernetes deployment at:
`/Users/shangkuei/dev/shangkuei/flux/shangkuei/vaultwarden/`

### Key Differences

| Aspect | Kubernetes | Docker Compose |
|--------|------------|----------------|
| Orchestration | Flux CD | Manual / CI pipeline |
| Secrets | SOPS + ExternalSecret | SOPS + Age encryption |
| Ingress | Gateway API (HTTPRoute) | Tailscale Serve |
| Storage | PVC (OpenEBS/SMB) | Unraid array paths |
| Networking | K8s Service | Docker network + Tailscale |

## Backup Recommendations

1. **Database**: Use `pg_dump` for PostgreSQL backups
2. **Vaultwarden Data**: Backup `/mnt/user/appdata/vaultwarden/`
3. **Encryption Keys**: Securely store Age key separately

## Troubleshooting

### Check container health

```bash
docker exec vaultwarden_server curl -fsSL http://localhost:8080/alive
docker exec vaultwarden_postgres pg_isready -U vaultwarden
```

### View logs

```bash
make logs
# Or for specific service:
docker logs vaultwarden_server
docker logs vaultwarden_postgres
docker logs vaultwarden_tailscale
```

### Regenerate admin token

```bash
# Generate new argon2id hash
docker run --rm -it vaultwarden/server /vaultwarden hash
# Update ADMIN_TOKEN in .env and re-encrypt
make edit-env
```
