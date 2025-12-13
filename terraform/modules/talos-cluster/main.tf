# Talos Cluster Module - Machine Configuration Generator
#
# This module generates Talos machine configurations for a Kubernetes cluster
# with Tailscale network integration. Configurations are saved as files for manual
# application to nodes.
#
# Workflow:
# 1. terraform apply → generates machine configs
# 2. Review generated configs in output_path/
# 3. Manually apply configs to nodes using talosctl
# 4. Bootstrap cluster and deploy Tailscale components

# =============================================================================
# Local Variables
# =============================================================================

locals {
  # Output path defaults to module path if not specified
  output_dir = var.output_path != "" ? var.output_path : "${path.module}/generated"
}

# =============================================================================
# Image Factory Schematic
# =============================================================================

# Generate custom Talos installer images with per-node extensions and overlays
# Create a map of unique extension+overlay combinations to avoid duplicate schematics
locals {
  # Collect all nodes with their extensions and overlay configuration
  # Note: Node keys from variables are used as-is (e.g., "cp-01", "worker-01")
  all_nodes_config = merge(
    {
      for k, v in var.control_plane_nodes : k => {
        extensions = v.extensions
        overlay    = v.overlay
      }
    },
    {
      for k, v in var.worker_nodes : k => {
        extensions = v.extensions
        overlay    = v.overlay
      }
    }
  )

  # Create unique schematic keys combining extensions and overlay
  # Format: "ext1,ext2|overlay_image:overlay_name" or "ext1,ext2|" if no overlay
  node_to_schematic_key = {
    for node_key, config in local.all_nodes_config :
    node_key => format("%s|%s",
      join(",", sort(config.extensions)),
      config.overlay != null ? "${config.overlay.image}:${config.overlay.name}" : ""
    )
  }

  # Create unique schematic configurations
  unique_schematic_configs = {
    for key in toset(values(local.node_to_schematic_key)) :
    key => {
      extensions = split(",", split("|", key)[0])
      overlay = split("|", key)[1] != "" ? {
        image = split(":", split("|", key)[1])[0]
        name  = split(":", split("|", key)[1])[1]
      } : null
    }
  }
}

# Generate schematics for each unique extension+overlay combination
resource "talos_image_factory_schematic" "nodes" {
  for_each = local.unique_schematic_configs

  schematic = yamlencode(merge(
    {
      customization = {
        systemExtensions = {
          officialExtensions = each.value.extensions
        }
      }
    },
    each.value.overlay != null ? {
      overlay = {
        image = each.value.overlay.image
        name  = each.value.overlay.name
      }
    } : {}
  ))
}

# =============================================================================
# Machine Secrets Generation
# =============================================================================

# Generate cluster-wide secrets (certificates, tokens, etc.)
resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

# Generate Talos client configuration for cluster management
# Endpoints include all control plane IPs (IPv4/IPv6) and FQDNs (MagicDNS hostnames)
# This allows talosctl to connect via any available control plane endpoint
data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints = compact(concat(
    # Control plane Tailscale IPv4 addresses
    [for node in var.control_plane_nodes : node.tailscale_ipv4],
    # Control plane Tailscale IPv6 addresses (if configured)
    [for node in var.control_plane_nodes : node.tailscale_ipv6 if node.tailscale_ipv6 != null],
    # Control plane MagicDNS hostnames (FQDNs)
    var.tailscale_tailnet != "" ? [
      for node in var.control_plane_nodes :
      "${node.hostname}.${var.tailscale_tailnet}.ts.net"
      if node.hostname != null
    ] : []
  ))
}

# =============================================================================
# Local Configuration
# =============================================================================

