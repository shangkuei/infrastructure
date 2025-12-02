# Talos GitOps Terraform Environment

This Terraform environment bootstraps Flux CD on the Talos Kubernetes cluster using the **Flux Operator** for GitOps-based continuous delivery.

> **📍 Part 2 of 2**: This environment enables GitOps on an **existing running cluster** provisioned by [`talos-cluster/`](../talos-cluster/).
>
> **Prerequisites**: Complete [`talos-cluster/`](../talos-cluster/) deployment first. Cluster must be running and healthy.
>
> See [Terraform Environments Overview](../README.md) for complete deployment workflow.

## Overview

This environment uses a modern operator-based approach to install and manage Flux CD:

1. **cert-manager**: Certificate management for OLM webhooks (Helm)
2. **OLM v1**: Operator Lifecycle Manager v1 using operator-controller (kubectl provider)
3. **ClusterCatalog**: OperatorHub catalog for operator discovery (OLM v1)
4. **Flux Operator**: Manages Flux installation via FluxInstance CRD (OLM ClusterExtension)
5. **FluxInstance**: Declarative Flux configuration with SOPS integration

**Architecture Benefits**:

- ✅ Declarative Flux management via FluxInstance CRD
- ✅ OLM v1-based operator lifecycle management
- ✅ Catalog-driven operator installation and upgrades
- ✅ Native SOPS integration for encrypted manifests
- ✅ GitOps workflow with automatic reconciliation
- ✅ Clean separation of concerns (operator vs. controllers)

**Managed Namespaces**:

- `cert-manager`: Certificate management
- `olmv1-system`: Operator Lifecycle Manager v1
- `flux-system`: Flux Operator and controllers
- `kube-system`: Core system components (managed by Flux)
- `kube-addons`: Cluster addons (managed by Flux)

## Component Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| cert-manager | v1.19.1 | TLS certificate management for webhooks |
| OLM v1 | v1.5.1 | Operator Lifecycle Manager (operator-controller) |
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
kubectl create serviceaccount talos-gitops-admin -n kube-system

# Step 2: Create cluster role binding
kubectl create clusterrolebinding talos-gitops-admin --clusterrole=cluster-admin --serviceaccount=kube-system:talos-gitops-admin

# Step 3: Create secret for long-lived token (required in K8s 1.24+)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: talos-gitops-admin-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: talos-gitops-admin
type: kubernetes.io/service-account-token
EOF

# Step 4: Wait for token to be generated and retrieve it
kubectl get secret talos-gitops-admin-token -n kube-system -o jsonpath='{.data.token}' | base64 -d

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

1. **Terraform Key** (`talos-gitops.txt`): For encrypting local Terraform files (terraform.tfvars, backend.hcl)
2. **Flux Key** (`talos-gitops-flux.txt`): For encrypting Kubernetes manifests in Git (deployed to Kubernetes as a secret)

```bash
# Generate both age keys
make age-keygen

# This creates:
# Terraform Key (for local Terraform file encryption)
# - ~/.config/sops/age/talos-gitops.txt (private key)
# - ~/.config/sops/age/talos-gitops.txt.pub (public key)
#
# Flux Key (for Kubernetes manifest encryption in Git)
# - ~/.config/sops/age/talos-gitops-flux.txt (private key)
# - ~/.config/sops/age/talos-gitops-flux.txt.pub (public key)
```

**⚠️ Important**: The private keys must be stored securely:

- Keys are stored centrally in `~/.config/sops/age/`
- Backup both private keys to password manager
- **Flux key**: Store in GitHub Secrets for CI/CD: `gh secret set SOPS_AGE_KEY < ~/.config/sops/age/talos-gitops-flux.txt`
- **Flux key**: Will be deployed to Kubernetes by Terraform as `sops-age` secret
- Never commit private keys to Git

**Key Information**: View both keys: `make age-info`

## Setup Instructions

### Step 1: Generate Age Keys for SOPS

