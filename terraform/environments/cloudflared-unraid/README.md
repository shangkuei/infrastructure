# Salary Mailman Terraform Environment

Terraform environment for deploying Cloudflare Tunnel infrastructure for the salary-mailman application.

## Overview

This environment uses the `cloudflared` module to create:

- Cloudflare Tunnel
- DNS record
- Tunnel token for cloudflared

## Prerequisites

- Terraform >= 1.5.0
- Cloudflare API token with permissions:
  - Zone:Read
  - Account:Cloudflare Tunnel:Edit
- SOPS with age key for encrypting sensitive values
- S3 backend for Terraform state (optional but recommended)

## Setup

### 1. Configure Backend

```bash
# Copy example backend configuration
cp backend.hcl.example backend.hcl

# Edit backend.hcl with your S3 bucket details
# DO NOT commit backend.hcl
```

### 2. Configure Variables

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your Cloudflare credentials
# Fill in:
# - cloudflare_api_token
# - cloudflare_account_id
# - cloudflare_zone_id
```

### 3. Encrypt Sensitive Files

```bash
# Encrypt terraform.tfvars
sops -e terraform.tfvars > terraform.tfvars.enc

# Remove unencrypted file
rm terraform.tfvars

# For future edits:
sops terraform.tfvars.enc
```

## Usage

### Initialize Terraform

```bash
# Initialize with S3 backend
terraform init -backend-config=backend.hcl

# Or without backend (local state)
terraform init
```

### Plan and Apply

```bash
# Decrypt variables (if using SOPS)
sops -d terraform.tfvars.enc > terraform.tfvars

# Plan changes
terraform plan

# Apply changes
terraform apply

# Clean up decrypted file
rm terraform.tfvars
```

### Get Tunnel Token

After applying, extract the tunnel token for Kubernetes:

```bash
# Decrypt variables first
sops -d terraform.tfvars.enc > terraform.tfvars

# Get tunnel token (sensitive output)
terraform output -raw tunnel_token

# Clean up
rm terraform.tfvars
```

## Integration with Kubernetes

### Update Cloudflared Secret

1. Get the tunnel token:

   ```bash
   terraform output -raw tunnel_token
   ```

2. Update the Kubernetes secret:

   ```bash
   # Edit the secret file
   vim ../../argocd-examples/salary-mailman/overlays/shangkuei-xyz-talos/secret-cloudflared.yaml

   # Replace REPLACE_WITH_CLOUDFLARE_TUNNEL_TOKEN with actual token

   # Encrypt with SOPS
   sops -e -i ../../argocd-examples/salary-mailman/overlays/shangkuei-xyz-talos/secret-cloudflared.yaml
   ```

3. Commit and push the encrypted secret

## File Structure

```
edatw-salary-mailman/
├── main.tf                      # Main configuration
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output definitions
├── backend.tf                   # Backend configuration
├── backend.hcl.example          # Example backend config
├── terraform.tfvars.example     # Example variables
├── .sops.yaml                   # SOPS encryption rules
├── .gitignore                   # Git ignore patterns
└── README.md                    # This file
```

## Security Notes

- **Never commit unencrypted secrets**:
  - terraform.tfvars (contains API tokens)
  - backend.hcl (may contain AWS credentials)

- **Always use SOPS for encryption**:
  - Encrypt terraform.tfvars before committing
  - Store encrypted files as terraform.tfvars.enc

- **Tunnel token security**:
  - Treat tunnel_token as highly sensitive
  - Only store encrypted in Kubernetes secrets
  - Rotate regularly

## Troubleshooting

### "Error: Invalid provider configuration"

Ensure terraform.tfvars is decrypted before running terraform commands:

```bash
sops -d terraform.tfvars.enc > terraform.tfvars
```

### "Error: Backend initialization required"

Run terraform init with backend configuration:

```bash
terraform init -backend-config=backend.hcl
```

### "Error: No value for required variable"

Ensure all required variables are set in terraform.tfvars:

- cloudflare_api_token
- cloudflare_account_id
- cloudflare_zone_id

## Related Documentation

- [Cloudflare Tunnel Module](../../modules/cloudflare-tunnel/README.md)
- [ArgoCD Application Setup](../../../argocd-examples/salary-mailman/README.md)
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_edatw_tunnel"></a> [edatw\_tunnel](#module\_edatw\_tunnel) | ../../modules/cloudflared | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudflare_account_id"></a> [cloudflare\_account\_id](#input\_cloudflare\_account\_id) | Cloudflare Account ID | `string` | n/a | yes |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token with Zone:Read and Tunnel:Edit permissions | `string` | n/a | yes |
| <a name="input_cloudflare_zone_id"></a> [cloudflare\_zone\_id](#input\_cloudflare\_zone\_id) | Cloudflare Zone ID for shangkuei.xyz | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dns_records"></a> [dns\_records](#output\_dns\_records) | Created DNS records |
| <a name="output_tunnel_cname"></a> [tunnel\_cname](#output\_tunnel\_cname) | CNAME target for the tunnel |
| <a name="output_tunnel_id"></a> [tunnel\_id](#output\_tunnel\_id) | Cloudflare Tunnel ID for salary-mailman |
| <a name="output_tunnel_name"></a> [tunnel\_name](#output\_tunnel\_name) | Cloudflare Tunnel name |
| <a name="output_tunnel_token"></a> [tunnel\_token](#output\_tunnel\_token) | Tunnel token for cloudflared (use in Kubernetes secret) |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