locals {
  # Cluster endpoint selection priority:
  # 1. Use user-provided endpoint if specified
  # 2. If KubePrism enabled: use localhost KubePrism load balancer (requires component on every node)
  # 3. Fallback: use localhost direct API server (works on control plane nodes, simple single-node clusters)
  cluster_endpoint = var.cluster_endpoint != "" ? var.cluster_endpoint : (
    var.enable_kubeprism
    ? "https://127.0.0.1:${var.kubeprism_port}"
    : "https://127.0.0.1:6443"
  )

  # Build cert SANs list - Tailscale-only for simplified certificate management
  # All cluster communication happens via Tailscale mesh network

  # Conditionally determine which nodes to include in cert SANs
  # When KubePrism is enabled, include all nodes (control plane + workers) since
  # KubePrism runs on every node and provides local load balancing to all control plane nodes
  # When disabled, only control plane nodes need to be in the certificate
  cert_nodes = var.enable_kubeprism ? merge(var.control_plane_nodes, var.worker_nodes) : var.control_plane_nodes

  # Collect both IPv4 and IPv6 addresses from nodes
  # Filter out placeholder values like "auto-assigned" and null values
  tailscale_ipv4_list = compact([
    for node in local.cert_nodes :
    node.tailscale_ipv4 != null && node.tailscale_ipv4 != "auto-assigned" ? node.tailscale_ipv4 : ""
  ])
  tailscale_ipv6_list = compact([
    for node in local.cert_nodes :
    node.tailscale_ipv6 != null ? node.tailscale_ipv6 : ""
  ])
  tailscale_ips = concat(local.tailscale_ipv4_list, local.tailscale_ipv6_list)

  # Build Tailscale MagicDNS hostnames
  # Format: <hostname>.<tailnet-name>.ts.net
  # Only include hostnames if both tailnet and node hostname are provided
  tailscale_hostnames = var.tailscale_tailnet != "" ? [
    for node in local.cert_nodes :
    "${node.hostname}.${var.tailscale_tailnet}.ts.net"
    if node.hostname != null
  ] : []

  # Certificate SANs include:
  # - Tailscale IPs (individual control plane nodes, both IPv4 and IPv6)
  # - MagicDNS hostnames (convenient hostname access)
  # - localhost (for KubePrism local load balancer)
  # Physical IPs are NOT included - they're only used during initial bootstrap
  cert_sans = concat(
    var.cert_sans,
    local.tailscale_ips,
    local.tailscale_hostnames,
    ["127.0.0.1", "::1", "localhost"]
  )

  # Check if Cilium Helm values contain bpf.masquerade = true
  cilium_bpf_masquerade = try(
    lookup(var.cilium_helm_values, "bpf", {}).masquerade,
    false
  )

  # Check if Cilium is replacing kube-proxy
  # kubeProxyReplacement can be "true", "strict", "probe", or "false"
  # We consider it enabled for "true", "strict", or "probe"
  cilium_kube_proxy_replacement = try(
    contains(["true", "strict", "probe"], lower(tostring(var.cilium_helm_values.kubeProxyReplacement))),
    false
  )

  # Check if Cilium Gateway API is enabled
  cilium_gateway_api_enabled = try(
    lookup(var.cilium_helm_values, "gatewayAPI", {}).enabled,
    false
  )

  # Gateway API CRD URLs (standard CRDs from kubernetes-sigs/gateway-api)
  gateway_api_version = "v1.4.0"
  gateway_api_crds = [
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_gateways.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_version}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml"
  ]

  # Common cluster configuration patches
  base_cluster_config = yamlencode({
    machine = {
      features = {
        hostDNS = {
          enabled = true
          # Default DNS forwarding behavior (enabled for most CNIs)
          # NOTE: This will be overridden by cilium_cluster_config when Cilium uses BPF masquerading
          forwardKubeDNSToHost = true
          resolveMemberNames   = true
        }
      }
    }

    cluster = {
      network = {
        # Default CNI configuration (Flannel)
        # NOTE: This will be overridden by cilium_cluster_config when var.cni_name == "cilium"
        cni = {
          name = "flannel"
        }
        dnsDomain      = var.dns_domain
        podSubnets     = [var.pod_cidr]
        serviceSubnets = [var.service_cidr]
      }
      apiServer = {
        certSANs = local.cert_sans
      }
    }
  })

  # Cilium-specific cluster configuration patch
  # - Sets CNI to "none" (Cilium installed via Helm)
  # - Conditionally disables kube-proxy when Cilium replaces it
  # - Conditionally disables forwardKubeDNSToHost when Cilium uses BPF masquerading
  # - Conditionally includes Gateway API CRDs when Gateway API is enabled
  # NOTE: Deep merge required - merge() only does shallow merge, so we merge at appropriate levels
  cilium_cluster_config = yamlencode(merge(
    {
      # Machine-level configuration (DNS forwarding)
      machine = merge(
        {},
        # Only disable DNS forwarding if Cilium uses BPF masquerading
        local.cilium_bpf_masquerade ? {
          features = {
            hostDNS = {
              forwardKubeDNSToHost = false
            }
          }
        } : {}
      )
    },
    {
      # Cluster-level configuration (CNI, proxy, manifests)
      cluster = merge(
        {
          # Override CNI from flannel to none for Cilium
          network = {
            cni = {
              name = "none"
            }
          }
        },
        # Only disable kube-proxy if Cilium is replacing it
        local.cilium_kube_proxy_replacement ? {
          proxy = {
            disabled = true
          }
        } : {},
        # Include Gateway API CRDs when Gateway API is enabled
        local.cilium_gateway_api_enabled ? {
          extraManifests = local.gateway_api_crds
        } : {}
      )
    }
  ))

  # Platform-specific installer image URLs using image factory
  # Image factory URL format: factory.talos.dev/<installer-type>/<schematic-id>:<talos-version>
  # Different platforms use different installer types:
  #   - metal, metal-arm64 → installer
  #   - metal-secureboot → metal-installer-secureboot
  #   - aws, azure, gcp, etc. → installer

  # Map platform to installer type
  platform_installer_types = {
    "metal"            = "metal-installer"
    "metal-secureboot" = "metal-installer-secureboot"
  }

  # Generate per-node installer URLs using node-specific schematics
  # Control plane installer URLs
  cp_installer_image_urls = {
    for k, v in var.control_plane_nodes :
    k => "factory.talos.dev/${lookup(local.platform_installer_types, coalesce(v.platform, "metal"), "installer")}/${talos_image_factory_schematic.nodes[local.node_to_schematic_key[k]].id}:${var.talos_version}"
  }

  # Worker installer URLs
  worker_installer_image_urls = {
    for k, v in var.worker_nodes :
    k => "factory.talos.dev/${lookup(local.platform_installer_types, coalesce(v.platform, "metal"), "installer")}/${talos_image_factory_schematic.nodes[local.node_to_schematic_key[k]].id}:${var.talos_version}"
  }

  # Tailscale-specific machine patches
  tailscale_machine_patch = yamlencode({
    machine = {
      # Network configuration for Tailscale MagicDNS
      network = {
        nameservers = [
          "100.100.100.100",
          "8.8.8.8", "8.8.4.4",
          "1.1.1.1", "1.0.0.1",
        ]
        searchDomains = var.tailscale_tailnet != "" ? ["${var.tailscale_tailnet}.ts.net", ] : []
      }
      # Kernel modules for Tailscale
      kernel = {
        modules = [
          {
            name = "tun"
          }
        ]
      }
    }
  })

  # KubePrism configuration patch
  # KubePrism provides local load balancer that proxies to all control plane nodes
  kubeprism_patch = yamlencode({
    machine = {
      features = {
        kubePrism = {
          enabled = var.enable_kubeprism
          port    = var.kubeprism_port
        }
      }

      # Node labels
      nodeLabels = merge(
        var.node_labels,
        {
          "feature.talos.dev/kubeprism" = var.enable_kubeprism ? "enabled" : "disabled"
        }
      )
    }
  })

  # OpenEBS LocalPV Hostpath configuration patch
  # - Adds Pod Security exemptions for openebs namespace (allows privileged operations)
  # - Configures kubelet extraMounts for hostpath storage
  openebs_hostpath_patch = yamlencode({
    machine = {
      kubelet = {
        extraMounts = [
          {
            destination = "/var/openebs/local"
            type        = "bind"
            source      = "/var/openebs/local"
            options = [
              "bind",
              "rshared",
              "rw"
            ]
          }
        ]
      }
    }
  })

  # OpenEBS ZFS LocalPV configuration patch
  # - Adds kubelet extraMounts for ZFS encryption keys directory (Talos-compatible path)
  openebs_zfs_patch = yamlencode({
    machine = {
      kubelet = {
        extraMounts = [
          {
            destination = "/var/openebs/encr-keys"
            type        = "bind"
            source      = "/var/openebs/encr-keys"
            options = [
              "bind",
              "rshared",
              "rw"
            ]
          }
        ]
      }
    }
  })

  # Check if any worker nodes have ZFS pool configuration
  openebs_zfs_enabled = anytrue([for k, v in var.worker_nodes : length(v.zfs_pools) > 0])
}

