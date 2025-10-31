# Runbook 0003: Talos Kubernetes Operations

Operational procedures for managing the Talos Linux Kubernetes cluster on Unraid.

**Last Updated**: 2025-10-31
**Status**: Active
**Related ADR**: [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](../decisions/0016-talos-unraid-primary.md)
**Related Spec**: [Talos Cluster Specification](../../specs/talos/talos-cluster-specification.md)

## Quick Reference

### Essential Commands

```bash
# Cluster health check
talosctl health --wait-timeout=10m

# Get node status
kubectl get nodes -o wide

# View all pods
kubectl get pods -A

# Access node logs
talosctl logs -n <node-ip> -f kubelet

# Create etcd snapshot
talosctl -n <control-plane-ip> etcd snapshot ./backup.db
```

### Emergency Contacts

- **Documentation**: https://www.talos.dev/latest/
- **Community**: https://slack.dev.talos.dev/
- **GitHub Issues**: https://github.com/siderolabs/talos/issues

## Daily Operations

### Morning Checks

**1. Verify Cluster Health**:

```bash
# Check Talos health
talosctl health

# Check node status
kubectl get nodes

# Check critical pods
kubectl get pods -n kube-system
kubectl get pods -n ingress-nginx
kubectl get pods -n monitoring
```

**2. Review Resource Usage**:

```bash
# Node resources
kubectl top nodes

# Pod resources (top consumers)
kubectl top pods -A --sort-by=memory | head -20
kubectl top pods -A --sort-by=cpu | head -20
```

**3. Check for Issues**:

```bash
# Pods not running
kubectl get pods -A | grep -v Running | grep -v Completed

# Recent events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Node conditions
kubectl describe nodes | grep -A 5 Conditions
```

### Weekly Tasks

**1. Configuration Backup**:

```bash
# Backup etcd
talosctl -n <control-plane-ip> etcd snapshot ./backups/etcd-backup-$(date +%Y%m%d).db

# Verify backup
ls -lh ./backups/

# Upload to Cloudflare R2 (optional)
# Configure AWS CLI with R2 credentials
aws s3 cp ./backups/etcd-backup-$(date +%Y%m%d).db \
  s3://my-terraform-state/etcd-backups/
```

**2. Update Check**:

```bash
# Check Talos version
talosctl version

# Check Kubernetes version
kubectl version

# Check for available updates
# Visit https://github.com/siderolabs/talos/releases
```

**3. Log Review**:

```bash
# Review control plane logs for errors
talosctl logs -n <control-plane-ip> controller-runtime | grep -i error | tail -50

# Review kubelet logs for issues
talosctl logs -n <worker-ip> kubelet | grep -i error | tail -50
```

## Routine Maintenance

### Update Talos Linux

**Preparation**:

```bash
# 1. Backup current configuration
cp talosconfig backups/talosconfig-$(date +%Y%m%d)

# 2. Create etcd snapshot
talosctl -n <control-plane-ip> etcd snapshot ./backups/pre-update-etcd-$(date +%Y%m%d).db

# 3. Check release notes
# Visit https://github.com/siderolabs/talos/releases
```

**Update Control Plane**:

```bash
# Update control plane node
talosctl upgrade --nodes <control-plane-ip> \
  --image ghcr.io/siderolabs/installer:v1.7.0 \
  --preserve

# Wait for node to come back up (5-10 minutes)
watch kubectl get nodes

# Verify control plane health
talosctl -n <control-plane-ip> health
```

**Update Worker Nodes**:

```bash
# Drain worker node
kubectl drain <worker-node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force

# Update worker node
talosctl upgrade --nodes <worker-ip> \
  --image ghcr.io/siderolabs/installer:v1.7.0 \
  --preserve

# Wait for node to come back up
watch kubectl get nodes

# Uncordon worker node
kubectl uncordon <worker-node-name>

# Verify pods are running
kubectl get pods -A -o wide
```

### Update Kubernetes

**Preparation**:

```bash
# 1. Check current version
kubectl version --short

# 2. Review Kubernetes release notes
# Visit https://kubernetes.io/releases/

# 3. Verify compatibility with Talos
# Check https://www.talos.dev/latest/introduction/support-matrix/

# 4. Backup etcd
talosctl -n <control-plane-ip> etcd snapshot ./backups/pre-k8s-update-$(date +%Y%m%d).db
```

**Upgrade Kubernetes**:

```bash
# Upgrade Kubernetes to new version
talosctl upgrade-k8s --nodes <control-plane-ip> --to 1.30.0

# Monitor upgrade progress
watch kubectl get nodes

# Verify upgrade
kubectl version
kubectl get nodes
kubectl get pods -A
```

