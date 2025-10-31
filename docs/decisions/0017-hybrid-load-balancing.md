# 17. Hybrid Load Balancing with Cloudflare Tunnel and Ngrok

Date: 2025-11-01

## Status

Accepted

**Related**:

- [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](0016-talos-unraid-primary.md)
- [ADR-0009: Tailscale for Hybrid Cloud Networking](0009-tailscale-hybrid-networking.md)
- [ADR-0004: Cloudflare for DNS Services](0004-cloudflare-dns-services.md)

## Context

With the Talos Kubernetes cluster running on-premises on SBC (Single Board Computer) hardware via Unraid VMs, we need
a strategy to expose services to the public internet. The cluster is behind a residential internet connection without
static IP addresses or the ability to easily configure port forwarding at scale.

### Requirements

**Production Public Services**:

- Reliable public access to production applications
- Custom domain support
- HTTPS/TLS termination
- DDoS protection
- High availability and uptime
- Zero or minimal cost for small-scale deployments

**Development and Testing**:

- Quick public URL generation for testing
- Webhook endpoint exposure for development
- Easy Kubernetes integration
- Traffic inspection and debugging capabilities
- Ephemeral URLs for temporary testing

**Operational Requirements**:

- Kubernetes-native integration (Ingress resources)
- Minimal infrastructure overhead
- Simple operational model
- No complex VPN or cloud VM management for basic use cases
- Automatic failover and redundancy

### On-Premises Infrastructure

**Current Setup**:

- Talos Kubernetes cluster on Unraid VMs (2+ nodes)
- MetalLB for internal LoadBalancer services
- NGINX Ingress Controller for HTTP/HTTPS routing
- Tailscale for private network access
- Residential internet connection (dynamic IP)

### Load Balancer Options Evaluated

**Cloud Provider Load Balancers**:

- AWS ALB/NLB: $22-40/month + data transfer
- GCP Load Balancer: $25-40/month
- Azure Standard LB: $25-35/month
- DigitalOcean LB: $12/month flat rate
- Oracle Cloud LB: $10-25/month (free tier available)

**Issue**: All require cloud VMs or managed Kubernetes, adding complexity and cost for an on-premises cluster.

**Tunneling Solutions**:

- **Cloudflare Tunnel**: FREE, production-grade, DDoS protection, global CDN
- **Ngrok**: $8-20/month for personal/pro plans, excellent developer experience
- **Tailscale + Cloud LB**: $0-24/month, requires cloud VM management

**Traditional Approaches**:

- Port forwarding: Not scalable, security concerns, residential ISP restrictions
- Dynamic DNS + Direct Exposure: Security risks, no DDoS protection
- VPS + VPN: Requires VPS management, additional complexity

## Decision

We will implement a **hybrid load balancing strategy** using:

1. **Cloudflare Tunnel** (Primary) - For production public-facing services
2. **Ngrok** (Secondary) - For development, testing, and failover

This approach provides:

- **Cost Efficiency**: Cloudflare Tunnel is free, Ngrok starts at $8/month
- **High Availability**: Primary/secondary failover capability
- **Flexibility**: Best tool for each use case
- **Simplicity**: No cloud VMs or complex networking to manage

## Architecture

### Overall Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      Public Internet                             │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ├──────────────────┬──────────────────┐
                          │                  │                  │
                    Cloudflare         Ngrok Cloud        Tailscale
                    Global CDN         (Development)      (Private)
                          │                  │                  │
                          │                  │                  │
                 Cloudflare Tunnel    Ngrok Ingress    Tailscale VPN
                    (cloudflared)      Controller         Mesh
                          │                  │                  │
                          └──────────────────┴──────────────────┘
                                            │
                                            │
