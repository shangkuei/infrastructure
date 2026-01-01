# OpenEBS Storage for shangkuei-lab Cluster

This overlay configures OpenEBS with multiple storage backends for the shangkuei-lab cluster.

## Storage Configuration

| Node | Storage Backend | Storage Class | Use Case |
|------|-----------------|---------------|----------|
| worker-1 | Mayastor | `openebs-mayastor` | Replicated NVMe storage |
| worker-2 | Mayastor | `openebs-mayastor` | Replicated NVMe storage |
| worker-3 | Mayastor | `openebs-mayastor` | Replicated NVMe storage |
| worker-4 | ZFS LocalPV | `openebs-zfs` | Local ZFS storage |
| All nodes | LocalPV Hostpath | `openebs-hostpath` | Simple local storage (default) |

## VM Environment Requirements

This cluster runs on VMs (Proxmox/KVM), requiring special DPDK configuration:

- **`--iova-mode=pa`**: Required for Mayastor io-engine in virtualized environments
  - Fixes DPDK EAL initialization failure: "IOVA exceeding limits of current DMA mask"
  - Uses Physical Address mode instead of Virtual Address mode
  - Automatically configured in the overlay

## Node Labels (Terraform-Managed)

Node labels are automatically applied by Terraform based on node configuration:

| Node Config | Auto-Applied Label | Condition |
|-------------|-------------------|-----------|
| `openebs_storage = true` | `openebs.io/engine=mayastor` | Mayastor storage enabled |
| `openebs_storage = true` | `openebs.io/storage-node=true` | Mayastor storage enabled |
| `zfs_pools = [...]` | `openebs.io/zfs=true` | ZFS pools configured |

**Example Terraform configuration:**

```hcl
worker_nodes = {
  # Mayastor nodes
  worker-1 = {
    openebs_storage = true
    openebs_disk    = "/dev/nvme0n1"
    # ...
  }
  # ZFS node
  worker-4 = {
    zfs_pools = [{
      name  = "zpool"
      disks = ["/dev/sda"]
      # ...
    }]
    # ...
  }
}
```

After `terraform apply`, verify labels:

```bash
kubectl get nodes --show-labels | grep -E 'openebs.io/(engine|zfs)'
```

## Storage Classes

After deployment, three storage classes are available:

```bash
kubectl get storageclass

# Expected output:
# NAME                        PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      AGE
# openebs-hostpath (default)  openebs.io/local               Delete          WaitForFirstConsumer   5m
# openebs-zfs                 zfs.csi.openebs.io             Delete          WaitForFirstConsumer   5m
# openebs-mayastor            io.openebs.csi-mayastor        Delete          WaitForFirstConsumer   5m
```

---

## Testing Guide

### Prerequisites

```bash
# Verify OpenEBS is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=openebs

# Create test namespace
kubectl create namespace openebs-test
```

---

## Test 1: LocalPV Hostpath (Default)

### Create PVC and Pod

```bash
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-hostpath-pvc
  namespace: openebs-test
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  # Uses default storage class (openebs-hostpath)
---
apiVersion: v1
kind: Pod
metadata:
  name: test-hostpath-pod
  namespace: openebs-test
spec:
  containers:
  - name: test
    image: busybox:latest
    command: ["sh", "-c", "echo 'Hostpath test' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-hostpath-pvc
EOF
```

### Verify

```bash
# Check PVC is bound
kubectl get pvc -n openebs-test test-hostpath-pvc

# Verify data
kubectl exec -n openebs-test test-hostpath-pod -- cat /data/test.txt
```

---

## Test 2: ZFS LocalPV (worker-4)

### Create PVC and Pod

```bash
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-zfs-pvc
  namespace: openebs-test
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: openebs-zfs
  resources:
    requests:
      storage: 2Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-zfs-pod
  namespace: openebs-test
spec:
  containers:
  - name: test
    image: busybox:latest
    command: ["sh", "-c", "echo 'ZFS test data' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-zfs-pvc
EOF
```

