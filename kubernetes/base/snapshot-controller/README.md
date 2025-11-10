# Snapshot Controller for Kubernetes

This directory contains Flux CD manifests for deploying the Volume Snapshot Controller on the Talos Linux cluster.

## Overview

The Snapshot Controller is a Kubernetes component that manages the lifecycle of volume snapshots. It works with CSI drivers (like SMB CSI driver) to provide snapshot functionality.

## Components

- **Namespace**: `kube-system` (system component)
- **GitRepository**: Official kubernetes-csi/external-snapshotter (v8.4.0)
- **ArtifactGenerator**: Extracts CRDs and controller manifests
- **Deployment**: Managed by Flux CD via GitOps

## Architecture

The snapshot controller consists of:

1. **Snapshot Controller**: Watches VolumeSnapshot CRDs and triggers snapshot creation
2. **CSI External Snapshotter**: Sidecar container that communicates with CSI drivers

## Prerequisites

1. Kubernetes 1.20+ with CSI snapshot CRDs
2. CSI driver with snapshot support (e.g., csi-driver-smb, OpenEBS)
3. Cilium CNI deployed and ready

## CRDs (Custom Resource Definitions)

The snapshot controller requires these CRDs (installed automatically):

- `VolumeSnapshotClass`: Defines how snapshots are created
- `VolumeSnapshot`: Represents a snapshot request
- `VolumeSnapshotContent`: Represents the actual snapshot

## Usage

### Check Installation

```bash
# Check snapshot controller deployment
kubectl get deployment -n kube-system -l app.kubernetes.io/name=snapshot-controller

# Check snapshot CRDs
kubectl get crd | grep snapshot

# List snapshot classes
kubectl get volumesnapshotclass
```

### Working with Snapshots

See the [SMB CSI Driver README](../csi-driver-smb/README.md) for complete examples of:

- Creating VolumeSnapshotClass
- Taking snapshots
- Restoring from snapshots

## Configuration

The snapshot controller is deployed from the official kubernetes-csi/external-snapshotter repository using Flux CD GitRepository and ArtifactGenerator.

### Source Configuration

```yaml
# gitrepository-snapshot-controller.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: snapshot-controller
  namespace: flux-system
spec:
  url: https://github.com/kubernetes-csi/external-snapshotter
  ref:
    tag: v8.4.0  # PINNED version
  interval: 24h
```

### Artifact Extraction

```yaml
# artifactgenerator-snapshot-controller.yaml
artifacts:
  # VolumeSnapshot CRDs
  - name: snapshot-controller-crds
    copy:
      - from: "@repo/client/config/crd/**"

  # Snapshot Controller deployment and RBAC
  - name: snapshot-controller-deploy
    copy:
      - from: "@repo/deploy/kubernetes/snapshot-controller/**"
```

Default resource limits from upstream manifests are suitable for most deployments. For custom resource limits, use Kustomize patches.

## Monitoring

### Check Controller Logs

```bash
# View controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=snapshot-controller

# Follow logs in real-time
kubectl logs -n kube-system -l app.kubernetes.io/name=snapshot-controller -f
```

### Verify Snapshot Operations

```bash
# List all snapshots
kubectl get volumesnapshot --all-namespaces

# Describe a specific snapshot
kubectl describe volumesnapshot <snapshot-name> -n <namespace>

# Check snapshot status
kubectl get volumesnapshot <snapshot-name> -n <namespace> -o jsonpath='{.status.readyToUse}'
```

## Troubleshooting

### Common Issues

1. **Snapshot creation stuck**: Check CSI driver logs
2. **CRD not found**: Ensure snapshot CRDs are installed
3. **Permission errors**: Check RBAC configuration

### Debug Commands

```bash
# Check snapshot controller status
kubectl get pods -n kube-system -l app.kubernetes.io/name=snapshot-controller

# View events in kube-system (filter by label if needed)
kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep snapshot

# Check CSI driver compatibility
kubectl get csidriver
```

### Validation

```bash
# Test snapshot creation
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: test-snapshot
  namespace: default
spec:
  volumeSnapshotClassName: smb-snapshot
  source:
    persistentVolumeClaimName: <your-pvc-name>
EOF

# Check snapshot status
kubectl get volumesnapshot test-snapshot -n default

# Clean up test
kubectl delete volumesnapshot test-snapshot -n default
```

## Integration with CSI Drivers

The snapshot controller works with any CSI driver that implements the snapshot capability:

- **SMB CSI Driver**: For SMB/CIFS shares
- **OpenEBS**: For local and replicated storage
- **Other CSI Drivers**: Any driver with snapshot support

## Best Practices

1. **Retention Policy**: Define appropriate snapshot retention in VolumeSnapshotClass
2. **Testing**: Regularly test snapshot and restore procedures
3. **Monitoring**: Set up alerts for snapshot failures
4. **Scheduling**: Use tools like Velero for automated snapshot scheduling
5. **Storage**: Ensure sufficient storage space for snapshots

## References

- [Kubernetes Volume Snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)
- [CSI External Snapshotter](https://github.com/kubernetes-csi/external-snapshotter)
- [Volume Snapshot API](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/volume-snapshot-v1/)
