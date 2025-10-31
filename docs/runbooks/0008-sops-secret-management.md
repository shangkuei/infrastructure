# Runbook: SOPS Secret Management Operations

## Overview

This runbook covers operational procedures for managing secrets using SOPS (Secrets OPerationS)
with age encryption. SOPS provides GitOps-friendly secret management by encrypting secrets in
the repository while keeping them version-controlled.

**Decision Reference**: [ADR-0008: Secret Management Strategy](../decisions/0008-secret-management.md)

**Three-Layer Architecture**:

- **Layer 1**: SOPS - Infrastructure secrets (Terraform, Ansible, Kubernetes manifests)
- **Layer 2**: GitHub Secrets - CI/CD pipeline credentials and SOPS decryption keys
- **Layer 3**: Kubernetes Secrets - Runtime application secrets (populated from SOPS)

## Prerequisites

### Required Tools

```bash
# Install SOPS
brew install sops

# Or download from: https://github.com/getsops/sops/releases

# Install age encryption tool
brew install age

# Or download from: https://age-encryption.org/
```

### Required Access

- Repository write access
- GitHub repository admin access (for setting secrets)
- Kubernetes cluster access (for deploying secrets)

### Verify Installation

```bash
# Check SOPS version
sops --version
# Expected: sops 3.8.0 or later

# Check age version
age --version
# Expected: v1.1.0 or later
```

## Initial Setup

### Step 1: Generate Per-Environment Age Key Pairs

**⚠️ SECURITY STRATEGY**: Separate keys for each environment provides security isolation

Benefits of per-environment keys:

- **Principle of least privilege**: Developers can access homelab keys but not production
- **Blast radius reduction**: Compromised homelab key doesn't expose production secrets
- **Flexible rotation**: Rotate production keys quarterly, homelab keys annually

```bash
# Create SOPS config directory
mkdir -p ~/.config/sops/age

# Generate homelab-unraid environment key
age-keygen -o ~/.config/sops/age/homelab-unraid-key.txt
# Output:
# Public key: age1homelab_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# (Save this public key for .sops.yaml)

# Generate production environment key
age-keygen -o ~/.config/sops/age/prod-key.txt
# Output:
# Public key: age1prod_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# (Save this public key for .sops.yaml)
```

**Important**:

- The **public keys** (starts with `age1...`) will be added to `.sops.yaml`
- The **private keys** (entire files) must be stored in GitHub Secrets separately
- Keep **backups** of both private keys in your password manager
- Label keys clearly: "Infrastructure - Homelab Key" and "Infrastructure - Production Key"

### Step 2: Configure SOPS

```bash
# Navigate to repository root
cd /path/to/infrastructure

# Extract public keys for use
HOMELAB_PUBLIC_KEY=$(grep "# public key:" ~/.config/sops/age/homelab-unraid-key.txt | cut -d: -f2 | tr -d ' ')
PROD_PUBLIC_KEY=$(grep "# public key:" ~/.config/sops/age/prod-key.txt | cut -d: -f2 | tr -d ' ')

# Replace placeholders in .sops.yaml
sed -i '' "s/age1HOMELAB_KEY_PLACEHOLDER_REPLACE_WITH_HOMELAB_AGE_PUBLIC_KEY_XXXXXXXXXXXXXXX/$HOMELAB_PUBLIC_KEY/g" .sops.yaml
sed -i '' "s/age1PROD_KEY_PLACEHOLDER_REPLACE_WITH_PRODUCTION_AGE_PUBLIC_KEY_XXXXXXXXXXXXXXX/$PROD_PUBLIC_KEY/g" .sops.yaml

# Verify replacement
grep "age1" .sops.yaml | grep -v PLACEHOLDER
# Should show your actual public keys (not PLACEHOLDER)
```

### Step 3: Store Private Keys in GitHub Secrets

**⚠️ IMPORTANT**: Store each environment key in a separate GitHub Secret

