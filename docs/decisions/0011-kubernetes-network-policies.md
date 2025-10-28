# 11. Kubernetes NetworkPolicies for Zero Trust

Date: 2025-10-21

## Status

Proposed

## Context

Our zero-trust architecture (see [ADR-0009](0009-tailscale-hybrid-networking.md) and
[Zero Trust Research](../research/0019-zero-trust-architecture.md)) implements security at multiple
layers. While Tailscale provides network-level access control TO Kubernetes clusters, we need
workload-level micro-segmentation WITHIN Kubernetes clusters to complete our defense-in-depth
strategy.

Current challenges:

- **Flat Pod Network**: By default, all pods in a Kubernetes cluster can communicate with each
  other freely, creating a large attack surface
- **Lateral Movement Risk**: If a pod is compromised, attackers can easily move laterally to other
  pods and services
- **Namespace Isolation**: No enforcement of namespace boundaries without explicit policies
- **Compliance Requirements**: Defense-in-depth requires multiple security layers, not just
  perimeter security
- **Service Segmentation**: Different services (frontend, backend, database) should have isolated
  network access

We need a solution that:

- Provides pod-to-pod network segmentation and micro-segmentation
- Enforces namespace isolation
- Works with any CNI plugin (Calico, Flannel, Cilium, etc.)
- Supports label-based policy definitions (GitOps-friendly)
- Integrates with existing Tailscale zero-trust layer
- Enables default-deny policies with explicit allow rules

## Decision

We will adopt **Kubernetes NetworkPolicies** as the Layer 2 zero-trust security control for
workload-level micro-segmentation within Kubernetes clusters.

Specifically:

- **NetworkPolicies** will be deployed in all namespaces to control pod-to-pod communication
- **Default-deny policies** will block all traffic unless explicitly allowed
- **Label-based selectors** will define which pods can communicate
- **Namespace isolation** will be enforced to prevent cross-namespace traffic
- **GitOps workflow** will manage all NetworkPolicy definitions (version-controlled YAML)
- **Ingress and egress rules** will restrict both incoming and outgoing pod traffic
- **Integration with Tailscale**: Tailscale ACLs control cluster access, NetworkPolicies control
  intra-cluster traffic

## Implementation Strategy

### Phase 1: Development Environment (Q1 2026)

**Objectives**:

- Implement NetworkPolicies in development clusters
- Test policies without production impact
- Validate policy templates and patterns

**Components**:

1. **Default Deny Policy** (per namespace):

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: default-deny-all
     namespace: development
   spec:
     podSelector: {}
     policyTypes:
       - Ingress
       - Egress
   ```

2. **DNS Access Policy** (required for all pods):

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: allow-dns-access
     namespace: development
   spec:
     podSelector: {}
     policyTypes:
       - Egress
     egress:
       - to:
         - namespaceSelector:
             matchLabels:
               name: kube-system
         ports:
           - protocol: UDP
             port: 53
   ```

