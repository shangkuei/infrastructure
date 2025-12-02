# Terraform State Backend Environment

This environment deploys a Cloudflare R2 bucket for storing Terraform state files for all other environments.

## Overview

- **Purpose**: Central state storage for all Terraform environments
- **Backend**: Cloudflare R2 (S3-compatible)
- **Cost**: ~$0.02-0.17/month for typical usage
- **State**: Local (this environment uses local state, others use R2)

## Quick Start

### 1. Generate Age Encryption Key

```bash
# Generate age key for encrypting sensitive variables
make age-keygen
```

This creates:

- `~/.config/sops/age/r2-terraform-state.txt` - Private key (keep secure!)
- `~/.config/sops/age/r2-terraform-state.txt.pub` - Public key (for encryption)

**Important**: Backup the private key in your password manager!

### 2. Configure Sensitive Variables

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your Cloudflare credentials
vim terraform.tfvars
```

Required variables:

- `cloudflare_api_token` - Cloudflare API token (create at dash.cloudflare.com/profile/api-tokens)
- `cloudflare_account_id` - Your Cloudflare account ID
- `bucket_name` - R2 bucket name (default: "r2-terraform-state")

### 3. Encrypt Variables with SOPS

```bash
# Create SOPS configuration (already exists in repo root)
# .sops.yaml specifies encryption rules for terraform.tfvars

# Encrypt terraform.tfvars
sops -e terraform.tfvars > terraform.tfvars.enc

# Remove unencrypted file (optional, for security)
rm terraform.tfvars

# The encrypted file (terraform.tfvars.enc) can be committed to git
```

### 4. Deploy with Encrypted Variables

```bash
# Plan deployment (uses encrypted variables automatically)
make plan

# Apply deployment (uses encrypted variables automatically)
make apply

# Confirm and deploy
```

**Note**: The Makefile automatically handles SOPS decryption using the age key at `~/.config/sops/age/r2-terraform-state.txt`. All credentials are stored encrypted in `terraform.tfvars.enc` and `backend.hcl.enc`.

### 5. Create R2 Access Credentials

After deployment:

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Navigate to **R2 → Manage R2 API Tokens**
3. Create token with **Object Read & Write** permission
4. Save Access Key ID and Secret Access Key

### 6. Configure Backend with SOPS (Partial Configuration)

Terraform supports partial backend configuration, allowing you to store sensitive backend credentials separately from the main configuration. We use SOPS to encrypt these credentials:

```bash
# 1. Copy the backend configuration template
cp backend.hcl.example backend.hcl

# 2. Edit with your actual values
vim backend.hcl
# Fill in:
# - endpoint: Your Cloudflare account ID in the URL
# - access_key: R2 Access Key ID from step 5
# - secret_key: R2 Secret Access Key from step 5

# 3. Encrypt the backend configuration
make encrypt-backend

# 4. Remove the plaintext file (IMPORTANT for security!)
rm backend.hcl

# The encrypted backend.hcl.enc can be safely committed to git
```

**How it works**:

- `backend.hcl.example` - Template for backend configuration (committed to git)
- `backend.hcl` - Temporary file with plaintext credentials (gitignored)
- `backend.hcl.enc` - SOPS-encrypted backend config (committed to git)
- `make init` - Automatically decrypts and loads backend.hcl.enc

### 7. Migrate Local State to R2

After the R2 bucket is created and backend configuration is encrypted, migrate the local state file to R2:

```bash
# 1. Verify bucket was created successfully
make output

# 2. Verify encrypted backend configuration exists
ls -la backend.hcl.enc

# 3. Reinitialize Terraform with backend configuration and migrate state
make init
# When prompted "Do you want to copy existing state to the new backend?", answer "yes"

# 4. Verify state was migrated
terraform state list

# 5. Verify state is in R2 (local state file should be gone)
ls -la terraform.tfstate*
# You should only see terraform.tfstate.backup

# 6. Remove local state backup (optional, after verifying migration)
# rm terraform.tfstate.backup
```

**Important Notes**:

- The `make init` command automatically decrypts `backend.hcl.enc` and loads the backend configuration
- After migration, this environment uses R2 for its own state storage (self-hosting)
- The backend configuration in `main.tf` is now just `backend "s3" {}` - all sensitive values are in the encrypted `backend.hcl.enc`
- To edit backend configuration: `sops backend.hcl.enc`

**Manual Migration (without Makefile)**:

If you prefer to run terraform commands directly:

```bash
# Initialize with encrypted backend config
SOPS_AGE_KEY_FILE=~/.config/sops/age/r2-terraform-state.txt \
  sops exec-file backend.hcl.enc 'terraform init -backend-config={} -migrate-state'

# Verify migration
terraform state list
```

## Using in Other Environments

After deploying the state backend, configure other environments to use it.

### Add Backend Configuration

In your environment's `main.tf`, use partial backend configuration:

```hcl
terraform {
  required_version = ">= 1.6.0"

  # Backend configuration using partial configuration
  # Sensitive values are stored in backend.hcl.enc
  backend "s3" {}

  required_providers {
    # ... your providers
  }
}
```

Then create a `backend.hcl` file for the environment:

```hcl
# Backend configuration for <env-name> environment
bucket = "r2-terraform-state"
key    = "environments/<env-name>/terraform.tfstate"
region = "auto"