┌───────────────────────────────────────────────────────────────────┐
│                    On-Premises Network                             │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │              Talos Kubernetes Cluster                        │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │  MetalLB (192.168.1.240-250)                           │ │  │
│  │  │              │                                          │ │  │
│  │  │  ┌───────────▼───────────┐                            │ │  │
│  │  │  │  NGINX Ingress         │                            │ │  │
│  │  │  │  Controller            │                            │ │  │
│  │  │  │  (192.168.1.240)       │                            │ │  │
│  │  │  └───────────┬────────────┘                            │ │  │
│  │  │              │                                          │ │  │
│  │  │  ┌───────────▼───────────────────────────────────┐    │ │  │
│  │  │  │  Kubernetes Services                          │    │ │  │
│  │  │  │  ├── Production Apps (Cloudflare Tunnel)      │    │ │  │
│  │  │  │  ├── Dev/Test Apps (Ngrok)                    │    │ │  │
│  │  │  │  └── Internal Apps (Tailscale only)           │    │ │  │
│  │  │  └───────────────────────────────────────────────┘    │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  └─────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

### Component Details

#### 1. Cloudflare Tunnel (Primary - Production)

**Purpose**: Production-grade public access with zero cost

**Deployment**:

- Cloudflared daemon runs as Kubernetes DaemonSet or standalone on cluster network
- Establishes outbound-only encrypted tunnels to Cloudflare edge
- Routes traffic from Cloudflare domains to internal MetalLB IPs
- No inbound firewall rules or port forwarding required

**Use Cases**:

- Production web applications
- Public APIs
- Customer-facing services
- Marketing and content websites
- Any service requiring high uptime and reliability

**Configuration Example**:

```yaml
# Cloudflared ConfigMap
tunnel: <tunnel-id>
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: app.example.com
    service: http://192.168.1.240:80
  - hostname: api.example.com
    service: http://192.168.1.240:443
  - hostname: "*.staging.example.com"
    service: http://192.168.1.240:80
  - service: http_status:404
```

**Features**:

- Free unlimited bandwidth
- Built-in DDoS protection
- Global CDN with 300+ PoPs
- Automatic HTTPS with Cloudflare certificates
- WAF (Web Application Firewall) available
- Access control and authentication policies
- Health checks and automatic failover

#### 2. Ngrok Kubernetes Ingress Controller (Secondary - Development)

**Purpose**: Development, testing, and failover capability

**Deployment**:

- Native Kubernetes Ingress Controller
- Automatically provisions ngrok tunnels for Ingress resources
- Manages tunnel lifecycle within Kubernetes
- Standard Kubernetes Ingress API

**Use Cases**:

- Development and testing environments
- Webhook endpoints (GitHub, Stripe, etc.)
- Demo environments and POCs
- Quick public URL generation
- Traffic inspection and debugging
- Failover when Cloudflare Tunnel unavailable

**Configuration Example**:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dev-app
  annotations:
    k8s.ngrok.com/domain: dev-app.ngrok.app
spec:
  ingressClassName: ngrok
  rules:
  - host: dev-app.ngrok.app
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

**Features**:

- Native Kubernetes integration
- Traffic inspection UI
- Webhook replay capability
- Custom domains (Pro+ plan)
- Authentication and authorization
- API access for automation
- Kubernetes-native status reporting

#### 3. MetalLB (Internal Load Balancer)

**Purpose**: Provide LoadBalancer IPs within cluster network

**Configuration**:

- IP address pool: 192.168.1.240-250
- L2 mode for simple home network integration
- Assigns IPs to LoadBalancer-type Services
- NGINX Ingress Controller gets IP from this pool

#### 4. Tailscale (Private Access)

**Purpose**: Secure private access for administration and internal tools

**Use Cases**:

- Kubernetes Dashboard access
- Prometheus/Grafana monitoring
- Admin panels and internal tools
- Direct kubectl access
- CI/CD runner connectivity

**Integration**: Already configured per [ADR-0009](0009-tailscale-hybrid-networking.md)

## Routing Strategy

### Service Classification

**Production Public Services** → Cloudflare Tunnel:

```yaml
# Standard Ingress with hostname annotation
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-app
  annotations:
    # Cloudflare-managed via cloudflared config
spec:
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
              number: 80
```

**Development/Testing Services** → Ngrok:

```yaml
# Ngrok Ingress with ingressClassName
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dev-app
spec:
  ingressClassName: ngrok  # Routes to Ngrok
  rules:
  - host: dev-app.ngrok.app
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

**Internal Private Services** → Tailscale Only:

```yaml
# No Ingress - access via Tailscale
# Direct service access via Tailscale IPs
apiVersion: v1
kind: Service
metadata:
  name: internal-dashboard
