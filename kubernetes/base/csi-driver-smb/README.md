# SMB CSI Driver for Kubernetes

This directory contains Flux CD manifests for deploying the SMB CSI driver on the Talos Linux cluster.

## Overview

The SMB CSI driver enables Kubernetes to use SMB/CIFS shares as persistent volumes. This is useful for:

- Backup storage
- Volume snapshots
- Shared storage across multiple pods
- Integration with existing SMB/CIFS file servers

## Components

- **Namespace**: `kube-system` (system component)
- **Helm Repository**: https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
- **HelmRelease**: Managed by Flux CD

## Prerequisites

1. SMB/CIFS server accessible from the Kubernetes cluster
2. Network connectivity between nodes and SMB server
3. Cilium CNI deployed and ready

## Usage Examples

### 1. Create Secret for SMB Credentials

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: smb-credentials
  namespace: default
type: Opaque
stringData:
  username: "myuser"
  password: "mypassword"
```

### 2. StorageClass for SMB

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: smb
provisioner: smb.csi.k8s.io
parameters:
  # SMB server address
  source: "//smb-server.example.com/share"

  # Sub-directory within the share (optional)
  # subDir: "backups"

  # Mount options
  csi.storage.k8s.io/provisioner-secret-name: "smb-credentials"
  csi.storage.k8s.io/provisioner-secret-namespace: "default"
  csi.storage.k8s.io/node-stage-secret-name: "smb-credentials"
  csi.storage.k8s.io/node-stage-secret-namespace: "default"

# Reclaim policy
reclaimPolicy: Retain

# Volume binding mode
volumeBindingMode: Immediate

# Allow volume expansion
allowVolumeExpansion: true
```

### 3. PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-smb-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany  # SMB supports multiple readers/writers
  storageClassName: smb
  resources:
    requests:
      storage: 10Gi
```

### 4. VolumeSnapshotClass for SMB Snapshots

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: smb-snapshot
driver: smb.csi.k8s.io
deletionPolicy: Delete
parameters:
  # Snapshot parameters specific to your SMB setup
  csi.storage.k8s.io/snapshotter-secret-name: "smb-credentials"
  csi.storage.k8s.io/snapshotter-secret-namespace: "default"
```

### 5. VolumeSnapshot

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-smb-snapshot
  namespace: default
spec:
  volumeSnapshotClassName: smb-snapshot
  source:
    persistentVolumeClaimName: my-smb-pvc
```

### 6. Restore from Snapshot

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-from-snapshot
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: smb
  dataSource:
    name: my-smb-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: 10Gi
```

### 7. Using in a Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-using-smb
  namespace: default
spec:
  containers:
    - name: app
      image: nginx:latest
      volumeMounts:
        - name: smb-storage
          mountPath: /data
  volumes:
    - name: smb-storage
      persistentVolumeClaim:
        claimName: my-smb-pvc
```

## Advanced Configuration

### Static Provisioning (Pre-existing SMB Share)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: smb-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: smb
  mountOptions:
    - dir_mode=0777
    - file_mode=0777
    - vers=3.0
  csi:
    driver: smb.csi.k8s.io
    readOnly: false
    volumeHandle: smb-server.example.com/share##pv-name
    volumeAttributes:
      source: "//smb-server.example.com/share"
    nodeStageSecretRef:
      name: smb-credentials
      namespace: default
```

### Mount Options

Common SMB mount options you can add to StorageClass:

```yaml
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1000
  - gid=1000
  - vers=3.0           # SMB version (2.0, 2.1, 3.0, 3.1.1)
  - noperm             # Don't check permissions client-side
  - mfsymlinks         # Support for symbolic links
  - cache=strict       # Caching mode (strict, none, loose)
```

## Troubleshooting

### Check CSI Driver Status

```bash
# Check driver pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=csi-driver-smb

# Check CSI driver
kubectl get csidriver smb.csi.k8s.io

# Check storage class
kubectl get storageclass smb
```

### Common Issues

1. **Mount failures**: Check network connectivity to SMB server
2. **Permission denied**: Verify credentials in secret
3. **Version incompatibility**: Adjust `vers` mount option
4. **Snapshot failures**: Ensure snapshot-controller is running

### View Logs

```bash
# Controller logs
kubectl logs -n kube-system -l app=csi-smb-controller

# Node plugin logs
kubectl logs -n kube-system -l app=csi-smb-node
```

## References

- [SMB CSI Driver GitHub](https://github.com/kubernetes-csi/csi-driver-smb)
- [Kubernetes CSI Documentation](https://kubernetes-csi.github.io/docs/)
- [Volume Snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)
