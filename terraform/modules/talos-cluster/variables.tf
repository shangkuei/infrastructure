# Talos Cluster Module - Variables
#
# All variables required to generate Talos machine configurations for a
# Kubernetes cluster with Tailscale network integration.

# =============================================================================
# Cluster Configuration
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.cluster_name))
    error_message = "Cluster name must be lowercase alphanumeric with hyphens."
  }
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint using Tailscale IP (e.g., https://100.64.0.10:6443). Set to first control plane's Tailscale IP."
  type        = string
  default     = "" # Will be auto-generated from first control plane node if empty

  validation {
    condition     = var.cluster_endpoint == "" || can(regex("^https://", var.cluster_endpoint))
    error_message = "Cluster endpoint must start with https:// or be empty (auto-generated)."
  }
}

variable "output_path" {
  description = "Base path for generated configuration files. If empty, uses module path."
  type        = string
  default     = ""
}

# =============================================================================
# Node Configuration
# =============================================================================

variable "control_plane_nodes" {
  description = "Map of control plane nodes with their configuration (using Tailscale IPs)"
  type = map(object({
    tailscale_ipv4 = string           # Tailscale IPv4 address (100.64.0.0/10 range)
    tailscale_ipv6 = optional(string) # Tailscale IPv6 address (fd7a:115c:a1e0::/48 range)
    physical_ip    = optional(string) # Physical IP (for initial bootstrapping only)
    install_disk   = string
    hostname       = optional(string)
    interface      = optional(string, "tailscale0")
    platform       = optional(string, "metal")                        # Platform type: metal, metal-arm64, metal-secureboot, aws, gcp, azure, etc.
    extensions     = optional(list(string), ["siderolabs/tailscale"]) # Talos system extensions (default: Tailscale only)
    # SBC overlay configuration (for Raspberry Pi, Rock Pi, etc.)
    overlay = optional(object({
      image = string # Overlay image (e.g., "siderolabs/sbc-raspberrypi")
      name  = string # Overlay name (e.g., "rpi_generic", "rpi_5")
    }))
    # Kubernetes topology and node labels
    region      = optional(string)          # topology.kubernetes.io/region
    zone        = optional(string)          # topology.kubernetes.io/zone
    arch        = optional(string)          # kubernetes.io/arch (e.g., amd64, arm64)
    os          = optional(string)          # kubernetes.io/os (e.g., linux)
    node_labels = optional(map(string), {}) # Additional node-specific labels
  }))

  validation {
    condition     = length(var.control_plane_nodes) >= 1
    error_message = "At least one control plane node is required."
  }

  validation {
    condition     = length(var.control_plane_nodes) == 1 || length(var.control_plane_nodes) >= 3
    error_message = "Control plane must have 1 node or 3+ nodes for HA (etcd quorum)."
  }
}

variable "worker_nodes" {
  description = "Map of worker nodes with their configuration (using Tailscale IPs)"
  type = map(object({
    tailscale_ipv4 = string           # Tailscale IPv4 address (100.64.0.0/10 range)
    tailscale_ipv6 = optional(string) # Tailscale IPv6 address (fd7a:115c:a1e0::/48 range)
    physical_ip    = optional(string) # Physical IP (for initial bootstrapping only)
    install_disk   = string
    hostname       = optional(string)
    interface      = optional(string, "tailscale0")
    platform       = optional(string, "metal")                        # Platform type: metal, metal-arm64, metal-secureboot, aws, gcp, azure, etc.
    extensions     = optional(list(string), ["siderolabs/tailscale"]) # Talos system extensions (default: Tailscale only)
    # SBC overlay configuration (for Raspberry Pi, Rock Pi, etc.)
    overlay = optional(object({
      image = string # Overlay image (e.g., "siderolabs/sbc-raspberrypi")
      name  = string # Overlay name (e.g., "rpi_generic", "rpi_5")
    }))
    # Kubernetes topology and node labels
    region      = optional(string)          # topology.kubernetes.io/region
    zone        = optional(string)          # topology.kubernetes.io/zone
    arch        = optional(string)          # kubernetes.io/arch (e.g., amd64, arm64)
    os          = optional(string)          # kubernetes.io/os (e.g., linux)
    node_labels = optional(map(string), {}) # Additional node-specific labels
    # OpenEBS Replicated Storage configuration
    openebs_storage       = optional(bool, false)  # Enable OpenEBS storage on this node
    openebs_disk          = optional(string)       # Storage disk device (e.g., /dev/nvme0n1, /dev/sdb)
    openebs_hugepages_2mi = optional(number, 1024) # Number of 2MiB hugepages (1024 = 2GiB, required for Mayastor)
    # OpenEBS ZFS LocalPV configuration - supports multiple pools per node
    zfs_pools = optional(list(object({
      name  = string               # Pool name (e.g., "zpool", "tank", "data")
      disks = list(string)         # Disk devices (e.g., ["/dev/sdb"] or ["/dev/sdb", "/dev/sdc"])
      type  = optional(string, "") # Pool type: "" (single/stripe), "mirror", "raidz", "raidz2", "raidz3"
    })), [])
  }))
  default = {}
}