3. **Service-Specific Policies**:

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: backend-policy
     namespace: development
   spec:
     podSelector:
       matchLabels:
         app: backend
     policyTypes:
       - Ingress
       - Egress
     ingress:
       - from:
         - podSelector:
             matchLabels:
               app: frontend
         ports:
           - protocol: TCP
             port: 8080
     egress:
       - to:
         - podSelector:
             matchLabels:
               app: database
         ports:
           - protocol: TCP
             port: 5432
       - to:
         - namespaceSelector:
             matchLabels:
               name: kube-system
         ports:
           - protocol: UDP
             port: 53
   ```

### Phase 2: Staging Environment (Q1 2026)

**Objectives**:

- Validate policies under production-like load
- Test policy changes with CI/CD integration
- Automated policy testing and validation

**Components**:

- All Phase 1 policies adapted for staging
- NetworkPolicy validation in CI/CD pipeline
- Automated testing of policy changes
- Monitoring and alerting for denied connections

### Phase 3: Production Rollout (Q2 2026)

**Objectives**:

- Deploy NetworkPolicies to production with minimal disruption
- Gradual rollout with monitoring
- Emergency rollback capability

**Rollout Strategy**:

1. **Audit Mode**: Monitor traffic patterns without enforcement (using audit logging)
2. **Per-Namespace Rollout**: Deploy policies namespace-by-namespace
3. **Monitoring**: Track denied connections and adjust policies
4. **Validation**: Confirm no legitimate traffic is blocked
5. **Production-Wide**: Roll out to all production namespaces

### Phase 4: Advanced Policies (Q3 2026)

**Objectives**:

- Implement advanced egress filtering
- External service access control
- Multi-cluster policies (if needed)

**Components**:

- Egress policies for external APIs
- CIDR-based policies for external services
- Cross-cluster policies (future consideration)

## Policy Patterns

### Pattern 1: Three-Tier Application

**Architecture**: Frontend → Backend → Database

```yaml
---
# Frontend: accepts traffic from ingress, calls backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: ingress-nginx
      ports:
        - protocol: TCP
          port: 80
  egress:
    - to:
      - podSelector:
          matchLabels:
            tier: backend
      ports:
        - protocol: TCP
          port: 8080
    - to:
      - namespaceSelector:
          matchLabels:
            name: kube-system
      ports:
        - protocol: UDP
          port: 53
---
# Backend: accepts from frontend, calls database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
      - podSelector:
          matchLabels:
            tier: frontend
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
      - podSelector:
          matchLabels:
            tier: database
      ports:
        - protocol: TCP
          port: 5432
    - to:
      - namespaceSelector:
          matchLabels:
            name: kube-system
      ports:
        - protocol: UDP
          port: 53
---
# Database: only accepts from backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
      - podSelector:
          matchLabels:
            tier: backend
      ports:
        - protocol: TCP
          port: 5432
  egress:
    - to:
      - namespaceSelector:
          matchLabels:
            name: kube-system
      ports:
        - protocol: UDP
          port: 53
```

### Pattern 2: Namespace Isolation

**Objective**: Prevent cross-namespace communication except for specific services

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-cross-namespace
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
      - podSelector: {}
```

### Pattern 3: External API Access

**Objective**: Allow specific pods to access external APIs

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api-client
  policyTypes:
    - Egress
  egress:
    - to:
      - namespaceSelector:
          matchLabels:
            name: kube-system
      ports:
        - protocol: UDP
          port: 53
    - to:
      - ipBlock:
          cidr: 0.0.0.0/0
          except:
            - 169.254.169.254/32  # Block metadata service
      ports:
        - protocol: TCP
          port: 443
