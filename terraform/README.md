# Terraform Infrastructure

This directory contains Terraform configurations for provisioning and managing hybrid cloud infrastructure.

## Architecture Philosophy

**Two-Tier Design**: Clean separation between reusable modules and environment-specific deployments.

**Key Principles**:

- **Modules are pure infrastructure** - Only Terraform resources, no templates or file generation
- **Environments configure modules** - Use variables and patches for platform-specific customization
- **No wrapper modules** - Environments use core modules directly with inline configuration
- **Variables over templates** - Use Terraform variables and outputs instead of template generation

## Structure

```
terraform/
├── modules/            # Reusable Terraform modules
│   ├── digitalocean-vpc/    # DigitalOcean VPC
│   ├── digitalocean-doks/   # DigitalOcean Kubernetes
│   ├── oracle-vcn/          # Oracle Cloud VCN
│   └── oracle-oke/          # Oracle Kubernetes Engine
│
└── environments/       # Environment deployments
    ├── r2-terraform-state/ # R2 backend for Terraform state
    ├── talos-cluster/      # Talos Kubernetes with Tailscale
    ├── prod/               # Production (Oracle Cloud)
    └── unraid/             # Homelab Talos on Unraid
```

### Module Design Pattern

Modules contain ONLY Terraform resources and standard files. Modules should provide significant abstraction value - simple resource wrappers should be used directly in environments:

```hcl
# modules/digitalocean-vpc/main.tf (Good: Complex abstraction)
resource "digitalocean_vpc" "this" {
  name        = var.vpc_name
  region      = var.region
  ip_range    = var.ip_range
  description = var.description
}

# environments/r2-terraform-state/main.tf (Good: Direct resource usage)
resource "cloudflare_r2_bucket" "terraform_state" {
  account_id = var.cloudflare_account_id
  name       = var.bucket_name
  location   = "WNAM"
}
```

**What modules contain**:

- ✅ Resource definitions
- ✅ Variable declarations
- ✅ Output declarations
- ✅ Provider requirements
- ✅ Documentation (README.md)

**What modules DO NOT contain**:

- ❌ Template files (.tpl)
- ❌ File generation resources
- ❌ Environment-specific logic
- ❌ Wrapper modules

### Environment Configuration Pattern

Environments use modules directly with configuration:

```hcl
# environments/prod/main.tf
module "vpc" {
  source = "../../modules/digitalocean-vpc"

  vpc_name    = var.vpc_name
  region      = var.region
  ip_range    = var.vpc_cidr
  description = "Production VPC"
}
```

**Environment responsibilities**:

- Configure module variables
- Provide platform-specific configuration
- Generate documentation/templates (if needed)
- Local file outputs for helper scripts

### File Patterns

**Required Files (All Modules)**:

- `main.tf` - Resource definitions
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `README.md` - Documentation

**Optional Files**:

- `versions.tf` - Provider version constraints (can be in main.tf)
- `locals.tf` - Local values (if complex logic needed)
- `data.tf` - Data sources (if many data sources)

**Environment Files**:

- `main.tf` - Module usage and resources
- `variables.tf` - Environment variables
- `outputs.tf` - Environment outputs
- `terraform.tfvars.example` - Example configuration
- `.gitignore` - Ignore sensitive files
- `Makefile` - Operational automation (optional)
- `README.md` - Setup and usage documentation

**Files to Avoid**:

- ❌ Template files (`.tpl`)
- ❌ Generated directories
- ❌ Nested module hierarchies
- ❌ Wrapper modules

## State Backend Setup

**First Step**: Deploy the Terraform state backend before working with other environments.

The `r2-terraform-state` environment creates a Cloudflare R2 bucket for storing Terraform state remotely.

### Special Case: r2-terraform-state Environment

The `r2-terraform-state` environment is unique:

- **Uses local state** (can't store its own state in R2)
- **Creates R2 bucket** for all other environments
- **Outputs configuration values** for other environments to use

### Setup Flow

```bash
# 1. Deploy state-backend first
cd environments/r2-terraform-state

# Generate age encryption key
make age-keygen

# Configure Cloudflare credentials (encrypted with SOPS)
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
make encrypt-tfvars
rm terraform.tfvars

# Deploy R2 backend
make apply

# Configure backend credentials
cp backend.hcl.example backend.hcl
vim backend.hcl  # Add R2 access key and secret
make encrypt-backend
rm backend.hcl

# Migrate state to R2 (self-hosting)
make init  # Answer 'yes' when prompted

# 2. Get backend configuration
terraform output -raw setup_instructions

# 3. Add backend to other environments (see backend.tf in each environment)
# 4. Migrate existing environments: terraform init -migrate-state
```

After deploying the state backend:

1. R2 bucket is created and ready
2. Backend credentials are encrypted with SOPS
3. Local state is migrated to R2 (self-hosting)
4. Other environments can use the same R2 bucket with their own state keys

See [environments/r2-terraform-state/README.md](environments/r2-terraform-state/README.md) for complete documentation.

## Configuration Management

### Variables Over Templates

Instead of generating template files, use Terraform variables and outputs:

**Before (❌ Wrong)**:

```hcl
# Module generates files from templates
resource "local_file" "backend_config" {
  content = templatefile("${path.module}/templates/backend.hcl.tpl", {...})
  filename = "generated/backend.hcl"
}
```

**After (✅ Correct)**:

```hcl
# Environments use resources directly
resource "cloudflare_r2_bucket" "terraform_state" {
  account_id = var.cloudflare_account_id
  name       = var.bucket_name
  location   = "WNAM"
}

output "backend_configuration" {
  value = {
    bucket   = cloudflare_r2_bucket.terraform_state.name
    endpoint = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
  }
}
```

### Makefiles for Automation

Use Makefiles in environments for operational tasks:

```makefile
# environments/r2-terraform-state/Makefile
.PHONY: init apply age-keygen

init:
    terraform init

apply:
    terraform apply

age-keygen:
    @mkdir -p .age
    @age-keygen -o .age/key.txt
```

### Age Encryption Integration

**Key Generation**: Makefiles handle age key generation

```bash
cd environments/r2-terraform-state
make age-keygen
```

Creates:

- `.age/key.txt` - Private key
- `.age/key.txt.pub` - Public key

**Usage**:

```bash
# Encrypt sensitive data
echo "secret" | age -r "$(cat .age/key.txt.pub)" > encrypted.age

# Decrypt
age -d -i .age/key.txt encrypted.age
```

## Quick Start

### Initialize Terraform

```bash
# Navigate to environment directory
cd environments/dev

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

### Plan and Apply

```bash
# Create execution plan
terraform plan -out=tfplan

# Review plan
terraform show tfplan

# Apply changes
terraform apply tfplan

# Or plan and apply in one step (not recommended for production)
terraform apply
```

### Inspect State

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show 'module.network.digitalocean_vpc.main'

# Show all resources
terraform show
```

## Modules

### Creating a New Module

```bash
# Create module directory structure
mkdir -p modules/my-module
cd modules/my-module

# Create standard files
touch main.tf variables.tf outputs.tf versions.tf README.md
```

Module structure:

- **main.tf**: Resource definitions
- **variables.tf**: Input variables
- **outputs.tf**: Output values
- **versions.tf**: Provider version constraints
- **README.md**: Module documentation

### Module Best Practices

1. **Single Responsibility**: Each module should have a single, well-defined purpose
2. **Reusability**: Design modules to be used across environments
3. **Documentation**: Document all variables, outputs, and usage examples
4. **Versioning**: Use semantic versioning for modules
5. **Testing**: Write tests for modules using Terratest
6. **Examples**: Provide usage examples in `examples/` directory

### Module Template

```hcl
# main.tf
resource "provider_resource" "name" {
  # Resource configuration
}

# variables.tf
variable "name" {
  description = "Descriptive text about this variable"
  type        = string
  default     = "default-value"

  validation {
    condition     = length(var.name) > 0
    error_message = "Name must not be empty."
  }
}

# outputs.tf
output "resource_id" {
  description = "ID of the created resource"
  value       = provider_resource.name.id
}

# versions.tf
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    provider = {
      source  = "provider/name"
      version = "~> 1.0"
    }
  }
}
```

## Environments

### Environment Configuration

Each environment directory contains:

- **main.tf**: Environment-specific resource configuration
- **variables.tf**: Environment variables
- **terraform.tfvars**: Variable values (gitignored)
- **terraform.tfvars.example**: Example variable values
- **backend.tf**: Remote state configuration
- **providers.tf**: Provider configuration

### Environment Differences

| Aspect            | Development    | Staging        | Production           |
| ----------------- | -------------- | -------------- | -------------------- |
| Auto-apply        | Yes            | Manual trigger | Manual approval      |
| Instance size     | Small          | Medium         | Large                |
| HA                | No             | Partial        | Full                 |
| Backup            | Daily          | Daily          | Hourly               |
| Cost optimization | Aggressive     | Moderate       | Reserved instances   |

### Creating an Environment

```bash
# Example: Create new environment using DigitalOcean modules
mkdir -p environments/production
cd environments/production

# Create main.tf that uses modules directly
cat > main.tf <<'EOF'
module "vpc" {
  source = "../../modules/digitalocean-vpc"

  vpc_name = "production-vpc"
  region   = "nyc3"
  ip_range = "10.0.0.0/16"
}

module "kubernetes" {
  source = "../../modules/digitalocean-doks"

  cluster_name = "production-cluster"
  region       = var.region
  vpc_id       = module.vpc.vpc_id
}
EOF

# Copy configuration templates
touch variables.tf outputs.tf
cp ../dev/terraform.tfvars.example .

# Configure for your environment
vim terraform.tfvars.example
mv terraform.tfvars.example terraform.tfvars

# Initialize
terraform init

# Plan
terraform plan
```

## State Management

### Remote Backend

State is stored remotely in Cloudflare R2 for:

- **Team collaboration**: Multiple team members can work together
- **State locking**: Prevents concurrent modifications (native via `use_lockfile`)
- **Security**: State is encrypted at rest and in transit
- **Versioning**: History of state changes and rollback capability
- **Zero cost**: R2 free tier (10GB) covers all state files
- **Zero egress**: Unlimited data transfer at no cost

### Backend Configuration

```hcl
# backend.tf
terraform {
  required_version = "~> 1.11"

  backend "s3" {
    # Cloudflare R2 endpoint
    endpoints = {
      s3 = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
    }

    bucket = "terraform-state"
    key    = "environments/dev/terraform.tfstate"
    region = "auto"  # Required but ignored by R2

    # Enable native state locking (Terraform v1.10+)
    use_lockfile = true

    # Disable AWS-specific features
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
```

**Setup Steps**:

1. Deploy R2 backend: `cd environments/r2-terraform-state && make apply`
2. Create R2 API token with Object Read/Write permissions
3. Configure backend credentials with SOPS encryption
4. Migrate state: `make init` (answer 'yes' when prompted)
5. Configure backend in other environments' `backend.tf`

See [environments/r2-terraform-state/README.md](environments/r2-terraform-state/README.md) for complete setup guide.

### State Commands

```bash
# List resources in state
terraform state list

# Show resource details
terraform state show 'resource_address'

# Move resource in state
terraform state mv 'old_address' 'new_address'

# Remove resource from state
terraform state rm 'resource_address'

# Pull remote state
terraform state pull > terraform.tfstate.backup

# Push local state (dangerous!)
terraform state push terraform.tfstate
```

## Variables and Secrets

### Variable Types

```hcl
# String
variable "region" {
  type    = string
  default = "nyc3"  # DigitalOcean region
}

# Number
variable "instance_count" {
  type    = number
  default = 3
}

# Boolean
variable "enable_monitoring" {
  type    = bool
  default = true
}

# List
variable "regions" {
  type    = list(string)
  default = ["nyc3", "sfo3"]  # DigitalOcean regions
}

# Map
variable "tags" {
  type = map(string)
  default = {
    Environment = "dev"
  }
}

# Object
variable "network_config" {
  type = object({
    cidr_block = string
    enable_dns = bool
  })
}
```

### Sensitive Variables

```hcl
variable "database_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}

# Mark outputs as sensitive
output "db_password" {
  value     = var.database_password
  sensitive = true
}
```

### Variable Sources

1. **terraform.tfvars**: Main variable file (gitignored)
2. **Environment variables**: `TF_VAR_variable_name`
3. **Command line**: `-var="variable=value"`
4. **Variable files**: `-var-file="custom.tfvars"`

## Resource Naming Conventions

### Naming Pattern

`{environment}-{component}-{resource-type}`

Examples:

- `prod-web-lb`
- `staging-app-cluster`
- `dev-data-db`

### Tagging Strategy

All resources should include:

```hcl
tags = {
  Name        = "${var.environment}-${var.component}-${resource-type}"
  Environment = var.environment
  ManagedBy   = "Terraform"
  Project     = var.project_name
  Component   = var.component
  CostCenter  = var.cost_center
  Owner       = var.owner_email
}
```

## Testing

### Validation

```bash
# Format check
terraform fmt -check -recursive

# Validate syntax
terraform validate

# Lint with tflint
tflint --recursive
```

### Security Scanning

```bash
# Scan with tfsec
tfsec .

# Scan with checkov
checkov -d .

# Scan with terrascan
terrascan scan -t terraform
```

### Unit Testing

Use Terratest for module testing:

```go
// test/module_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestModule(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/my-module",
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    output := terraform.Output(t, terraformOptions, "resource_id")
    assert.NotEmpty(t, output)
}
```

## Best Practices

### Module Development

1. **Single responsibility** - One module, one purpose
2. **Reusability** - Design for use across multiple environments
3. **Variables for everything** - Make all configuration parameterizable
4. **Clear outputs** - Export all useful values
5. **Good documentation** - README with examples

### Environment Development

1. **Use modules directly** - No wrapper modules
2. **Inline patches** - Use `yamlencode()` for platform-specific config
3. **Document setup** - README with deployment steps
4. **Example configs** - Provide `terraform.tfvars.example`
5. **Makefiles for ops** - Automate common tasks

### State Management

1. **Deploy state-backend first** - Before any other environment
2. **Local state for state-backend** - Can't use R2 for its own state
3. **Remote state for others** - All environments use R2 backend
4. **Consistent naming** - Use `environments/<name>/terraform.tfstate`
5. **Backup strategy** - Regular backups of R2 bucket

### Code Organization

- Keep modules focused and reusable
- Use consistent naming conventions
- Document all variables and outputs
- Version pin all providers and modules

### Security

- Mark sensitive variables as sensitive
- Never commit .tfvars files with secrets
- Use encryption for state files (SOPS with age)
- Scan code for security issues

### Performance

- Use `-parallelism` flag for large deployments
- Leverage `-target` for specific resources
- Use data sources instead of repeated resources
- Cache provider plugins

### Change Management

- Always run `terraform plan` before apply
- Review plan output carefully
- Use workspaces or directories for environments
- Tag resources consistently

## Troubleshooting

### Common Issues

**State lock error**:

```bash
terraform force-unlock <lock-id>
```

**Provider authentication**:

All credentials are managed with SOPS encryption:

```bash
# Cloudflare API Token (for provider authentication)
# Stored in terraform.tfvars.enc, automatically decrypted by make commands
cd environments/r2-terraform-state
sops terraform.tfvars.enc  # Edit encrypted file

# R2 Backend Credentials (for state storage)
# Stored in backend.hcl.enc, automatically loaded by make init
sops backend.hcl.enc  # Edit encrypted backend config

# Other environments follow the same pattern
cd environments/prod
sops terraform.tfvars.enc
sops backend.hcl.enc
```

**GitHub Secrets for CI/CD**:

```bash
# Set age private key for SOPS decryption
gh secret set SOPS_AGE_KEY --body "$(cat ~/.config/sops/age/r2-terraform-state.txt)"

# Environment-specific keys
gh secret set SOPS_AGE_KEY_PROD --body "$(cat ~/.config/sops/age/prod.txt)"
gh secret set SOPS_AGE_KEY_TALOS_CLUSTER --body "$(cat ~/.config/sops/age/talos-cluster.txt)"
```

**Module not found**:

```bash
terraform init -upgrade
```

**Resource import**:

```bash
# Import existing resource
terraform import module.network.digitalocean_vpc.main vpc-uuid-here

# Example: Import existing resource
terraform import resource_type.name resource-id
```

## Summary

The Terraform structure achieves:

✅ **Simplicity** - Two-tier architecture (modules + environments)
✅ **Clarity** - Clear separation of concerns
✅ **Reusability** - Pure modules used across environments
✅ **Flexibility** - Platform-specific patches without wrappers
✅ **Maintainability** - Easy to understand and modify
✅ **Best practices** - Following Terraform conventions

## Related Documentation

- [Talos Cluster Environment](environments/talos-cluster/README.md)
- [R2 State Backend](environments/r2-terraform-state/README.md)
- [ADR-0002: Terraform as Primary IaC Tool](../docs/decisions/0002-terraform-primary-tool.md)
- [ADR-0008: Secret Management Strategy](../docs/decisions/0008-secret-management.md)
- [Network Specifications](../specs/network/)
- [Security Specifications](../specs/security/)
