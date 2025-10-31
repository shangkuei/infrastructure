# Hybrid Load Balancing Technical Specification

**Status**: Approved
**Version**: 1.0
**Last Updated**: 2025-11-01
**Related ADR**: [ADR-0017: Hybrid Load Balancing with Cloudflare Tunnel and Ngrok](../../docs/decisions/0017-hybrid-load-balancing.md)

## Overview

This document provides the technical specification for implementing hybrid load balancing using Cloudflare Tunnel and Ngrok to expose on-premises Talos Kubernetes cluster services to the public internet.

## Architecture Summary

```
┌──────────────────────────────────────────────────────────────────┐
│                       Public Internet Users                       │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │
        ┌─────────────────────┴─────────────────────┐
        │                                             │
        │                                             │
┌───────▼──────────┐                     ┌───────────▼──────────┐
│ Cloudflare Edge  │                     │   Ngrok Cloud        │
│ (300+ PoPs)      │                     │   (Dev/Failover)     │
│ - DDoS Protection│                     │   - Traffic Inspect  │
│ - WAF            │                     │   - Webhook Testing  │
│ - Global CDN     │                     │   - Quick URLs       │
└────────┬─────────┘                     └──────────┬───────────┘
         │                                           │
         │ Encrypted Tunnel                          │ Encrypted Tunnel
         │ (Outbound Only)                           │ (Outbound Only)
         │                                           │
┌────────▼───────────────────────────────────────────▼───────────┐
│            On-Premises Network (192.168.1.0/24)                 │
│  ┌────────────────────────────────────────────────────────────┐│
│  │         Talos Kubernetes Cluster (Unraid VMs)              ││
│  │  ┌───────────────────────────────────────────────────────┐││
│  │  │ Cloudflared Pods (2 replicas)                         │││
│  │  │ + Ngrok Ingress Controller                             │││
│  │  └────────────────┬──────────────────────────────────────┘││
│  │                   │                                         ││
│  │  ┌────────────────▼──────────────┐                        ││
│  │  │  MetalLB                       │                        ││
│  │  │  IP Pool: 192.168.1.240-250   │                        ││
│  │  └────────────────┬───────────────┘                        ││
│  │                   │                                         ││
│  │  ┌────────────────▼──────────────┐                        ││
│  │  │  NGINX Ingress Controller      │                        ││
│  │  │  IP: 192.168.1.240             │                        ││
│  │  └────────────────┬───────────────┘                        ││
│  │                   │                                         ││
│  │  ┌────────────────▼──────────────────────────────────────┐││
│  │  │  Kubernetes Services                                   │││
│  │  │  ├─ Production Apps (via Cloudflare Tunnel)           │││
│  │  │  ├─ Dev/Test Apps (via Ngrok)                         │││
│  │  │  └─ Internal Apps (Tailscale only)                    │││
│  │  └───────────────────────────────────────────────────────┘││
│  └────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Component Specifications

### 1. Cloudflare Tunnel (Primary)

#### Deployment Specifications

**Container Image**: `cloudflare/cloudflared:latest`

**Resource Requirements** (per replica):

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

**Replica Configuration**:

- Minimum replicas: 2 (for HA)
- Maximum replicas: 4 (if using HPA)
- Deployment strategy: RollingUpdate
- Max unavailable: 1
- Max surge: 1

**Network Requirements**:

- Outbound HTTPS (443) to `*.cloudflare.com`
- No inbound ports required
- DNS resolution for `*.cloudflare.com`

#### Configuration Structure

**Tunnel Configuration** (`config.yaml`):

```yaml
tunnel: <TUNNEL_UUID>
credentials-file: /etc/cloudflared/credentials/credentials.json

# Origin certificate validation
originRequest:
  noTLSVerify: false  # Set to true for self-signed certs in dev
  connectTimeout: 30s
  tlsTimeout: 10s
  keepAliveTimeout: 90s

# Ingress rules (order matters - first match wins)
ingress:
  # Production app with custom origin config
  - hostname: app.example.com
    service: http://192.168.1.240:80
    originRequest:
      httpHostHeader: app.example.com
      connectTimeout: 10s

  # API endpoint with HTTPS backend
  - hostname: api.example.com
    service: https://192.168.1.240:443
    originRequest:
      originServerName: api.example.com

  # Wildcard staging environment
  - hostname: "*.staging.example.com"
    service: http://192.168.1.240:80
    originRequest:
      httpHostHeader: staging.example.com

  # Websocket support
  - hostname: ws.example.com
    service: http://192.168.1.240:80
    originRequest:
      httpHostHeader: ws.example.com
      disableChunkedEncoding: true

  # Catch-all 404
  - service: http_status:404
