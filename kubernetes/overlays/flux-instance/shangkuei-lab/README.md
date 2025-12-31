# SOPS Secrets for Flux Instance (GitOps-Managed)

This directory contains SOPS-encrypted secrets that are managed via Flux GitOps. The secrets are encrypted with age and can be safely committed to Git.

## GitOps Integration

- **SOPS-encrypted secrets** are safe to commit to Git
- **Flux kustomize-controller** automatically decrypts using the `sops-age` secret
- **Secrets managed via Kustomize** overlay for the shangkuei-lab cluster
- **Referenced by**: `kubernetes/clusters/shangkuei-lab/kustomization-flux-instance.yaml`

## Quick Start

Generate encrypted secrets using the provided Makefile:

```bash
# Show available commands
make help

# Step 1: Import existing age key and generate .sops.yaml
make import-age-key AGE_KEY_FILE=~/.config/sops/age/gitops-shangkuei-lab-flux.txt

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

- Age encryption key file (from `~/.config/sops/age/gitops-shangkuei-lab-flux.txt`)

**Output files**:

- `age-key.txt` - Age private key (DO NOT commit to Git)
- `.sops.yaml` - SOPS configuration with age public key (generated locally)
- `*.enc.yaml` - SOPS-encrypted secrets (safe to commit)
- `*.decrypted` - Plaintext secrets (DO NOT commit to Git)

## Workflow Overview

### Initial Setup (GitOps)

```
1. Generate or obtain age encryption key
   cd terraform/environments/gitops-shangkuei-lab
   make flux-keygen
        ↓
2. Import key and generate secrets
   cd kubernetes/overlays/flux-instance/shangkuei-lab
   make import-age-key AGE_KEY_FILE=~/.config/sops/age/gitops-shangkuei-lab-flux.txt
   make setup
        ↓
3. Bootstrap: Terraform creates sops-age secret in cluster
   cd terraform/environments/gitops-shangkuei-lab
   terraform apply
        ↓
4. Commit encrypted secrets to Git
   git add secret-*.enc.yaml
   git commit -m "feat: add flux SOPS secrets for shangkuei-lab"
   git push
        ↓
5. Flux GitOps applies secrets automatically
   Flux syncs from Git repository
   kustomize-controller decrypts .enc.yaml files
   Secrets applied to flux-system namespace
```

## SOPS Secrets

### 1. Secret: sops-age

**File**: [secret-sops-age.enc.yaml](secret-sops-age.enc.yaml) (to be generated)

Contains the age encryption private key used by Flux to decrypt SOPS-encrypted manifests.

### 2. Secret: flux-system (Git Credentials)

**File**: [secret-flux-git-credentials.enc.yaml](secret-flux-git-credentials.enc.yaml) (to be generated)

Contains GitHub credentials (username and token) used by Flux to authenticate when cloning the Git repository.

## References

- [Flux SOPS Guide](https://fluxcd.io/flux/guides/mozilla-sops/)
- [Age Encryption](https://github.com/FiloSottile/age)
- [GitHub Token Permissions](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