endpoints = {
  s3 = "https://<account-id>.r2.cloudflarestorage.com"
}

access_key = "<r2-access-key-id>"
secret_key = "<r2-secret-access-key>"

skip_credentials_validation = true
skip_requesting_account_id  = true
skip_metadata_api_check     = true
skip_region_validation      = true
skip_s3_checksum            = true
use_path_style              = true
```

Encrypt the backend configuration:

```bash
# Encrypt backend config (requires age key for the environment)
sops -e backend.hcl > backend.hcl.enc

# Remove plaintext file
rm backend.hcl

# Initialize with encrypted backend
sops exec-file backend.hcl.enc 'terraform init -backend-config={}'
```

### Get Configuration Values

```bash
# From r2-terraform-state directory
make output

# View bucket name and endpoint
terraform output bucket_name
terraform output bucket_endpoint

# View setup instructions
terraform output -raw setup_instructions
```

## SOPS Encryption Workflow

This environment uses SOPS with age encryption to protect sensitive variables in version control.

### Why SOPS?

- **Version Control Safe**: Encrypted files can be committed to git
- **Selective Encryption**: Only encrypts values, not keys
- **Easy Collaboration**: Team members can decrypt with their age keys
- **Terraform Integration**: Seamless integration with terraform workflows

### Daily Workflow

```bash
# Edit encrypted Terraform variables (SOPS handles encryption automatically)
sops terraform.tfvars.enc

# Edit encrypted backend configuration (only if changing R2 credentials or endpoint)
sops backend.hcl.enc

# Initialize Terraform (loads encrypted backend config automatically)
make init

# Plan changes (uses encrypted variables automatically)
make plan

# Apply changes (uses encrypted variables automatically)
make apply

# View sensitive outputs
make output
```

**Note**: The Makefile automatically sets `SOPS_AGE_KEY_FILE` to
`~/.config/sops/age/r2-terraform-state.txt`, so you can use `make` commands
without any manual configuration. Backend credentials are automatically loaded
from `backend.hcl.enc` during `make init`.

### Advanced SOPS Usage

```bash
# Encrypt a new file
sops -e new-file.txt > new-file.enc

# Update encryption keys (rotate age keys)
sops updatekeys terraform.tfvars.enc
sops updatekeys backend.hcl.enc

# Edit with specific editor
EDITOR=vim sops terraform.tfvars.enc
EDITOR=vim sops backend.hcl.enc

# Decrypt files to view manually
sops -d terraform.tfvars.enc
sops -d backend.hcl.enc

# Use multiple age keys (team setup)
# Edit .sops.yaml to add team member public keys
```

### File Structure

**Committed to git (safe)**:

- `backend.hcl.example` - Template for backend configuration
- `backend.hcl.enc` - SOPS-encrypted backend config with R2 credentials
- `terraform.tfvars.enc` - SOPS-encrypted Terraform variables
- `.sops.yaml` - SOPS configuration with age public key
- `main.tf` - Terraform configuration with empty backend block

**Gitignored (never commit)**:

- `backend.hcl` - Temporary plaintext backend config (deleted after encryption)
- `terraform.tfvars` - Temporary plaintext variables (deleted after encryption)
- `terraform.tfstate*` - Local state files (migrated to R2)

## Makefile Commands

```bash
make help             # Show all commands
make init             # Initialize Terraform (loads encrypted backend.hcl.enc)
make plan             # Show Terraform plan
make apply            # Deploy R2 backend
make destroy          # Destroy R2 backend (caution!)
make validate         # Validate configuration
make fmt              # Format Terraform files
make check            # Run all validation checks
make age-keygen       # Generate age encryption key
make age-info         # Display age key information
make encrypt-backend  # Encrypt backend.hcl with SOPS
make output           # Show all outputs (including sensitive)
make clean            # Clean generated files
```

## Directory Structure

```
r2-terraform-state/
├── Makefile                    # Build automation
├── README.md                   # This file
├── main.tf                     # Terraform config (empty backend block)
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── .sops.yaml                  # SOPS configuration
├── .gitignore                  # Git ignore rules
├── backend.hcl.example         # Backend config template
├── backend.hcl.enc             # Encrypted backend config (committed)
├── terraform.tfvars.example    # Terraform vars template
├── terraform.tfvars.enc        # Encrypted variables (committed)
├── .terraform/                 # Terraform plugins (gitignored)
└── terraform.tfstate*          # Local state (gitignored, migrated to R2)

~/.config/sops/age/                  # Age keys (one per environment)
├── r2-terraform-state.txt           # Private key (this environment)
├── r2-terraform-state.txt.pub       # Public key (this environment)
├── prod.txt                         # Private key (prod env)
└── prod.txt.pub                     # Public key (prod env)
```

## State Key Naming Convention

Use consistent naming for state keys:

```
environments/<environment>/<project>/terraform.tfstate