```

**Kubernetes Deployment**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflare-tunnel
  labels:
    app: cloudflared
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app: cloudflared
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "2000"
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
        - tunnel
        - --config
        - /etc/cloudflared/config/config.yaml
        - --metrics
        - 0.0.0.0:2000
        - run

        ports:
        - name: metrics
          containerPort: 2000
          protocol: TCP

        livenessProbe:
          httpGet:
            path: /ready
            port: 2000
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        readinessProbe:
          httpGet:
            path: /ready
            port: 2000
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 1

        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi

        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared/config
          readOnly: true
        - name: credentials
          mountPath: /etc/cloudflared/credentials
          readOnly: true

      volumes:
      - name: config
        configMap:
          name: cloudflared-config
      - name: credentials
        secret:
          secretName: cloudflared-credentials
```

#### DNS Configuration

**Cloudflare DNS Records** (created via `cloudflared tunnel route dns`):

```
Type  Name                      Content                           Proxied
─────────────────────────────────────────────────────────────────────────
CNAME app.example.com          <TUNNEL_ID>.cfargotunnel.com      Yes
CNAME api.example.com          <TUNNEL_ID>.cfargotunnel.com      Yes
CNAME *.staging.example.com    <TUNNEL_ID>.cfargotunnel.com      Yes
CNAME ws.example.com           <TUNNEL_ID>.cfargotunnel.com      Yes
```

#### Monitoring Metrics

**Exposed Metrics** (Prometheus format on port 2000):

- `cloudflared_tunnel_total_requests` - Total requests processed
- `cloudflared_tunnel_request_errors` - Request errors
- `cloudflared_tunnel_response_time_seconds` - Response time histogram
- `cloudflared_tunnel_concurrent_requests` - Current concurrent requests
- `cloudflared_tunnel_ha_connections` - HA connection count

### 2. Ngrok Kubernetes Ingress Controller (Secondary)

#### Deployment Specifications

**Helm Chart**: `ngrok/kubernetes-ingress-controller`
**Chart Version**: Latest stable

**Resource Requirements**:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Replica Configuration**:

- Replicas: 1 (Ngrok handles HA at cloud level)
- Deployment strategy: Recreate

#### Installation

**Helm Values** (`ngrok-values.yaml`):

```yaml
credentials:
  apiKey: <NGROK_API_KEY>
  authtoken: <NGROK_AUTHTOKEN>

controller:
  replicaCount: 1

  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Ingress class configuration
  ingressClass:
    name: ngrok
    default: false  # Don't make default, explicit opt-in

  # Metrics and monitoring
  metrics:
    enabled: true
    port: 8080

  # Logging
  log:
    level: info
    format: json

# Pod security context
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

# Service account
serviceAccount:
  create: true
  name: ngrok-ingress-controller
```

**Installation Command**:

```bash
helm install ngrok-ingress-controller ngrok/kubernetes-ingress-controller \
  --namespace ngrok-ingress \
  --create-namespace \
  --values ngrok-values.yaml
```

#### Usage Examples

**Basic Ingress** (Free tier - ephemeral URL):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dev-app
  namespace: development
spec:
  ingressClassName: ngrok
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dev-app
            port:
              number: 80
```

**Custom Domain** (Pro+ plan):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dev-app
  namespace: development
  annotations:
    k8s.ngrok.com/domain: dev-app.example.com
spec:
  ingressClassName: ngrok
  rules:
  - host: dev-app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dev-app
            port:
              number: 80
```

**With Authentication** (Basic Auth):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: protected-app
  namespace: development
  annotations:
    k8s.ngrok.com/domain: protected.example.com
    k8s.ngrok.com/basic-auth-secret: basic-auth-credentials
spec:
  ingressClassName: ngrok
  rules:
  - host: protected.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: protected-app
            port:
              number: 80
---
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth-credentials
  namespace: development
type: Opaque
stringData:
  username: admin
  password: secret123
```

### 3. MetalLB Configuration

#### IP Address Pool

**Configuration**:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250  # 11 IPs available
  autoAssign: true
  avoidBuggyIPs: false

---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
  interfaces:
  - eth0  # Adjust based on Talos network interface
```

#### IP Allocation Strategy

**Reserved IPs**:

- `192.168.1.240`: NGINX Ingress Controller (primary)
- `192.168.1.241`: Reserved for future ingress controller
- `192.168.1.242-250`: Available for LoadBalancer services

### 4. NGINX Ingress Controller

#### Installation

