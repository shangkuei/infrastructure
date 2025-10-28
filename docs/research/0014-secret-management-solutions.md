# Research: Secret Management Solutions

Date: 2025-10-18
Author: Infrastructure Team
Status: Completed

## Objective

Evaluate secret management solutions for storing and accessing sensitive credentials across infrastructure toolchain (Terraform, Ansible, Kubernetes, GitHub Actions).

## Scope

### In Scope

- SOPS (Secrets OPerationS) for Git-stored encrypted secrets
- GitHub Secrets for CI/CD pipeline credentials
- Kubernetes Secrets for runtime application secrets
- External Secrets Operator for secret synchronization
- Multi-layered approach for different contexts

### Out of Scope

- Application-level secret management
- Hardware security modules (HSMs)
- Enterprise secret platforms (CyberArk, Thycotic)

## Methodology

- Implemented each solution in test environments
- Measured integration complexity and operational overhead
- Evaluated cost for small companies
- Tested secret rotation and access control

## Findings

### Solution Comparison

| Solution | Cost | Complexity | Rotation | Integration | Best For |
|----------|------|------------|----------|-------------|----------|
| **SOPS** | Free | Low | Manual | Git, Terraform, Ansible | Git-stored secrets |
| **GitHub Secrets** | Free | Low | Manual | GitHub Actions | CI/CD |
| **K8s Secrets** | Free | Low | Manual | Kubernetes | Apps (basic) |
| **External Secrets Operator** | Free | Medium | Automated | K8s + external | Apps (advanced) |
| **HashiCorp Vault** | Free (OSS) | High | Automated | Universal | Enterprise |
| **AWS Secrets Manager** | $0.40/secret/month | Medium | Automated | AWS services | AWS-heavy |
| **Azure Key Vault** | $0.03/10k ops | Medium | Automated | Azure services | Azure-heavy |
| **GCP Secret Manager** | $0.06/secret/month | Medium | Automated | GCP services | GCP-heavy |

### 1. SOPS (Recommended for Git-Stored Secrets)

**Purpose**: Encrypt secrets in Git repository using age or PGP

**Example**:

```bash
# Install SOPS
brew install sops age

# Generate age key
age-keygen -o keys.txt

# Create .sops.yaml configuration
cat <<EOF > .sops.yaml
creation_rules:
  - path_regex: \.enc\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF

# Create encrypted file
sops secrets.enc.yaml

# Content (encrypted in Git)
# apiVersion: v1
# kind: Secret
# metadata:
#   name: app-secret
# stringData:
#   db-password: "super-secret"

# Decrypt and view
sops secrets.enc.yaml

# Use with Terraform
data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

# Use with kubectl
sops -d secrets.enc.yaml | kubectl apply -f -
```

**Pros**:

- ✅ Free, Git-friendly
- ✅ Simple encryption with age or PGP
- ✅ Works with Terraform, Ansible, kubectl
- ✅ Encrypted secrets committed to Git
- ✅ Per-file or per-value encryption
- ✅ Supports multiple key types (age, PGP, AWS KMS, GCP KMS, Azure Key Vault)

**Cons**:

- ❌ Requires key management
- ❌ Manual decryption in pipelines
- ❌ Key rotation requires re-encryption

**Cost**: $0

### 2. GitHub Secrets (Recommended for CI/CD)

**Purpose**: Store credentials for GitHub Actions workflows

**Example**:

```bash
# Set secret
gh secret set DIGITALOCEAN_TOKEN

# Use in workflow
name: Deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      DO_TOKEN: ${{ secrets.DIGITALOCEAN_TOKEN }}
    steps:
      - run: echo "Token is hidden in logs"
```

**Pros**:

- ✅ Free, unlimited secrets
- ✅ Zero setup
- ✅ Environment-specific secrets
- ✅ Encrypted at rest

**Cons**:

- ❌ GitHub Actions only
- ❌ Manual rotation
- ❌ No dynamic secrets

**Cost**: $0

### 3. Kubernetes Secrets + External Secrets Operator (Recommended for K8s)

**Native Secrets**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  db-password: "super-secret"
  api-key: "abc123"
```

**External Secrets Operator** (sync from external sources):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "my-app"

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
  target:
    name: app-secret
  data:
  - secretKey: db-password
    remoteRef:
      key: database
      property: password
```

**Pros**:

- ✅ Kubernetes-native
- ✅ ESO syncs from any source
- ✅ Automated refresh

**Cons**:

- ❌ Base64 only (not encrypted at rest without extra config)
- ❌ Requires external source for ESO

**Cost**: $0 (ESO is free)

### 4. SOPS + Kubernetes Integration

**Purpose**: Use SOPS-encrypted secrets with Kubernetes

**Example**:

```bash
# Create encrypted Kubernetes secret
sops secrets.enc.yaml

# Content (encrypted in Git):
# apiVersion: v1
# kind: Secret
# metadata:
#   name: app-secret
# stringData:
#   db-password: ENC[AES256_GCM,data:xxx,type:str]

# Decrypt and apply
sops -d secrets.enc.yaml | kubectl apply -f -

# Or use in CI/CD
- name: Deploy secrets
  run: |
    sops -d kubernetes/secrets/app.enc.yaml | kubectl apply -f -
```

**Pros**:

- ✅ Secrets stored in Git (encrypted)
- ✅ GitOps-friendly
- ✅ Version control for secrets
- ✅ Works with existing K8s tooling

**Cons**:

- ❌ Manual decryption step
- ❌ Key management required
- ❌ No automatic rotation

**Cost**: $0

### 5. HashiCorp Vault (Enterprise Grade)

**Architecture**: Self-hosted secret server with dynamic secrets

**Example**:

```bash
# Start Vault (dev mode)
vault server -dev

# Store secret
vault kv put secret/database password="super-secret"

# Read secret
vault kv get secret/database

# Dynamic database credentials (expires in 1h)
vault read database/creds/my-role
```

**Pros**:

- ✅ Dynamic secrets
- ✅ Automated rotation
- ✅ Audit logging
- ✅ Universal integration

**Cons**:

- ❌ Complex setup
- ❌ Operational overhead
- ❌ Requires infrastructure

**Cost**: Free (OSS) + infrastructure ($24/month for server)

### 5. Cloud Secret Managers

**AWS Secrets Manager**:

```bash
# Create secret
aws secretsmanager create-secret \
  --name myapp/database \
  --secret-string '{"password":"super-secret"}'

# Retrieve
aws secretsmanager get-secret-value --secret-id myapp/database
```

**Cost**: $0.40/secret/month + $0.05/10k API calls

**Not recommended for DigitalOcean-primary infrastructure** (cloud vendor lock-in)

## Analysis

### Three-Layer Approach (Recommended)

```
Layer 1: SOPS → Infrastructure secrets (Terraform, Ansible, configs)
         ↓
Layer 2: GitHub Secrets → CI/CD pipeline credentials & SOPS keys
         ↓
Layer 3: Kubernetes Secrets → Runtime application secrets
```

**Rationale**:

- **Layer 1 (SOPS)**: GitOps-friendly encrypted secrets in repository
  - Terraform variables, Ansible vars, Kubernetes manifests
  - Version controlled with encryption
  - Works with existing tooling

- **Layer 2 (GitHub Secrets)**: Pipeline-specific credentials
  - Cloud provider tokens (DIGITALOCEAN_TOKEN)
  - SOPS decryption keys (AGE_PRIVATE_KEY)
  - Service account credentials
  - Never stored in Git

- **Layer 3 (Kubernetes Secrets)**: Application runtime secrets
  - Populated from SOPS-encrypted manifests
  - Managed by External Secrets Operator (optional)
  - Available to pods at runtime

**Benefits**:

- Defense in depth with three distinct layers
- Cost-effective ($0 for small teams)
- GitOps-compatible workflow
- Right tool for each context
- No vendor lock-in

### Total Cost of Ownership (Annual)

| Approach | Software | Infrastructure | Operations | **Total** |
|----------|----------|----------------|------------|-----------|
| **Three-layer (SOPS)** | $0 | $0 | $50 | **$50** |
| **Vault-only** | $0 | $288 | $500 | **$788** |
| **AWS Secrets** | $48 | $0 | $50 | **$98** |

\*Based on 10 secrets, 1000 retrievals/month

**Three-layer approach is most cost-effective for small companies**

## Recommendations

### Recommended: Three-Layer Approach

**Implementation**:

1. **Layer 1: SOPS** (Infrastructure secrets):