```bash
# Store homelab-unraid key
gh secret set SOPS_AGE_KEY_HOMELAB_UNRAID < ~/.config/sops/age/homelab-unraid-key.txt

# Store production key
gh secret set SOPS_AGE_KEY_PROD < ~/.config/sops/age/prod-key.txt

# Verify secrets were set
gh secret list | grep SOPS_AGE_KEY
# Should show:
# SOPS_AGE_KEY_HOMELAB_UNRAID  Updated YYYY-MM-DD
# SOPS_AGE_KEY_PROD            Updated YYYY-MM-DD
```

**Alternative**: Manually via GitHub web interface:

1. Go to repository Settings → Secrets and variables → Actions
2. Create two secrets:
   - Name: `SOPS_AGE_KEY_HOMELAB_UNRAID`, Value: Contents of `homelab-unraid-key.txt`
   - Name: `SOPS_AGE_KEY_PROD`, Value: Contents of `prod-key.txt`

### Step 4: Backup Private Keys

**⚠️ CRITICAL**: Store both private keys in secure location with clear labels

```bash
# Option 1: Copy to password manager (RECOMMENDED)
echo "=== Homelab-Unraid Key ==="
cat ~/.config/sops/age/homelab-unraid-key.txt

echo "=== Production Key ==="
cat ~/.config/sops/age/prod-key.txt
# Copy each output to password manager with descriptive names

# Option 2: Encrypted backup to secure storage
# (Ensure this location is NOT in the Git repository)
mkdir -p ~/secure-backup/infrastructure-keys-$(date +%Y%m%d)
cp ~/.config/sops/age/homelab-unraid-key.txt ~/secure-backup/infrastructure-keys-$(date +%Y%m%d)/
cp ~/.config/sops/age/prod-key.txt ~/secure-backup/infrastructure-keys-$(date +%Y%m%d)/
```

### Step 5: Commit Configuration

```bash
# Stage .sops.yaml (contains public key only - safe to commit)
git add .sops.yaml

# Commit
git commit -m "feat(security): configure SOPS secret management

- Add .sops.yaml with age encryption configuration
- Configure encryption rules for Terraform, Ansible, Kubernetes
- See ADR-0008 for secret management strategy"

# Push
git push origin main
```

## Daily Operations

### Creating Encrypted Secrets

#### Terraform Secrets

```bash
# Navigate to environment directory
cd terraform/environments/prod

# Create secrets file (will be encrypted)
cat > secrets.enc.json <<EOF
{
  "do_token": "dop_v1_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "cloudflare_api_token": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "tailscale_auth_key": "tskey-auth-xxxxxxxxxxxxxxxxxxxxx"
}
EOF

# Encrypt the file
sops -e -i secrets.enc.json

# File is now encrypted and safe to commit
git add secrets.enc.json
git commit -m "feat(terraform): add encrypted production secrets"
git push
```

#### Ansible Secrets

```bash
# Create ansible group_vars directory if needed
mkdir -p ansible/group_vars/production

# Create secrets file
sops ansible/group_vars/production/secrets.enc.yaml

# Editor will open - add your secrets in YAML format:
# db_password: "super-secret-password"
# api_key: "abc123xyz789"
# Save and exit - file is automatically encrypted

# Commit encrypted file
git add ansible/group_vars/production/secrets.enc.yaml
git commit -m "feat(ansible): add encrypted production secrets"
git push
```

#### Kubernetes Secrets

```bash
# Create kubernetes secrets directory
mkdir -p kubernetes/secrets/production

# Create Kubernetes Secret manifest
cat > kubernetes/secrets/production/app.enc.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: production
type: Opaque
stringData:
  db-password: "super-secret-password"
  api-key: "abc123xyz789"
  redis-password: "redis-secret"
EOF

# Encrypt
sops -e -i kubernetes/secrets/production/app.enc.yaml

# Commit
git add kubernetes/secrets/production/app.enc.yaml
git commit -m "feat(k8s): add encrypted production app secrets"
git push
```

### Viewing Encrypted Secrets

