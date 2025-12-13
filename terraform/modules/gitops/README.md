# Talos GitOps Module

This Terraform module bootstraps Flux CD on a Kubernetes cluster using the **Flux Operator** for GitOps-based continuous delivery.

## Overview

This module installs and configures:

1. **cert-manager**: Certificate management for webhooks (Helm)
2. **Flux Operator**: Manages Flux installation via FluxInstance CRD (Helm)
3. **FluxInstance**: Declarative Flux configuration with SOPS integration

## Architecture Benefits

- ✅ Declarative Flux management via FluxInstance CRD
- ✅ Native SOPS integration for encrypted manifests
- ✅ GitOps workflow with automatic reconciliation
- ✅ Reusable across multiple clusters/environments
- ✅ Simple Helm-based installation

## Usage

```hcl
module "gitops" {
  source = "../../modules/gitops"

  # Cluster configuration
  cluster_name = "my-cluster"
  cluster_path = "./kubernetes/clusters/my-cluster"

  # GitHub configuration
  github_owner      = "my-org"
  github_repository = "infrastructure"
  github_token      = var.github_token
  github_branch     = "main"

  # SOPS age key content (read from file)
  sops_age_key = file("~/.config/sops/age/my-cluster-flux.txt")

  # Optional: customize versions
  cert_manager_version  = "v1.19.1"
  flux_operator_version = "0.33.0"
  flux_version          = "v2.7.3"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| kubernetes | ~> 2.23 |
| helm | ~> 2.12 |

## Providers

The calling module must configure these providers:

```hcl
provider "kubernetes" {
  host                   = var.kubernetes_host
  token                  = var.kubernetes_token
  cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.kubernetes_host
    token                  = var.kubernetes_token
    cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the Kubernetes cluster | `string` | n/a | yes |
| cluster_path | Path in the repository where cluster manifests are stored | `string` | n/a | yes |
| github_owner | GitHub repository owner (organization or user) | `string` | n/a | yes |
| github_repository | GitHub repository name (without owner) | `string` | n/a | yes |
| github_token | GitHub personal access token for Flux GitOps | `string` | n/a | yes |
| sops_age_key | SOPS age private key content for Flux decryption | `string` | n/a | yes |
| github_branch | Git branch to track for GitOps | `string` | `"main"` | no |
| flux_namespace | Namespace where Flux controllers will be installed | `string` | `"flux-system"` | no |
| flux_network_policy | Enable network policies for Flux controllers | `bool` | `true` | no |
| flux_components_extra | Extra Flux components to install | `list(string)` | `[]` | no |
| cert_manager_version | Version of cert-manager Helm chart | `string` | `"v1.19.1"` | no |
| cert_manager_dns01_recursive_nameservers | DNS servers for ACME DNS01 challenges | `list(string)` | `["1.1.1.1:53", "8.8.8.8:53"]` | no |
| cert_manager_dns01_recursive_nameservers_only | Only use configured DNS resolvers | `bool` | `true` | no |
| cert_manager_enable_certificate_owner_ref | Auto-cleanup secrets when cert deleted | `bool` | `true` | no |
| cert_manager_enable_gateway_api | Enable Gateway API support | `bool` | `true` | no |
| flux_operator_version | Version of Flux Operator Helm chart | `string` | `"0.33.0"` | no |
| flux_version | Version of Flux controllers | `string` | `"v2.7.3"` | no |

## Outputs

| Name | Description |
|------|-------------|
| flux_namespace | Namespace where Flux is installed |
| cert_manager_namespace | Namespace where cert-manager is installed |
| git_repository | Git repository URL used by Flux |
| git_branch | Git branch tracked by Flux |
| cluster_path | Path in repository where cluster manifests are stored |
| cluster_name | Name of the Kubernetes cluster |
| component_versions | Versions of installed components |
| verification_commands | Commands to verify the installation |
| flux_logs_commands | Commands to view Flux logs |

## Deployment

The module uses Helm releases with proper dependency ordering. All resources are applied in a single `terraform apply`:

1. **cert-manager**: Installed first for webhook certificate management
2. **flux-system namespace**: Created for Flux components
3. **Flux Operator**: Installed via Helm from ghcr.io OCI registry
4. **SOPS secret**: Created for encrypted manifest decryption
5. **FluxInstance**: Bootstraps Flux controllers and Git sync

## SOPS Integration

The module creates a `sops-age` secret in the flux-system namespace. The FluxInstance is configured to use this secret for decrypting SOPS-encrypted manifests in the Git repository.

### Creating Encrypted Secrets

1. Create `.sops.yaml` in your repository with the Flux age public key
2. Create secret manifests and encrypt with SOPS
3. Flux automatically decrypts manifests during reconciliation

## License

See the repository LICENSE file.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.12 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 1.19.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.flux_operator](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.flux_instance](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.cert_manager](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.flux_system](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.flux_git_credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.sops_age](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cert_manager_dns01_recursive_nameservers"></a> [cert\_manager\_dns01\_recursive\_nameservers](#input\_cert\_manager\_dns01\_recursive\_nameservers) | DNS server endpoints for DNS01 and DoH check requests (list of strings, e.g., ['8.8.8.8:53', '8.8.4.4:53'] or ['https://1.1.1.1/dns-query']) | `list(string)` | <pre>[<br/>  "1.1.1.1:53",<br/>  "8.8.8.8:53"<br/>]</pre> | no |
| <a name="input_cert_manager_dns01_recursive_nameservers_only"></a> [cert\_manager\_dns01\_recursive\_nameservers\_only](#input\_cert\_manager\_dns01\_recursive\_nameservers\_only) | When true, cert-manager will only query configured DNS resolvers for ACME DNS01 self check | `bool` | `true` | no |
| <a name="input_cert_manager_enable_certificate_owner_ref"></a> [cert\_manager\_enable\_certificate\_owner\_ref](#input\_cert\_manager\_enable\_certificate\_owner\_ref) | When true, certificate resource will be set as owner of the TLS secret | `bool` | `true` | no |
| <a name="input_cert_manager_enable_gateway_api"></a> [cert\_manager\_enable\_gateway\_api](#input\_cert\_manager\_enable\_gateway\_api) | Enable gateway API integration in cert-manager (requires v1.15+) | `bool` | `true` | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | Version of cert-manager Helm chart to install | `string` | `"v1.19.1"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Kubernetes cluster | `string` | n/a | yes |
| <a name="input_cluster_path"></a> [cluster\_path](#input\_cluster\_path) | Path in the repository where cluster manifests are stored | `string` | n/a | yes |
| <a name="input_flux_components_extra"></a> [flux\_components\_extra](#input\_flux\_components\_extra) | Extra Flux components to install (e.g., image-reflector-controller, image-automation-controller) | `list(string)` | `[]` | no |
| <a name="input_flux_namespace"></a> [flux\_namespace](#input\_flux\_namespace) | Namespace where Flux controllers will be installed | `string` | `"flux-system"` | no |
| <a name="input_flux_network_policy"></a> [flux\_network\_policy](#input\_flux\_network\_policy) | Enable network policies for Flux controllers | `bool` | `true` | no |
| <a name="input_flux_operator_version"></a> [flux\_operator\_version](#input\_flux\_operator\_version) | Version of Flux Operator Helm chart to install | `string` | `"0.33.0"` | no |
| <a name="input_flux_version"></a> [flux\_version](#input\_flux\_version) | Version of Flux controllers to deploy via FluxInstance | `string` | `"v2.7.3"` | no |
| <a name="input_github_branch"></a> [github\_branch](#input\_github\_branch) | Git branch to track for GitOps | `string` | `"main"` | no |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub repository owner (organization or user) | `string` | n/a | yes |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository name (without owner) | `string` | n/a | yes |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub personal access token for Flux GitOps | `string` | n/a | yes |
| <a name="input_sops_age_key"></a> [sops\_age\_key](#input\_sops\_age\_key) | SOPS age private key content for Flux decryption (deployed to Kubernetes secret) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cert_manager_namespace"></a> [cert\_manager\_namespace](#output\_cert\_manager\_namespace) | Namespace where cert-manager is installed |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the Kubernetes cluster |
| <a name="output_cluster_path"></a> [cluster\_path](#output\_cluster\_path) | Path in repository where cluster manifests are stored |
| <a name="output_component_versions"></a> [component\_versions](#output\_component\_versions) | Versions of installed components |
| <a name="output_flux_logs_commands"></a> [flux\_logs\_commands](#output\_flux\_logs\_commands) | Commands to view Flux logs |
| <a name="output_flux_namespace"></a> [flux\_namespace](#output\_flux\_namespace) | Namespace where Flux is installed |
| <a name="output_git_branch"></a> [git\_branch](#output\_git\_branch) | Git branch tracked by Flux |
| <a name="output_git_repository"></a> [git\_repository](#output\_git\_repository) | Git repository URL used by Flux |
| <a name="output_verification_commands"></a> [verification\_commands](#output\_verification\_commands) | Commands to verify the installation |
<!-- END_TF_DOCS -->
