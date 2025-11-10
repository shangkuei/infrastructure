# OpenEBS Storage for Talos Cluster

OpenEBS provides dynamic local storage provisioning for the Kubernetes cluster using the LocalPV Hostpath engine.

## Configuration

- **Version**: 4.2.0 (stable)
- **Engine**: LocalPV Hostpath (optimized for Talos)
- **Storage Class**: `openebs-hostpath` (default)
- **Base Path**: `/var/openebs/local` (Talos persistent storage)

## Architecture

```text
┌─────────────────────────────────────────────────────┐
│              OpenEBS LocalPV Hostpath               │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐         ┌──────────────┐        │
│  │  Provisioner │◄────────┤ StorageClass │        │
│  │  Controller  │         │   (Default)  │        │
│  └──────┬───────┘         └──────────────┘        │
│         │                                          │
│         ▼                                          │
│  ┌─────────────────────────────────────┐          │
│  │    /var/openebs/local (Hostpath)    │          │
│  │    - PV directories per volume      │          │
│  │    - Persisted across reboots       │          │
│  └─────────────────────────────────────┘          │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Features

- **Dynamic Provisioning**: Automatic PV creation on-demand
- **Default Storage Class**: Automatically used when no class specified
- **Talos Compatible**: Uses `/var/openebs/local` for persistence
- **Simple Setup**: No additional storage backends required
- **Reclaim Policy**: Delete (automatically cleans up when PVC deleted)

## Talos-Specific Considerations

### Storage Path

OpenEBS LocalPV uses `/var/openebs/local` which is:

- Persistent across Talos reboots
- Located in the Talos stateful partition
- Automatically created by OpenEBS if missing

### Node Requirements

- **Minimum**: No specific hardware requirements
- **Recommended**: Separate disk/partition for `/var` on worker nodes
- **Talos Version**: Compatible with Talos 1.6+

### Limitations

1. **No Replication**: Data is local to each node (use for non-critical workloads)
2. **No High Availability**: Pod restart on different node loses data
3. **Node Affinity**: Pods are bound to nodes where data resides

### When to Use

✅ **Good for**:

- Development environments
- Stateful sets with known node placement
- Caching layers
- Temporary storage
- CI/CD pipelines

❌ **Not suitable for**:

- Production databases requiring HA
- Multi-replica applications needing shared storage
- Applications requiring cross-node data access

## Usage Example

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
  namespace: default
spec:
  # storageClassName not needed - uses default openebs-hostpath
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  namespace: default
spec:
  containers:
    - name: app
      image: nginx:latest
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: my-app-data
```

## Verification

After deployment, verify OpenEBS is working:

```bash
# Check OpenEBS pods
kubectl get pods -n openebs

# Check storage class
kubectl get storageclass

# Expected output:
# NAME                        PROVISIONER
# openebs-hostpath (default)  openebs.io/local
```

## Deployment Order

OpenEBS is deployed in **Layer 4** of the cluster bootstrap:

1. Gateway API CRDs
2. Cilium CNI
3. cert-manager
4. **OpenEBS** ← Current layer
5. OLM operator-controller
6. OLM ClusterCatalog
7. Flux Operator
8. Flux Instance

**Dependencies**:

- Requires Cilium CNI for pod networking
- No dependencies on cert-manager or other components

## Troubleshooting

### Pods stuck in ContainerCreating

```bash
# Check PVC status
kubectl get pvc -A

# Check PV status
kubectl get pv

# Check OpenEBS logs
kubectl logs -n openebs deployment/openebs-localpv-provisioner
```

### Storage not provisioning

```bash
# Verify storage class exists and is default
kubectl get storageclass openebs-hostpath -o yaml

# Check if provisioner is running
kubectl get deployment -n openebs openebs-localpv-provisioner
```

### Node storage issues

```bash
# Check node storage capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check Talos disk usage
talosctl -n <node-ip> df /var
```

## Future Enhancements

For production workloads requiring high availability, consider:

1. **OpenEBS Mayastor**: Replicated storage with NVMe performance
2. **Longhorn**: Cloud-native distributed block storage
3. **Rook-Ceph**: Full-featured distributed storage system

## References

- [OpenEBS Documentation](https://openebs.io/docs)
- [OpenEBS LocalPV Guide](https://openebs.io/docs/user-guides/localpv-hostpath)
- [Talos Storage Guide](https://www.talos.dev/latest/kubernetes-guides/configuration/storage/)
- [ADR-0016: Talos Linux on Unraid](../../docs/decisions/0016-talos-unraid-primary.md)
