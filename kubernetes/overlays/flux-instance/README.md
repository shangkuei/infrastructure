# SOPS Secrets for Flux Instance (GitOps-Managed)

This directory contains SOPS-encrypted secrets that are managed via Flux GitOps. The secrets are encrypted with age and can be safely committed to Git.

**Important**: Only the `data`, `stringData`, or `string` sections of Kubernetes secrets are encrypted. The metadata, kind, and apiVersion fields remain in plaintext, as required by kustomize-controller.

## ✅ GitOps Integration

- **SOPS-encrypted secrets** are safe to commit to Git
- **Flux kustomize-controller** automatically decrypts using the `sops-age` secret
- **Secrets managed via Kustomize** overlay for cluster-specific configuration
- **Referenced by**: `kubernetes/clusters/gitops/flux-instance-sops/kustomization.yaml`

## Directory Structure

```
kubernetes/
├── overlays/flux-instance/
│   ├── Makefile                               # Secret generation helper (reference)
│   ├── README.md                              # This file
│   └── shangkuei-xyz-talos/                   # Cluster-specific SOPS overlay
│       ├── .gitignore                         # Ignore decrypted files
│       ├── .sops.yaml                         # SOPS config (generated locally, NOT in Git)
│       ├── Makefile                           # Secret generation helper
│       ├── README.md                          # Cluster-specific documentation
│       ├── secret-sops-age.yaml.enc          # SOPS age secret (ENCRYPTED, in Git)
│       └── secret-flux-git-credentials.yaml.enc  # Git credentials (ENCRYPTED, in Git)
│
└── clusters/shangkuei-xyz-talos/
    ├── kustomization.yaml                     # Main cluster configuration
    ├── kustomization-flux-instance.yaml       # Flux Kustomization CR
    └── flux-instance-sops/
        └── kustomization.yaml                 # References ../../../overlays/flux-instance/shangkuei-xyz-talos/*.enc
```

**Key Points**:

- The cluster's `flux-instance-sops/kustomization.yaml` references individual `.enc` files from the overlay
- It also includes the base flux-instance and patches the FluxInstance to enable SOPS decryption
- The `.sops.yaml` file is generated locally and should NOT be committed to Git
- Only `.enc` files are committed to Git

**Implementation Pattern**:

This directory contains cluster-specific overlays for SOPS-encrypted Flux secrets. For actual cluster deployments:

1. **Create cluster-specific overlay**: Create a subdirectory (e.g., `shangkuei-xyz-talos/`)
2. **Generate secrets**: Use the Makefile in the cluster overlay to generate `.enc` files with your age key
3. **Reference from cluster**: Create a cluster-specific `flux-instance-sops/kustomization.yaml` that references the `.enc` files
4. **Bootstrap manually**: Create the `sops-age` secret in the cluster using `kubectl`
5. **GitOps takes over**: Flux will then manage all future secret updates via Git

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
- `.sops.yaml` - SOPS configuration with age public key and `encrypted_regex` setting (generated locally, DO NOT commit)
- `secret-sops-age.yaml.enc` - SOPS-encrypted age secret with only `stringData` encrypted (safe to commit)
- `secret-flux-git-credentials.yaml.enc` - SOPS-encrypted Git credentials with only `stringData` encrypted (safe to commit)
- `*.decrypted` - Plaintext secrets (DO NOT commit to Git)

**Encryption Scope**: Only the `data` or `stringData` sections are encrypted. Kubernetes metadata, kind, and apiVersion remain in plaintext to ensure compatibility with kustomize-controller.

**Generated `.sops.yaml` Configuration**:

```yaml
creation_rules:
  - path_regex: .*\.(enc|decrypted|yaml|yml)$
    encrypted_regex: '^(data|stringData)$'  # Only encrypt data/stringData sections
    age: <your-age-public-key>
```

This configuration ensures that SOPS automatically encrypts only the `data` and `stringData` sections without needing to specify the `--encrypted-regex` flag in each command.

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
│    • Only encrypts data/stringData sections                │
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

**GitOps-Managed Secret**: Encrypted with SOPS, safe to commit to Git

Contains the age encryption private key used by Flux to decrypt SOPS-encrypted manifests in the Git repository.

**Encryption Details**: Only the `stringData` section containing the age key is encrypted. The secret metadata (name, namespace), kind, and apiVersion remain in plaintext for kustomize-controller compatibility.

**Why this secret is special**:

