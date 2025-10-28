# 12. Identity and Access Management with RBAC

Date: 2025-10-21

## Status

Accepted

## Context

Our zero-trust architecture (see [ADR-0009](0009-tailscale-hybrid-networking.md) and
[Zero Trust Research](../research/0019-zero-trust-architecture.md)) requires identity-based access
control at multiple layers. While Tailscale provides network-level identity authentication and
NetworkPolicies provide workload segmentation, we need comprehensive Identity and Access Management
(IAM) for Kubernetes API access and infrastructure resource management.

Current challenges:

- **Kubernetes API Access**: Need to control WHO can deploy, modify, and delete Kubernetes resources
- **Shared Credentials**: Traditional kubeconfig files with shared credentials don't scale securely
- **No Audit Trail**: Shared credentials prevent attribution of actions to specific users
- **Role Confusion**: Developers and SRE need different permission levels
- **Service Account Management**: CI/CD and automated systems need managed service accounts
- **Cross-Environment Access**: Development, staging, and production require different permission
  levels
- **Compliance Requirements**: SOC 2 and audit requirements need clear access control and logging

We need a solution that:

- Provides identity-based authentication (not shared credentials)
- Implements role-based access control (RBAC) for least-privilege
- Integrates with existing SSO (GitHub for Tailscale)
- Supports both human users and service accounts (CI/CD)
- Enables per-environment permission models
- Provides complete audit trail of all API access
- Scales from development to production

## Decision

We will adopt **Kubernetes RBAC** with **SSO integration** as the Layer 3 zero-trust security
control for identity and access management.

Specifically:

- **Kubernetes RBAC** will control access to Kubernetes API resources (pods, deployments, secrets)
- **SSO Integration** via GitHub for user authentication (consistent with Tailscale)
- **Role-Based Permissions** with predefined roles (Developer, SRE, Read-Only)
- **Namespace-Based Isolation** to separate development, staging, and production
- **Service Accounts** for CI/CD pipelines and automated systems
- **GitOps for RBAC Definitions** - all Roles and RoleBindings version-controlled
- **Audit Logging** enabled for all Kubernetes API access
- **Integration with Tailscale**: Network access via Tailscale, API access via RBAC

## Architecture

### Identity Flow

```
User → GitHub SSO (2FA) → Tailscale Auth → Network Access
                       ↓
                  OIDC Token
                       ↓
            Kubernetes API Server → RBAC Check → Resource Access
                                              ↓
                                        Audit Log
```

### RBAC Model

**Three-Tier Permission Model**:

1. **Developer Role** (Development & Staging):
   - Deploy applications
   - View logs and resources
   - Create/update non-sensitive resources
   - NO access to production
   - NO access to secrets (except in development)

2. **SRE Role** (All Environments):
   - Full access to production
   - Manage infrastructure resources
   - Access secrets and sensitive data
   - Emergency operations
   - RBAC management

3. **Read-Only Role** (All Environments):
   - View-only access to all resources
   - For auditors, stakeholders, and monitoring

### Environment Separation

```yaml
Namespaces:
  - development (Developer: full, SRE: full, Read-Only: view)
  - staging (Developer: full, SRE: full, Read-Only: view)
  - production (Developer: none, SRE: full, Read-Only: view)
  - monitoring (Developer: view, SRE: full, Read-Only: view)
  - kube-system (Developer: none, SRE: full, Read-Only: view)
```

## Implementation

### Phase 1: SSO Integration (Current - Q4 2025)

**Objective**: Integrate GitHub SSO for Kubernetes authentication

**Components**:

1. **OIDC Configuration** on Kubernetes API server:

   ```yaml
   apiServer:
     extraArgs:
       oidc-issuer-url: https://github.com
       oidc-client-id: <github-oauth-app-id>
       oidc-username-claim: email
       oidc-groups-claim: groups
   ```

2. **GitHub OAuth Application** for Kubernetes access

3. **kubelogin** for user authentication:

   ```bash
   # Install kubelogin
   kubectl krew install oidc-login

   # Configure kubeconfig
   kubectl config set-credentials github-user \
     --exec-command=kubectl \
     --exec-arg=oidc-login \
     --exec-arg=get-token \
     --exec-arg=--oidc-issuer-url=https://github.com \
     --exec-arg=--oidc-client-id=<client-id>
   ```

### Phase 2: RBAC Roles (Q4 2025)

**Objective**: Define and implement role-based access control

