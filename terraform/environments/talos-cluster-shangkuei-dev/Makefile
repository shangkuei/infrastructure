# Talos Shangkuei Dev Cluster - Makefile
# Manages Talos Kubernetes cluster configuration generation and deployment

.DEFAULT_GOAL := help

# ============================================================================
# SOPS Configuration
# ============================================================================

SOPS_DOMAIN := terraform
SOPS_ENV_NAME := talos-cluster-shangkuei-dev
SOPS_KEY_STRATEGY := central

# ============================================================================
# Terraform Configuration
# ============================================================================

# Override default encrypted file names (legacy format)
TF_TFVARS_ENC := terraform.tfvars.enc
TF_BACKEND_ENC := backend.hcl.enc

# Talos-specific configuration
GENERATED_DIR := generated
TALOSCONFIG := $(GENERATED_DIR)/talosconfig
KUBECONFIG := $(GENERATED_DIR)/kubeconfig

# ============================================================================
# Include Shared Makefiles
# ============================================================================

include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk

# ============================================================================
# Override Standard Targets
# ============================================================================

# Override apply to show next steps
.PHONY: apply
apply: tf-apply ## Generate cluster configurations
	@echo "$(_SOPS_GREEN)✓ Configurations generated in $(GENERATED_DIR)/$(_SOPS_NC)"
	@echo ""
	@echo "$(_SOPS_YELLOW)Next steps:$(_SOPS_NC)"
	@echo "  1. make apply-configs  # Apply configs to nodes"
	@echo "  2. make bootstrap      # Bootstrap Kubernetes cluster"
	@echo "  3. make health         # Check cluster health"

# Override clean to remove generated directory
.PHONY: clean
clean: ## Remove generated directory and Terraform files
	@echo "$(_SOPS_YELLOW)Removing generated files...$(_SOPS_NC)"
	@rm -rf $(GENERATED_DIR)
	@rm -rf .terraform .terraform.lock.hcl
	@rm -f terraform.tfstate terraform.tfstate.backup
	@echo "$(_SOPS_GREEN)✓ Clean complete$(_SOPS_NC)"

# ============================================================================
# Cluster Deployment
# ============================================================================

##@ Cluster Deployment