spec:
  type: ClusterIP  # or NodePort for Tailscale access
  ports:
  - port: 80
```

## Failover and High Availability

### Cloudflare Tunnel HA

**Multi-Replica Deployment**:

```yaml
# Deploy cloudflared with multiple replicas
# Cloudflare automatically load balances across tunnels
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
spec:
  replicas: 2  # Run 2+ replicas for HA
  selector:
    matchLabels:
      app: cloudflared
  template:
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
        - tunnel
        - run
```

**Automatic Failover**:

- Cloudflare automatically fails over between tunnel replicas
- No manual intervention required
- Health checks ensure traffic only goes to healthy tunnels
- Sub-second failover time

### Ngrok as Backup

**Scenario**: Cloudflare Tunnel outage or maintenance

**Action**:

1. Update DNS to point to Ngrok tunnel URL
2. Or configure Ngrok with custom domain (Pro+ plan)
3. Ngrok Ingress Controller handles routing

**Recovery Time**: 2-5 minutes (DNS propagation)

### Monitoring and Alerting

**Health Checks**:

```yaml
# Monitor both Cloudflare Tunnel and Ngrok availability
# Alert if either becomes unavailable
# Automated DNS failover (optional)
```

## Cost Analysis

### Monthly Costs

| Component | Plan | Monthly Cost | Annual Cost | Notes |
|-----------|------|--------------|-------------|-------|
| **Cloudflare Tunnel** | Free | **$0** | **$0** | Unlimited bandwidth, tunnels |
| **Ngrok** | Free | $0 | $0 | Development only, ephemeral URLs |
| **Ngrok** | Personal | $8 | $96 | 3 custom domains, persistent URLs |
| **Ngrok** | Pro | $20 | $228 | 10 agents, 5 domains, recommended for production failover |
| **MetalLB** | - | $0 | $0 | Open source |
| **Electricity** | - | ~$5-10 | ~$60-120 | Estimated for always-on cluster |

### Recommended Configuration

**Phase 1: Development and Testing** (Now):

- Cloudflare Tunnel: FREE
- Ngrok Free: FREE
- **Total: $0/month**

**Phase 2: Small Production** (Later):

- Cloudflare Tunnel: FREE (primary)
- Ngrok Personal: $8/month (development + backup)
- **Total: $8/month**

**Phase 3: Production with HA** (Future):

- Cloudflare Tunnel: FREE (primary with multi-replica)
- Ngrok Pro: $20/month (development + production failover)
- **Total: $20/month**

### Cost Comparison vs Alternatives

| Solution | Monthly Cost | HA | DDoS Protection | Developer Tools |
|----------|--------------|-----|-----------------|-----------------|
| **Our Hybrid** | $0-20 | ✅ | ✅ (Cloudflare) | ✅ (Ngrok) |
| Cloud LB + VMs | $25-50 | ✅ | Partial | ❌ |
| DigitalOcean LB | $12-24 | ✅ | Partial | ❌ |
| Oracle Cloud | $0-15 | ✅ | Partial | ❌ |
| VPS + HAProxy | $6-20 | ⚠️ | ❌ | ❌ |

## Implementation

### Phase 1: Cloudflare Tunnel Setup (Week 1)

**Prerequisites**:

- Cloudflare account
- Domain configured in Cloudflare
- Talos cluster running
- MetalLB and NGINX Ingress deployed

**Steps**:

1. **Create Cloudflare Tunnel**:

```bash
# Install cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/

# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create talos-home

# Note the Tunnel ID and credentials file location
```

2. **Configure Tunnel**:

```bash
# Create configuration file
cat > ~/.cloudflared/config.yml <<EOF
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  # Production apps
  - hostname: app.example.com
    service: http://192.168.1.240:80

  # API endpoints
  - hostname: api.example.com
    service: http://192.168.1.240:443

  # Wildcard for staging
  - hostname: "*.staging.example.com"
    service: http://192.168.1.240:80

  # Catch-all
  - service: http_status:404
EOF
```

3. **Deploy to Kubernetes**:

```bash
# Create namespace
kubectl create namespace cloudflare-tunnel

