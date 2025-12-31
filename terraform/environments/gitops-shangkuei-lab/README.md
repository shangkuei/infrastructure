# Talos GitOps Shangkuei Lab

This Terraform environment bootstraps Flux CD on the **shangkuei-lab** Kubernetes cluster using the **Flux Operator** for GitOps-based continuous delivery.

> **Part 2 of 2**: This environment enables GitOps on an **existing running cluster** provisioned by [`talos-cluster-shangkuei-lab/`](../talos-cluster-shangkuei-lab/).
>
> **Prerequisites**: Complete [`talos-cluster-shangkuei-lab/`](../talos-cluster-shangkuei-lab/) deployment first. Cluster must be running and healthy.

## Overview

This environment uses the `gitops` module to install:

1. **cert-manager**: Certificate management for webhooks
2. **Flux Operator**: Manages Flux installation via FluxInstance CRD (Helm)
3. **FluxInstance**: Declarative Flux configuration with SOPS integration

## Quick Start

### 1. Generate Age Keys

```bash
make age-keygen
```

This creates two keys:

- **Terraform key**: For encrypting `terraform.tfvars` and `backend.hcl`
- **Flux key**: For encrypting Kubernetes manifests in Git

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your credentials
```

### 3. Configure Backend (Optional)

```bash
cp backend.hcl.example backend.hcl
# Edit backend.hcl with R2 credentials
make encrypt-backend
rm backend.hcl
```

### 4. Encrypt and Apply

```bash
make encrypt-tfvars
rm terraform.tfvars
make init
make plan
make apply
```

## Prerequisites

### Kubernetes Credentials

Extract credentials from your shangkuei-lab cluster:

```bash
# Create service account for Terraform
kubectl create serviceaccount gitops-admin -n kube-system
kubectl create clusterrolebinding gitops-admin --clusterrole=cluster-admin --serviceaccount=kube-system:gitops-admin

# Create token secret
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitops-admin-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: gitops-admin
type: kubernetes.io/service-account-token
EOF

# Get credentials
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
kubectl get secret gitops-admin-token -n kube-system -o jsonpath='{.data.token}' | base64 -d
kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
```

### GitHub Token

Create a GitHub personal access token with `repo` permissions.

## Component Versions

| Component | Version |
|-----------|---------|
| cert-manager | v1.19.1 |
| Flux Operator | 0.33.0 |
| Flux | v2.7.3 |

## Verification

After deployment:

```bash
# Check components
kubectl -n cert-manager get pods
kubectl -n flux-system get pods

# Check FluxInstance
kubectl -n flux-system get fluxinstance flux

# Check Git sync
kubectl -n flux-system get gitrepository
kubectl -n flux-system get kustomization
```

## GitOps Workflow

After Flux is installed, manage your cluster via Git:

```bash
# Add manifests to kubernetes/clusters/shangkuei-lab/
git add kubernetes/
git commit -m "feat: add monitoring stack"
git push

# Flux automatically syncs within 5 minutes
# Force immediate sync:
flux reconcile kustomization flux-system --with-source
```

## Directory Structure

```
kubernetes/
└── clusters/
    └── shangkuei-lab/           # Cluster-specific configuration
        ├── flux-system/         # Flux controllers
        └── kustomization.yaml   # Entry point
```

## SOPS Encryption

This environment uses two age keys:

| Key | Purpose | Location |
|-----|---------|----------|
| Terraform | Encrypt terraform.tfvars, backend.hcl | `~/.config/sops/age/gitops-shangkuei-lab.txt` |
| Flux | Encrypt Kubernetes manifests in Git | `~/.config/sops/age/gitops-shangkuei-lab-flux.txt` |

The Flux key is deployed to Kubernetes as the `sops-age` secret for manifest decryption.

## Troubleshooting

```bash
# Check Flux logs
make flux-logs

# Force reconcile
make flux-reconcile