.PHONY: apply-configs
apply-configs: ## Apply Talos configs (NODE=<name>, INSECURE=true for initial)
	@if [ ! -d "$(GENERATED_DIR)" ]; then \
		echo "$(_SOPS_RED)Error: Configuration files not generated. Run 'make apply' first.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: talosconfig not found. Run 'make apply' first.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@export TALOSCONFIG=$(TALOSCONFIG); \
	INSECURE_FLAG=""; \
	if [ "$(INSECURE)" = "true" ]; then \
		INSECURE_FLAG="--insecure"; \
		echo "$(_SOPS_YELLOW)==> Using --insecure mode for initial setup$(_SOPS_NC)"; \
	fi; \
	if [ -n "$(NODE)" ]; then \
		echo "$(_SOPS_BLUE)Applying configuration to node: $(NODE)$(_SOPS_NC)"; \
		if [ -f "$(GENERATED_DIR)/control-plane-$(NODE).yaml" ]; then \
			NODE_TYPE="control-plane"; \
			BASE_CONFIG="$(GENERATED_DIR)/control-plane-$(NODE).yaml"; \
		elif [ -f "$(GENERATED_DIR)/worker-$(NODE).yaml" ]; then \
			NODE_TYPE="worker"; \
			BASE_CONFIG="$(GENERATED_DIR)/worker-$(NODE).yaml"; \
		else \
			echo "$(_SOPS_RED)Error: No configuration found for node '$(NODE)'$(_SOPS_NC)"; \
			echo "$(_SOPS_YELLOW)Available nodes:$(_SOPS_NC)"; \
			ls -1 $(GENERATED_DIR)/*-*.yaml 2>/dev/null | grep -E '(control-plane|worker)-[^-]+\.yaml$$' | sed 's/.*\/\(control-plane\|worker\)-\(.*\)\.yaml/  \2/' | sort -u; \
			exit 1; \
		fi; \
		echo "$(_SOPS_BLUE)==> Node type: $$NODE_TYPE$(_SOPS_NC)"; \
		OUTPUT_KEY=$$(echo "$$NODE_TYPE" | sed 's/-/_/g'); \
		NODE_IP=$$(terraform output -json generated_configs 2>/dev/null | jq -r ".[\"$$OUTPUT_KEY\"][\"$(NODE)\"].physical_ip // \"\"" || echo ""); \
		if [ -z "$$NODE_IP" ] || [ "$$NODE_IP" = "null" ]; then \
			echo "$(_SOPS_YELLOW)==> Could not determine node IP from terraform output$(_SOPS_NC)"; \
			read -p "Enter node IP address: " NODE_IP; \
		fi; \
		echo "$(_SOPS_BLUE)==> Applying to: $$NODE_IP$(_SOPS_NC)"; \
		echo "$(_SOPS_BLUE)==> Base config: $$BASE_CONFIG$(_SOPS_NC)"; \
		PATCH_FILES=$$(find $(GENERATED_DIR) -name "$$NODE_TYPE-$(NODE)-*.yaml" ! -name "$$NODE_TYPE-$(NODE).yaml" | sort); \
		PATCH_ARGS=""; \
		if [ -n "$$PATCH_FILES" ]; then \
			echo "$(_SOPS_BLUE)==> Patch files:$(_SOPS_NC)"; \
			for patch in $$PATCH_FILES; do \
				echo "  - $$patch"; \
				PATCH_ARGS="$$PATCH_ARGS --config-patch @$$patch"; \
			done; \
		else \
			echo "$(_SOPS_YELLOW)==> No patch files found$(_SOPS_NC)"; \
		fi; \
		talosctl apply-config $$INSECURE_FLAG --nodes $$NODE_IP --endpoints $$NODE_IP \
			--file $$BASE_CONFIG \
			$$PATCH_ARGS && \
		echo "$(_SOPS_GREEN)✓ Configuration applied to $(NODE)$(_SOPS_NC)" || \
		(echo "$(_SOPS_RED)✗ Failed to apply configuration to $(NODE)$(_SOPS_NC)"; exit 1); \
	else \
		echo "$(_SOPS_BLUE)Applying configurations to all nodes...$(_SOPS_NC)"; \
		for config in $(GENERATED_DIR)/control-plane-*.yaml; do \
			if [ -f "$$config" ]; then \
				BASE_NAME=$$(basename $$config); \
				if echo "$$BASE_NAME" | grep -q '^control-plane-[^-]\+\.yaml$$'; then \
					NODE_NAME=$$(echo "$$BASE_NAME" | sed 's/control-plane-\(.*\)\.yaml/\1/'); \
					NODE_IP=$$(terraform output -json generated_configs 2>/dev/null | jq -r ".[\"control_plane\"][\"$$NODE_NAME\"].physical_ip // \"\"" || echo ""); \
					if [ -n "$$NODE_IP" ] && [ "$$NODE_IP" != "null" ]; then \
						echo "$(_SOPS_BLUE)==> Applying to control plane node $$NODE_NAME ($$NODE_IP)$(_SOPS_NC)"; \
						PATCH_FILES=$$(find $(GENERATED_DIR) -name "control-plane-$$NODE_NAME-*.yaml" | sort); \
						PATCH_ARGS=""; \
						for patch in $$PATCH_FILES; do \
							PATCH_ARGS="$$PATCH_ARGS --config-patch @$$patch"; \
						done; \
						talosctl apply-config $$INSECURE_FLAG --nodes $$NODE_IP --endpoints $$NODE_IP \
							--file $$config \
							$$PATCH_ARGS && \
						echo "$(_SOPS_GREEN)✓ Applied to $$NODE_NAME$(_SOPS_NC)" || \
						echo "$(_SOPS_RED)✗ Failed to apply to $$NODE_NAME$(_SOPS_NC)"; \
					fi; \
				fi; \
			fi; \
		done; \
		for config in $(GENERATED_DIR)/worker-*.yaml; do \
			if [ -f "$$config" ]; then \
				BASE_NAME=$$(basename $$config); \
				if echo "$$BASE_NAME" | grep -q '^worker-[^-]\+\.yaml$$'; then \
					NODE_NAME=$$(echo "$$BASE_NAME" | sed 's/worker-\(.*\)\.yaml/\1/'); \
					NODE_IP=$$(terraform output -json generated_configs 2>/dev/null | jq -r ".[\"worker\"][\"$$NODE_NAME\"].physical_ip // \"\"" || echo ""); \
					if [ -n "$$NODE_IP" ] && [ "$$NODE_IP" != "null" ]; then \
						echo "$(_SOPS_BLUE)==> Applying to worker node $$NODE_NAME ($$NODE_IP)$(_SOPS_NC)"; \
						PATCH_FILES=$$(find $(GENERATED_DIR) -name "worker-$$NODE_NAME-*.yaml" | sort); \
						PATCH_ARGS=""; \
						for patch in $$PATCH_FILES; do \
							PATCH_ARGS="$$PATCH_ARGS --config-patch @$$patch"; \
						done; \
						talosctl apply-config $$INSECURE_FLAG --nodes $$NODE_IP --endpoints $$NODE_IP \
							--file $$config \
							$$PATCH_ARGS && \
						echo "$(_SOPS_GREEN)✓ Applied to $$NODE_NAME$(_SOPS_NC)" || \
						echo "$(_SOPS_RED)✗ Failed to apply to $$NODE_NAME$(_SOPS_NC)"; \
					fi; \
				fi; \
			fi; \
		done; \
		echo "$(_SOPS_GREEN)✓ All configurations applied$(_SOPS_NC)"; \
	fi

