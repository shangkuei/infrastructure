variable "kubernetes_host" {
  description = "Kubernetes cluster API endpoint (e.g., https://api.cluster.example.com:6443)"
  type        = string
  sensitive   = true
}

variable "kubernetes_token" {
  description = "Kubernetes authentication token"
  type        = string
  sensitive   = true
}

variable "kubernetes_cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate (base64 encoded)"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub repository owner (organization or user)"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name (without owner)"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token for Flux GitOps"
  type        = string
  sensitive   = true
}

variable "github_branch" {
  description = "Git branch to track for GitOps"
  type        = string
  default     = "main"
}


variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "edatw"
}

variable "cluster_path" {
  description = "Path in the repository where cluster manifests are stored"
  type        = string
  default     = "./kubernetes/clusters/edatw"
}

variable "flux_namespace" {
  description = "Namespace where Flux controllers will be installed"
  type        = string
  default     = "flux-system"
}

variable "flux_network_policy" {
  description = "Enable network policies for Flux controllers"
  type        = bool
  default     = true
}

variable "flux_components_extra" {
  description = "Extra Flux components to install (e.g., image-reflector-controller, image-automation-controller)"
  type        = list(string)
  default     = []
}

variable "sops_age_key_path" {
  description = "Path to the SOPS age private key file for Flux decryption (deployed to Kubernetes)"
  type        = string
  default     = "~/.config/sops/age/gitops-edatw-cluster-flux.txt"
}

# ============================================================================
# Component Versions
# ============================================================================

variable "cert_manager_version" {
  description = "Version of cert-manager Helm chart to install"
  type        = string
  default     = "v1.19.1"
}

variable "cert_manager_dns01_recursive_nameservers" {
  description = "DNS server endpoints for DNS01 and DoH check requests (list of strings, e.g., ['8.8.8.8:53', '8.8.4.4:53'] or ['https://1.1.1.1/dns-query'])"
  type        = list(string)
  default     = ["1.1.1.1:53", "8.8.8.8:53"]
}

variable "cert_manager_dns01_recursive_nameservers_only" {
  description = "When true, cert-manager will only query configured DNS resolvers for ACME DNS01 self check"
  type        = bool
  default     = true
}

variable "cert_manager_enable_certificate_owner_ref" {
  description = "When true, certificate resource will be set as owner of the TLS secret"
  type        = bool
  default     = true
}

variable "cert_manager_enable_gateway_api" {
  description = "Enable gateway API integration in cert-manager (requires v1.15+)"
  type        = bool
  default     = true
}

variable "flux_operator_version" {
  description = "Version of Flux Operator Helm chart to install"
  type        = string
  default     = "0.33.0"
}

variable "flux_version" {
  description = "Version of Flux controllers to deploy via FluxInstance"
  type        = string
  default     = "v2.7.3"
}