**Helm Chart**: `ingress-nginx/ingress-nginx`

**Values** (`nginx-ingress-values.yaml`):

```yaml
controller:
  # Service configuration
  service:
    type: LoadBalancer
    loadBalancerIP: 192.168.1.240  # Request specific IP from MetalLB
    annotations:
      metallb.universe.tf/allow-shared-ip: "ingress-nginx"

  # Resource requirements
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Replica configuration
  replicaCount: 2
  minAvailable: 1

  # Metrics
  metrics:
    enabled: true
    service:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "10254"

  # Configuration
  config:
    use-forwarded-headers: "true"
    compute-full-forwarded-for: "true"
    use-proxy-protocol: "false"

    # Performance tuning
    worker-processes: "2"
    worker-connections: "10240"
    keepalive-requests: "100"
    upstream-keepalive-connections: "50"

    # Logging
    log-format-escape-json: "true"
    log-format-upstream: '{"time": "$time_iso8601", "remote_addr": "$remote_addr",
      "request": "$request", "status": $status, "body_bytes_sent": $body_bytes_sent,
      "request_time": $request_time, "upstream_addr": "$upstream_addr",
      "upstream_response_time": "$upstream_response_time"}'

  # Ingress class
  ingressClass: nginx
  ingressClassResource:
    name: nginx
    enabled: true
    default: true  # Default ingress class
    controllerValue: k8s.io/ingress-nginx
```

## Service Routing Matrix

### Routing Decision Flow

```
┌─────────────────────────────────────────────────────────────┐
│ New Service Deployment                                       │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
        ┌────────────────────┐
        │ Public or Private? │
        └────────┬───────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
   ┌─────────┐      ┌──────────┐
   │ Public  │      │ Private  │
   └────┬────┘      └─────┬────┘
        │                 │
        ▼                 ▼
   ┌───────────────┐  ┌────────────────┐
   │ Production or │  │ Tailscale Only │
   │ Development?  │  │ (ClusterIP or  │
   └───────┬───────┘  │  NodePort)     │
           │          └────────────────┘
      ┌────┴─────┐
      │          │
      ▼          ▼
 ┌──────────┐ ┌─────────────┐
 │Production│ │ Development │
 └────┬─────┘ └──────┬──────┘
      │              │
      ▼              ▼
 ┌──────────────┐ ┌──────────────┐
 │ Cloudflare   │ │    Ngrok     │
 │ Tunnel       │ │   Ingress    │
 │ + NGINX      │ │  Controller  │
 │ Ingress      │ │              │
 └──────────────┘ └──────────────┘
```

### Service Classification Table

| Service Type | Access Pattern | Ingress Class | Tunnel/Route | Example |
|--------------|----------------|---------------|--------------|---------|
| Production Web App | Public | `nginx` (default) | Cloudflare Tunnel → NGINX | `app.example.com` |
| Production API | Public | `nginx` (default) | Cloudflare Tunnel → NGINX | `api.example.com` |
| Staging Environment | Public | `nginx` (default) | Cloudflare Tunnel → NGINX | `*.staging.example.com` |
| Development App | Public (temporary) | `ngrok` | Ngrok Tunnel | `dev-app.ngrok.app` |
| Webhook Testing | Public (temporary) | `ngrok` | Ngrok Tunnel | `webhook-test.ngrok.app` |
| Admin Dashboard | Private | N/A (NodePort) | Tailscale only | `admin.internal` |
| Monitoring (Grafana) | Private | N/A (NodePort) | Tailscale only | `grafana.internal` |
| Database UI | Private | N/A (ClusterIP) | kubectl port-forward | N/A |

### Example Service Definitions

**Production Service** (Cloudflare Tunnel):

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: production-app
  namespace: production
spec:
  selector:
    app: production-app
  ports:
  - port: 80
    targetPort: 8080
    name: http
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-app
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx  # Routes through NGINX, exposed via Cloudflare Tunnel
  tls:
  - hosts:
    - app.example.com
    secretName: app-example-com-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: production-app
            port:
              name: http
```

**Development Service** (Ngrok):

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: dev-app
  namespace: development
spec:
  selector:
    app: dev-app
  ports:
  - port: 80
    targetPort: 3000
    name: http
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dev-app
  namespace: development
spec:
  ingressClassName: ngrok  # Routes through Ngrok
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dev-app
            port:
              name: http
```

**Internal Service** (Tailscale):

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: NodePort  # Accessible via Tailscale to node IP
  selector:
    app: grafana
  ports:
  - port: 80
    targetPort: 3000
    nodePort: 30080  # Access via <node-tailscale-ip>:30080
    name: http
