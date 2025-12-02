# ============================================================================
# Talos GitOps Module
# ============================================================================
# This module bootstraps Flux CD on a Kubernetes cluster using:
# - cert-manager: Certificate management for webhooks
# - Flux Operator: Manages Flux installation via FluxInstance CRD (Helm)
# - FluxInstance: Declarative Flux configuration with SOPS integration
# ============================================================================

# ============================================================================
# Step 1: Install cert-manager (required for webhooks)
# ============================================================================

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  values = [
    yamlencode({
      crds = {
        enabled = true
      }
      global = {
        leaderElection = {
          namespace = kubernetes_namespace.cert_manager.metadata[0].name
        }
      }
      dns01RecursiveNameservers     = join(",", var.cert_manager_dns01_recursive_nameservers)
      dns01RecursiveNameserversOnly = var.cert_manager_dns01_recursive_nameservers_only
      enableCertificateOwnerRef     = var.cert_manager_enable_certificate_owner_ref
      featureGates                  = "ExperimentalGatewayAPISupport=true"
      extraArgs = [
        "--enable-gateway-api=${var.cert_manager_enable_gateway_api}"
      ]
    })
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 600
}

# ============================================================================
# Step 2: Install Flux Operator via Helm
# ============================================================================

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = var.flux_namespace
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations,
    ]
  }
}

resource "helm_release" "flux_operator" {
  depends_on = [helm_release.cert_manager, kubernetes_namespace.flux_system]

  name       = "flux-operator"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-operator"
  version    = var.flux_operator_version
  namespace  = kubernetes_namespace.flux_system.metadata[0].name

  wait          = true
  wait_for_jobs = true
  timeout       = 600
}

# ============================================================================
# Step 3: Create SOPS Age Secret for Flux
# ============================================================================

resource "kubernetes_secret" "sops_age" {
  depends_on = [kubernetes_namespace.flux_system]

  metadata {
    name      = "sops-age"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }

  data = {
    "age.agekey" = var.sops_age_key
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }
}

# ============================================================================
# Step 4: Create FluxInstance to bootstrap Flux
# ============================================================================

resource "kubernetes_secret" "flux_git_credentials" {
  depends_on = [kubernetes_namespace.flux_system]

  metadata {
    name      = "flux-system"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }

  data = {
    username = "git"
    password = var.github_token
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }
}

# Using kubectl_manifest instead of kubernetes_manifest because:
# - kubernetes_manifest validates CRD exists during plan phase
# - FluxInstance CRD is installed by Flux Operator Helm chart during apply
# - kubectl_manifest validates during apply, solving the timing issue
resource "kubectl_manifest" "flux_instance" {
  depends_on = [
    helm_release.flux_operator,
    kubernetes_secret.sops_age,
    kubernetes_secret.flux_git_credentials
  ]

  yaml_body = yamlencode({
    apiVersion = "fluxcd.controlplane.io/v1"
    kind       = "FluxInstance"
    metadata = {
      name      = "flux"
      namespace = var.flux_namespace
      annotations = {
        "fluxcd.controlplane.io/reconcileEvery"   = "1h"
        "fluxcd.controlplane.io/reconcileTimeout" = "5m"
      }
    }
    spec = {
      distribution = {
        version  = var.flux_version
        registry = "ghcr.io/fluxcd"
      }

      components = concat(
        [
          "source-controller",
          "kustomize-controller",
          "helm-controller",
          "notification-controller"
        ],
        var.flux_components_extra
      )

      cluster = {
        type          = "kubernetes"
        multitenant   = false
        networkPolicy = var.flux_network_policy
        domain        = "cluster.local"
      }

      sync = {
        kind       = "GitRepository"
        url        = "https://github.com/${var.github_owner}/${var.github_repository}"
        ref        = "refs/heads/${var.github_branch}"
        path       = var.cluster_path
        pullSecret = "flux-system"
        interval   = "5m"
      }

      kustomize = {
        patches = [
          {
            patch = yamlencode([
              {
                op   = "add"
                path = "/spec/decryption"
                value = {
                  provider = "sops"
                  secretRef = {
                    name = "sops-age"
                  }
                }
              }
            ])
            target = {
              kind = "Kustomization"
              name = "flux-system"
            }
          }
        ]
      }
    }
  })

  # Server-side apply for better handling
  server_side_apply = true
  force_conflicts   = true
}