**Developer Role** (development & staging namespaces):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: development
rules:
  # Application resources
  - apiGroups: ["", "apps", "batch"]
    resources:
      - pods
      - deployments
      - replicasets
      - jobs
      - cronjobs
      - services
      - configmaps
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

  # Logs and debugging
  - apiGroups: [""]
    resources:
      - pods/log
      - pods/exec
    verbs: ["get", "list"]

  # Limited secret access (development only)
  - apiGroups: [""]
    resources:
      - secrets
    verbs: ["get", "list"]
    resourceNames: ["dev-*"]  # Only secrets prefixed with dev-
```

**SRE Role** (all namespaces):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: sre
rules:
  # Full access to all resources
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]

  # Non-resource URLs (metrics, health)
  - nonResourceURLs: ["*"]
    verbs: ["*"]
```

**Read-Only Role** (all namespaces):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: read-only
rules:
  # View all resources
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]

  # View non-resource URLs
  - nonResourceURLs: ["*"]
    verbs: ["get"]
```

**RoleBindings**:

```yaml
---
# Bind developers to development namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: development
subjects:
  - kind: Group
    name: developers  # GitHub team
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
---
# Bind SRE to cluster admin
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: sre-binding
subjects:
  - kind: Group
    name: sre  # GitHub team
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: sre
  apiGroup: rbac.authorization.k8s.io
---
# Bind read-only to all namespaces
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-only-binding
subjects:
  - kind: Group
    name: auditors  # GitHub team
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: read-only
  apiGroup: rbac.authorization.k8s.io
```

### Phase 3: Service Accounts (Q4 2025)

**Objective**: Secure CI/CD and automation access

**CI/CD Service Account**:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: github-actions
  namespace: development
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: github-actions-deployer
  namespace: development
rules:
  - apiGroups: ["", "apps"]
    resources: ["deployments", "services", "configmaps"]
    verbs: ["get", "list", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: github-actions-binding
  namespace: development
subjects:
  - kind: ServiceAccount
    name: github-actions
    namespace: development
roleRef:
  kind: Role
  name: github-actions-deployer
  apiGroup: rbac.authorization.k8s.io
```

