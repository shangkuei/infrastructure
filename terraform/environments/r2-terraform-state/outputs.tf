# Outputs for State Backend Environment

output "bucket_name" {
  description = "Name of the R2 bucket for Terraform state"
  value       = cloudflare_r2_bucket.terraform_state.name
}

output "bucket_id" {
  description = "ID of the R2 bucket"
  value       = cloudflare_r2_bucket.terraform_state.id
}

output "bucket_endpoint" {
  description = "S3-compatible endpoint URL for the R2 bucket"
  value       = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
  sensitive   = true
}

output "bucket_location" {
  description = "Location of the R2 bucket"
  value       = cloudflare_r2_bucket.terraform_state.location
}

output "account_id" {
  description = "Cloudflare account ID"
  value       = var.cloudflare_account_id
  sensitive   = true
}

output "backend_configuration" {
  description = "Backend configuration values for use in other environments"
  value = {
    bucket   = cloudflare_r2_bucket.terraform_state.name
    endpoint = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
    region   = "auto"
  }
  sensitive = true
}

output "setup_instructions" {
  description = "Quick setup instructions for configuring backend in other environments"
  sensitive   = true
  value       = <<-EOT
    ## Terraform State Backend Setup Complete!

    Bucket created: ${cloudflare_r2_bucket.terraform_state.name}
    Endpoint: https://${var.cloudflare_account_id}.r2.cloudflarestorage.com

    ## Next Steps:

    ### 1. Migrate This Environment's State to R2

    After initial deployment, migrate local state to R2:

    a. Uncomment backend block in main.tf (lines 13-27)
    b. Replace <YOUR_ACCOUNT_ID> with: ${var.cloudflare_account_id}
    c. Set R2 credentials (from step 2 below)
    d. Run: terraform init -migrate-state

    ### 2. Create R2 API Token

    Visit: https://dash.cloudflare.com → R2 → Manage R2 API Tokens
    - Permission: Object Read & Write
    - Bucket: ${cloudflare_r2_bucket.terraform_state.name}

    Set credentials:
    export AWS_ACCESS_KEY_ID="<your-r2-access-key>"
    export AWS_SECRET_ACCESS_KEY="<your-r2-secret-key>"

    ### 3. Configure Other Environments

    Add to other environment's main.tf:

    terraform {
      backend "s3" {
        bucket = "r2-terraform-state"
        key    = "environments/<env-name>/terraform.tfstate"
        region = "auto"

        endpoints = {
          s3 = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
        }

        skip_credentials_validation = true
        skip_requesting_account_id  = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        use_path_style             = true
      }
    }

    Then run: terraform init -migrate-state

    ### 4. SOPS Encryption (Recommended)

    Protect sensitive variables in version control:

    a. Generate age key: make age-keygen
    b. Backup private key: ~/.config/sops/age/r2-terraform-state.txt
    c. Encrypt vars: sops -e terraform.tfvars > terraform.tfvars.enc
    d. Commit encrypted file to git
    e. Apply with: make apply (Makefile handles SOPS automatically)

    Age key location: ~/.config/sops/age/r2-terraform-state.txt
    See README.md for complete SOPS workflow documentation.
  EOT
}
