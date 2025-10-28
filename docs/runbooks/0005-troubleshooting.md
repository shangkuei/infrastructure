# Runbook: Kubernetes Troubleshooting Guide

## Overview

Common Kubernetes issues and their solutions for quick incident response.

## Quick Diagnostics

### First Steps for Any Issue

```bash
# 1. Check overall cluster health
kubectl get nodes
kubectl get pods -A

# 2. Check recent events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# 3. Check resource usage
kubectl top nodes
kubectl top pods -A
```

## Common Issues

### Issue: Pods Not Starting

**Symptoms**: Pods stuck in `Pending`, `CrashLoopBackOff`, or `ImagePullBackOff`

**Diagnosis**:

```bash
# Get pod status
kubectl get pods -n <namespace>

# Describe pod for details
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

**Solutions by State**:

| State | Cause | Solution |
|-------|-------|----------|
| **ImagePullBackOff** | Cannot pull image | Check image name/tag, add imagePullSecrets |
| **CrashLoopBackOff** | App crashes on start | Check logs, env vars, config maps |
| **Pending** | Cannot schedule | Check node resources, node selectors, taints |
| **ErrImagePull** | Image doesn't exist | Verify image exists in registry |
| **CreateContainerConfigError** | Config error | Check secrets, config maps exist |

**Fix Examples**:

```bash
# ImagePullBackOff - check image
kubectl describe pod <pod-name> | grep "Failed to pull image"
# Fix: Update deployment with correct image tag

# CrashLoopBackOff - check logs
kubectl logs <pod-name> --previous
# Fix: Correct application configuration

# Pending - check resources
kubectl describe pod <pod-name> | grep -A 5 "Events"
# Fix: Scale cluster or reduce resource requests
```

### Issue: Service Not Accessible

**Symptoms**: Cannot reach application via service or ingress

**Diagnosis**:

```bash
# 1. Check service
kubectl get svc <service-name> -n <namespace>
kubectl describe svc <service-name> -n <namespace>

# 2. Check endpoints
kubectl get endpoints <service-name> -n <namespace>

# 3. Test from within cluster
kubectl run test --rm -it --image=curlimages/curl -- \
  curl http://<service-name>.<namespace>.svc.cluster.local

# 4. Check ingress
kubectl get ingress -n <namespace>
kubectl describe ingress <ingress-name> -n <namespace>
```

**Solutions**:

1. **No Endpoints**: Pod labels don't match service selector

```bash
# Check labels
kubectl get pods -n <namespace> --show-labels
kubectl get svc <service-name> -n <namespace> -o yaml | grep selector

# Fix: Update pod labels or service selector
```

2. **Endpoints Exist But Not Reachable**: Pod not ready

```bash
# Check pod readiness
kubectl get pods -n <namespace>

# Check readiness probe
kubectl describe pod <pod-name> | grep -A 5 "Readiness"

# Fix: Adjust readiness probe or fix application health endpoint
```

3. **Service Works But Ingress Doesn't**: Ingress misconfiguration

```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Fix: Verify ingress annotations, TLS certs, host rules
```

### Issue: High Resource Usage

**Symptoms**: Pods evicted, cluster slow, OOMKilled errors

**Diagnosis**:

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -A

# Identify resource-hungry pods
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu

# Check for OOMKilled
kubectl get pods -A | grep OOMKilled
kubectl describe pod <pod-name> | grep -A 5 "Last State"
```

**Solutions**:

1. **Memory Pressure**: Pod exceeds memory limit

```bash
# Increase memory limit
kubectl edit deployment <name>
# Update resources.limits.memory

# Or scale horizontally
kubectl scale deployment <name> --replicas=3
```

2. **CPU Throttling**: Pod hitting CPU limit

```bash
# Check throttling
kubectl describe pod <pod-name> | grep cpu

# Increase CPU limit
kubectl edit deployment <name>
# Update resources.limits.cpu
```

3. **Node Pressure**: Node out of resources

```bash
# Check node capacity
kubectl describe node <node-name> | grep -A 5 "Allocated resources"

# Solutions:
# a) Scale cluster (see scale-cluster.md)
# b) Reduce resource requests
# c) Delete unnecessary pods/deployments
```

### Issue: Persistent Volume Problems

**Symptoms**: Pods stuck in `ContainerCreating`, PVC in `Pending`

**Diagnosis**:

```bash
# Check PVC status
kubectl get pvc -A

# Describe PVC for events
kubectl describe pvc <pvc-name> -n <namespace>

# Check PV
kubectl get pv

# Check storage class
kubectl get storageclass
```

**Solutions**:

1. **PVC Pending**: No matching PV available

```bash
# Check if storage class provisions dynamically
kubectl describe storageclass <storage-class>

# Fix: Ensure storage provisioner is running
kubectl get pods -n kube-system | grep provisioner
```