**Monitoring Service Account**:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-reader
rules:
  - apiGroups: [""]
    resources:
      - nodes
      - nodes/metrics
      - services
      - endpoints
      - pods
    verbs: ["get", "list", "watch"]
  - nonResourceURLs: ["/metrics"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-binding
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: monitoring
roleRef:
  kind: ClusterRole
  name: prometheus-reader
  apiGroup: rbac.authorization.k8s.io
```

### Phase 4: Audit Logging (Q1 2026)

**Objective**: Complete audit trail for compliance

**Audit Policy**:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log all requests at Metadata level
  - level: Metadata
    omitStages:
      - RequestReceived

  # Log sensitive resources at Request level
  - level: Request
    resources:
      - group: ""
        resources: ["secrets", "configmaps"]
      - group: "rbac.authorization.k8s.io"

  # Log authentication failures at Request level
  - level: Request
    omitStages:
      - RequestReceived
    userGroups:
      - system:unauthenticated

  # Don't log read-only requests to non-sensitive resources
  - level: None
    verbs: ["get", "list", "watch"]
    resources:
      - group: ""
        resources: ["pods", "services"]
```

**Audit Log Analysis**:

```bash
# Common audit queries
kubectl logs -n kube-system kube-apiserver-* | grep audit

# Failed authentication attempts
jq 'select(.responseStatus.code >= 400)' /var/log/kubernetes/audit.log

# Secret access
jq 'select(.objectRef.resource == "secrets")' /var/log/kubernetes/audit.log

# RBAC changes
jq 'select(.objectRef.apiGroup == "rbac.authorization.k8s.io")' \
  /var/log/kubernetes/audit.log
```

## Consequences

### Positive

**Security Improvements**:

- ✅ **Identity-Based Access**: Every action attributed to specific user or service account
- ✅ **Least Privilege**: Granular permissions based on role and environment
- ✅ **No Shared Credentials**: Each user authenticates individually via SSO
- ✅ **Audit Trail**: Complete logging of all API access for compliance
- ✅ **Namespace Isolation**: Production isolated from development access

**Operational Benefits**:

- ✅ **SSO Integration**: Same GitHub authentication as Tailscale (consistent UX)
- ✅ **GitOps Management**: RBAC definitions version-controlled and reviewed
- ✅ **Service Account Management**: Automated systems have scoped, managed access
- ✅ **Environment Separation**: Clear boundaries between dev/staging/production

**Compliance**:

- ✅ **SOC 2 Compliance**: Access control and audit logging requirements met
- ✅ **Accountability**: All actions traceable to individuals
- ✅ **Access Reviews**: Regular review of RoleBindings in Git
- ✅ **Evidence**: Audit logs provide evidence for compliance audits

### Negative

**Complexity**:

- ❌ **RBAC Complexity**: Kubernetes RBAC syntax steep learning curve
- ❌ **Role Management**: Requires careful design to avoid overly permissive roles
- ❌ **SSO Setup**: Initial OIDC integration requires careful configuration

**Operational Overhead**:

- ❌ **Initial Setup**: 10-20 hours to configure SSO and define roles
- ❌ **Ongoing Maintenance**: ~2 hours/month to manage role assignments
- ❌ **User Onboarding**: Each new team member requires role assignment

**User Experience**:

- ❌ **Authentication Flow**: Users must authenticate via kubelogin (additional step)
- ❌ **Token Expiration**: OIDC tokens expire, requiring re-authentication
- ❌ **Troubleshooting**: Permission errors harder to debug than shared credentials

**Risks**:

- ❌ **Lockout Risk**: Misconfigured RBAC could lock out administrators
- ❌ **Service Disruption**: Incorrect service account permissions can break CI/CD
- ❌ **SSO Dependency**: GitHub outage affects Kubernetes access

### Trade-offs

**Security vs. Convenience**:

- **Choice**: Requiring individual authentication vs. shared kubeconfig
- **Rationale**: Security and accountability requirements outweigh convenience
- **Mitigation**: Streamlined authentication flow with kubelogin, clear documentation

**Granularity vs. Simplicity**:

- **Choice**: Three predefined roles vs. custom roles per user
- **Rationale**: Standardized roles easier to manage and audit
- **Mitigation**: Can create additional roles for specific use cases when needed

**SSO vs. Certificate-Based Auth**:

- **Choice**: Using GitHub SSO (OIDC) vs. client certificates
- **Rationale**: SSO provides better user experience and integrates with Tailscale
- **Mitigation**: Certificate-based auth available as backup for SSO outages

## Integration with Other Security Layers

### Layer 1: Tailscale (Network Access)

- **Tailscale Controls**: Network access TO Kubernetes API server
- **RBAC Controls**: Authorization for API operations WITHIN Kubernetes
- **Integration**: Must authenticate with Tailscale AND pass RBAC checks

### Layer 2: NetworkPolicies (Workload Segmentation)

- **RBAC Controls**: WHO can deploy NetworkPolicies
- **NetworkPolicies Control**: Network traffic between workloads
- **Integration**: RBAC prevents unauthorized policy modifications

### Layer 5: Privileged Access Management (Future)

- **Teleport Enhances**: Session recording, just-in-time access
- **RBAC Provides**: Baseline authorization framework
- **Integration**: Teleport can integrate with Kubernetes RBAC for unified access

## Monitoring and Validation

### Key Metrics

- **Authentication Success Rate**: Should be >99%
- **Authorization Denials**: Track denied API requests (indicates permission issues)
- **Role Coverage**: Percentage of users with assigned roles (target: 100%)
- **Service Account Usage**: Monitor service account access patterns

### Alerting Rules

**Critical Alerts**:

- Multiple failed authentication attempts (>5 in 10 minutes)
- RBAC policy modifications outside change windows
- Access to production secrets by non-SRE users
- Service account token compromise indicators

**Warning Alerts**:

- Increasing rate of authorization denials
- Users without role assignments
- Expired OIDC tokens not being refreshed

### Audit Queries

```bash
# Users accessing production secrets
kubectl get events --all-namespaces --field-selector \
  involvedObject.kind=Secret,involvedObject.namespace=production

# Failed authorization attempts
kubectl logs -n kube-system kube-apiserver-* | \
  grep "Forbidden" | jq -r '.user.username'

# RBAC changes
kubectl get events --all-namespaces --field-selector \
  involvedObject.kind=Role,involvedObject.kind=RoleBinding
```

## Emergency Access

### Break-Glass Procedure

**Scenario**: SSO provider (GitHub) is unavailable, need emergency cluster access

**Backup Authentication**:

1. **Certificate-Based Admin Access**:

   ```bash
   # Emergency kubeconfig with certificate authentication
   kubectl config set-cluster production \
     --certificate-authority=/path/to/ca.crt \
     --server=https://k8s-api.example.com:6443

   kubectl config set-credentials emergency-admin \
     --client-certificate=/path/to/admin.crt \
     --client-key=/path/to/admin.key

   kubectl config set-context emergency \
     --cluster=production \
     --user=emergency-admin
   ```

2. **Access Control**:
   - Emergency credentials stored in secure vault (HashiCorp Vault)
   - Requires approval from 2+ SRE team members
   - Time-limited (4-hour window)
   - All actions logged and reviewed
   - Post-incident review required

## Success Criteria

- ✅ All users authenticate via GitHub SSO (no shared kubeconfig)
- ✅ RBAC roles defined for Developer, SRE, and Read-Only
- ✅ Namespace-based access control enforced
- ✅ Service accounts for CI/CD with scoped permissions
- ✅ Audit logging enabled and monitored
- ✅ Zero production access for developers (enforced by RBAC)
- ✅ Complete audit trail for compliance
- ✅ Documentation and training materials complete

## Testing Strategy

### Pre-Production Testing

1. **Role Validation**:

   ```bash
   # Test developer role (should succeed)
   kubectl auth can-i create deployment --namespace=development \
     --as=user:developer@example.com

   # Test developer role in production (should fail)
   kubectl auth can-i create deployment --namespace=production \
     --as=user:developer@example.com
   ```

2. **Service Account Testing**:

   ```bash
   # Test CI/CD service account
   kubectl auth can-i create deployment --namespace=development \
     --as=system:serviceaccount:development:github-actions
   ```

3. **Audit Log Validation**:
   - Verify all API calls are logged
   - Confirm user attribution is correct
   - Test log queries for compliance reporting

### Production Validation

- User acceptance testing with development team
- Verify SSO authentication flow
- Confirm role permissions in each environment
- Validate emergency access procedures

## Rollback Plan

If RBAC causes access issues:

1. **Immediate Rollback**:
   - Use emergency certificate-based admin access
   - Temporarily grant broader permissions
   - Estimated time: <10 minutes

2. **Investigation**:
   - Review audit logs for failed authorizations
   - Identify misconfigured roles or bindings
   - Test fixes in staging environment

3. **Remediation**:
   - Update RBAC definitions in Git
   - Apply corrected policies
   - Verify access restored

## References

### Documentation

- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [OIDC Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens)
- [Audit Logging](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [kubelogin](https://github.com/int128/kubelogin)

### Tools

- [rbac-lookup](https://github.com/FairwindsOps/rbac-lookup) - RBAC debugging
- [kubectl-who-can](https://github.com/aquasecurity/kubectl-who-can) - Permission queries
- [audit2rbac](https://github.com/liggitt/audit2rbac) - Generate RBAC from audit logs

### Related Documentation

- [ADR-0009: Tailscale for Hybrid Cloud Networking](0009-tailscale-hybrid-networking.md)
- [ADR-0011: Kubernetes NetworkPolicies](0011-kubernetes-network-policies.md)
- [Research: Zero Trust Architecture](../research/0019-zero-trust-architecture.md)
- [ADR-0005: Kubernetes as Container Platform](0005-kubernetes-container-platform.md)
- [ADR-0006: GitHub Actions CI/CD](0006-github-actions-cicd.md)
- [ADR-0007: GitOps Workflow](0007-gitops-workflow.md)
- [ADR-0008: Secret Management Strategy](0008-secret-management.md)

## Implementation Timeline

| Phase | Timeline | Deliverables |
|-------|----------|--------------|
| **Phase 1: SSO Integration** | Q4 2025 (Oct-Dec) | GitHub OIDC configured, kubelogin setup |
| **Phase 2: RBAC Roles** | Q4 2025 (Nov-Dec) | Roles defined, RoleBindings applied |
| **Phase 3: Service Accounts** | Q4 2025 (Dec) | CI/CD service accounts created |
| **Phase 4: Audit Logging** | Q1 2026 (Jan-Mar) | Audit logs enabled, monitoring operational |

## Future Enhancements

- **Just-in-Time Access**: Temporary elevated permissions for emergency operations
- **Dynamic Role Assignment**: Automatically assign roles based on GitHub team membership
- **Teleport Integration**: Enhanced session recording and access management
- **Certificate Rotation**: Automated rotation of emergency access certificates
- **Policy-as-Code Validation**: Automated testing of RBAC policies in CI/CD
- **Fine-Grained Permissions**: Additional custom roles for specialized use cases

This decision will be reviewed annually or when triggered by significant changes in requirements,
security incidents, or compliance needs.
