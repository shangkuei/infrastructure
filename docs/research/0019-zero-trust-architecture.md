# Research: Zero Trust Architecture

Date: 2025-10-21
Author: Infrastructure Team
Status: Accepted (based on ADR-0009)

## Objective

Implement Zero Trust security model for hybrid cloud infrastructure using practical, scalable approaches suitable for small teams.

## Executive Summary

Zero Trust is a security model that eliminates implicit trust based on network location,
instead requiring continuous verification of every access request based on identity, device
posture, and context. For hybrid cloud infrastructure, we implement Zero Trust through multiple
layers, with **Tailscale** providing the foundational network-level zero trust capabilities.

**Key Decision**: Tailscale mesh network serves as the primary zero-trust networking layer, providing identity-based access control, automatic encryption, and micro-segmentation across our hybrid infrastructure.

## Scope

- Zero Trust principles and framework (NIST SP 800-207)
- Network segmentation and micro-segmentation
- Identity and access management (IAM)
- mTLS and service-to-service authentication
- Policy enforcement points across infrastructure layers

## Zero Trust Principles

### 1. Never Trust, Always Verify

**Traditional Model**: Trust based on network location (inside corporate network = trusted)
**Zero Trust Model**: Verify every access request regardless of location

**Our Implementation**:

- Tailscale ACLs verify every connection attempt
- SSO authentication for all user access (GitHub/Google/Okta)
- WireGuard encryption for all network traffic (no unencrypted "internal" traffic)
- Continuous authentication (not one-time login)

### 2. Assume Breach

**Mindset**: Design systems assuming attackers are already inside the network

**Our Implementation**:

- End-to-end encryption prevents lateral movement even if network is compromised
- Micro-segmentation limits blast radius of compromised nodes
- Audit logging detects suspicious access patterns
- No "trusted" network zones with relaxed security

### 3. Verify Explicitly (Identity-Based Access)

**Traditional Model**: Access based on IP address or network segment
**Zero Trust Model**: Access tied to verified user/service identity

**Our Implementation**:

- SSO integration with Tailscale (GitHub authentication)
- Each device has unique WireGuard cryptographic identity
- Service accounts for non-human access (Kubernetes, CI/CD)
- No shared credentials or static passwords

### 4. Least Privilege Access

**Principle**: Grant minimum permissions necessary for task completion

**Our Implementation**:

- Tag-based ACLs for granular resource access control
- Environment separation (dev, staging, production) with distinct policies
- Port-level access control (only required services exposed)
- Regular access reviews and permission audits

### 5. Micro-Segmentation

**Traditional Model**: Flat networks with perimeter security
**Zero Trust Model**: Granular network segmentation at workload level

**Our Implementation**:

- Tailscale ACLs segment network by environment, role, and service
- Kubernetes NetworkPolicies for pod-level isolation
- Service mesh (future) for application-level segmentation

## Zero Trust Architecture Layers

### Layer 1: Network Access (Implemented)

**Technology**: Tailscale mesh network

**Capabilities**:

- **Identity-Based Authentication**: SSO (GitHub/Google/Okta) with 2FA
- **Automatic Encryption**: WireGuard encrypts all traffic end-to-end
- **Centralized Policy**: GitOps-managed ACLs for access control
- **Audit Logging**: Complete trail of all connection attempts
- **Micro-Segmentation**: Tag-based network isolation

