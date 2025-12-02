# Shared Makefiles

This directory contains shared Makefile includes that provide standardized operations across the infrastructure repository.

## Available Includes

### sops.mk - Unified SOPS Operations

Provides standardized secret management operations using SOPS with age encryption.

**Specification**: [specs/security/unified-sops-operations.md](../specs/security/unified-sops-operations.md)

### terraform.mk - Terraform Operations

Provides standardized Terraform operations with SOPS integration for encrypted tfvars and backend configuration.

**Requires**: `sops.mk` (must be included first)

## Usage

Include the shared Makefile in your domain Makefile:

```makefile
# At the top of your Makefile, set required variables
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := my-environment

# Include the shared operations
include ../../../makefiles/sops.mk

# Your domain-specific targets follow...
```

## sops.mk Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SOPS_DOMAIN` | Domain identifier | `terraform`, `kubernetes`, `docker` |
| `SOPS_ENV_NAME` | Environment name (used for key naming) | `talos-cluster-dev` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SOPS_KEY_STRATEGY` | `central` | Key location: `central` (~/.config/sops/age/) or `local` (./age-key.txt) |
| `SOPS_AGE_DIR` | `~/.config/sops/age` | Central key storage directory |
| `SOPS_LOCAL_KEY` | `age-key.txt` | Local key filename |
| `SOPS_CONFIG` | `.sops.yaml` | SOPS configuration filename |
| `SOPS_EDITOR` | `$EDITOR` or `vim` | Editor for `sops-edit` |
| `SOPS_COLOR` | `true` | Enable colored output |

### Available Targets

#### Tier 1: Universal (All Domains)

```bash
make sops-help          # Show help for SOPS operations
make sops-check-deps    # Verify sops and age are installed
make sops-check-config  # Verify .sops.yaml exists and is valid
make sops-info          # Display encryption configuration
make sops-validate      # Validate all encrypted files can be decrypted
```

#### Tier 2: Key Management

```bash
make sops-keygen                           # Generate new age key pair
make sops-import-key AGE_KEY_FILE=/path    # Import existing age key
make sops-export-public                    # Export public key for sharing
make sops-rotate-key                       # Show key rotation procedure
```

#### Tier 3: Encryption Operations

```bash
make sops-encrypt FILE=secrets.yaml    # Encrypt a file in-place
make sops-decrypt FILE=secrets.yaml    # Decrypt file to stdout
make sops-edit FILE=secrets.yaml       # Edit encrypted file
make sops-rekey FILE=secrets.yaml      # Re-encrypt with current config
make sops-clean                        # Remove temporary/decrypted files
```

### Key Strategies

#### Central Strategy (Terraform Default)

Keys stored in user's home directory:

```
~/.config/sops/age/
├── talos-cluster.txt         # Private key (chmod 600)
├── talos-cluster.txt.pub     # Public key (chmod 644)
└── ...
```

Best for:

- Terraform environments with static `.sops.yaml`
- Shared development machines
- Keys that need to be reused across sessions

#### Local Strategy (Kubernetes/Docker Default)

Keys stored in the environment directory:

```
kubernetes/overlays/flux-instance/dev/
├── age-key.txt               # Private key (gitignored)
├── .sops.yaml                # Generated config
└── *.yaml.enc                # Encrypted files
```

Best for:

- Environments with dynamically generated `.sops.yaml`
- CI/CD pipelines that inject keys
- Isolated per-environment keys

## terraform.mk Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SOPS_DOMAIN` | Domain identifier | `terraform` |
| `SOPS_ENV_NAME` | Environment name | `talos-cluster-dev` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TF_TFVARS_ENC` | `terraform.tfvars.enc` | Encrypted tfvars filename |
| `TF_TFVARS_PLAIN` | `terraform.tfvars` | Plain tfvars filename |
| `TF_BACKEND_HCL` | `backend.hcl` | Plain backend config filename |
| `TF_BACKEND_ENC` | `backend.hcl.enc` | Encrypted backend config filename |
| `TF_AUTO_INIT` | `false` | Auto-run init before plan/apply |

### Available Targets

#### Core Terraform Operations

```bash
make tf-init             # Initialize Terraform with encrypted backend
make tf-plan             # Show plan using encrypted tfvars
make tf-apply            # Apply changes using encrypted tfvars
make tf-destroy          # Destroy resources using encrypted tfvars
make tf-validate         # Validate configuration
make tf-fmt              # Format Terraform files
make tf-lint             # Run tflint (if available)
make tf-upgrade          # Upgrade providers
make tf-output           # Show Terraform outputs
make tf-clean            # Remove .terraform and lock files
make tf-help             # Show Terraform operations help
```

#### SOPS Integration

```bash
make tf-encrypt-backend  # Encrypt backend.hcl
make tf-encrypt-tfvars   # Encrypt terraform.tfvars
make tf-edit-backend     # Edit encrypted backend.hcl
make tf-edit-tfvars      # Edit encrypted terraform.tfvars
make tf-sops-validate    # Validate encrypted Terraform files
```

### Usage Example

```makefile
# SOPS configuration
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := my-environment
SOPS_KEY_STRATEGY := central

