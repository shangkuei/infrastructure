# Makefile for Terraform State Backend Environment
# Manages R2 backend deployment with SOPS encryption

.DEFAULT_GOAL := help

# ============================================================================
# SOPS Configuration
# ============================================================================

SOPS_DOMAIN := terraform
SOPS_ENV_NAME := r2-terraform-state
SOPS_KEY_STRATEGY := central

# ============================================================================
# Terraform Configuration
# ============================================================================

# Override default encrypted file names (legacy format)
TF_TFVARS_ENC := terraform.enc.tfvars
TF_BACKEND_ENC := backend.enc.hcl

# ============================================================================
# Include Shared Makefiles
# ============================================================================

include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk

# ============================================================================
# Environment-Specific Targets
# ============================================================================

.PHONY: outputs
outputs: tf-output ## Show all outputs (alias for output)
	@:

# Override apply to show next steps
.PHONY: apply
apply: tf-apply ## Deploy R2 backend
	@echo ""
	@echo "$(_SOPS_YELLOW)Next steps:$(_SOPS_NC)"
	@echo "1. Review bucket outputs: make output"
	@echo "2. Create R2 API token at https://dash.cloudflare.com → R2 → Manage R2 API Tokens"
	@echo "3. Configure backend: cp backend.hcl.example backend.hcl && edit backend.hcl"
	@echo "4. Encrypt backend config: make tf-encrypt-backend && rm backend.hcl"
	@echo "5. Migrate state to R2: make init (answer 'yes' when prompted)"

# ============================================================================
# Help Target (AWK-based)
# ============================================================================

.PHONY: help
help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\n\033[1mR2 Terraform State Backend\033[0m\n\nUsage:\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "Run 'make tf-help' for detailed Terraform operations"
	@echo "Run 'make sops-help' for SOPS operations"
