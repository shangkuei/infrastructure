# Cloudflared Unraid Environment - Makefile
# Manages Cloudflared tunnel configuration with SOPS encryption

.DEFAULT_GOAL := help

# ============================================================================
# SOPS Configuration
# ============================================================================

SOPS_DOMAIN := terraform
SOPS_ENV_NAME := cloudflared-unraid
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

.PHONY: workflow
workflow: tf-workflow ## Show SOPS setup workflow
	@:

# ============================================================================
# Help Target (AWK-based)
# ============================================================================

##@ General

.PHONY: help
help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "Run 'make tf-help' for detailed Terraform operations"
	@echo "Run 'make sops-help' for SOPS operations"