# Check FluxInstance status
kubectl -n flux-system describe fluxinstance flux
```

## References

- [gitops module](../../modules/gitops/)
- [Flux Operator Documentation](https://fluxcd.control-plane.io/operator/)
- [Kubernetes manifests](../../../kubernetes/clusters/shangkuei-lab/)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | ~> 5.42 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.12 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.23 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_gitops"></a> [gitops](#module\_gitops) | ../../modules/gitops | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cert_manager_dns01_recursive_nameservers"></a> [cert\_manager\_dns01\_recursive\_nameservers](#input\_cert\_manager\_dns01\_recursive\_nameservers) | DNS server endpoints for DNS01 and DoH check requests (list of strings, e.g., ['8.8.8.8:53', '8.8.4.4:53'] or ['https://1.1.1.1/dns-query']) | `list(string)` | <pre>[<br/>  "1.1.1.1:53",<br/>  "8.8.8.8:53"<br/>]</pre> | no |
| <a name="input_cert_manager_dns01_recursive_nameservers_only"></a> [cert\_manager\_dns01\_recursive\_nameservers\_only](#input\_cert\_manager\_dns01\_recursive\_nameservers\_only) | When true, cert-manager will only query configured DNS resolvers for ACME DNS01 self check | `bool` | `true` | no |
| <a name="input_cert_manager_enable_certificate_owner_ref"></a> [cert\_manager\_enable\_certificate\_owner\_ref](#input\_cert\_manager\_enable\_certificate\_owner\_ref) | When true, certificate resource will be set as owner of the TLS secret | `bool` | `true` | no |
| <a name="input_cert_manager_enable_gateway_api"></a> [cert\_manager\_enable\_gateway\_api](#input\_cert\_manager\_enable\_gateway\_api) | Enable gateway API integration in cert-manager (requires v1.15+) | `bool` | `true` | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | Version of cert-manager Helm chart to install | `string` | `"v1.19.1"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Kubernetes cluster | `string` | `"shangkuei-lab"` | no |
| <a name="input_cluster_path"></a> [cluster\_path](#input\_cluster\_path) | Path in the repository where cluster manifests are stored | `string` | `"./kubernetes/clusters/shangkuei-lab"` | no |
| <a name="input_flux_components_extra"></a> [flux\_components\_extra](#input\_flux\_components\_extra) | Extra Flux components to install (e.g., image-reflector-controller, image-automation-controller) | `list(string)` | `[]` | no |
| <a name="input_flux_namespace"></a> [flux\_namespace](#input\_flux\_namespace) | Namespace where Flux controllers will be installed | `string` | `"flux-system"` | no |
| <a name="input_flux_network_policy"></a> [flux\_network\_policy](#input\_flux\_network\_policy) | Enable network policies for Flux controllers | `bool` | `true` | no |
| <a name="input_flux_operator_version"></a> [flux\_operator\_version](#input\_flux\_operator\_version) | Version of Flux Operator Helm chart to install | `string` | `"0.33.0"` | no |
| <a name="input_flux_version"></a> [flux\_version](#input\_flux\_version) | Version of Flux controllers to deploy via FluxInstance | `string` | `"v2.7.3"` | no |
| <a name="input_github_branch"></a> [github\_branch](#input\_github\_branch) | Git branch to track for GitOps | `string` | `"main"` | no |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub repository owner (organization or user) | `string` | n/a | yes |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository name (without owner) | `string` | n/a | yes |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub personal access token for Flux GitOps | `string` | n/a | yes |
| <a name="input_kubernetes_cluster_ca_certificate"></a> [kubernetes\_cluster\_ca\_certificate](#input\_kubernetes\_cluster\_ca\_certificate) | Kubernetes cluster CA certificate (base64 encoded) | `string` | n/a | yes |
| <a name="input_kubernetes_host"></a> [kubernetes\_host](#input\_kubernetes\_host) | Kubernetes cluster API endpoint (e.g., https://api.cluster.example.com:6443) | `string` | n/a | yes |
| <a name="input_kubernetes_token"></a> [kubernetes\_token](#input\_kubernetes\_token) | Kubernetes authentication token | `string` | n/a | yes |
| <a name="input_sops_age_key_path"></a> [sops\_age\_key\_path](#input\_sops\_age\_key\_path) | Path to the SOPS age private key file for Flux decryption (deployed to Kubernetes) | `string` | `"~/.config/sops/age/gitops-shangkuei-lab-flux.txt"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cert_manager_namespace"></a> [cert\_manager\_namespace](#output\_cert\_manager\_namespace) | Namespace where cert-manager is installed |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the Kubernetes cluster |
| <a name="output_cluster_path"></a> [cluster\_path](#output\_cluster\_path) | Path in repository where cluster manifests are stored |
| <a name="output_component_versions"></a> [component\_versions](#output\_component\_versions) | Versions of installed components |
| <a name="output_deployment_phase"></a> [deployment\_phase](#output\_deployment\_phase) | Current deployment phase and next steps |
| <a name="output_flux_logs_commands"></a> [flux\_logs\_commands](#output\_flux\_logs\_commands) | Commands to view Flux logs |
| <a name="output_flux_namespace"></a> [flux\_namespace](#output\_flux\_namespace) | Namespace where Flux is installed |
| <a name="output_git_branch"></a> [git\_branch](#output\_git\_branch) | Git branch tracked by Flux |
| <a name="output_git_repository"></a> [git\_repository](#output\_git\_repository) | Git repository URL used by Flux |
| <a name="output_next_steps"></a> [next\_steps](#output\_next\_steps) | Next steps after complete installation |
| <a name="output_verification_commands"></a> [verification\_commands](#output\_verification\_commands) | Commands to verify the installation |
<!-- END_TF_DOCS -->