# Optional: Override encrypted file names (legacy format)
TF_TFVARS_ENC := terraform.enc.tfvars
TF_BACKEND_ENC := backend.enc.hcl

# Include shared operations
include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk

# Environment-specific targets can be added below...
```

## Domain-Specific Extensions

Each domain can extend the base includes with additional targets.

### Terraform with Talos Example

```makefile
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := talos-cluster-dev
SOPS_KEY_STRATEGY := central

include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk

# Talos-specific operations
.PHONY: kubeconfig
kubeconfig: ## Get kubeconfig for the cluster
 @terraform output -raw kubeconfig > kubeconfig
```

### Terraform with Flux Example

```makefile
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := talos-gitops-dev
SOPS_KEY_STRATEGY := central

# Flux uses separate key from Terraform
AGE_FLUX_PRIVATE_KEY := $(SOPS_AGE_DIR)/talos-gitops-dev-flux.txt

include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk

# Generate both Terraform and Flux keys
.PHONY: age-keygen
age-keygen: sops-keygen flux-keygen
 @echo "Both keys generated"

# Flux-specific key generation
.PHONY: flux-keygen
flux-keygen: sops-check-deps
 @age-keygen -o $(AGE_FLUX_PRIVATE_KEY)
```

### Kubernetes Example

```makefile
SOPS_DOMAIN := kubernetes
SOPS_ENV_NAME := flux-dev
SOPS_KEY_STRATEGY := local

include ../../../../makefiles/sops.mk

.PHONY: sops-secret-age
sops-secret-age: sops-check-deps
 @# Generate Kubernetes secret containing the age key
 @echo "apiVersion: v1" > secret-sops-age.yaml
 @# ... (create manifest)
 @SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --encrypt --in-place secret-sops-age.yaml
```

### Docker Example

```makefile
SOPS_DOMAIN := docker
SOPS_ENV_NAME := gitea-unraid
SOPS_KEY_STRATEGY := local

include ../../../../makefiles/sops.mk

.PHONY: sops-edit-env
sops-edit-env: sops-check-deps
 @EDITOR="$(SOPS_EDITOR)" SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops .env
```

## Helper Functions

The sops.mk provides helper functions for domain Makefiles:

```makefile
# Check if file is encrypted
$(call sops_is_encrypted,filename)  # Returns: true or false

# Get public key from private key
$(call sops_get_public_key,keyfile)  # Returns: age1...

# Generate .sops.yaml header
$(call sops_config_header)

# Add creation rule to .sops.yaml
$(call sops_add_rule,path_regex,age_key,[encrypted_regex])
```

## Backward Compatibility

The following aliases are provided for compatibility with existing Makefiles:

| Old Target | New Target |
|------------|------------|
| `age-keygen` | `sops-keygen` |
| `age-info` | `sops-info` |

Domain Makefiles should define their own aliases for domain-specific targets (e.g., `encrypt-backend` → `sops-encrypt-backend`).

## Security Notes

1. **Never commit private keys** - Only `.sops.yaml` (public keys) should be in Git
2. **Use `.gitignore`** - Ensure `age-key.txt` and `*.txt` in key directories are ignored
3. **Backup keys** - Store private keys in a password manager
4. **Rotate keys** - Follow the rotation procedure in the runbook

## Related Documentation

- [ADR-0008: Secret Management Strategy](../docs/decisions/0008-secret-management.md)
- [Runbook: SOPS Secret Management](../docs/runbooks/0008-sops-secret-management.md)
- [Spec: Unified SOPS Operations](../specs/security/unified-sops-operations.md)
