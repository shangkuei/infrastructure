# Talos Shangkuei Lab Cluster - Outputs
#
# Expose outputs from the talos-cluster module.

# =============================================================================
# Generated Files
# =============================================================================

output "generated_configs" {
  description = "Paths to all generated machine configuration files"
  value       = module.talos_cluster.generated_configs
}

output "client_configs" {
  description = "Client configuration files for cluster access"
  value       = module.talos_cluster.client_configs
}

output "cilium_values_path" {
  description = "Path to generated Cilium Helm values file (only when Cilium CNI is enabled)"
  value       = module.talos_cluster.cilium_values_path
}

output "output_directory" {
  description = "Directory containing all generated configuration files"
  value       = module.talos_cluster.output_directory
}

# =============================================================================
# Cluster Information
# =============================================================================

output "cluster_info" {
  description = "Cluster configuration summary"
  value       = module.talos_cluster.cluster_info
}

output "node_summary" {
  description = "Summary of cluster nodes"
  value       = module.talos_cluster.node_summary
}

output "tailscale_config" {
  description = "Tailscale network configuration"
  value       = module.talos_cluster.tailscale_config
}

# =============================================================================
# Machine Secrets (Sensitive)
# =============================================================================

output "machine_secrets" {
  description = "Talos machine secrets for cluster operations"
  value       = module.talos_cluster.machine_secrets
  sensitive   = true
}

output "client_configuration" {
  description = "Talos client configuration for cluster management"
  value       = module.talos_cluster.client_configuration
  sensitive   = true
}

# =============================================================================
# Image Factory Information
# =============================================================================

output "installer_images" {
  description = "Talos installer image URLs for each node"
  value       = module.talos_cluster.installer_images
}

output "schematic_ids" {
  description = "Image factory schematic IDs for each unique extension combination"
  value       = module.talos_cluster.schematic_ids
}

# =============================================================================
# Troubleshooting Information
# =============================================================================

output "troubleshooting" {
  description = "Common troubleshooting commands"
  value       = module.talos_cluster.troubleshooting
}

# =============================================================================
# Deployment Commands
# =============================================================================

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
# Deployment Workflow
# =============================================================================

output "deployment_workflow" {
  description = "Step-by-step deployment instructions"
  value       = <<-EOT

    ╔════════════════════════════════════════════════════════════════╗
    ║  Talos Cluster Deployment Workflow - ${var.cluster_name}
    ╚════════════════════════════════════════════════════════════════╝

    Cluster Endpoint: ${module.talos_cluster.cluster_info.endpoint}
    Control Plane Nodes: ${module.talos_cluster.node_summary.control_plane_count}
    Worker Nodes: ${module.talos_cluster.node_summary.worker_count}

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

  EOT
}