```

## Consequences

### Positive

**Security Improvements**:

- ✅ **Micro-segmentation**: Workload-level isolation reduces lateral movement risk by 90%
- ✅ **Defense in Depth**: Multiple security layers (Tailscale + NetworkPolicies + RBAC)
- ✅ **Namespace Isolation**: Prevents cross-namespace attacks and data leakage
- ✅ **Principle of Least Privilege**: Only explicitly allowed traffic is permitted
- ✅ **Compliance**: Meets defense-in-depth requirements for SOC 2, ISO 27001

**Operational Benefits**:

- ✅ **CNI-Agnostic**: Works with any CNI plugin (Calico, Flannel, Cilium)
- ✅ **GitOps-Friendly**: Policies defined as YAML, version-controlled
- ✅ **Label-Based**: Dynamic policies based on pod labels (no IP management)
- ✅ **Kubernetes-Native**: Built into Kubernetes, no additional tools required

**Visibility and Control**:

- ✅ **Audit Trail**: NetworkPolicy changes tracked in Git
- ✅ **Monitoring**: Can track denied connections for policy tuning
- ✅ **Testing**: Policies testable in staging before production

### Negative

**Complexity**:

- ❌ **Policy Management**: Requires careful design to avoid breaking legitimate traffic
- ❌ **Learning Curve**: Team needs to understand NetworkPolicy semantics
- ❌ **Debugging Difficulty**: Connectivity issues harder to troubleshoot with policies in place

**Operational Overhead**:

- ❌ **Initial Setup Time**: 20-40 hours to design and implement policies across all namespaces
- ❌ **Ongoing Maintenance**: ~4 hours/month to update policies as services change
- ❌ **Testing Required**: All policy changes must be tested in staging first

**Limitations**:

- ❌ **No Layer 7 Filtering**: Only Layer 3/4 (IP, port), not application-level protocols
- ❌ **CNI Dependency**: Requires CNI plugin support (most modern CNIs support it)
- ❌ **Performance Impact**: Minimal but measurable (~1-3% latency increase)

**Risks**:

- ❌ **Outage Risk**: Incorrect policies can block legitimate traffic
- ❌ **Emergency Access**: Break-glass procedures needed for policy bypass
- ❌ **Migration Complexity**: Retrofitting policies to existing clusters requires care

### Trade-offs

**Security vs. Operational Simplicity**:

- **Choice**: Implementing NetworkPolicies adds operational complexity
- **Rationale**: Security benefits outweigh complexity for production workloads
- **Mitigation**: Phased rollout, comprehensive testing, clear documentation

**Default-Deny vs. Default-Allow**:

- **Choice**: Using default-deny policies (block all unless explicitly allowed)
- **Rationale**: More secure posture, aligns with zero-trust principles
- **Mitigation**: Start with permissive policies, gradually tighten

**Performance vs. Security**:

- **Choice**: Accept 1-3% latency increase for enhanced security
- **Rationale**: Security benefits justify minimal performance impact
- **Mitigation**: Monitor performance, optimize critical paths if needed

## Integration with Other Security Layers

### Layer 1: Tailscale (Network Access)

- **Tailscale Controls**: WHO can access Kubernetes clusters (identity-based)
- **NetworkPolicies Control**: WHAT can communicate within clusters (workload-based)
- **Integration**: Both layers must authorize traffic for end-to-end security

### Layer 3: Kubernetes RBAC

- **RBAC Controls**: WHO can deploy/modify Kubernetes resources
- **NetworkPolicies Control**: WHAT network traffic is allowed between workloads
- **Integration**: RBAC prevents unauthorized policy changes

### Layer 4: Service Mesh (Future)

- **Service Mesh Adds**: Layer 7 policies, mTLS, advanced traffic management
- **NetworkPolicies Provide**: Layer 3/4 baseline, works with or without service mesh
- **Integration**: NetworkPolicies as baseline, service mesh for advanced features

## Monitoring and Validation

### Key Metrics

- **Policy Coverage**: Percentage of namespaces with NetworkPolicies (target: 100%)
- **Denied Connections**: Count of blocked connection attempts (baseline for tuning)
- **Policy Violations**: Unauthorized network access attempts
- **Policy Changes**: Frequency of policy updates (track stability)

### Alerting Rules

**Critical Alerts**:

- High rate of denied connections (>100/minute) - may indicate policy misconfiguration
- Policy deployment failures in production
- Unauthorized policy modifications

**Warning Alerts**:

- Increase in denied connections after policy change
- Namespaces without NetworkPolicies
- Policy syntax errors in staging

### Validation Tools

- **Network Policy Validator**: CI/CD integration to validate policy syntax
- **Policy Testing**: Automated tests for expected allow/deny behavior
- **Connectivity Tests**: Synthetic tests to verify legitimate traffic flows
- **Audit Mode**: Monitoring before enforcement to identify issues

## Testing Strategy

### Unit Testing

- Validate policy YAML syntax
- Check for common mistakes (missing DNS egress, etc.)
- Verify label selectors are correct

### Integration Testing

```yaml
# Example test: Verify frontend can reach backend
apiVersion: v1
kind: Pod
metadata:
  name: network-test-frontend
  labels:
    tier: frontend
