# SOPS Secrets for Flux Instance (GitOps-Managed)

This directory contains SOPS-encrypted secrets that are managed via Flux GitOps. The secrets are encrypted with age and can be safely committed to Git.

## ✅ GitOps Integration

- **SOPS-encrypted secrets** are safe to commit to Git
- **Flux kustomize-controller** automatically decrypts using the `sops-age` secret
- **Secrets managed via Kustomize** overlay for the shangkuei-xyz-talos cluster
- **Referenced by**: `kubernetes/clusters/shangkuei-xyz-talos/kustomization-flux-instance.yaml`

## Quick Start

Generate encrypted secrets using the provided Makefile:

```bash
# Show available commands
make help

# Step 1: Import existing age key and generate .sops.yaml
make import-age-key AGE_KEY_FILE=/path/to/your/age-key.txt

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

- Age encryption key file (generate with: `age-keygen -o age-key.txt`)

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

### Bootstrap Requirement

**IMPORTANT**: Before Flux can decrypt these secrets, you must manually create the `sops-age` secret containing the age private key:

```bash
# One-time bootstrap step
kubectl create secret generic sops-age \
  --from-file=age.agekey=age-key.txt \
  --namespace flux-system
```

This is a chicken-and-egg situation: Flux needs the age key to decrypt the SOPS secrets, but the age key itself cannot be SOPS-encrypted.

## SOPS Secrets

### 1. Secret: sops-age

**File**: [secret-sops-age.yaml.enc](secret-sops-age.yaml.enc)

**GitOps Managed**: Yes (SOPS-encrypted)

Contains the age encryption private key used by Flux to decrypt SOPS-encrypted manifests in the Git repository.

**Bootstrap Requirement**:

- Must be manually created ONCE via `kubectl` before Flux can use it
- After bootstrap, this encrypted version serves as backup/reference
- The actual decryption key is stored in the manually created secret

**How it's used**:

```yaml
# FluxInstance patches flux-system Kustomization:
spec:
  kustomize:
    patches:
      - patch: |
          - op: add
            path: /spec/decryption
            value:
              provider: sops
              secretRef:
                name: sops-age
        target:
          kind: Kustomization
          name: flux-system
```

**Terraform Source**:

- Variable: `sops_age_key_path`
- Points to: Local age private key file
- Generated by: `age-keygen` during environment setup

### 2. Secret: flux-system (Git Credentials)

**File**: [secret-flux-git-credentials.yaml.enc](secret-flux-git-credentials.yaml.enc)

**GitOps Managed**: Yes (SOPS-encrypted, applied via Kustomize)

Contains GitHub credentials (username and token) used by Flux to authenticate when cloning the Git repository.

**Why GitOps manages it**:

- SOPS encryption makes it safe to store in Git
- Flux kustomize-controller decrypts using the sops-age key
- Changes can be tracked via Git history
- No manual kubectl operations needed after bootstrap

**How it's used**:

```yaml
# FluxInstance references it in sync configuration:
spec:
  sync:
    kind: GitRepository
    url: https://github.com/owner/repo
    pullSecret: flux-system