```bash
# Install SOPS and age
brew install sops age

# Generate age key pair
age-keygen -o ~/.config/sops/age/keys.txt

# Extract public key
grep "# public key:" ~/.config/sops/age/keys.txt

# Create .sops.yaml in repository root
cat <<EOF > .sops.yaml
creation_rules:
  - path_regex: \.enc\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - path_regex: secrets/.*\.enc\.json$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF

# Create encrypted Terraform variables
sops terraform/environments/production/secrets.enc.json

# Create encrypted Kubernetes secrets
sops kubernetes/secrets/app.enc.yaml

# Commit encrypted files to Git
git add .sops.yaml terraform/environments/production/secrets.enc.json
git commit -m "Add encrypted secrets with SOPS"
```

2. **Layer 2: GitHub Secrets** (CI/CD credentials):

```bash
# Store cloud provider token
gh secret set DIGITALOCEAN_TOKEN

# Store SOPS decryption key (from ~/.config/sops/age/keys.txt)
gh secret set SOPS_AGE_KEY

# Store Spaces credentials
gh secret set DIGITALOCEAN_SPACES_ACCESS_KEY_ID
gh secret set DIGITALOCEAN_SPACES_SECRET_ACCESS_KEY

# Use in GitHub Actions workflow
- name: Decrypt secrets
  env:
    SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
  run: |
    echo "$SOPS_AGE_KEY" > /tmp/age-key.txt
    export SOPS_AGE_KEY_FILE=/tmp/age-key.txt
    sops -d secrets.enc.yaml | kubectl apply -f -
```

3. **Layer 3: Kubernetes Secrets** (Runtime secrets):

```bash
# Decrypt SOPS file and apply to cluster
sops -d kubernetes/secrets/app.enc.yaml | kubectl apply -f -

# Or use External Secrets Operator for automation
helm install external-secrets \
  external-secrets/external-secrets -n external-secrets

# Configure ESO to sync from SOPS files in Git
# (requires webhook or custom operator)
```

### When to Add Vault

**Triggers**:

- Team > 10 people
- Compliance requirements (SOC2, ISO27001)
- Need dynamic secrets
- Automated rotation required

### Rotation Strategy

**Quarterly** (every 3 months):

- Cloud provider access keys
- GitHub tokens
- SOPS age keys (generate new, re-encrypt)

**Annual** (every 12 months):

- Database passwords
- TLS certificates (or use auto-renewal)
- Application API keys

**Immediate**:

- Suspected compromises
- Team member departures
- SOPS key exposure (re-encrypt all files)

## Action Items

1. **Immediate**:
   - [ ] Install SOPS and age
   - [ ] Generate age key pair
   - [ ] Create .sops.yaml configuration
   - [ ] Set up GitHub Secrets (DIGITALOCEAN_TOKEN, SOPS_AGE_KEY)
   - [ ] Add .gitignore for .sops.yaml (public keys only in repo)

2. **Short-term** (1-3 months):
   - [ ] Encrypt Terraform variables with SOPS
   - [ ] Encrypt Kubernetes secrets with SOPS
   - [ ] Update CI/CD pipelines to decrypt SOPS files
   - [ ] Create runbook for SOPS key rotation
   - [ ] Implement secret rotation procedures

3. **Long-term** (6-12 months):
   - [ ] Deploy External Secrets Operator (optional)
   - [ ] Evaluate Vault for production (if needed)
   - [ ] Automated rotation scripts
   - [ ] Secret scanning in CI/CD (detect unencrypted secrets)

## Follow-up Research Needed

1. **Secret Scanning**: Tools to detect secrets in Git (GitGuardian, TruffleHog, gitleaks)
2. **SOPS Best Practices**: Key rotation automation, multi-key encryption
3. **External Secrets Operator**: Integration patterns with SOPS-encrypted Git repos

## References

- [SOPS (Secrets OPerationS)](https://github.com/getsops/sops)
- [age encryption](https://age-encryption.org/)
- [GitHub Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [External Secrets Operator](https://external-secrets.io/)
- [Terraform SOPS Provider](https://registry.terraform.io/providers/carlpett/sops/latest/docs)

## Outcome

This research led to **[ADR-0008: Secret Management Strategy](../decisions/0008-secret-management.md)**,
which adopted a three-layer approach using SOPS for infrastructure secrets, GitHub Secrets
for CI/CD credentials, and Kubernetes Secrets for runtime application secrets.