- FluxInstance needs this secret to decrypt other encrypted manifests
- Must be bootstrapped manually (chicken-and-egg: can't decrypt itself)
- After bootstrap, this encrypted version serves as backup/documentation
- Contains sensitive key material encrypted with SOPS

**How it's used**:

```yaml
# In cluster flux-instance-sops/kustomization.yaml:
# Patches FluxInstance to enable SOPS decryption for flux-system Kustomization
patches:
  - patch: |-
      - op: add
        path: /spec/kustomize/patches
        value:
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
    target:
      kind: FluxInstance
      name: flux
```

**Source Data**:

- Generated from: Age private key file (`age-key.txt`)
- Created by: `age-keygen` command
- Encrypted with: SOPS using the same age public key
- Applied by: Flux kustomize-controller after manual bootstrap

### 2. Secret: flux-system (Git Credentials)

**File**: [secret-flux-git-credentials.yaml.enc](secret-flux-git-credentials.yaml.enc)

**GitOps-Managed Secret**: Encrypted with SOPS, safe to commit to Git

Contains GitHub credentials (username and token) used by Flux to authenticate when cloning the Git
repository.

**Encryption Details**: Only the `stringData` section containing username and password is encrypted.
The secret metadata (name, namespace), kind, and apiVersion remain in plaintext for
kustomize-controller compatibility.

**Why this secret is GitOps-managed**:

- FluxInstance needs this secret to access the Git repository
- SOPS-encrypted so it can be safely stored in Git
- Decrypted automatically by Flux kustomize-controller
- Easy to rotate by re-encrypting and committing new version

**How it's used**:

```yaml
# FluxInstance references it in sync configuration:
spec:
  sync:
    kind: GitRepository
    url: https://github.com/owner/repo
    pullSecret: flux-system
```

**Source Data**:

- GitHub username and Personal Access Token (PAT)
- Token permissions: Read access to repository (repo scope)
- Encrypted with: SOPS using age public key
- Can be rotated: Re-encrypt and commit updated version

## FluxInstance Integration

```
┌─────────────────────────────────────────────────────────────┐
│ INITIAL BOOTSTRAP (One-Time Manual)                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Manually create sops-age secret (namespace: flux-system)│
│      kubectl create secret generic sops-age \                │
│        --from-file=age.agekey=age-key.txt                   │
│      └─ Required for Flux to decrypt SOPS manifests        │
│                                                              │
│  2. Install Flux Operator and create FluxInstance          │
│      ├─ References: sops-age secret for decryption         │
│      ├─ References: flux-system secret for Git auth        │
│      └─ Starts Flux CD components                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ FLUX CD CONTINUOUS DEPLOYMENT (GitOps)                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  • Flux syncs manifests from Git repository                 │
│  • kustomize-controller decrypts .enc files using sops-age  │
│  • Encrypted secrets applied to cluster                     │
│  • GitOps manages all cluster resources automatically       │
│  • No manual kubectl commands needed after bootstrap        │
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

# 4. Commit encrypted secrets to Git
git add secret-*.yaml.enc
git commit -m "feat: rotate SOPS age key"
git push

# 5. Manually update sops-age secret in cluster
kubectl delete secret sops-age -n flux-system
kubectl create secret generic sops-age \
  --from-file=age.agekey=new-age-key.txt \
  --namespace flux-system

# 6. Restart kustomize-controller to reload secret
kubectl rollout restart deployment kustomize-controller -n flux-system
```

### Updating Git Credentials

If you need to rotate the GitHub token:

```bash
# 1. Create new GitHub token with repository access

# 2. Re-generate encrypted secret with new token
make secret-flux-git
# (Will prompt for new username and token)

# 3. Commit encrypted secret to Git
git add secret-flux-git-credentials.yaml.enc
git commit -m "feat: rotate GitHub token"
git push

# 4. Wait for Flux to sync (or force reconciliation)
flux reconcile kustomization flux-instance

# 5. Restart source-controller to reload secret
kubectl rollout restart deployment source-controller -n flux-system
```

## Security Considerations

1. **Never commit unencrypted secrets to Git**
   - Age private keys (`age-key.txt`) are in `.gitignore`
   - Only SOPS-encrypted `.enc` files are committed
   - Plaintext `.decrypted` files are in `.gitignore`
   - Actual decryption happens in-cluster by Flux

2. **Protect the age private key**
   - Store age key securely (password manager, hardware token)
   - Never commit `age-key.txt` to Git
   - Backup key in secure offline location
   - Limit access to key file

3. **Rotate credentials regularly**
   - GitHub tokens: Every 90 days
   - SOPS age keys: Annually or after exposure
   - Document rotation procedures
   - Test rotation in non-production first

4. **Monitor secret usage**
   - Audit logs for secret access in cluster
   - Monitor Flux reconciliation for decryption failures
   - Alert on unauthorized access attempts
   - Track secret lifecycle and rotation dates

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
