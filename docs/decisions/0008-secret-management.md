# 8. Secret Management Strategy

Date: 2025-10-19

## Status

Accepted

## Context

Following our GitOps workflow ([ADR-0007](0007-gitops-workflow.md)),
we need a secure approach to manage sensitive information across our infrastructure.
Our toolchain includes Terraform ([ADR-0002](0002-terraform-primary-tool.md)),
Ansible ([ADR-0003](0003-ansible-configuration-management.md)),
and GitHub Actions ([ADR-0006](0006-github-actions-cicd.md)),
each requiring different types of secrets:

- **Cloud credentials**: DigitalOcean API tokens and access keys
- **API keys**: Third-party service credentials (Cloudflare, monitoring, etc.)
- **Database passwords**: Application and admin database credentials
- **SSH keys**: Server and deployment access keys
- **TLS certificates**: SSL/TLS private keys
- **Encryption keys**: Data encryption and signing keys

For a small company, we need secret management that is:

- **Secure by default**: Secrets never stored in plaintext in Git
- **Cost-effective**: Free or low-cost solutions
- **Simple to use**: Easy for small teams to adopt
- **Multi-layered**: Different solutions for different contexts
- **Auditable**: Track secret access and usage

## Decision

We will use a **three-layer secret management approach** optimized for GitOps workflows:

1. **SOPS (Layer 1)**: For infrastructure secrets stored encrypted in Git
   - Terraform variables, Ansible configurations, Kubernetes manifests
   - Encrypted with age or PGP keys
   - Version controlled alongside code

2. **GitHub Secrets (Layer 2)**: For CI/CD pipeline credentials
   - Cloud provider API tokens
   - SOPS decryption keys
   - Service account credentials

3. **Kubernetes Secrets (Layer 3)**: For application runtime secrets
   - Populated from SOPS-encrypted manifests
   - Optional External Secrets Operator integration
   - Available to pods at runtime

## Consequences

### Positive

- **GitOps-friendly**: Encrypted secrets version controlled alongside code
- **Zero-cost**: All tools are free and open source
- **Simple workflow**: Three clear layers with distinct responsibilities
- **Defense in depth**: Multiple layers of secret protection
- **No vendor lock-in**: Works with any cloud provider
- **Audit trail**: Git history tracks secret changes, GitHub logs access
- **Developer-friendly**: Works with existing tools (Terraform, kubectl, Ansible)

### Negative

- **Key management**: SOPS age keys must be securely stored and rotated
- **Manual decryption**: CI/CD pipelines require explicit decryption steps
- **Learning curve**: Team must understand SOPS encryption workflow
- **Key exposure risk**: If SOPS key compromised, all encrypted files must be re-encrypted
- **Limited automation**: Secret rotation requires manual re-encryption

### Trade-offs

- **GitOps vs. Secret Security**: Secrets in Git (encrypted) vs. external secret stores
- **Simplicity vs. Features**: Simple three-layer approach vs. enterprise solutions (Vault)
- **Manual vs. Automated**: Manual decryption steps vs. fully automated pipelines
- **Cost vs. Complexity**: Zero cost with some operational overhead vs. paid managed services

## Alternatives Considered

### HashiCorp Vault

**Description**: Enterprise-grade secret management with dynamic secrets

**Whynot chosen**:

- Requires infrastructure to host Vault server
- Too complex for small company
- Free tier but requires management overhead
- Overkill for current scale

**Trade-offs**: Enterprise features vs. operational simplicity

**When to reconsider**: If team grows significantly or compliance requirements emerge

### Cloud Provider Secret Managers Only

**Description**: Use cloud-native secret managers (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager) exclusively

**Why not chosen**:

- DigitalOcean doesn't have a dedicated secret manager service
- Third-party secret managers cost money (AWS: $0.40/secret/month, Azure: $0.03/10k operations)
- Creates cloud vendor lock-in
- Doesn't work for hybrid/multi-cloud secrets
- CI/CD still needs GitHub Secrets

**Trade-offs**: Native integration vs. cost and vendor lock-in

**When to use**: Production-critical secrets, regulatory compliance (if we expand to AWS/Azure/GCP)

### Ansible Vault Only

**Description**: Use Ansible Vault for all encrypted secrets

**Why not chosen**:

