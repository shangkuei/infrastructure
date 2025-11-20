# Migration Summary: salary-mailman - Updated Architecture

## Migration Status: ✅ Adapted - Ready for Configuration

Migrated from Flux CD (hsjtw cluster) to ArgoCD (shangkuei-xyz-talos cluster) with updated architecture.

## Major Changes

### 1. Container Image: Private Registry

- **Before**: `bitnami/nginx:1.25` (public)
- **After**: `ghcr.io/edatw/salary-mailman:1` (private GHCR)
- **Required**: GitHub PAT with `read:packages` permission

### 2. Storage: Embedded Content

- **Before**: SMB CSI → Synology NAS
- **After**: Content embedded in container image
- **Impact**: Removed PV, PVC, StorageClass

### 3. Exposure: Cloudflare Tunnel

- **Before**: Gateway API HTTPRoute
- **After**: Cloudflared sidecar container
- **Impact**: Removed HTTPRoute, added tunnel configuration

## Required Configuration

### 1. GHCR Pull Secret ⚠️

```bash
cd overlays/shangkuei-xyz-talos
vim secret-ghcr-pull.yaml

# Update:
# - GITHUB_USERNAME
# - GITHUB_TOKEN (PAT with read:packages)
# - Base64 of "username:token"

# Generate base64 auth:
echo -n "USERNAME:TOKEN" | base64

# Encrypt:
sops -e -i secret-ghcr-pull.yaml
```

### 2. Cloudflare Tunnel Token ⚠️

```bash
# Create tunnel in Cloudflare dashboard
# Copy tunnel token

vim secret-cloudflared.yaml
# Replace: CLOUDFLARE_TUNNEL_TOKEN

# Encrypt:
sops -e -i secret-cloudflared.yaml
```

### 3. Configure Tunnel Route

In Cloudflare dashboard:

- Public hostname: `salary-mailman.yourdomain.com`
- Service: `http://salary-mailman.salary-mailman.svc.cluster.local:8080`

## Quick Deploy

```bash
# 1. Validate
kustomize build argocd-examples/salary-mailman/base

# 2. Deploy
kubectl apply -f kubernetes/overlays/argocd-examples/shangkuei-xyz-talos/application-salary-mailman.yaml

# 3. Verify
kubectl get all,secret -n salary-mailman
kubectl logs -n salary-mailman -l app=salary-mailman -c cloudflared

# 4. Test
curl https://salary-mailman.yourdomain.com/
```

## Files Summary

**Base (6)**: namespace, serviceaccount, deployment, service, secret-cloudflared, secret-ghcr-pull

**Overlay (4)**: kustomization, ksops-generator, secret-cloudflared (encrypted), secret-ghcr-pull (encrypted)

**Removed (5)**: storage-class, persistent-volume, persistent-volume-claim, httproute, secret-smb-creds

See [README.md](README.md) for detailed documentation.