```

## Network Flow Details

### Request Flow: Cloudflare Tunnel (Production)

```
Internet User
    ↓
    1. DNS Resolution (app.example.com → Cloudflare IP via CNAME)
    ↓
Cloudflare Edge (nearest PoP)
    ↓
    2. DDoS protection, WAF checks, caching
    ↓
Cloudflare Tunnel Service
    ↓
    3. Encrypted tunnel to on-prem (QUIC/HTTP2)
    ↓
Cloudflared Pod (in cluster)
    ↓
    4. Decrypt, forward to http://192.168.1.240:80
    ↓
NGINX Ingress Controller (192.168.1.240)
    ↓
    5. Route based on Host header (app.example.com)
    ↓
    6. Forward to backend Service
    ↓
Backend Pod (production-app)
    ↓
    7. Process request, return response
    ↓
    (Reverse flow back to user)
```

### Request Flow: Ngrok (Development)

```
Internet User
    ↓
    1. DNS Resolution (dev-app.ngrok.app → Ngrok IP)
    ↓
Ngrok Edge (nearest PoP)
    ↓
    2. Encrypted tunnel to on-prem
    ↓
Ngrok Ingress Controller Pod
    ↓
    3. Route based on Ingress rules
    ↓
    4. Forward directly to backend Service
    ↓
Backend Pod (dev-app)
    ↓
    5. Process request, return response
    ↓
    (Reverse flow back to user)
```

### Request Flow: Tailscale (Internal)

```
Authorized User (on Tailscale network)
    ↓
    1. Tailscale mesh network connection
    ↓
    2. Direct encrypted connection to node Tailscale IP
    ↓
Kubernetes Node (NodePort service)
    ↓
    3. Route to service via kube-proxy
    ↓
Backend Pod (grafana)
    ↓
    4. Process request, return response
    ↓
    (Reverse flow back to user)
```

## Performance Specifications

### Latency Targets

| Metric | Target | Measurement Point |
|--------|--------|-------------------|
| Cloudflare Edge to User | <50ms | P95 global |
| Tunnel Overhead | <30ms | P95 from edge to origin |
| NGINX Processing | <10ms | P95 at ingress |
| End-to-End (Production) | <500ms | P95 including application |
| Ngrok Tunnel Overhead | <50ms | P95 from edge to origin |

### Throughput Targets

| Component | Target Throughput | Bottleneck |
|-----------|------------------|------------|
| Cloudflare Tunnel | Unlimited (Cloudflare side) | ISP upload bandwidth |
| NGINX Ingress | 1000 req/sec | CPU and memory limits |
| MetalLB | 1 Gbps | Local network speed |
| Residential ISP Upload | ~20-100 Mbps | ISP plan |

### Availability Targets

| Component | Target Availability | SLA |
|-----------|---------------------|-----|
| Cloudflare Tunnel | 99.99% | Cloudflare SLA (Enterprise) |
| Ngrok | 99.9% | Ngrok Pro SLA |
| On-Prem Cluster | 95% | Best effort (single host) |
| End-to-End (Production) | 99% | Limited by on-prem availability |

## Security Specifications

### TLS/SSL Configuration

**Cloudflare Tunnel SSL Mode**: Full (Strict)

- Cloudflare → User: Cloudflare certificate
- Cloudflare → Origin: Validate origin certificate
- Origin certificate: Let's Encrypt via cert-manager

**Certificate Management**:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

### Access Control

**Cloudflare Access** (Optional):

- Zero Trust access policies
- SSO integration
- Device posture checks

**Ngrok Authentication**:

- Basic Auth (via annotations)
- OAuth (Pro+ plan)
- IP restrictions (Pro+ plan)

**Kubernetes RBAC**:

- Least privilege service accounts
- Namespace isolation
- Network policies

### Firewall Rules

**Required Outbound** (from cluster):

- Port 443 to `*.cloudflare.com` (Cloudflare Tunnel)
- Port 443 to `*.ngrok.com` (Ngrok)
- Port 443 to `acme-v02.api.letsencrypt.org` (cert-manager)

**No Inbound Required**: All connections are outbound-initiated tunnels

## Monitoring and Alerting

### Key Metrics to Monitor

**Cloudflare Tunnel**:

- `cloudflared_tunnel_total_requests`
- `cloudflared_tunnel_request_errors`
- `cloudflared_tunnel_response_time_seconds`
- `cloudflared_tunnel_concurrent_requests`

**Ngrok**:

- Ingress controller pod status
- Tunnel connection status
- Request rate and error rate (from Ngrok dashboard)

**NGINX Ingress**:

- `nginx_ingress_controller_requests`
- `nginx_ingress_controller_request_duration_seconds`
- `nginx_ingress_controller_response_size`
- `nginx_ingress_controller_ssl_expire_time_seconds`

### Prometheus ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cloudflared
  namespace: cloudflare-tunnel
spec:
  selector:
    matchLabels:
      app: cloudflared
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nginx-ingress
  namespace: ingress-nginx
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Alert Rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: load-balancer-alerts
  namespace: monitoring
spec:
  groups:
  - name: load-balancer
    interval: 30s
    rules:
    # Cloudflare Tunnel down
    - alert: CloudflareTunnelDown
      expr: up{job="cloudflared"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Cloudflare Tunnel is down"
        description: "No cloudflared pods are running"

    # High error rate
    - alert: HighErrorRate
      expr: rate(nginx_ingress_controller_requests{status=~"5.."}[5m]) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate detected"
        description: "5xx error rate is above 5%"

    # Certificate expiring soon
    - alert: CertificateExpiringSoon
      expr: (nginx_ingress_controller_ssl_expire_time_seconds - time()) < 604800
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "SSL certificate expiring soon"
        description: "Certificate expires in less than 7 days"
```

