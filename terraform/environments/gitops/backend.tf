# Terraform Backend Configuration - talos-flux with SOPS Encryption
#
# This configuration stores Terraform state for Flux GitOps bootstrap.
# Backend credentials and sensitive variables are encrypted with SOPS.
#
# Prerequisites:
# 1. Deploy r2-terraform-state environment: cd ../r2-terraform-state && make apply
# 2. Generate age encryption key: age-keygen (unique key per environment)
# 3. Create backend.hcl from backend.hcl.example with R2 credentials
# 4. Encrypt backend config: sops -e -i backend.hcl && mv backend.hcl backend.enc.hcl
# 5. Uncomment the backend block below
# 6. Initialize with SOPS-encrypted config
#
# SOPS Configuration:
# - Age public key: age1m739xc52juac23wtkg0eyfs5rtj5a3uhlvge0upr0aw5cz28svtqxuysjf
# - Encryption rules: see .sops.yaml in this directory
# - Private key storage: ~/.config/sops/age/ and GitHub Secrets
#
# See: README.md - "Secret Management with SOPS" section

# Uncomment after completing SOPS setup above
terraform {
  backend "s3" {}
}

# Workflow:
# 1. Generate unique age key for this environment:
#    age-keygen -o ~/.config/sops/age/talos-flux-key.txt
#
# 2. Update .sops.yaml with your age public key
#
# 3. Create backend configuration:
#    cp backend.hcl.example backend.hcl
#    # Edit backend.hcl with R2 credentials
#
# 4. Encrypt backend config with SOPS:
#    sops -e backend.hcl > backend.enc.hcl
#    rm backend.hcl  # Remove plaintext file
#
# 5. Create and encrypt terraform.tfvars:
#    cp terraform.tfvars.example terraform.tfvars
#    # Add your GitHub token and credentials
#    sops -e terraform.tfvars > terraform.enc.tfvars
#    rm terraform.tfvars  # Remove plaintext file
#
# 6. Store private key in GitHub Secrets:
#    gh secret set SOPS_AGE_KEY_TALOS_FLUX < ~/.config/sops/age/talos-flux-key.txt
#
# 7. Initialize Terraform (with SOPS decryption):
#    sops exec-file backend.enc.hcl 'terraform init -backend-config={}'
#
# 8. Plan/Apply with encrypted variables:
#    sops exec-file terraform.enc.tfvars 'terraform plan -var-file={}'
#    sops exec-file terraform.enc.tfvars 'terraform apply -var-file={}'
#
# Daily Usage:
# - Decrypt and init:  sops exec-file backend.enc.hcl 'terraform init -backend-config={}'
# - Decrypt and plan:  sops exec-file terraform.enc.tfvars 'terraform plan -var-file={}'
# - Decrypt and apply: sops exec-file terraform.enc.tfvars 'terraform apply -var-file={}'
#
# Security Notes:
# - backend.enc.hcl and terraform.enc.tfvars are safe to commit (encrypted)
# - backend.hcl and terraform.tfvars should NEVER be committed (gitignored)
# - Private age key must be stored securely (GitHub Secrets + password manager)
# - See docs/runbooks/0008-sops-secret-management.md for full documentation