# Create secret with credentials
kubectl create secret generic tunnel-credentials \
  --from-file=credentials.json=/root/.cloudflared/<TUNNEL_ID>.json \
  -n cloudflare-tunnel

# Create ConfigMap with config
kubectl create configmap tunnel-config \
  --from-file=config.yaml=~/.cloudflared/config.yml \
  -n cloudflare-tunnel

# Deploy cloudflared
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflare-tunnel
spec:
  replicas: 2  # For HA
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
        - tunnel
        - --config
        - /etc/cloudflared/config.yaml
        - run
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared
          readOnly: true
        - name: credentials
          mountPath: /etc/cloudflared/credentials
          readOnly: true
        livenessProbe:
          httpGet:
            path: /ready
            port: 2000
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: config
        configMap:
          name: tunnel-config
      - name: credentials
        secret:
          secretName: tunnel-credentials
EOF
```

4. **Configure DNS**:

```bash
# Route DNS to tunnel (one-time setup)
cloudflared tunnel route dns talos-home app.example.com
cloudflared tunnel route dns talos-home api.example.com
cloudflared tunnel route dns talos-home "*.staging.example.com"
```

5. **Test Access**:

```bash
# Test external access
curl https://app.example.com
```

### Phase 2: Ngrok Integration (Week 1)

**Prerequisites**:

- Ngrok account (free or paid)
- API key and auth token from ngrok dashboard

**Steps**:

1. **Install Ngrok Ingress Controller**:

```bash
# Add Helm repo
helm repo add ngrok https://ngrok.github.io/kubernetes-ingress-controller
helm repo update

# Install controller
helm install ngrok-ingress-controller ngrok/kubernetes-ingress-controller \
  --namespace ngrok-ingress \
  --create-namespace \
  --set credentials.apiKey=<NGROK_API_KEY> \
  --set credentials.authtoken=<NGROK_AUTHTOKEN>
```

2. **Verify Installation**:

```bash
# Check pods
kubectl get pods -n ngrok-ingress

# Check ingress class
kubectl get ingressclass
# Should show 'ngrok' ingress class
```

3. **Create Test Ingress**:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: test-app
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app
spec:
  ingressClassName: ngrok
  rules:
  - host: test-app.ngrok.app
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-app
            port:
              number: 80
EOF
```

4. **Get Ngrok URL**:

```bash
# Check ingress status
kubectl get ingress test-app

# Should show ngrok.app URL in ADDRESS column
```

5. **Test Access**:

```bash
# Test external access (may take 30-60 seconds)
curl https://test-app.ngrok.app
```

### Phase 3: Routing Configuration (Week 2)

**Establish Routing Policies**:

1. **Create Ingress for Production Apps** (Cloudflare):

```yaml
# Goes through default ingress class (NGINX)
# Cloudflare Tunnel routes to NGINX via config
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-app
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
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
              number: 80
```

2. **Create Ingress for Dev Apps** (Ngrok):

```yaml
# Uses ngrok ingress class
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dev-app
  namespace: development
spec:
  ingressClassName: ngrok
  rules:
  - host: dev-app.ngrok.app
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

3. **Document Service Classification**:

```markdown
# Service Routing Matrix