# =============================================================================
# Control Plane Machine Configurations
# =============================================================================

# Generate base control plane configuration
data "talos_machine_configuration" "control_plane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  docs     = false
  examples = false

  config_patches = concat(
    [local.base_cluster_config],
    var.cni_name == "cilium" ? [local.cilium_cluster_config] : [],
    [local.tailscale_machine_patch],
    [local.kubeprism_patch],
    var.additional_control_plane_patches
  )
}

# Generate individual control plane node configs
resource "local_file" "control_plane_config" {
  for_each = var.control_plane_nodes

  filename = "${local.output_dir}/control-plane-${each.key}.yaml"
  content  = data.talos_machine_configuration.control_plane.machine_configuration

  file_permission = "0600"
}

# Generate per-node patches (hostname, IP, disk, labels, extension-specific kernel modules)
resource "local_file" "control_plane_patches" {
  for_each = var.control_plane_nodes

  filename = "${local.output_dir}/control-plane-${each.key}-patch.yaml"
  content = yamlencode({
    machine = merge(
      {
        network = {
          hostname = coalesce(each.value.hostname, each.key)
          interfaces = [{
            interface = each.value.interface
            dhcp      = var.use_dhcp_for_physical_interface
          }]
        }
        install = {
          disk  = each.value.install_disk
          wipe  = var.wipe_install_disk
          image = local.cp_installer_image_urls[each.key]
        }
        nodeLabels = merge(
          # Topology labels
          each.value.region != null ? { "topology.kubernetes.io/region" = each.value.region } : {},
          each.value.zone != null ? { "topology.kubernetes.io/zone" = each.value.zone } : {},
          # Standard Kubernetes labels
          each.value.hostname != null ? { "kubernetes.io/hostname" = each.value.hostname } : {},
          each.value.arch != null ? { "kubernetes.io/arch" = each.value.arch } : {},
          each.value.os != null ? { "kubernetes.io/os" = each.value.os } : {},
          # Additional node-specific labels
          each.value.node_labels
        )
      },
      # ZFS kernel module (required when siderolabs/zfs extension is used)
      contains(each.value.extensions, "siderolabs/zfs") ? {
        kernel = {
          modules = [{ name = "zfs" }]
        }
      } : {}
    )
  })

  file_permission = "0600"
}