**Example ACL Configuration**:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["group:developers"],
      "dst": ["tag:development:*"],
      "comment": "Developers can access all development resources"
    },
    {
      "action": "accept",
      "src": ["group:sre"],
      "dst": ["tag:production:22,443,6443"],
      "comment": "SRE can access production SSH, HTTPS, and Kubernetes API"
    },
    {
      "action": "accept",
      "src": ["tag:kubernetes-prod"],
      "dst": ["tag:database-prod:5432"],
      "comment": "Production pods can access production databases"
    },
    {
      "action": "accept",
      "src": ["group:data-team"],
      "dst": ["tag:analytics:*"],
      "comment": "Data team can access analytics infrastructure"
    }
  ],
  "tagOwners": {
    "tag:production": ["group:sre"],
    "tag:development": ["group:developers"],
    "tag:database-prod": ["group:sre"],
    "tag:kubernetes-prod": ["group:sre"],
    "tag:analytics": ["group:sre", "group:data-team"]
  },
  "groups": {
    "group:sre": ["user@example.com", "sre@example.com"],
    "group:developers": ["dev1@example.com", "dev2@example.com"],
    "group:data-team": ["data@example.com"]
  }
}
```

**Benefits**:

- ✅ No VPN complexity or shared secrets
- ✅ Unified access control across clouds and on-premise
- ✅ Automatic NAT traversal and peer discovery
- ✅ MagicDNS for service discovery
- ✅ Sub-10ms latency overhead

**Security Features**:

- WireGuard cryptography (ChaCha20-Poly1305, Curve25519)
- Automatic key rotation
- No trust in relay servers (DERP relays cannot decrypt traffic)
- Protection against man-in-the-middle and replay attacks

### Layer 2: Kubernetes Network Policies (Planned)

**Decision**: See [ADR-0011: Kubernetes NetworkPolicies](../decisions/0011-kubernetes-network-policies.md)

**Technology**: Kubernetes NetworkPolicies + Cilium (future)

**Capabilities**:

- Pod-to-pod communication control
- Namespace isolation
- Label-based policies
- Ingress/egress traffic rules

**Example NetworkPolicy**:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
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
```

**Integration with Tailscale**:

- Tailscale controls access TO Kubernetes clusters
- NetworkPolicies control access WITHIN Kubernetes clusters
- Defense in depth: both layers must authorize traffic

### Layer 3: Identity and Access Management (Implemented)

**Decision**: See [ADR-0012: Identity and Access Management](../decisions/0012-identity-access-management.md)

**Technology**: SSO (GitHub/Google/Okta) + Kubernetes RBAC

**Capabilities**:

- Single sign-on for user authentication
- Multi-factor authentication (2FA)
- Role-based access control (RBAC)
- Service account management
- Token-based authentication for CI/CD

**User Authentication Flow**:

```
1. User requests access → Tailscale authentication
2. Tailscale redirects to SSO provider (GitHub)
3. User authenticates with SSO (username + 2FA)
4. SSO returns identity assertion to Tailscale
5. Tailscale issues WireGuard credentials
6. User's device joins Tailscale network
7. ACLs evaluated for each connection attempt
```

