# Runbook: Hybrid Load Balancer Operations

**Document ID**: RB-0004
**Last Updated**: 2025-11-01
**Status**: Active
**Related ADR**: [ADR-0017: Hybrid Load Balancing](../decisions/0017-hybrid-load-balancing.md)
**Related Spec**: [Hybrid Load Balancing Technical Spec](../../specs/network/hybrid-load-balancing.md)

## Overview

This runbook covers operational procedures for managing the hybrid load balancing infrastructure using Cloudflare Tunnel (primary) and Ngrok (secondary) for the on-premises Talos Kubernetes cluster.

### Components Covered

- Cloudflare Tunnel (cloudflared)
- Ngrok Kubernetes Ingress Controller
- MetalLB
- NGINX Ingress Controller

### Prerequisites

- `kubectl` configured with cluster access
- `cloudflared` CLI installed
- `helm` CLI installed
- Cloudflare account access
- Ngrok account access

---

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Day-to-Day Operations](#day-to-day-operations)
3. [Monitoring and Health Checks](#monitoring-and-health-checks)
4. [Troubleshooting](#troubleshooting)
5. [Maintenance Procedures](#maintenance-procedures)
6. [Emergency Procedures](#emergency-procedures)
7. [Configuration Changes](#configuration-changes)

---

## Initial Setup

### 1. Install Cloudflare Tunnel

#### Step 1.1: Install cloudflared CLI

**macOS**:

```bash
brew install cloudflared
```

**Linux**:

```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

**Verify**:

```bash
cloudflared version
```

#### Step 1.2: Authenticate with Cloudflare

```bash
# Login to Cloudflare
cloudflared tunnel login

# This opens browser for authentication
# Follow the prompts and select your domain
```

**Expected Output**:

```
You have successfully logged in.
If you wish to copy your credentials to a server, they have been saved to:
/Users/username/.cloudflared/cert.pem
```

#### Step 1.3: Create Tunnel

```bash
# Create tunnel with descriptive name
cloudflared tunnel create talos-home

# Note the Tunnel ID from output
# Example: Created tunnel talos-home with id: <TUNNEL_UUID>
```

**Save Important Information**:

```bash
# Save these for later use:
# - Tunnel ID: <TUNNEL_UUID>
# - Credentials file: ~/.cloudflared/<TUNNEL_UUID>.json
```

#### Step 1.4: Configure Tunnel

Create tunnel configuration file:

```bash
mkdir -p ~/.cloudflared

cat > ~/.cloudflared/config.yml <<EOF
tunnel: <TUNNEL_UUID>
credentials-file: /root/.cloudflared/<TUNNEL_UUID>.json

ingress:
  # Production apps
  - hostname: app.example.com
    service: http://192.168.1.240:80
    originRequest:
      httpHostHeader: app.example.com

  # API endpoints
  - hostname: api.example.com
    service: https://192.168.1.240:443
    originRequest:
      originServerName: api.example.com

  # Wildcard staging
  - hostname: "*.staging.example.com"
    service: http://192.168.1.240:80

  # Catch-all
  - service: http_status:404
EOF
```

**Validate Configuration**:

```bash
cloudflared tunnel ingress validate ~/.cloudflared/config.yml
```

**Expected Output**:

```
Validating rules from ~/.cloudflared/config.yml
OK
```

#### Step 1.5: Configure DNS

```bash
# Route DNS for each hostname to the tunnel
cloudflared tunnel route dns talos-home app.example.com
cloudflared tunnel route dns talos-home api.example.com
cloudflared tunnel route dns talos-home "*.staging.example.com"
```

**Expected Output** (for each):

```
2025-11-01T10:00:00Z INF Added CNAME app.example.com which will route to this tunnel
```

**Verify DNS**:

```bash
# Check DNS records in Cloudflare dashboard
# Or use dig:
dig app.example.com CNAME
```

#### Step 1.6: Deploy to Kubernetes

**Create Namespace**:

```bash
kubectl create namespace cloudflare-tunnel
```

**Create Secrets**:

```bash
# Create secret with credentials
kubectl create secret generic tunnel-credentials \
  --from-file=credentials.json=$HOME/.cloudflared/<TUNNEL_UUID>.json \
  -n cloudflare-tunnel

# Create ConfigMap with config
kubectl create configmap tunnel-config \
  --from-file=config.yaml=$HOME/.cloudflared/config.yml \
  -n cloudflare-tunnel
```

**Deploy cloudflared**:

```bash
kubectl apply -f - <<EOF
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
        - /etc/cloudflared/config/config.yaml
        - --metrics
        - 0.0.0.0:2000
        - run

        ports:
        - name: metrics
          containerPort: 2000

        livenessProbe:
          httpGet:
            path: /ready
            port: 2000
          initialDelaySeconds: 10
          periodSeconds: 10

        readinessProbe:
          httpGet:
            path: /ready
            port: 2000
          initialDelaySeconds: 10
          periodSeconds: 10

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
          name: tunnel-config
      - name: credentials
        secret:
          secretName: tunnel-credentials
EOF
```

**Verify Deployment**:

```bash
# Check pods are running
kubectl get pods -n cloudflare-tunnel

# Expected: 2 pods in Running state
# NAME                           READY   STATUS    RESTARTS   AGE
# cloudflared-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
# cloudflared-xxxxxxxxxx-xxxxx   1/1     Running   0          1m

# Check logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=20
```

**Expected Log Output**:

```
INF Starting tunnel tunnelID=<TUNNEL_UUID>
INF Connection registered connIndex=0 location=LAX
INF Connection registered connIndex=1 location=LAX
```

#### Step 1.7: Test Cloudflare Tunnel

```bash
# Test external access (wait 30-60 seconds for DNS propagation)
curl -I https://app.example.com

# Expected: HTTP 200 or appropriate response from backend
```

---

### 2. Install Ngrok Ingress Controller

#### Step 2.1: Create Ngrok Account and Get Credentials

1. Sign up at https://dashboard.ngrok.com/
2. Navigate to "Your Authtoken" page
3. Copy your authtoken
4. Navigate to "API Keys"
5. Create new API key and copy it

**Save Credentials**:

```bash
# Store in environment variables (for this session)
export NGROK_AUTHTOKEN="<your-authtoken>"
export NGROK_API_KEY="<your-api-key>"
```

#### Step 2.2: Install via Helm

```bash
# Add Helm repository
helm repo add ngrok https://ngrok.github.io/kubernetes-ingress-controller
helm repo update

# Install Ngrok Ingress Controller
helm install ngrok-ingress-controller ngrok/kubernetes-ingress-controller \
  --namespace ngrok-ingress \
  --create-namespace \
  --set credentials.apiKey=$NGROK_API_KEY \
  --set credentials.authtoken=$NGROK_AUTHTOKEN \
  --set controller.replicaCount=1 \
  --set controller.ingressClass.default=false
```

**Expected Output**:

```
NAME: ngrok-ingress-controller
NAMESPACE: ngrok-ingress
STATUS: deployed
```

#### Step 2.3: Verify Installation

```bash
# Check pods
kubectl get pods -n ngrok-ingress

# Expected:
# NAME                                        READY   STATUS    RESTARTS   AGE
# ngrok-ingress-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          1m

# Check ingress class
kubectl get ingressclass

# Expected to see 'ngrok' in the list
# NAME    CONTROLLER                       PARAMETERS   AGE
# nginx   k8s.io/ingress-nginx             <none>       10d
# ngrok   k8s.io/ingress-ngrok-controller  <none>       1m
```

#### Step 2.4: Test Ngrok Ingress

```bash
# Create test application
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: test-ngrok
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: test-ngrok
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
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app
  namespace: test-ngrok
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app
  namespace: test-ngrok
spec:
  ingressClassName: ngrok
  rules:
  - http:
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

**Get Ngrok URL**:

```bash
# Wait 30-60 seconds for Ngrok to provision
kubectl get ingress test-app -n test-ngrok

# Check the ADDRESS column for the ngrok.app URL
# Example: abc123.ngrok.app
```

**Test Access**:

```bash
NGROK_URL=$(kubectl get ingress test-app -n test-ngrok -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl https://$NGROK_URL
```

**Expected**: HTML from nginx welcome page

**Cleanup Test**:

```bash
kubectl delete namespace test-ngrok
```

---

### 3. Verify MetalLB and NGINX Ingress

These should already be installed per [ADR-0016](../decisions/0016-talos-unraid-primary.md).

**Verify MetalLB**:

```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspools -n metallb-system
```

**Verify NGINX Ingress**:

```bash
kubectl get svc -n ingress-nginx

# Should show:
# NAME                                 TYPE           EXTERNAL-IP      PORT(S)
# ingress-nginx-controller             LoadBalancer   192.168.1.240    80:xxxxx/TCP,443:xxxxx/TCP
```

**Test NGINX Access**:

```bash
# From within local network
curl http://192.168.1.240

# Expected: 404 or backend response (if default backend configured)
```

---

## Day-to-Day Operations

### Check System Health

**Quick Health Check Script**:

```bash
#!/bin/bash
# save as: check-lb-health.sh

echo "=== Cloudflare Tunnel Status ==="
kubectl get pods -n cloudflare-tunnel
echo ""

echo "=== Ngrok Ingress Status ==="
kubectl get pods -n ngrok-ingress
echo ""

echo "=== MetalLB Status ==="
kubectl get pods -n metallb-system
echo ""

echo "=== NGINX Ingress Status ==="
kubectl get pods -n ingress-nginx
echo ""

echo "=== NGINX Service IP ==="
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""
echo ""

echo "=== Active Ingresses ==="
kubectl get ingress -A
```

**Run Health Check**:

```bash
chmod +x check-lb-health.sh
./check-lb-health.sh
```

### View Logs

**Cloudflare Tunnel Logs**:

```bash
# All pods
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=50

# Specific pod
kubectl logs -n cloudflare-tunnel <pod-name> --tail=100 -f

# Errors only
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=100 | grep -i error
```

**Ngrok Ingress Controller Logs**:

```bash
# Controller logs
kubectl logs -n ngrok-ingress -l app=ngrok-ingress-controller --tail=50 -f

# Errors only
kubectl logs -n ngrok-ingress -l app=ngrok-ingress-controller --tail=100 | grep -i error
```

**NGINX Ingress Logs**:

```bash
# Controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50

# Access logs (if enabled)
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f | grep "GET\|POST\|PUT\|DELETE"
```

### List All Public Endpoints

**Script to List All Exposed Services**:

```bash
#!/bin/bash
# save as: list-endpoints.sh

echo "=== Production Endpoints (Cloudflare Tunnel) ==="
echo "Configured in tunnel config:"
kubectl get configmap -n cloudflare-tunnel tunnel-config -o jsonpath='{.data.config\.yaml}' | grep "hostname:"
echo ""

echo "=== Development Endpoints (Ngrok) ==="
kubectl get ingress -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CLASS:.spec.ingressClassName,HOSTS:.spec.rules[*].host,ADDRESS:.status.loadBalancer.ingress[*].hostname | grep ngrok
echo ""

echo "=== All Ingress Resources ==="
kubectl get ingress -A
```

---

## Monitoring and Health Checks

### Prometheus Metrics

**Cloudflare Tunnel Metrics**:

```bash
# Port-forward to metrics endpoint
kubectl port-forward -n cloudflare-tunnel deploy/cloudflared 2000:2000

# In another terminal, scrape metrics
curl http://localhost:2000/metrics

# Key metrics to watch:
# - cloudflared_tunnel_total_requests
# - cloudflared_tunnel_request_errors
# - cloudflared_tunnel_response_time_seconds
```

**NGINX Ingress Metrics**:

```bash
# Metrics should be scraped by Prometheus automatically if configured
# View in Grafana or query Prometheus directly

# Port-forward to NGINX metrics
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller-metrics 10254:10254

# Scrape metrics
curl http://localhost:10254/metrics
```

### External Monitoring

**Setup with UptimeRobot** (Free):

1. Create account at https://uptimerobot.com
2. Add monitors for:
   - `https://app.example.com` (production via Cloudflare)
   - `https://api.example.com` (API via Cloudflare)
   - Any critical Ngrok endpoints (if persistent)

3. Configure alerts:
   - Email notifications
   - Slack/Discord webhooks (optional)
   - Check interval: 5 minutes

**Setup with Better Uptime** (Alternative):

1. Create account at https://betteruptime.com
2. Add monitors with:
   - URL checks
   - SSL certificate monitoring
   - Response time tracking
3. Configure incident escalation

### Health Check Endpoints

**Create Health Check Service**:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: healthz
  namespace: default
spec:
  selector:
    app: healthz
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: healthz
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: healthz
  template:
    metadata:
      labels:
        app: healthz
    spec:
      containers:
      - name: healthz
        image: gcr.io/google_containers/echoserver:1.10
        ports:
        - containerPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: healthz
  namespace: default
spec:
  ingressClassName: nginx
  rules:
  - host: health.example.com
    http:
      paths:
      - path: /healthz
        pathType: Prefix
        backend:
          service:
            name: healthz
            port:
              number: 80
EOF
```

**Test Health Endpoint**:

```bash
curl https://health.example.com/healthz
```

---

## Troubleshooting

### Issue: Cloudflare Tunnel Pods Not Starting

**Symptoms**:

- Pods in `CrashLoopBackOff` or `Error` state
- Cannot access sites via Cloudflare Tunnel

**Diagnosis**:

```bash
# Check pod status
kubectl get pods -n cloudflare-tunnel

# Check events
kubectl get events -n cloudflare-tunnel --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n cloudflare-tunnel <pod-name>
```

**Common Causes and Solutions**:

**1. Invalid Credentials**:

```bash
# Verify secret exists and contains valid JSON
kubectl get secret tunnel-credentials -n cloudflare-tunnel -o jsonpath='{.data.credentials\.json}' | base64 -d | jq .

# Expected: Valid JSON with AccountTag, TunnelSecret, TunnelID

# If invalid, recreate secret:
kubectl delete secret tunnel-credentials -n cloudflare-tunnel
kubectl create secret generic tunnel-credentials \
  --from-file=credentials.json=$HOME/.cloudflared/<TUNNEL_UUID>.json \
  -n cloudflare-tunnel

# Restart pods
kubectl rollout restart deployment/cloudflared -n cloudflare-tunnel
```

**2. Invalid Configuration**:

```bash
# Check config
kubectl get configmap tunnel-config -n cloudflare-tunnel -o yaml

# Validate locally
kubectl get configmap tunnel-config -n cloudflare-tunnel -o jsonpath='{.data.config\.yaml}' > /tmp/config.yaml
cloudflared tunnel ingress validate /tmp/config.yaml

# If errors, fix config and update:
kubectl create configmap tunnel-config \
  --from-file=config.yaml=/path/to/fixed/config.yml \
  -n cloudflare-tunnel \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods
kubectl rollout restart deployment/cloudflared -n cloudflare-tunnel
```

**3. Network Connectivity Issues**:

```bash
# Test connectivity from pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh

# Inside pod:
curl -I https://api.cloudflare.com
# Should get HTTP 200

# If fails, check network policies or firewall rules
```

### Issue: Site Returns 502 Bad Gateway

**Symptoms**:

- Site accessible but returns 502 error
- Cloudflare Tunnel shows connected

**Diagnosis**:

```bash
# Check tunnel logs for connection errors
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=100 | grep -i "502\|bad gateway\|connection refused"

# Check NGINX ingress logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100

# Check backend service
kubectl get svc -A | grep <your-service>
kubectl get endpoints <your-service> -n <namespace>
```

**Common Causes and Solutions**:

**1. Backend Service Not Ready**:

```bash
# Check backend pods
kubectl get pods -n <namespace> -l app=<your-app>

# If not running, check deployment
kubectl describe deployment <your-app> -n <namespace>

# Check pod logs
kubectl logs -n <namespace> <pod-name>
```

**2. Incorrect Service Configuration in Tunnel**:

```bash
# Verify tunnel config points to correct IP
kubectl get configmap tunnel-config -n cloudflare-tunnel -o yaml

# Should show: service: http://192.168.1.240:80

# Verify NGINX has this IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# If mismatch, update tunnel config
```

**3. Ingress Not Configured**:

```bash
# Check if Ingress exists for the hostname
kubectl get ingress -A | grep <hostname>

# If missing, create Ingress resource
# See "Adding New Service" section
```

### Issue: Ngrok Ingress Not Working

**Symptoms**:

- Ingress created but no URL assigned
- Ngrok URL returns 404 or error

**Diagnosis**:

```bash
# Check ingress status
kubectl describe ingress <ingress-name> -n <namespace>

# Check controller logs
kubectl logs -n ngrok-ingress -l app=ngrok-ingress-controller --tail=50

# Check controller status
kubectl get pods -n ngrok-ingress
```

**Common Causes and Solutions**:

**1. Invalid Credentials**:

```bash
# Check Helm values
helm get values ngrok-ingress-controller -n ngrok-ingress

# If credentials invalid, update:
helm upgrade ngrok-ingress-controller ngrok/kubernetes-ingress-controller \
  --namespace ngrok-ingress \
  --set credentials.apiKey=<NEW_API_KEY> \
  --set credentials.authtoken=<NEW_AUTHTOKEN> \
  --reuse-values
```

**2. Rate Limit Exceeded** (Free Tier):

```bash
# Check logs for rate limit messages
kubectl logs -n ngrok-ingress -l app=ngrok-ingress-controller --tail=100 | grep -i "rate limit\|quota"

# Solution: Upgrade to paid plan or wait for rate limit reset
```

**3. Wrong Ingress Class**:

```bash
# Verify ingressClassName is set to 'ngrok'
kubectl get ingress <ingress-name> -n <namespace> -o yaml | grep ingressClassName

# Should show: ingressClassName: ngrok

# If wrong, patch:
kubectl patch ingress <ingress-name> -n <namespace> -p '{"spec":{"ingressClassName":"ngrok"}}'
```

### Issue: High Latency

**Symptoms**:

- Slow response times
- Timeouts

**Diagnosis**:

```bash
# Test latency at different points
curl -w "@curl-format.txt" -o /dev/null -s https://app.example.com

# Create curl-format.txt:
cat > curl-format.txt <<EOF
    time_namelookup:  %{time_namelookup}s\n
       time_connect:  %{time_connect}s\n
    time_appconnect:  %{time_appconnect}s\n
   time_pretransfer:  %{time_pretransfer}s\n
      time_redirect:  %{time_redirect}s\n
 time_starttransfer:  %{time_starttransfer}s\n
                    ----------\n
         time_total:  %{time_total}s\n
EOF

# Check Cloudflare Analytics for tunnel latency
# Visit Cloudflare dashboard → Zero Trust → Tunnels → Analytics
```

**Common Causes and Solutions**:

**1. ISP Upload Bandwidth Limit**:

```bash
# Run speed test
speedtest-cli

# If upload is slow, consider:
# - Optimizing response sizes (compression)
# - Using CDN/caching more aggressively
# - Migrating to cloud for high-traffic services
```

**2. Resource Constraints**:

```bash
# Check pod resources
kubectl top pods -n cloudflare-tunnel
kubectl top pods -n ingress-nginx

# If high, increase resource limits
kubectl edit deployment cloudflared -n cloudflare-tunnel
# Increase limits.cpu and limits.memory
```

**3. Backend Application Slow**:

```bash
# Check application logs and metrics
kubectl logs -n <namespace> <pod-name> --tail=100

# Profile application performance
# Add APM (Application Performance Monitoring) if not present
```

---

## Maintenance Procedures

### Update Cloudflare Tunnel Configuration

**Add New Hostname**:

1. **Update local config**:

```bash
# Edit ~/.cloudflared/config.yml
vim ~/.cloudflared/config.yml

# Add new hostname BEFORE the catch-all:
# - hostname: new-app.example.com
#   service: http://192.168.1.240:80
```

2. **Validate**:

```bash
cloudflared tunnel ingress validate ~/.cloudflared/config.yml
```

3. **Update ConfigMap**:

```bash
kubectl create configmap tunnel-config \
  --from-file=config.yaml=$HOME/.cloudflared/config.yml \
  -n cloudflare-tunnel \
  --dry-run=client -o yaml | kubectl apply -f -
```

4. **Restart cloudflared**:

```bash
kubectl rollout restart deployment/cloudflared -n cloudflare-tunnel
```

5. **Configure DNS**:

```bash
cloudflared tunnel route dns talos-home new-app.example.com
```

6. **Verify**:

```bash
# Wait 30-60 seconds
curl -I https://new-app.example.com
```

### Update Cloudflared Image

```bash
# Update to latest image
kubectl set image deployment/cloudflared \
  cloudflared=cloudflare/cloudflared:latest \
  -n cloudflare-tunnel

# Or edit deployment
kubectl edit deployment cloudflared -n cloudflare-tunnel
# Change image tag

# Monitor rollout
kubectl rollout status deployment/cloudflared -n cloudflare-tunnel

# Verify
kubectl get pods -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=20
```

### Rotate Tunnel Credentials

**When to Rotate**:

- Suspected credential compromise
- Regular security policy (e.g., every 90 days)
- Team member departure

**Steps**:

1. **Create new tunnel** (recommended over rotating):

```bash
cloudflared tunnel create talos-home-new
# Note new Tunnel ID
```

2. **Update configuration**:

```bash
# Update config with new tunnel ID
vim ~/.cloudflared/config.yml
# Change tunnel: <OLD_UUID> to tunnel: <NEW_UUID>
```

3. **Update Kubernetes secrets**:

```bash
# Create new secret
kubectl create secret generic tunnel-credentials-new \
  --from-file=credentials.json=$HOME/.cloudflared/<NEW_UUID>.json \
  -n cloudflare-tunnel

# Update ConfigMap
kubectl create configmap tunnel-config-new \
  --from-file=config.yaml=$HOME/.cloudflared/config.yml \
  -n cloudflare-tunnel

# Update deployment to use new secrets
kubectl edit deployment cloudflared -n cloudflare-tunnel
# Change secret names in volumeMounts
```

4. **Update DNS**:

```bash
# Route DNS to new tunnel
cloudflared tunnel route dns talos-home-new app.example.com
# Repeat for all hostnames
```

5. **Verify new tunnel works**:

```bash
curl -I https://app.example.com
```

6. **Clean up old tunnel**:

```bash
# After confirming new tunnel works for 24-48 hours
cloudflared tunnel delete talos-home

# Delete old Kubernetes resources
kubectl delete secret tunnel-credentials -n cloudflare-tunnel
kubectl delete configmap tunnel-config -n cloudflare-tunnel
```

### Scale Cloudflared Replicas

**Increase Replicas** (for higher availability):

```bash
kubectl scale deployment cloudflared --replicas=3 -n cloudflare-tunnel

# Verify
kubectl get pods -n cloudflare-tunnel
```

**Decrease Replicas**:

```bash
kubectl scale deployment cloudflared --replicas=1 -n cloudflare-tunnel
```

**Set Auto-Scaling** (optional, requires metrics-server):

```bash
kubectl autoscale deployment cloudflared \
  --min=2 --max=4 \
  --cpu-percent=80 \
  -n cloudflare-tunnel
```

### Upgrade Ngrok Ingress Controller

```bash
# Check current version
helm list -n ngrok-ingress

# Update Helm repository
helm repo update ngrok

# Check available versions
helm search repo ngrok/kubernetes-ingress-controller --versions

# Upgrade to latest
helm upgrade ngrok-ingress-controller ngrok/kubernetes-ingress-controller \
  --namespace ngrok-ingress \
  --reuse-values

# Or upgrade to specific version
helm upgrade ngrok-ingress-controller ngrok/kubernetes-ingress-controller \
  --namespace ngrok-ingress \
  --version 1.2.3 \
  --reuse-values

# Monitor upgrade
kubectl rollout status deployment/ngrok-ingress-controller -n ngrok-ingress

# Verify
kubectl get pods -n ngrok-ingress
helm get values ngrok-ingress-controller -n ngrok-ingress
```

---

## Emergency Procedures

### Complete Cloudflare Tunnel Outage

**Symptoms**:

- All Cloudflare Tunnel endpoints down
- Cloudflared pods failing
- Cannot connect to Cloudflare

**Immediate Actions**:

1. **Check tunnel status**:

```bash
kubectl get pods -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=50
```

2. **Verify Cloudflare service status**:

```bash
# Check https://www.cloudflarestatus.com/
curl -s https://www.cloudflarestatus.com/ | grep -i "all systems operational"
```

3. **If Cloudflare is down** (rare):
   - Wait for service restoration
   - Monitor https://www.cloudflarestatus.com/
   - No action needed, automatic recovery

4. **If local issue**:

**Option A: Restart cloudflared**:

```bash
kubectl rollout restart deployment/cloudflared -n cloudflare-tunnel
kubectl rollout status deployment/cloudflared -n cloudflare-tunnel
```

**Option B: Failover to Ngrok**:

```bash
# For critical services, quickly create Ngrok ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: emergency-app-ngrok
  namespace: production
  annotations:
    k8s.ngrok.com/domain: emergency-app.ngrok.app  # Or custom domain on paid plan
spec:
  ingressClassName: ngrok
  rules:
  - host: emergency-app.ngrok.app
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: production-app
            port:
              number: 80
EOF

# Get Ngrok URL
kubectl get ingress emergency-app-ngrok -n production

# Update DNS manually in Cloudflare dashboard:
# Change app.example.com CNAME to point to Ngrok URL
# Or communicate Ngrok URL to users temporarily
```

**Option C: Complete Tunnel Recreation**:

See "Rotate Tunnel Credentials" section above for complete recreation steps.

### NGINX Ingress Controller Failure

**Symptoms**:

- 502/503 errors on all services
- NGINX pods not running

**Immediate Actions**:

1. **Check NGINX status**:

```bash
kubectl get pods -n ingress-nginx
kubectl describe pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

2. **Check logs**:

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100
```

3. **Restart NGINX**:

```bash
kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx
```

4. **If still failing, reinstall**:

```bash
# Delete and reinstall (CAUTION: causes brief downtime)
helm uninstall ingress-nginx -n ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --values /path/to/nginx-ingress-values.yaml
```

5. **Verify LoadBalancer IP**:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Should show 192.168.1.240
```

### MetalLB Failure

**Symptoms**:

- NGINX Ingress has no EXTERNAL-IP
- LoadBalancer services stuck in Pending

**Immediate Actions**:

1. **Check MetalLB status**:

```bash
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb --tail=100
```

2. **Check IP pool configuration**:

```bash
kubectl get ipaddresspools -n metallb-system
kubectl describe ipaddresspool default-pool -n metallb-system
```

3. **Restart MetalLB**:

```bash
kubectl rollout restart deployment/controller -n metallb-system
kubectl rollout restart daemonset/speaker -n metallb-system
```

4. **If still failing, check L2 advertisement**:

```bash
kubectl get l2advertisements -n metallb-system
kubectl describe l2advertisement default-advertisement -n metallb-system
```

### Complete Network Failure (ISP Outage)

**Symptoms**:

- Cannot reach external sites
- All tunnels down
- Local network still accessible via Tailscale

**Actions**:

1. **Verify ISP outage**:

```bash
# From a device outside the network (mobile hotspot)
ping your-home-ip

# Check ISP status page
```

2. **Communicate to users**:
   - Update status page
   - Send notifications
   - Provide ETA if known

3. **No technical action required**:
   - Services will auto-recover when ISP restores
   - Tunnels reconnect automatically

4. **Post-recovery verification**:

```bash
# Check all services
./check-lb-health.sh

# Test external access
curl -I https://app.example.com
```

---

## Configuration Changes

### Adding a New Public Service (via Cloudflare Tunnel)

**Complete Steps**:

1. **Deploy application to Kubernetes**:

```bash
kubectl apply -f your-app-deployment.yaml
```

2. **Create Service**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: new-app
  namespace: production
spec:
  selector:
    app: new-app
  ports:
  - port: 80
    targetPort: 8080
```

3. **Create Ingress**:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: new-app
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - newapp.example.com
    secretName: newapp-example-com-tls
  rules:
  - host: newapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: new-app
            port:
              number: 80
```

4. **Update Cloudflare Tunnel config**:

```bash
# Edit config
vim ~/.cloudflared/config.yml

# Add BEFORE catch-all:
#   - hostname: newapp.example.com
#     service: http://192.168.1.240:80

# Validate
cloudflared tunnel ingress validate ~/.cloudflared/config.yml

# Update ConfigMap
kubectl create configmap tunnel-config \
  --from-file=config.yaml=$HOME/.cloudflared/config.yml \
  -n cloudflare-tunnel \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart cloudflared
kubectl rollout restart deployment/cloudflared -n cloudflare-tunnel
```

5. **Configure DNS**:

```bash
cloudflared tunnel route dns talos-home newapp.example.com
```

6. **Wait for cert-manager**:

```bash
# Monitor certificate issuance
kubectl get certificate -n production
kubectl describe certificate newapp-example-com-tls -n production
```

7. **Test**:

```bash
# Wait 60-120 seconds for DNS + cert
curl -I https://newapp.example.com
```

### Adding a New Development Service (via Ngrok)

**Steps**:

1. **Deploy application**:

```bash
kubectl apply -f dev-app-deployment.yaml
```

2. **Create Service and Ingress**:

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
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dev-app
  namespace: development
spec:
  ingressClassName: ngrok
  rules:
  - http:  # Will get auto-assigned ngrok.app URL
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dev-app
            port:
              number: 80
```

3. **Apply and get URL**:

```bash
kubectl apply -f dev-app-ingress.yaml

# Wait 30-60 seconds
kubectl get ingress dev-app -n development

# Get the ngrok URL from ADDRESS column
```

4. **Optional: Use custom domain** (Pro+ plan):

```yaml
metadata:
  annotations:
    k8s.ngrok.com/domain: dev-app.yourdomain.com
```

### Changing Service Routing (Cloudflare → Ngrok or vice versa)

**Scenario**: Move service from Cloudflare Tunnel to Ngrok

1. **Create Ngrok Ingress**:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ngrok
  namespace: production
  annotations:
    k8s.ngrok.com/domain: app-backup.ngrok.app
spec:
  ingressClassName: ngrok
  rules:
  - host: app-backup.ngrok.app
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: production-app
            port:
              number: 80
EOF
```

2. **Test Ngrok URL**:

```bash
curl https://app-backup.ngrok.app
```

3. **Update DNS** (if needed):

```bash
# In Cloudflare dashboard, change CNAME for app.example.com
# From: <tunnel-id>.cfargotunnel.com
# To: app-backup.ngrok.app
```

4. **Or remove from tunnel config**:

```bash
# Edit config to remove hostname
vim ~/.cloudflared/config.yml
# Remove or comment out the hostname

# Update and restart
kubectl create configmap tunnel-config \
  --from-file=config.yaml=$HOME/.cloudflared/config.yml \
  -n cloudflare-tunnel \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment/cloudflared -n cloudflare-tunnel
```

---

## Backup and Disaster Recovery

### Backup Critical Configuration

**Create Backup Script**:

```bash
#!/bin/bash
# save as: backup-lb-config.sh

BACKUP_DIR="./lb-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backing up load balancer configuration to $BACKUP_DIR"

# Cloudflare Tunnel
kubectl get configmap tunnel-config -n cloudflare-tunnel -o yaml > "$BACKUP_DIR/tunnel-config.yaml"
kubectl get secret tunnel-credentials -n cloudflare-tunnel -o yaml > "$BACKUP_DIR/tunnel-credentials.yaml"
kubectl get deployment cloudflared -n cloudflare-tunnel -o yaml > "$BACKUP_DIR/cloudflared-deployment.yaml"

# Ngrok
helm get values ngrok-ingress-controller -n ngrok-ingress > "$BACKUP_DIR/ngrok-values.yaml"

# MetalLB
kubectl get ipaddresspool -n metallb-system -o yaml > "$BACKUP_DIR/metallb-ippool.yaml"
kubectl get l2advertisement -n metallb-system -o yaml > "$BACKUP_DIR/metallb-l2ad.yaml"

# NGINX Ingress
helm get values ingress-nginx -n ingress-nginx > "$BACKUP_DIR/nginx-values.yaml"

# All Ingresses
kubectl get ingress -A -o yaml > "$BACKUP_DIR/all-ingresses.yaml"

echo "Backup complete: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
```

**Run Backup**:

```bash
chmod +x backup-lb-config.sh
./backup-lb-config.sh
```

**Schedule Regular Backups** (via cron):

```bash
# Add to crontab
crontab -e

# Add line (daily at 2 AM):
0 2 * * * /path/to/backup-lb-config.sh
```

### Restore from Backup

```bash
# Restore Cloudflare Tunnel
kubectl apply -f lb-backups/20251101-020000/tunnel-config.yaml
kubectl apply -f lb-backups/20251101-020000/tunnel-credentials.yaml
kubectl apply -f lb-backups/20251101-020000/cloudflared-deployment.yaml

# Restore MetalLB
kubectl apply -f lb-backups/20251101-020000/metallb-ippool.yaml
kubectl apply -f lb-backups/20251101-020000/metallb-l2ad.yaml

# Restore all Ingresses
kubectl apply -f lb-backups/20251101-020000/all-ingresses.yaml

# Verify
./check-lb-health.sh
```

---

## Useful Commands Reference

### Quick Commands

```bash
# Check all load balancer components
kubectl get pods -n cloudflare-tunnel -n ngrok-ingress -n metallb-system -n ingress-nginx

# Tail all logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared -f

# Get all ingresses with details
kubectl get ingress -A -o wide

# Port-forward to metrics
kubectl port-forward -n cloudflare-tunnel deploy/cloudflared 2000:2000

# Test tunnel config locally
cloudflared tunnel ingress validate ~/.cloudflared/config.yml

# Restart all components
kubectl rollout restart deployment/cloudflared -n cloudflare-tunnel
kubectl rollout restart deployment/ngrok-ingress-controller -n ngrok-ingress
kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx
```

---

## Related Documentation

- [ADR-0017: Hybrid Load Balancing with Cloudflare Tunnel and Ngrok](../decisions/0017-hybrid-load-balancing.md)
- [Technical Specification: Hybrid Load Balancing](../../specs/network/hybrid-load-balancing.md)
- [ADR-0016: Talos Linux on Unraid as Primary Infrastructure](../decisions/0016-talos-unraid-primary.md)
- [Runbook: Talos Operations](0003-talos-operations.md)

---

**Document Version**: 1.0
**Last Review Date**: 2025-11-01
**Next Review Date**: 2026-02-01
**Document Owner**: Infrastructure Team
