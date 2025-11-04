# Talos Cluster Environment - Outputs

# =============================================================================
# Generated Files
# =============================================================================

output "generated_configs" {
  description = "Paths to all generated machine configuration files"
  value = {
    control_plane = {
      for k, v in var.control_plane_nodes : k => {
        config              = abspath("${path.module}/generated/control-plane-${k}.yaml")
        patch               = abspath("${path.module}/generated/control-plane-${k}-patch.yaml")
        tailscale_extension = abspath("${path.module}/generated/control-plane-${k}-tailscale.yaml")
        tailscale_ipv4      = v.tailscale_ipv4
        tailscale_ipv6      = v.tailscale_ipv6
        physical_ip         = v.physical_ip
      }
    }
    worker = {
      for k, v in var.worker_nodes : k => {
        config              = abspath("${path.module}/generated/worker-${k}.yaml")
        patch               = abspath("${path.module}/generated/worker-${k}-patch.yaml")
        tailscale_extension = abspath("${path.module}/generated/worker-${k}-tailscale.yaml")
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
    talosconfig = abspath("${path.module}/generated/talosconfig")
  }
}

output "deployment_commands" {
  description = "Makefile commands for cluster deployment"
  value = {
    apply_configs     = "make apply-configs"
    bootstrap_cluster = "make bootstrap"
    check_health      = "make health"
    list_nodes        = "make nodes"
    list_pods         = "make pods"
    show_status       = "make status"
  }
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
    control_plane_ipv4 = { for k, v in var.control_plane_nodes : k => v.tailscale_ipv4 }
    control_plane_ipv6 = { for k, v in var.control_plane_nodes : k => v.tailscale_ipv6 if v.tailscale_ipv6 != null }
    worker_ipv4        = { for k, v in var.worker_nodes : k => v.tailscale_ipv4 }
    worker_ipv6        = { for k, v in var.worker_nodes : k => v.tailscale_ipv6 if v.tailscale_ipv6 != null }
  }
}

# =============================================================================
# Deployment Workflow
# =============================================================================

output "deployment_workflow" {
  description = "Step-by-step deployment instructions"
  value       = <<-EOT

    ╔════════════════════════════════════════════════════════════════╗
    ║  Talos Cluster Deployment Workflow - ${var.cluster_name}
    ╚════════════════════════════════════════════════════════════════╝

    Cluster Endpoint: ${local.cluster_endpoint}
    Control Plane Nodes: ${length(var.control_plane_nodes)}
    Worker Nodes: ${length(var.worker_nodes)}

    ┌────────────────────────────────────────────────────────────────┐
    │ Quick Start - Automated Deployment                             │
    └────────────────────────────────────────────────────────────────┘

      Run the complete workflow:
        $ make all

      This will:
        1. Initialize Terraform (make init)
        2. Generate configurations (make apply)
        3. Apply configs to nodes (make apply-configs)
        4. Bootstrap cluster (make bootstrap)
        5. Check cluster health (make health)

    ┌────────────────────────────────────────────────────────────────┐
    │ Step-by-Step Manual Deployment                                 │
    └────────────────────────────────────────────────────────────────┘

      STEP 1: Generate configurations
        $ make apply

      STEP 2: Apply configurations to all nodes (initial setup - insecure mode)
        $ make apply-configs INSECURE=true

      STEP 3: Wait for nodes to join Tailscale (~1-2 min)
        Check Tailscale admin console for node IPs

      STEP 4: Update terraform.tfvars with Tailscale IPs and regenerate
        $ make apply

      STEP 5: Reapply configurations (secure mode via Tailscale)
        $ make apply-configs

      STEP 6: Bootstrap Kubernetes cluster
        $ make bootstrap

      STEP 7: Verify cluster health
        $ make health
        $ make nodes
        $ make pods

    ┌────────────────────────────────────────────────────────────────┐
    │ Generated Configuration Files                                  │
    └────────────────────────────────────────────────────────────────┘

      Location: ${abspath("${path.module}/generated/")}

      Per-node machine configs (3 files each):
    %{~for k in keys(var.control_plane_nodes)}
        Control Plane ${k}:
          - control-plane-${k}.yaml          (base config)
          - control-plane-${k}-patch.yaml    (node-specific patch)
          - control-plane-${k}-tailscale.yaml (Tailscale extension)
    %{~endfor}
    %{~for k in keys(var.worker_nodes)}
        Worker ${k}:
          - worker-${k}.yaml                 (base config)
          - worker-${k}-patch.yaml           (node-specific patch)
          - worker-${k}-tailscale.yaml       (Tailscale extension)
    %{~endfor}

      Client configurations:
        - talosconfig   (for talosctl)
        - kubeconfig    (for kubectl, generated after bootstrap)

    ╔════════════════════════════════════════════════════════════════╗
    ║  Useful Make Commands                                          ║
    ╚════════════════════════════════════════════════════════════════╝

      Deployment:
        make workflow                    Show detailed workflow
        make all                         Complete automated deployment
        make apply-configs INSECURE=true Initial config (before certs)
        make apply-configs               Update config (secure mode)
        make apply-configs NODE=<name>   Apply to single node
        make bootstrap                   Bootstrap Kubernetes cluster

      Cluster Status:
        make health            Check cluster health
        make nodes             List cluster nodes
        make pods              List all pods
        make status            Show complete status

      Cluster Access:
        make env               Show environment exports
        make dashboard NODE=<ip>    Open Talos dashboard
        make logs NODE=<ip> SERVICE=<name>  View service logs

      Maintenance:
        make upgrade-k8s VERSION=v1.32.0    Upgrade Kubernetes
        make upgrade-talos VERSION=v1.9.0 NODE=<ip>  Upgrade Talos

      Cleanup:
        make clean             Remove generated files
        make destroy           Destroy configurations

    ╔════════════════════════════════════════════════════════════════╗
    ║  Documentation & Support                                       ║
    ╚════════════════════════════════════════════════════════════════╝

      - README: ${abspath("${path.module}/README.md")}
      - Make help: make help
      - Talos Docs: https://www.talos.dev/
      - Tailscale Docs: https://tailscale.com/kb/

  EOT
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
