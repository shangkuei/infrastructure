# Research: Deployment Strategies

Date: 2025-10-18
Author: Infrastructure Team
Status: Completed

## Objective

Evaluate deployment strategies (rolling, blue-green, canary, recreate) for Kubernetes applications and infrastructure updates, focusing on minimizing downtime and risk for small teams.

## Scope

### In Scope

- Kubernetes deployment strategies
- Infrastructure (Terraform) deployment approaches
- GitOps workflows (ArgoCD, Flux)
- Rollback procedures
- Small company considerations

### Out of Scope

- Feature flags (application-level concern)
- A/B testing frameworks
- Enterprise deployment platforms

## Methodology

### Testing Approach

- Implemented each strategy in test Kubernetes cluster
- Measured downtime and rollback time
- Simulated failures and recovery
- Evaluated complexity and operational overhead

### Evaluation Criteria

- **Downtime**: Zero-downtime capability
- **Risk**: Blast radius of failed deployments
- **Complexity**: Implementation and operational overhead
- **Speed**: Deployment and rollback time
- **Cost**: Additional infrastructure requirements

## Findings

### Deployment Strategy Comparison

| Strategy | Downtime | Risk | Complexity | Speed | Extra Infra |
|----------|----------|------|------------|-------|-------------|
| **Recreate** | High | High | Low | Fast | None |
| **Rolling** | None | Medium | Low | Medium | None |
| **Blue-Green** | None | Low | Medium | Fast | 2x resources |
| **Canary** | None | Very Low | High | Slow | Minimal |

### 1. Recreate Deployment

**Description**: Stop old version, deploy new version

**Kubernetes Example**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  strategy:
    type: Recreate  # All pods killed before new ones created
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: myapp:2.0.0
```

**Process**:

1. Scale down old version to 0 replicas
2. Wait for pods to terminate
3. Deploy new version
4. Wait for pods to be ready

**Pros**:

- ✅ Simplest strategy
- ✅ No version conflicts
- ✅ Lowest resource usage

**Cons**:

- ❌ Downtime during deployment
- ❌ Not suitable for production
- ❌ No gradual rollout

**Use cases**: Development environments, stateful apps requiring full shutdown, database migrations

**Downtime**: 30-120 seconds

### 2. Rolling Update (Recommended Default)

**Description**: Gradually replace old pods with new ones

**Kubernetes Example**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max pods above desired count
      maxUnavailable: 0  # Min pods that must be available
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: myapp:2.0.0
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Process**:

1. Create 1 new pod (maxSurge: 1)
2. Wait for new pod to be ready
3. Terminate 1 old pod
4. Repeat until all pods updated

**Pros**:

- ✅ Zero downtime
- ✅ Gradual rollout
- ✅ Built-in to Kubernetes
- ✅ No extra infrastructure

**Cons**:

- ❌ Old and new versions run simultaneously
- ❌ Slower than recreate
- ❌ Rollback requires new deployment

**Configuration Best Practices**:

```yaml
strategy:
  rollingUpdate:
    maxSurge: 25%         # Conservative: 1 extra pod per 4
    maxUnavailable: 0     # No capacity loss during update

# Add health checks
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3

livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
```

**Rollback**:

```bash
# Automatic (if new pods fail health checks)
# Kubernetes stops rolling update

# Manual rollback
kubectl rollout undo deployment/app

# Rollback to specific revision
kubectl rollout undo deployment/app --to-revision=2

# Check rollout status
kubectl rollout status deployment/app
```

**Use cases**: Most production applications, default strategy

**Deployment time**: 2-5 minutes (3-pod deployment)

### 3. Blue-Green Deployment

**Description**: Run two identical environments, switch traffic atomically

**Kubernetes Example**:

```yaml
# Blue deployment (current)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  labels:
    app: myapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: myapp:1.0.0

---
# Green deployment (new)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    app: myapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: myapp:2.0.0

---
# Service (switch between blue/green)
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
    version: blue  # Switch to 'green' to cutover
  ports:
  - port: 80
    targetPort: 8080
```

**Process**:

1. Deploy green environment alongside blue
2. Test green environment (smoke tests)
3. Switch service selector to green
4. Monitor for issues
5. If successful, delete blue
6. If issues, switch back to blue

**Cutover Script**:

```bash
# Deploy green
kubectl apply -f deployment-green.yaml

# Wait for green to be ready
kubectl wait --for=condition=available --timeout=300s deployment/app-green

# Smoke test green
kubectl run test --rm -it --image=curlimages/curl -- curl http://app-green-service

# Switch traffic to green
kubectl patch service app-service -p '{"spec":{"selector":{"version":"green"}}}'

# Monitor
kubectl logs -f deployment/app-green

# If issues, rollback to blue
kubectl patch service app-service -p '{"spec":{"selector":{"version":"blue"}}}'

# After success, delete blue
kubectl delete deployment app-blue
```

**Pros**:

- ✅ Instant cutover
- ✅ Easy rollback
- ✅ Full testing before switch
- ✅ Zero downtime

**Cons**:

- ❌ 2x infrastructure cost during deployment
- ❌ Database migration complexity
- ❌ Manual cutover process

**Use cases**: Critical applications, major version changes, database schema migrations

**Cost**: 2x resources for 15-30 minutes

### 4. Canary Deployment

**Description**: Gradually shift traffic from old to new version

**Kubernetes + Istio Example**:

```yaml
# Deployment v1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v1
spec:
  replicas: 9  # 90% of traffic
  template:
    metadata:
      labels:
        app: myapp
        version: v1
    spec:
      containers:
      - name: app
        image: myapp:1.0.0

