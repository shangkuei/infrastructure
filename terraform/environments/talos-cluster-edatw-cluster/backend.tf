# Talos Edatw Cluster - Backend Configuration
#
# This file configures the Terraform backend. The actual backend settings
# are provided via backend.hcl (encrypted with SOPS as backend.enc.hcl).

terraform {
  # Backend will be configured via -backend-config flag during init
  # See Makefile for usage: make init
  #
  # For local development, you can run: terraform init
  # For remote state, create backend.hcl and run: make init
  backend "s3" {}
}