Examples:
├── environments/unraid/terraform.tfstate
├── environments/prod/terraform.tfstate
├── environments/staging/terraform.tfstate
└── environments/dev/terraform.tfstate
```

## Security Best Practices

### 1. Credential Management

- ✅ Store credentials encrypted with SOPS
- ✅ Use separate age keys per environment
- ✅ Rotate credentials every 90 days
- ❌ Never commit plaintext credentials to git
- ❌ Never hardcode credentials in Terraform files

### 2. Age Encryption Keys

- ✅ Store private key in password manager
- ✅ Backup private key securely offline
- ✅ Use separate keys per environment
- ❌ Never commit private keys
- ❌ Never share private keys in plain text

### 3. Access Control

- Create separate R2 tokens per project
- Use minimal required permissions
- Enable MFA on Cloudflare account
- Review access logs regularly

### 4. State File Security

- State files contain sensitive data
- R2 buckets are private by default
- Consider additional encryption for sensitive environments
- Implement backup strategy

## State Locking

⚠️ **Important**: Cloudflare R2 does not support native state locking.

### Solutions

**1. Terraform Cloud** (Recommended for teams)

- Free tier with state locking
- Team collaboration features
- Sign up: https://app.terraform.io/

**2. Single User/Sequential Operations**

- Acceptable for personal projects
- Coordinate changes manually
- Use CI/CD with job queues

**3. No Locking** (Current setup)

- Ensure only one person runs terraform at a time
- Use CI/CD pipelines to serialize operations

## Cost Estimation

Cloudflare R2 pricing (2025):

- **Storage**: $0.015/GB/month
- **Class A operations** (write): $4.50/million
- **Class B operations** (read): $0.36/million
- **Egress**: FREE

### Example Costs

| Scenario | Storage | Operations | Monthly Cost |
|----------|---------|------------|--------------|
| Small (1-3 envs) | 1GB | 1,000 ops | ~$0.02 |
| Medium (5-10 envs) | 5GB | 5,000 ops | ~$0.10 |
| Large (10+ envs) | 10GB | 10,000 ops | ~$0.17 |

Much cheaper than AWS S3 with egress fees!

## Troubleshooting

### Authentication Errors

```bash
# Verify encrypted backend configuration exists
ls -la backend.hcl.enc

# View backend configuration (credentials will be shown)
sops -d backend.hcl.enc

# Test R2 access
terraform state list
```

### Bucket Not Found

```bash
# Verify bucket exists
terraform output bucket_name

# Check Cloudflare dashboard
# https://dash.cloudflare.com → R2
```

### State Migration Failed

```bash
# Restore from backup (if exists)
cp terraform.tfstate.backup terraform.tfstate

# Reconfigure backend
terraform init -reconfigure

# Try migration again
terraform init -migrate-state
```

## Maintenance

### Backup State Files

```bash
# Download all state files (requires AWS CLI)
aws s3 sync s3://terraform-state backups/ \
  --endpoint-url=$(terraform output -raw bucket_endpoint)
```

### Update Configuration

```bash
# Modify terraform.tfvars
vim terraform.tfvars

# Apply changes
make apply
```

### Rotate R2 Credentials

```bash
# 1. Create new R2 API token in Cloudflare dashboard

# 2. Update encrypted backend configuration
sops backend.hcl.enc
# Update access_key and secret_key with new credentials

# 3. Test access
terraform state list

# 4. Revoke old token in Cloudflare dashboard
```

## External Resources

- [Cloudflare R2 Documentation](https://developers.cloudflare.com/r2/)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Age Encryption](https://age-encryption.org/)
- [SOPS Documentation](https://github.com/mozilla/sops)

## Support

For issues:

1. Check terraform output for instructions
2. Review [Cloudflare R2 Status](https://www.cloudflarestatus.com/)
3. See infrastructure repository documentation
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 4.52.5 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [cloudflare_r2_bucket.terraform_state](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/r2_bucket) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the R2 bucket for Terraform state storage | `string` | `"r2-terraform-state"` | no |
| <a name="input_cloudflare_account_id"></a> [cloudflare\_account\_id](#input\_cloudflare\_account\_id) | Cloudflare account ID for R2 bucket | `string` | n/a | yes |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token for authentication (stored encrypted in tfvars.enc) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_id"></a> [account\_id](#output\_account\_id) | Cloudflare account ID |
| <a name="output_backend_configuration"></a> [backend\_configuration](#output\_backend\_configuration) | Backend configuration values for use in other environments |
| <a name="output_bucket_endpoint"></a> [bucket\_endpoint](#output\_bucket\_endpoint) | S3-compatible endpoint URL for the R2 bucket |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | ID of the R2 bucket |
| <a name="output_bucket_location"></a> [bucket\_location](#output\_bucket\_location) | Location of the R2 bucket |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the R2 bucket for Terraform state |
| <a name="output_setup_instructions"></a> [setup\_instructions](#output\_setup\_instructions) | Quick setup instructions for configuring backend in other environments |
<!-- END_TF_DOCS -->
