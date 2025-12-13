# Talos Cluster Module

Terraform module for generating Talos Linux machine configurations for Kubernetes clusters with Tailscale network integration.

## Overview

This module generates Talos machine configurations for deploying Kubernetes clusters with:

- **Tailscale Integration**: All cluster communication via Tailscale mesh network
- **Per-Node Extensions**: Custom Talos system extensions per node via Image Factory
- **SBC Overlay Support**: Hardware overlays for Raspberry Pi, Rock Pi, and other SBCs
- **KubePrism Support**: Local load balancer for high-availability API access
- **CNI Flexibility**: Support for Flannel, Cilium, Calico, or none
- **OpenEBS Support**: Optional OpenEBS LocalPV and Mayastor storage configuration

## Usage

```hcl
module "talos_cluster" {
  source = "../../modules/talos-cluster"

  cluster_name = "my-cluster"

  # Node configuration
  control_plane_nodes = {
    cp-01 = {
      tailscale_ipv4 = "100.64.0.10"
      install_disk   = "/dev/sda"
      hostname       = "cp-01"
    }
  }

  worker_nodes = {
    worker-01 = {
      tailscale_ipv4 = "100.64.0.20"
      install_disk   = "/dev/sda"
      hostname       = "worker-01"
    }
  }

  # Tailscale configuration
  tailscale_tailnet  = "example-org"
  tailscale_auth_key = var.tailscale_auth_key

  # Version configuration
  talos_version      = "v1.8.0"
  kubernetes_version = "v1.31.0"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| talos | >= 0.7.0 |
| local | >= 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| talos | >= 0.7.0 |
| local | >= 2.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the Kubernetes cluster | `string` | n/a | yes |
| control_plane_nodes | Map of control plane nodes with their configuration | `map(object)` | n/a | yes |
| cluster_endpoint | Kubernetes API endpoint | `string` | `""` | no |
| output_path | Base path for generated configuration files | `string` | `""` | no |
| worker_nodes | Map of worker nodes with their configuration | `map(object)` | `{}` | no |
| tailscale_tailnet | Tailscale tailnet name for MagicDNS | `string` | `""` | no |
| tailscale_auth_key | Tailscale authentication key | `string` | `""` | no |
| talos_version | Talos Linux version | `string` | `"v1.8.0"` | no |
| kubernetes_version | Kubernetes version | `string` | `"v1.31.0"` | no |
| cni_name | CNI plugin name | `string` | `"flannel"` | no |
| cilium_helm_values | Helm values for Cilium CNI | `any` | See variables.tf | no |
| enable_kubeprism | Enable KubePrism for HA API access | `bool` | `true` | no |
| kubeprism_port | Port for KubePrism load balancer | `number` | `7445` | no |
| pod_cidr | Pod network CIDR block | `string` | `"10.244.0.0/16"` | no |
| service_cidr | Service network CIDR block | `string` | `"10.96.0.0/12"` | no |
| dns_domain | Kubernetes DNS domain | `string` | `"cluster.local"` | no |
| cert_sans | Additional SANs for API server certificate | `list(string)` | `[]` | no |
| node_labels | Additional node labels for all nodes | `map(string)` | `{}` | no |
| additional_control_plane_patches | Additional YAML patches for control plane | `list(string)` | `[]` | no |
| additional_worker_patches | Additional YAML patches for workers | `list(string)` | `[]` | no |
| use_dhcp_for_physical_interface | Use DHCP for physical interface | `bool` | `true` | no |
| wipe_install_disk | Wipe install disk before installing | `bool` | `false` | no |
| openebs_hostpath_enabled | Enable OpenEBS LocalPV Hostpath support | `bool` | `false` | no |

### Node Configuration Object

```hcl
{
  tailscale_ipv4 = string           # Tailscale IPv4 address (required)
  tailscale_ipv6 = optional(string) # Tailscale IPv6 address
  physical_ip    = optional(string) # Physical IP for bootstrapping
  install_disk   = string           # Disk for Talos installation (required)
  hostname       = optional(string) # Node hostname
  interface      = optional(string) # Network interface (default: tailscale0)
  platform       = optional(string) # Platform type (default: metal)
  extensions     = optional(list)   # Talos extensions (default: [tailscale])
  overlay        = optional(object) # SBC overlay configuration (see below)
  region         = optional(string) # topology.kubernetes.io/region
  zone           = optional(string) # topology.kubernetes.io/zone
  arch           = optional(string) # kubernetes.io/arch
  os             = optional(string) # kubernetes.io/os
  node_labels    = optional(map)    # Additional node labels

  # Worker nodes only:
  openebs_storage       = optional(bool)   # Enable OpenEBS storage
  openebs_disk          = optional(string) # OpenEBS storage disk
  openebs_hugepages_2mi = optional(number) # Hugepages for Mayastor
}
```

## Outputs

| Name | Description |
|------|-------------|
| generated_configs | Paths to all generated machine configuration files |
| client_configs | Client configuration files for cluster access |
| cilium_values_path | Path to Cilium Helm values file |
| output_directory | Directory containing all generated files |
| cluster_info | Cluster configuration summary |
| node_summary | Summary of cluster nodes |
| tailscale_config | Tailscale network configuration |
| machine_secrets | Talos machine secrets (sensitive) |
| client_configuration | Talos client configuration (sensitive) |
| installer_images | Talos installer image URLs for each node |
| schematic_ids | Image factory schematic IDs |
| troubleshooting | Common troubleshooting commands |

### SBC Overlay Configuration

For single-board computers (Raspberry Pi, Rock Pi, etc.), use the `overlay` object:

```hcl
overlay = {
  image = "siderolabs/sbc-raspberrypi"  # Overlay image
  name  = "rpi_generic"                  # Overlay name
}
```

**Example - Raspberry Pi 5 worker node:**

```hcl
worker_nodes = {
  rpi5-worker = {
    tailscale_ipv4 = "100.64.0.30"
    install_disk   = "/dev/mmcblk0"
    hostname       = "rpi5-worker"
    arch           = "arm64"
    overlay = {
      image = "siderolabs/sbc-raspberrypi"
      name  = "rpi_5"
    }
  }
}
```

**Available Overlays:**

| SBC | Overlay Image | Overlay Name |
|-----|---------------|--------------|
| Raspberry Pi 4 | `siderolabs/sbc-raspberrypi` | `rpi_4` |
| Raspberry Pi 5 | `siderolabs/sbc-raspberrypi` | `rpi_5` |
| Raspberry Pi Generic | `siderolabs/sbc-raspberrypi` | `rpi_generic` |
| Rock Pi 4 | `siderolabs/sbc-rockchip` | `rock4c-plus` |
| Orange Pi 5 | `siderolabs/sbc-rockchip` | `orangepi-5` |

See [Talos Image Factory](https://factory.talos.dev/) for a complete list of available overlays.

## Generated Files

The module generates the following files in the output directory:

```
generated/
├── control-plane-{name}.yaml          # Base control plane config
├── control-plane-{name}-patch.yaml    # Node-specific patches
├── control-plane-{name}-tailscale.yaml # Tailscale extension config
├── worker-{name}.yaml                 # Base worker config
├── worker-{name}-patch.yaml           # Node-specific patches
├── worker-{name}-tailscale.yaml       # Tailscale extension config
├── talosconfig                        # Talos client configuration
└── cilium-values.yaml                 # Cilium Helm values (if CNI=cilium)
```

## Deployment Workflow

1. **Generate configurations**: `terraform apply`
2. **Apply configs to nodes** (initial - insecure mode):

   ```bash
   talosctl apply-config --insecure -n <physical-ip> \
     -f generated/control-plane-cp-01.yaml \
     -f generated/control-plane-cp-01-patch.yaml \
     -f generated/control-plane-cp-01-tailscale.yaml
   ```

3. **Wait for nodes to join Tailscale** (~1-2 min)
4. **Bootstrap cluster**:

   ```bash
   talosctl --talosconfig=generated/talosconfig bootstrap -n <tailscale-ip>
   ```

5. **Verify cluster health**:

   ```bash
   talosctl --talosconfig=generated/talosconfig health -n <tailscale-ip>
   ```

## CNI Configuration

### Flannel (Default)

Flannel is configured by default with standard settings.

### Cilium

To use Cilium CNI with kube-proxy replacement:

```hcl
cni_name = "cilium"

