# Talos Cluster Shangkuei Dev

Terraform environment for deploying a development Talos Linux Kubernetes cluster with Tailscale networking.

## Overview

This environment uses the `talos-cluster` module to generate Talos machine configurations for a development Kubernetes
cluster. The cluster is designed to operate over Tailscale mesh networking for secure, private cluster communication.

## Features

- **Tailscale Integration**: All cluster communication via Tailscale mesh network
- **KubePrism**: Local load balancer for high-availability API access
- **CNI Flexibility**: Support for Flannel (default), Cilium, or Calico
- **SOPS Encryption**: Secure secrets management with age encryption
- **OpenEBS Support**: Optional LocalPV and Mayastor storage configuration

## Prerequisites

- Terraform >= 1.6.0
- [talosctl](https://www.talos.dev/latest/introduction/getting-started/)
- [SOPS](https://github.com/getsops/sops) (for secrets management)
- [age](https://age-encryption.org/) (for encryption)
- Tailscale account with [auth key](https://login.tailscale.com/admin/settings/keys)

## Quick Start

### 1. Generate Encryption Key

```bash
make age-keygen
```

Update `.sops.yaml` with your public key.

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration
```

### 3. Encrypt Variables

```bash
make encrypt-tfvars
rm terraform.tfvars  # Remove unencrypted file
```

### 4. Deploy Cluster

```bash
make init
make apply
make apply-configs INSECURE=true
# Wait for nodes to join Tailscale
make bootstrap
make health
```

## Directory Structure

```
talos-cluster-shangkuei-dev/
├── main.tf                     # Module invocation
├── variables.tf                # Input variables
├── outputs.tf                  # Output definitions
├── versions.tf                 # Provider requirements
├── backend.tf                  # State backend configuration
├── Makefile                    # Automation commands
├── .sops.yaml                  # SOPS encryption configuration
├── .gitignore                  # Git ignore patterns
├── terraform.tfvars.example    # Example configuration
├── terraform.tfvars.enc        # Encrypted variables (committed)
├── backend.hcl.enc             # Encrypted backend config (committed)
└── generated/                  # Generated configs (gitignored)
    ├── control-plane-*.yaml
    ├── worker-*.yaml
    ├── talosconfig
    └── cilium-values.yaml
```

## Makefile Commands

### Terraform Operations

| Command | Description |
|---------|-------------|
| `make init` | Initialize Terraform |
| `make plan` | Preview changes |
| `make apply` | Generate cluster configurations |
| `make destroy` | Remove configurations |
| `make validate` | Validate Terraform files |
| `make format` | Format Terraform files |

### Cluster Deployment

| Command | Description |
|---------|-------------|
| `make apply-configs` | Apply configs to all nodes |
| `make apply-configs INSECURE=true` | Initial setup (before certs) |
| `make apply-configs NODE=cp-01` | Apply to specific node |
| `make bootstrap` | Bootstrap Kubernetes cluster |
| `make deploy-cilium` | Deploy Cilium CNI |

### Cluster Status

| Command | Description |
|---------|-------------|
| `make health` | Check cluster health |
| `make nodes` | List cluster nodes |
| `make pods` | List all pods |
| `make status` | Complete cluster status |

### Cluster Access

| Command | Description |
|---------|-------------|
| `make kubeconfig` | Retrieve kubeconfig |
| `make talosconfig` | Show talosconfig export |
| `make env` | Show all environment exports |
| `make dashboard NODE=<ip>` | Open Talos dashboard |
| `make logs NODE=<ip> SERVICE=<name>` | View service logs |

### Maintenance

| Command | Description |
|---------|-------------|
| `make upgrade-k8s VERSION=v1.32.0` | Upgrade Kubernetes |
| `make upgrade-talos VERSION=v1.9.0 NODE=<ip>` | Upgrade Talos |
| `make reset-node NODE=<ip>` | Reset a node |
| `make clean` | Remove generated files |

### SOPS Encryption

| Command | Description |
|---------|-------------|
| `make age-keygen` | Generate age encryption key |
| `make age-info` | Display key information |
| `make encrypt-backend` | Encrypt backend.hcl |
| `make encrypt-tfvars` | Encrypt terraform.tfvars |

## Deployment Workflow

### Initial Deployment (Two-Phase)

1. **Generate configurations**:

   ```bash
   make apply
   ```

2. **Apply configs in insecure mode** (before Tailscale is active):

   ```bash
   make apply-configs INSECURE=true
   ```

3. **Wait for Tailscale** (~1-2 minutes):
   Check [Tailscale admin console](https://login.tailscale.com/admin/machines) for new nodes

4. **Update terraform.tfvars** with real Tailscale IPs

5. **Regenerate configurations**:

   ```bash
   make apply
   ```

6. **Reapply configs in secure mode**:

   ```bash
   make apply-configs
   ```

7. **Bootstrap Kubernetes**:

   ```bash
   make bootstrap
   ```

8. **Verify cluster**:

   ```bash
   make health
   make nodes
   ```

### With Cilium CNI

After bootstrap:

```bash
make kubeconfig
make deploy-cilium
```

## Security Notes

- **Never commit** unencrypted `terraform.tfvars` or `backend.hcl`
- **Encrypted files** (`.enc`) are safe to commit
- **Age private key** should be stored in a password manager
- **Tailscale auth key** should use tags for ACL management

## Troubleshooting

### Common Commands

```bash
# Check node status
talosctl -n <node-ip> services

# View service logs
talosctl -n <node-ip> logs kubelet

# Reset a node
talosctl -n <node-ip> reset --graceful

# Open dashboard
talosctl -n <node-ip> dashboard
```

### Useful Links

- [Talos Documentation](https://www.talos.dev/)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [SOPS Documentation](https://github.com/getsops/sops)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | >= 0.7.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_talos_cluster"></a> [talos\_cluster](#module\_talos\_cluster) | ../../modules/talos-cluster | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_control_plane_patches"></a> [additional\_control\_plane\_patches](#input\_additional\_control\_plane\_patches) | Additional YAML patches to apply to control plane nodes (merged with Tailscale patches) | `list(string)` | `[]` | no |
| <a name="input_additional_worker_patches"></a> [additional\_worker\_patches](#input\_additional\_worker\_patches) | Additional YAML patches to apply to worker nodes (merged with Tailscale patches) | `list(string)` | `[]` | no |
| <a name="input_cert_sans"></a> [cert\_sans](#input\_cert\_sans) | Additional Subject Alternative Names (SANs) for API server certificate (Tailscale IPs will be added automatically) | `list(string)` | `[]` | no |
| <a name="input_cilium_helm_values"></a> [cilium\_helm\_values](#input\_cilium\_helm\_values) | Helm values for Cilium CNI deployment (only used when cni\_name = 'cilium'). Map of values to customize Cilium installation. | `any` | <pre>{<br/>  "hubble": {<br/>    "enabled": false,<br/>    "relay": {<br/>      "enabled": false<br/>    },<br/>    "ui": {<br/>      "enabled": false<br/>    }<br/>  },<br/>  "ipv6": {<br/>    "enabled": false<br/>  },<br/>  "k8sServiceHost": "localhost",<br/>  "k8sServicePort": 6443,<br/>  "kubeProxyReplacement": "true",<br/>  "operator": {<br/>    "replicas": 1<br/>  }<br/>}</pre> | no |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | Kubernetes API endpoint using Tailscale IP (e.g., https://100.64.0.10:6443). Set to first control plane's Tailscale IP. | `string` | `""` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Kubernetes cluster | `string` | n/a | yes |
| <a name="input_cni_name"></a> [cni\_name](#input\_cni\_name) | CNI plugin name (flannel, cilium, calico, or none) | `string` | `"flannel"` | no |
| <a name="input_control_plane_nodes"></a> [control\_plane\_nodes](#input\_control\_plane\_nodes) | Map of control plane nodes with their configuration (using Tailscale IPs) | <pre>map(object({<br/>    tailscale_ipv4 = string           # Tailscale IPv4 address (100.64.0.0/10 range)<br/>    tailscale_ipv6 = optional(string) # Tailscale IPv6 address (fd7a:115c:a1e0::/48 range)<br/>    physical_ip    = optional(string) # Physical IP (for initial bootstrapping only)<br/>    install_disk   = string<br/>    hostname       = optional(string)<br/>    interface      = optional(string, "tailscale0")<br/>    platform       = optional(string, "metal")                        # Platform type: metal, metal-arm64, metal-secureboot, aws, gcp, azure, etc.<br/>    extensions     = optional(list(string), ["siderolabs/tailscale"]) # Talos system extensions (default: Tailscale only)<br/>    # SBC overlay configuration (for Raspberry Pi, Rock Pi, etc.)<br/>    overlay = optional(object({<br/>      image = string # Overlay image (e.g., "siderolabs/sbc-raspberrypi")<br/>      name  = string # Overlay name (e.g., "rpi_generic", "rpi_5")<br/>    }))<br/>    # Kubernetes topology and node labels<br/>    region      = optional(string)          # topology.kubernetes.io/region<br/>    zone        = optional(string)          # topology.kubernetes.io/zone<br/>    arch        = optional(string)          # kubernetes.io/arch (e.g., amd64, arm64)<br/>    os          = optional(string)          # kubernetes.io/os (e.g., linux)<br/>    node_labels = optional(map(string), {}) # Additional node-specific labels<br/>  }))</pre> | n/a | yes |
| <a name="input_dns_domain"></a> [dns\_domain](#input\_dns\_domain) | Kubernetes DNS domain | `string` | `"cluster.local"` | no |
| <a name="input_enable_kubeprism"></a> [enable\_kubeprism](#input\_enable\_kubeprism) | Enable KubePrism for high-availability Kubernetes API access | `bool` | `true` | no |
| <a name="input_kubeprism_port"></a> [kubeprism\_port](#input\_kubeprism\_port) | Port for KubePrism local load balancer | `number` | `7445` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version (e.g., v1.31.0) | `string` | `"v1.31.0"` | no |
| <a name="input_node_labels"></a> [node\_labels](#input\_node\_labels) | Additional Kubernetes node labels to apply to all nodes | `map(string)` | `{}` | no |
| <a name="input_openebs_hostpath_enabled"></a> [openebs\_hostpath\_enabled](#input\_openebs\_hostpath\_enabled) | Enable OpenEBS LocalPV Hostpath support (adds Pod Security admission control exemptions and kubelet hostpath mounts for openebs namespace) | `bool` | `false` | no |
| <a name="input_pod_cidr"></a> [pod\_cidr](#input\_pod\_cidr) | Pod network CIDR block | `string` | `"10.244.0.0/16"` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | Service network CIDR block | `string` | `"10.96.0.0/12"` | no |
| <a name="input_tailscale_auth_key"></a> [tailscale\_auth\_key](#input\_tailscale\_auth\_key) | Tailscale authentication key for joining the tailnet (use reusable, tagged key) | `string` | `""` | no |
| <a name="input_tailscale_tailnet"></a> [tailscale\_tailnet](#input\_tailscale\_tailnet) | Tailscale tailnet name for MagicDNS hostnames (e.g., 'example-org' for example-org.ts.net). Leave empty to skip MagicDNS hostname generation. | `string` | `""` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos Linux version (e.g., v1.8.0) | `string` | `"v1.8.0"` | no |
| <a name="input_use_dhcp_for_physical_interface"></a> [use\_dhcp\_for\_physical\_interface](#input\_use\_dhcp\_for\_physical\_interface) | Use DHCP for physical network interface configuration | `bool` | `true` | no |
| <a name="input_wipe_install_disk"></a> [wipe\_install\_disk](#input\_wipe\_install\_disk) | Wipe the installation disk before installing Talos | `bool` | `false` | no |
| <a name="input_worker_nodes"></a> [worker\_nodes](#input\_worker\_nodes) | Map of worker nodes with their configuration (using Tailscale IPs) | <pre>map(object({<br/>    tailscale_ipv4 = string           # Tailscale IPv4 address (100.64.0.0/10 range)<br/>    tailscale_ipv6 = optional(string) # Tailscale IPv6 address (fd7a:115c:a1e0::/48 range)<br/>    physical_ip    = optional(string) # Physical IP (for initial bootstrapping only)<br/>    install_disk   = string<br/>    hostname       = optional(string)<br/>    interface      = optional(string, "tailscale0")<br/>    platform       = optional(string, "metal")                        # Platform type: metal, metal-arm64, metal-secureboot, aws, gcp, azure, etc.<br/>    extensions     = optional(list(string), ["siderolabs/tailscale"]) # Talos system extensions (default: Tailscale only)<br/>    # SBC overlay configuration (for Raspberry Pi, Rock Pi, etc.)<br/>    overlay = optional(object({<br/>      image = string # Overlay image (e.g., "siderolabs/sbc-raspberrypi")<br/>      name  = string # Overlay name (e.g., "rpi_generic", "rpi_5")<br/>    }))<br/>    # Kubernetes topology and node labels<br/>    region      = optional(string)          # topology.kubernetes.io/region<br/>    zone        = optional(string)          # topology.kubernetes.io/zone<br/>    arch        = optional(string)          # kubernetes.io/arch (e.g., amd64, arm64)<br/>    os          = optional(string)          # kubernetes.io/os (e.g., linux)<br/>    node_labels = optional(map(string), {}) # Additional node-specific labels<br/>    # OpenEBS Replicated Storage configuration<br/>    openebs_storage       = optional(bool, false)  # Enable OpenEBS storage on this node<br/>    openebs_disk          = optional(string)       # Storage disk device (e.g., /dev/nvme0n1, /dev/sdb)<br/>    openebs_hugepages_2mi = optional(number, 1024) # Number of 2MiB hugepages (1024 = 2GiB, required for Mayastor)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cilium_values_path"></a> [cilium\_values\_path](#output\_cilium\_values\_path) | Path to generated Cilium Helm values file (only when Cilium CNI is enabled) |
| <a name="output_client_configs"></a> [client\_configs](#output\_client\_configs) | Client configuration files for cluster access |
| <a name="output_client_configuration"></a> [client\_configuration](#output\_client\_configuration) | Talos client configuration for cluster management |
| <a name="output_cluster_info"></a> [cluster\_info](#output\_cluster\_info) | Cluster configuration summary |
| <a name="output_deployment_commands"></a> [deployment\_commands](#output\_deployment\_commands) | Makefile commands for cluster deployment |
| <a name="output_deployment_workflow"></a> [deployment\_workflow](#output\_deployment\_workflow) | Step-by-step deployment instructions |
| <a name="output_generated_configs"></a> [generated\_configs](#output\_generated\_configs) | Paths to all generated machine configuration files |
| <a name="output_installer_images"></a> [installer\_images](#output\_installer\_images) | Talos installer image URLs for each node |
| <a name="output_machine_secrets"></a> [machine\_secrets](#output\_machine\_secrets) | Talos machine secrets for cluster operations |
| <a name="output_node_summary"></a> [node\_summary](#output\_node\_summary) | Summary of cluster nodes |
| <a name="output_output_directory"></a> [output\_directory](#output\_output\_directory) | Directory containing all generated configuration files |
| <a name="output_schematic_ids"></a> [schematic\_ids](#output\_schematic\_ids) | Image factory schematic IDs for each unique extension combination |
| <a name="output_tailscale_config"></a> [tailscale\_config](#output\_tailscale\_config) | Tailscale network configuration |
| <a name="output_troubleshooting"></a> [troubleshooting](#output\_troubleshooting) | Common troubleshooting commands |
<!-- END_TF_DOCS -->
