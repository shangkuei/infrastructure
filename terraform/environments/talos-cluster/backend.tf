# Terraform Backend Configuration - Cloudflare R2 with SOPS
#
# This configuration stores Terraform state in Cloudflare R2 bucket with encryption.
# Backend credentials are encrypted with SOPS and automatically decrypted during init.
#
# Prerequisites:
# 1. Deploy r2-terraform-state environment: cd ../r2-terraform-state && make apply
# 2. Generate age encryption key: make age-keygen
# 3. Create backend.hcl from backend.hcl.example with R2 credentials
# 4. Encrypt backend config: make encrypt-backend && rm backend.hcl
# 5. Uncomment the backend block below
# 6. Initialize with SOPS: make init (automatically decrypts backend.hcl.enc)
#
# See: README.md - "Secret Management with SOPS" section

# Uncomment after completing SOPS setup above
terraform {
  backend "s3" {}
}

# Workflow:
# 1. Deploy R2 backend:
#    cd ../r2-terraform-state && make apply
#
# 2. Generate age key (if not already done):
#    make age-keygen
#
# 3. Create backend configuration:
#    cp backend.hcl.example backend.hcl
#    # Edit backend.hcl with R2 credentials from r2-terraform-state outputs
#
# 4. Encrypt backend config with SOPS:
#    make encrypt-backend
#    rm backend.hcl  # Remove plaintext file
#
# 5. Uncomment the backend block above
#
# 6. Initialize Terraform (SOPS auto-decrypts):
#    make init  # Automatically: sops exec-file backend.hcl.enc 'terraform init -backend-config={}'
#
# 7. Migrate state to R2:
#    Answer 'yes' when prompted to migrate state
#
# Daily Usage:
# - make init   # SOPS decrypts backend.hcl.enc automatically
# - make plan   # SOPS decrypts terraform.tfvars.enc automatically
# - make apply  # SOPS decrypts terraform.tfvars.enc automatically