```bash
# View (decrypt in-place, does not modify file)
sops terraform/environments/prod/secrets.enc.json

# View with YAML output format
sops -d terraform/environments/prod/secrets.enc.json | jq .

# Extract specific value
sops -d --extract '["do_token"]' terraform/environments/prod/secrets.enc.json
```

### Editing Encrypted Secrets

```bash
# Edit encrypted file (automatically decrypts, opens editor, re-encrypts)
sops terraform/environments/prod/secrets.enc.json

# Edit with specific editor
EDITOR=vim sops ansible/group_vars/production/secrets.enc.yaml
```

### Decrypting for Deployment

```bash
# Decrypt and output to stdout
sops -d kubernetes/secrets/production/app.enc.yaml

# Decrypt and apply to Kubernetes
sops -d kubernetes/secrets/production/app.enc.yaml | kubectl apply -f -

# Decrypt and save to file (NOT recommended - file is unencrypted)
sops -d secrets.enc.yaml > secrets-decrypted.yaml  # ⚠️ Danger: unencrypted file
```

## Working with Per-Environment Keys

### Using Environment-Specific Keys Locally

```bash
# Set environment variable to use specific key
export SOPS_AGE_KEY_FILE=~/.config/sops/age/homelab-unraid-key.txt

# Decrypt homelab secrets
sops terraform/environments/homelab-unraid/secrets.enc.json

# Switch to production key
export SOPS_AGE_KEY_FILE=~/.config/sops/age/prod-key.txt

# Decrypt production secrets
sops terraform/environments/prod/secrets.enc.json

# Add to shell profile for convenience
echo 'alias sops-homelab="SOPS_AGE_KEY_FILE=~/.config/sops/age/homelab-unraid-key.txt sops"' >> ~/.zshrc
echo 'alias sops-prod="SOPS_AGE_KEY_FILE=~/.config/sops/age/prod-key.txt sops"' >> ~/.zshrc
source ~/.zshrc

# Usage with aliases
sops-homelab terraform/environments/homelab-unraid/secrets.enc.json
sops-prod terraform/environments/prod/secrets.enc.json
```

### Access Control Strategy

**Homelab-Unraid Key** (Development/Testing):

- All team members have access
- Stored in personal password managers
- Can be shared with new developers
- Rotated annually

**Production Key** (Production Environment):

- Restricted to senior engineers and ops team
- Stored in team-shared secure vault
- Requires approval for access
- Rotated quarterly

## CI/CD Integration

### GitHub Actions Workflow with Per-Environment Keys

```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]
    paths:
      - 'terraform/environments/**'
      - '.github/workflows/**'

jobs:
  deploy-homelab:
    name: Deploy Homelab-Unraid Environment
    runs-on: ubuntu-latest
    if: contains(github.event.head_commit.modified, 'homelab-unraid')
    steps:
      - uses: actions/checkout@v4

      - name: Install SOPS
        run: |
          curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
          chmod +x sops-v3.8.1.linux.amd64
          sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops

      - name: Setup SOPS Homelab Key
        env:
          SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY_HOMELAB_UNRAID }}
        run: |
          mkdir -p ~/.config/sops/age
          echo "$SOPS_AGE_KEY" > ~/.config/sops/age/keys.txt
          chmod 600 ~/.config/sops/age/keys.txt

      - name: Deploy Terraform Homelab
        env:
          DIGITALOCEAN_TOKEN: ${{ secrets.DIGITALOCEAN_TOKEN }}
        run: |
          cd terraform/environments/homelab-unraid
          terraform init
          terraform plan
          # terraform apply -auto-approve  # Uncomment for auto-deploy

  deploy-production:
    name: Deploy Production Environment
    runs-on: ubuntu-latest
    if: contains(github.event.head_commit.modified, 'prod')
    environment: production  # Requires manual approval
    steps:
      - uses: actions/checkout@v4

      - name: Install SOPS
        run: |
          curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
          chmod +x sops-v3.8.1.linux.amd64
          sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops

      - name: Setup SOPS Production Key
        env:
          SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY_PROD }}
        run: |
          mkdir -p ~/.config/sops/age
          echo "$SOPS_AGE_KEY" > ~/.config/sops/age/keys.txt
          chmod 600 ~/.config/sops/age/keys.txt

      - name: Deploy Terraform Production
        env:
          DIGITALOCEAN_TOKEN: ${{ secrets.DIGITALOCEAN_TOKEN }}
        run: |
          cd terraform/environments/prod
          terraform init
          terraform plan -out=tfplan

      - name: Deploy Kubernetes Secrets
        run: |
          sops -d kubernetes/secrets/production/app.enc.yaml | kubectl apply -f -
```

