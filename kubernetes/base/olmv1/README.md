# OLM v1 (Operator Lifecycle Manager)

GitOps configuration for OLM v1 operator-controller and OperatorHub catalog.

## Overview

This directory contains Flux-managed configuration for:

- **OLM v1 operator-controller**: Core operator lifecycle management
- **OperatorHub ClusterCatalog**: Community operator catalog from operatorhub.io
- **olmv1-system namespace**: Isolated namespace for OLM components

## Architecture

### Bootstrap vs GitOps Management

```
┌─────────────────────────────────────────────────────────────┐
│ BOOTSTRAP PHASE (Terraform)                                 │
│ terraform/environments/gitops/                         │
├─────────────────────────────────────────────────────────────┤
│ 1. cert-manager (Helm)                                       │
│ 2. OLM v1 operator-controller (kubectl manifests)            │
│ 3. OperatorHub ClusterCatalog (initial)                      │
│ 4. Flux Operator (OLM ClusterExtension)                      │
│ 5. FluxInstance (points to Git repo)                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ GITOPS PHASE (Flux)                                          │
│ kubernetes/base/olmv1/ & kubernetes/clusters/*/              │
├─────────────────────────────────────────────────────────────┤
│ 1. olmv1-system namespace (explicit)                         │
│ 2. OLM v1 GitRepository (upstream source)                    │
│ 3. OLM v1 ArtifactGenerator (extract manifests)             │
│ 4. OperatorHub ClusterCatalog (ongoing management)           │
└─────────────────────────────────────────────────────────────┘
```

### Why This Split?

**Bootstrap (Terraform)**:

- Initial cluster setup requires OLM to install Flux Operator
- Terraform ensures correct installation order with dependencies
- One-time operation during cluster initialization

**GitOps (Flux)**:

- Long-term configuration management via Git
- Automatic updates and drift detection
- Declarative desired state in version control

## Components

### 1. Namespace

[namespace-olmv1-system.yaml](namespace-olmv1-system.yaml)

Creates the `olmv1-system` namespace where OLM operator-controller runs.

### 2. GitRepository

[gitrepository-olmv1.yaml](gitrepository-olmv1.yaml)

Tracks the official `operator-framework/operator-controller` repository at version `v1.5.1`.

### 3. ArtifactGenerator

[artifactgenerator-olmv1.yaml](artifactgenerator-olmv1.yaml)

Extracts operator-controller manifests from the Git repository for deployment.

### 4. OperatorHub ClusterCatalog

[clustercatalog-operatorhub.yaml](clustercatalog-operatorhub.yaml)

Provides access to community operators from operatorhub.io:

- Image: `quay.io/operatorhubio/catalog:latest`
- Poll interval: 60 minutes
- Enables operator discovery and installation

## Migration from Terraform

If you're migrating from Terraform-managed resources, follow this process:

### Step 1: Verify Terraform State

```bash
cd terraform/environments/gitops
terraform state list | grep -E "olmv1|operatorhub"
```

Expected output:

```
kubernetes_namespace.olmv1_system
kubectl_manifest.olm[...]
kubernetes_manifest.operatorhub_catalog
```

### Step 2: Add Lifecycle Ignore to Terraform

Update `main.tf` to prevent Terraform from managing the ClusterCatalog:

```hcl
resource "kubernetes_manifest" "operatorhub_catalog" {
  depends_on = [kubectl_manifest.olm]

  manifest = {
    # ... existing configuration
  }

  lifecycle {
    ignore_changes = all
  }
}
```

### Step 3: Apply Terraform Changes

```bash
terraform apply
```

This tells Terraform to keep the resource in state but ignore changes.

### Step 4: Verify Flux Management

```bash
# Check Flux Kustomization status
kubectl get kustomization olmv1 -n flux-system

# Verify ClusterCatalog is present
kubectl get clustercatalog operatorhubio

# Check catalog readiness
kubectl get clustercatalog operatorhubio -o jsonpath='{.status.conditions[?(@.type=="Unpacked")].status}'
```

### Step 5: Remove from Terraform (Optional)

Once verified working, optionally remove from Terraform state:

```bash
terraform state rm kubernetes_manifest.operatorhub_catalog
```

## Usage

### Installing Operators

Once the ClusterCatalog is ready, install operators using ClusterExtension:

```yaml
apiVersion: olm.operatorframework.io/v1
kind: ClusterExtension
metadata:
  name: my-operator
spec:
  source:
    sourceType: Catalog
    catalog:
      packageName: my-operator
      version: "1.0.0"
  namespace: my-operator-namespace
```

### Listing Available Operators

```bash
# List all available packages
kubectl get packages

# Search for specific operator
kubectl get packages | grep <operator-name>

# Get operator details
kubectl get package <package-name> -o yaml
```

### Troubleshooting

**ClusterCatalog not unpacking:**

```bash
# Check catalog status
kubectl describe clustercatalog operatorhubio

# Check catalogd pod logs
kubectl logs -n olmv1-system -l app=catalogd

# Force reconciliation
kubectl annotate clustercatalog operatorhubio reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

**Operator installation failing:**

```bash
# Check ClusterExtension status
kubectl get clusterextension <name> -o yaml

# Check operator-controller logs
kubectl logs -n olmv1-system -l app.kubernetes.io/name=operator-controller
```

## References

- [OLM v1 Documentation](https://operator-framework.github.io/operator-controller/)
- [OperatorHub.io](https://operatorhub.io/)
- [Flux GitRepository](https://fluxcd.io/flux/components/source/gitrepositories/)
- [Flux ArtifactGenerator](https://fluxcd.io/flux/components/source/artifactgenerators/)

## Version Pinning

- **OLM version**: `v1.5.1` (pinned in GitRepository)
- **Catalog image**: `latest` (auto-updates every 60 minutes)

To pin the catalog version, update [clustercatalog-operatorhub.yaml](clustercatalog-operatorhub.yaml):

```yaml
spec:
  source:
    image:
      ref: quay.io/operatorhubio/catalog:v0.23.0  # Pin to specific version
```
