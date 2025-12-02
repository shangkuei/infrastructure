# Terraform Backend Configuration - talos-gitops-shangkuei-dev with SOPS Encryption
#
# This configuration stores Terraform state for Flux GitOps bootstrap on shangkuei-dev.
# Backend credentials and sensitive variables are encrypted with SOPS.
#
# Prerequisites:
# 1. Deploy r2-terraform-state environment: cd ../r2-terraform-state && make apply
# 2. Generate age encryption key: make age-keygen
# 3. Create backend.hcl from backend.hcl.example with R2 credentials
# 4. Encrypt backend config: make encrypt-backend
# 5. Initialize with SOPS-encrypted config: make init
#
# See: README.md for full setup instructions

terraform {
  backend "s3" {}
}
