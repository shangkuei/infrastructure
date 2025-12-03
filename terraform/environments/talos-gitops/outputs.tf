output "flux_namespace" {
  description = "Namespace where Flux is installed"
  value       = module.talos_gitops.flux_namespace
}

output "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed"
  value       = module.talos_gitops.cert_manager_namespace
}

output "git_repository" {
  description = "Git repository URL used by Flux"
  value       = module.talos_gitops.git_repository
}

output "git_branch" {
  description = "Git branch tracked by Flux"
  value       = module.talos_gitops.git_branch
}

output "cluster_path" {
  description = "Path in repository where cluster manifests are stored"
  value       = module.talos_gitops.cluster_path
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = module.talos_gitops.cluster_name
}

output "component_versions" {
  description = "Versions of installed components"
  value       = module.talos_gitops.component_versions
}

output "verification_commands" {
  description = "Commands to verify the installation"
  value       = module.talos_gitops.verification_commands
}

output "flux_logs_commands" {
  description = "Commands to view Flux logs"
  value       = module.talos_gitops.flux_logs_commands
}

output "deployment_phase" {
  description = "Current deployment phase and next steps"
  value       = <<-EOT
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                   TALOS GITOPS DEPLOYMENT GUIDE                             ║
    ╚════════════════════════════════════════════════════════════════════════════╝

    This configuration deploys Flux CD on a Talos Kubernetes cluster.

    ══════════════════════════════════════════════════════════════════════════════
    Deployed Components
    ══════════════════════════════════════════════════════════════════════════════

    - cert-manager (namespace: ${module.talos_gitops.cert_manager_namespace})
    - Flux Operator (namespace: ${module.talos_gitops.flux_namespace})
    - FluxInstance + controllers (namespace: ${module.talos_gitops.flux_namespace})
    - SOPS age secret for encrypted manifest decryption

    ══════════════════════════════════════════════════════════════════════════════
    Verification Commands
    ══════════════════════════════════════════════════════════════════════════════

    # Check all components
    kubectl -n ${module.talos_gitops.cert_manager_namespace} get pods
    kubectl -n ${module.talos_gitops.flux_namespace} get pods

    # Check FluxInstance status
    kubectl -n ${module.talos_gitops.flux_namespace} get fluxinstance flux

    # Check Git sync
    kubectl -n ${module.talos_gitops.flux_namespace} get gitrepository
    kubectl -n ${module.talos_gitops.flux_namespace} get kustomization

    Full documentation: terraform/environments/talos-gitops/README.md
  EOT
}

output "next_steps" {
  description = "Next steps after complete installation"
  value       = <<-EOT
    After deployment is complete:

    1. Verify all components are running:
       kubectl -n ${module.talos_gitops.cert_manager_namespace} get pods
       kubectl -n ${module.talos_gitops.flux_namespace} get pods

    2. Check FluxInstance status:
       kubectl -n ${module.talos_gitops.flux_namespace} get fluxinstance flux -o jsonpath='{.status.conditions}' | jq

    3. Verify Git sync:
       kubectl -n ${module.talos_gitops.flux_namespace} get gitrepository
       kubectl -n ${module.talos_gitops.flux_namespace} get kustomization

    4. Add manifests to: ${module.talos_gitops.cluster_path}
       - Push to branch: ${module.talos_gitops.git_branch}
       - Flux will automatically reconcile

    5. Monitor reconciliation:
       kubectl -n ${module.talos_gitops.flux_namespace} get kustomization -w
  EOT
}