.PHONY: bootstrap
bootstrap: ## Bootstrap Kubernetes (NODE=<ip> optional)
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: talosconfig not found. Run 'make apply' first.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@export TALOSCONFIG=$(TALOSCONFIG); \
	if [ -n "$(NODE)" ]; then \
		BOOTSTRAP_NODE="$(NODE)"; \
	else \
		FIRST_CP=$$(terraform output -json generated_configs 2>/dev/null | jq -r '.control_plane | keys[0]' || echo ""); \
		if [ -z "$$FIRST_CP" ]; then \
			echo "$(_SOPS_RED)Error: Could not determine bootstrap node$(_SOPS_NC)"; \
			echo "$(_SOPS_YELLOW)Specify manually: make bootstrap NODE=<node-ip>$(_SOPS_NC)"; \
			exit 1; \
		fi; \
		BOOTSTRAP_NODE=$$(terraform output -json generated_configs 2>/dev/null | jq -r ".control_plane[\"$$FIRST_CP\"].physical_ip // \"\"" || echo ""); \
		if [ -z "$$BOOTSTRAP_NODE" ] || [ "$$BOOTSTRAP_NODE" = "null" ]; then \
			echo "$(_SOPS_RED)Error: Could not determine bootstrap node IP$(_SOPS_NC)"; \
			echo "$(_SOPS_YELLOW)Specify manually: make bootstrap NODE=<node-ip>$(_SOPS_NC)"; \
			exit 1; \
		fi; \
		echo "$(_SOPS_BLUE)==> Using first control plane node: $$FIRST_CP ($$BOOTSTRAP_NODE)$(_SOPS_NC)"; \
	fi; \
	echo "$(_SOPS_BLUE)Bootstrapping Kubernetes cluster on $$BOOTSTRAP_NODE...$(_SOPS_NC)"; \
	talosctl bootstrap --nodes $$BOOTSTRAP_NODE --endpoints $$BOOTSTRAP_NODE && \
	echo "$(_SOPS_GREEN)✓ Cluster bootstrapped successfully$(_SOPS_NC)" || \
	(echo "$(_SOPS_RED)✗ Bootstrap failed$(_SOPS_NC)"; exit 1)

# ============================================================================
# Cluster Access
# ============================================================================

##@ Cluster Access

