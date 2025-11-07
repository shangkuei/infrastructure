terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.42"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# Provider configurations using explicit credentials
provider "kubernetes" {
  host                   = var.kubernetes_host
  token                  = var.kubernetes_token
  cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.kubernetes_host
    token                  = var.kubernetes_token
    cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
  }
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

provider "kubectl" {
  host                   = var.kubernetes_host
  token                  = var.kubernetes_token
  cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
  load_config_file       = false
}

# ============================================================================
# Step 1: Install cert-manager (required for OLM webhooks)
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
      installCRDs = true
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
# Step 2: Install OLM v1 (Operator Lifecycle Manager)
# ============================================================================

# NOTE: This installation method uses kubectl provider with manifests from
# operator-controller releases, which is the official installation method.
# TODO: Switch to olmv1 Helm chart when it becomes officially available at:
#       https://operator-framework.github.io/operator-controller
# The Helm chart approach would provide better version management and configuration.

resource "kubernetes_namespace" "olmv1_system" {
  metadata {
    name = "olmv1-system"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations,
    ]
  }
}

# Fetch OLM v1 installation manifest from operator-controller releases
# This replicates: curl -L -s "${olmv1_manifest}" | kubectl apply -f -
data "http" "olm_install_manifest" {
  url = "https://github.com/operator-framework/operator-controller/releases/download/${var.olm_version}/operator-controller.yaml"
}

# Apply OLM v1 manifests using kubectl provider
# kubectl_manifest has better support for complex manifests compared to kubernetes_manifest:
# - More robust server-side apply with conflict resolution
# - Better adoption of existing resources (can take over pre-installed resources)
# - Improved handling of multiple YAML documents and edge cases
# - More reliable with CRDs and custom resources
# - Better error messages and troubleshooting
resource "kubectl_manifest" "olm" {
  depends_on = [kubernetes_namespace.olmv1_system, helm_release.cert_manager]

  # Split the YAML manifest into individual documents and apply each
  for_each = {
    for manifest in split("---", data.http.olm_install_manifest.response_body) :
    sha256(manifest) => manifest
    if trimspace(manifest) != "" && length(regexall("(?m)^(apiVersion|kind):", manifest)) > 0
  }

  yaml_body = each.value

  # Server-side apply with force to adopt existing resources
  server_side_apply = true
  force_conflicts   = true

  # Wait for the resource to be fully created
  wait = true
}

# ============================================================================
# Step 3: Create ClusterCatalog for OperatorHub
# ============================================================================

# Create ClusterCatalog pointing to OperatorHub catalog
# This catalog contains the flux-operator and many other community operators
resource "kubernetes_manifest" "operatorhub_catalog" {
  depends_on = [kubectl_manifest.olm]

  manifest = {
    apiVersion = "olm.operatorframework.io/v1"
    kind       = "ClusterCatalog"
    metadata = {
      name = "operatorhubio"
    }
    spec = {
      source = {
        type = "Image"
        image = {
          ref                 = "quay.io/operatorhubio/catalog:latest"
          pollIntervalMinutes = 60
        }
      }
    }
  }
}

# ============================================================================
# Step 4: Install Flux Operator via OLM ClusterExtension
# ============================================================================

# Create flux-system namespace
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

# Create ServiceAccount for flux-operator installation
resource "kubernetes_service_account" "flux_operator_installer" {
  depends_on = [kubernetes_namespace.flux_system]

  metadata {
    name      = "flux-operator-installer"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }
}

# ClusterRole for flux-operator installer
resource "kubernetes_cluster_role" "flux_operator_installer" {
  metadata {
    name = "flux-operator-installer-clusterrole"
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

# ClusterRoleBinding for flux-operator installer
resource "kubernetes_cluster_role_binding" "flux_operator_installer" {
  metadata {
    name = "flux-operator-installer-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.flux_operator_installer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.flux_operator_installer.metadata[0].name
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }
}

# Install Flux Operator using OLM ClusterExtension
resource "kubernetes_manifest" "flux_operator_extension" {
  depends_on = [
    kubernetes_manifest.operatorhub_catalog,
    kubernetes_cluster_role_binding.flux_operator_installer
  ]

  manifest = {
    apiVersion = "olm.operatorframework.io/v1"
    kind       = "ClusterExtension"
    metadata = {
      name = "flux-operator"
    }
    spec = {
      source = {
        sourceType = "Catalog"
        catalog = {
          packageName = "flux-operator"
          version     = var.flux_operator_version
        }
      }
      namespace = kubernetes_namespace.flux_system.metadata[0].name
      serviceAccount = {
        name = kubernetes_service_account.flux_operator_installer.metadata[0].name
      }
    }
  }

  # Wait for the operator to be installed
  wait {
    condition {
      type   = "Installed"
      status = "True"
    }
  }
}

# ============================================================================
# Step 5: Create SOPS Age Secret for Flux
# ============================================================================

# SOPS age key secret for Flux to decrypt encrypted manifests
#
# MODERN FLUX OPERATOR SOPS APPROACH:
# This secret is used by the flux-system Kustomization (patched below via
# FluxInstance.spec.kustomize.patches) to automatically decrypt all SOPS-encrypted
# manifests in the Git repository during cluster sync.
#
# The decryption configuration is added by patching the generated flux-system
# Kustomization resource with:
#
#   spec:
#     decryption:
#       provider: sops
#       secretRef:
#         name: sops-age
#
# This provides cluster-wide automatic decryption for all manifests synced from Git.
# Individual Kustomization resources can optionally use different SOPS keys by
# specifying their own decryption.secretRef configuration.
#
# Benefits over volume mount approach:
# - Declarative: Configured via FluxInstance kustomize patches
# - Cluster-wide: Automatic decryption for all synced manifests
# - Per-resource override: Individual Kustomizations can use different keys
# - Official method: Documented in Flux Operator guides
# - Cleaner: No controller volume mount patches needed
# - Easier troubleshooting: Decryption status visible in Kustomization resource
#
# References:
# - https://fluxcd.io/flux/guides/mozilla-sops/
# - https://fluxcd.control-plane.io/operator/flux-kustomize/#cluster-sync-sops-decryption
#
resource "kubernetes_secret" "sops_age" {
  depends_on = [kubernetes_namespace.flux_system]

  metadata {
    name      = "sops-age"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }

  data = {
    "age.agekey" = file(var.sops_age_key_path)
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }
}

# ============================================================================
# Step 6: Create FluxInstance to bootstrap Flux
# ============================================================================

# Create Git credentials secret for Flux
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

resource "kubernetes_manifest" "flux_instance" {
  depends_on = [
    kubernetes_manifest.flux_operator_extension,
    kubernetes_secret.sops_age,
    kubernetes_secret.flux_git_credentials
  ]

  manifest = {
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
            patch = <<-EOT
              - op: add
                path: /spec/decryption
                value:
                  provider: sops
                  secretRef:
                    name: sops-age
            EOT
            target = {
              kind = "Kustomization"
              name = "flux-system"
            }
          }
        ]
      }
    }
  }
}
