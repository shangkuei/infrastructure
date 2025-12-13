# SOPS Secrets for Flux Instance (GitOps-Managed)

This directory contains SOPS-encrypted secrets that are managed via Flux GitOps. The secrets are encrypted with age and can be safely committed to Git.

## ✅ GitOps Integration

- **SOPS-encrypted secrets** are safe to commit to Git
- **Flux kustomize-controller** automatically decrypts using the `sops-age` secret
- **Secrets managed via Kustomize** overlay for the shangkuei-dev cluster
- **Referenced by**: `kubernetes/clusters/shangkuei-dev/kustomization-flux-instance.yaml`

## Quick Start

Generate encrypted secrets using the provided Makefile:

```bash
# Show available commands
make help

# Step 1: Import existing age key and generate .sops.yaml
make import-age-key AGE_KEY_FILE=~/.config/sops/age/gitops-shangkuei-dev-flux.txt

# Step 2: Generate secrets individually
make secret-sops-age      # Generate SOPS age secret (encrypted)
make secret-flux-git      # Generate Flux Git credentials (encrypted)

# Or use setup (after importing key)
make setup

# Validate encrypted secrets
make validate

# View decrypted secrets (creates .decrypted files)
make decrypt-all
```

**Required input**:

- Age encryption key file (from `~/.config/sops/age/gitops-shangkuei-dev-flux.txt`)

**Output files**:

- `age-key.txt` - Age private key (DO NOT commit to Git)
- `.sops.yaml` - SOPS configuration with age public key (generated locally)
- `*.enc` - SOPS-encrypted secrets (safe to commit, reference only)
- `*.decrypted` - Plaintext secrets (DO NOT commit to Git)

## Workflow Overview

### Initial Setup (GitOps)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Generate or obtain age encryption key                   │
│    age-keygen -o age-key.txt                                │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Import key and generate .sops.yaml                      │
│    make import-age-key AGE_KEY_FILE=age-key.txt            │
│    • Copies key to local age-key.txt                       │
│    • Extracts public key                                   │
│    • Generates .sops.yaml with public key                  │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Generate encrypted secrets                              │
│    make secret-sops-age    # SOPS age key secret          │
│    make secret-flux-git    # Flux Git credentials         │
│    • Creates encrypted .enc files                          │
│    • Uses .sops.yaml for encryption                        │
│    • Safe to commit to Git                                 │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Bootstrap: Manually create sops-age secret              │
│    • kubectl create secret generic sops-age \               │
│      --from-file=age.agekey=age-key.txt -n flux-system     │
│    • Required ONE TIME for Flux to decrypt secrets         │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Commit encrypted secrets to Git                         │
│    • git add secret-*.yaml.enc                             │
│    • git commit -m "feat: add flux SOPS secrets"          │
│    • git push                                               │
└────────────────┬────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Flux GitOps applies secrets automatically               │
│    • Flux syncs from Git repository                        │
│    • kustomize-controller decrypts .enc files              │
│    • Secrets applied to flux-system namespace              │
└─────────────────────────────────────────────────────────────┘
```

## SOPS Secrets

### 1. Secret: sops-age

**File**: [secret-sops-age.yaml.enc](secret-sops-age.yaml.enc) (to be generated)

Contains the age encryption private key used by Flux to decrypt SOPS-encrypted manifests.

### 2. Secret: flux-system (Git Credentials)

**File**: [secret-flux-git-credentials.yaml.enc](secret-flux-git-credentials.yaml.enc) (to be generated)

Contains GitHub credentials (username and token) used by Flux to authenticate when cloning the Git repository.

## References

- [Flux SOPS Guide](https://fluxcd.io/flux/guides/mozilla-sops/)
- [Age Encryption](https://github.com/FiloSottile/age)
- [GitHub Token Permissions](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
