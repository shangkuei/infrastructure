# Terraform Backend Configuration - Cloudflare R2 with SOPS
#
# This configuration stores Terraform state in Cloudflare R2 bucket with encryption.
# Backend credentials are encrypted with SOPS and automatically decrypted during init.
#
# Prerequisites:
# 1. Create backend.hcl from backend.hcl.example with R2 credentials
# 2. Encrypt backend config: make encrypt-backend && rm backend.hcl
# 3. Initialize with SOPS: make init (automatically decrypts backend.hcl.enc)
#
# See: README.md - "Secret Management with SOPS" section

terraform {
  backend "s3" {}
}

# Workflow:
# 1. Create backend configuration:
#    cp backend.hcl.example backend.hcl
#    # Edit backend.hcl with your backend credentials
#
# 2. Encrypt backend config with SOPS:
#    make encrypt-backend
#    rm backend.hcl  # Remove plaintext file
#
# 3. Initialize Terraform (SOPS auto-decrypts):
#    make init  # Automatically: sops exec-file backend.hcl.enc 'terraform init -backend-config={}'
#
# Daily Usage:
# - make init   # SOPS decrypts backend.hcl.enc automatically
# - make plan   # SOPS decrypts terraform.tfvars.enc automatically
# - make apply  # SOPS decrypts terraform.tfvars.enc automatically
