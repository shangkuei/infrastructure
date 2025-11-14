# Flux Operator (OLM Installation)

Flux Operator installed via OLM ClusterExtension from OperatorHub catalog.

## Overview

The Flux Operator manages Flux CD installations via FluxInstance CRDs. This installation uses
OLM (Operator Lifecycle Manager) instead of Helm for better integration with the cluster's
operator management infrastructure.

## Architecture

```
OperatorHub Catalog (olmv1-catalog)
    ↓
ClusterExtension (flux-operator)
    ↓ OLM installs operator
    ↓
Deployment (flux-operator)
    ↓ Watches for FluxInstance CRDs
    ↓
FluxInstance Resources
```

## Installation Method

### Why OLM Instead of Helm?

1. **Consistent Operator Management**: All operators managed through OLM
2. **Better Lifecycle Management**: OLM handles upgrades, dependencies, and health
3. **Catalog Integration**: Discover and install from OperatorHub catalog
4. **Bootstrap Consistency**: Matches Terraform bootstrap approach

### Components

**Namespace**:

- [namespace-flux-system.yaml](namespace-flux-system.yaml)

**RBAC Resources**:

- [serviceaccount-flux-operator-installer.yaml](serviceaccount-flux-operator-installer.yaml)
- [clusterrole-flux-operator-installer.yaml](clusterrole-flux-operator-installer.yaml)
- [clusterrolebinding-flux-operator-installer.yaml](clusterrolebinding-flux-operator-installer.yaml)

**Operator Installation**:

- [clusterextension-flux-operator.yaml](clusterextension-flux-operator.yaml)

**Bootstrap Prerequisites** (Cluster-specific SOPS overlay):

- See: [overlays/flux-instance/shangkuei-xyz-talos/](../../../overlays/flux-instance/shangkuei-xyz-talos/)

### Version

- **Package**: `flux-operator`
- **Version**: `^0.33.0` (semver compatible, auto-upgrades)
- **Channel**: `stable`
- **Source**: OperatorHub catalog (`quay.io/operatorhubio/catalog`)
- **Catalog**: `operatorhubio`

## Dependencies

```
cert-manager → olmv1 → olmv1-catalog → flux-operator
```

- **olmv1-catalog**: Provides OperatorHub catalog with flux-operator package
- **ClusterExtension CRD**: Provided by olmv1 operator-controller

## Usage

### Verify Installation

```bash
# Check ClusterExtension status
kubectl get clusterextension flux-operator

# Check operator deployment
kubectl get deployment flux-operator -n flux-system

# Check operator logs
kubectl logs -n flux-system -l app.kubernetes.io/name=flux-operator

# List available Flux packages in catalog
kubectl get packages | grep flux
```

### Expected ClusterExtension Status

```yaml
status:
  conditions:
    - type: Installed
      status: "True"
      reason: InstallSuccessful
```

### Create FluxInstance

After the operator is running, create a FluxInstance:

```yaml
apiVersion: fluxcd.controlplane.io/v1
kind: FluxInstance
metadata:
  name: flux
  namespace: flux-system
spec:
  distribution:
    version: "v2.7.3"
    registry: "ghcr.io/fluxcd"
  components:
    - source-controller
    - kustomize-controller
    - helm-controller
    - notification-controller
  sync:
    kind: GitRepository
    url: "https://github.com/user/repo"
    ref: "refs/heads/main"
    path: "./clusters/cluster-name"
```

## Troubleshooting

### ClusterExtension Not Installing

```bash
# Check ClusterExtension status
kubectl describe clusterextension flux-operator

# Check OLM operator logs
kubectl logs -n olmv1-system -l app.kubernetes.io/name=operator-controller

# Verify catalog is ready
kubectl get clustercatalog operatorhubio
```

Common issues:

- Catalog not unpacked: Wait for catalog to be ready
- Package not found: Verify package exists in catalog
- Version conflict: Check requested version exists

### Operator Pod Not Starting

```bash
# Check deployment
kubectl describe deployment flux-operator -n flux-system

# Check events
kubectl get events -n flux-system --sort-by='.lastTimestamp'

# Check ServiceAccount permissions
kubectl auth can-i '*' '*' --as=system:serviceaccount:flux-system:flux-operator-installer
```

### Upgrade Operator Version

Edit [clusterextension-flux-operator.yaml](clusterextension-flux-operator.yaml):

```yaml
spec:
  source:
    catalog:
      version: "0.9.0"  # Update version
```

OLM will automatically handle the upgrade.

## Comparison: Helm vs OLM

| Feature | Helm | OLM |
|---------|------|-----|
| Discovery | Helm repo search | Catalog browsing |
| Dependencies | Manual | Automatic |
| Upgrades | `helm upgrade` | OLM handles |
| Health checks | Manual | Built-in |
| RBAC | Chart-defined | ServiceAccount-based |
| Uninstall | `helm uninstall` | Delete ClusterExtension |

## References

- [Flux Operator Documentation](https://fluxcd.control-plane.io/operator/)
- [OLM Documentation](https://olm.operatorframework.io/)
- [OperatorHub.io](https://operatorhub.io/operator/flux-operator)
- [ClusterExtension API](https://operator-framework.github.io/operator-controller/refs/api/)
