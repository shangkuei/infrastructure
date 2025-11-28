# Vaultwarden Base Configuration

Self-hosted Bitwarden-compatible password manager with PostgreSQL backend.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    vaultwarden-internal                      │
│                                                              │
│  ┌────────────────────┐     ┌─────────────────────────────┐ │
│  │   vaultwarden      │     │      database               │ │
│  │   (Port 8080)      │────▶│    (PostgreSQL 17)          │ │
│  │                    │     │    (Port 5432)              │ │
│  └────────────────────┘     └─────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Services

### vaultwarden

- **Image**: `vaultwarden/server:latest`
- **Port**: 8080 (HTTP)
- **User**: 1001:1001 (non-root)
- **Features**:
  - PostgreSQL database backend
  - SMTP email notifications
  - Yubico 2FA support
  - Push notifications (Bitwarden-compatible)
  - Admin panel (token-protected)

### database

- **Image**: `postgres:17`
- **Features**:
  - Data checksums for integrity
  - WAL compression
  - Health monitoring with checksum verification

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_NAME` | PostgreSQL database name | `vaultwarden` |
| `DB_USER` | PostgreSQL username | `vaultwarden` |
| `DB_PASS` | PostgreSQL password | `secure-password` |
| `VAULTWARDEN_DOMAIN` | Public URL | `https://vault.example.com` |
| `ADMIN_TOKEN` | Admin panel token (argon2) | `$argon2id$v=19$...` |

### SMTP (Optional)

| Variable | Description | Example |
|----------|-------------|---------|
| `SMTP_HOST` | SMTP server hostname | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP server port | `465` |
| `SMTP_SECURITY` | SMTP security mode | `force_tls` |
| `SMTP_FROM` | Sender email address | `vault@example.com` |
| `SMTP_USERNAME` | SMTP authentication user | `user@example.com` |
| `SMTP_PASSWORD` | SMTP authentication password | `app-password` |

### Yubico 2FA (Optional)

| Variable | Description |
|----------|-------------|
| `YUBICO_CLIENT_ID` | Yubico API client ID |
| `YUBICO_SECRET_KEY` | Yubico API secret key |

### Push Notifications (Optional)

| Variable | Description |
|----------|-------------|
| `PUSH_ENABLED` | Enable push notifications |
| `PUSH_INSTALLATION_ID` | Bitwarden installation ID |
| `PUSH_INSTALLATION_KEY` | Bitwarden installation key |

## Usage

This is a base configuration. Use with environment-specific overlays:

```bash
cd docker/overlays/vaultwarden/shangkuei-xyz-unraid
docker compose \
  -f ../../../base/vaultwarden/docker-compose.yml \
  -f docker-compose.override.yml \
  up -d
```

## Volumes

| Volume | Purpose | Recommended Location |
|--------|---------|---------------------|
| `vaultwarden_data` | Application data, attachments | SSD/Cache |
| `postgres_data` | Database files | SSD/Cache |

## Security Considerations

- **Admin Token**: Generate using `vaultwarden hash` or use argon2id hash
- **Database Password**: Use strong, unique password
- **HTTPS**: Always use HTTPS in production (via Tailscale or reverse proxy)
- **Signups**: Disabled by default, use invitations

## References

- [Vaultwarden GitHub](https://github.com/dani-garcia/vaultwarden)
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Bitwarden Help Center](https://bitwarden.com/help/)
