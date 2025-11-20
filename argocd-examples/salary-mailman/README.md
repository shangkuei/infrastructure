# Salary Mailman Application

Static site application with dedicated container image and Cloudflare Tunnel exposure. Migrated from Flux CD (hsjtw cluster) to ArgoCD (shangkuei-xyz-talos cluster).

## Overview

This application serves a static salary comparison site using a dedicated container image
(`ghcr.io/edatw/salary-mailman:1`). The application is exposed to the internet via
Cloudflare Tunnel using a cloudflared sidecar container.

## Architecture

### Application Components

```
┌─────────────────────────────────────────┐
│         Kubernetes Pod                   │
│                                          │
│  ┌────────────────┐  ┌───────────────┐  │
│  │ salary-mailman │  │  cloudflared  │  │
│  │                │  │   (sidecar)   │  │
│  │ Container      │  │               │  │
│  │ Port: 8080     │  │ Tunnel to CF  │  │
│  └────────────────┘  └───────────────┘  │
│                                          │
└─────────────────────────────────────────┘
              │
              ↓
        ClusterIP Service
              │
              ↓
        Cloudflare Tunnel
              │
              ↓
          Internet
```

### Key Features

- **Dedicated Container Image**: `ghcr.io/edatw/salary-mailman:1` with baked-in static content
- **Cloudflare Tunnel**: Secure exposure via cloudflared sidecar (no ingress/gateway needed)
- **No External Storage**: Content is embedded in the container image
- **PSS Compliant**: Security contexts configured for Pod Security Standards

## Directory Structure

```
salary-mailman/
├── base/                           # Base Kubernetes manifests
│   ├── namespace.yaml              # salary-mailman namespace
│   ├── serviceaccount.yaml         # Service account for pods
│   ├── deployment.yaml             # Main app + cloudflared sidecar
│   ├── service.yaml                # ClusterIP service on port 8080
│   ├── secret-cloudflared.yaml     # Cloudflared tunnel token (template)
│   └── kustomization.yaml          # Base kustomization config
└── overlays/
    └── shangkuei-xyz-talos/        # Cluster-specific overlay
        ├── kustomization.yaml      # Overlay configuration
        ├── ksops-generator.yaml    # SOPS secret decryption config
        └── secret-cloudflared.yaml # Cloudflare tunnel token (SOPS encrypted)
```

## Architecture Changes from Flux

### Original (Flux CD - hsjtw cluster)

- **Deployment**: Flux HelmRelease → Bitnami nginx Helm chart (v15.8.x)
- **Content Storage**: SMB CSI driver → Synology NAS (ds916plus)
- **Exposure**: HTTPRoute → Gateway API on `hsjtw.shangkuei.xyz`
- **Secret Management**: SOPS with age encryption

### Updated (ArgoCD - shangkuei-xyz-talos cluster)

- **Deployment**: Native Kubernetes Deployment → `ghcr.io/edatw/salary-mailman:1`
- **Content Storage**: Embedded in container image (no external storage)
- **Exposure**: Cloudflare Tunnel via cloudflared sidecar
- **Secret Management**: SOPS with age encryption via KSOPS (Cloudflare tunnel token)

## Configuration Steps

### 1. Obtain Cloudflare Tunnel Token

Create a Cloudflare Tunnel in your Cloudflare dashboard or via CLI:

```bash
# Using cloudflared CLI
cloudflared tunnel create salary-mailman

# Get the tunnel token
cloudflared tunnel token <tunnel-id>
```

Or via the Cloudflare Zero Trust dashboard:

1. Go to Zero Trust → Networks → Tunnels
2. Create a new tunnel named "salary-mailman"
3. Copy the tunnel token

### 2. Configure the Secret

Edit the secret file with your tunnel token:

```bash
cd overlays/shangkuei-xyz-talos
vim secret-cloudflared.yaml

# Replace REPLACE_WITH_CLOUDFLARE_TUNNEL_TOKEN with your actual tunnel token
```

### 3. Encrypt the Secret with SOPS

```bash
# Encrypt in place
sops -e -i secret-cloudflared.yaml

# Verify encryption
sops -d secret-cloudflared.yaml
```

The age recipient is: `age1dvf63gewxhnydzt4yjlpp23qplqekt979udv4xgk47zct48kh40srrdjwn`

### 4. Configure Cloudflare Tunnel Routes

In the Cloudflare dashboard, configure the tunnel to route to your service:

- **Public hostname**: `salary-mailman.yourdomain.com` (or subdomain of your choice)
- **Service**: `http://salary-mailman.salary-mailman.svc.cluster.local:8080`

### 5. Deploy via ArgoCD

The ArgoCD Application manifest is located at:

- `kubernetes/overlays/argocd-examples/shangkuei-xyz-talos/application-salary-mailman.yaml`

Deploy via Flux (recommended):

