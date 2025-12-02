# Backend Environment - Cloudflare R2 for Terraform State Storage
# This environment deploys the R2 bucket used to store state for all other environments

terraform {
  required_version = ">= 1.6.0"

  # Note: Initial deployment uses local state
  # After R2 bucket is created, uncomment the backend block below and run:
  #   terraform init -migrate-state
  # This migrates the local state to R2 for centralized storage

  # Backend configuration using partial configuration
  # Sensitive values (access_key, secret_key, endpoint) are stored in backend.enc.hcl
  # See README.md for setup instructions
  backend "s3" {}

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Cloudflare Provider Configuration
# API token is stored encrypted in terraform.enc.tfvars using SOPS
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Cloudflare R2 Bucket for Terraform State Storage
# Note: Lifecycle rules are not yet supported by the Cloudflare Terraform provider
# They can be configured via Cloudflare Dashboard or API if needed
resource "cloudflare_r2_bucket" "terraform_state" {
  account_id = var.cloudflare_account_id
  name       = var.bucket_name
  location   = "WNAM" # Western North America
}