spec:
  containers:
  - name: curl
    image: curlimages/curl
    command: ["curl", "http://backend-service:8080/health"]
```

### Staging Validation

- Deploy policies to staging environment
- Run full application test suites
- Monitor for denied connections
- Validate all expected traffic flows

### Production Validation

- Gradual rollout per namespace
- Continuous monitoring during rollout
- Automated rollback on high denial rates
- Manual verification of critical services

## Rollback Plan

If NetworkPolicies cause production issues:

1. **Immediate Rollback**:
   - Delete problematic NetworkPolicy: `kubectl delete networkpolicy <name> -n <namespace>`
   - Estimated rollback time: <5 minutes
   - Traffic immediately returns to default-allow

2. **Namespace-Level Rollback**:
   - Remove all policies from affected namespace
   - Investigate issues in development/staging
   - Redeploy corrected policies

3. **Cluster-Wide Rollback**:
   - Automation script to remove all NetworkPolicies
   - Keep Tailscale layer for perimeter security
   - Plan remediation before re-enabling

## Success Criteria

- ✅ All production namespaces have NetworkPolicies deployed
- ✅ Default-deny policies in place with explicit allow rules
- ✅ No legitimate traffic blocked (zero false positives in production)
- ✅ Reduced lateral movement risk (validated via penetration testing)
- ✅ Policies managed via GitOps (all changes version-controlled)
- ✅ Monitoring and alerting operational
- ✅ Team trained on policy management and troubleshooting
- ✅ Documentation complete (policy patterns, runbooks, troubleshooting)

## References

### Documentation

- [Kubernetes NetworkPolicies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [NetworkPolicy Editor](https://editor.cilium.io/) - Visual policy editor
- [Calico NetworkPolicy Tutorial](https://docs.projectcalico.org/security/tutorials/kubernetes-policy-basic)
- [Cilium NetworkPolicy Guide](https://docs.cilium.io/en/stable/security/policy/)

### Tools

- [kubectl-netpol](https://github.com/mattfenwick/kubectl-netpol) - NetworkPolicy debugging tool
- [inspektor-gadget](https://github.com/inspektor-gadget/inspektor-gadget) - Network monitoring
- [Goldilocks](https://github.com/FairwindsOps/goldilocks) - Policy recommendations

### Related Documentation

- [ADR-0009: Tailscale for Hybrid Cloud Networking](0009-tailscale-hybrid-networking.md)
- [ADR-0012: Identity and Access Management](0012-identity-access-management.md) (to be created)
- [Research: Zero Trust Architecture](../research/0019-zero-trust-architecture.md)
- [ADR-0005: Kubernetes as Container Platform](0005-kubernetes-container-platform.md)
- [ADR-0007: GitOps Workflow](0007-gitops-workflow.md)

## Implementation Timeline

| Phase | Timeline | Deliverables |
|-------|----------|--------------|
| **Phase 1: Development** | Q1 2026 (Jan-Mar) | Policies in dev clusters, templates created |
| **Phase 2: Staging** | Q1 2026 (Mar) | Staging validation, CI/CD integration |
| **Phase 3: Production** | Q2 2026 (Apr-Jun) | Production rollout, monitoring operational |
| **Phase 4: Advanced** | Q3 2026 (Jul-Sep) | Advanced egress policies, optimization |

## Future Enhancements

- **Advanced CNI Features**: Evaluate Cilium for Layer 7 policies and observability
- **Policy Automation**: Auto-generate policies from observed traffic patterns
- **Multi-Cluster Policies**: Extend policies across cluster boundaries
- **Service Mesh Integration**: Layer NetworkPolicies with Istio/Linkerd for defense-in-depth
- **eBPF-Based Policies**: Leverage eBPF for more efficient policy enforcement (Cilium)

This decision will be reviewed after Phase 3 completion or when triggered by significant changes
in requirements, performance impact, or available alternatives.
