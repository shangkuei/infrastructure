# Terraform Infrastructure

This directory contains Terraform configurations for provisioning and managing hybrid cloud infrastructure.

## Structure

```
terraform/
├── modules/            # Reusable Terraform modules
│   ├── talos-cluster/       # Talos Kubernetes cluster
│   ├── cloudflare-r2/       # Cloudflare R2 bucket
│   ├── digitalocean-vpc/    # DigitalOcean VPC
│   ├── digitalocean-doks/   # DigitalOcean Kubernetes
│   ├── oracle-vcn/          # Oracle Cloud VCN
│   └── oracle-oke/          # Oracle Kubernetes Engine
│
└── environments/           # Environment deployments
    ├── r2-terraform-state/ # R2 backend for Terraform state
    ├── prod/               # Production (Oracle Cloud)
    └── unraid/             # Homelab Talos on Unraid
```

### Simple Two-Tier Architecture

- **modules/**: Reusable infrastructure components
- **environments/**: Actual deployments that use modules with environment-specific configuration

**Key principle**: Environments reference modules directly and provide platform-specific patches/variables

## State Backend Setup

**First Step**: Deploy the Terraform state backend before working with other environments.

The `r2-terraform-state` environment creates a Cloudflare R2 bucket for storing Terraform state remotely.

```bash
# Navigate to r2-terraform-state environment
cd environments/r2-terraform-state

# Generate age encryption key
make age-keygen

# Configure Cloudflare credentials (encrypted with SOPS)
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
sops -e terraform.tfvars > terraform.tfvars.enc
rm terraform.tfvars

# Deploy R2 backend
make apply

# Configure backend credentials
cp backend.hcl.example backend.hcl
vim backend.hcl  # Add R2 access key and secret
make encrypt-backend
rm backend.hcl

# Migrate state to R2
make init  # Answer 'yes' when prompted
```

After deploying the state backend:

1. R2 bucket is created and ready
2. Backend credentials are encrypted with SOPS
3. Local state is migrated to R2 (self-hosting)
4. Other environments can use the same R2 bucket with their own state keys

See [environments/r2-terraform-state/README.md](environments/r2-terraform-state/README.md) for complete documentation.

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

| Aspect | Development | Staging | Production |
|--------|-------------|---------|------------|
| Auto-apply | Yes | Manual trigger | Manual approval |
| Instance size | Small | Medium | Large |
| HA | No | Partial | Full |
| Backup | Daily | Daily | Hourly |
| Cost optimization | Aggressive | Moderate | Reserved instances |

### Creating an Environment

Environments use provider configurations as modules:

```bash
# Example: Create new environment using Talos Unraid provider
mkdir -p environments/production-unraid
cd environments/production-unraid

# Create main.tf that uses provider module
cat > main.tf <<'EOF'
module "talos_unraid" {
  source = "../../providers/talos/unraid"

  cluster_name = "production-cluster"
  # ... configuration
}
EOF

# Copy configuration templates
cp ../homelab-unraid/variables.tf .
cp ../homelab-unraid/outputs.tf .
cp ../homelab-unraid/terraform.tfvars.example .

# Configure for your environment
vim terraform.tfvars.example
mv terraform.tfvars.example terraform.tfvars

# Initialize
terraform init

# Plan
terraform plan
```

### Example: Homelab Unraid Environment

See [environments/homelab-unraid/](environments/homelab-unraid/) for a complete example:

- Uses `providers/talos/unraid` module
- Configures Talos Kubernetes on Unraid VMs
- Integrates Tailscale VPN
- Includes complete documentation

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
5. Configure backend in other environments' `main.tf`

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

## Providers

Provider configurations are organized by cloud/platform provider in `providers/` directory. Each provider may contain:

- **modules/**: Reusable modules specific to the provider
- **Platform configs**: Platform-specific deployments (e.g., unraid, proxmox)
- **Backend configs**: Infrastructure services (e.g., r2-backend)

### Active Providers

#### Talos Linux (`providers/talos/`)

**Purpose**: Kubernetes clusters on various platforms

**Structure**:

```
providers/talos/
├── modules/cluster/    # Core Talos cluster module
├── unraid/            # Unraid VM platform
├── proxmox/           # Proxmox platform (future)
└── baremetal/         # Bare metal (future)
```

**Usage**:

```hcl
# In environment deployment
module "talos_unraid" {
  source = "../../providers/talos/unraid"

  cluster_name     = "my-cluster"
  cluster_endpoint = "https://192.168.1.100:6443"
  # ... configuration
}
```

**Documentation**:

- [Module README](providers/talos/modules/cluster/README.md)
- [Unraid Configuration](providers/talos/unraid/)
- [Deployment Guide](../docs/guides/talos-unraid-deployment-guide.md)

#### Cloudflare (`providers/cloudflare/`)

**Purpose**: Edge services and infrastructure

**Active Configurations**:

- `r2-backend/`: Terraform state storage with R2

**Documentation**: [R2 Backend README](providers/cloudflare/r2-backend/README.md)

### Future Providers

#### DigitalOcean (Primary Cloud - Future)

```hcl
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34"
    }
  }
}

provider "digitalocean" {
  token = var.digitalocean_token
}

# Example: DOKS Kubernetes Cluster
resource "digitalocean_kubernetes_cluster" "main" {
  name    = "production-cluster"
  region  = "nyc3"
  version = "1.28.2-do.0"

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-2gb"  # $12/month per node
    node_count = 2
    auto_scale = true
    min_nodes  = 2
    max_nodes  = 5
  }

  tags = ["production", "kubernetes"]
}

# Example: Droplet (VM)
resource "digitalocean_droplet" "web" {
  name   = "web-server"
  region = "nyc3"
  size   = "s-1vcpu-1gb"  # $6/month
  image  = "ubuntu-22-04-x64"

  tags = ["web", "production"]
}

# Example: Load Balancer
resource "digitalocean_loadbalancer" "public" {
  name   = "public-lb"
  region = "nyc3"

  forwarding_rule {
    entry_port     = 443
    entry_protocol = "https"

    target_port     = 80
    target_protocol = "http"

    certificate_name = digitalocean_certificate.cert.name
  }

  healthcheck {
    port     = 80
    protocol = "http"
    path     = "/health"
  }

  droplet_ids = [digitalocean_droplet.web.id]
}

# Example: Spaces (Object Storage)
resource "digitalocean_spaces_bucket" "terraform_state" {
  name   = "my-terraform-state"
  region = "nyc3"
  acl    = "private"
}
```

**Features**:

- DOKS (Managed Kubernetes) with free control plane
- Droplets (VMs) starting at $6/month
- Load Balancers ($12/month)
- Spaces (S3-compatible object storage) for application storage
- Block Storage for persistent volumes
- VPC networking for isolation
- Managed Databases (PostgreSQL, MySQL, Redis)

**Note**: Terraform state is stored in Cloudflare R2, not DigitalOcean Spaces (see State Management section)

**Required Secrets**:

```bash
# Set DigitalOcean token
export TF_VAR_digitalocean_token="your-do-token"
# Or use GitHub Secrets for CI/CD
gh secret set DIGITALOCEAN_TOKEN
```

### Talos Provider Examples (Legacy - See Active Providers Section)

**Note**: Talos configurations have been reorganized under `providers/talos/`. See the [Active Providers](#active-providers) section above for current structure.

For Talos deployments, use the provider configurations:

```hcl
# Use Talos Unraid provider in an environment
module "talos_unraid" {
  source = "../../providers/talos/unraid"
  # Configuration handled by provider module
}
```

**See**:

- [providers/talos/](providers/talos/) - Current Talos provider structure
- [environments/homelab-unraid/](environments/homelab-unraid/) - Example deployment

### Cloudflare Provider (Edge Services)

```hcl
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Example: DNS Zone
resource "cloudflare_zone" "domain" {
  zone = "example.com"
  plan = "free"
}

# Example: DNS Record pointing to DigitalOcean Load Balancer
resource "cloudflare_record" "www" {
  zone_id = cloudflare_zone.domain.id
  name    = "www"
  value   = digitalocean_loadbalancer.public.ip
  type    = "A"
  proxied = true
}

# Example: Email Routing
resource "cloudflare_email_routing_settings" "domain" {
  zone_id = cloudflare_zone.domain.id
  enabled = true
}

resource "cloudflare_email_routing_rule" "admin" {
  zone_id = cloudflare_zone.domain.id
  name    = "Admin email routing"
  enabled = true

  matcher {
    type  = "literal"
    field = "to"
    value = "admin@example.com"
  }

  action {
    type  = "forward"
    value = ["personal.email@gmail.com"]
  }
}
```

**Features**:

- DNS management with DNSSEC
- Email routing configuration
- SSL/TLS certificate management
- CDN and security settings
- Workers deployment

**Required Secrets**:

```bash
# Create scoped API token in Cloudflare dashboard
# Permissions: Zone.DNS (Edit), Zone.Email Routing (Edit), Zone.SSL (Edit)
gh secret set CLOUDFLARE_API_TOKEN

# Or use in terraform.tfvars (gitignored)
cloudflare_api_token = "your-api-token-here"
```

See [Cloudflare Services Specification](../specs/cloudflare/cloudflare-services.md) for detailed configuration and [ADR-0004](../docs/decisions/0004-cloudflare-dns-services.md) for implementation rationale.

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

- `prod-web-alb`
- `staging-app-asg`
- `dev-data-rds`

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

### Code Organization

- Keep modules focused and reusable
- Use consistent naming conventions
- Document all variables and outputs
- Version pin all providers and modules

### State Management

- Always use remote state for team environments
- Enable state locking
- Never commit state files to version control
- Back up state files regularly

### Security

- Mark sensitive variables as sensitive
- Never commit .tfvars files with secrets
- Use encryption for state files
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
```

**Module not found**:

```bash
terraform init -upgrade
```

**Resource import**:

```bash
# Import existing DigitalOcean resource
terraform import module.network.digitalocean_vpc.main vpc-uuid-here

# Example: Import existing Droplet
terraform import digitalocean_droplet.web 12345678
```

## Related Documentation

- [Module Development Guide](modules/README.md)
- [Environment Setup](environments/README.md)
- [Provider Configurations](providers/README.md)
- [ADR-0002: Terraform as Primary IaC Tool](../docs/decisions/0002-terraform-primary-tool.md)
- [Network Specifications](../specs/network/)
- [Security Specifications](../specs/security/)
