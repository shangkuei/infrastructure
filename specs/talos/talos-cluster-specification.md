# Talos Linux Cluster Specification

Technical specification for the Talos Linux Kubernetes cluster running on Unraid VMs.

**Last Updated**: 2025-10-31
**Status**: Active
**Related ADR**: [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](../../docs/decisions/0016-talos-unraid-primary.md)

## Overview

This document specifies the technical configuration for a 2-node Talos Linux Kubernetes cluster running on Unraid VMs, designed for learning, development, and low-traffic production workloads.

## Cluster Architecture

### Node Configuration

| Component | Control Plane | Worker Node |
|-----------|--------------|-------------|
| **Role** | Kubernetes API, etcd, controllers | Application workloads |
| **vCPU** | 2 cores | 4 cores |
| **Memory** | 4 GB | 8 GB |
| **Disk** | 50 GB | 100 GB |
| **Network** | Bridged to Unraid network | Bridged to Unraid network |
| **OS** | Talos Linux 1.6+ | Talos Linux 1.6+ |

### Cluster Specifications

- **Kubernetes Version**: 1.29+ (latest stable)
- **CNI Plugin**: Flannel (default) or Cilium (advanced features)
- **Service CIDR**: 10.96.0.0/12 (default)
- **Pod CIDR**: 10.244.0.0/16 (default)
- **DNS**: CoreDNS
- **Proxy Mode**: iptables or ipvs

## Talos Configuration

### Machine Configuration

**Control Plane** (`controlplane.yaml`):

```yaml
version: v1alpha1
machine:
  type: controlplane
  token: <cluster-token>
  ca:
    crt: <ca-certificate>
    key: <ca-key>
  certSANs:
    - <control-plane-ip>
    - <tailscale-ip>
  kubelet:
    image: ghcr.io/siderolabs/kubelet:v1.29.0
    clusterDNS:
      - 10.96.0.10
    extraArgs:
      rotate-server-certificates: true
  network:
    hostname: talos-cp
    interfaces:
      - interface: eth0
        dhcp: true
  install:
    disk: /dev/sda
    image: ghcr.io/siderolabs/installer:v1.6.0
    bootloader: true
    wipe: false

cluster:
  clusterName: talos-home
  controlPlane:
    endpoint: https://<control-plane-ip>:6443
  network:
    cni:
      name: flannel
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12
  apiServer:
    certSANs:
      - <control-plane-ip>
      - <tailscale-ip>
  etcd:
    advertisedSubnets:
      - 10.244.0.0/16
```

**Worker Node** (`worker.yaml`):

```yaml
version: v1alpha1
machine:
  type: worker
  token: <cluster-token>
  ca:
    crt: <ca-certificate>
    key: <ca-key>
  kubelet:
    image: ghcr.io/siderolabs/kubelet:v1.29.0
    clusterDNS:
      - 10.96.0.10
    extraArgs:
      rotate-server-certificates: true
  network:
    hostname: talos-worker-01
    interfaces:
      - interface: eth0
        dhcp: true
  install:
    disk: /dev/sda
    image: ghcr.io/siderolabs/installer:v1.6.0
    bootloader: true
    wipe: false

cluster:
  clusterName: talos-home
  controlPlane:
    endpoint: https://<control-plane-ip>:6443
  network:
    cni:
      name: flannel
```

### Network Configuration

**Physical Network**:

- Network Type: Bridged to Unraid host network
- DHCP: Enabled (or static IPs configured in machine config)
- MTU: 1500 (default)

**Kubernetes Network**:

- CNI: Flannel (VXLAN overlay)
- Pod Network: 10.244.0.0/16
- Service Network: 10.96.0.0/12
- DNS: CoreDNS (10.96.0.10)

**Tailscale Integration**:

- Deployment: DaemonSet on all nodes
- Access: Secure VPN access to cluster from anywhere
- Subnet Routing: Optional, for exposing services

### Storage Configuration

**Local Storage**:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

**Storage Locations**:

- Path: `/opt/local-path-provisioner` (on worker nodes)
- Type: Local filesystem
- Performance: Depends on Unraid disk configuration

**Optional NFS Storage**:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
provisioner: nfs.csi.k8s.io
parameters:
  server: <unraid-ip>
  share: /mnt/user/kubernetes-storage
volumeBindingMode: Immediate
```

## Security Configuration

### Talos Security Features

**Built-in Security**:

- No SSH access (API-only management)
- Immutable root filesystem
- Minimal attack surface (no shell, no package manager)
- mTLS for all Talos API communication
- Automatic security patches via image updates

**Kubernetes Security**:

- RBAC enabled by default
- Pod Security Standards: Restricted (recommended)
- Network Policies: Enabled with Cilium CNI
- Secret encryption at rest (optional)
- Audit logging (optional)

### Access Control

**talosctl Configuration**:

```yaml
context: talos-home
contexts:
  talos-home:
    endpoints:
      - <control-plane-ip>
    nodes:
      - <control-plane-ip>
      - <worker-ip>
    ca: <ca-certificate>
    crt: <client-certificate>
    key: <client-key>
```

**kubectl Configuration**:

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: <ca-data>
    server: https://<control-plane-ip>:6443
  name: talos-home
contexts:
- context:
    cluster: talos-home
    user: admin@talos-home
  name: admin@talos-home
current-context: admin@talos-home
users:
- name: admin@talos-home
  user:
    client-certificate-data: <client-cert-data>
    client-key-data: <client-key-data>
```