---
# Deployment v2 (canary)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v2
spec:
  replicas: 1  # 10% of traffic
  template:
    metadata:
      labels:
        app: myapp
        version: v2
    spec:
      containers:
      - name: app
        image: myapp:2.0.0

---
# Istio VirtualService (traffic splitting)
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: app
spec:
  hosts:
  - app.example.com
  http:
  - match:
    - headers:
        user-agent:
          regex: ".*Mobile.*"  # Route mobile to canary
    route:
    - destination:
        host: app
        subset: v2
  - route:
    - destination:
        host: app
        subset: v1
      weight: 90
    - destination:
        host: app
        subset: v2
      weight: 10
```

**Process**:

1. Deploy canary (10% traffic)
2. Monitor error rates, latency
3. If successful, increase to 25%
4. Continue increasing: 50% → 75% → 100%
5. If issues, route all traffic to stable

**Canary Metrics**:

```yaml
# Monitor these metrics
- Error rate (< 1%)
- Response time (p95 < 200ms)
- CPU/memory usage
- Business metrics (conversion rate)

# Automated rollback if:
- Error rate > 5%
- p95 latency > 500ms
- Resource usage > 80%
```

**Pros**:

- ✅ Lowest risk (small blast radius)
- ✅ Real traffic validation
- ✅ Gradual rollout
- ✅ Automated rollback possible

**Cons**:

- ❌ Complex setup (requires service mesh or ingress controller)
- ❌ Slow deployment process
- ❌ Requires good monitoring

**Tools**:

- **Istio**: Service mesh for traffic splitting
- **Flagger**: Automated canary deployments
- **Argo Rollouts**: Progressive delivery for Kubernetes

**Use cases**: High-risk changes, new features, ML model deployments

**Deployment time**: 30-60 minutes (gradual rollout)

## GitOps Integration

### ArgoCD (Recommended)

**Deployment Workflow**:

```yaml
# Application manifest
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/k8s-manifests
    targetRevision: main
    path: apps/myapp
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true

# Rollback
# Git revert commit → ArgoCD auto-syncs → Deployment rolls back
```

**Benefits**:

- Git as single source of truth
- Declarative deployments
- Easy rollback (git revert)
- Audit trail in Git history

### Terraform Deployments

**Strategy**: Blue-Green for Infrastructure

**Example**:

```hcl
# terraform/environments/production/main.tf
module "app_blue" {
  source = "../../modules/app"
  version = "1.0.0"
  environment = "production-blue"
  enabled = var.active_env == "blue"
}

module "app_green" {
  source = "../../modules/app"
  version = "2.0.0"
  environment = "production-green"
  enabled = var.active_env == "green"
}

# Switch traffic
resource "digitalocean_loadbalancer" "app" {
  name   = "app-lb"
  region = "nyc3"

  forwarding_rule {
    entry_port     = 443
    target_port    = 8080
    entry_protocol = "https"
    target_protocol = "http"
  }

  # Point to active environment
  droplet_ids = var.active_env == "blue" ? module.app_blue.droplet_ids : module.app_green.droplet_ids
}
```

**Deployment Process**:

```bash
# 1. Deploy green infrastructure
terraform apply -var="active_env=blue" -target=module.app_green

# 2. Test green
curl https://app-green.internal/health

# 3. Switch traffic
terraform apply -var="active_env=green"

# 4. Verify
curl https://app.example.com/

# 5. If issues, rollback
terraform apply -var="active_env=blue"

# 6. After success, destroy blue
terraform destroy -target=module.app_blue
```

## Recommendations

### Application Deployments

**Default Strategy**: Rolling Update

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 25%
    maxUnavailable: 0
```

**Rationale**:

- Zero downtime
- No extra infrastructure
- Built into Kubernetes
- Simple to implement

**When to use others**:

- **Blue-Green**: Major versions, database migrations
- **Canary**: High-risk changes, ML models
- **Recreate**: Dev/test environments only

### Infrastructure Deployments

**Terraform Strategy**: Plan → Manual Apply

**Process**:

```bash
# 1. PR created → GitHub Actions runs terraform plan
# 2. Review plan output
# 3. Merge PR → Manual workflow trigger
# 4. terraform apply (with approval)
# 5. Monitor infrastructure
```

**Safeguards**:

- Always run `terraform plan` first
- Require PR approval for infrastructure changes
- Use `prevent_destroy` for critical resources
- Maintain state backups

## Action Items

1. **Immediate**:
   - [ ] Implement rolling updates for all deployments
   - [ ] Add readiness/liveness probes
   - [ ] Test rollback procedures
   - [ ] Document deployment process

2. **Short-term** (1-3 months):
   - [ ] Set up ArgoCD for GitOps
   - [ ] Implement blue-green for critical apps
   - [ ] Create deployment runbooks
   - [ ] Add automated tests

3. **Long-term** (6-12 months):
   - [ ] Evaluate service mesh (Istio/Linkerd)
   - [ ] Implement canary deployments
   - [ ] Automated rollback on failures
   - [ ] Progressive delivery

## Follow-up Research Needed

1. **Service Mesh**: Istio vs. Linkerd for traffic management
2. **Progressive Delivery**: Flagger vs. Argo Rollouts
3. **Feature Flags**: LaunchDarkly vs. Unleash vs. Flagsmith

## References

- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Flagger Documentation](https://docs.flagger.app/)
- [Martin Fowler - Blue-Green Deployment](https://martinfowler.com/bliki/BlueGreenDeployment.html)
- [Canary Deployments](https://martinfowler.com/bliki/CanaryRelease.html)

## Outcome

This research led to **[ADR-0007: GitOps Workflow](../decisions/0007-gitops-workflow.md)**, which adopted rolling updates as default with GitOps for deployment automation.
