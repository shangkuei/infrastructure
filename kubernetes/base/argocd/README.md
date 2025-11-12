# ArgoCD

GitOps continuous delivery tool for Kubernetes, installed directly via Helm.

## Overview

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes.
It automates the deployment of applications by continuously monitoring Git
repositories and synchronizing the desired state with the live cluster state.

## Installation Method

- **Source**: [Argo Helm Charts](https://github.com/argoproj/argo-helm)
- **Installation**: Direct Helm installation via Flux CD HelmRelease
- **Repository**: https://argoproj.github.io/argo-helm
- **Chart**: argo-cd
- **Chart Version**: 7.7.8
- **ArgoCD Version**: v2.13.2
- **Namespace**: argocd

## Why Direct Installation (Not Operator)?

The ArgoCD Operator v0.15.0 uses `webhookDefinitions` which are **not supported by OLM v1** (operator-controller). Direct Helm installation:

- ✅ No OLM v1 limitations
- ✅ Official installation method
- ✅ Simpler architecture
- ✅ Better Flux CD integration
- ✅ Full webhook support
- ✅ Easier version management

## Components

- **namespace-argocd.yaml**: Dedicated namespace for ArgoCD
- **helmrepository-argo.yaml**: Argo Helm repository source
- **helmrelease-argocd.yaml**: Direct ArgoCD Helm installation
- **kustomization.yaml**: Kustomize manifest

## Dependencies

- Flux CD (source-controller and helm-controller)
- Kubernetes 1.24+

## Features

- GitOps workflow automation
- Multi-cluster management
- Automated sync and rollback
- SSO integration (Dex)
- RBAC and security policies
- Application health monitoring
- ApplicationSet controller
- Notifications controller
- Declarative repository management

## Deployment

### Apply via Kustomize

```bash
kubectl apply -k kubernetes/base/argocd/
```

### Verify Installation

```bash
# Check HelmRelease
kubectl get helmrelease argocd -n argocd

# Check ArgoCD pods
kubectl get pods -n argocd

# Check CRDs
kubectl get crds | grep argoproj.io
```

## Access ArgoCD

### Get Initial Admin Password

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

### Port Forward to UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at: https://localhost:8080

- **Username**: `admin`
- **Password**: (from secret above)

### Login via CLI

```bash
argocd login localhost:8080 \
  --username admin \
  --password <password-from-secret> \
  --insecure
```

## Configuration

### Update Domain and URL

Edit [helmrelease-argocd.yaml](helmrelease-argocd.yaml) and update:

```yaml
values:
  global:
    domain: argocd.example.com  # Your domain

  server:
    config:
      url: https://argocd.example.com  # Your URL
```

### Enable Ingress

```yaml
values:
  server:
    ingress:
      enabled: true
      ingressClassName: nginx
      hosts:
        - argocd.example.com
      tls:
        - secretName: argocd-tls
          hosts:
            - argocd.example.com
```

### Add Git Repositories

```yaml
values:
  configs:
    repositories:
      - url: https://github.com/your-org/your-repo
        type: git
      - url: https://github.com/your-org/another-repo
        type: git
        sshPrivateKeySecret:
          name: git-ssh-key
          key: sshPrivateKey
```

### Configure SSO

```yaml
values:
  dex:
    enabled: true

  server:
    config:
      # Add Dex configuration
      dex.config: |
        connectors:
          - type: github
            id: github
            name: GitHub
            config:
              clientID: $GITHUB_CLIENT_ID
              clientSecret: $GITHUB_CLIENT_SECRET
```

## Resource Scaling

For production environments, adjust resources:

```yaml
values:
  controller:
    replicas: 2
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 4Gi

  server:
    replicas: 2
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 1000m
        memory: 1Gi

  repoServer:
    replicas: 2
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 2Gi
```

## High Availability

For HA setup:

```yaml
values:
  redis-ha:
    enabled: true

  redis:
    enabled: false

  controller:
    replicas: 2

  server:
    replicas: 3

  repoServer:
    replicas: 3
```

## Monitoring

Enable Prometheus ServiceMonitors:

```yaml
values:
  controller:
    metrics:
      enabled: true
      serviceMonitor:
        enabled: true

  server:
    metrics:
      enabled: true
      serviceMonitor:
        enabled: true

  repoServer:
    metrics:
      enabled: true
      serviceMonitor:
        enabled: true
```

## Documentation

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Argo Helm Charts](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Testing Guide](../../docs/guides/argocd-testing-guide.md)

## Troubleshooting

See the [ArgoCD Testing Guide](../../docs/guides/argocd-testing-guide.md) for detailed troubleshooting steps.

### Common Issues

**HelmRelease not Ready**:

```bash
kubectl describe helmrelease argocd -n argocd
kubectl logs -n flux-system -l app=helm-controller
```

**Pods CrashLoopBackOff**:

```bash
kubectl logs -n argocd <pod-name>
kubectl describe pod -n argocd <pod-name>
```

**Cannot Access UI**:

```bash
kubectl get svc -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