### Terraform Integration

Using terraform-provider-sops:

```hcl
# Configure SOPS provider
terraform {
  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
  }
}

# Read encrypted secrets
data "sops_file" "secrets" {
  source_file = "secrets.enc.json"
}

# Use decrypted values
resource "digitalocean_kubernetes_cluster" "main" {
  name   = "production"
  region = "nyc3"
  # Access decrypted value
  # token = data.sops_file.secrets.data["do_token"]
}
```

## Key Rotation

### Rotation Schedule

**Production Key**: Rotate every 3 months (quarterly)
**Homelab-Unraid Key**: Rotate every 12 months (annually)

### Production Key Rotation (Quarterly)

```bash
# 1. Generate new production key
age-keygen -o ~/.config/sops/age/prod-key-new.txt

# 2. Extract new public key
PROD_NEW_KEY=$(grep "# public key:" ~/.config/sops/age/prod-key-new.txt | cut -d: -f2 | tr -d ' ')
echo "New production public key: $PROD_NEW_KEY"

# 3. Edit .sops.yaml and add new key alongside old key (comma-separated)
# Find production rules and update to include both keys temporarily:
# Before:
#   age: age1OLDPRODKEY...
# After:
#   age: >-
#     age1OLDPRODKEY...,
#     age1NEWPRODKEY...

# 4. Re-encrypt ONLY production files with both keys
find terraform/environments/prod -name "*.enc.*" | while read file; do
  echo "Re-encrypting $file"
  sops updatekeys -y "$file"
done

find ansible/group_vars/production -name "*.enc.*" 2>/dev/null | while read file; do
  sops updatekeys -y "$file"
done

find kubernetes/secrets/production -name "*.enc.*" 2>/dev/null | while read file; do
  sops updatekeys -y "$file"
done

# 5. Verify decryption with new production key
SOPS_AGE_KEY_FILE=~/.config/sops/age/prod-key-new.txt \
  sops terraform/environments/prod/secrets.enc.json
# Should decrypt successfully

# 6. Update GitHub Secret with new production key
gh secret set SOPS_AGE_KEY_PROD < ~/.config/sops/age/prod-key-new.txt

# 7. Test production deployment in CI/CD
# Trigger a test workflow to verify new key works

# 8. Remove OLD production key from .sops.yaml
# Edit .sops.yaml and remove old production public key (keep only new)

# 9. Commit changes
git add .sops.yaml
git commit -m "chore(security): rotate production SOPS age encryption key

- Generate new production age key pair (Q1 2025)
- Re-encrypt all production secrets with new key
- Update GitHub Secret SOPS_AGE_KEY_PROD
- Remove old production key from configuration"
git push

# 10. Backup new production key
cat ~/.config/sops/age/prod-key-new.txt
# Store in password manager as "Infrastructure - Production Key (2025-Q1)"

# 11. Replace old production key file
mv ~/.config/sops/age/prod-key-new.txt ~/.config/sops/age/prod-key.txt

# 12. Securely delete old production key
rm -P ~/.config/sops/age/prod-key-old.txt  # If backed up
```

### Homelab-Unraid Key Rotation (Annually)