**Post-Upgrade Validation**:

```bash
# Check all system pods are running
kubectl get pods -n kube-system

# Check API server is responsive
kubectl get --raw /healthz

# Verify DNS is working
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

## Application Management

### Deploy Application

**Using kubectl**:

```bash
# Create deployment
kubectl create deployment myapp --image=myapp:latest --replicas=2

# Expose service
kubectl expose deployment myapp --port=80 --type=NodePort

# Check status
kubectl get deployments,pods,svc -l app=myapp
```

**Using YAML manifests**:

```bash
# Apply manifest
kubectl apply -f app/deployment.yaml

# Check rollout status
kubectl rollout status deployment/myapp

# View logs
kubectl logs -f deployment/myapp
```

### Update Application

```bash
# Update image
kubectl set image deployment/myapp myapp=myapp:v2

# Monitor rollout
kubectl rollout status deployment/myapp

# Rollback if needed
kubectl rollout undo deployment/myapp
```

### Scale Application

```bash
# Scale deployment
kubectl scale deployment/myapp --replicas=5

# Verify scaling
kubectl get pods -l app=myapp

# Setup autoscaling (optional)
kubectl autoscale deployment myapp --cpu-percent=50 --min=2 --max=10
```

## Troubleshooting

### Node Issues

**Node Not Ready**:

```bash
# 1. Check node status
kubectl describe node <node-name>

# 2. Check Talos services
talosctl -n <node-ip> services

# 3. Check kubelet status
talosctl -n <node-ip> service kubelet status

# 4. View kubelet logs
talosctl -n <node-ip> logs kubelet --tail 100

# 5. Restart kubelet if needed
talosctl -n <node-ip> service kubelet restart
```

**High Resource Usage**:

```bash
# 1. Check resource usage
kubectl top node <node-name>

# 2. Identify resource-hungry pods
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu

# 3. Check for pod evictions
kubectl get events -A | grep Evicted

# 4. Review pod resource requests/limits
kubectl describe pod <pod-name>
```

**Disk Space Issues**:

```bash
# 1. Check node disk usage
talosctl -n <node-ip> df

# 2. Clean up unused images
talosctl -n <node-ip> images prune

# 3. Check pod volume usage
kubectl exec <pod-name> -- df -h

# 4. Clean up old logs (if needed)
talosctl -n <node-ip> logs --tail 0  # Forces log rotation
```

### Pod Issues

**Pod Not Starting**:

```bash
# 1. Check pod status
kubectl get pod <pod-name> -o wide

# 2. Describe pod for events
kubectl describe pod <pod-name>

# 3. Check pod logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Previous container logs

# 4. Check image pull
kubectl get events --field-selector involvedObject.name=<pod-name>

# 5. Debug with ephemeral container (K8s 1.23+)
kubectl debug <pod-name> -it --image=busybox --target=<container-name>
```

**CrashLoopBackOff**:

```bash
# 1. Check pod logs
kubectl logs <pod-name> --tail=100

# 2. Check previous container logs
kubectl logs <pod-name> --previous

# 3. Check resource limits
kubectl describe pod <pod-name> | grep -A 5 Limits

# 4. Check liveness/readiness probes
kubectl describe pod <pod-name> | grep -A 10 Probes

# 5. Disable probes temporarily for debugging
kubectl edit deployment <deployment-name>
# Comment out livenessProbe and readinessProbe
```

**ImagePullBackOff**:

```bash
# 1. Check image name
kubectl describe pod <pod-name> | grep Image

# 2. Check image pull secrets
kubectl get secrets
kubectl describe pod <pod-name> | grep -A 5 ImagePullSecrets

# 3. Verify registry access
kubectl run -it --rm debug --image=<registry>/<image>:<tag> --restart=Never -- sh

# 4. Create image pull secret if needed
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password>
```

### Network Issues

**Pod Cannot Communicate**:

```bash
# 1. Check pod IP and network
kubectl get pod <pod-name> -o wide

# 2. Check service endpoints
kubectl get endpoints <service-name>

# 3. Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service-name>

# 4. Check network policies
kubectl get networkpolicies -A
kubectl describe networkpolicy <policy-name>

# 5. Check CNI pods
kubectl get pods -n kube-system -l k8s-app=flannel
kubectl logs -n kube-system -l k8s-app=flannel
```

**Ingress Not Working**:

```bash
# 1. Check ingress configuration
kubectl get ingress
kubectl describe ingress <ingress-name>

# 2. Check ingress controller pods
kubectl get pods -n ingress-nginx

# 3. Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# 4. Test backend service
kubectl get svc <backend-service>
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- <service-name>:<port>

# 5. Check ingress controller service
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

**DNS Not Resolving**:

```bash
# 1. Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# 3. Test DNS from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# 4. Check DNS configuration
kubectl get configmap -n kube-system coredns -o yaml

# 5. Restart CoreDNS if needed
kubectl rollout restart deployment -n kube-system coredns
```

### Storage Issues

**PVC Pending**:

```bash
# 1. Check PVC status
kubectl get pvc

# 2. Describe PVC for events
kubectl describe pvc <pvc-name>

# 3. Check storage class
kubectl get storageclass
kubectl describe storageclass <storageclass-name>

# 4. Check provisioner pods
kubectl get pods -n kube-system -l app=local-path-provisioner

# 5. Check node storage
talosctl -n <worker-ip> df
```

**Volume Mount Issues**:

```bash
# 1. Check pod volume mounts
kubectl describe pod <pod-name> | grep -A 10 Mounts

# 2. Check volume permissions
kubectl exec <pod-name> -- ls -la /mount/path

# 3. Check PV status
kubectl get pv

# 4. Check for mount errors
kubectl describe pod <pod-name> | grep -i error
```

## Disaster Recovery

### Cluster Failure Recovery

**Scenario: Control Plane Node Failure**:

```bash
# 1. Check control plane status
talosctl -n <control-plane-ip> services

# 2. If VM is corrupted, rebuild:
# - Create new VM with same specs
# - Boot from Talos ISO
# - Apply saved control plane configuration
talosctl apply-config --insecure --nodes <control-plane-ip> --file controlplane.yaml

# 3. Wait for node to come up
watch talosctl -n <control-plane-ip> health

# 4. Verify cluster
kubectl get nodes
kubectl get pods -A
```

**Scenario: etcd Data Loss**:

```bash
# 1. Stop kube-apiserver
talosctl -n <control-plane-ip> service etcd stop

# 2. Restore etcd snapshot
talosctl -n <control-plane-ip> etcd snapshot restore --data-dir=/var/lib/etcd ./backup.db

# 3. Start etcd
talosctl -n <control-plane-ip> service etcd start

# 4. Verify cluster
kubectl get nodes
kubectl get pods -A
```

**Scenario: Complete Cluster Loss**:

```bash
# 1. Rebuild VMs with same specifications
# 2. Apply saved configurations
# 3. Bootstrap control plane
# 4. Restore etcd from backup
# 5. Join worker nodes
# 6. Redeploy applications from Git
```

### Backup Verification

**Monthly Backup Test**:

```bash
# 1. Create test etcd snapshot
talosctl -n <control-plane-ip> etcd snapshot ./test-backup.db

# 2. Verify snapshot integrity
# Create test VM and restore snapshot

# 3. Verify backup can be restored
# Document any issues found

# 4. Update recovery procedures as needed
```

## Performance Optimization

### Resource Monitoring

```bash
# Monitor node resources
watch kubectl top nodes

# Monitor pod resources
watch 'kubectl top pods -A --sort-by=memory | head -20'

# Check resource requests/limits across cluster
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Optimization Tips

**For Worker Nodes**:

```bash
# Set resource requests/limits on pods
kubectl set resources deployment/<name> \
  --limits=cpu=500m,memory=512Mi \
  --requests=cpu=100m,memory=128Mi

# Use pod disruption budgets
kubectl create poddisruptionbudget <name> \
  --selector=app=<app> \
  --min-available=1
```

## Security Operations

### Certificate Management

**View Certificates**:

```bash
# Check certificate expiration
talosctl -n <control-plane-ip> get certificates

# View specific certificate
talosctl -n <control-plane-ip> get certificate <cert-name> -o yaml
```

**Rotate Certificates** (if needed):

```bash
# Rotate talosctl client certificate
talosctl gen secrets -o secrets.yaml
# Apply new secrets following Talos documentation
```

### Audit and Compliance

**Review RBAC**:

```bash
# List service accounts
kubectl get serviceaccounts -A

# Check role bindings
kubectl get rolebindings,clusterrolebindings -A

# Review specific access
kubectl auth can-i --list --as=system:serviceaccount:default:myapp
```

**Security Scanning**:

```bash
# Scan running images (requires trivy)
kubectl get pods -A -o json | \
  jq -r '.items[].spec.containers[].image' | \
  sort -u | \
  xargs -I {} trivy image {}
```

## References

- [Talos Linux Documentation](https://www.talos.dev/latest/)
- [Talos Troubleshooting Guide](https://www.talos.dev/latest/learn-more/troubleshooting/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [ADR-0016: Talos Implementation Plan](../decisions/0016-talos-unraid-primary.md#implementation-plan)
- [Talos Cluster Specification](../../specs/talos/talos-cluster-specification.md)