.PHONY: kubeconfig
kubeconfig: ## Retrieve kubeconfig (NODE=<ip> optional)
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: talosconfig not found. Run 'make apply' first.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@export TALOSCONFIG=$(TALOSCONFIG); \
	if [ -n "$(NODE)" ]; then \
		KUBECONFIG_NODE="$(NODE)"; \
	else \
		FIRST_CP=$$(terraform output -json generated_configs 2>/dev/null | jq -r '.control_plane | keys[0]' || echo ""); \
		if [ -z "$$FIRST_CP" ]; then \
			echo "$(_SOPS_RED)Error: Could not determine control plane node$(_SOPS_NC)"; \
			echo "$(_SOPS_YELLOW)Specify manually: make kubeconfig NODE=<node-ip>$(_SOPS_NC)"; \
			exit 1; \
		fi; \
		KUBECONFIG_NODE=$$(terraform output -json generated_configs 2>/dev/null | jq -r ".control_plane[\"$$FIRST_CP\"].physical_ip // \"\"" || echo ""); \
		if [ -z "$$KUBECONFIG_NODE" ] || [ "$$KUBECONFIG_NODE" = "null" ]; then \
			echo "$(_SOPS_RED)Error: Could not determine control plane node IP$(_SOPS_NC)"; \
			echo "$(_SOPS_YELLOW)Specify manually: make kubeconfig NODE=<node-ip>$(_SOPS_NC)"; \
			exit 1; \
		fi; \
		echo "$(_SOPS_BLUE)==> Using control plane node: $$FIRST_CP ($$KUBECONFIG_NODE)$(_SOPS_NC)"; \
	fi; \
	echo "$(_SOPS_BLUE)Retrieving kubeconfig from $$KUBECONFIG_NODE...$(_SOPS_NC)"; \
	mkdir -p $$(dirname $(KUBECONFIG)); \
	talosctl kubeconfig --nodes $$KUBECONFIG_NODE --endpoints $$KUBECONFIG_NODE --force $(KUBECONFIG) && \
	echo "$(_SOPS_GREEN)✓ Kubeconfig retrieved$(_SOPS_NC)" && \
	echo "" && \
	echo "export KUBECONFIG=$$(pwd)/$(KUBECONFIG)" || \
	(echo "$(_SOPS_RED)✗ Failed to retrieve kubeconfig$(_SOPS_NC)"; exit 1)

.PHONY: talosconfig
talosconfig: ## Export talosconfig path
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: talosconfig not found. Run 'make apply' first.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "export TALOSCONFIG=$$(pwd)/$(TALOSCONFIG)"

.PHONY: env
env: kubeconfig talosconfig ## Display environment exports

# ============================================================================
# CNI Deployment
# ============================================================================

##@ CNI Deployment

.PHONY: deploy-cilium
deploy-cilium: ## Deploy Cilium CNI using Helm
	@if [ ! -f "$(KUBECONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: kubeconfig not found. Run 'make kubeconfig' first.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(GENERATED_DIR)/cilium-values.yaml" ]; then \
		echo "$(_SOPS_RED)Error: Cilium values file not found.$(_SOPS_NC)"; \
		echo "$(_SOPS_YELLOW)Set cni_name='cilium' in terraform.tfvars and run 'make apply' first.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@if ! command -v helm >/dev/null 2>&1; then \
		echo "$(_SOPS_RED)Error: helm is not installed$(_SOPS_NC)"; \
		echo "Install: brew install helm"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)Deploying Cilium CNI...$(_SOPS_NC)"
	@export KUBECONFIG=$(KUBECONFIG) && \
		helm repo add cilium https://helm.cilium.io/ && \
		helm repo update && \
		helm upgrade --install cilium cilium/cilium \
			--namespace kube-system \
			--values $(GENERATED_DIR)/cilium-values.yaml \
			--wait && \
		echo "$(_SOPS_GREEN)✓ Cilium deployed$(_SOPS_NC)" || \
		(echo "$(_SOPS_RED)✗ Cilium deployment failed$(_SOPS_NC)"; exit 1)

# ============================================================================
# Cluster Status
# ============================================================================

##@ Cluster Status

.PHONY: health
health: ## Check cluster health
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: talosconfig not found.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)Checking cluster health...$(_SOPS_NC)"
	@export TALOSCONFIG=$(TALOSCONFIG) && talosctl health --wait-timeout=10m