# Generate per-node Tailscale extension configuration (separate document)
resource "local_file" "control_plane_tailscale_extension" {
  for_each = var.control_plane_nodes

  filename = "${local.output_dir}/control-plane-${each.key}-tailscale.yaml"
  content = yamlencode({
    apiVersion = "v1alpha1"
    kind       = "ExtensionServiceConfig"
    name       = "tailscale"
    environment = [
      "TS_AUTHKEY=${var.tailscale_auth_key}",
      "TS_HOSTNAME=${coalesce(each.value.hostname, each.key)}"
    ]
  })

  file_permission = "0600"
}

# =============================================================================
# Worker Machine Configurations
# =============================================================================

# Generate base worker configuration
data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  docs     = false
  examples = false

  config_patches = concat(
    [local.base_cluster_config],
    var.cni_name == "cilium" ? [local.cilium_cluster_config] : [],
    [local.tailscale_machine_patch],
    [local.kubeprism_patch],
    var.openebs_hostpath_enabled ? [local.openebs_hostpath_patch] : [],
    local.openebs_zfs_enabled ? [local.openebs_zfs_patch] : [],
    var.additional_worker_patches
  )
}

# Generate individual worker node configs
resource "local_file" "worker_config" {
  for_each = var.worker_nodes

  filename = "${local.output_dir}/worker-${each.key}.yaml"
  content  = data.talos_machine_configuration.worker.machine_configuration

  file_permission = "0600"
}

