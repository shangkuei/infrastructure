# Alloy - shangkuei-xyz-unraid

Grafana Alloy telemetry agent for Unraid Docker host.

## Setup

1. **Import Age key:**

   ```bash
   make sops-import-key AGE_KEY_FILE=/path/to/age-key.txt
   ```

2. **Create encrypted environment file:**

   ```bash
   # Copy example and edit
   cp .env.example .enc.env
   # Edit with your values
   vim .enc.env
   # Encrypt
   make encrypt
   ```

3. **Start service:**

   ```bash
   make up
   ```

## Verify

```bash
# Check container status
make ps

# View logs
make logs

# Check Alloy ready endpoint
curl http://localhost:12345/-/ready
```

## Loki Queries

Once running, logs can be queried in Grafana:

```logql
# All logs from this cluster
{cluster="shangkuei-unraid"}

# Logs from specific container
{cluster="shangkuei-unraid", container="immich_server"}

# Logs from specific compose project
{cluster="shangkuei-unraid", compose_project="immich"}
```

## Files

| File | Description |
|------|-------------|
| `.env.example` | Environment variable template |
| `.enc.env` | Encrypted environment (SOPS) |
| `Makefile` | Build and deployment operations |
| `.sops.yaml` | SOPS encryption configuration |
| `age-key.txt` | Local Age private key |