### Verify

```bash
# Check PVC is bound
kubectl get pvc -n openebs-test test-zfs-pvc

# Verify pod is scheduled on worker-4 (ZFS node)
kubectl get pod -n openebs-test test-zfs-pod -o wide

# Verify data
kubectl exec -n openebs-test test-zfs-pod -- cat /data/test.txt

# Check ZFS volumes via OpenEBS CRD
kubectl get zfsvolumes -A
```

### ZFS Features Test

```bash
# Test compression (data should compress well)
kubectl exec -n openebs-test test-zfs-pod -- sh -c '
  dd if=/dev/zero of=/data/zeros bs=1M count=100
  ls -lh /data/zeros
'

# Check ZFS volume properties via OpenEBS CRD
kubectl get zfsvolumes -A -o wide
```

---

## Test 3: Mayastor (worker-1,2,3)

### Verify Mayastor Components

```bash
# Check Mayastor pods are running
kubectl get pods -n kube-system -l app=io-engine

# Check disk pools
kubectl get diskpools -n kube-system

# Check Mayastor nodes (io-engine status)
kubectl get pods -n kube-system -l app=io-engine -o wide
```

### Create PVC and Pod

```bash
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-mayastor-pvc
  namespace: openebs-test
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: openebs-mayastor
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-mayastor-pod
  namespace: openebs-test
spec:
  containers:
  - name: test
    image: busybox:latest
    command: ["sh", "-c", "echo 'Mayastor replicated test' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-mayastor-pvc
EOF
```

### Verify

```bash
# Check PVC is bound
kubectl get pvc -n openebs-test test-mayastor-pvc

# Check PV details (shows Mayastor CSI info)
kubectl get pv -o wide | grep mayastor

# Check disk pool usage
kubectl get diskpools -n kube-system -o wide

# Verify data
kubectl exec -n openebs-test test-mayastor-pod -- cat /data/test.txt
```

### Replica Failover Test

```bash
# Check disk pool status before test
kubectl get diskpools -n kube-system -o wide

# Simulate node failure (drain a Mayastor node)
kubectl drain shangkuei-lab-worker-02 --ignore-daemonsets --delete-emptydir-data

# Verify volume remains accessible
kubectl exec -n openebs-test test-mayastor-pod -- cat /data/test.txt

# Restore node
kubectl uncordon shangkuei-lab-worker-02

# Verify disk pools recover
kubectl get diskpools -n kube-system -o wide
```

---

## Test 4: Performance Comparison

### Create Performance Test Pods

```bash
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: perf-hostpath
  namespace: openebs-test
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: perf-zfs
  namespace: openebs-test
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: openebs-zfs
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: perf-mayastor
  namespace: openebs-test
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: openebs-mayastor
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: fio-hostpath
  namespace: openebs-test
spec:
  containers:
  - name: fio
    image: nixery.dev/fio
    command: ["tail", "-f", "/dev/null"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: perf-hostpath
---
apiVersion: v1
kind: Pod
metadata:
  name: fio-zfs
  namespace: openebs-test
spec:
  containers:
  - name: fio
    image: nixery.dev/fio
    command: ["tail", "-f", "/dev/null"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: perf-zfs
---
apiVersion: v1
kind: Pod
metadata:
  name: fio-mayastor
  namespace: openebs-test
spec:
  containers:
  - name: fio
    image: nixery.dev/fio
    command: ["tail", "-f", "/dev/null"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: perf-mayastor
EOF
```

### Run Performance Tests

