# OLM v1 ClusterCatalog Resources

ClusterCatalog resources for OLM v1, deployed AFTER operator-controller CRDs are installed.

## Dependency Chain

```
cert-manager (HelmRelease)
    ↓
olmv1 (operator-controller via ExternalArtifact)
    ↓ Installs ClusterCatalog CRD
    ↓ Waits for operator-controller Deployment
    ↓
olmv1-catalog (ClusterCatalog resources) ← YOU ARE HERE
    ↓
operatorhubio ClusterCatalog is ready
```

## Why Separate from olmv1?

The `ClusterCatalog` CRD is provided by the operator-controller. If we deploy ClusterCatalog resources in the same Flux Kustomization as the operator-controller, we get a race condition:

```
❌ BAD: Same Kustomization
olmv1 Kustomization
├── GitRepository
├── ArtifactGenerator
└── ClusterCatalog ← Fails! CRD doesn't exist yet
```

```
✅ GOOD: Separate Kustomizations
olmv1 Kustomization
├── GitRepository
├── ArtifactGenerator (installs CRDs)
└── Health check (waits for operator-controller)

olmv1-catalog Kustomization (dependsOn: olmv1)
└── ClusterCatalog ← Succeeds! CRD exists
```

## Resources

### ClusterCatalog: operatorhubio

[clustercatalog-operatorhub.yaml](clustercatalog-operatorhub.yaml)

Provides access to community operators from operatorhub.io:

- **Catalog**: `quay.io/operatorhubio/catalog:latest`
- **Poll Interval**: 60 minutes
- **Source Type**: Image-based catalog

## Usage

### List Available Operators

```bash
# List all packages in the catalog
kubectl get packages -l olm.operatorframework.io/catalog=operatorhubio

# Search for specific operator
kubectl get packages -l olm.operatorframework.io/catalog=operatorhubio | grep <operator-name>

# Get package details
kubectl get package <package-name> -o yaml
```

### Install an Operator

Create a ClusterExtension resource:

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
  serviceAccount:
    name: my-operator-installer
```

## Troubleshooting

### ClusterCatalog Not Ready

```bash
# Check catalog status
kubectl get clustercatalog operatorhubio -o yaml

# Check catalogd logs
kubectl logs -n olmv1-system -l app=catalogd

# Check for unpacking errors
kubectl describe clustercatalog operatorhubio
```

Expected status conditions:

- `Unpacked: True` - Catalog successfully unpacked
- `Ready: True` - Catalog is ready to serve packages

### CRD Not Found Error

If you see `no matches for kind "ClusterCatalog"`, the olmv1 operator-controller is not ready yet:

```bash
# Check olmv1 Kustomization status
kubectl get kustomization olmv1 -n flux-system

# Check operator-controller deployment
kubectl get deployment -n olmv1-system operator-controller-controller-manager

# Check CRD exists
kubectl get crd clustercatalogs.olm.operatorframework.io
```

## References

- [OLM v1 Documentation](https://operator-framework.github.io/operator-controller/)
- [OperatorHub.io](https://operatorhub.io/)
- [ClusterCatalog API](https://operator-framework.github.io/operator-controller/refs/api/)
