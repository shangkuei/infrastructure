# Docker SOPS Overlay Skill

Manage Docker Compose overlays with SOPS encryption for secrets.

## When to Use

Use this skill when:

- Creating new Docker service overlays with secrets
- Modifying encrypted Docker Compose files
- Adding environment variables with sensitive values
- Managing service configurations across environments

## Directory Structure

```text
docker/
├── base/<service>/
│   ├── docker-compose.yml        # Base service definition
│   └── config/                   # Base configuration files
└── overlays/<service>/<environment>/
    ├── docker-compose.override.yml       # Non-sensitive overrides
    ├── docker-compose.override.enc.yml   # SOPS-encrypted overrides
    ├── .enc.env                          # SOPS-encrypted environment
    ├── .env.example                      # Example environment template
    └── config/                           # Environment-specific config
```

## SOPS Configuration

### Encryption Key

The age key is stored at: `./age-key.txt` (project root, gitignored)

Recipient public key (from `.sops.yaml`):
`age18pns8av0m2g3wgenjnfkj046340azfytlp0jgpkw4dw7zkh83dwqlct4np`

### SOPS Rules (.sops.yaml)

```yaml
creation_rules:
  - path_regex: .*\.enc\.yml$
    encrypted_regex: ^(environment|volumes)$
    age: age18pns8av0m2g3wgenjnfkj046340azfytlp0jgpkw4dw7zkh83dwqlct4np
  - path_regex: .*\.enc\.env$
    age: age18pns8av0m2g3wgenjnfkj046340azfytlp0jgpkw4dw7zkh83dwqlct4np
```

## Workflow

### Creating New Encrypted Overlay

1. Create the directory structure:

```bash
mkdir -p docker/overlays/<service>/shangkuei-xyz-unraid
```

2. Create plaintext file first:

```yaml
# docker-compose.override.enc.yml (before encryption)
services:
  <service>:
    environment:
      - SECRET_KEY=my-secret-value
```

3. Encrypt with SOPS:

```bash
cd docker/overlays/<service>/shangkuei-xyz-unraid
SOPS_AGE_KEY_FILE=../../../../age-key.txt sops -e -i docker-compose.override.enc.yml
```

### Editing Encrypted Files

```bash
# Edit encrypted YAML
SOPS_AGE_KEY_FILE=./age-key.txt sops docker/overlays/<service>/shangkuei-xyz-unraid/docker-compose.override.enc.yml

# Edit encrypted env file
SOPS_AGE_KEY_FILE=./age-key.txt sops docker/overlays/<service>/shangkuei-xyz-unraid/.enc.env
```

### Decrypting for Inspection

```bash
# Decrypt to stdout
SOPS_AGE_KEY_FILE=./age-key.txt sops -d docker/overlays/<service>/shangkuei-xyz-unraid/docker-compose.override.enc.yml

# Decrypt to file (for debugging)
SOPS_AGE_KEY_FILE=./age-key.txt sops -d docker/overlays/<service>/shangkuei-xyz-unraid/docker-compose.override.enc.yml > /tmp/<service>-decrypted.yml
```

## Compose File Patterns

### Non-Sensitive Override (docker-compose.override.yml)

```yaml
services:
  <service>:
    networks:
      <service_network>:
      alloy:
        ipv4_address: 172.24.0.XX

networks:
  <service_network>:
  alloy:
    external: true
    name: alloy-internal
```

### Encrypted Override (docker-compose.override.enc.yml)

```yaml
services:
  <service>:
    environment:
      - ENC[AES256_GCM,data:...,type:str]
      - ENC[AES256_GCM,data:...,type:str]
    volumes:
      - ENC[AES256_GCM,data:...,type:str]
sops:
  age:
    - recipient: age18pns8av0m2g3wgenjnfkj046340azfytlp0jgpkw4dw7zkh83dwqlct4np
      enc: |
        -----BEGIN AGE ENCRYPTED FILE-----
        ...
        -----END AGE ENCRYPTED FILE-----
  encrypted_regex: ^(environment|volumes)$
```

### Encrypted Environment (.enc.env)

```bash
# After encryption, values are wrapped
SECRET_KEY=ENC[AES256_GCM,data:...,type:str]
DATABASE_URL=ENC[AES256_GCM,data:...,type:str]
```

### Example Environment (.env.example)

Always maintain an example file for documentation:

```bash
# Service Configuration
SECRET_KEY=your-secret-key-here
DATABASE_URL=postgres://user:pass@host:5432/db

# Metrics (optional)
METRICS_ENABLED=true
METRICS_TOKEN=your-metrics-token
```

## YAML Reset Syntax

Use `!reset` tag to clear inherited values:

```yaml
services:
  <service>:
    ports: !reset  # Removes all ports from base config
    networks:
      new_network:
```

## Tailscale Sidecar Pattern

For services using Tailscale:

```yaml
# docker-compose.tailscale.override.yml
services:
  <service>:
    ports: !reset
    networks:
      <service_network>:
      alloy:
        ipv4_address: 172.24.0.XX

networks:
  <service_network>:
  alloy:
    external: true
    name: alloy-internal
```

```yaml
# docker-compose.tailscale.override.enc.yml
services:
  tailscale:
    depends_on:
      - <service>
    environment:
      - ENC[AES256_GCM,data:...,type:str]  # TS_AUTHKEY
      - ENC[AES256_GCM,data:...,type:str]  # TS_HOSTNAME
    volumes:
      - ENC[AES256_GCM,data:...,type:str]  # State volume
      - ENC[AES256_GCM,data:...,type:str]  # Serve config
    networks:
      - <service_network>

networks:
  <service_network>:
```

## Deploying Changes

On the Unraid server:

```bash
cd /path/to/service
docker compose \
  -f docker-compose.yml \
  -f docker-compose.override.yml \
  -f docker-compose.override.enc.yml \
  up -d
```

For Tailscale services:

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.tailscale.override.yml \
  -f docker-compose.tailscale.override.enc.yml \
  up -d
```

## Common Issues

### SOPS Decryption Errors

Ensure the age key file path is correct:

```bash
export SOPS_AGE_KEY_FILE=/full/path/to/age-key.txt
```

### Encrypted Regex Not Matching

Check `.sops.yaml` for the correct `encrypted_regex` pattern. Only matched fields are encrypted.

### Network Conflicts with Tailscale

Services using `network_mode: service:tailscale` cannot join additional networks directly. Override the main service's network configuration instead.
