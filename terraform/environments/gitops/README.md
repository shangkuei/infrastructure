# Talos GitOps Terraform Environment

This Terraform environment bootstraps Flux CD on the Talos Kubernetes cluster using the **Flux Operator** for GitOps-based continuous delivery.

> **📍 Part 2 of 2**: This environment enables GitOps on an **existing running cluster** provisioned by [`talos-cluster/`](../talos-cluster/).
>
> **Prerequisites**: Complete [`talos-cluster/`](../talos-cluster/) deployment first. Cluster must be running and healthy.
>
> See [Terraform Environments Overview](../README.md) for complete deployment workflow.

## Overview

This environment uses the `gitops` module to deploy Flux CD with a modern operator-based approach:

1. **cert-manager**: Certificate management for webhooks (Helm)
2. **Flux Operator**: Manages Flux installation via FluxInstance CRD (Helm)
3. **FluxInstance**: Declarative Flux configuration with SOPS integration

**Architecture Benefits**:

- ✅ Declarative Flux management via FluxInstance CRD
- ✅ Helm-based operator installation (simple, reliable)
- ✅ Native SOPS integration for encrypted manifests
- ✅ GitOps workflow with automatic reconciliation
- ✅ Reusable module architecture

**Managed Namespaces**:

- `cert-manager`: Certificate management
- `flux-system`: Flux Operator and controllers
- `kube-system`: Core system components (managed by Flux)
- `kube-addons`: Cluster addons (managed by Flux)

## Component Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| cert-manager | v1.19.1 | TLS certificate management for webhooks |
| Flux Operator | 0.33.0 | Flux installation and management |
| Flux | v2.7.3 | GitOps controllers |

## cert-manager Configuration

cert-manager is configured with the following enhanced features:

### DNS01 Challenge Configuration

- **Recursive DNS Nameservers**: Custom DNS resolvers for DNS01 ACME challenges
  - Supports both standard DNS (`<ip>:<port>`) and DNS-over-HTTPS (DoH) formats
  - Default: `1.1.1.1:53,8.8.8.8:53` (Cloudflare and Google DNS)
  - Example DoH: `https://1.1.1.1/dns-query,https://8.8.8.8/dns-query`

- **Recursive Nameservers Only**: Forces all DNS01 checks through configured resolvers
  - Useful in DNS-constrained environments with restricted authoritative nameserver access
  - May increase DNS01 self-check time due to recursive DNS caching
  - Default: `true`

### Additional Features

- **Certificate Owner Reference**: Automatically removes secrets when certificate resources are deleted
  - Enables proper garbage collection of TLS secrets
  - Default: `true`

- **Gateway API Support**: Enables integration with Kubernetes Gateway API
  - Requires cert-manager v1.15+ with `ExperimentalGatewayAPISupport` feature gate
  - Configured via both feature gate and `--enable-gateway-api` CLI flag
  - Allows certificate management for Gateway API resources
  - Default: `true`

### Customizing DNS Configuration

To use different DNS resolvers, update `terraform.tfvars`:

```hcl
# Use custom DNS servers
cert_manager_dns01_recursive_nameservers = "9.9.9.9:53,149.112.112.112:53"  # Quad9

# Or use DNS-over-HTTPS
cert_manager_dns01_recursive_nameservers = "https://cloudflare-dns.com/dns-query,https://dns.google/dns-query"

# Allow queries to authoritative nameservers
cert_manager_dns01_recursive_nameservers_only = false
```

## Prerequisites

### 1. Kubernetes Cluster

Ensure you have a running Kubernetes cluster and kubectl configured:

```bash
kubectl cluster-info
kubectl get nodes
```

### 2. Kubernetes Credentials

Extract credentials from your cluster for Terraform provider authentication:

```bash
# Get cluster API endpoint
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'

# Get authentication token (Kubernetes 1.24+)
# Step 1: Create service account
kubectl create serviceaccount gitops-admin -n kube-system

# Step 2: Create cluster role binding
kubectl create clusterrolebinding gitops-admin --clusterrole=cluster-admin --serviceaccount=kube-system:gitops-admin

# Step 3: Create secret for long-lived token (required in K8s 1.24+)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitops-admin-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: gitops-admin
type: kubernetes.io/service-account-token
EOF

# Step 4: Wait for token to be generated and retrieve it
kubectl get secret gitops-admin-token -n kube-system -o jsonpath='{.data.token}' | base64 -d

# Get cluster CA certificate (base64 encoded)
kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
```

Store these credentials securely in environment variables or a password manager.

### 3. GitHub Personal Access Token

Create a GitHub personal access token with `repo` permissions:

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select scopes: `repo` (Full control of private repositories)
4. Generate and save the token securely

### 4. Required Tools

Install required CLI tools:

```bash
# Flux CLI (for verification)
brew install fluxcd/tap/flux

# SOPS (for secret management)
brew install sops

# age (for encryption)
brew install age

# jq (for JSON parsing)
brew install jq
```

## Secret Management with SOPS

This environment uses [SOPS](https://github.com/getsops/sops) with age encryption for secure secret management.

### Age Key Setup

This environment uses **two separate age keys** for different purposes:

1. **Terraform Key** (`gitops.txt`): For encrypting local Terraform files (terraform.tfvars, backend.hcl)
2. **Flux Key** (`gitops-flux.txt`): For encrypting Kubernetes manifests in Git (deployed to Kubernetes as a secret)

```bash
# Generate both age keys
make age-keygen

# This creates:
# Terraform Key (for local Terraform file encryption)
# - ~/.config/sops/age/gitops.txt (private key)
# - ~/.config/sops/age/gitops.txt.pub (public key)
#
# Flux Key (for Kubernetes manifest encryption in Git)
# - ~/.config/sops/age/gitops-flux.txt (private key)
# - ~/.config/sops/age/gitops-flux.txt.pub (public key)
```

**⚠️ Important**: The private keys must be stored securely:

- Keys are stored centrally in `~/.config/sops/age/`
- Backup both private keys to password manager
- **Flux key**: Store in GitHub Secrets for CI/CD: `gh secret set SOPS_AGE_KEY < ~/.config/sops/age/gitops-flux.txt`
- **Flux key**: Will be deployed to Kubernetes by Terraform as `sops-age` secret
- Never commit private keys to Git

**Key Information**: View both keys: `make age-info`

## Setup Instructions

### Step 1: Generate Age Keys for SOPS

```bash
cd terraform/environments/gitops

# Generate both age keys (Terraform + Flux)
make age-keygen

# View key information (including public keys for .sops.yaml)
make age-info

# Backup both keys to your password manager
cat ~/.config/sops/age/gitops.txt       # Terraform key
cat ~/.config/sops/age/gitops-flux.txt  # Flux key
```

### Step 2: Configure Variables

Copy the example variables file and set your credentials:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# Kubernetes Credentials (from prerequisites step)
kubernetes_host                   = "https://api.cluster.example.com:6443"
kubernetes_token                  = "your-service-account-token"
kubernetes_cluster_ca_certificate = "LS0tLS1CRUdJTi..."  # base64 encoded

# GitHub Configuration
github_owner      = "your-username"
github_repository = "infrastructure"
github_token      = "ghp_your_github_token_here"
github_branch     = "main"

# Cluster Configuration
cluster_name = "gitops"
cluster_path = "./kubernetes/clusters/gitops"

# Flux Configuration
flux_namespace      = "flux-system"
flux_network_policy = true

# SOPS Configuration (Flux key - deployed to Kubernetes)
sops_age_key_path = "~/.config/sops/age/gitops-flux.txt"

# Component Versions (optional, defaults provided)
cert_manager_version  = "v1.19.1"
flux_operator_version = "0.33.0"
flux_version         = "v2.7.3"

# cert-manager DNS and Feature Configuration (optional, defaults provided)
cert_manager_dns01_recursive_nameservers       = ["1.1.1.1:53", "8.8.8.8:53"]
cert_manager_dns01_recursive_nameservers_only  = true
cert_manager_enable_certificate_owner_ref      = true
cert_manager_enable_gateway_api                = true
```

**Alternatively**, use environment variables instead of storing in `terraform.tfvars`:

```bash
export TF_VAR_kubernetes_host="https://api.cluster.example.com:6443"
export TF_VAR_kubernetes_token="your-token"
export TF_VAR_kubernetes_cluster_ca_certificate="your-ca-cert"
export TF_VAR_github_token="your-github-token"
```

### Step 3: Initialize Terraform

```bash
# Using Makefile
make init

# Or directly
terraform init
```

### Step 4: Review the Plan

```bash
# Using Makefile
make plan

# Or directly
terraform plan
```

Review the resources that will be created:

- **cert-manager**: Helm release with CRDs and custom DNS configuration
- **Flux Operator**: Helm release from `ghcr.io/controlplaneio-fluxcd/charts/flux-operator`
- **SOPS Age Secret**: For decrypting manifests
- **FluxInstance**: Declarative Flux configuration with Git sync
- **Git Credentials**: Secret for GitHub authentication

### Step 5: Apply the Configuration

```bash
# Using Makefile
make apply

# Or directly
terraform apply
```

The module-based approach handles all dependencies automatically - no phased deployment required.

## Verification

### Check Component Installation

```bash
# Check cert-manager
kubectl -n cert-manager get pods
kubectl get crd | grep cert-manager

# Check Flux Operator pods
kubectl -n flux-system get pods -l app.kubernetes.io/name=flux-operator

# Verify FluxInstance CRD is available
kubectl get crd fluxinstances.fluxcd.controlplane.io
```

### Check FluxInstance Status

```bash
# Get FluxInstance status
kubectl -n flux-system get fluxinstance flux

# Detailed status with conditions
kubectl -n flux-system get fluxinstance flux -o jsonpath='{.status.conditions}' | jq

# Full FluxInstance spec
kubectl -n flux-system get fluxinstance flux -o yaml
```

Expected output:

```
NAME   AGE   READY   STATUS
flux   2m    True    Flux installation is ready
```

### Check Flux Controllers

The FluxInstance should deploy the following controllers:

```bash
# Check all Flux pods
kubectl -n flux-system get pods

# Expected pods:
# - flux-operator-*
# - source-controller-*
# - kustomize-controller-*
# - helm-controller-*
# - notification-controller-*
```

### Check GitRepository Sync

```bash
# View GitRepository status
kubectl -n flux-system get gitrepository

# Expected output:
# NAME         URL                                    AGE   READY   STATUS
# flux-system  https://github.com/user/repo           2m    True    stored artifact for revision 'main@sha1:...'
```

### Check Kustomizations

```bash
# View all Kustomizations
kubectl -n flux-system get kustomization

# Check specific Kustomizations
kubectl -n flux-system get kustomization kube-system -o yaml
kubectl -n flux-system get kustomization kube-addons -o yaml
```

### View Flux Logs

```bash
# All Flux controller logs
kubectl -n flux-system logs -l app.kubernetes.io/part-of=flux --tail=100 -f

# Source controller logs
kubectl -n flux-system logs -l app=source-controller --tail=100 -f

# Kustomize controller logs
kubectl -n flux-system logs -l app=kustomize-controller --tail=100 -f

# Flux Operator logs
kubectl -n flux-system logs -l app.kubernetes.io/name=flux-operator --tail=100 -f
```

## GitOps Workflow

Once Flux is installed, all changes to Kubernetes manifests should be made via Git:

### 1. Create Feature Branch

```bash
git checkout -b feature/add-monitoring
```

### 2. Add/Modify Manifests

```bash
# Add manifests to base directories
mkdir -p kubernetes/base/kube-addons/monitoring
# Create your manifests...
```

### 3. Test Locally (Optional)

```bash
# Dry-run validation
kubectl apply --dry-run=server -k kubernetes/base/kube-addons/monitoring/

# Or use kustomize
kustomize build kubernetes/base/kube-addons/ | kubectl apply --dry-run=server -f -
```

### 4. Commit and Push

```bash
git add kubernetes/
git commit -m "feat(monitoring): add Prometheus stack"
git push origin feature/add-monitoring
```

### 5. Create Pull Request

```bash
gh pr create --title "Add monitoring stack" --body "Adds Prometheus and Grafana"
```

### 6. Merge and Deploy

After PR approval and merge to `main`:

- Flux detects the change within 5 minutes (configurable)
- Flux automatically reconciles the cluster state
- Resources are created/updated in the cluster

### 7. Monitor Deployment

```bash
# Watch Flux reconciliation
kubectl -n flux-system get kustomization -w

# Check for errors
kubectl -n flux-system logs -l app=kustomize-controller --tail=50

# Force immediate reconciliation (optional)
flux reconcile kustomization kube-addons --with-source
```

## FluxInstance Configuration

The FluxInstance CRD provides declarative configuration for Flux:

### Key Features

**SOPS Integration**:

- SOPS age key secret (`sops-age`) created in `flux-system` namespace
- Decryption configured per-Kustomization via `spec.decryption.secretRef`
- Supports encrypted secrets in Git repository
- **See**: [Using SOPS with Flux](#using-sops-encrypted-secrets)

**Git Sync**:

- Monitors GitHub repository via GitRepository CRD
- Automatic reconciliation every 5 minutes
- HTTPS authentication with GitHub token

**Component Management**:

- Core controllers: source, kustomize, helm, notification
- Optional components via `flux_components_extra` variable
- Network policies enabled by default

### Customizing FluxInstance

To customize the FluxInstance, modify variables in [variables.tf](variables.tf):

```hcl
# Add extra components
flux_components_extra = [
  "image-reflector-controller",   # For image scanning
  "image-automation-controller"   # For automated image updates
]

# Adjust reconciliation interval in main.tf:
# spec.sync.interval = "1m"  # Check every minute instead of 5m
```

## Using SOPS Encrypted Secrets

This environment includes SOPS integration for encrypting secrets in Git. The `sops-age` secret is automatically created during Terraform apply.

### How It Works

**Modern Flux SOPS Approach**:

1. **Secret Created**: Terraform creates `sops-age` secret in `flux-system` namespace
2. **Kustomization References Secret**: Each Kustomization specifies `decryption.secretRef`
3. **Flux Decrypts**: kustomize-controller decrypts SOPS-encrypted files before applying

**Reference**: [Flux SOPS Guide](https://fluxcd.io/flux/guides/mozilla-sops/)

### Creating Encrypted Secrets

**Step 1: Create `.sops.yaml` in your repository root**

```yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Replace with your **Flux age public key** from: `cat ~/.config/sops/age/gitops-flux.txt.pub`

**Important**: Use the **Flux key** for Kubernetes manifests, not the Terraform key.

**Step 2: Create a secret file**

```yaml
# kubernetes/clusters/gitops/secrets/database-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: production
type: Opaque
stringData:
  username: postgres
  password: super-secret-password
```

**Step 3: Encrypt with SOPS**

```bash
sops --encrypt --in-place kubernetes/clusters/gitops/secrets/database-credentials.yaml
```

**Step 4: Create Kustomization with SOPS decryption**

```yaml
# kubernetes/clusters/gitops/secrets-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: secrets
  namespace: flux-system
spec:
  interval: 10m
  path: ./kubernetes/clusters/gitops/secrets
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

**Step 5: Commit and push**

```bash
git add .sops.yaml kubernetes/
git commit -m "feat(secrets): add encrypted database credentials"
git push
```

Flux will automatically decrypt and apply the secret.

### Verifying SOPS Decryption

```bash
# Check if secret was created
kubectl -n production get secret database-credentials

# View kustomize-controller logs for decryption
kubectl -n flux-system logs -l app=kustomize-controller | grep -i sops

# Check Kustomization status
kubectl -n flux-system get kustomization secrets -o yaml
```

### SOPS Best Practices

**Security**:

- ✅ Store encrypted files in Git
- ✅ Keep private keys in `~/.config/sops/age/` (never commit to Git)
- ✅ Use different age keys per environment
- ✅ Rotate keys periodically

**Organization**:

- ✅ Use separate directories for encrypted secrets
- ✅ Create dedicated Kustomizations for secrets
- ✅ Document which secrets are encrypted in README

**Key Management**:

- ✅ Backup age keys securely (password manager, vault)
- ✅ Store in CI/CD as secrets for automation
- ✅ Use key rotation when team members change

## Troubleshooting

### FluxInstance not ready

**Problem**: FluxInstance shows `READY=False`

```bash
# Check FluxInstance status
kubectl -n flux-system describe fluxinstance flux

# Check operator logs
kubectl -n flux-system logs -l app.kubernetes.io/name=flux-operator --tail=100
```

**Solution**: Check operator logs for specific error messages

### Flux controllers not starting

**Problem**: Flux controller pods not running

```bash
# Check pod status
kubectl -n flux-system get pods

# Check pod events
kubectl -n flux-system describe pod <pod-name>

# Check Flux Operator logs
kubectl -n flux-system logs -l app.kubernetes.io/name=flux-operator
```

**Solution**: Verify FluxInstance configuration and check for resource constraints

### GitRepository not syncing

**Problem**: GitRepository shows as not ready

```bash
# Check GitRepository status
kubectl -n flux-system describe gitrepository flux-system

# Common issues:
# - GitHub token invalid or expired
# - Repository URL incorrect
# - Network connectivity issues
```

**Solution**: Verify GitHub credentials secret and repository URL

### SOPS decryption failing

**Problem**: Encrypted manifests not being decrypted

```bash
# Check if SOPS secret exists
kubectl -n flux-system get secret sops-age

# Check controller logs for decryption errors
kubectl -n flux-system logs -l app=kustomize-controller | grep -i sops
```

**Solution**: Verify age key is correctly mounted and matches encryption key

### Kustomization failing

**Problem**: Kustomization shows reconciliation errors

```bash
# Check Kustomization status
kubectl -n flux-system describe kustomization kube-system

# View detailed error messages
kubectl -n flux-system logs -l app=kustomize-controller --tail=100
```

**Solution**: Fix manifest errors and push corrected files to Git

### Resource not appearing

**Problem**: Resources not created in cluster despite being in Git

```bash
# Check if Kustomization includes the resource
kubectl -n flux-system get kustomization <name> -o yaml | grep path

# Verify kustomization.yaml includes the resource
cat kubernetes/base/kube-system/kustomization.yaml
```

**Solution**: Ensure resource is listed in `kustomization.yaml` resources section

### Manual changes being reverted

**Problem**: Manual kubectl changes are reverted by Flux

**Explanation**: This is expected behavior! Flux enforces Git as the single source of truth.

**Solution**: Make all changes via Git commits to maintain GitOps workflow

### Force reconciliation

If you need immediate deployment without waiting for the sync interval:

```bash
# Reconcile GitRepository (fetch latest commits)
flux reconcile source git flux-system

# Reconcile specific Kustomization
flux reconcile kustomization kube-system --with-source
flux reconcile kustomization kube-addons --with-source
```

## Upgrading Components

### Upgrading Flux

To upgrade Flux version:

```hcl
# In terraform.tfvars or variables
flux_version = "v2.8.0"  # New version
```

Then apply:

```bash
terraform apply
```

The Flux Operator will handle the rolling update of controllers.

### Upgrading Flux Operator

To upgrade the Flux Operator:

```hcl
flux_operator_version = "0.34.0"  # New version
```

```bash
terraform apply
```

Helm will handle the upgrade, performing a rolling update.

### Upgrading cert-manager

```hcl
cert_manager_version = "v1.19.1"  # New version
```

```bash
terraform apply
```

## Disaster Recovery

To rebuild the cluster from scratch:

### 1. Provision Infrastructure

```bash
# Use Terraform to provision cluster
cd terraform/environments/talos-cluster
terraform apply
```

### 2. Bootstrap Flux

```bash
# Apply this Flux bootstrap environment
cd terraform/environments/gitops
terraform apply
```

### 3. Wait for Reconciliation

Flux will automatically:

1. Fetch manifests from Git
2. Apply kube-system resources
3. Apply kube-addons resources (after kube-system is ready)
4. Bring cluster to desired state

```bash
# Monitor reconciliation
kubectl -n flux-system get kustomization -w
```

## Uninstallation

To remove Flux and related components from the cluster:

```bash
# Remove Terraform resources
terraform destroy
```

This will remove:

- FluxInstance (Flux controllers will be cleaned up)
- Flux Operator
- cert-manager
- All related secrets and namespaces

**Warning**: This will stop GitOps reconciliation. Manual kubectl commands will be needed for deployments.

## Secret Management

### Encrypted Files

This environment uses SOPS encryption for all sensitive data:

- `terraform.tfvars.enc` - Encrypted Terraform variables (GitHub token, etc.)
- `backend.hcl.enc` - Encrypted backend configuration (R2 credentials)
- `.sops.yaml` - SOPS configuration with age public key

### Editing Encrypted Files

```bash
# Edit terraform.tfvars.enc (auto-decrypts, opens editor, re-encrypts)
sops terraform.tfvars.enc

# View decrypted content (doesn't modify file)
sops -d terraform.tfvars.enc

# Extract specific value
sops -d --extract '["github_token"]' terraform.tfvars.enc
```

### Key Rotation

When rotating the age key for this environment:

```bash
# Generate new key
age-keygen -o ~/.config/sops/age/gitops-key-new.txt

# Update .sops.yaml with new public key (keep old key temporarily)

# Re-encrypt all files with both keys
sops updatekeys -y terraform.tfvars.enc
sops updatekeys -y backend.hcl.enc

# Test decryption with new key
SOPS_AGE_KEY_FILE=~/.config/sops/age/gitops-key-new.txt \
  sops -d terraform.tfvars.enc

# Update Kubernetes secret
kubectl -n flux-system create secret generic sops-age \
  --from-file=age.agekey=~/.config/sops/age/gitops-flux.txt \
  --dry-run=client -o yaml | kubectl apply -f -

# Update GitHub Secret
gh secret set SOPS_AGE_KEY_TALOS_FLUX < ~/.config/sops/age/gitops-flux.txt

# Remove old key from .sops.yaml and commit
```

## Architecture Decisions

This implementation follows these architectural decisions:

- **[ADR-0007: GitOps Workflow](../../../docs/decisions/0007-gitops-workflow.md)**: Git as single source of truth
- **[ADR-0018: Flux for Kubernetes GitOps](../../../docs/decisions/0018-flux-kubernetes-gitops.md)**: Flux CD for GitOps
- **Operator Pattern**: Using Flux Operator for declarative management
- **Module Architecture**: Reusable module for consistent deployments

## References

- [Flux Operator Documentation](https://fluxcd.control-plane.io/operator/)
- [FluxInstance CRD Reference](https://fluxcd.control-plane.io/operator/fluxinstance/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [SOPS Documentation](https://github.com/getsops/sops)
- [age Encryption](https://age-encryption.org/)

## Next Steps: Managing Kubernetes Resources

After Flux is successfully installed, all Kubernetes resource management happens via **GitOps workflow**:

### 1. Understanding the GitOps Structure

```
kubernetes/
├── clusters/gitops/           # Flux configuration for your cluster
│   ├── flux-system/                 # Flux controllers (auto-managed)
│   ├── kube-system.yaml             # Points to base/kube-system/
│   └── kube-addons.yaml             # Points to base/kube-addons/
│
└── base/                            # Your Kubernetes manifests
    ├── kube-system/                 # Core system components
    │   └── kustomization.yaml       # Add resources here
    │
    └── kube-addons/                 # Cluster addons
        └── kustomization.yaml       # Add resources here
```

See [kubernetes/README.md](../../../kubernetes/README.md) for complete directory structure.

### 2. Deploy Applications via GitOps

**Add manifests to the repository**:

```bash
# Navigate to kubernetes base directory
cd ../../../kubernetes/base/kube-addons/

# Create your manifest
cat > monitoring.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
EOF

# Update kustomization.yaml
cat >> kustomization.yaml <<EOF
resources:
  - monitoring.yaml
EOF

# Commit and push
git add .
git commit -m "feat(monitoring): add monitoring namespace"
git push
```

**Flux automatically syncs** (within 5 minutes):

```bash
# Watch Flux reconciliation
kubectl -n flux-system get kustomization -w

# Force immediate sync (optional)
flux reconcile kustomization kube-addons --with-source

# View deployed resources
kubectl -n monitoring get all
```

### 3. Recommended Next Steps

1. **Add System Components**: Core Kubernetes resources in `kubernetes/base/kube-system/`
   - Custom DNS configurations
   - Storage classes
   - Network policies

2. **Add Cluster Addons**: Operational tools in `kubernetes/base/kube-addons/`
   - Ingress controller (nginx, traefik)
   - Certificate management (cert-manager)
   - Monitoring stack (Prometheus, Grafana)
   - Logging aggregation

3. **Configure Monitoring**: Set up Flux notifications and alerts

   ```bash
   flux create alert-provider slack --type slack --address <webhook-url>
   flux create alert flux-system --provider-ref slack
   ```

4. **Document Runbooks**: Create operational runbooks for:
   - Disaster recovery procedures
   - Common troubleshooting scenarios
   - Application deployment workflows

5. **Test Recovery**: Practice disaster recovery:

   ```bash
   # Delete cluster and rebuild from Git
   cd ../../terraform/environments/talos-cluster
   # Rebuild cluster...
   cd ../gitops
   terraform apply              # Bootstrap Flux
   # Flux automatically restores all resources from Git!
   ```

### 4. Reference Documentation

- **[ADR-0018: Flux for Kubernetes GitOps](../../../docs/decisions/0018-flux-kubernetes-gitops.md)** - GitOps decision and workflow
- **[kubernetes/README.md](../../../kubernetes/README.md)** - Kubernetes manifests structure
- **[Terraform Environments Overview](../README.md)** - Complete infrastructure workflow

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | ~> 5.42 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.12 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.23 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_gitops"></a> [gitops](#module\_gitops) | ../../modules/gitops | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cert_manager_dns01_recursive_nameservers"></a> [cert\_manager\_dns01\_recursive\_nameservers](#input\_cert\_manager\_dns01\_recursive\_nameservers) | DNS server endpoints for DNS01 and DoH check requests (list of strings, e.g., ['8.8.8.8:53', '8.8.4.4:53'] or ['https://1.1.1.1/dns-query']) | `list(string)` | <pre>[<br/>  "1.1.1.1:53",<br/>  "8.8.8.8:53"<br/>]</pre> | no |
| <a name="input_cert_manager_dns01_recursive_nameservers_only"></a> [cert\_manager\_dns01\_recursive\_nameservers\_only](#input\_cert\_manager\_dns01\_recursive\_nameservers\_only) | When true, cert-manager will only query configured DNS resolvers for ACME DNS01 self check | `bool` | `true` | no |
| <a name="input_cert_manager_enable_certificate_owner_ref"></a> [cert\_manager\_enable\_certificate\_owner\_ref](#input\_cert\_manager\_enable\_certificate\_owner\_ref) | When true, certificate resource will be set as owner of the TLS secret | `bool` | `true` | no |
| <a name="input_cert_manager_enable_gateway_api"></a> [cert\_manager\_enable\_gateway\_api](#input\_cert\_manager\_enable\_gateway\_api) | Enable gateway API integration in cert-manager (requires v1.15+) | `bool` | `true` | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | Version of cert-manager Helm chart to install | `string` | `"v1.19.1"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Kubernetes cluster | `string` | `"gitops"` | no |
| <a name="input_cluster_path"></a> [cluster\_path](#input\_cluster\_path) | Path in the repository where cluster manifests are stored | `string` | `"./kubernetes/clusters/gitops"` | no |
| <a name="input_flux_components_extra"></a> [flux\_components\_extra](#input\_flux\_components\_extra) | Extra Flux components to install (e.g., image-reflector-controller, image-automation-controller) | `list(string)` | `[]` | no |
| <a name="input_flux_namespace"></a> [flux\_namespace](#input\_flux\_namespace) | Namespace where Flux controllers will be installed | `string` | `"flux-system"` | no |
| <a name="input_flux_network_policy"></a> [flux\_network\_policy](#input\_flux\_network\_policy) | Enable network policies for Flux controllers | `bool` | `true` | no |
| <a name="input_flux_operator_version"></a> [flux\_operator\_version](#input\_flux\_operator\_version) | Version of Flux Operator Helm chart to install | `string` | `"0.33.0"` | no |
| <a name="input_flux_version"></a> [flux\_version](#input\_flux\_version) | Version of Flux controllers to deploy via FluxInstance | `string` | `"v2.7.3"` | no |
| <a name="input_github_branch"></a> [github\_branch](#input\_github\_branch) | Git branch to track for GitOps | `string` | `"main"` | no |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub repository owner (organization or user) | `string` | n/a | yes |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository name (without owner) | `string` | n/a | yes |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub personal access token for Flux GitOps | `string` | n/a | yes |
| <a name="input_kubernetes_cluster_ca_certificate"></a> [kubernetes\_cluster\_ca\_certificate](#input\_kubernetes\_cluster\_ca\_certificate) | Kubernetes cluster CA certificate (base64 encoded) | `string` | n/a | yes |
| <a name="input_kubernetes_host"></a> [kubernetes\_host](#input\_kubernetes\_host) | Kubernetes cluster API endpoint (e.g., https://api.cluster.example.com:6443) | `string` | n/a | yes |
| <a name="input_kubernetes_token"></a> [kubernetes\_token](#input\_kubernetes\_token) | Kubernetes authentication token | `string` | n/a | yes |
| <a name="input_sops_age_key_path"></a> [sops\_age\_key\_path](#input\_sops\_age\_key\_path) | Path to the SOPS age private key file for Flux decryption (deployed to Kubernetes) | `string` | `"~/.config/sops/age/gitops-flux.txt"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cert_manager_namespace"></a> [cert\_manager\_namespace](#output\_cert\_manager\_namespace) | Namespace where cert-manager is installed |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the Kubernetes cluster |
| <a name="output_cluster_path"></a> [cluster\_path](#output\_cluster\_path) | Path in repository where cluster manifests are stored |
| <a name="output_component_versions"></a> [component\_versions](#output\_component\_versions) | Versions of installed components |
| <a name="output_deployment_phase"></a> [deployment\_phase](#output\_deployment\_phase) | Current deployment phase and next steps |
| <a name="output_flux_logs_commands"></a> [flux\_logs\_commands](#output\_flux\_logs\_commands) | Commands to view Flux logs |
| <a name="output_flux_namespace"></a> [flux\_namespace](#output\_flux\_namespace) | Namespace where Flux is installed |
| <a name="output_git_branch"></a> [git\_branch](#output\_git\_branch) | Git branch tracked by Flux |
| <a name="output_git_repository"></a> [git\_repository](#output\_git\_repository) | Git repository URL used by Flux |
| <a name="output_next_steps"></a> [next\_steps](#output\_next\_steps) | Next steps after complete installation |
| <a name="output_verification_commands"></a> [verification\_commands](#output\_verification\_commands) | Commands to verify the installation |
<!-- END_TF_DOCS -->