## Monitoring and Observability

### Metrics Collection

**Node Metrics**:

- Talos built-in metrics endpoint
- Kubernetes metrics-server
- Node exporter (via Prometheus)

**Cluster Metrics**:

- kube-state-metrics
- CoreDNS metrics
- etcd metrics (from control plane)

### Logging

**System Logs**:

```bash
# View control plane logs
talosctl logs -n <control-plane-ip> -f controller-runtime

# View kubelet logs
talosctl logs -n <node-ip> -f kubelet

# View containerd logs
talosctl logs -n <node-ip> -f containerd
```

**Application Logs**:

- kubectl logs for pod logs
- Loki for centralized logging (optional)

### Health Checks

**Cluster Health**:

```bash
# Talos health check
talosctl health --wait-timeout=10m

# Kubernetes health
kubectl get nodes
kubectl get pods -A
kubectl get componentstatuses
```

## Backup and Recovery

### Configuration Backup

**Talos Configuration**:

```bash
# Backup machine configs
cp controlplane.yaml backups/controlplane-$(date +%Y%m%d).yaml
cp worker.yaml backups/worker-$(date +%Y%m%d).yaml
cp talosconfig backups/talosconfig-$(date +%Y%m%d)
```

**Store in Git**:

- All configuration files stored in repository
- Sensitive data encrypted with git-crypt or sealed secrets

### etcd Backup

**Manual Backup**:

```bash
# Create etcd snapshot
talosctl -n <control-plane-ip> etcd snapshot ./etcd-backup-$(date +%Y%m%d).db

# Upload to Cloudflare R2
aws s3 cp etcd-backup-$(date +%Y%m%d).db s3://my-bucket/etcd-backups/
```

**Automated Backup** (recommended):

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: etcd-backup
            image: alpine:latest
            command:
            - /bin/sh
            - -c
            - |
              # Backup script here
          restartPolicy: OnFailure
```

### Disaster Recovery

**Recovery Steps**:

1. **Rebuild VMs**: Create new VMs with same specifications
2. **Restore Configuration**: Apply saved machine configs
3. **Restore etcd**: Restore etcd snapshot if needed
4. **Verify Cluster**: Validate all nodes and services

**Recovery Time Objective (RTO)**: 1-2 hours
**Recovery Point Objective (RPO)**: 24 hours (with daily backups)

## Maintenance Procedures

### Updating Talos

**Update Process**:

```bash
# Check current version
talosctl version

# Update Talos (rolling update)
talosctl upgrade --nodes <control-plane-ip> \
  --image ghcr.io/siderolabs/installer:v1.7.0

talosctl upgrade --nodes <worker-ip> \
  --image ghcr.io/siderolabs/installer:v1.7.0
```

### Updating Kubernetes

**Update Process**:

```bash
# Check current version
kubectl version

# Update Kubernetes
talosctl upgrade-k8s --nodes <control-plane-ip> --to 1.30.0
```

### Node Maintenance

**Drain Node**:

```bash
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

**Uncordon Node**:

```bash
kubectl uncordon <node-name>
```

## Performance Tuning

### Resource Allocation

**Control Plane**:

- Reserved memory: ~1.5GB for system components
- Available: ~2.5GB for control plane workloads
- Not recommended to run application pods

**Worker Node**:

- Reserved memory: ~500MB for system components
- Available: ~7.5GB for application workloads
- CPU pinning: Not configured (can be added if needed)

### Optimization Tips

**For Learning/Development**:

- Default configuration is sufficient
- Monitor resource usage with Prometheus

**For Production Workloads**:

- Increase worker node resources as needed
- Add more worker nodes for horizontal scaling
- Consider CPU/memory limits on pods
- Implement pod disruption budgets

## Troubleshooting

### Common Issues

**Node Not Ready**:

```bash
# Check node status
kubectl describe node <node-name>

# Check Talos services
talosctl -n <node-ip> services

# Check kubelet logs
talosctl -n <node-ip> logs kubelet
```

**Pod Scheduling Issues**:

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes
kubectl describe node <node-name>
```

**Network Issues**:

```bash
# Check CNI pods
kubectl get pods -n kube-system -l k8s-app=flannel

# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check network policies
kubectl get networkpolicies -A
```

## Scaling Strategy

### Adding Worker Nodes

**Steps**:

1. Create new VM with worker specifications
2. Boot from Talos ISO
3. Generate worker configuration
4. Apply configuration
5. Verify node joined cluster

**Commands**:

```bash
# Generate worker config
talosctl gen config --output-types worker > worker-02.yaml

# Apply config
talosctl apply-config --insecure --nodes <new-worker-ip> --file worker-02.yaml

# Verify
kubectl get nodes
```

### Converting to HA Control Plane

**Requirements**:

- Minimum 3 control plane nodes
- Load balancer for control plane endpoint (optional but recommended)

**Not covered in initial setup** - See Talos documentation for HA configuration

## References

- [Talos Linux Documentation](https://www.talos.dev/latest/)
- [Talos Configuration Reference](https://www.talos.dev/latest/reference/configuration/)
- [Talos API Reference](https://www.talos.dev/latest/reference/api/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ADR-0016: Talos Linux on Unraid](../../docs/decisions/0016-talos-unraid-primary.md)