```bash
cd terraform/environments/talos-gitops

# Generate both age keys (Terraform + Flux)
make age-keygen

# View key information (including public keys for .sops.yaml)
make age-info

# Backup both keys to your password manager
cat ~/.config/sops/age/talos-gitops.txt       # Terraform key
cat ~/.config/sops/age/talos-gitops-flux.txt  # Flux key
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
cluster_name = "talos-gitops"
cluster_path = "./kubernetes/clusters/talos-gitops"

# Flux Configuration
flux_namespace      = "flux-system"
flux_network_policy = true

# SOPS Configuration (Flux key - deployed to Kubernetes)
sops_age_key_path = "~/.config/sops/age/talos-gitops-flux.txt"

# Component Versions (optional, defaults provided)
cert_manager_version  = "v1.19.1"
olm_version          = "v1.5.1"  # OLM v1 (operator-controller)
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
- **OLM v1**: kubectl_manifest resources from operator-controller release manifests
- **ClusterCatalog**: OperatorHub catalog for operator discovery
- **Flux Operator**: ClusterExtension resource for OLM-based installation
- **SOPS Age Secret**: For decrypting manifests
- **FluxInstance**: Declarative Flux configuration with Git sync
- **Git Credentials**: Secret for GitHub authentication

### Step 5: Apply the Configuration (Phased Deployment)

**IMPORTANT**: Due to Kubernetes CRD registration timing, this configuration requires a
**phased deployment approach**. Terraform cannot guarantee that CRDs are fully registered
and available immediately after installation, even with `depends_on` relationships.

#### Why Phased Deployment?

When OLM v1 is installed, it creates several Custom Resource Definitions (CRDs) including `ClusterCatalog`, `ClusterExtension`, and `FluxInstance`. The Kubernetes API server needs time to:

1. Register the new CRDs
2. Make them available for resource creation
3. Start the controllers that manage these resources

If Terraform attempts to create resources using these CRDs in the same apply operation, it will fail with errors like:

```
Error: no matches for kind 'ClusterCatalog' in group 'olm.operatorframework.io'
```

#### Deployment Phases

**Phase 1: Core Infrastructure (cert-manager + OLM v1)**

Deploy the foundation components that provide CRDs:

```bash
# Comment out these resources in main.tf before Phase 1:
# - kubectl_manifest.operatorhub_catalog (lines ~167-187)
# - kubernetes_manifest.flux_operator_extension (lines ~248-284)
# - kubernetes_manifest.flux_instance (lines ~364-435)

# Apply Phase 1
make apply  # or: terraform apply

# Wait for cert-manager to be ready
kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager --timeout=5m
kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager-webhook --timeout=5m

# Wait for OLM v1 to be ready
kubectl -n olmv1-system wait --for=condition=Available deployment/operator-controller-controller-manager --timeout=5m

# Verify CRDs are registered
kubectl get crd clustercatalogs.olm.operatorframework.io
kubectl get crd clusterextensions.olm.operatorframework.io
```

**Phase 2: Operator Catalog**

Deploy the ClusterCatalog to enable operator discovery:

```bash
# Uncomment kubectl_manifest.operatorhub_catalog in main.tf (lines ~167-187)

# Apply Phase 2
make apply  # or: terraform apply

# Wait for catalog to be ready
kubectl wait --for=condition=Serving clustercatalog/operatorhubio --timeout=5m

# Verify catalog is serving
kubectl get clustercatalog operatorhubio -o jsonpath='{.status.conditions[?(@.type=="Serving")].status}'
# Should output: True
```

**Phase 3: Flux Operator Installation**

Deploy the Flux Operator via OLM ClusterExtension:

```bash
# Uncomment kubernetes_manifest.flux_operator_extension in main.tf (lines ~248-284)

# Apply Phase 3
make apply  # or: terraform apply

# Wait for operator to be installed
kubectl wait --for=condition=Installed clusterextension/flux-operator --timeout=10m

# Verify operator pods are running
kubectl -n flux-system get pods -l app.kubernetes.io/name=flux-operator