2. **Mount Errors**: Volume already attached to another node

```bash
# Describe pod
kubectl describe pod <pod-name> | grep -A 10 "Events"

# Fix: Delete old pod or use ReadWriteMany access mode
kubectl delete pod <old-pod>
```

### Issue: DNS Resolution Failures

**Symptoms**: Services can't resolve by name

**Diagnosis**:

```bash
# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS from pod
kubectl run test --rm -it --image=busybox -- nslookup kubernetes.default

# Check DNS config
kubectl get cm coredns -n kube-system -o yaml
```

**Solutions**:

1. **CoreDNS Not Running**: Restart DNS pods

```bash
kubectl rollout restart deployment/coredns -n kube-system
```

2. **DNS Timeouts**: Increase replicas

```bash
kubectl scale deployment/coredns --replicas=3 -n kube-system
```

### Issue: Application Logs Missing

**Symptoms**: `kubectl logs` returns nothing or errors

**Diagnosis**:

```bash
# Check if pod is running
kubectl get pod <pod-name> -n <namespace>

# Try different log sources
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
kubectl logs <pod-name> -c <container-name> -n <namespace>
```

**Solutions**:

1. **No Logs**: Application not logging to stdout/stderr

```bash
# Check application configuration
# Fix: Configure app to log to stdout
```

2. **Logs Rotated**: Check Loki/logging system

```bash
# Query Grafana Loki
# Or check cloud provider logs
```

## Investigation Commands

### Pod Investigation

```bash
# Get pod details
kubectl get pod <pod-name> -n <namespace> -o yaml

# Get events for pod
kubectl get events --field-selector involvedObject.name=<pod-name> -n <namespace>

# Execute commands in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Copy files from pod
kubectl cp <namespace>/<pod-name>:/path/to/file ./local-file
```

### Network Investigation

```bash
# Test connectivity between pods
kubectl run test --rm -it --image=nicolaka/netshoot -- /bin/bash
# Inside: ping, curl, nslookup, traceroute

# Check network policies
kubectl get networkpolicies -A

# Check service endpoints
kubectl get endpoints <service-name> -n <namespace> -o yaml
```

### Resource Investigation

```bash
# Get resource usage history
kubectl top pods -A --containers

# Check resource quotas
kubectl get resourcequotas -A

# Check limit ranges
kubectl get limitranges -A
```

## Emergency Procedures

### Force Delete Stuck Pod

```bash
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force
```

### Restart Deployment

```bash
kubectl rollout restart deployment/<name> -n <namespace>
```

### Scale to Zero (Emergency)

```bash
kubectl scale deployment/<name> --replicas=0 -n <namespace>
```

### Drain Node for Maintenance

```bash
# Cordon node (no new pods)
kubectl cordon <node-name>

# Drain node (evict pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon when done
kubectl uncordon <node-name>
```

## Useful Debugging Tools

### Run Debug Container

```bash
# Alpine with networking tools
kubectl run debug --rm -it --image=nicolaka/netshoot -- /bin/bash

# Ubuntu
kubectl run debug --rm -it --image=ubuntu -- bash

# Curl for testing
kubectl run curl --rm -it --image=curlimages/curl -- sh
```

### Debug Existing Pod

```bash
# Ephemeral container (K8s 1.23+)
kubectl debug <pod-name> -n <namespace> -it --image=busybox --target=<container-name>
```

## Monitoring and Alerts

### Check Prometheus Alerts

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/alerts
```

### Check Grafana Dashboards

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# Visit http://localhost:3000
# Default: admin/prom-operator
```

## Escalation

When to escalate:

1. **Cluster-wide issues**: Multiple nodes down, control plane issues
2. **Data loss**: Database corruption, PV deleted
3. **Security incidents**: Unauthorized access, compromised pods
4. **Persistent failures**: Issue unresolved after 30 minutes

**Escalation Path**:

1. Senior engineer on-call
2. Cloud provider support (critical issues)
3. Disaster recovery procedures (see disaster-recovery.md)

## Common kubectl Commands

```bash
# Get everything in namespace
kubectl get all -n <namespace>

# Wide output (more columns)
kubectl get pods -o wide

# YAML output
kubectl get pod <pod-name> -o yaml

# JSON output with filtering
kubectl get pods -o json | jq '.items[].metadata.name'

# Watch for changes
kubectl get pods -w

# Sort by age
kubectl get pods --sort-by=.metadata.creationTimestamp

# Filter by label
kubectl get pods -l app=myapp

# Get from all namespaces
kubectl get pods -A
```

## Related Runbooks

- [Deploy Application](0002-deploy-application.md)
- [Scale Cluster](0004-scale-cluster.md)
- [Disaster Recovery](0003-disaster-recovery.md)

## References

- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Debugging Pods](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-application/)