**Kubernetes RBAC Example**:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: development
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["pods", "deployments", "jobs"]
    verbs: ["get", "list", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: sre-role
  namespace: production
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
```

### Layer 4: Service-to-Service Authentication (Future)

**Technology**: Service mesh (Istio/Linkerd) for mTLS

**Capabilities**:

- Automatic mutual TLS between services
- Service identity and authentication
- Fine-grained authorization policies
- Traffic encryption within Kubernetes

**Why Not Immediately**:

- Tailscale provides network-level encryption already
- Service mesh adds operational complexity
- Cost/benefit analysis favors deferring until scale requires it
- Can be added incrementally when needed

**Future Implementation Timeline**:

- Evaluate when: >10 microservices, compliance requires service-level mTLS
- Candidate solutions: Linkerd (lightweight) or Istio (feature-rich)

### Layer 5: Privileged Access Management (Future)

**Technology**: Teleport or Boundary for infrastructure access

**Capabilities**:

- Certificate-based SSH access (no static keys)
- Session recording and audit
- Just-in-time access provisioning
- Kubernetes access with RBAC integration

**Current State**:

- Tailscale provides network access layer
- SSH keys managed manually (to be improved)
- Kubernetes access via kubeconfig with RBAC

**Future Enhancement**:

- Teleport for unified access to SSH, Kubernetes, databases
- Short-lived certificates replace static SSH keys
- Session recording for compliance and audit

## Implementation Roadmap

### Phase 1: Foundation (Current - Q4 2025)

**Status**: ✅ In Progress

**Components**:

- ✅ Tailscale mesh network deployed
- ✅ SSO integration with GitHub
- ✅ ACL-based access control for environments
- 🔄 Kubernetes RBAC implementation
- 🔄 Audit logging and monitoring

**Security Posture Achieved**:

- Identity-based network access
- Encrypted traffic across hybrid infrastructure
- Least-privilege access by environment
- Complete audit trail

### Phase 2: Kubernetes Hardening (Q1 2026)

**Status**: 📋 Planned

**Components**:

- NetworkPolicies for pod-to-pod isolation
- Namespace segmentation by environment
- Enhanced RBAC with fine-grained roles
- Pod Security Standards enforcement
- Network policy validation in CI/CD

**Security Posture Improvement**:

- Workload-level micro-segmentation
- Defense in depth for Kubernetes
- Automated policy enforcement

### Phase 3: Service Mesh (Q2-Q3 2026)

**Status**: 📋 Future

**Components**:

- Service mesh deployment (Linkerd or Istio)
- Automatic mTLS between services
- Service-level authorization policies
- Traffic observability and tracing

**Trigger Conditions**:

- Microservice count >10
- Compliance requires service-level encryption
- Need for fine-grained service authorization

### Phase 4: Privileged Access (Q4 2026)

**Status**: 📋 Future

**Components**:

- Teleport deployment for infrastructure access
- Certificate-based SSH (replace static keys)
- Session recording for audit
- Just-in-time access provisioning
- Database access proxy

**Trigger Conditions**:

- Compliance requirements for session recording
- Team size >10 (key management complexity)
- Need for temporary/emergency access workflows

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Users (SSO: GitHub/Google)                    │
│                         ↓ (2FA Authentication)                       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│                  Tailscale Control Plane (Zero Trust)                │
│  - Identity verification (SSO integration)                           │
│  - ACL policy enforcement                                            │
│  - Audit logging                                                     │
│  - WireGuard key distribution                                        │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼────────┐     ┌───────▼────────┐    ┌───────▼────────┐
│   AWS VPC      │     │  Azure VNet    │    │  On-Premise    │
│                │     │                │    │                │
│ ┌────────────┐ │     │ ┌────────────┐ │    │ ┌────────────┐ │
│ │ Tailscale  │◄├─────┤►│ Tailscale  │◄├────┤►│ Tailscale  │ │
│ │ Subnet     │ │     │ │ Subnet     │ │    │ │ Subnet     │ │
│ │ Router     │ │     │ │ Router     │ │    │ │ Router     │ │
│ └──────┬─────┘ │     │ └──────┬─────┘ │    │ └──────┬─────┘ │
│        │       │     │        │       │    │        │       │
│ ┌──────▼─────┐ │     │ ┌──────▼─────┐ │    │ ┌──────▼─────┐ │
│ │ Kubernetes │ │     │ │ Kubernetes │ │    │ │ Services   │ │
│ │ Cluster    │ │     │ │ Cluster    │ │    │ │            │ │
│ │            │ │     │ │            │ │    │ │            │ │
│ │ ┌────────┐ │ │     │ │ ┌────────┐ │ │    │ │ ┌────────┐ │ │
│ │ │Network │ │ │     │ │ │Network │ │ │    │ │ │Firewall│ │ │
│ │ │Policies│ │ │     │ │ │Policies│ │ │    │ │ │ Rules  │ │ │
│ │ └────────┘ │ │     │ │ └────────┘ │ │    │ │ └────────┘ │ │
│ │            │ │     │ │            │ │    │ │            │ │
│ │ [Services] │ │     │ │ [Services] │ │    │ │ [Services] │ │
│ └────────────┘ │     │ └────────────┘ │    │ └────────────┘ │
└────────────────┘     └────────────────┘    └────────────────┘
      │                      │                      │
      └──────────────────────┴──────────────────────┘
         (Encrypted WireGuard tunnels - peer-to-peer)

Layer 1: Tailscale (Identity + Network Encryption)
Layer 2: NetworkPolicies (Pod-level isolation)
Layer 3: RBAC (Kubernetes authorization)
Layer 4: Service Mesh (Service-level mTLS) [Future]
```

## Security Benefits

### 1. Identity-Based Access Control

**Problem Solved**: Traditional IP-based security fails in dynamic cloud environments

**Solution**:

- Access tied to verified user identity (SSO)
- Device-specific cryptographic keys (WireGuard)
- No shared secrets or static passwords
- Automatic key rotation

**Threat Mitigation**:

- IP spoofing → Prevented (identity required)
- Stolen credentials → Limited blast radius (device-specific keys)
- Insider threats → Audit trail and least-privilege access

### 2. End-to-End Encryption

**Problem Solved**: "Secure perimeter" model leaves internal traffic unencrypted

**Solution**:

- All Tailscale traffic encrypted with WireGuard
- No unencrypted "internal" network
- Encryption independent of underlying network

**Threat Mitigation**:

- Network eavesdropping → Prevented (encrypted tunnels)
- Man-in-the-middle attacks → Prevented (authenticated encryption)
- Cloud provider snooping → Protected (end-to-end encryption)

### 3. Micro-Segmentation

**Problem Solved**: Flat networks allow lateral movement after breach

**Solution**:

- Tailscale ACLs segment by environment, role, service
- Kubernetes NetworkPolicies for pod-level isolation
- Default-deny policies (explicit allow required)

**Threat Mitigation**:

- Lateral movement → Limited (segmentation boundaries)
- Blast radius → Minimized (compartmentalization)
- Privilege escalation → Harder (least-privilege enforcement)

### 4. Continuous Verification

**Problem Solved**: "One-time login" model doesn't detect compromised sessions

**Solution**:

- Every connection verified against current ACL state
- Real-time policy updates (no waiting for agent refresh)
- Audit logging of all access attempts

**Threat Mitigation**:

- Compromised sessions → Revocable (policy updates)
- Unauthorized access → Detected (audit logs)
- Policy drift → Prevented (GitOps for ACLs)

### 5. Defense in Depth

**Problem Solved**: Single security layer creates single point of failure

**Solution**:

- Multiple independent security layers
- Each layer enforces different controls
- Failure in one layer doesn't compromise entire system

**Security Layers**:

1. Tailscale ACLs (network access)
2. Kubernetes NetworkPolicies (pod-to-pod)
3. Kubernetes RBAC (API access)
4. Application authentication (app-level)
5. Audit logging (detection)

## Compliance and Audit

### Audit Logging

**What We Log**:

- All connection attempts (successful and denied)
- ACL policy changes (who, what, when)
- User authentication events
- Device authorization/deauthorization
- SSH sessions (future: Teleport)

**Log Retention**:

- Security events: 1 year minimum
- Access logs: 90 days
- Audit trail: Immutable, tamper-proof

**Log Storage**:

- Tailscale audit logs (managed service)
- Kubernetes audit logs (centralized logging)
- Application logs (ELK/Loki stack)

### Compliance Frameworks

**SOC 2 Type II**:

- ✅ Tailscale is SOC 2 compliant
- ✅ Access control policies documented
- ✅ Audit logging enabled
- ✅ Regular access reviews

**GDPR**:

- ✅ Data encryption in transit
- ✅ Access control and authorization
- ✅ Audit trail for data access
- ✅ Right to revoke access

**HIPAA** (if applicable):

- ✅ Encryption of PHI in transit
- ✅ Audit logging of access
- ✅ Access control and authentication
- ⚠️ Business Associate Agreement (BAA) with Tailscale

**ISO 27001**:

- ✅ Risk-based access control
- ✅ Incident detection and response
- ✅ Continuous monitoring
- ✅ Regular security reviews

## Operational Considerations

### Day 1: User Onboarding

**Process**:

1. User invited to Tailscale organization
2. User authenticates with SSO (GitHub)
3. User's device joins Tailscale network
4. ACLs automatically apply based on user group
5. User can access authorized resources

**Time to Access**: <5 minutes from invite to working access

### Day 2: Access Management

**Common Operations**:

- Add user to group: Update ACL config in Git, merge PR
- Grant temporary access: Create time-limited ACL rule
- Revoke access: Remove from group or delete node
- Audit access: Query Tailscale audit logs

**Automation**:

- ACL changes via GitOps workflow
- Automated testing of ACL policies
- Alerts for suspicious access patterns

### Emergency Access

**Break-Glass Procedure**:

1. Emergency access group with broad permissions
2. Requires manual approval from 2+ admins
3. Time-limited (4-hour window)
4. All actions logged and reviewed
5. Post-incident review required

**Use Cases**:

- Production incident requiring immediate access
- Critical security vulnerability remediation
- Infrastructure emergency (outage, data loss)

## Cost Analysis

### Current Costs (Phase 1)

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| Tailscale Team Plan | $600 (100 users @ $6/user) | Identity + network layer |
| GitHub SSO | $0 | Included in GitHub plan |
| Kubernetes RBAC | $0 | Native Kubernetes feature |
| Audit Logging | $50 | Log storage and analysis |
| **Total** | **$650/month** | **$7,800/year** |

### Cost Comparison

| Approach | Monthly Cost | Operational Overhead | Total Cost (1st year) |
|----------|--------------|----------------------|----------------------|
| **Tailscale Zero Trust** | $650 | 4 hours/month | $7,800 + $4,800 = $12,600 |
| Traditional VPN + Bastion | $200 | 20 hours/month | $2,400 + $24,000 = $26,400 |
| Cloud VPN Gateways | $500 | 15 hours/month | $6,000 + $18,000 = $24,000 |

**ROI**: Tailscale approach saves $13,800/year vs. traditional VPN (52% cost reduction)

### Future Costs (Phases 2-4)

| Phase | Additional Monthly Cost | Timeline |
|-------|-------------------------|----------|
| Phase 2: NetworkPolicies | $0 (native Kubernetes) | Q1 2026 |
| Phase 3: Service Mesh | $100 (monitoring/ops) | Q2-Q3 2026 |
| Phase 4: Teleport | $300 (25 users @ $12/user) | Q4 2026 |

## Monitoring and Alerting

### Key Metrics

**Security Metrics**:

- Unauthorized access attempts per day
- Failed authentication rate
- Policy violation count
- Time to detect suspicious activity
- Time to revoke compromised access

**Operational Metrics**:

- Active Tailscale connections
- Connection success rate
- ACL policy update frequency
- User onboarding time
- Mean time to grant access

### Alerting Rules

**Critical Alerts**:

- Multiple failed authentication attempts (>5 in 1 hour)
- Access from unexpected geographic location
- Policy changes outside change window
- Node compromise indicators
- Mass data access or exfiltration attempts

**Warning Alerts**:

- ACL policy syntax errors
- Deprecated authentication methods in use
- Certificate expiration approaching
- Unusual access patterns

## Testing and Validation

### Security Testing

**Penetration Testing**:

- Annual third-party security audit
- Quarterly internal security assessments
- Continuous vulnerability scanning

**Access Control Testing**:

- Verify unauthorized access is blocked
- Test ACL policies in staging environment
- Validate RBAC configurations
- Test emergency access procedures

**Incident Response Drills**:

- Simulated breach scenarios
- Access revocation procedures
- Policy rollback testing
- Disaster recovery validation

### Compliance Testing

**Quarterly Reviews**:

- User access audit (remove unused accounts)
- ACL policy review (remove stale rules)
- Log retention compliance
- Encryption verification

## Challenges and Mitigations

### Challenge 1: User Experience vs. Security

**Tension**: Strong security can create friction for users

**Mitigation**:

- SSO reduces password fatigue (single login)
- MagicDNS simplifies service discovery
- Automated access provisioning reduces waiting
- Clear documentation and training

### Challenge 2: Operational Complexity

**Tension**: Multi-layer security increases operational burden

**Mitigation**:

- Managed Tailscale service reduces network ops
- GitOps for ACL management (infrastructure as code)
- Automation for common operations
- Phased implementation (not all at once)

### Challenge 3: Cloud Provider Dependencies

**Tension**: Tailscale control plane is managed service

**Mitigation**:

- Data encrypted end-to-end (control plane sees metadata only)
- SOC 2 compliance provides assurance
- Headscale available as self-hosted alternative
- Exit strategy documented

### Challenge 4: Cost Scalability

**Tension**: Per-user costs increase with team growth

**Mitigation**:

- Shared service accounts for CI/CD (not per-user)
- Regular access reviews to remove inactive users
- Cost/benefit analysis at milestones (50, 100, 200 users)
- Headscale migration option if cost becomes prohibitive

## Success Metrics

### Security Posture Improvement

**Baseline** (Traditional perimeter security):

- Network access based on IP address
- VPN with shared credentials
- Flat internal network
- Limited audit logging

**Target** (Zero Trust with Tailscale):

- ✅ 100% identity-based access
- ✅ 100% encrypted internal traffic
- ✅ Micro-segmentation by environment
- ✅ Complete audit trail of access

**Measurable Improvements**:

- Reduce attack surface by 80% (limited exposed services)
- Reduce lateral movement risk by 90% (micro-segmentation)
- Reduce unauthorized access by 95% (identity + ACLs)
- Reduce time to revoke access from hours to minutes

### Operational Efficiency

**Before**:

- VPN setup: 30-60 minutes per user
- Access grant: 2-4 hours (manual approval + config)
- Access revocation: 1-2 hours
- Network maintenance: 20 hours/month

**After**:

- Tailscale onboarding: <5 minutes per user
- Access grant: <10 minutes (GitOps PR)
- Access revocation: <1 minute (remove from group)
- Network maintenance: <2 hours/month

**Efficiency Gains**: 90% reduction in access management time

## Next Steps

### Immediate Actions (Q4 2025)

- ✅ Tailscale deployment complete (development environment)
- 🔄 Expand Tailscale to staging and production
- 🔄 Document ACL policies for all environments
- 🔄 Implement Kubernetes RBAC
- 🔄 Set up audit logging and monitoring
- 📋 Create security incident response runbook

### Short-term (Q1 2026)

- 📋 Deploy Kubernetes NetworkPolicies
- 📋 Implement automated ACL testing in CI/CD
- 📋 Conduct security audit and penetration test
- 📋 Create user training materials
- 📋 Establish access review process

### Long-term (Q2-Q4 2026)

- 📋 Evaluate service mesh deployment
- 📋 Research Teleport for privileged access
- 📋 Implement session recording for compliance
- 📋 Develop zero-trust roadmap for next phase

## Conclusion

Zero Trust architecture is not a single product or technology, but a comprehensive security strategy that fundamentally changes how we approach access control and network security.

**Tailscale provides the foundational layer** for our zero-trust implementation by:

- Eliminating network location as a basis for trust
- Enforcing identity-based access control
- Encrypting all traffic by default
- Enabling micro-segmentation at scale
- Providing comprehensive audit logging

This foundation allows us to build additional security layers incrementally (NetworkPolicies, service mesh, privileged access management) without disrupting existing operations.

**Key Takeaway**: Zero Trust is a journey, not a destination. We implement it in phases, continuously improving our security posture while maintaining operational efficiency.

## References

### Standards and Frameworks

- [NIST SP 800-207: Zero Trust Architecture](https://www.nist.gov/publications/zero-trust-architecture)
- [Google BeyondCorp](https://cloud.google.com/beyondcorp)
- [CISA Zero Trust Maturity Model](https://www.cisa.gov/zero-trust-maturity-model)

### Technology Documentation

- [Tailscale Documentation](https://tailscale.com/kb/)
- [Kubernetes NetworkPolicies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Teleport Documentation](https://goteleport.com/docs/)
- [Istio Service Mesh](https://istio.io/latest/docs/)
- [Linkerd Service Mesh](https://linkerd.io/2/overview/)

### Related Documentation

- [ADR-0009: Tailscale for Hybrid Cloud Networking](../decisions/0009-tailscale-hybrid-networking.md) - Layer 1: Network Access
- [ADR-0011: Kubernetes NetworkPolicies](../decisions/0011-kubernetes-network-policies.md) - Layer 2: Workload Segmentation
- [ADR-0012: Identity and Access Management](../decisions/0012-identity-access-management.md) - Layer 3: API Authorization
- [Research: Tailscale Evaluation](0017-tailscale-evaluation.md)
- [Research: Hybrid Cloud Networking](0007-hybrid-cloud-networking.md)
- [Spec: Tailscale Mesh Network](../../specs/network/tailscale-mesh-network.md)
