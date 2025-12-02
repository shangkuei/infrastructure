# Talos Cluster Module - Outputs

# =============================================================================
# Generated Files
# =============================================================================

output "generated_configs" {
  description = "Paths to all generated machine configuration files"
  value = {
    control_plane = {
      for k, v in var.control_plane_nodes : k => {
        config              = abspath("${local.output_dir}/control-plane-${k}.yaml")
        patch               = abspath("${local.output_dir}/control-plane-${k}-patch.yaml")
        tailscale_extension = abspath("${local.output_dir}/control-plane-${k}-tailscale.yaml")
        tailscale_ipv4      = v.tailscale_ipv4
        tailscale_ipv6      = v.tailscale_ipv6
        physical_ip         = v.physical_ip
      }
    }
    worker = {
      for k, v in var.worker_nodes : k => {
        config              = abspath("${local.output_dir}/worker-${k}.yaml")
        patch               = abspath("${local.output_dir}/worker-${k}-patch.yaml")
        tailscale_extension = abspath("${local.output_dir}/worker-${k}-tailscale.yaml")
        tailscale_ipv4      = v.tailscale_ipv4
        tailscale_ipv6      = v.tailscale_ipv6
        physical_ip         = v.physical_ip
      }
    }
  }
}

output "client_configs" {
  description = "Client configuration files for cluster access"
  value = {
    talosconfig = abspath("${local.output_dir}/talosconfig")
  }
}

output "cilium_values_path" {
  description = "Path to generated Cilium Helm values file (only when Cilium CNI is enabled)"
  value       = var.cni_name == "cilium" ? abspath("${local.output_dir}/cilium-values.yaml") : null
}

output "output_directory" {
  description = "Directory containing all generated configuration files"
  value       = abspath(local.output_dir)
}

# =============================================================================
# Cluster Information
# =============================================================================

output "cluster_info" {
  description = "Cluster configuration summary"
  value = {
    name               = var.cluster_name
    endpoint           = local.cluster_endpoint
    talos_version      = var.talos_version
    kubernetes_version = var.kubernetes_version
    cni                = var.cni_name
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    kubeprism_enabled  = var.enable_kubeprism
    kubeprism_port     = var.kubeprism_port
  }
}

output "node_summary" {
  description = "Summary of cluster nodes"
  value = {
    control_plane_count          = length(var.control_plane_nodes)
    worker_count                 = length(var.worker_nodes)
    total_nodes                  = length(var.control_plane_nodes) + length(var.worker_nodes)
    control_plane_tailscale_ipv4 = [for n in var.control_plane_nodes : n.tailscale_ipv4]
    control_plane_tailscale_ipv6 = [for n in var.control_plane_nodes : n.tailscale_ipv6 if n.tailscale_ipv6 != null]
    worker_tailscale_ipv4        = [for n in var.worker_nodes : n.tailscale_ipv4]
    worker_tailscale_ipv6        = [for n in var.worker_nodes : n.tailscale_ipv6 if n.tailscale_ipv6 != null]
  }
}

output "tailscale_config" {
  description = "Tailscale network configuration"
  value = {
    tailnet            = var.tailscale_tailnet
    control_plane_ipv4 = { for k, v in var.control_plane_nodes : k => v.tailscale_ipv4 }
    control_plane_ipv6 = { for k, v in var.control_plane_nodes : k => v.tailscale_ipv6 if v.tailscale_ipv6 != null }
    worker_ipv4        = { for k, v in var.worker_nodes : k => v.tailscale_ipv4 }
    worker_ipv6        = { for k, v in var.worker_nodes : k => v.tailscale_ipv6 if v.tailscale_ipv6 != null }
  }
}

# =============================================================================
# Machine Secrets (Sensitive)
# =============================================================================

output "machine_secrets" {
  description = "Talos machine secrets for cluster operations"
  value       = talos_machine_secrets.cluster.machine_secrets
  sensitive   = true
}

output "client_configuration" {
  description = "Talos client configuration for cluster management"
  value       = talos_machine_secrets.cluster.client_configuration
  sensitive   = true
}

# =============================================================================
# Image Factory Information
# =============================================================================

output "installer_images" {
  description = "Talos installer image URLs for each node"
  value = {
    control_plane = local.cp_installer_image_urls
    worker        = local.worker_installer_image_urls
  }
}

output "schematic_ids" {
  description = "Image factory schematic IDs for each unique extension+overlay combination"
  value = {
    for key, config in local.unique_schematic_configs :
    key => talos_image_factory_schematic.nodes[key].id
  }
}

# =============================================================================
# Troubleshooting Information
# =============================================================================

output "troubleshooting" {
  description = "Common troubleshooting commands"
  value = {
    check_node_status = "talosctl -n <node-ip> services"
    view_logs         = "talosctl -n <node-ip> logs <service>"
    reset_node        = "talosctl -n <node-ip> reset --graceful"
    dashboard         = "talosctl -n <node-ip> dashboard"
  }
}