# Generate per-node patches (hostname, IP, disk, labels, extension-specific kernel modules)
resource "local_file" "worker_patches" {
  for_each = var.worker_nodes

  filename = "${local.output_dir}/worker-${each.key}-patch.yaml"
  content = yamlencode({
    machine = merge(
      {
        network = {
          hostname = coalesce(each.value.hostname, each.key)
          interfaces = [{
            interface = each.value.interface
            dhcp      = var.use_dhcp_for_physical_interface
          }]
        }
        install = {
          disk  = each.value.install_disk
          wipe  = var.wipe_install_disk
          image = local.worker_installer_image_urls[each.key]
        }
        nodeLabels = merge(
          # Topology labels
          each.value.region != null ? { "topology.kubernetes.io/region" = each.value.region } : {},
          each.value.zone != null ? { "topology.kubernetes.io/zone" = each.value.zone } : {},
          # Standard Kubernetes labels
          each.value.hostname != null ? { "kubernetes.io/hostname" = each.value.hostname } : {},
          each.value.arch != null ? { "kubernetes.io/arch" = each.value.arch } : {},
          each.value.os != null ? { "kubernetes.io/os" = each.value.os } : {},
          # OpenEBS storage node labels (when enabled)
          each.value.openebs_storage ? {
            "openebs.io/engine"       = "mayastor"
            "openebs.io/storage-node" = "true"
          } : {},
          # Additional node-specific labels
          each.value.node_labels
        )
      },
      # ZFS kernel module (required when siderolabs/zfs extension is used)
      contains(each.value.extensions, "siderolabs/zfs") ? {
        kernel = {
          modules = [{ name = "zfs" }]
        }
      } : {},
      # OpenEBS hugepages configuration (when storage enabled)
      each.value.openebs_storage ? {
        sysctls = {
          "vm.nr_hugepages" = tostring(each.value.openebs_hugepages_2mi)
        }
      } : {},
      # OpenEBS disk configuration (when storage enabled and disk specified)
      each.value.openebs_storage && each.value.openebs_disk != null ? {
        disks = [
          {
            device = each.value.openebs_disk
            partitions = [
              {
                size       = 0 # 0 means use all remaining space
                mountpoint = "/var/local/mayastor"
              }
            ]
          }
        ]
      } : {}
    )
  })

  file_permission = "0600"
}

# Generate per-node Tailscale extension configuration (separate document)
resource "local_file" "worker_tailscale_extension" {
  for_each = var.worker_nodes

  filename = "${local.output_dir}/worker-${each.key}-tailscale.yaml"
  content = yamlencode({
    apiVersion = "v1alpha1"
    kind       = "ExtensionServiceConfig"
    name       = "tailscale"
    environment = [
      "TS_AUTHKEY=${var.tailscale_auth_key}",
      "TS_HOSTNAME=${coalesce(each.value.hostname, each.key)}"
    ]
  })

  file_permission = "0600"
}

# Generate per-node ZFS pool setup scripts (only for workers with ZFS configuration)
# These scripts are meant to be run via talosctl after the node boots:
#   cat worker-<node>-zfs-pool-setup.sh | talosctl -n <node-ip> -e <endpoint> run -
resource "local_file" "worker_zfs_pool_setup" {
  for_each = {
    for k, v in var.worker_nodes : k => v
    if length(v.zfs_pools) > 0
  }

  filename = "${local.output_dir}/worker-${each.key}-zfs-pool-setup.sh"
  content = templatefile("${path.module}/templates/zfs-pool-setup.sh.tftpl", {
    pools     = each.value.zfs_pools
    node_name = coalesce(each.value.hostname, each.key)
  })

  file_permission = "0755"
}

# =============================================================================
# Client Configurations
# =============================================================================

# Save talosconfig for cluster management
resource "local_file" "talosconfig" {
  filename        = "${local.output_dir}/talosconfig"
  content         = data.talos_client_configuration.cluster.talos_config
  file_permission = "0600"
}

# =============================================================================
# Cilium CNI Configuration
# =============================================================================

# Generate Cilium Helm values file (only when Cilium is selected as CNI)
resource "local_file" "cilium_values" {
  count = var.cni_name == "cilium" ? 1 : 0

  filename        = "${local.output_dir}/cilium-values.yaml"
  content         = yamlencode(var.cilium_helm_values)
  file_permission = "0644"
}
