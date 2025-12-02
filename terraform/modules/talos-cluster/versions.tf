# Talos Cluster Module - Provider Requirements

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.7.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
  }
}
