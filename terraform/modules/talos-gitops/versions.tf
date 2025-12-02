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
    # kubectl provider is needed for FluxInstance because:
    # - kubernetes_manifest validates CRD exists during plan phase
    # - FluxInstance CRD is installed by Flux Operator Helm chart
    # - kubectl_manifest validates during apply, solving the timing issue
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}