# Verify FluxInstance CRD is available
kubectl get crd fluxinstances.fluxcd.controlplane.io
```

**Phase 4: Flux Bootstrap**

Deploy the FluxInstance to bootstrap Flux and sync with Git:

```bash
# Uncomment kubernetes_manifest.flux_instance in main.tf (lines ~364-435)

# Apply Phase 4
make apply  # or: terraform apply

# Wait for FluxInstance to be ready
kubectl -n flux-system wait --for=condition=Ready fluxinstance/flux --timeout=10m

# Verify Flux controllers are running
kubectl -n flux-system get pods
```

#### Troubleshooting Phased Deployment

**Problem**: CRD not found even after Phase 1 completes

```bash
# Solution: Wait a bit longer and manually verify
kubectl get crd | grep olm.operatorframework.io
kubectl api-resources | grep olm.operatorframework.io

# If still not showing, check OLM v1 controller logs
kubectl -n olmv1-system logs -l app.kubernetes.io/name=operator-controller
```

**Problem**: ClusterCatalog remains in "Unpacking" state

```bash
# Solution: Check catalog controller logs
kubectl -n olmv1-system logs -l app.kubernetes.io/name=catalogd

# Check catalog status details
kubectl get clustercatalog operatorhubio -o yaml
```

**Problem**: ClusterExtension installation fails

```bash
# Solution: Verify catalog is serving
kubectl get clustercatalog operatorhubio -o jsonpath='{.status.conditions[?(@.type=="Serving")]}'

# Check if flux-operator package exists in catalog
kubectl get packages | grep flux-operator

# Check ClusterExtension events
kubectl describe clusterextension flux-operator
```

**Problem**: FluxInstance fails to create Flux controllers

```bash
# Solution: Check Flux Operator logs
kubectl -n flux-system logs -l app.kubernetes.io/name=flux-operator

# Verify SOPS age secret exists
kubectl -n flux-system get secret sops-age

# Check FluxInstance status
kubectl -n flux-system get fluxinstance flux -o yaml
```

#### Single-Phase Deployment (Advanced)

For automated environments, you can use a single apply with retry logic:

```bash
# Apply everything (will fail on first attempt)
make apply || true

# Wait for CRDs to register
sleep 30

# Retry apply (Phase 2-4 resources will now succeed)
make apply

# Wait for catalog
sleep 30

# Final apply (remaining resources)
make apply
```

This approach is less reliable and not recommended for production deployments.

## Verification

### Check Component Installation

```bash
# Check cert-manager
kubectl -n cert-manager get pods
kubectl get crd | grep cert-manager

# Check OLM v1
kubectl -n olmv1-system get pods
kubectl get crd | grep operator.operatorframework.io

# Check ClusterCatalog
kubectl get clustercatalog operatorhubio
kubectl get clustercatalog operatorhubio -o jsonpath='{.status.conditions}' | jq

# Check Flux Operator ClusterExtension
kubectl get clusterextension flux-operator
kubectl get clusterextension flux-operator -o jsonpath='{.status.conditions}' | jq

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

Replace with your **Flux age public key** from: `cat ~/.config/sops/age/talos-gitops-flux.txt.pub`

**Important**: Use the **Flux key** for Kubernetes manifests, not the Terraform key.

**Step 2: Create a secret file**

```yaml
# kubernetes/clusters/shangkuei-xyz-talos/secrets/database-credentials.yaml
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
sops --encrypt --in-place kubernetes/clusters/shangkuei-xyz-talos/secrets/database-credentials.yaml
```

**Step 4: Create Kustomization with SOPS decryption**

```yaml
# kubernetes/clusters/shangkuei-xyz-talos/secrets-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: secrets
  namespace: flux-system
spec:
  interval: 10m
  path: ./kubernetes/clusters/shangkuei-xyz-talos/secrets
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

### ClusterCatalog not ready

**Problem**: ClusterCatalog shows as not serving

```bash
# Check ClusterCatalog status
kubectl get clustercatalog operatorhubio
kubectl describe clustercatalog operatorhubio