cilium_helm_values = {
  operator = {
    replicas = 1
  }
  kubeProxyReplacement = "true"
  k8sServiceHost       = "localhost"
  k8sServicePort       = 7445  # KubePrism port
  gatewayAPI = {
    enabled = true
  }
}
```

## License

See repository LICENSE file.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | >= 0.7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | 2.6.1 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [local_file.cilium_values](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.control_plane_config](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.control_plane_patches](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.control_plane_tailscale_extension](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.talosconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.worker_config](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.worker_patches](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.worker_tailscale_extension](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.worker_zfs_pool_setup](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [talos_image_factory_schematic.nodes](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/image_factory_schematic) | resource |
| [talos_machine_secrets.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets) | resource |
| [talos_client_configuration.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_machine_configuration.control_plane](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |
| [talos_machine_configuration.worker](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |

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
| <a name="input_output_path"></a> [output\_path](#input\_output\_path) | Base path for generated configuration files. If empty, uses module path. | `string` | `""` | no |
| <a name="input_pod_cidr"></a> [pod\_cidr](#input\_pod\_cidr) | Pod network CIDR block | `string` | `"10.244.0.0/16"` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | Service network CIDR block | `string` | `"10.96.0.0/12"` | no |
| <a name="input_tailscale_auth_key"></a> [tailscale\_auth\_key](#input\_tailscale\_auth\_key) | Tailscale authentication key for joining the tailnet (use reusable, tagged key) | `string` | `""` | no |
| <a name="input_tailscale_tailnet"></a> [tailscale\_tailnet](#input\_tailscale\_tailnet) | Tailscale tailnet name for MagicDNS hostnames (e.g., 'example-org' for example-org.ts.net). Leave empty to skip MagicDNS hostname generation. | `string` | `""` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos Linux version (e.g., v1.8.0) | `string` | `"v1.8.0"` | no |
| <a name="input_use_dhcp_for_physical_interface"></a> [use\_dhcp\_for\_physical\_interface](#input\_use\_dhcp\_for\_physical\_interface) | Use DHCP for physical network interface configuration | `bool` | `true` | no |
| <a name="input_wipe_install_disk"></a> [wipe\_install\_disk](#input\_wipe\_install\_disk) | Wipe the installation disk before installing Talos | `bool` | `false` | no |
| <a name="input_worker_nodes"></a> [worker\_nodes](#input\_worker\_nodes) | Map of worker nodes with their configuration (using Tailscale IPs) | <pre>map(object({<br/>    tailscale_ipv4 = string           # Tailscale IPv4 address (100.64.0.0/10 range)<br/>    tailscale_ipv6 = optional(string) # Tailscale IPv6 address (fd7a:115c:a1e0::/48 range)<br/>    physical_ip    = optional(string) # Physical IP (for initial bootstrapping only)<br/>    install_disk   = string<br/>    hostname       = optional(string)<br/>    interface      = optional(string, "tailscale0")<br/>    platform       = optional(string, "metal")                        # Platform type: metal, metal-arm64, metal-secureboot, aws, gcp, azure, etc.<br/>    extensions     = optional(list(string), ["siderolabs/tailscale"]) # Talos system extensions (default: Tailscale only)<br/>    # SBC overlay configuration (for Raspberry Pi, Rock Pi, etc.)<br/>    overlay = optional(object({<br/>      image = string # Overlay image (e.g., "siderolabs/sbc-raspberrypi")<br/>      name  = string # Overlay name (e.g., "rpi_generic", "rpi_5")<br/>    }))<br/>    # Kubernetes topology and node labels<br/>    region      = optional(string)          # topology.kubernetes.io/region<br/>    zone        = optional(string)          # topology.kubernetes.io/zone<br/>    arch        = optional(string)          # kubernetes.io/arch (e.g., amd64, arm64)<br/>    os          = optional(string)          # kubernetes.io/os (e.g., linux)<br/>    node_labels = optional(map(string), {}) # Additional node-specific labels<br/>    # OpenEBS Replicated Storage configuration<br/>    openebs_storage       = optional(bool, false)  # Enable OpenEBS storage on this node<br/>    openebs_disk          = optional(string)       # Storage disk device (e.g., /dev/nvme0n1, /dev/sdb)<br/>    openebs_hugepages_2mi = optional(number, 1024) # Number of 2MiB hugepages (1024 = 2GiB, required for Mayastor)<br/>    # OpenEBS ZFS LocalPV configuration - supports multiple pools per node<br/>    zfs_pools = optional(list(object({<br/>      name  = string               # Pool name (e.g., "zpool", "tank", "data")<br/>      disks = list(string)         # Disk devices (e.g., ["/dev/sdb"] or ["/dev/sdb", "/dev/sdc"])<br/>      type  = optional(string, "") # Pool type: "" (single/stripe), "mirror", "raidz", "raidz2", "raidz3"<br/>    })), [])<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cilium_values_path"></a> [cilium\_values\_path](#output\_cilium\_values\_path) | Path to generated Cilium Helm values file (only when Cilium CNI is enabled) |
| <a name="output_client_configs"></a> [client\_configs](#output\_client\_configs) | Client configuration files for cluster access |
| <a name="output_client_configuration"></a> [client\_configuration](#output\_client\_configuration) | Talos client configuration for cluster management |
| <a name="output_cluster_info"></a> [cluster\_info](#output\_cluster\_info) | Cluster configuration summary |
| <a name="output_generated_configs"></a> [generated\_configs](#output\_generated\_configs) | Paths to all generated machine configuration files |
| <a name="output_installer_images"></a> [installer\_images](#output\_installer\_images) | Talos installer image URLs for each node |
| <a name="output_machine_secrets"></a> [machine\_secrets](#output\_machine\_secrets) | Talos machine secrets for cluster operations |
| <a name="output_node_summary"></a> [node\_summary](#output\_node\_summary) | Summary of cluster nodes |
| <a name="output_output_directory"></a> [output\_directory](#output\_output\_directory) | Directory containing all generated configuration files |
| <a name="output_schematic_ids"></a> [schematic\_ids](#output\_schematic\_ids) | Image factory schematic IDs for each unique extension+overlay combination |
| <a name="output_tailscale_config"></a> [tailscale\_config](#output\_tailscale\_config) | Tailscale network configuration |
| <a name="output_troubleshooting"></a> [troubleshooting](#output\_troubleshooting) | Common troubleshooting commands |
<!-- END_TF_DOCS -->