```bash
# 1. Generate new homelab key
age-keygen -o ~/.config/sops/age/homelab-unraid-key-new.txt

# 2. Extract new public key
HOMELAB_NEW_KEY=$(grep "# public key:" ~/.config/sops/age/homelab-unraid-key-new.txt | cut -d: -f2 | tr -d ' ')

# 3. Update .sops.yaml with both keys temporarily
# Add new key alongside old homelab key

# 4. Re-encrypt ONLY homelab files
find terraform/environments/homelab-unraid -name "*.enc.*" | while read file; do
  sops updatekeys -y "$file"
done

find ansible/group_vars/{dev,homelab} -name "*.enc.*" 2>/dev/null | while read file; do
  sops updatekeys -y "$file"
done

# 5. Verify with new key
SOPS_AGE_KEY_FILE=~/.config/sops/age/homelab-unraid-key-new.txt \
  sops terraform/environments/homelab-unraid/secrets.enc.json

# 6. Update GitHub Secret
gh secret set SOPS_AGE_KEY_HOMELAB_UNRAID < ~/.config/sops/age/homelab-unraid-key-new.txt

# 7. Remove old homelab key from .sops.yaml

# 8. Commit and backup
git add .sops.yaml
git commit -m "chore(security): rotate homelab SOPS age encryption key (annual rotation 2025)"
git push

# 9. Store new key in password manager
cat ~/.config/sops/age/homelab-unraid-key-new.txt

# 10. Replace key file
mv ~/.config/sops/age/homelab-unraid-key-new.txt ~/.config/sops/age/homelab-unraid-key.txt
```

## Emergency Procedures

### Scenario 1: Age Key Compromised

**Impact**: Unauthorized access to all encrypted secrets

**Immediate Actions**:

```bash
# 1. Generate new age key immediately
age-keygen -o ~/.config/sops/age/keys-emergency.txt

# 2. Extract new public key
NEW_KEY=$(grep "# public key:" ~/.config/sops/age/keys-emergency.txt | cut -d: -f2 | tr -d ' ')

# 3. Update .sops.yaml with ONLY new key (remove old compromised key)
sed -i '' "s/age: age1.*/age: $NEW_KEY/" .sops.yaml

# 4. Re-encrypt ALL secret files immediately
find . -name "*.enc.yaml" -o -name "*.enc.json" | while read file; do
  sops updatekeys -y "$file"
done

# 5. Update GitHub Secret immediately
gh secret set SOPS_AGE_KEY < ~/.config/sops/age/keys-emergency.txt

# 6. Audit Git history for suspicious commits
git log --all --source --full-history -- "*.enc.*"

# 7. Consider rotating ALL application secrets
# (Database passwords, API keys, etc.)

# 8. Notify team and stakeholders
# Document incident in incident-YYYYMMDD.md

# 9. Review and update access controls
```

### Scenario 2: Cannot Decrypt Files

**Symptoms**: `error decrypting key: no key could decrypt`

**Troubleshooting**:

```bash
# Check age key file exists
ls -la ~/.config/sops/age/keys.txt

# Verify public key in .sops.yaml matches your private key
age-keygen -y ~/.config/sops/age/keys.txt
# Compare output with public key in .sops.yaml

# Check SOPS can find the key
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops --version

# Try decrypting with explicit key
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops -d secrets.enc.yaml

# Verify file was encrypted with your key
sops metadata secrets.enc.yaml
# Check "age" section contains your public key
```

### Scenario 3: Accidentally Committed Unencrypted Secret

**Impact**: Secret exposed in Git history

**Immediate Actions**:

```bash
# 1. Rotate the exposed secret immediately
# (Change password, regenerate API token, etc.)

# 2. Remove file from Git history using BFG Repo-Cleaner
# Download from: https://rpo.github.io/bfg-repo-cleaner/
java -jar bfg.jar --delete-files unencrypted-secret.yaml

# Or use git filter-repo
git filter-repo --path unencrypted-secret.yaml --invert-paths

# 3. Force push (⚠️ WARNING: Rewrites history)
git push origin --force --all

# 4. Notify all team members to re-clone repository

# 5. Create encrypted version
sops secrets.enc.yaml
# Add secret in encrypted form

# 6. Document incident
```

## Troubleshooting

### Common Issues

#### Issue: "no key could decrypt the data key"

**Cause**: Private key doesn't match encrypted file

