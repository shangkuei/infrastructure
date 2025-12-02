# Talos Shangkuei Dev Cluster - Main Configuration
#
# This environment uses the talos-cluster module to generate Talos machine
# configurations for a development Kubernetes cluster with Tailscale networking.

module "talos_cluster" {
  source = "../../modules/talos-cluster"

  # Cluster configuration
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  output_path      = "${path.module}/generated"

  # Node configuration
  control_plane_nodes = var.control_plane_nodes
  worker_nodes        = var.worker_nodes

  # Tailscale configuration
  tailscale_tailnet  = var.tailscale_tailnet
  tailscale_auth_key = var.tailscale_auth_key

  # Version configuration
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  # Machine configuration
  use_dhcp_for_physical_interface = var.use_dhcp_for_physical_interface
  wipe_install_disk               = var.wipe_install_disk
  enable_kubeprism                = var.enable_kubeprism
  kubeprism_port                  = var.kubeprism_port

  # Network configuration
  pod_cidr           = var.pod_cidr
  service_cidr       = var.service_cidr
  dns_domain         = var.dns_domain
  cni_name           = var.cni_name
  cilium_helm_values = var.cilium_helm_values

  # Security configuration
  cert_sans = var.cert_sans

  # Configuration patches
  additional_control_plane_patches = var.additional_control_plane_patches
  additional_worker_patches        = var.additional_worker_patches
  node_labels                      = var.node_labels
  openebs_hostpath_enabled         = var.openebs_hostpath_enabled
}