- Ansible-only (doesn't work with Terraform, kubectl directly)
- Vault password management complexity
- Less flexible than SOPS for multi-tool workflows
- Doesn't support per-value encryption

**Trade-offs**: Simplicity vs. flexibility

**When to use**: Can be used alongside SOPS for Ansible-specific secrets if needed

## Implementation Notes

### Layer 1: SOPS (Infrastructure Secrets)

**Purpose**: Encrypt secrets that need to be version controlled alongside infrastructure code

**What to store**:

- Terraform variable files (sensitive values)
- Ansible variable files (application configs)
- Kubernetes Secret manifests
- Application configuration files
- Database connection strings
- API keys and tokens

**How to use**:

```bash
# Install SOPS and age
brew install sops age

# Generate age key pair
age-keygen -o ~/.config/sops/age/keys.txt

# Output:
# Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# (Save private key securely, add public key to .sops.yaml)

# Create .sops.yaml in repository root
cat <<EOF > .sops.yaml
creation_rules:
  # Encrypt files ending with .enc.yaml
  - path_regex: \.enc\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

  # Encrypt files in secrets/ directory
  - path_regex: secrets/.*\.enc\.(yaml|json)$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

  # Encrypt Terraform secret files
  - path_regex: terraform/.*/secrets\.enc\.json$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF

# Create encrypted Terraform variables
cat <<EOF > terraform/environments/production/secrets.enc.json
{
  "db_password": "super-secret-password",
  "api_key": "abc123xyz789"
}
EOF

# Encrypt the file
sops -e -i terraform/environments/production/secrets.enc.json

# File is now encrypted, safe to commit
git add terraform/environments/production/secrets.enc.json
git commit -m "Add encrypted production secrets"

# View encrypted file
sops terraform/environments/production/secrets.enc.json

# Use with Terraform
data "sops_file" "secrets" {
  source_file = "secrets.enc.json"
}

resource "digitalocean_database_cluster" "main" {
  name       = "production-db"
  # Use decrypted value
  # (requires terraform-provider-sops)
}

# Create encrypted Kubernetes secret
cat <<EOF > kubernetes/secrets/app.enc.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: production
type: Opaque
stringData:
  db-password: "super-secret"
  api-key: "abc123"
EOF

# Encrypt
sops -e -i kubernetes/secrets/app.enc.yaml

# Decrypt and apply
sops -d kubernetes/secrets/app.enc.yaml | kubectl apply -f -
```

**Best practices**:

- Store age private key in GitHub Secrets (SOPS_AGE_KEY)
- Never commit unencrypted secrets
- Use `.enc.yaml` or `.enc.json` suffix for encrypted files
- Add `.sops.yaml` to repository (contains public keys only)
- Encrypt files before first commit
- Rotate age keys quarterly
- Use multiple age keys for team access (comma-separated in .sops.yaml)
- Keep age private key backup in secure location (password manager)

### Layer 2: GitHub Secrets (CI/CD Credentials)

**Purpose**: Store credentials that GitHub Actions workflows need to access infrastructure

**What to store**:

- Cloud provider API tokens (DIGITALOCEAN_TOKEN)
- SOPS decryption keys (SOPS_AGE_KEY)
- Container registry credentials
- Terraform Cloud/Enterprise tokens
- SSH keys for deployment
- Service account credentials
- Third-party API tokens (monitoring, alerting)

**How to use**:

```bash
# Set secret via GitHub CLI
gh secret set DIGITALOCEAN_TOKEN

# Set SOPS age private key (from ~/.config/sops/age/keys.txt)
gh secret set SOPS_AGE_KEY < ~/.config/sops/age/keys.txt

# For DigitalOcean Spaces (S3-compatible storage)
gh secret set DIGITALOCEAN_SPACES_ACCESS_KEY_ID
gh secret set DIGITALOCEAN_SPACES_SECRET_ACCESS_KEY

# Use in GitHub Actions workflow
name: Deploy Infrastructure
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup SOPS
        env:
          SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
        run: |
          echo "$SOPS_AGE_KEY" > /tmp/age-key.txt
          export SOPS_AGE_KEY_FILE=/tmp/age-key.txt

      - name: Deploy with Terraform
        env:
          DIGITALOCEAN_TOKEN: ${{ secrets.DIGITALOCEAN_TOKEN }}
        run: |
          terraform init
          terraform apply -auto-approve

      - name: Deploy Kubernetes secrets
        run: |
          sops -d kubernetes/secrets/app.enc.yaml | kubectl apply -f -
```

**Best practices**:

- Use repository secrets for repo-specific credentials
- Use organization secrets for shared credentials
- Use environment secrets for environment-specific credentials (dev/staging/prod)
- Require environment protection rules for production
- Rotate secrets quarterly
- Never echo or log secret values in workflows
- Use `${{ secrets.SECRET_NAME }}` syntax (never hardcode)

### Layer 3: Kubernetes Secrets (Runtime Application Secrets)

**Purpose**: Manage application secrets in Kubernetes

**What to store**:

- Application database credentials
- API keys for microservices
- TLS certificates
- Service account tokens

**Primary Method: SOPS-encrypted manifests**

Secrets are stored encrypted in Git using SOPS and decrypted during deployment:

```yaml
# kubernetes/secrets/app.enc.yaml (encrypted in Git)
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: production
type: Opaque
stringData:
  db-password: ENC[AES256_GCM,data:xxxxx,type:str]
  api-key: ENC[AES256_GCM,data:yyyyy,type:str]
```

```bash
# Deploy from CI/CD pipeline
sops -d kubernetes/secrets/app.enc.yaml | kubectl apply -f -

# Or in GitHub Actions
- name: Deploy application secrets
  env:
    SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
  run: |
    export SOPS_AGE_KEY_FILE=<(echo "$SOPS_AGE_KEY")
    sops -d kubernetes/secrets/app.enc.yaml | kubectl apply -f -
```

**Alternative: External Secrets Operator** (optional, for advanced use cases)

For automated secret synchronization without manual decryption:

```yaml
# Install External Secrets Operator
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets --create-namespace

# Use SOPS as backend (experimental)
# Or use custom webhook to serve decrypted SOPS files
```

**Best practices**:

- Store secrets encrypted with SOPS in Git
- Decrypt only in CI/CD pipelines (never commit decrypted)
- Use namespace-based RBAC to limit secret access
- Enable audit logging for secret access in Kubernetes
- Rotate application secrets annually (or when compromised)
- Use separate SOPS files per namespace/environment
- Never log or echo secret values in pod logs

### Optional: HashiCorp Vault (Future Consideration)

**Purpose**: Centralized secret management with dynamic secrets and automated rotation

**When to consider**:

- Team grows beyond 10 people
- Compliance requirements (SOC2, ISO27001)
- Need for dynamic secrets (temporary database credentials)
- Automated secret rotation requirements
- Advanced audit and access control needs

**DigitalOcean Deployment**:

HashiCorp Vault can be deployed on DOKS (DigitalOcean Kubernetes):

```bash
# Deploy Vault on DOKS
helm install vault hashicorp/vault \
  --set server.ha.enabled=true \
  --set server.ha.replicas=3

# Integrate with External Secrets Operator
# (provides centralized management while maintaining GitOps workflow)
```

**Trade-offs**:

- **Benefits**: Dynamic secrets, automated rotation, centralized audit
- **Costs**: Infrastructure ($72-144/year), operational overhead, complexity
- **Recommendation**: Use three-layer approach first, add Vault only when needed

### Secret Rotation Strategy

**Quarterly rotation** (every 3 months):

- Cloud provider API tokens (DIGITALOCEAN_TOKEN)
- GitHub Personal Access Tokens
- SOPS age keys (generate new, re-encrypt all files)
- SSH keys for deployment

**Annual rotation** (every 12 months):

- Database passwords (coordinated with application)
- Service account keys
- Application API keys
- TLS certificates (or use automated renewal with cert-manager)

**Immediate rotation** (when compromised):

- Any secret suspected of being exposed
- SOPS age key exposure (re-encrypt all files immediately)
- Secrets from departed team members
- Secrets found in logs or error messages

**SOPS Key Rotation Procedure**:

1. Generate new age key: `age-keygen -o ~/.config/sops/age/keys-new.txt`
2. Add new public key to `.sops.yaml` (comma-separated with old key)
3. Re-encrypt all files with new key: `sops updatekeys file.enc.yaml`
4. Update GitHub Secret (SOPS_AGE_KEY) with new private key
5. Verify decryption works with new key
6. Remove old public key from `.sops.yaml`
7. Commit changes to Git

**General Secret Rotation Procedure**:

1. Generate new secret value
2. Encrypt with SOPS (for Layer 1 secrets)
3. Update GitHub Secrets (for Layer 2 credentials)
4. Deploy to Kubernetes (for Layer 3 runtime secrets)
5. Verify applications working with new secret
6. Remove old secret value
7. Update documentation and runbooks

### Security Best Practices

**Never**:

- Commit unencrypted secrets to Git
- Echo or log secret values in workflows or pod logs
- Share SOPS private keys via chat or email
- Reuse secrets across environments (dev/staging/prod)
- Store SOPS keys in repository (use GitHub Secrets)
- Commit `.sops.yaml` with private keys (public keys only)

**Always**:

- Encrypt secrets with SOPS before first commit
- Use `.enc.yaml` or `.enc.json` suffix for encrypted files
- Store SOPS age private key in GitHub Secrets
- Keep backup of SOPS key in secure location (password manager)
- Rotate SOPS age keys quarterly
- Use separate SOPS files per environment
- Audit secret access via Git history and GitHub Actions logs
- Enable MFA for GitHub account (protects GitHub Secrets access)

### Emergency Procedures

**If secret compromised**:

1. **Immediate**: Rotate the compromised secret immediately
   - SOPS key: Generate new age key, re-encrypt all files
   - GitHub Secret: Update via `gh secret set`
   - Kubernetes Secret: Update and redeploy pods

2. **Audit**: Check logs for unauthorized access
   - Git commit history for suspicious decryption
   - GitHub Actions logs for unusual workflow runs
   - Kubernetes audit logs for secret access

3. **Assess**: Determine scope of exposure
   - Which secrets were affected?
   - What systems had access?
   - Was data exfiltrated?

4. **Notify**: Inform team and stakeholders
   - Internal team notification
   - Security team escalation if needed
   - Customer notification if PII/data affected

5. **Prevent**: Update processes to prevent recurrence
   - Review access controls
   - Update rotation schedules
   - Implement additional monitoring

6. **Document**: Record incident and learnings
   - Create incident report
   - Update runbooks
   - Share lessons learned

**If SOPS age key compromised**:

1. Generate new age key immediately
2. Re-encrypt ALL encrypted files with new key
3. Update GitHub Secret (SOPS_AGE_KEY)
4. Revoke access for compromised key
5. Audit all Git commits for suspicious activity
6. Consider rotating all secrets encrypted with old key

## Directory Structure

```text
infrastructure/
├── .sops.yaml                  # SOPS configuration (public keys only, committed)
├── .gitignore                  # MUST exclude: *.key, *.pem, age-keys.txt
│
├── terraform/
│   └── environments/
│       ├── dev/
│       │   └── secrets.enc.json        # Encrypted Terraform variables
│       ├── staging/
│       │   └── secrets.enc.json        # Encrypted Terraform variables
│       └── production/
│           └── secrets.enc.json        # Encrypted Terraform variables
│
├── ansible/
│   └── group_vars/
│       ├── dev/
│       │   └── secrets.enc.yaml        # Encrypted Ansible variables
│       ├── staging/
│       │   └── secrets.enc.yaml        # Encrypted Ansible variables
│       └── production/
│           └── secrets.enc.yaml        # Encrypted Ansible variables
│
└── kubernetes/
    └── secrets/
        ├── dev/
        │   ├── app.enc.yaml            # Encrypted K8s Secret manifest
        │   └── database.enc.yaml       # Encrypted K8s Secret manifest
        ├── staging/
        │   ├── app.enc.yaml
        │   └── database.enc.yaml
        ├── production/
        │   ├── app.enc.yaml
        │   └── database.enc.yaml
        └── README.md                   # Secret documentation
```

**Important notes**:

- All `.enc.yaml` and `.enc.json` files are **encrypted** and safe to commit
- `.sops.yaml` contains **public keys only** (safe to commit)
- SOPS **private keys** stored in GitHub Secrets (SOPS_AGE_KEY)
- Local SOPS key at `~/.config/sops/age/keys.txt` (NEVER commit)

## Future Considerations

**When to adopt HashiCorp Vault**:

- Team grows beyond 10 people
- Regulatory compliance requirements (SOC2, ISO27001)
- Need for dynamic secrets (temporary database credentials)
- Automated secret rotation requirements
- Advanced audit and access control needs

**When to consider alternative approaches**:

- **GitOps limitations**: If encrypted secrets in Git become unwieldy
- **Compliance requirements**: If audit requirements exceed SOPS capabilities
- **Team size growth**: When team exceeds 20 people with complex access patterns
- **Multi-cloud expansion**: If expanding to AWS/Azure/GCP significantly

**Migration path from SOPS to Vault**:

1. Deploy Vault on DOKS cluster
2. Configure External Secrets Operator
3. Migrate secrets from SOPS files to Vault
4. Update CI/CD to use Vault instead of SOPS
5. Deprecate SOPS files (keep for rollback capability)

## References

- [SOPS (Secrets OPerationS)](https://github.com/getsops/sops)
- [age encryption tool](https://age-encryption.org/)
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Terraform SOPS Provider](https://registry.terraform.io/providers/carlpett/sops/latest/docs)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [External Secrets Operator](https://external-secrets.io/)
- [HashiCorp Vault](https://www.vaultproject.io/)