**Solution**:

```bash
# Verify your age key fingerprint
age-keygen -y ~/.config/sops/age/keys.txt

# Check file metadata
sops metadata secrets.enc.yaml

# Re-encrypt with correct key
sops updatekeys secrets.enc.yaml
```

#### Issue: "failed to get the data key required to decrypt the SOPS file"

**Cause**: SOPS cannot find age key file

**Solution**:

```bash
# Set explicit key file path
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# Or set in shell profile
echo 'export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt' >> ~/.zshrc
source ~/.zshrc
```

#### Issue: CI/CD cannot decrypt files

**Cause**: GitHub Secret not set or incorrect

**Solution**:

```bash
# Verify GitHub Secret exists
gh secret list | grep SOPS_AGE_KEY

# Re-set secret
gh secret set SOPS_AGE_KEY < ~/.config/sops/age/keys.txt

# Check workflow permissions in .github/workflows/
```

### Verification Commands

```bash
# Test encryption/decryption cycle
echo "test: secret" | sops -e /dev/stdin | sops -d /dev/stdin

# List all encrypted files in repository
find . -name "*.enc.yaml" -o -name "*.enc.json"

# Verify all encrypted files can be decrypted
for file in $(find . -name "*.enc.yaml" -o -name "*.enc.json"); do
  echo "Testing: $file"
  sops -d "$file" > /dev/null && echo "✅ OK" || echo "❌ FAIL"
done
```

## Best Practices

### Security

- ✅ Always encrypt secrets before first commit
- ✅ Use `.enc.yaml` or `.enc.json` suffix for encrypted files
- ✅ Store age private key in GitHub Secrets and password manager
- ✅ Rotate age keys quarterly
- ✅ Use separate SOPS files per environment (dev/staging/prod)
- ❌ Never commit unencrypted secrets to Git
- ❌ Never echo or log secret values in CI/CD workflows
- ❌ Never share age private keys via chat or email

### Operational

- Keep backup of age private key in secure location
- Document key rotation dates
- Test decryption after key rotation
- Audit encrypted file access via Git history
- Enable MFA for GitHub account (protects GitHub Secrets)

### Development

- Use `sops <file>` to edit encrypted files (safer than manual decrypt/encrypt)
- Verify encryption before committing: `sops metadata <file>`
- Use `.enc.*` suffix to clearly identify encrypted files
- Add comments in SOPS files for context (not encrypted by default)

## Directory Structure

```text
infrastructure/
├── .sops.yaml                          # SOPS configuration (committed)
├── .gitignore                          # Excludes age private keys
│
├── terraform/
│   └── environments/
│       ├── homelab-unraid/
│       │   └── secrets.enc.json        # ✅ Encrypted, safe to commit
│       └── prod/
│           └── secrets.enc.json        # ✅ Encrypted, safe to commit
│
├── ansible/
│   └── group_vars/
│       ├── dev/
│       │   └── secrets.enc.yaml        # ✅ Encrypted, safe to commit
│       └── production/
│           └── secrets.enc.yaml        # ✅ Encrypted, safe to commit
│
└── kubernetes/
    └── secrets/
        ├── dev/
        │   └── app.enc.yaml            # ✅ Encrypted, safe to commit
        └── production/
            └── app.enc.yaml            # ✅ Encrypted, safe to commit
```

## References

- [SOPS Documentation](https://github.com/getsops/sops)
- [age Encryption](https://age-encryption.org/)
- [ADR-0008: Secret Management Strategy](../decisions/0008-secret-management.md)
- [Research: Secret Management Solutions](../research/0014-secret-management-solutions.md)
- [Terraform SOPS Provider](https://registry.terraform.io/providers/carlpett/sops/latest/docs)
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

## Related Runbooks

- [0001: Cloudflare Operations](0001-cloudflare-operations.md) - May involve API token secrets
- [0003: Disaster Recovery](0003-disaster-recovery.md) - Backup and restore procedures
- [0006: DigitalOcean Operations](0006-digitalocean-operations.md) - API token management