```bash
# Sequential write test (1MB blocks) - measures throughput in MB/s
for pod in fio-hostpath fio-zfs fio-mayastor; do
  echo "=== Sequential Write: $pod ==="
  kubectl exec -n openebs-test $pod -- fio \
    --name=seqwrite \
    --directory=/data \
    --rw=write \
    --bs=1M \
    --size=1G \
    --numjobs=1 \
    --runtime=30s \
    --time_based \
    --group_reporting \
    --output-format=json | grep -E '"bw"|"iops"' | head -4
done

# Random 4K read/write IOPS test - measures IOPS
for pod in fio-hostpath fio-zfs fio-mayastor; do
  echo "=== Random 4K IOPS: $pod ==="
  kubectl exec -n openebs-test $pod -- fio \
    --name=randrw \
    --directory=/data \
    --rw=randrw \
    --bs=4k \
    --size=512M \
    --numjobs=4 \
    --runtime=30s \
    --time_based \
    --group_reporting \
    --output-format=json | grep -E '"bw"|"iops"' | head -4
done
```

### Understanding Results

**Key metrics:**

- **bw** (bandwidth): Throughput in KB/s (divide by 1024 for MB/s)
- **iops**: I/O operations per second

**Typical ranges (varies by hardware):**

| Metric | HDD | SATA SSD | NVMe SSD |
|--------|-----|----------|----------|
| Sequential Write | 100-200 MB/s | 400-550 MB/s | 1,000-3,500 MB/s |
| Random 4K IOPS | 100-200 | 20,000-90,000 | 100,000-500,000 |

### Expected Performance Characteristics

| Storage Class | Sequential Write | Random IOPS | Notes |
|---------------|------------------|-------------|-------|
| openebs-hostpath | Highest | Highest | Direct disk, no overhead |
| openebs-zfs | High | High | Compression may improve effective throughput |
| openebs-mayastor | Medium | Medium | Network replication overhead, but HA |

---

## Test 5: Data Persistence

### Test Pod Recreation

```bash
# Write unique data
kubectl exec -n openebs-test test-zfs-pod -- sh -c 'date > /data/timestamp.txt'
kubectl exec -n openebs-test test-zfs-pod -- cat /data/timestamp.txt

# Delete pod (keep PVC)
kubectl delete pod -n openebs-test test-zfs-pod

# Recreate pod with same PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-zfs-pod
  namespace: openebs-test
spec:
  containers:
  - name: test
    image: busybox:latest
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-zfs-pvc
EOF

# Verify data persisted
kubectl wait --for=condition=ready pod/test-zfs-pod -n openebs-test --timeout=60s
kubectl exec -n openebs-test test-zfs-pod -- cat /data/timestamp.txt
```

---

## Cleanup

```bash
# Delete all test resources
kubectl delete namespace openebs-test

# Verify PVs are cleaned up
kubectl get pv | grep openebs-test

# Check disk pool status
kubectl get diskpools -n kube-system
```

---

## Troubleshooting

### PVC Stuck in Pending

```bash
# Check storage class exists
kubectl get storageclass

# Check provisioner logs
kubectl logs -n kube-system deployment/openebs-localpv-provisioner
kubectl logs -n kube-system deployment/openebs-zfs-controller

# For Mayastor
kubectl logs -n kube-system -l app=io-engine
```

### Mayastor Volume Not Creating

```bash
# Check disk pools are healthy
kubectl get diskpools -n kube-system -o wide

# Check if hugepages are available
kubectl describe node worker-1 | grep -i hugepages

# Check Mayastor CSI driver
kubectl get csidrivers io.openebs.csi-mayastor
```

### ZFS Volume Issues

```bash
# Check ZFS volumes and snapshots via OpenEBS CRDs
kubectl get zfsvolumes -A
kubectl get zfssnapshots -A
kubectl get zfsnodes -A

# Check ZFS LocalPV logs
kubectl logs -n kube-system deployment/openebs-zfs-localpv-controller
```

---

## References

- [OpenEBS Documentation](https://openebs.io/docs)
- [Mayastor User Guide](https://openebs.io/docs/user-guides/replicated-storage-user-guide/replicated-pv-mayastor/rs-installation)
- [ZFS LocalPV Guide](https://openebs.io/docs/user-guides/local-storage-user-guide/local-pv-zfs/zfs-installation)
- [Detailed Testing Guide](../../../docs/guides/openebs-localpv-testing-guide.md)
