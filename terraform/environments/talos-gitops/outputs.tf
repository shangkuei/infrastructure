output "flux_namespace" {
  description = "Namespace where Flux is installed"
  value       = var.flux_namespace
}

output "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed"
  value       = kubernetes_namespace.cert_manager.metadata[0].name
}

output "olm_namespace" {
  description = "Namespace where OLM is installed"
  value       = "olmv1-system"
}

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

output "component_versions" {
  description = "Versions of installed components"
  value = {
    cert_manager  = var.cert_manager_version
    olm           = var.olm_version
    flux_operator = var.flux_operator_version
    flux          = var.flux_version
  }
}

output "verification_commands" {
  description = "Commands to verify the installation"
  value       = <<-EOT
    # Check cert-manager installation
    kubectl -n ${kubernetes_namespace.cert_manager.metadata[0].name} get pods
    kubectl get crd | grep cert-manager

    # Check OLM installation
    kubectl -n olmv1-system get pods
    kubectl get crd | grep operator.operatorframework.io

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

output "deployment_phase" {
  description = "Current deployment phase and next steps"
  value       = <<-EOT
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                    PHASED DEPLOYMENT GUIDE                                  ║
    ╚════════════════════════════════════════════════════════════════════════════╝

    This configuration requires a multi-phase deployment due to CRD registration
    timing. Follow the phases below to complete the installation.

    ══════════════════════════════════════════════════════════════════════════════
    PHASE 1: Core Infrastructure (cert-manager + OLM v1) ✓ COMPLETED
    ══════════════════════════════════════════════════════════════════════════════

    The following components have been deployed:
    - cert-manager (namespace: ${kubernetes_namespace.cert_manager.metadata[0].name})
    - OLM v1 operator-controller (namespace: olmv1-system)
    - flux-system namespace
    - SOPS age secret
    - Git credentials secret
    - Flux Operator RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding)

    ┌─ Verification Commands ────────────────────────────────────────────────────┐
    │                                                                             │
    │  # Wait for cert-manager to be ready                                       │
    │  kubectl -n ${kubernetes_namespace.cert_manager.metadata[0].name} wait --for=condition=Available deployment/cert-manager --timeout=5m
    │  kubectl -n ${kubernetes_namespace.cert_manager.metadata[0].name} wait --for=condition=Available deployment/cert-manager-webhook --timeout=5m
    │                                                                             │
    │  # Wait for OLM v1 to be ready                                             │
    │  kubectl -n olmv1-system wait --for=condition=Available \
    │    deployment/operator-controller-controller-manager --timeout=5m          │
    │                                                                             │
    │  # Verify CRDs are registered                                              │
    │  kubectl get crd clustercatalogs.olm.operatorframework.io                  │
    │  kubectl get crd clusterextensions.olm.operatorframework.io                │
    │                                                                             │
    └─────────────────────────────────────────────────────────────────────────────┘

    ══════════════════════════════════════════════════════════════════════════════
    PHASE 2: Operator Catalog (ClusterCatalog) - NEXT STEP
    ══════════════════════════════════════════════════════════════════════════════

    Once Phase 1 verification is complete:

    1. Uncomment the ClusterCatalog resource in main.tf (lines ~146-165)
    2. Run: terraform apply
    3. Wait for catalog to be ready (see verification commands below)

    ┌─ Verification Commands ────────────────────────────────────────────────────┐
    │                                                                             │
    │  # Wait for catalog to be ready                                            │
    │  kubectl wait --for=condition=Serving clustercatalog/operatorhubio \
    │    --timeout=5m                                                             │
    │                                                                             │
    │  # Verify catalog is serving                                               │
    │  kubectl get clustercatalog operatorhubio -o \
    │    jsonpath='{.status.conditions[?(@.type=="Serving")].status}'            │
    │  # Should output: True                                                     │
    │                                                                             │
    │  # Check catalog details                                                   │
    │  kubectl get clustercatalog operatorhubio -o yaml                          │
    │                                                                             │
    └─────────────────────────────────────────────────────────────────────────────┘

    ══════════════════════════════════════════════════════════════════════════════
    PHASE 3: Flux Operator (ClusterExtension)
    ══════════════════════════════════════════════════════════════════════════════

    Once Phase 2 verification is complete:

    1. Uncomment the ClusterExtension resource in main.tf (lines ~228-264)
    2. Run: terraform apply
    3. Wait for operator installation (see verification commands below)

    ┌─ Verification Commands ────────────────────────────────────────────────────┐
    │                                                                             │
    │  # Wait for operator to be installed                                       │
    │  kubectl wait --for=condition=Installed clusterextension/flux-operator \
    │    --timeout=10m                                                            │
    │                                                                             │
    │  # Verify operator pods are running                                        │
    │  kubectl -n ${var.flux_namespace} get pods -l app.kubernetes.io/name=flux-operator
    │                                                                             │
    │  # Verify FluxInstance CRD is available                                    │
    │  kubectl get crd fluxinstances.fluxcd.controlplane.io                      │
    │                                                                             │
    └─────────────────────────────────────────────────────────────────────────────┘

    ══════════════════════════════════════════════════════════════════════════════
    PHASE 4: Flux Bootstrap (FluxInstance)
    ══════════════════════════════════════════════════════════════════════════════

    Once Phase 3 verification is complete:

    1. Uncomment the FluxInstance resource in main.tf (lines ~270-341)
    2. Run: terraform apply
    3. Wait for Flux controllers to be ready (see verification commands below)

    ┌─ Verification Commands ────────────────────────────────────────────────────┐
    │                                                                             │
    │  # Wait for FluxInstance to be ready                                       │
    │  kubectl -n ${var.flux_namespace} wait --for=condition=Ready \
    │    fluxinstance/flux --timeout=10m                                          │
    │                                                                             │
    │  # Verify Flux controllers are running                                     │
    │  kubectl -n ${var.flux_namespace} get pods                                 │
    │                                                                             │
    │  # Check FluxInstance status                                               │
    │  kubectl -n ${var.flux_namespace} get fluxinstance flux -o yaml            │
    │                                                                             │
    │  # Verify Git sync                                                         │
    │  kubectl -n ${var.flux_namespace} get gitrepository                        │
    │  kubectl -n ${var.flux_namespace} get kustomization                        │
    │                                                                             │
    └─────────────────────────────────────────────────────────────────────────────┘

    ╔════════════════════════════════════════════════════════════════════════════╗
    ║  TROUBLESHOOTING                                                            ║
    ╚════════════════════════════════════════════════════════════════════════════╝

    If any phase fails, check logs:

    # OLM v1 controller logs
    kubectl -n olmv1-system logs -l app.kubernetes.io/name=operator-controller

    # Catalog controller logs
    kubectl -n olmv1-system logs -l app.kubernetes.io/name=catalogd

    # Flux Operator logs
    kubectl -n ${var.flux_namespace} logs -l app.kubernetes.io/name=flux-operator

    # Flux controller logs
    kubectl -n ${var.flux_namespace} logs -l app.kubernetes.io/part-of=flux

    Full documentation: terraform/environments/talos-gitops/README.md
  EOT
}

output "next_steps" {
  description = "Next steps after complete installation"
  value       = <<-EOT
    After all 4 phases are complete:

    1. Verify all components are running:
       kubectl -n ${kubernetes_namespace.cert_manager.metadata[0].name} get pods
       kubectl -n olmv1-system get pods
       kubectl -n ${var.flux_namespace} get pods

    2. Check FluxInstance status:
       kubectl -n ${var.flux_namespace} get fluxinstance flux -o jsonpath='{.status.conditions}' | jq

    3. Verify Git sync:
       kubectl -n ${var.flux_namespace} get gitrepository
       kubectl -n ${var.flux_namespace} get kustomization

    4. Add manifests to: ${var.cluster_path}
       - kubernetes/base/kube-system/ for system components
       - kubernetes/base/kube-addons/ for cluster addons
       - Push to branch: ${var.github_branch}
       - Flux will automatically reconcile

    5. Monitor reconciliation:
       kubectl -n ${var.flux_namespace} get kustomization -w
  EOT
}