```

**Terraform Source**:

- Variable: `github_token`
- Contains: GitHub Personal Access Token or App token
- Permissions: Read access to repository

## FluxInstance Integration

```
┌─────────────────────────────────────────────────────────────┐
│ BOOTSTRAP (ONE-TIME MANUAL STEP)                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Create SOPS age secret manually via kubectl             │
│      └─ kubectl create secret generic sops-age \            │
│         --from-file=age.agekey=age-key.txt \                │
│         --namespace flux-system                             │
│      └─ Required for Flux to decrypt SOPS secrets           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ GITOPS DEPLOYMENT (AUTOMATIC)                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Flux syncs manifests from Git repository                │
│      └─ Reads kustomization-flux-instance.yaml              │
│                                                              │
│  2. kustomize-controller processes overlay                  │
│      ├─ Reads overlays/flux-instance/shangkuei-xyz-talos-   │
│      │   sops/kustomization.yaml                            │
│      ├─ Decrypts secret-sops-age.yaml.enc                   │
│      ├─ Decrypts secret-flux-git-credentials.yaml.enc       │
│      └─ Applies decrypted secrets to flux-system namespace  │
│                                                              │
│  3. FluxInstance uses secrets                               │
│      ├─ References: sops-age secret (for manifest decrypt)  │
│      ├─ References: flux-system credentials (for Git auth)  │
│      └─ Starts Flux CD components                           │
│                                                              │
│  4. Ongoing GitOps operations                               │
│      ├─ All secret updates via SOPS-encrypted Git commits   │
│      ├─ Automatic decryption and application                │
│      └─ Full Git history and audit trail                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Updating SOPS Secrets

### Updating SOPS Key

If you need to rotate the SOPS age key:

```bash
# 1. Generate new age key
age-keygen -o new-age-key.txt

# 2. Import new key and update .sops.yaml
make import-age-key AGE_KEY_FILE=new-age-key.txt

# 3. Re-generate encrypted secrets with new key
make secret-sops-age
make secret-flux-git

# 4. Update the bootstrap secret in cluster
kubectl delete secret sops-age -n flux-system
kubectl create secret generic sops-age \
  --from-file=age.agekey=new-age-key.txt \
  --namespace flux-system

# 5. Commit encrypted secrets to Git
git add secret-*.yaml.enc
git commit -m "chore(security): rotate SOPS age key"
git push

# 6. Restart kustomize-controller to reload secret
kubectl rollout restart deployment kustomize-controller -n flux-system
```

### Updating Git Credentials

If you need to rotate the GitHub token:

```bash
# 1. Create new GitHub token with repository access

# 2. Re-generate the encrypted secret
make secret-flux-git

# 3. Commit to Git
git add secret-flux-git-credentials.yaml.enc
git commit -m "chore(security): rotate GitHub token"
git push

# 4. Wait for Flux to sync (or force reconciliation)
flux reconcile kustomization flux-instance -n flux-system

# 5. Restart source-controller to reload secret
kubectl rollout restart deployment source-controller -n flux-system
```

## Security Considerations

1. **Never commit secrets to Git**
   - SOPS keys are in `.gitignore`
   - Terraform variables are SOPS-encrypted
   - Actual secrets only in cluster

2. **Restrict access to Terraform state**
   - State contains sensitive data
   - Use encrypted backend (S3, GCS, etc.)
   - Limit access to state files

3. **Rotate credentials regularly**
   - GitHub tokens: Every 90 days
   - SOPS keys: Annually or after exposure
   - Use automation for rotation

4. **Monitor secret usage**
   - Audit logs for secret access
   - Alert on unauthorized access
   - Track secret lifecycle

## Troubleshooting

### Flux Can't Decrypt Manifests

**Symptom**: `decryption failed` errors in kustomize-controller logs

**Solution**:

```bash
# Verify secret exists
kubectl get secret sops-age -n flux-system

# Verify secret content (should show age.agekey key)
kubectl get secret sops-age -n flux-system -o jsonpath='{.data}'

# Check kustomize-controller can read secret
kubectl logs -n flux-system -l app=kustomize-controller | grep sops
```

### Flux Can't Clone Repository

**Symptom**: `authentication failed` errors in source-controller logs

**Solution**:

```bash
# Verify secret exists
kubectl get secret flux-system -n flux-system

# Verify secret type
kubectl get secret flux-system -n flux-system -o jsonpath='{.type}'
# Should be: Opaque

# Check source-controller logs
kubectl logs -n flux-system -l app=source-controller | grep authentication
```

## References

- [Flux SOPS Guide](https://fluxcd.io/flux/guides/mozilla-sops/)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Age Encryption](https://github.com/FiloSottile/age)
- [GitHub Token Permissions](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
