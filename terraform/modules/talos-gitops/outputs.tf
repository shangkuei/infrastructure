# ============================================================================
# Namespace Outputs
# ============================================================================

output "flux_namespace" {
  description = "Namespace where Flux is installed"
  value       = var.flux_namespace
}

output "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed"
  value       = kubernetes_namespace.cert_manager.metadata[0].name
}

# ============================================================================
# Git Configuration Outputs
# ============================================================================

output "git_repository" {
  description = "Git repository URL used by Flux"
  value       = "https://github.com/${var.github_owner}/${var.github_repository}"
}

output "git_branch" {
  description = "Git branch tracked by Flux"
  value       = var.github_branch
}

output "cluster_path" {
  description = "Path in repository where cluster manifests are stored"
  value       = var.cluster_path
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

# ============================================================================
# Component Version Outputs
# ============================================================================

output "component_versions" {
  description = "Versions of installed components"
  value = {
    cert_manager  = var.cert_manager_version
    flux_operator = var.flux_operator_version
    flux          = var.flux_version
  }
}

# ============================================================================
# Verification Commands
# ============================================================================

output "verification_commands" {
  description = "Commands to verify the installation"
  value       = <<-EOT
    # Check cert-manager installation
    kubectl -n ${kubernetes_namespace.cert_manager.metadata[0].name} get pods
    kubectl get crd | grep cert-manager

    # Check Flux Operator installation
    kubectl -n ${var.flux_namespace} get pods -l app.kubernetes.io/name=flux-operator
    kubectl get crd fluxinstances.fluxcd.controlplane.io

    # Check FluxInstance status
    kubectl -n ${var.flux_namespace} get fluxinstance flux -o yaml

    # Check Flux controllers (deployed by FluxInstance)
    kubectl -n ${var.flux_namespace} get pods
    kubectl -n ${var.flux_namespace} get gitrepository
    kubectl -n ${var.flux_namespace} get kustomization
  EOT
}

output "flux_logs_commands" {
  description = "Commands to view Flux logs"
  value       = <<-EOT
    # View all Flux controller logs
    kubectl -n ${var.flux_namespace} logs -l app.kubernetes.io/part-of=flux --tail=100 -f

    # View source-controller logs
    kubectl -n ${var.flux_namespace} logs -l app=source-controller --tail=100 -f

    # View kustomize-controller logs
    kubectl -n ${var.flux_namespace} logs -l app=kustomize-controller --tail=100 -f
  EOT
}
