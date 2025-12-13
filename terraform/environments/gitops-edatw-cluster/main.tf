# Talos GitOps Edatw - Main Configuration
#
# This environment uses the gitops module to bootstrap Flux CD
# on the edatw Kubernetes cluster for GitOps-based continuous delivery.

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

provider "kubectl" {
  host                   = var.kubernetes_host
  token                  = var.kubernetes_token
  cluster_ca_certificate = base64decode(var.kubernetes_cluster_ca_certificate)
  load_config_file       = false
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

# ============================================================================
# Talos GitOps Module
# ============================================================================
# This module bootstraps Flux CD on the edatw Kubernetes cluster using:
# - cert-manager: Certificate management for webhooks
# - Flux Operator: Manages Flux installation via FluxInstance CRD (Helm)
# - FluxInstance: Declarative Flux configuration with SOPS integration
# ============================================================================

module "gitops" {
  source = "../../modules/gitops"

  # Cluster configuration
  cluster_name = var.cluster_name
  cluster_path = var.cluster_path

  # GitHub configuration
  github_owner      = var.github_owner
  github_repository = var.github_repository
  github_token      = var.github_token
  github_branch     = var.github_branch

  # Flux configuration
  flux_namespace        = var.flux_namespace
  flux_network_policy   = var.flux_network_policy
  flux_components_extra = var.flux_components_extra

  # SOPS age key content (read from file if exists, empty for validation)
  sops_age_key = fileexists(var.sops_age_key_path) ? file(var.sops_age_key_path) : ""

  # Component versions
  cert_manager_version                          = var.cert_manager_version
  cert_manager_dns01_recursive_nameservers      = var.cert_manager_dns01_recursive_nameservers
  cert_manager_dns01_recursive_nameservers_only = var.cert_manager_dns01_recursive_nameservers_only
  cert_manager_enable_certificate_owner_ref     = var.cert_manager_enable_certificate_owner_ref
  cert_manager_enable_gateway_api               = var.cert_manager_enable_gateway_api
  flux_operator_version                         = var.flux_operator_version
  flux_version                                  = var.flux_version
}