.PHONY: nodes
nodes: ## List cluster nodes
	@if [ ! -f "$(KUBECONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: kubeconfig not found.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)Cluster nodes:$(_SOPS_NC)"
	@export KUBECONFIG=$(KUBECONFIG) && kubectl get nodes -o wide

.PHONY: pods
pods: ## List all pods
	@if [ ! -f "$(KUBECONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: kubeconfig not found.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)All pods:$(_SOPS_NC)"
	@export KUBECONFIG=$(KUBECONFIG) && kubectl get pods -A

.PHONY: status
status: health nodes pods ## Complete cluster status

# ============================================================================
# Maintenance
# ============================================================================

##@ Maintenance

.PHONY: upgrade-k8s
upgrade-k8s: ## Upgrade Kubernetes (VERSION=v1.32.0)
	@if [ -z "$(VERSION)" ]; then \
		echo "$(_SOPS_RED)Error: VERSION required. Usage: make upgrade-k8s VERSION=v1.32.0$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_YELLOW)Upgrading Kubernetes to $(VERSION)...$(_SOPS_NC)"
	@export TALOSCONFIG=$(TALOSCONFIG) && talosctl upgrade-k8s --to $(VERSION)

.PHONY: upgrade-talos
upgrade-talos: ## Upgrade Talos (VERSION= NODE= required)
	@if [ -z "$(VERSION)" ]; then \
		echo "$(_SOPS_RED)Error: VERSION required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@if [ -z "$(NODE)" ]; then \
		echo "$(_SOPS_RED)Error: NODE required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_YELLOW)Upgrading Talos on $(NODE) to $(VERSION)...$(_SOPS_NC)"
	@export TALOSCONFIG=$(TALOSCONFIG) && \
		talosctl upgrade --nodes $(NODE) --image ghcr.io/siderolabs/installer:$(VERSION)

.PHONY: dashboard
dashboard: ## Open Talos dashboard (NODE= required)
	@if [ -z "$(NODE)" ]; then \
		echo "$(_SOPS_RED)Error: NODE required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@export TALOSCONFIG=$(TALOSCONFIG) && talosctl -n $(NODE) dashboard

.PHONY: logs
logs: ## View node logs (NODE= SERVICE= required)
	@if [ -z "$(NODE)" ]; then \
		echo "$(_SOPS_RED)Error: NODE required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(_SOPS_RED)Error: SERVICE required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@export TALOSCONFIG=$(TALOSCONFIG) && talosctl -n $(NODE) logs $(SERVICE)

.PHONY: reset-node
reset-node: ## Reset a Talos node (NODE= required)
	@if [ -z "$(NODE)" ]; then \
		echo "$(_SOPS_RED)Error: NODE required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_RED)WARNING: This will wipe the node at $(NODE)!$(_SOPS_NC)"
	@printf "Press Enter to continue or Ctrl+C to cancel: "; read confirm
	@export TALOSCONFIG=$(TALOSCONFIG) && talosctl -n $(NODE) reset --graceful=false --reboot

# ============================================================================
# Workflow
# ============================================================================

##@ Workflow

.PHONY: all
all: init apply apply-configs bootstrap health ## Complete cluster setup
	@echo ""
	@echo "$(_SOPS_GREEN)========================================"
	@echo "Cluster deployment complete!"
	@echo "========================================$(_SOPS_NC)"
	@echo ""
	@echo "Access the cluster:"
	@echo "  export TALOSCONFIG=$$(pwd)/$(TALOSCONFIG)"
	@echo "  export KUBECONFIG=$$(pwd)/$(KUBECONFIG)"

.PHONY: workflow
workflow: ## Show deployment workflow
	@echo ""
	@echo "$(_SOPS_BOLD)Talos Cluster Deployment Workflow$(_SOPS_NC)"
	@echo "========================================"
	@echo ""
	@echo "$(_SOPS_YELLOW)Initial Setup:$(_SOPS_NC)"
	@echo "  1. make init"
	@echo "  2. make apply"
	@echo ""
	@echo "$(_SOPS_YELLOW)Cluster Deployment (Two-Phase):$(_SOPS_NC)"
	@echo "  3. make apply-configs INSECURE=true"
	@echo "  4. [Wait for Tailscale join]"
	@echo "  5. [Update terraform.tfvars with Tailscale IPs]"
	@echo "  6. make apply"
	@echo "  7. make apply-configs"
	@echo "  8. make bootstrap"
	@echo ""
	@echo "$(_SOPS_YELLOW)CNI Deployment (if Cilium):$(_SOPS_NC)"
	@echo "  9. make kubeconfig"
	@echo "  10. make deploy-cilium"
	@echo ""
	@echo "$(_SOPS_YELLOW)Verification:$(_SOPS_NC)"
	@echo "  make health"
	@echo "  make nodes"
	@echo "  make pods"

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
