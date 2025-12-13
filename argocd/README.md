# ArgoCD Test Applications

This directory contains test applications for validating ArgoCD multi-application management and KSOPS encrypted secrets functionality.

## Purpose

- **Multi-Application Management**: Test ArgoCD's ability to manage multiple applications from a single repository
- **KSOPS Integration**: Validate encrypted secrets using SOPS/Age with ArgoCD
- **GitOps Workflow**: Demonstrate declarative application deployment patterns

## Structure

```
argocd-examples/
├── app1/                    # Test application 1 (nginx example)
│   ├── base/               # Base kustomize configuration
│   └── overlays/           # Environment-specific overlays
│       └── shangkuei-xyz-talos/
│           ├── secret-app1.yaml      # SOPS-encrypted secret
│           ├── ksops-generator.yaml  # KSOPS generator config
│           └── kustomization.yaml
├── app2/                    # Test application 2 (redis example)
│   ├── base/               # Base kustomize configuration
│   └── overlays/           # Environment-specific overlays
│       └── shangkuei-xyz-talos/
│           ├── secret-app2.yaml      # SOPS-encrypted secret
│           ├── ksops-generator.yaml  # KSOPS generator config
│           └── kustomization.yaml
└── argocd-apps/            # ArgoCD Application manifests
    ├── base/               # Base application definitions
    │   ├── app1.yaml       # ArgoCD Application for app1
    │   ├── app2.yaml       # ArgoCD Application for app2
    │   └── kustomization.yaml
    └── overlays/           # Cluster-specific application configs
        └── shangkuei-xyz-talos/
```

## Age Key Architecture

This setup uses **two separate Age keys** for enhanced security:

### 1. Flux Age Key (`gitops-flux.txt`)

- **Purpose**: Flux uses this to decrypt Kubernetes manifests
- **Usage**: Encrypts the ArgoCD SOPS Age key secret
- **Location**: `~/.config/sops/age/gitops-flux.txt`

### 2. ArgoCD Age Key (`argocd-ksops.txt`)

- **Purpose**: Dedicated key for ArgoCD KSOPS plugin
- **Usage**: Encrypts test application secrets
- **Deployment**: Deployed to ArgoCD namespace by Flux
- **Location**: `~/.config/sops/age/argocd-ksops.txt`

**Why Two Keys?** Separation of concerns - Flux deploys the ArgoCD key but doesn't use it directly.

## Quick Start

```bash
# Generate Age key and setup secrets
cd kubernetes/overlays/argocd-examples/shangkuei-xyz-talos
make setup

# Commit and deploy
git add . && git commit -m "feat(argocd): add KSOPS setup" && git push

# Deploy test applications
kubectl apply -k argocd-examples/argocd-apps/base/
```

## Testing

See [ArgoCD Testing Guide](../docs/guides/argocd-testing-guide.md) for comprehensive procedures.

## Cleanup

```bash
kubectl delete -k argocd-examples/argocd-apps/base/
```

## Notes

- Test applications only - not for production
- Secrets contain dummy data
- All manifests follow GitOps best practices