## Cost Summary

### Monthly Operating Costs

| Component | Plan | Cost/Month | Annual Cost |
|-----------|------|------------|-------------|
| **Cloudflare Tunnel** | Free | $0 | $0 |
| **Ngrok** | Free (Dev Only) | $0 | $0 |
| **Ngrok** | Personal | $8 | $96 |
| **Ngrok** | Pro (Recommended) | $20 | $228 |
| **MetalLB** | Open Source | $0 | $0 |
| **NGINX Ingress** | Open Source | $0 | $0 |
| **Electricity** | - | ~$5-10 | ~$60-120 |

**Recommended Setup**:

- **Phase 1** (Development): $0/month (Cloudflare + Ngrok free)
- **Phase 2** (Small Production): $8/month (+ Ngrok Personal)
- **Phase 3** (Production HA): $20/month (+ Ngrok Pro for failover)

## Operational Procedures

### Deployment Checklist

- [ ] Cloudflare Tunnel created and configured
- [ ] Tunnel credentials stored as Kubernetes Secret
- [ ] Cloudflared deployment created with 2+ replicas
- [ ] DNS records configured (CNAME to tunnel)
- [ ] Ngrok account created, API key obtained
- [ ] Ngrok Ingress Controller installed via Helm
- [ ] MetalLB installed and IP pool configured
- [ ] NGINX Ingress Controller installed with LoadBalancer service
- [ ] NGINX assigned IP from MetalLB (192.168.1.240)
- [ ] cert-manager installed for TLS certificates
- [ ] Prometheus ServiceMonitors created
- [ ] Alert rules configured
- [ ] Test ingress resources created and verified
- [ ] External monitoring configured (UptimeRobot, etc.)
- [ ] Documentation updated with actual IPs and URLs

### Testing Procedures

**Test Cloudflare Tunnel**:

```bash
# 1. Check tunnel status
kubectl get pods -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=50

# 2. Test external access
curl -I https://app.example.com

# 3. Check metrics
kubectl port-forward -n cloudflare-tunnel deploy/cloudflared 2000:2000
curl http://localhost:2000/metrics
```

**Test Ngrok Ingress**:

```bash
# 1. Check controller status
kubectl get pods -n ngrok-ingress
kubectl logs -n ngrok-ingress -l app=ngrok-ingress-controller

# 2. Create test ingress
kubectl apply -f test-ingress.yaml

# 3. Get Ngrok URL
kubectl get ingress test-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# 4. Test access
curl https://<ngrok-url>
```

**Test MetalLB + NGINX**:

```bash
# 1. Check MetalLB
kubectl get pods -n metallb-system

# 2. Check NGINX service
kubectl get svc -n ingress-nginx

# Should show EXTERNAL-IP: 192.168.1.240

# 3. Test direct access (from within network)
curl http://192.168.1.240
```

### Troubleshooting Guide

See [Runbook: Load Balancer Operations](../../docs/runbooks/0006-load-balancer-operations.md) for detailed troubleshooting procedures.

## References

- [ADR-0017: Hybrid Load Balancing](../../docs/decisions/0017-hybrid-load-balancing.md)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Ngrok Kubernetes Ingress Controller](https://ngrok.com/docs/k8s/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [NGINX Ingress Controller Documentation](https://kubernetes.github.io/ingress-nginx/)
