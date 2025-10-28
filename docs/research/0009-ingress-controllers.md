# Research: Ingress Controller Options

Date: 2025-10-18
Author: Infrastructure Team
Status: Completed

## Objective

Evaluate Kubernetes ingress controllers for HTTP/HTTPS traffic management.

## Findings

| Controller | Complexity | Features | Performance | Best For |
|------------|------------|----------|-------------|----------|
| **Nginx** | Low | Good | Excellent | General purpose |
| **Traefik** | Low | Good | Good | Small clusters |
| **Istio Gateway** | High | Excellent | Good | Service mesh users |
| **Contour** | Medium | Good | Excellent | Advanced routing |
| **Cilium Gateway API** | Medium | Excellent | Very Good | eBPF-native, Gateway API |

## Detailed Analysis

### Cilium Gateway API

**Architecture**: eBPF-based ingress using Kubernetes Gateway API standard with per-node Envoy proxy

**Key Features**:

- **Gateway API Native**: Full conformance with Gateway API v1.2+
- **eBPF Integration**: Leverages eBPF for efficient packet processing
- **TLS Termination**: Native support with cert-manager integration
- **Traffic Management**: Traffic splitting, header manipulation, redirects
- **L7 Load Balancing**: Per-request gRPC balancing
- **Multi-tenancy**: Namespace isolation and RBAC integration

**Strengths**:

- ✅ Modern Gateway API standard (successor to Ingress)
- ✅ Consolidated networking (CNI + ingress + service mesh)
- ✅ Eliminates kube-proxy and iptables overhead
- ✅ Native TLS with cert-manager support
- ✅ Production-ready with conformance testing
- ✅ No sidecars required for L7 routing

**Weaknesses**:

- ❌ Requires Cilium as CNI (not standalone)
- ❌ Gateway API less mature than Ingress API
- ❌ Smaller community vs Nginx
- ❌ More complex troubleshooting (eBPF + Envoy)
- ❌ Migration effort from existing Ingress resources

**Best Use Cases**:

- New clusters adopting Gateway API standard
- Organizations using Cilium as CNI
- Consolidating networking stack (CNI + ingress)
- Multi-tenant environments requiring namespace isolation
- Modern cloud-native architectures

**When to Avoid**:

- Already invested in Ingress API resources
- Using different CNI (Calico, Flannel)
- Team unfamiliar with Gateway API or eBPF
- Need maximum community support and examples

## Recommendations

### Primary Recommendation: Nginx Ingress Controller

**For most use cases**:

- Industry standard
- Excellent performance
- Large community
- Simple configuration
- Good documentation

### Alternative: Cilium Gateway API

**If using Cilium CNI**:

- Consolidate networking components
- Adopt modern Gateway API standard
- Benefit from eBPF performance
- Simplify architecture

## Decision Matrix

| Requirement | Recommended Controller |
|-------------|------------------------|
| General purpose | **Nginx** |
| Simplicity | **Nginx** or **Traefik** |
| Service mesh integration | **Istio Gateway** |
| Advanced L7 routing | **Contour** |
| Gateway API adoption | **Cilium Gateway API** |
| eBPF-based networking | **Cilium Gateway API** |
| Consolidated stack | **Cilium Gateway API** |

## Example: Nginx Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app
            port:
              number: 80
```

## Example: Cilium Gateway API

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: app-gateway
  namespace: default
spec:
  gatewayClassName: cilium
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "app.example.com"
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  namespace: default
spec:
  parentRefs:
  - name: app-gateway
  hostnames:
  - "app.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: app
      port: 80
```

## References

- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Cilium Gateway API Documentation](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Cilium Gateway API Deep Dive (Isovalent)](https://isovalent.com/blog/post/cilium-gateway-api/)
