# Runbook: Deploy Application to Kubernetes

## Overview

Procedure for deploying applications to Kubernetes clusters using GitOps (ArgoCD) or kubectl.

## Prerequisites

- Access to GitHub repository
- `kubectl` configured for target cluster
- ArgoCD installed (for GitOps)
- Application manifests prepared
- Secrets configured

## Procedure

### Method 1: GitOps with ArgoCD (Recommended)

**Step 1: Update Manifests**

```bash
# 1. Clone repository
git clone https://github.com/myorg/k8s-manifests
cd k8s-manifests

# 2. Update image tag
cd apps/myapp
sed -i 's/image: myapp:.*/image: myapp:v2.0.0/' deployment.yaml

# 3. Commit and push
git add deployment.yaml
git commit -m "chore: update myapp to v2.0.0"
git push origin main
```

**Step 2: Sync Application**

```bash
# ArgoCD auto-syncs (if configured)
# Or manual sync:
argocd app sync myapp

# Watch progress
argocd app wait myapp --health
```

**Step 3: Verify Deployment**

```bash
# Check pods
kubectl get pods -n production -l app=myapp

# Check rollout status
kubectl rollout status deployment/myapp -n production

# Check logs
kubectl logs -f deployment/myapp -n production
```

### Method 2: Direct kubectl Deployment

**Step 1: Apply Manifests**

```bash
# Apply all manifests
kubectl apply -f k8s/

# Or specific files
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

**Step 2: Monitor Rollout**

```bash
# Watch deployment
kubectl rollout status deployment/myapp -n production

# Watch pods
kubectl get pods -n production -w -l app=myapp
```

**Step 3: Verify Health**

```bash
# Check pod status
kubectl get pods -n production -l app=myapp

# Check logs for errors
kubectl logs deployment/myapp -n production --tail=100

# Test endpoint
kubectl port-forward svc/myapp 8080:80 -n production
curl http://localhost:8080/health
```

## Verification

### Health Checks

```bash
# 1. All pods running
kubectl get pods -n production -l app=myapp
# Expected: All pods STATUS=Running, READY=1/1

# 2. Service accessible
kubectl get svc myapp -n production
# Expected: Service has CLUSTER-IP

# 3. Ingress configured
kubectl get ingress myapp -n production
# Expected: ADDRESS populated

# 4. Application responding
curl https://myapp.example.com/health
# Expected: HTTP 200, {"status":"healthy"}
```

### Metrics Check

```bash
# Check Prometheus metrics
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090
# Query: up{job="myapp"}
# Expected: 1 (up)
```

### Log Check

```bash
# Check for errors in logs
kubectl logs deployment/myapp -n production --tail=100 | grep -i error
# Expected: No critical errors
```

## Rollback

### Automatic Rollback (ArgoCD)

```bash
# Revert Git commit
git revert HEAD
git push origin main

# ArgoCD auto-syncs to previous version
argocd app wait myapp --health
```

### Manual Rollback (kubectl)

```bash
# Rollback to previous revision
kubectl rollout undo deployment/myapp -n production

# Rollback to specific revision
kubectl rollout history deployment/myapp -n production
kubectl rollout undo deployment/myapp --to-revision=2 -n production

# Verify rollback
kubectl rollout status deployment/myapp -n production
```

## Troubleshooting

### Pods Not Starting

**Symptom**: Pods in CrashLoopBackOff or ImagePullBackOff

**Diagnosis**:

```bash
# Describe pod
kubectl describe pod <pod-name> -n production

# Check events
kubectl get events -n production --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n production --previous
```

**Solutions**:

- ImagePullBackOff → Check image tag, registry credentials
- CrashLoopBackOff → Check application logs, environment variables
- Pending → Check resource requests, node capacity

### Service Not Accessible

**Symptom**: Cannot reach application via service/ingress

**Diagnosis**:

```bash
# Check service endpoints
kubectl get endpoints myapp -n production
# Expected: Endpoints should list pod IPs

# Check pod labels match service selector
kubectl get pods -n production --show-labels
kubectl get svc myapp -n production -o yaml | grep selector

# Test service directly
kubectl run test --rm -it --image=curlimages/curl -- curl http://myapp.production.svc.cluster.local
```

**Solutions**:

- No endpoints → Check pod labels match service selector
- Endpoints exist but not reachable → Check pod health, readiness probes
- Service works but ingress doesn't → Check ingress configuration, DNS

### Slow Rollout

**Symptom**: Deployment taking >5 minutes

**Diagnosis**:

```bash
# Check rollout status
kubectl rollout status deployment/myapp -n production

# Check pod events
kubectl describe pods -n production -l app=myapp | grep -A 10 Events
```

**Solutions**:

- Image pull slow → Use image pull policy IfNotPresent, local registry
- Health checks failing → Adjust initialDelaySeconds, check readiness probe
- Resource limits → Increase CPU/memory requests

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| ImagePullBackOff | Wrong tag, no credentials | Check image name, add imagePullSecrets |
| CrashLoopBackOff | App crashes on startup | Check logs, env vars, config |
| Pending pods | Insufficient resources | Scale cluster or reduce requests |
| Service 503 errors | No healthy pods | Check readiness probe, app health |
| DNS not resolving | Ingress not configured | Check ingress, external-dns |

## Post-Deployment

1. **Monitor for 30 minutes**:

   ```bash
   # Watch pods
   kubectl get pods -n production -w -l app=myapp

   # Monitor logs
   kubectl logs -f deployment/myapp -n production

   # Check metrics in Grafana
   ```

2. **Update documentation**:
   - [ ] Update version in CHANGELOG
   - [ ] Document any configuration changes
   - [ ] Update runbook if procedure changed

3. **Notify team**:
   - Post in Slack/Discord: "myapp v2.0.0 deployed to production"
   - Include rollback procedure if needed

## Related Runbooks

- [Scale Kubernetes Cluster](0004-scale-cluster.md)
- [Disaster Recovery](0003-disaster-recovery.md)
- [Troubleshooting Guide](0005-troubleshooting.md)

## References

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
