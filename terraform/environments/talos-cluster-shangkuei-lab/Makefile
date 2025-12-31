# Talos Shangkuei Lab Cluster - Makefile
# Manages Talos Kubernetes cluster configuration generation and deployment

.DEFAULT_GOAL := help

# ============================================================================
# SOPS Configuration
# ============================================================================

SOPS_DOMAIN := terraform
SOPS_ENV_NAME := talos-cluster-shangkuei-lab
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

# Cilium configuration
CILIUM_VALUES := $(GENERATED_DIR)/cilium-values.yaml
CILIUM_NAMESPACE := kube-system

# ============================================================================
# Include Shared Makefiles
# ============================================================================

include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk
include ../../../makefiles/talos.mk
include ../../../makefiles/helm.mk

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
	@echo "  3. make cilium-install       # Install Cilium CNI"
	@echo "  4. make talos-health         # Check cluster health"

# Override clean to remove generated directory
.PHONY: clean
clean: ## Remove generated directory and Terraform files
	@echo "$(_SOPS_YELLOW)Removing generated files...$(_SOPS_NC)"
	@rm -rf $(GENERATED_DIR)
	@rm -rf .terraform .terraform.lock.hcl
	@rm -f terraform.tfstate terraform.tfstate.backup
	@echo "$(_SOPS_GREEN)✓ Clean complete$(_SOPS_NC)"

# ============================================================================
# Cilium CNI Installation
# ============================================================================

##@ Cilium CNI

.PHONY: cilium-install
cilium-install: helm-check-deps helm-check-kubeconfig ## Install Cilium CNI using Helm
	@if [ ! -f "$(CILIUM_VALUES)" ]; then \
		echo "$(_SOPS_RED)Error: Cilium values file not found: $(CILIUM_VALUES)$(_SOPS_NC)"; \
		echo "Run 'make apply' first to generate the values file"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)Installing Cilium CNI...$(_SOPS_NC)"
	@$(MAKE) helm-install chart=cilium values=$(CILIUM_VALUES) ns=$(CILIUM_NAMESPACE)

.PHONY: cilium-upgrade
cilium-upgrade: helm-check-deps helm-check-kubeconfig ## Upgrade Cilium CNI
	@if [ ! -f "$(CILIUM_VALUES)" ]; then \
		echo "$(_SOPS_RED)Error: Cilium values file not found: $(CILIUM_VALUES)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)Upgrading Cilium CNI...$(_SOPS_NC)"
	@$(MAKE) helm-upgrade chart=cilium values=$(CILIUM_VALUES) ns=$(CILIUM_NAMESPACE)

.PHONY: cilium-uninstall
cilium-uninstall: helm-check-deps helm-check-kubeconfig ## Uninstall Cilium CNI
	@echo "$(_SOPS_YELLOW)Uninstalling Cilium CNI...$(_SOPS_NC)"
	@$(MAKE) helm-uninstall release=cilium ns=$(CILIUM_NAMESPACE)

.PHONY: cilium-status
cilium-status: helm-check-deps helm-check-kubeconfig ## Show Cilium installation status
	@$(MAKE) helm-status release=cilium ns=$(CILIUM_NAMESPACE)

.PHONY: cilium-connectivity-test
cilium-connectivity-test: helm-check-kubeconfig ## Run Cilium connectivity test
	@if ! command -v cilium >/dev/null 2>&1; then \
		echo "$(_SOPS_RED)Error: cilium CLI is not installed$(_SOPS_NC)"; \
		echo "Install: brew install cilium-cli"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)Running Cilium connectivity test...$(_SOPS_NC)"
	@export KUBECONFIG=$(KUBECONFIG); \
	cilium connectivity test

# ============================================================================
# Workflow
# ============================================================================

##@ Workflow

.PHONY: all
all: init apply talos-apply talos-bootstrap cilium-install talos-health ## Complete cluster setup
	@echo ""
	@echo "$(_SOPS_GREEN)========================================"
	@echo "Cluster deployment complete!"
	@echo "========================================$(_SOPS_NC)"
	@echo ""
	@echo "Access the cluster:"
	@echo "  export TALOSCONFIG=$$(pwd)/$(TALOSCONFIG)"
	@echo "  export KUBECONFIG=$$(pwd)/$(KUBECONFIG)"
	@echo ""
	@echo "Verify Cilium:"
	@echo "  make cilium-status"
	@echo "  make cilium-connectivity-test"

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
	@echo "Run 'make helm-help' for Helm operations"
