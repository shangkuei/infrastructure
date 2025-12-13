# ============================================================================
# talos.mk - Unified Talos Cluster Operations
# ============================================================================
# Shared Makefile include for standardized Talos cluster management operations.
#
# Usage:
#   Include this file in your Talos environment Makefile after sops.mk and terraform.mk:
#     include ../../../makefiles/sops.mk
#     include ../../../makefiles/terraform.mk
#     include ../../../makefiles/talos.mk
#
# Required variables (set before including):
#   GENERATED_DIR        - Directory containing generated configs (default: generated)
#   TALOSCONFIG          - Path to talosconfig file (default: $(GENERATED_DIR)/talosconfig)
#   KUBECONFIG           - Path to kubeconfig file (default: $(GENERATED_DIR)/kubeconfig)
#
# Optional variables:
#   TALOS_WAIT_TIMEOUT   - Timeout for health checks (default: 10m)
#
# Reference:
#   docs/guides/talos-unraid-deployment-guide.md
# ============================================================================

# ============================================================================
# Default Configuration
# ============================================================================

GENERATED_DIR ?= generated
TALOSCONFIG ?= $(GENERATED_DIR)/talosconfig
KUBECONFIG ?= $(GENERATED_DIR)/kubeconfig
TALOS_WAIT_TIMEOUT ?= 10m

# ============================================================================
# Cluster Deployment
# ============================================================================

##@ Talos Cluster Deployment

.PHONY: talos-apply
talos-apply: ## Apply Talos configs (NODE=<name>, INSECURE=true, MODE=auto|reboot|no-reboot|staged)
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
	MODE_FLAG=""; \
	if [ "$(INSECURE)" = "true" ]; then \
		INSECURE_FLAG="--insecure"; \
		echo "$(_SOPS_YELLOW)==> Using --insecure mode for initial setup$(_SOPS_NC)"; \
	fi; \
	if [ -n "$(MODE)" ]; then \
		case "$(MODE)" in \
			auto|reboot|no-reboot|staged) \
				MODE_FLAG="--mode=$(MODE)"; \
				echo "$(_SOPS_YELLOW)==> Using --mode=$(MODE)$(_SOPS_NC)"; \
				;; \
			*) \
				echo "$(_SOPS_RED)Error: Invalid MODE '$(MODE)'. Valid options: auto, reboot, no-reboot, staged$(_SOPS_NC)"; \
				exit 1; \
				;; \
		esac; \
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
		talosctl apply-config $$INSECURE_FLAG $$MODE_FLAG --nodes $$NODE_IP --endpoints $$NODE_IP \
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
						talosctl apply-config $$INSECURE_FLAG $$MODE_FLAG --nodes $$NODE_IP --endpoints $$NODE_IP \
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
						talosctl apply-config $$INSECURE_FLAG $$MODE_FLAG --nodes $$NODE_IP --endpoints $$NODE_IP \
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

.PHONY: talos-bootstrap
talos-bootstrap: ## Bootstrap Kubernetes (NODE=<ip> optional)
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

##@ Talos Cluster Access

.PHONY: talos-kubeconfig
talos-kubeconfig: ## Retrieve kubeconfig (NODE=<ip> optional)
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

.PHONY: talos-talosconfig
talos-talosconfig: ## Export talosconfig path
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: talosconfig not found. Run 'make apply' first.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "export TALOSCONFIG=$$(pwd)/$(TALOSCONFIG)"

.PHONY: talos-env
talos-env: talos-kubeconfig talos-talosconfig ## Display environment exports

# ============================================================================
# Cluster Status
# ============================================================================

##@ Talos Cluster Status

.PHONY: talos-health
talos-health: ## Check cluster health
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: talosconfig not found.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)Checking cluster health...$(_SOPS_NC)"
	@export TALOSCONFIG=$(TALOSCONFIG) && talosctl health --wait-timeout=$(TALOS_WAIT_TIMEOUT)

