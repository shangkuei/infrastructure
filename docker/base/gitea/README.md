# Gitea - Self-hosted Git Service

Gitea is a lightweight, self-hosted Git service with PostgreSQL backend and integrated CI/CD runner.

## Why Docker-Compose (Not Kubernetes)

- **Large repository storage**: Direct access to storage arrays for multi-GB repositories
- **Git LFS**: Efficient large file storage without PV/PVC overhead
- **Simplicity**: Single-host deployment is sufficient for personal/small team use
- **CI/CD Runner**: Docker-in-Docker support for Gitea Actions

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Gitea Stack                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Gitea     │    │  PostgreSQL │    │ Act Runner  │     │
│  │   Server    │───▶│   Database  │    │   (CI/CD)   │     │
│  │  :3000/:22  │    │    :5432    │    │             │     │
│  └──────┬──────┘    └─────────────┘    └──────┬──────┘     │
│         │                                      │            │
│         └──────────────────────────────────────┘            │
│                    gitea-internal network                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Services

### Gitea Server

- Web interface and Git hosting
- PostgreSQL database backend
- Git LFS support enabled
- Actions (CI/CD) enabled

### PostgreSQL Database

- Data checksums for integrity verification
- Performance tuning (shared_buffers, wal_compression)
- Health check includes checksum failure detection

### Act Runner

- Gitea Actions compatible runner
- Docker-in-Docker support via socket mount
- Waits for Gitea health before starting

## Configuration

### Required Environment Variables

| Variable | Description |
|----------|-------------|
| `DB_NAME` | PostgreSQL database name |
| `DB_USER` | PostgreSQL username |
| `DB_PASS` | PostgreSQL password |
| `GITEA_RUNNER_REGISTRATION_TOKEN` | Runner registration token |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GITEA_DOMAIN` | Server domain | `localhost` |
| `GITEA_SSH_DOMAIN` | SSH domain | `localhost` |
| `GITEA_ROOT_URL` | Full URL for links | `http://localhost:3000` |
| `GITEA_HTTP_PORT` | HTTP port mapping | `3000` |
| `GITEA_SSH_PORT` | SSH port mapping | `22` |
| `GITEA_DISABLE_REGISTRATION` | Disable new user registration | `true` |
| `GITEA_REQUIRE_SIGNIN` | Require login to view repos | `false` |
| `GITEA_RUNNER_INSTANCE_URL` | URL for runner to connect | `http://gitea:3000` |
| `GITEA_RUNNER_NAME` | Runner display name | `default-runner` |

### Volumes

| Volume | Description |
|--------|-------------|
| `gitea_data` | Gitea configuration, repositories, LFS objects |
| `postgres_data` | PostgreSQL database files |
| `runner_data` | Runner configuration and cache |

## Deployment

### With Overlay (Recommended)

```bash
cd docker/overlays/gitea/<environment>

# First time: Setup secrets
cp .env.example .env
# Edit .env with actual values
make encrypt

# Deploy
make up

# View logs
make logs

# Stop
make down
```

### Manual Deployment

```bash
docker compose \
  -f docker/base/gitea/docker-compose.yml \
  -f docker/overlays/gitea/<environment>/docker-compose.override.yml \
  up -d
```

## Runner Registration

1. Start Gitea and create admin account
2. Go to Site Administration → Actions → Runners
3. Generate new registration token
4. Add token to `.env` as `GITEA_RUNNER_REGISTRATION_TOKEN`
5. Restart the runner: `make down && make up`

## Health Checks

- **Gitea**: HTTP health endpoint at `/api/healthz`
- **PostgreSQL**: Connection check + checksum validation (detects data corruption)
- **Runner**: Depends on Gitea health

## PostgreSQL Lifecycle

> **Version**: PostgreSQL 17 (EOL: November 2029)
>
> PostgreSQL versions are supported for 5 years. Check [endoflife.date/postgresql](https://endoflife.date/postgresql)
> annually and plan upgrades when < 1 year remains before EOL.

| Version | Release | EOL | Status |
|---------|---------|-----|--------|
| 17 | Nov 2024 | Nov 2029 | ✅ Current |
| 16 | Sep 2023 | Nov 2028 | Supported |
| 15 | Oct 2022 | Nov 2027 | Supported |

### Upgrade Checklist (when EOL < 1 year)

1. Test new PostgreSQL version in development
2. Review [release notes](https://www.postgresql.org/docs/release/) for breaking changes
3. Backup database: `pg_dumpall > backup.sql`
4. Update image tag in `docker-compose.yml`
5. Test with `make config` before deploying

## PostgreSQL Performance Tuning

The database includes the following optimizations:

```yaml
- logging_collector=on      # Enable logging
- max_wal_size=2GB          # Larger WAL for better write performance
- shared_buffers=512MB      # Memory for caching
- wal_compression=on        # Reduce disk I/O
```

Adjust `shared_buffers` based on available RAM (typically 25% of total).

## References

- [Gitea Documentation](https://docs.gitea.com/)
- [Gitea Docker Installation](https://docs.gitea.com/installation/install-with-docker)
- [Gitea Actions](https://docs.gitea.com/usage/actions/overview)
- [Act Runner](https://docs.gitea.com/usage/actions/act-runner)
