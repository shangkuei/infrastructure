# 18. Flux for Kubernetes GitOps

Date: 2025-11-04

## Status

Accepted

## Context

With our Talos Linux Kubernetes cluster operational (ADR-0016), we need a GitOps solution to manage
Kubernetes resources declaratively. While GitHub Actions handles infrastructure provisioning (ADR-0007),
we need Kubernetes-native GitOps for:

- **System Components**: Core addons in `kube-system` namespace
- **Cluster Addons**: Operational tools in `kube-addons` namespace
- **Continuous Reconciliation**: Automatic drift detection and correction
- **Declarative Management**: All Kubernetes manifests in Git

For system-level Kubernetes resources specifically, we need:

- **Automatic reconciliation**: Detect and fix configuration drift
- **Ordered deployment**: Handle dependencies between components
- **Health checking**: Verify components are running correctly
- **Bootstrap capability**: Set up cluster from scratch using GitOps

## Decision

We will adopt **Flux CD** as our Kubernetes GitOps solution for managing resources in:

- **`kube-system` namespace**: Core system components (CNI, CSI, CoreDNS extensions)
- **`kube-addons` namespace**: Cluster addons (ingress, cert-manager, monitoring)

Specifically:

- **Flux Controllers**: Installed in `flux-system` namespace
- **Git Repository**: This infrastructure repository as the source of truth
- **Kustomization**: Flux Kustomizations for each namespace
- **Automated Sync**: 5-minute reconciliation interval (configurable)
- **GitOps Workflow**: Changes via pull requests, Flux applies automatically
- **Hybrid Approach**: GitHub Actions for Terraform/infrastructure, Flux for Kubernetes resources

## Consequences

### Positive

- **Automatic Reconciliation**: Flux continuously ensures cluster state matches Git
- **Drift Detection**: Identifies and corrects manual changes automatically
- **Ordered Deployment**: Dependencies handled via Flux Kustomization dependencies
- **Health Checks**: Built-in health assessment for Kubernetes resources
- **Disaster Recovery**: Cluster can rebuild itself from Git repository
- **Separation of Concerns**: Infrastructure (GitHub Actions) vs. Kubernetes (Flux)
- **Kubernetes Native**: Works with standard Kubernetes manifests and Kustomize
- **Bootstrap Ready**: Flux can bootstrap entire cluster configuration
- **Security**: Flux uses Kubernetes RBAC, no external credentials needed

### Negative

- **Learning Curve**: Team needs to learn Flux concepts and CRDs
- **Additional Complexity**: Another tool in the stack (vs. pure GitHub Actions)
- **Debugging**: Requires understanding Flux reconciliation model
- **Initial Setup**: Flux bootstrap and configuration required
- **Resource Overhead**: Flux controllers consume cluster resources (~100-200MB)

### Trade-offs

- **Automation vs. Control**: Flux auto-applies changes, reducing manual control but increasing reliability
- **Complexity vs. Features**: More tooling but better Kubernetes-native GitOps
- **Immediate vs. Eventual**: GitHub Actions is immediate, Flux is eventual consistency

## Alternatives Considered

### GitHub Actions Only (Current ADR-0007)

**Description**: Continue using GitHub Actions with `kubectl apply` for all deployments

**Why not chosen**:

- No continuous reconciliation (drift detection requires manual checks)
- No dependency ordering (must handle manually in workflows)
- No built-in health checking (must implement custom health checks)
- Requires cluster credentials in GitHub Secrets (security concern)
- Manual intervention needed when configuration drifts
- Not Kubernetes-native (external tool applying changes)

**Trade-offs**: Simplicity vs. Kubernetes-native continuous reconciliation

### ArgoCD

**Description**: Alternative Kubernetes GitOps tool with UI focus

**Why not chosen**:

- **Heavier footprint**: Requires Redis, more resource intensive
- **UI-centric**: Built-in UI that we don't need for system namespaces
- **More complex**: Additional features we don't need at this stage
- **Sync-wave approach**: Less flexible than Flux's Kustomization dependencies

**When to reconsider**: If we need multi-cluster management with extensive UI visualization

**Trade-offs**: Feature-rich UI and multi-cluster vs. lightweight and simple

### Manual kubectl apply

**Description**: Operators manually apply Kubernetes manifests

**Why not chosen**:

- No automation or continuous reconciliation
- Human error prone
- No audit trail of who changed what
- Difficult to maintain consistency
- Violates GitOps principles (ADR-0007)

**Trade-offs**: Maximum flexibility vs. all automation benefits

### Helm + GitHub Actions

**Description**: Use Helm charts deployed via GitHub Actions

**Why not chosen**:

- Still requires external credentials in GitHub
- No continuous reconciliation
- Helm templating adds complexity
- No drift detection
- Not addressing the core GitOps reconciliation need

**Trade-offs**: Helm's packaging features vs. GitOps reconciliation

## Implementation Notes

### Flux Installation

**Bootstrap Flux**:

```bash
# Install Flux CLI
brew install fluxcd/tap/flux

# Check cluster compatibility
flux check --pre

# Bootstrap Flux in the cluster
flux bootstrap github \
  --owner=shangkuei \
  --repository=infrastructure \
  --branch=main \
  --path=./kubernetes/clusters/shangkuei-xyz-talos \
  --personal
```

### Directory Structure

```text
infrastructure/
├── kubernetes/
│   ├── clusters/
│   │   └── shangkuei-xyz-talos/      # Cluster-specific configs
│   │       ├── flux-system/          # Flux controllers (auto-managed)
│   │       ├── kube-system.yaml      # Kustomization for kube-system
│   │       └── kube-addons.yaml      # Kustomization for kube-addons
│   │
│   └── base/                          # Base manifests
│       ├── kube-system/              # System components
│       │   └── kustomization.yaml    # Add manifests here
│       │
│       └── kube-addons/              # Cluster addons
│           └── kustomization.yaml    # Add manifests here
```

### Flux Kustomization Examples

**kube-system.yaml**:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: kube-system
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/base/kube-system
  prune: true
  wait: true
  timeout: 5m
```

**kube-addons.yaml**:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: kube-addons
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/base/kube-addons
  prune: true
  wait: true
  timeout: 10m
  dependsOn:
    - name: kube-system
```

**Note**: Add `healthChecks` when you deploy specific components (e.g., Cilium, ingress-nginx).

### GitOps Workflow

1. **Create feature branch**:

   ```bash
   git checkout -b feature/add-monitoring
   ```

2. **Add/modify Kubernetes manifests**:

   ```bash
   # Add manifests to kubernetes/base/kube-addons/ or kubernetes/base/kube-system/
   ```

3. **Test locally** (optional):

   ```bash
   kubectl apply --dry-run=server -k kubernetes/base/kube-addons/
   ```

4. **Push and create PR**:

   ```bash
   git push origin feature/add-monitoring
   gh pr create --title "Add monitoring stack"
   ```

5. **CI validates** (GitHub Actions):
   - `kubectl --dry-run=server apply` validation
   - YAML lint checks
   - Kustomize build verification
   - Security scanning (kubesec, kyverno)

6. **Merge to main**:
   - PR merged after review
   - Flux detects change within 5 minutes
   - Flux reconciles cluster state automatically

7. **Monitor reconciliation**:

   ```bash
   flux get kustomizations
   flux logs --level=info
   ```

### Security Considerations

- **No External Credentials**: Flux uses in-cluster service account (no GitHub token in cluster)
- **RBAC**: Flux controllers have minimal required permissions via Kubernetes RBAC
- **Git Authentication**: GitHub token only used during bootstrap (stored as Kubernetes secret)
- **Audit Trail**: All changes tracked in Git with commit history
- **Drift Prevention**: Flux automatically reverts unauthorized manual changes

### Monitoring Flux

**Check Flux status**:

```bash
# Overall status
flux get all

# Specific Kustomization
flux get kustomization kube-system

# Check for errors
flux logs --level=error

# Reconcile immediately (don't wait)
flux reconcile kustomization kube-system --with-source
```

**Flux Events**:

```bash
# Watch Flux events
kubectl -n flux-system get events --watch

# Check specific Kustomization events
kubectl -n flux-system describe kustomization kube-system
```

### Disaster Recovery

**Complete cluster rebuild with Flux**:

```bash
# 1. Provision cluster infrastructure (Terraform/Talos)
# 2. Bootstrap Flux (one command)
flux bootstrap github \
  --owner=shangkuei \
  --repository=infrastructure \
  --branch=main \
  --path=./kubernetes/clusters/shangkuei-xyz-talos \
  --personal

# 3. Flux automatically reconciles all resources
#    - kube-system components
#    - kube-addons components
#    No additional steps needed!
```

## Hybrid Architecture

### GitHub Actions (ADR-0007)

Manages:

- Terraform infrastructure provisioning
- Cloud provider resources
- Talos cluster bootstrapping
- VM creation and configuration

### Flux CD (This ADR)

Manages:

- Kubernetes manifests in `kube-system`
- Kubernetes manifests in `kube-addons`
- Continuous reconciliation
- Drift detection and correction

### Clear Boundaries

- **Infrastructure Layer**: GitHub Actions deploys infrastructure
- **Kubernetes Layer**: Flux manages Kubernetes resources
- **Single Source of Truth**: Git repository for both
- **Complementary**: Not competing, each tool for its strength

## References

- [Flux CD Documentation](https://fluxcd.io/flux/)
- [GitOps Principles](https://opengitops.dev/)
- [Flux vs ArgoCD Comparison](https://fluxcd.io/flux/faq/#how-does-flux-compare-to-argo-cd)
- [Flux Security Best Practices](https://fluxcd.io/flux/security/)
- [Kustomize Documentation](https://kustomize.io/)
- [ADR-0007: GitOps Workflow](0007-gitops-workflow.md) - Infrastructure GitOps
- [ADR-0016: Talos Linux on Unraid](0016-talos-unraid-primary.md) - Kubernetes cluster