.PHONY: talos-nodes
talos-nodes: ## List cluster nodes
	@if [ ! -f "$(KUBECONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: kubeconfig not found.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)Cluster nodes:$(_SOPS_NC)"
	@export KUBECONFIG=$(KUBECONFIG) && kubectl get nodes -o wide

.PHONY: talos-pods
talos-pods: ## List all pods
	@if [ ! -f "$(KUBECONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: kubeconfig not found.$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)All pods:$(_SOPS_NC)"
	@export KUBECONFIG=$(KUBECONFIG) && kubectl get pods -A

.PHONY: talos-status
talos-status: talos-health talos-nodes talos-pods ## Complete cluster status

# ============================================================================
# Maintenance
# ============================================================================

##@ Talos Maintenance

.PHONY: talos-upgrade-k8s
talos-upgrade-k8s: ## Upgrade Kubernetes (VERSION=v1.32.0)
	@if [ -z "$(VERSION)" ]; then \
		echo "$(_SOPS_RED)Error: VERSION required. Usage: make upgrade-k8s VERSION=v1.32.0$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_YELLOW)Upgrading Kubernetes to $(VERSION)...$(_SOPS_NC)"
	@export TALOSCONFIG=$(TALOSCONFIG) && talosctl upgrade-k8s --to $(VERSION)

.PHONY: talos-upgrade
talos-upgrade: ## Upgrade Talos node (NODE= IMAGE= required)
	@if [ -z "$(NODE)" ]; then \
		echo "$(_SOPS_RED)Error: NODE required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@if [ -z "$(IMAGE)" ] && [ -z "$(VERSION)" ]; then \
		echo "$(_SOPS_RED)Error: IMAGE or VERSION required$(_SOPS_NC)"; \
		echo "$(_SOPS_YELLOW)Usage: make talos-upgrade NODE=<ip> IMAGE=<installer-url>$(_SOPS_NC)"; \
		echo "$(_SOPS_YELLOW)   or: make talos-upgrade NODE=<ip> VERSION=v1.9.0$(_SOPS_NC)"; \
		exit 1; \
	fi
	@UPGRADE_IMAGE="$(IMAGE)"; \
	if [ -z "$$UPGRADE_IMAGE" ]; then \
		UPGRADE_IMAGE="ghcr.io/siderolabs/installer:$(VERSION)"; \
	fi; \
	echo "$(_SOPS_YELLOW)Upgrading Talos on $(NODE) with image: $$UPGRADE_IMAGE$(_SOPS_NC)"; \
	export TALOSCONFIG=$(TALOSCONFIG) && \
		talosctl upgrade --nodes $(NODE) --image $$UPGRADE_IMAGE --preserve

.PHONY: talos-dashboard
talos-dashboard: ## Open Talos dashboard (NODE= required, INSECURE=true optional)
	@if [ -z "$(NODE)" ]; then \
		echo "$(_SOPS_RED)Error: NODE required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@INSECURE_FLAG=""; \
	if [ "$(INSECURE)" = "true" ]; then \
		INSECURE_FLAG="--insecure"; \
	fi; \
	export TALOSCONFIG=$(TALOSCONFIG) && talosctl $$INSECURE_FLAG -n $(NODE) dashboard

.PHONY: talos-logs
talos-logs: ## View node logs (NODE= SERVICE= required, INSECURE=true optional)
	@if [ -z "$(NODE)" ]; then \
		echo "$(_SOPS_RED)Error: NODE required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(_SOPS_RED)Error: SERVICE required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@INSECURE_FLAG=""; \
	if [ "$(INSECURE)" = "true" ]; then \
		INSECURE_FLAG="--insecure"; \
	fi; \
	export TALOSCONFIG=$(TALOSCONFIG) && talosctl $$INSECURE_FLAG -n $(NODE) logs $(SERVICE)

.PHONY: talos-reset
talos-reset: ## Reset a Talos node (NODE= required, INSECURE=true optional)
	@if [ -z "$(NODE)" ]; then \
		echo "$(_SOPS_RED)Error: NODE required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_RED)WARNING: This will wipe the node at $(NODE)!$(_SOPS_NC)"
	@printf "Press Enter to continue or Ctrl+C to cancel: "; read confirm
	@INSECURE_FLAG=""; \
	if [ "$(INSECURE)" = "true" ]; then \
		INSECURE_FLAG="--insecure"; \
	fi; \
	export TALOSCONFIG=$(TALOSCONFIG) && talosctl $$INSECURE_FLAG -n $(NODE) reset --graceful=false --reboot

.PHONY: talos-reboot
talos-reboot: ## Reboot a Talos node (NODE= required, INSECURE=true optional)
	@if [ -z "$(NODE)" ]; then \
		echo "$(_SOPS_RED)Error: NODE required$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_YELLOW)Rebooting node $(NODE)...$(_SOPS_NC)"
	@INSECURE_FLAG=""; \
	if [ "$(INSECURE)" = "true" ]; then \
		INSECURE_FLAG="--insecure"; \
	fi; \
	export TALOSCONFIG=$(TALOSCONFIG) && talosctl $$INSECURE_FLAG -n $(NODE) reboot

# ============================================================================
# Help Target
# ============================================================================

.PHONY: talos-help
talos-help: ## Show Talos operations help
	@echo ""
	@echo "$(_SOPS_BOLD)Talos Cluster Operations$(_SOPS_NC)"
	@echo ""
	@echo "$(_SOPS_BOLD)Deployment:$(_SOPS_NC)"
	@echo "  talos-apply        Apply Talos configs to nodes"
	@echo "                     NODE=<name>  Apply to specific node"
	@echo "                     INSECURE=true  For initial setup"
	@echo "                     MODE=auto|reboot|no-reboot|staged"
	@echo "  talos-bootstrap    Bootstrap Kubernetes cluster"
	@echo ""
	@echo "$(_SOPS_BOLD)Access:$(_SOPS_NC)"
	@echo "  talos-kubeconfig   Retrieve kubeconfig"
	@echo "  talos-talosconfig  Export talosconfig path"
	@echo "  talos-env          Display all environment exports"
	@echo ""
	@echo "$(_SOPS_BOLD)Status:$(_SOPS_NC)"
	@echo "  talos-health       Check cluster health"
	@echo "  talos-nodes        List cluster nodes"
	@echo "  talos-pods         List all pods"
	@echo "  talos-status       Complete cluster status"
	@echo ""
	@echo "$(_SOPS_BOLD)Maintenance:$(_SOPS_NC)"
	@echo "  talos-upgrade-k8s  Upgrade Kubernetes (VERSION=)"
	@echo "  talos-upgrade      Upgrade Talos node (NODE= IMAGE=|VERSION=)"
	@echo "  talos-dashboard    Open Talos dashboard (NODE= INSECURE=true)"
	@echo "  talos-logs         View node logs (NODE= SERVICE= INSECURE=true)"
	@echo "  talos-reboot       Reboot a Talos node (NODE= INSECURE=true)"
	@echo "  talos-reset        Reset a Talos node (NODE= INSECURE=true)"
	@echo ""
