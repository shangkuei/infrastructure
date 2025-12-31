# Talos Cluster - shangkuei-lab

GitOps configuration for the Talos Linux Kubernetes lab cluster managed by Flux.

## Cluster Information

- **Cluster Name**: shangkuei-lab
- **Kubernetes Version**: v1.31.x
- **Talos Version**: v1.8.x
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
  Flux syncs this repository -> kubernetes/clusters/shangkuei-lab/

GitOps-Managed Applications:
  - gateway-api -> CRDs (no dependencies - foundational API extension)
  - cilium -> CNI (depends on gateway-api - implements Gateway API)
  - cert-manager -> Certificate management (depends on gateway-api)
```

## Directory Structure

```
kubernetes/
├── base/                                      # Application definitions
│   ├── gateway-api/                           # Gateway API GitRepository
│   ├── cert-manager/                          # Certificate automation
│   ├── cilium/                                # CNI with Gateway API support
│   └── flux-instance/                         # Flux configuration
│
├── overlays/
│   └── flux-instance/shangkuei-lab/          # Flux SOPS secrets
│
└── clusters/
    └── shangkuei-lab/
        ├── kustomization.yaml                 # Root: orchestrates all resources
        ├── kustomization-gateway-api-*.yaml   # Gateway API CRDs
        ├── kustomization-cilium.yaml          # Cilium CNI
        ├── kustomization-cert-manager.yaml    # cert-manager
        ├── kustomization-flux-operator.yaml   # Flux operator
        └── kustomization-flux-instance.yaml   # Flux instance
```

## Application Dependency Graph

```
gateway-api-standard (foundational)
    │
    ├── gateway-api-experimental
    │       │
    │       └── cilium (CNI)
    │               │
    │               └── flux-operator
    │                       │
    │                       └── flux-instance
    │
    └── cert-manager
```

## Managed Applications

| Application | Type | Dependencies | Namespace |
|-------------|------|--------------|-----------|
| Gateway API | CRDs | None | N/A |
| Cilium | HelmRelease | Gateway API | kube-system |
| cert-manager | HelmRelease | Gateway API | cert-manager |
| Flux Operator | HelmRelease | Cilium | flux-system |
| Flux Instance | FluxInstance | Flux Operator | flux-system |

## Deployment and Operations

### Initial Deployment

1. **Deploy Talos cluster via Terraform**:

   ```bash
   cd terraform/environments/talos-cluster-shangkuei-lab
   make init
   make apply
   make talos-apply
   make talos-bootstrap
   make cilium-install
   ```

2. **Generate SOPS secrets for Flux**:

   ```bash
   cd kubernetes/overlays/flux-instance/shangkuei-lab
   make import-age-key AGE_KEY_FILE=~/.config/sops/age/gitops-shangkuei-lab-flux.txt
   make setup
   ```

3. **Bootstrap GitOps via Terraform**:

   ```bash
   cd terraform/environments/gitops-shangkuei-lab
   make init
   make apply
   ```

4. **Commit Kubernetes manifests**:

   ```bash
   git add kubernetes/
   git commit -m "feat(kubernetes): add shangkuei-lab GitOps configuration"
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
```

## Configuration Management

### SOPS Encryption

Sensitive values are encrypted using SOPS with age encryption.

```bash
# Use the cluster Makefile
make secret-create NAME=my-secret NAMESPACE=my-namespace

# Or use the overlays Makefile
cd kubernetes/overlays/flux-instance/shangkuei-lab
make setup
```

## References

- [Flux Documentation](https://fluxcd.io/flux/)
- [Talos Linux Documentation](https://www.talos.dev/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [cert-manager Documentation](https://cert-manager.io/)
- [Cilium Documentation](https://docs.cilium.io/)
