# Kubernetes Manifests - Flux GitOps

This directory contains Kubernetes manifests managed by Flux CD for GitOps-based deployments.

See [ADR-0018: Flux for Kubernetes GitOps](../docs/decisions/0018-flux-kubernetes-gitops.md) for
decision rationale and implementation details.

## Directory Structure

```text
kubernetes/
├── base/                              # Base Kubernetes manifests (reusable components)
│   ├── gateway-api/                   # Gateway API CRDs (v1.3.0)
│   ├── cilium/                        # Cilium CNI with Gateway API support
│   ├── cert-manager/                  # Certificate management
│   ├── olmv1/                         # OLM v1 operator-controller (v1.5.1)
│   ├── olmv1-catalog/                 # OLM ClusterCatalog resources (OperatorHub)
│   ├── flux-operator/                 # Flux Operator via OLM ClusterExtension
│   └── flux-instance/                 # FluxInstance CRD (Flux components)
│
├── overlays/                          # Configuration overlays and references
│   └── flux-instance/
│       └── sops-reference/            # Terraform-managed SOPS secrets (reference docs)
│
└── clusters/shangkuei-xyz-talos/     # Cluster-specific Flux Kustomizations
    ├── kustomization.yaml             # Main cluster kustomization (resource list)
    ├── kustomization-gateway-api-standard.yaml      # Gateway API standard CRDs
    ├── kustomization-gateway-api-experimental.yaml  # Gateway API experimental CRDs
    ├── kustomization-cilium.yaml                    # Cilium CNI deployment
    ├── kustomization-cert-manager.yaml              # Certificate manager deployment
    ├── kustomization-olmv1.yaml                     # OLM operator-controller deployment
    ├── kustomization-olmv1-catalog.yaml             # OLM ClusterCatalog deployment
    ├── kustomization-flux-operator.yaml             # Flux Operator deployment
    └── kustomization-flux-instance.yaml             # Flux components deployment
```

## Deployment Layers

The cluster infrastructure is deployed in 8 ordered layers with health checks preventing race conditions:

### Layer 1: Gateway API CRDs

- **Component**: Gateway API v1.2.0 (standard + experimental)
- **Dependencies**: None (foundation layer)
- **Health Checks**: Gateway CRD readiness
- **Purpose**: Kubernetes Gateway API for ingress management

### Layer 2: Cilium CNI

- **Component**: Cilium CNI with Gateway API support
- **Dependencies**: Gateway API CRDs
- **Health Checks**: DaemonSet ready, Gateway API implementation
- **Purpose**: Container networking, service mesh, Gateway API implementation

### Layer 3: Certificate Manager

- **Component**: cert-manager v1.16.2
- **Dependencies**: Gateway API (HTTP01/TLS challenges)
- **Health Checks**: Deployment ready, webhook certificates
- **Purpose**: TLS certificate automation and management

### Layer 4: OpenEBS Storage

- **Component**: OpenEBS v4.2.0 (LocalPV Hostpath)
- **Dependencies**: Cilium CNI (pod networking)
- **Health Checks**: Deployment ready (`openebs-localpv-provisioner`)
- **Purpose**: Dynamic local storage provisioning with default StorageClass

### Layer 5: OLM Operator-Controller

- **Component**: operator-controller v1.5.1
- **Dependencies**: cert-manager (webhook certificates)
- **Health Checks**:
  - Deployment: `operator-controller-controller-manager` (namespace: `olmv1-system`)
  - CRDs: `clustercatalogs.olm.operatorframework.io`, `clusterextensions.olm.operatorframework.io`
- **Purpose**: Operator Lifecycle Manager for operator installations

### Layer 6: OLM ClusterCatalog

- **Component**: OperatorHub catalog (quay.io/operatorhubio/catalog)
- **Dependencies**: OLM CRDs must exist
- **Health Checks**: `ClusterCatalog/operatorhubio` ready
- **Purpose**: Operator package catalog for discovering and installing operators

### Layer 7: Flux Operator

- **Component**: flux-operator v0.33.0+ (stable channel, OLM-managed)
- **Dependencies**: OLM ClusterCatalog for operator installation
- **Health Checks**:
  - ClusterExtension: `flux-operator` installed by OLM
  - Deployment: `flux-operator` (namespace: `flux-system`)
  - CRD: `fluxinstances.fluxcd.controlplane.io`
- **Purpose**: Manages Flux CD installations via FluxInstance CRDs

### Layer 8: Flux Instance

- **Component**: Flux CD v2.7.3 components (source, kustomize, helm, notification controllers)
- **Dependencies**: Flux Operator and FluxInstance CRD
- **Health Checks**: FluxInstance ready, all controllers running
- **Purpose**: GitOps continuous deployment from this repository

## Managed Namespaces

Flux CD manages resources across these namespaces:

- **`flux-system`**: Flux Operator and Flux CD components
- **`olmv1-system`**: OLM operator-controller
- **`kube-system`**: Cilium CNI and network policies
- **`cert-manager`**: Certificate management controllers
- **`openebs`**: OpenEBS storage controllers and provisioner
- **Gateway API resources**: Cluster-scoped CRDs and controllers

## Prerequisites

**Required**: A running Talos Kubernetes cluster. See:

- [Terraform Environments Overview](../terraform/environments/README.md) - Complete deployment workflow
- [talos-cluster Environment](../terraform/environments/talos-cluster/README.md) - Cluster provisioning (Part 1)
- [Talos Cluster Specification](../specs/talos/talos-cluster-specification.md) - Technical requirements

This GitOps configuration assumes cluster is already provisioned and healthy.

### Bootstrap Flux

**Note**: This repository uses Terraform to bootstrap Flux via the Flux Operator. The manual bootstrap command is provided for reference only.

**Terraform-based bootstrap** (recommended):

```bash
cd terraform/environments/talos-gitops
terraform init
terraform apply
```

**Manual bootstrap** (alternative, for reference):

```bash
# Install Flux CLI
brew install fluxcd/tap/flux

# Verify cluster compatibility
flux check --pre

# Bootstrap Flux
flux bootstrap github \
  --owner=shangkuei \
  --repository=infrastructure \
  --branch=main \
  --path=./kubernetes/clusters/shangkuei-xyz-talos \
  --personal
```

The Terraform approach is preferred as it manages the complete stack including OLM, Flux Operator, cert-manager, and SOPS integration.

## Workflow

1. **Add manifests** to `base/kube-system/` or `base/kube-addons/`
2. **Update** `kustomization.yaml` to include new resources
3. **Commit and push** - Flux reconciles automatically within 5 minutes
4. **Monitor**: `flux get kustomizations`

## References

- [Flux CD Documentation](https://fluxcd.io/flux/)
- [ADR-0018: Flux for Kubernetes GitOps](../docs/decisions/0018-flux-kubernetes-gitops.md)
