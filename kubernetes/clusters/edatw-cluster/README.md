# Kubernetes Cluster - edatw-cluster

GitOps configuration for the edatw-cluster Kubernetes cluster managed by Flux.

## Cluster Information

- **Cluster Name**: edatw-cluster
- **GitOps Tool**: Flux v2.7.3
- **Bootstrap Method**: Terraform -> flux-operator (Helm) -> FluxInstance

## Architecture Overview

### Bootstrap Chain

```
Terraform Bootstrap:
  cert-manager (Helm) -> Certificate management
      |
  flux-operator (Helm) -> Manages Flux (NO OLM dependency)
      |
  Flux (FluxInstance) -> GitOps engine
      |
  Flux syncs this repository -> kubernetes/clusters/edatw-cluster/

GitOps-Managed Applications:
  - gateway-api -> CRDs (no dependencies - foundational API extension)
  - cilium -> CNI (depends on gateway-api - implements Gateway API)
  - cert-manager -> Certificate management (depends on gateway-api)
  - openebs -> Storage provisioner (depends on cilium)
  - snapshot-controller -> Volume snapshots (depends on cilium)
  - argocd -> GitOps CD tool (depends on cilium)
```

## Directory Structure

```
kubernetes/
├── base/                                      # Application definitions
│   ├── gateway-api/                           # Gateway API GitRepository
│   ├── cert-manager/                          # Certificate automation
│   ├── cilium/                                # CNI with Gateway API support
│   ├── openebs/                               # Local storage provisioner
│   ├── snapshot-controller/                   # Volume snapshot controller
│   ├── flux-instance/                         # Flux configuration
│   └── argocd/                                # ArgoCD installation
│
├── overlays/
│   ├── flux-instance/edatw-cluster/          # Flux SOPS secrets
│   └── argocd-projects/edatw-cluster/        # ArgoCD projects overlay
│
└── clusters/
    └── edatw-cluster/
        ├── kustomization.yaml                 # Root: orchestrates all resources
        ├── kustomization-gateway-api-*.yaml   # Gateway API CRDs
        ├── kustomization-cilium.yaml          # Cilium CNI
        ├── kustomization-cert-manager.yaml    # cert-manager
        ├── kustomization-openebs.yaml         # OpenEBS storage
        ├── kustomization-snapshot-controller.yaml
        ├── kustomization-flux-instance.yaml   # Flux instance
        ├── kustomization-argocd.yaml          # ArgoCD
        └── flux-instance-sops/                # SOPS-encrypted Flux secrets
```

## Application Dependency Graph

```
gateway-api-standard (foundational)
    │
    ├── gateway-api-experimental
    │       │
    │       └── cilium (CNI)
    │               │
    │               ├── openebs (storage)
    │               ├── snapshot-controller
    │               ├── flux-instance
    │               └── argocd
    │
    └── cert-manager
```

## Managed Applications

| Application | Type | Dependencies | Namespace |
|-------------|------|--------------|-----------|
| Gateway API | CRDs | None | N/A |
| Cilium | HelmRelease | Gateway API | kube-system |
| cert-manager | HelmRelease | Gateway API | cert-manager |
| OpenEBS | HelmRelease | Cilium | openebs |
| Snapshot Controller | HelmRelease | Cilium | kube-system |
| Flux Instance | FluxInstance | Cilium | flux-system |
| ArgoCD | HelmRelease | Cilium | argocd |

## Deployment and Operations

### Initial Deployment

1. **Bootstrap via Terraform**:

   ```bash
   cd terraform/environments/gitops-edatw-cluster
   terraform init
   terraform apply
   ```

2. **Generate SOPS secrets**:

   ```bash
   cd kubernetes/overlays/flux-instance/edatw-cluster
   make import-age-key AGE_KEY_FILE=~/.config/sops/age/gitops-edatw-cluster-flux.txt
   make setup
   ```

3. **Commit Kubernetes manifests**:

   ```bash
   git add kubernetes/
   git commit -m "feat(kubernetes): add edatw-cluster GitOps configuration"
   git push origin main
   ```

### Monitoring

```bash
# Check Flux system status
flux check

# Watch all Flux resources
flux get all -A

# Check Kustomization status
kubectl get kustomization -n flux-system

# Check HelmReleases
kubectl get helmrelease -A
```

### Manual Reconciliation

```bash
# Force reconcile entire cluster
flux reconcile kustomization flux-system --with-source

# Reconcile specific application
flux reconcile kustomization gateway-api-standard
flux reconcile kustomization cilium
flux reconcile kustomization argocd
```

## Configuration Management

### SOPS Encryption

Sensitive values are encrypted using SOPS with age encryption.

```bash
# Use the cluster Makefile
make secret-create NAME=my-secret NAMESPACE=my-namespace

# Or use the overlays Makefile
cd kubernetes/overlays/flux-instance/edatw-cluster
make setup
```

## References

- [Flux Documentation](https://fluxcd.io/flux/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [cert-manager Documentation](https://cert-manager.io/)
- [Cilium Documentation](https://docs.cilium.io/)
- [OpenEBS Documentation](https://openebs.io/docs)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