```bash
kubectl apply -f kubernetes/overlays/argocd-examples/shangkuei-xyz-talos/application-salary-mailman.yaml
```

Or apply directly:

```bash
kubectl apply -f argocd-examples/argocd-apps/base/salary-mailman.yaml
```

## Validation

### 1. Verify Kustomize Build

```bash
# Build the overlay (will fail on SOPS without ksops plugin, but validates structure)
kustomize build overlays/shangkuei-xyz-talos

# Build just the base
kustomize build base
```

### 2. Check ArgoCD Sync Status

```bash
# Check application status
kubectl get application salary-mailman -n argocd

# View application details
argocd app get salary-mailman
```

### 3. Verify Deployment

```bash
# Check all resources
kubectl get all -n salary-mailman

# Check pods are running
kubectl get pods -n salary-mailman

# Check both containers are running
kubectl get pods -n salary-mailman -o jsonpath='{.items[0].spec.containers[*].name}'
# Expected: salary-mailman cloudflared

# Check cloudflared logs
kubectl logs -n salary-mailman -l app=salary-mailman -c cloudflared

# Test the service internally
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://salary-mailman.salary-mailman.svc.cluster.local:8080
```

### 4. Test External Access

```bash
# Test via Cloudflare Tunnel
curl https://salary-mailman.yourdomain.com/
```

## Key Differences from Original

1. **Simplified Storage**: No SMB CSI driver, PV, PVC, or StorageClass needed
2. **Dedicated Image**: Using `ghcr.io/edatw/salary-mailman:1` instead of generic nginx
3. **Cloudflare Tunnel**: Replaced Gateway API HTTPRoute with cloudflared sidecar
4. **Deployment Name**: Changed from `nginx` to `salary-mailman`
5. **Service Name**: Changed from `nginx` to `salary-mailman`
6. **Security Context**: Explicitly defined PSS-compliant security contexts
7. **Resource Limits**: Added CPU and memory limits for better resource management
8. **Probes**: Startup, liveness, and readiness probes configured

## Troubleshooting

### Cloudflared Connection Issues

```bash
# Check cloudflared logs
kubectl logs -n salary-mailman -l app=salary-mailman -c cloudflared

# Common issues:
# 1. Invalid tunnel token → Update secret and restart pod
# 2. Tunnel not found in Cloudflare → Create tunnel in CF dashboard
# 3. Service not reachable → Check service configuration
```

### Application Not Starting

```bash
# Check pod status
kubectl describe pod -n salary-mailman -l app=salary-mailman

# Check application logs
kubectl logs -n salary-mailman -l app=salary-mailman -c salary-mailman

# Common issues:
# 1. Image pull errors → Verify image exists and is accessible
# 2. Container startup failures → Check application logs
# 3. Resource constraints → Review resource limits
```

### SOPS Decryption Failures

```bash
# Verify ArgoCD has the age key
kubectl get secret argocd-age-key -n argocd

# Check ArgoCD application sync errors
argocd app get salary-mailman

# Manually verify decryption
sops -d overlays/shangkuei-xyz-talos/secret-cloudflared.yaml
```

### Service Not Accessible via Tunnel

```bash
# Verify service exists and has endpoints
kubectl get svc salary-mailman -n salary-mailman
kubectl get endpoints salary-mailman -n salary-mailman

# Check Cloudflare Tunnel status in dashboard
# Verify tunnel configuration points to correct service
```

## Migration Checklist

- [ ] Create Cloudflare Tunnel
- [ ] Obtain tunnel token
- [ ] Update tunnel token in secret file
- [ ] Encrypt secret with SOPS
- [ ] Configure tunnel routes in Cloudflare dashboard
- [ ] Deploy ArgoCD Application manifest
- [ ] Verify pods are running (both containers)
- [ ] Test internal service accessibility
- [ ] Test external access via Cloudflare Tunnel
- [ ] Update DNS/domain configuration if needed

## References

- Original Flux config: `/Users/shangkuei/dev/shangkuei/flux/hsjtw/salary-mailman`
- Container image: `ghcr.io/edatw/salary-mailman:1`
- Cloudflare Tunnel docs: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
- KSOPS: https://github.com/viaduct-ai/kustomize-sops

## Additional Notes

### Image Updates

The application uses a dedicated container image. To update:

1. Build and push new image version to `ghcr.io/edatw/salary-mailman:<version>`
2. Update image tag in `base/deployment.yaml`
3. Commit and push changes
4. ArgoCD will automatically sync and deploy

### Cloudflare Tunnel Token Rotation

To rotate the tunnel token:

1. Generate new token in Cloudflare dashboard
2. Update `overlays/shangkuei-xyz-talos/secret-cloudflared.yaml`
3. Re-encrypt with SOPS: `sops -e -i secret-cloudflared.yaml`
4. Commit and push changes
5. ArgoCD will sync and restart pods with new token
