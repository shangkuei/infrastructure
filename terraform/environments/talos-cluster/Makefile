# Talos Cluster Environment - Makefile
# Manages Talos Kubernetes cluster configuration generation and deployment

.DEFAULT_GOAL := help

# ============================================================================
# SOPS Configuration
# ============================================================================

SOPS_DOMAIN := terraform
SOPS_ENV_NAME := talos-cluster
SOPS_KEY_STRATEGY := central

# ============================================================================
# Terraform Configuration
# ============================================================================

# Override default encrypted file names (legacy format)
TF_TFVARS_ENC := terraform.enc.tfvars
TF_BACKEND_ENC := backend.enc.hcl

# Talos-specific configuration
GENERATED_DIR := generated
TALOSCONFIG := $(GENERATED_DIR)/talosconfig
KUBECONFIG := $(GENERATED_DIR)/kubeconfig

# ============================================================================
# Include Shared Makefiles
# ============================================================================

include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk
include ../../../makefiles/talos.mk

# ============================================================================
# Override Standard Targets
# ============================================================================

# Override apply to show next steps
.PHONY: apply
apply: tf-apply ## Generate cluster configurations
	@echo "$(_SOPS_GREEN)✓ Configurations generated in $(GENERATED_DIR)/$(_SOPS_NC)"
	@echo ""
	@echo "$(_SOPS_YELLOW)Next steps:$(_SOPS_NC)"
	@echo "  1. make talos-apply          # Apply configs to nodes"
	@echo "  2. make talos-bootstrap      # Bootstrap Kubernetes cluster"
	@echo "  3. make talos-health         # Check cluster health"

# Override clean to remove generated directory
.PHONY: clean
clean: ## Remove generated directory and Terraform files
	@echo "$(_SOPS_YELLOW)Removing generated files...$(_SOPS_NC)"
	@rm -rf $(GENERATED_DIR)
	@rm -rf .terraform .terraform.lock.hcl
	@rm -f terraform.tfstate terraform.tfstate.backup
	@echo "$(_SOPS_GREEN)✓ Clean complete$(_SOPS_NC)"

# ============================================================================
# Workflow
# ============================================================================

##@ Workflow

.PHONY: all
all: init apply talos-apply talos-bootstrap talos-health ## Complete cluster setup
	@echo ""
	@echo "$(_SOPS_GREEN)========================================"
	@echo "Cluster deployment complete!"
	@echo "========================================$(_SOPS_NC)"
	@echo ""
	@echo "Access the cluster:"
	@echo "  export TALOSCONFIG=$$(pwd)/$(TALOSCONFIG)"
	@echo "  export KUBECONFIG=$$(pwd)/$(KUBECONFIG)"

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
	@echo "Run 'make tf-help' for Terraform operations"
	@echo "Run 'make sops-help' for SOPS operations"
	@echo "Run 'make talos-help' for Talos operations"