# Check catalog pod logs
kubectl -n olmv1-system logs -l olm.catalogd.io/catalog-name=operatorhubio
```

**Solution**: Verify network connectivity and image pull permissions

### ClusterExtension failing to install

**Problem**: Flux Operator ClusterExtension not installing

```bash
# Check ClusterExtension status
kubectl get clusterextension flux-operator
kubectl describe clusterextension flux-operator

# Check OLM controller logs
kubectl -n olmv1-system logs -l app.kubernetes.io/name=operator-controller
```

**Common issues**:

- Package name mismatch in catalog
- Version not available in catalog
- Insufficient RBAC permissions for installer service account
- Dependency conflicts with existing resources

**Solution**: Verify package availability in catalog and RBAC configuration

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

To upgrade the Flux Operator via OLM:

```hcl
flux_operator_version = "0.34.0"  # New version
```

```bash
terraform apply
```

OLM will handle the upgrade through the ClusterExtension resource, performing a rolling update.

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
cd terraform/environments/talos-flux
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
- OLM
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
age-keygen -o ~/.config/sops/age/talos-flux-key-new.txt

# Update .sops.yaml with new public key (keep old key temporarily)

# Re-encrypt all files with both keys
sops updatekeys -y terraform.tfvars.enc
sops updatekeys -y backend.hcl.enc

# Test decryption with new key
SOPS_AGE_KEY_FILE=~/.config/sops/age/talos-flux-key-new.txt \
  sops -d terraform.tfvars.enc

# Update Kubernetes secret
kubectl -n flux-system create secret generic sops-age \
  --from-file=age.agekey=~/.config/sops/age/talos-gitops.txt \
  --dry-run=client -o yaml | kubectl apply -f -

# Update GitHub Secret
gh secret set SOPS_AGE_KEY_TALOS_FLUX < ~/.config/sops/age/talos-flux-key-new.txt

# Remove old key from .sops.yaml and commit
```

## Architecture Decisions

This implementation follows these architectural decisions:

- **[ADR-0007: GitOps Workflow](../../../docs/decisions/0007-gitops-workflow.md)**: Git as single source of truth
- **[ADR-0018: Flux for Kubernetes GitOps](../../../docs/decisions/0018-flux-kubernetes-gitops.md)**: Flux CD for GitOps
- **Operator Pattern**: Using Flux Operator for declarative management
- **Defense in Depth**: Multiple layers (cert-manager, OLM, operators)

## References

