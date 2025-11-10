# ArgoCD Operator

GitOps continuous delivery tool for Kubernetes, installed via OLM v1.

## Overview

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It automates the deployment of applications by continuously monitoring
Git repositories and synchronizing the desired state with the live cluster state.

## Installation Method

- **Operator Source**: [OperatorHub.io](https://operatorhub.io/operator/argocd-operator)
- **Installation**: OLM v1 ClusterExtension
- **Catalog**: operatorhubio
- **Channel**: stable
- **Namespace**: argocd

## Components

- **namespace-argocd.yaml**: Dedicated namespace for ArgoCD
- **clusterextension-argocd-operator.yaml**: OLM v1 operator installation
- **kustomization.yaml**: Kustomize manifest

## Dependencies

- OLM v1 (operator-controller)
- operatorhubio ClusterCatalog

## Features

- GitOps workflow automation
- Multi-cluster management
- Automated sync and rollback
- SSO integration
- RBAC and security policies
- Application health monitoring
- Customizable sync strategies

## Usage

After installation, create ArgoCD instances using the ArgoCD CRD:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: argocd
  namespace: argocd
spec:
  server:
    route:
      enabled: false
  sso:
    provider: dex
```

## Documentation

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Operator Documentation](https://argocd-operator.readthedocs.io/)
- [OperatorHub Listing](https://operatorhub.io/operator/argocd-operator)