# =============================================================================
# Tailscale Configuration
# =============================================================================

variable "tailscale_tailnet" {
  description = "Tailscale tailnet name for MagicDNS hostnames (e.g., 'example-org' for example-org.ts.net). Leave empty to skip MagicDNS hostname generation."
  type        = string
  default     = ""
}

variable "tailscale_auth_key" {
  description = "Tailscale authentication key for joining the tailnet (use reusable, tagged key)"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.tailscale_auth_key == "" || can(regex("^tskey-auth-", var.tailscale_auth_key))
    error_message = "Tailscale auth key must start with 'tskey-auth-' or be empty."
  }
}


# =============================================================================
# Version Configuration
# =============================================================================

variable "talos_version" {
  description = "Talos Linux version (e.g., v1.8.0)"
  type        = string
  default     = "v1.8.0"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.talos_version))
    error_message = "Talos version must be in format vX.Y.Z"
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g., v1.31.0)"
  type        = string
  default     = "v1.31.0"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format vX.Y.Z"
  }
}

# =============================================================================
# Machine Configuration
# =============================================================================

variable "use_dhcp_for_physical_interface" {
  description = "Use DHCP for physical network interface configuration"
  type        = bool
  default     = true
}

variable "wipe_install_disk" {
  description = "Wipe the installation disk before installing Talos"
  type        = bool
  default     = false
}

variable "enable_kubeprism" {
  description = "Enable KubePrism for high-availability Kubernetes API access"
  type        = bool
  default     = true
}

variable "kubeprism_port" {
  description = "Port for KubePrism local load balancer"
  type        = number
  default     = 7445

  validation {
    condition     = var.kubeprism_port > 1024 && var.kubeprism_port < 65536
    error_message = "KubePrism port must be between 1024 and 65535."
  }
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "pod_cidr" {
  description = "Pod network CIDR block"
  type        = string
  default     = "10.244.0.0/16"

  validation {
    condition     = can(cidrhost(var.pod_cidr, 0))
    error_message = "Pod CIDR must be a valid IPv4 CIDR block."
  }
}

variable "service_cidr" {
  description = "Service network CIDR block"
  type        = string
  default     = "10.96.0.0/12"

  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "Service CIDR must be a valid IPv4 CIDR block."
  }
}

variable "dns_domain" {
  description = "Kubernetes DNS domain"
  type        = string
  default     = "cluster.local"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.dns_domain))
    error_message = "DNS domain must be a valid domain name."
  }
}

variable "cni_name" {
  description = "CNI plugin name (flannel, cilium, calico, or none)"
  type        = string
  default     = "flannel"

  validation {
    condition     = contains(["flannel", "cilium", "calico", "none"], var.cni_name)
    error_message = "CNI must be one of: flannel, cilium, calico, none."
  }
}

variable "cilium_helm_values" {
  description = "Helm values for Cilium CNI deployment (only used when cni_name = 'cilium'). Map of values to customize Cilium installation."
  type        = any
  default = {
    # Cilium operator configuration
    operator = {
      replicas = 1
    }
    # Enable Hubble for observability (optional)
    hubble = {
      enabled = false
      relay = {
        enabled = false
      }
      ui = {
        enabled = false
      }
    }
    # IPv6 support
    ipv6 = {
      enabled = false
    }
    # Kubernetes API server configuration
    k8sServiceHost = "localhost"
    k8sServicePort = 6443
    # kube-proxy replacement (required when proxy.disabled = true in Talos config)
    kubeProxyReplacement = "true"
  }
}

# =============================================================================
# Security Configuration
# =============================================================================

variable "cert_sans" {
  description = "Additional Subject Alternative Names (SANs) for API server certificate (Tailscale IPs will be added automatically)"
  type        = list(string)
  default     = []
}

# =============================================================================
# Configuration Patches
# =============================================================================

variable "additional_control_plane_patches" {
  description = "Additional YAML patches to apply to control plane nodes (merged with Tailscale patches)"
  type        = list(string)
  default     = []
}

variable "additional_worker_patches" {
  description = "Additional YAML patches to apply to worker nodes (merged with Tailscale patches)"
  type        = list(string)
  default     = []
}

variable "node_labels" {
  description = "Additional Kubernetes node labels to apply to all nodes"
  type        = map(string)
  default     = {}
}

variable "openebs_hostpath_enabled" {
  description = "Enable OpenEBS LocalPV Hostpath support (adds Pod Security admission control exemptions and kubelet hostpath mounts for openebs namespace)"
  type        = bool
  default     = false
}