- [Flux Operator Documentation](https://fluxcd.control-plane.io/operator/)
- [FluxInstance CRD Reference](https://fluxcd.control-plane.io/operator/fluxinstance/)
- [OLM Documentation](https://olm.operatorframework.io/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [SOPS Documentation](https://github.com/getsops/sops)
- [age Encryption](https://age-encryption.org/)

## Next Steps: Managing Kubernetes Resources

After Flux is successfully installed, all Kubernetes resource management happens via **GitOps workflow**:

### 1. Understanding the GitOps Structure

```
kubernetes/
├── clusters/shangkuei-xyz-talos/    # Flux configuration for your cluster
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
   cd ../talos-gitops
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
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.4 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 1.19.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.olm](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_cluster_role.flux_operator_installer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role_binding.flux_operator_installer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_manifest.flux_instance](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.flux_operator_extension](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.operatorhub_catalog](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.cert_manager](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.flux_system](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.olmv1_system](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.flux_git_credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.sops_age](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service_account.flux_operator_installer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [http_http.olm_install_manifest](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cert_manager_dns01_recursive_nameservers"></a> [cert\_manager\_dns01\_recursive\_nameservers](#input\_cert\_manager\_dns01\_recursive\_nameservers) | DNS server endpoints for DNS01 and DoH check requests (list of strings, e.g., ['8.8.8.8:53', '8.8.4.4:53'] or ['https://1.1.1.1/dns-query']) | `list(string)` | <pre>[<br/>  "1.1.1.1:53",<br/>  "8.8.8.8:53"<br/>]</pre> | no |
| <a name="input_cert_manager_dns01_recursive_nameservers_only"></a> [cert\_manager\_dns01\_recursive\_nameservers\_only](#input\_cert\_manager\_dns01\_recursive\_nameservers\_only) | When true, cert-manager will only query configured DNS resolvers for ACME DNS01 self check | `bool` | `true` | no |
| <a name="input_cert_manager_enable_certificate_owner_ref"></a> [cert\_manager\_enable\_certificate\_owner\_ref](#input\_cert\_manager\_enable\_certificate\_owner\_ref) | When true, certificate resource will be set as owner of the TLS secret | `bool` | `true` | no |
| <a name="input_cert_manager_enable_gateway_api"></a> [cert\_manager\_enable\_gateway\_api](#input\_cert\_manager\_enable\_gateway\_api) | Enable gateway API integration in cert-manager (requires v1.15+) | `bool` | `true` | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | Version of cert-manager Helm chart to install | `string` | `"v1.19.1"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Kubernetes cluster | `string` | `"talos-gitops"` | no |
| <a name="input_cluster_path"></a> [cluster\_path](#input\_cluster\_path) | Path in the repository where cluster manifests are stored | `string` | `"./kubernetes/clusters/talos-gitops"` | no |
| <a name="input_flux_components_extra"></a> [flux\_components\_extra](#input\_flux\_components\_extra) | Extra Flux components to install (e.g., image-reflector-controller, image-automation-controller) | `list(string)` | `[]` | no |
| <a name="input_flux_namespace"></a> [flux\_namespace](#input\_flux\_namespace) | Namespace where Flux controllers will be installed | `string` | `"flux-system"` | no |
| <a name="input_flux_network_policy"></a> [flux\_network\_policy](#input\_flux\_network\_policy) | Enable network policies for Flux controllers | `bool` | `true` | no |
| <a name="input_flux_operator_version"></a> [flux\_operator\_version](#input\_flux\_operator\_version) | Version of Flux Operator to install via OLM ClusterExtension | `string` | `"0.33.0"` | no |
| <a name="input_flux_version"></a> [flux\_version](#input\_flux\_version) | Version of Flux controllers to deploy via FluxInstance | `string` | `"v2.7.3"` | no |
| <a name="input_github_branch"></a> [github\_branch](#input\_github\_branch) | Git branch to track for GitOps | `string` | `"main"` | no |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub repository owner (organization or user) | `string` | n/a | yes |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository name (without owner) | `string` | n/a | yes |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub personal access token for Flux GitOps | `string` | n/a | yes |
| <a name="input_kubernetes_cluster_ca_certificate"></a> [kubernetes\_cluster\_ca\_certificate](#input\_kubernetes\_cluster\_ca\_certificate) | Kubernetes cluster CA certificate (base64 encoded) | `string` | n/a | yes |
| <a name="input_kubernetes_host"></a> [kubernetes\_host](#input\_kubernetes\_host) | Kubernetes cluster API endpoint (e.g., https://api.cluster.example.com:6443) | `string` | n/a | yes |
| <a name="input_kubernetes_token"></a> [kubernetes\_token](#input\_kubernetes\_token) | Kubernetes authentication token | `string` | n/a | yes |
| <a name="input_olm_version"></a> [olm\_version](#input\_olm\_version) | Version of OLM v1 (operator-controller) to install | `string` | `"v1.5.1"` | no |
| <a name="input_sops_age_key_path"></a> [sops\_age\_key\_path](#input\_sops\_age\_key\_path) | Path to the SOPS age private key file for Flux decryption (deployed to Kubernetes) | `string` | `"~/.config/sops/age/talos-gitops-flux.txt"` | no |

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
| <a name="output_olm_namespace"></a> [olm\_namespace](#output\_olm\_namespace) | Namespace where OLM is installed |
| <a name="output_verification_commands"></a> [verification\_commands](#output\_verification\_commands) | Commands to verify the installation |
<!-- END_TF_DOCS -->