| Service Type | Ingress Class | Access Method | Use Case |
|--------------|---------------|---------------|----------|
| Production | default (NGINX) | Cloudflare Tunnel | Public production apps |
| Staging | default (NGINX) | Cloudflare Tunnel | Pre-production testing |
| Development | ngrok | Ngrok Tunnel | Development and testing |
| Internal | - | Tailscale | Admin and monitoring |
```

## Consequences

### Positive

**Cost Efficiency**:

- **$0-20/month** total vs $25-50+ for cloud load balancers
- No cloud VM management overhead
- Pay only for what you need (scale cost with usage)

**High Availability**:

- Cloudflare Tunnel: 99.99% uptime SLA (enterprise-grade)
- Multi-replica deployment for redundancy
- Automatic failover within seconds
- Ngrok as secondary failover path

**Performance**:

- Cloudflare's global CDN (300+ edge locations)
- Reduced latency for global users
- Built-in caching and optimization
- DDoS protection included

**Security**:

- No inbound firewall rules needed
- No port forwarding required
- Outbound-only connections (more secure)
- DDoS protection with Cloudflare
- WAF capabilities available
- mTLS between tunnel and origin

**Developer Experience**:

- Ngrok's traffic inspection UI
- Webhook testing and replay
- Quick ephemeral URL generation
- Native Kubernetes integration
- Standard Ingress API

**Operational Simplicity**:

- No cloud VMs to manage
- No complex VPN configurations
- Kubernetes-native management
- Infrastructure as code (Kubernetes manifests)
- Automated tunnel management

**Flexibility**:

- Easy to add new services
- Quick to provision new environments
- Can still use Tailscale for private access
- Option to migrate to cloud LB later if needed

### Negative

**Vendor Lock-in**:

- Dependent on Cloudflare and Ngrok service availability
- Migration to different solution requires reconfiguration
- Custom domain configuration tied to Cloudflare DNS

**Limited Control**:

- Cannot customize load balancing algorithms
- Limited visibility into Cloudflare/Ngrok infrastructure
- Less control over routing decisions
- Dependent on third-party service policies

**Ngrok Limitations**:

- Free tier has rate limits (40-60 connections/minute)
- Ephemeral URLs on free tier (not production-suitable)
- Custom domains require paid plan ($8+/month)
- Connection limits on lower tiers

**Performance Considerations**:

- Additional hop through tunnel adds latency (~10-50ms)
- Upload bandwidth limited by residential ISP
- Cannot optimize routing like cloud multi-region
- Residential internet SLA limitations

**Cloudflare Tunnel Specifics**:

- Requires Cloudflare-managed DNS
- Configuration changes require tunnel restart
- Hostname routing configured outside Kubernetes
- Less dynamic than Kubernetes Ingress

**Monitoring Complexity**:

- Need to monitor multiple systems (Cloudflare, Ngrok, cluster)
- Troubleshooting spans multiple vendors
- Less integrated observability

### Mitigation Strategies

**For Vendor Lock-in**:

- Use standard Kubernetes Ingress API where possible
- Document architecture for easier migration
- Keep hybrid approach (multiple ingress options)
- Consider multi-cloud strategy for critical workloads

**For Limited Control**:

- Monitor performance metrics closely
- Document acceptable performance thresholds
- Have migration plan to cloud LB if requirements change
- Use Tailscale for direct access when needed

**For Rate Limits**:

- Start with Ngrok Pro plan ($20/month) for production failover
- Monitor connection rates and upgrade if needed
- Use Cloudflare Tunnel as primary (no rate limits)

**For Performance**:

- Monitor latency and throughput metrics
- Set up performance budgets and alerts
- Consider CDN caching for static content
- Plan migration to cloud for high-traffic services

**For Operational Complexity**:

- Implement comprehensive monitoring
- Create detailed runbooks
- Automate common operations
- Regular failover testing

## Monitoring and Operations

### Health Checks

**Cloudflare Tunnel**:

```bash
# Check tunnel status
kubectl get pods -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel -l app=cloudflared

# Cloudflare Dashboard
# Monitor tunnel metrics in Zero Trust dashboard
```

**Ngrok**:

```bash
# Check ingress controller
kubectl get pods -n ngrok-ingress
kubectl logs -n ngrok-ingress -l app=ngrok-ingress-controller

