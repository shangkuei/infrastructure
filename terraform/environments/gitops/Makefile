# Talos GitOps Terraform Environment - Makefile
# Manages GitOps configuration with Flux and dual-key SOPS encryption

.DEFAULT_GOAL := help

# ============================================================================
# SOPS Configuration
# ============================================================================

SOPS_DOMAIN := terraform
SOPS_ENV_NAME := talos-gitops
SOPS_KEY_STRATEGY := central

# ============================================================================
# Terraform Configuration
# ============================================================================

# Override default encrypted file names (legacy format: prefix style)
TF_TFVARS_ENC := terraform.enc.tfvars
TF_BACKEND_ENC := backend.enc.hcl

# ============================================================================
# Include Shared Makefiles
# ============================================================================

include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk

# Flux age key (separate from Terraform key, for Kubernetes manifests)
# NOTE: Must be defined AFTER includes so SOPS_AGE_DIR is available
AGE_FLUX_PRIVATE_KEY := $(SOPS_AGE_DIR)/gitops-flux.txt
AGE_FLUX_PUBLIC_KEY := $(SOPS_AGE_DIR)/gitops-flux.txt.pub

# ============================================================================
# Dual Key Management (Terraform + Flux)
# ============================================================================

##@ Key Management

.PHONY: age-keygen
age-keygen: sops-keygen flux-keygen ## Generate both Terraform and Flux keys
	@echo ""
	@echo "$(_SOPS_GREEN)==> Both keys generated successfully$(_SOPS_NC)"
	@$(MAKE) --no-print-directory age-info
	@echo ""
	@echo "$(_SOPS_YELLOW)==> SECURITY WARNING$(_SOPS_NC)"
	@echo "1. Store private keys securely (password manager)"
	@echo "2. Never commit private keys to git"
	@echo "3. Terraform key: For local tfvars/backend encryption"
	@echo "4. Flux key: Add public key to .sops.yaml for K8s manifests"

.PHONY: flux-keygen
flux-keygen: sops-check-deps ## Generate Flux age key
	@echo ""
	@echo "$(_SOPS_BLUE)==> Generating Flux age encryption key$(_SOPS_NC)"
	@mkdir -p $(SOPS_AGE_DIR); \
	chmod 700 $(SOPS_AGE_DIR); \
	if [ -f $(AGE_FLUX_PRIVATE_KEY) ]; then \
		echo "$(_SOPS_YELLOW)==> Flux age key already exists$(_SOPS_NC)"; \
		printf "Overwrite? [y/N] "; \
		read -r confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo "$(_SOPS_GREEN)==> Using existing Flux key$(_SOPS_NC)"; \
			exit 0; \
		fi; \
	fi; \
	age-keygen -o $(AGE_FLUX_PRIVATE_KEY) && \
	chmod 600 $(AGE_FLUX_PRIVATE_KEY) && \
	age-keygen -y $(AGE_FLUX_PRIVATE_KEY) > $(AGE_FLUX_PUBLIC_KEY) && \
	chmod 644 $(AGE_FLUX_PUBLIC_KEY) && \
	echo "$(_SOPS_GREEN)==> Flux age key generated$(_SOPS_NC)"

.PHONY: flux-info
flux-info: ## Display Flux key information
	@if [ ! -f $(AGE_FLUX_PRIVATE_KEY) ]; then \
		echo "$(_SOPS_YELLOW)==> Flux key not found$(_SOPS_NC)"; \
		echo "  Expected: $(AGE_FLUX_PRIVATE_KEY)"; \
		echo "  Run: make flux-keygen"; \
	else \
		echo "$(_SOPS_GREEN)Flux Key (for Kubernetes manifests):$(_SOPS_NC)"; \
		echo "  Private: $(AGE_FLUX_PRIVATE_KEY)"; \
		echo "  Public:  $(AGE_FLUX_PUBLIC_KEY)"; \
		echo "  Key: $$(cat $(AGE_FLUX_PUBLIC_KEY))"; \
	fi

.PHONY: age-info
age-info: sops-info flux-info ## Display all key information

# ============================================================================
# Flux Operations
# ============================================================================

##@ Flux Operations

.PHONY: flux-check
flux-check: ## Check Flux installation
	@echo "$(_SOPS_BLUE)Checking Flux installation...$(_SOPS_NC)"
	@flux check

.PHONY: flux-version
flux-version: ## Show Flux version
	@echo "$(_SOPS_BLUE)Flux version:$(_SOPS_NC)"
	@flux version

.PHONY: flux-logs
flux-logs: ## Show Flux controller logs
	@echo "$(_SOPS_BLUE)Flux controller logs:$(_SOPS_NC)"
	@flux logs --level=info --all-namespaces

.PHONY: flux-reconcile
flux-reconcile: ## Force reconcile all Flux resources
	@echo "$(_SOPS_BLUE)Reconciling Flux resources...$(_SOPS_NC)"
	@flux reconcile source git flux-system
	@flux reconcile kustomization --all

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