# Check ingress status
kubectl get ingress -A
```

**Service Availability**:

```bash
# External monitoring
# Use uptime monitoring service (UptimeRobot, Better Uptime, etc.)
# Monitor both Cloudflare and Ngrok URLs
```

### Key Metrics

**Cloudflare Tunnel**:

- Tunnel connection status (up/down)
- Request rate and error rate
- Response time (p50, p95, p99)
- Bandwidth usage

**Ngrok**:

- Tunnel status
- Connection count
- Rate limit usage
- Response time

**Cluster**:

- NGINX Ingress Controller metrics
- Pod health and availability
- Network connectivity

### Alerting

**Critical Alerts**:

- Both Cloudflare and Ngrok tunnels down
- Ingress controller unhealthy
- Certificate expiration warnings
- High error rates (>5%)

**Warning Alerts**:

- Single tunnel down (still have redundancy)
- Approaching rate limits
- High latency (>500ms)
- Bandwidth throttling detected

### Runbook References

Create separate detailed runbooks:

- [Cloudflare Tunnel Operations](../runbooks/0004-cloudflare-tunnel-operations.md) (to be created)
- [Ngrok Operations](../runbooks/0005-ngrok-operations.md) (to be created)
- [Load Balancer Failover](../runbooks/0006-load-balancer-failover.md) (to be created)

## Migration and Future Considerations

### When to Reconsider This Approach

**Scale Indicators**:

- Traffic exceeds 10TB/month
- More than 100 req/sec sustained
- Need for advanced load balancing (geo-routing, weighted routing)
- Multiple geographic regions required
- Residential ISP bandwidth becomes bottleneck

**Reliability Indicators**:

- Requiring 99.99%+ uptime SLA
- 24/7 critical production workload
- Financial or healthcare compliance requirements
- Need for DDoS protection beyond Cloudflare free tier

**Performance Indicators**:

- Latency requirements <50ms globally
- Need for application-level load balancing
- WebSocket connection limits exceeded
- Real-time/gaming applications with strict latency requirements

### Migration Path to Cloud

**Option 1: Keep Hybrid, Add Cloud for High-Traffic Services**:

```
Low traffic services → Stay on Cloudflare Tunnel (on-prem)
High traffic services → Migrate to cloud K8s + Cloud LB
Internal services → Stay on-prem with Tailscale
```

**Option 2: Full Migration to Cloud**:

```
Phase 1: Parallel cloud cluster deployment
Phase 2: Gradual service migration
Phase 3: DNS cutover
Phase 4: Decommission on-prem public access (keep for dev/test)
```

**Option 3: Edge + Origin Architecture**:

```
Cloudflare Workers/Pages (edge) → Cloudflare Tunnel → On-prem (origin)
Static content at edge, dynamic at origin
Best of both worlds: edge performance + on-prem control
```

### Technology Evolution

**Consider Adding**:

- **Cloudflare Load Balancer** (when multiple origins needed)
- **Cloudflare Argo Smart Routing** (performance optimization)
- **Cloudflare Access** (zero-trust access control)
- **Service Mesh** (Istio, Linkerd) for advanced traffic management
- **Multi-cluster** setup (on-prem + cloud)

## Success Metrics

### Technical Metrics

**Availability**:

- Target: 99.9% uptime (8.7 hours downtime/year)
- Measure: External monitoring probes

**Performance**:

- Target: P95 response time <500ms
- Target: P99 response time <1000ms
- Measure: Cloudflare Analytics, Prometheus

**Reliability**:

- Target: Error rate <0.1%
- Target: Successful failover in <5 minutes
- Measure: Log aggregation, alerting system

### Cost Metrics

**Phase 1** (Development):

- Target: $0/month
- Actual: Cloudflare free + Ngrok free

**Phase 2** (Small Production):

- Target: <$10/month
- Actual: Cloudflare free + Ngrok Personal

**Phase 3** (Production HA):

- Target: <$25/month
- Actual: Cloudflare free + Ngrok Pro

### Operational Metrics

**Time to Deploy New Service**:

- Target: <30 minutes
- Measure: From Ingress creation to public access

**Incident Response Time**:

- Target: <15 minutes to detect and respond
- Measure: Alert to remediation time

**Failover Success Rate**:

- Target: 100% successful failovers
- Practice: Monthly failover drills

## References

### Documentation

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Ngrok Kubernetes Ingress Controller](https://ngrok.com/docs/k8s/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

### Related ADRs

- [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](0016-talos-unraid-primary.md)
- [ADR-0009: Tailscale for Hybrid Cloud Networking](0009-tailscale-hybrid-networking.md)
- [ADR-0004: Cloudflare for DNS Services](0004-cloudflare-dns-services.md)
- [ADR-0005: Kubernetes as Container Orchestration Platform](0005-kubernetes-container-platform.md)

### External Resources

- [Cloudflare Zero Trust](https://www.cloudflare.com/products/zero-trust/)
- [Ngrok Pricing](https://ngrok.com/pricing)
- [Home Lab Load Balancing Best Practices](https://www.talos.dev/latest/)
