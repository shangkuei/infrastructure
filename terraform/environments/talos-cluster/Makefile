# Talos Cluster Environment - Makefile
# Manages Talos Kubernetes cluster configuration generation and deployment

.PHONY: help init plan apply destroy clean
.PHONY: apply-configs bootstrap deploy-tailscale
.PHONY: kubeconfig talosconfig health nodes pods
.PHONY: validate lint format
.PHONY: age-keygen age-info encrypt-backend encrypt-tfvars

# Default target
.DEFAULT_GOAL := help

# Configuration
GENERATED_DIR := generated
TALOSCONFIG := $(GENERATED_DIR)/talosconfig
KUBECONFIG := $(GENERATED_DIR)/kubeconfig

# SOPS configuration
AGE_DIR := $(HOME)/.config/sops/age
AGE_PRIVATE_KEY := $(AGE_DIR)/talos-cluster-key.txt
AGE_PUBLIC_KEY := $(AGE_DIR)/talos-cluster-key.txt.pub
SOPS_AGE_KEY_FILE := $(AGE_PRIVATE_KEY)
TFVARS_ENC := terraform.tfvars.enc
BACKEND_HCL := backend.hcl
BACKEND_ENC := backend.hcl.enc

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Terraform Operations

init: ## Initialize Terraform
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	@if [ -f $(BACKEND_ENC) ]; then \
		echo "$(BLUE)==> Using encrypted backend config from $(BACKEND_ENC)$(NC)"; \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(BACKEND_ENC) 'terraform init -backend-config={}'; \
	else \
		echo "$(YELLOW)==> No backend config found, using local state$(NC)"; \
		terraform init; \
	fi

plan: ## Generate Terraform execution plan
	@echo "$(BLUE)Planning Terraform changes...$(NC)"
	@if [ -f $(TFVARS_ENC) ]; then \
		echo "$(BLUE)==> Using encrypted variables from $(TFVARS_ENC)$(NC)"; \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(TFVARS_ENC) 'terraform plan -var-file={}'; \
	else \
		echo "$(YELLOW)==> Warning: $(TFVARS_ENC) not found, using default variables$(NC)"; \
		terraform plan; \
	fi

apply: ## Generate cluster configurations
	@echo "$(BLUE)Generating cluster configurations...$(NC)"
	@if [ -f $(TFVARS_ENC) ]; then \
		echo "$(BLUE)==> Using encrypted variables from $(TFVARS_ENC)$(NC)"; \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(TFVARS_ENC) 'terraform apply -var-file={}'; \
	else \
		echo "$(YELLOW)==> Warning: $(TFVARS_ENC) not found, using default variables$(NC)"; \
		terraform apply; \
	fi
	@echo "$(GREEN)✓ Configurations generated in $(GENERATED_DIR)/$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. make apply-configs  # Apply configs to nodes"
	@echo "  2. make bootstrap      # Bootstrap Kubernetes cluster"
	@echo "  3. make health         # Check cluster health"

destroy: ## Remove generated configurations
	@echo "$(RED)Removing generated configurations...$(NC)"
	@terraform destroy

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	@terraform validate

format: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	@terraform fmt -recursive

lint: validate format ## Run validation and formatting

##@ Cluster Deployment

apply-configs: ## Apply Talos configurations to all nodes (or NODE=<name> for single node, INSECURE=true for initial setup)
	@if [ ! -d "$(GENERATED_DIR)" ]; then \
		echo "$(RED)Error: Configuration files not generated. Run 'make apply' first.$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(RED)Error: talosconfig not found. Run 'make apply' first.$(NC)"; \
		exit 1; \
	fi
	@export TALOSCONFIG=$(TALOSCONFIG); \
	INSECURE_FLAG=""; \
	if [ "$(INSECURE)" = "true" ]; then \
		INSECURE_FLAG="--insecure"; \
		echo "$(YELLOW)==> Using --insecure mode for initial setup$(NC)"; \
	fi; \
	if [ -n "$(NODE)" ]; then \
		echo "$(BLUE)Applying configuration to node: $(NODE)$(NC)"; \
		if [ -f "$(GENERATED_DIR)/control-plane-$(NODE).yaml" ]; then \
			NODE_TYPE="control-plane"; \
			BASE_CONFIG="$(GENERATED_DIR)/control-plane-$(NODE).yaml"; \
		elif [ -f "$(GENERATED_DIR)/worker-$(NODE).yaml" ]; then \
			NODE_TYPE="worker"; \
			BASE_CONFIG="$(GENERATED_DIR)/worker-$(NODE).yaml"; \
		else \
			echo "$(RED)Error: No configuration found for node '$(NODE)'$(NC)"; \
			echo "$(YELLOW)Available nodes:$(NC)"; \
			ls -1 $(GENERATED_DIR)/*-*.yaml 2>/dev/null | grep -E '(control-plane|worker)-[^-]+\.yaml$$' | sed 's/.*\/\(control-plane\|worker\)-\(.*\)\.yaml/  \2/' | sort -u; \
			exit 1; \
		fi; \
		echo "$(BLUE)==> Node type: $$NODE_TYPE$(NC)"; \
		OUTPUT_KEY=$$(echo "$$NODE_TYPE" | sed 's/-/_/g'); \
		NODE_IP=$$(terraform output -json generated_configs 2>/dev/null | jq -r ".[\"$$OUTPUT_KEY\"][\"$(NODE)\"].physical_ip // \"\"" || echo ""); \
		if [ -z "$$NODE_IP" ] || [ "$$NODE_IP" = "null" ]; then \
			echo "$(YELLOW)==> Could not determine node IP from terraform output$(NC)"; \
			read -p "Enter node IP address: " NODE_IP; \
		fi; \
		echo "$(BLUE)==> Applying to: $$NODE_IP$(NC)"; \
		echo "$(BLUE)==> Base config: $$BASE_CONFIG$(NC)"; \
		PATCH_FILES=$$(find $(GENERATED_DIR) -name "$$NODE_TYPE-$(NODE)-*.yaml" ! -name "$$NODE_TYPE-$(NODE).yaml" | sort); \
		PATCH_ARGS=""; \
		if [ -n "$$PATCH_FILES" ]; then \
			echo "$(BLUE)==> Patch files:$(NC)"; \
			for patch in $$PATCH_FILES; do \
				echo "  - $$patch"; \
				PATCH_ARGS="$$PATCH_ARGS --config-patch @$$patch"; \
			done; \
		else \
			echo "$(YELLOW)==> No patch files found$(NC)"; \
		fi; \
		talosctl apply-config $$INSECURE_FLAG --nodes $$NODE_IP --endpoints $$NODE_IP \
			--file $$BASE_CONFIG \
			$$PATCH_ARGS && \
		echo "$(GREEN)✓ Configuration applied to $(NODE)$(NC)" || \
		(echo "$(RED)✗ Failed to apply configuration to $(NODE)$(NC)"; exit 1); \
	else \
		echo "$(BLUE)Applying configurations to all nodes...$(NC)"; \
		for config in $(GENERATED_DIR)/control-plane-*.yaml; do \
			if [ -f "$$config" ]; then \
				BASE_NAME=$$(basename $$config); \
				if echo "$$BASE_NAME" | grep -q '^control-plane-[^-]\+\.yaml$$'; then \
					NODE_NAME=$$(echo "$$BASE_NAME" | sed 's/control-plane-\(.*\)\.yaml/\1/'); \
					NODE_IP=$$(terraform output -json generated_configs 2>/dev/null | jq -r ".[\"control_plane\"][\"$$NODE_NAME\"].physical_ip // \"\"" || echo ""); \
					if [ -n "$$NODE_IP" ] && [ "$$NODE_IP" != "null" ]; then \
						echo "$(BLUE)==> Applying to control plane node $$NODE_NAME ($$NODE_IP)$(NC)"; \
						PATCH_FILES=$$(find $(GENERATED_DIR) -name "control-plane-$$NODE_NAME-*.yaml" | sort); \
						PATCH_ARGS=""; \
						for patch in $$PATCH_FILES; do \
							PATCH_ARGS="$$PATCH_ARGS --config-patch @$$patch"; \
						done; \
						talosctl apply-config $$INSECURE_FLAG --nodes $$NODE_IP --endpoints $$NODE_IP \
							--file $$config \
							$$PATCH_ARGS && \
						echo "$(GREEN)✓ Applied to $$NODE_NAME$(NC)" || \
						echo "$(RED)✗ Failed to apply to $$NODE_NAME$(NC)"; \
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
						echo "$(BLUE)==> Applying to worker node $$NODE_NAME ($$NODE_IP)$(NC)"; \
						PATCH_FILES=$$(find $(GENERATED_DIR) -name "worker-$$NODE_NAME-*.yaml" | sort); \
						PATCH_ARGS=""; \
						for patch in $$PATCH_FILES; do \
							PATCH_ARGS="$$PATCH_ARGS --config-patch @$$patch"; \
						done; \
						talosctl apply-config $$INSECURE_FLAG --nodes $$NODE_IP --endpoints $$NODE_IP \
							--file $$config \
							$$PATCH_ARGS && \
						echo "$(GREEN)✓ Applied to $$NODE_NAME$(NC)" || \
						echo "$(RED)✗ Failed to apply to $$NODE_NAME$(NC)"; \
					fi; \
				fi; \
			fi; \
		done; \
		echo "$(GREEN)✓ All configurations applied$(NC)"; \
	fi

bootstrap: ## Bootstrap Kubernetes cluster (use NODE=<ip> to specify bootstrap node, defaults to first control plane)
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(RED)Error: talosconfig not found. Run 'make apply' first.$(NC)"; \
		exit 1; \
	fi
	@export TALOSCONFIG=$(TALOSCONFIG); \
	if [ -n "$(NODE)" ]; then \
		BOOTSTRAP_NODE="$(NODE)"; \
	else \
		FIRST_CP=$$(terraform output -json generated_configs 2>/dev/null | jq -r '.control_plane | keys[0]' || echo ""); \
		if [ -z "$$FIRST_CP" ]; then \
			echo "$(RED)Error: Could not determine bootstrap node$(NC)"; \
			echo "$(YELLOW)Specify manually: make bootstrap NODE=<node-ip>$(NC)"; \
			exit 1; \
		fi; \
		BOOTSTRAP_NODE=$$(terraform output -json generated_configs 2>/dev/null | jq -r ".control_plane[\"$$FIRST_CP\"].physical_ip // \"\"" || echo ""); \
		if [ -z "$$BOOTSTRAP_NODE" ] || [ "$$BOOTSTRAP_NODE" = "null" ]; then \
			echo "$(RED)Error: Could not determine bootstrap node IP$(NC)"; \
			echo "$(YELLOW)Specify manually: make bootstrap NODE=<node-ip>$(NC)"; \
			exit 1; \
		fi; \
		echo "$(BLUE)==> Using first control plane node: $$FIRST_CP ($$BOOTSTRAP_NODE)$(NC)"; \
	fi; \
	echo "$(BLUE)Bootstrapping Kubernetes cluster on $$BOOTSTRAP_NODE...$(NC)"; \
	talosctl bootstrap --nodes $$BOOTSTRAP_NODE --endpoints $$BOOTSTRAP_NODE && \
	echo "$(GREEN)✓ Cluster bootstrapped successfully$(NC)" || \
	(echo "$(RED)✗ Bootstrap failed$(NC)"; exit 1)

##@ Cluster Access

kubeconfig: ## Generate and retrieve kubeconfig (use NODE=<ip> to specify control plane node, defaults to first)
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(RED)Error: talosconfig not found. Run 'make apply' first.$(NC)"; \
		exit 1; \
	fi
	@export TALOSCONFIG=$(TALOSCONFIG); \
	if [ -n "$(NODE)" ]; then \
		KUBECONFIG_NODE="$(NODE)"; \
	else \
		FIRST_CP=$$(terraform output -json generated_configs 2>/dev/null | jq -r '.control_plane | keys[0]' || echo ""); \
		if [ -z "$$FIRST_CP" ]; then \
			echo "$(RED)Error: Could not determine control plane node$(NC)"; \
			echo "$(YELLOW)Specify manually: make kubeconfig NODE=<node-ip>$(NC)"; \
			exit 1; \
		fi; \
		KUBECONFIG_NODE=$$(terraform output -json generated_configs 2>/dev/null | jq -r ".control_plane[\"$$FIRST_CP\"].physical_ip // \"\"" || echo ""); \
		if [ -z "$$KUBECONFIG_NODE" ] || [ "$$KUBECONFIG_NODE" = "null" ]; then \
			echo "$(RED)Error: Could not determine control plane node IP$(NC)"; \
			echo "$(YELLOW)Specify manually: make kubeconfig NODE=<node-ip>$(NC)"; \
			exit 1; \
		fi; \
		echo "$(BLUE)==> Using control plane node: $$FIRST_CP ($$KUBECONFIG_NODE)$(NC)"; \
	fi; \
	echo "$(BLUE)Retrieving kubeconfig from $$KUBECONFIG_NODE...$(NC)"; \
	mkdir -p $$(dirname $(KUBECONFIG)); \
	talosctl kubeconfig --nodes $$KUBECONFIG_NODE --endpoints $$KUBECONFIG_NODE --force $(KUBECONFIG) && \
	echo "$(GREEN)✓ Kubeconfig retrieved successfully$(NC)" && \
	echo "" && \
	echo "$(GREEN)export KUBECONFIG=$$(pwd)/$(KUBECONFIG)$(NC)" && \
	echo "" && \
	echo "Run this command to set your kubeconfig:" && \
	echo "  export KUBECONFIG=$$(pwd)/$(KUBECONFIG)" || \
	(echo "$(RED)✗ Failed to retrieve kubeconfig$(NC)"; exit 1)

talosconfig: ## Export talosconfig for talosctl access
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(RED)Error: talosconfig not found. Run 'make apply' first.$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)export TALOSCONFIG=$$(pwd)/$(TALOSCONFIG)$(NC)"
	@echo ""
	@echo "Run this command to set your talosconfig:"
	@echo "  export TALOSCONFIG=$$(pwd)/$(TALOSCONFIG)"

env: kubeconfig talosconfig ## Display environment variable exports

##@ CNI Deployment

deploy-cilium: ## Deploy Cilium CNI using Helm (requires kubeconfig)
	@if [ ! -f "$(KUBECONFIG)" ]; then \
		echo "$(RED)Error: kubeconfig not found. Run 'make kubeconfig' first.$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(GENERATED_DIR)/cilium-values.yaml" ]; then \
		echo "$(RED)Error: Cilium values file not found.$(NC)"; \
		echo "$(YELLOW)Make sure cni_name='cilium' in terraform.tfvars and run 'make apply' first.$(NC)"; \
		exit 1; \
	fi
	@if ! command -v helm >/dev/null 2>&1; then \
		echo "$(RED)Error: helm is not installed$(NC)"; \
		echo ""; \
		echo "Install Helm:"; \
		echo "  macOS:   brew install helm"; \
		echo "  Linux:   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"; \
		echo "  Manual:  https://helm.sh/docs/intro/install/"; \
		exit 1; \
	fi
	@echo "$(BLUE)Deploying Cilium CNI...$(NC)"
	@export KUBECONFIG=$(KUBECONFIG) && \
		helm repo add cilium https://helm.cilium.io/ && \
		helm repo update && \
		helm upgrade --install cilium cilium/cilium \
			--namespace kube-system \
			--values $(GENERATED_DIR)/cilium-values.yaml \
			--wait && \
		echo "$(GREEN)✓ Cilium deployed successfully$(NC)" || \
		(echo "$(RED)✗ Cilium deployment failed$(NC)"; exit 1)
	@echo ""
	@echo "$(YELLOW)Verify Cilium deployment:$(NC)"
	@echo "  kubectl -n kube-system get pods -l k8s-app=cilium"
	@echo "  kubectl -n kube-system exec -it ds/cilium -- cilium status"

##@ Cluster Status

health: ## Check cluster health
	@if [ ! -f "$(TALOSCONFIG)" ]; then \
		echo "$(RED)Error: talosconfig not found.$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Checking cluster health...$(NC)"
	@export TALOSCONFIG=$(TALOSCONFIG) && \
		talosctl health --wait-timeout=10m

nodes: ## List cluster nodes
	@if [ ! -f "$(KUBECONFIG)" ]; then \
		echo "$(RED)Error: kubeconfig not found.$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Cluster nodes:$(NC)"
	@export KUBECONFIG=$(KUBECONFIG) && \
		kubectl get nodes -o wide

pods: ## List all pods in all namespaces
	@if [ ! -f "$(KUBECONFIG)" ]; then \
		echo "$(RED)Error: kubeconfig not found.$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)All pods:$(NC)"
	@export KUBECONFIG=$(KUBECONFIG) && \
		kubectl get pods -A

status: health nodes pods ## Show complete cluster status

##@ Maintenance

upgrade-k8s: ## Upgrade Kubernetes (set VERSION=v1.32.0)
	@if [ -z "$(VERSION)" ]; then \
		echo "$(RED)Error: VERSION not specified. Usage: make upgrade-k8s VERSION=v1.32.0$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Upgrading Kubernetes to $(VERSION)...$(NC)"
	@export TALOSCONFIG=$(TALOSCONFIG) && \
		talosctl upgrade-k8s --to $(VERSION)

upgrade-talos: ## Upgrade Talos (set VERSION=v1.9.0)
	@if [ -z "$(VERSION)" ]; then \
		echo "$(RED)Error: VERSION not specified. Usage: make upgrade-talos VERSION=v1.9.0$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(NODE)" ]; then \
		echo "$(RED)Error: NODE not specified. Usage: make upgrade-talos VERSION=v1.9.0 NODE=100.64.0.10$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Upgrading Talos on $(NODE) to $(VERSION)...$(NC)"
	@export TALOSCONFIG=$(TALOSCONFIG) && \
		talosctl upgrade --nodes $(NODE) --image ghcr.io/siderolabs/installer:$(VERSION)

dashboard: ## Open Talos dashboard (set NODE=100.64.0.10)
	@if [ -z "$(NODE)" ]; then \
		echo "$(RED)Error: NODE not specified. Usage: make dashboard NODE=100.64.0.10$(NC)"; \
		exit 1; \
	fi
	@export TALOSCONFIG=$(TALOSCONFIG) && \
		talosctl -n $(NODE) dashboard

logs: ## View logs from a node (set NODE=100.64.0.10 SERVICE=kubelet)
	@if [ -z "$(NODE)" ]; then \
		echo "$(RED)Error: NODE not specified. Usage: make logs NODE=100.64.0.10 SERVICE=kubelet$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Error: SERVICE not specified. Usage: make logs NODE=100.64.0.10 SERVICE=kubelet$(NC)"; \
		exit 1; \
	fi
	@export TALOSCONFIG=$(TALOSCONFIG) && \
		talosctl -n $(NODE) logs $(SERVICE)

##@ Cleanup

clean: ## Remove generated directory
	@echo "$(YELLOW)Removing generated directory...$(NC)"
	@rm -rf $(GENERATED_DIR)
	@echo "$(GREEN)✓ Generated directory removed$(NC)"

reset-node: ## Reset a Talos node (set NODE=100.64.0.10)
	@if [ -z "$(NODE)" ]; then \
		echo "$(RED)Error: NODE not specified. Usage: make reset-node NODE=100.64.0.10$(NC)"; \
		exit 1; \
	fi
	@echo "$(RED)WARNING: This will wipe the node at $(NODE)!$(NC)"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read confirm
	@export TALOSCONFIG=$(TALOSCONFIG) && \
		talosctl -n $(NODE) reset --graceful=false --reboot

##@ Workflow

all: init apply apply-configs bootstrap health ## Complete cluster setup workflow
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)Cluster deployment complete!$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Access the cluster:$(NC)"
	@echo "  export TALOSCONFIG=$$(pwd)/$(TALOSCONFIG)"
	@echo "  export KUBECONFIG=$$(pwd)/$(KUBECONFIG)"
	@echo ""
	@echo "$(YELLOW)Verify cluster:$(NC)"
	@echo "  make nodes"
	@echo "  make pods"

workflow: ## Show deployment workflow steps
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)Talos Cluster Deployment Workflow$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Initial Setup:$(NC)"
	@echo "  1. make init                       # Initialize Terraform"
	@echo "  2. make apply                      # Generate configurations"
	@echo ""
	@echo "$(YELLOW)Cluster Deployment (Two-Phase):$(NC)"
	@echo "  3. make apply-configs INSECURE=true # Apply configs (initial, before certs)"
	@echo "  4. [Wait for Tailscale join]       # Nodes auto-join tailnet (~1-2 min)"
	@echo "  5. [Update terraform.tfvars]       # Add real Tailscale IPs"
	@echo "  6. make apply                      # Regenerate with Tailscale IPs"
	@echo "  7. make apply-configs              # Reapply configs (secure mode)"
	@echo "  8. make bootstrap                  # Bootstrap Kubernetes"
	@echo ""
	@echo "$(YELLOW)CNI Deployment (if using Cilium):$(NC)"
	@echo "  9. make kubeconfig                 # Retrieve kubeconfig from cluster"
	@echo "  10. make deploy-cilium             # Deploy Cilium CNI with Helm"
	@echo ""
	@echo "$(YELLOW)Verification:$(NC)"
	@echo "  11. make health                    # Check cluster health"
	@echo "  12. make nodes                     # List nodes"
	@echo "  13. make pods                      # List pods"
	@echo ""
	@echo "$(YELLOW)Single Node Updates:$(NC)"
	@echo "  make apply-configs NODE=cp-01      # Apply to single node (secure)"
	@echo "  make apply-configs NODE=cp-01 INSECURE=true # Initial node setup"
##@ SOPS Encryption

age-keygen: $(AGE_PRIVATE_KEY) ## Generate age encryption key

$(AGE_PRIVATE_KEY):
	@echo "$(BLUE)==> Generating age encryption key$(NC)"
	@if ! command -v age >/dev/null 2>&1; then \
		echo "$(RED)Error: age is not installed$(NC)"; \
		echo ""; \
		echo "Install age:"; \
		echo "  macOS:   brew install age"; \
		echo "  Linux:   apt install age"; \
		echo "  Manual:  https://age-encryption.org/"; \
		exit 1; \
	fi
	@mkdir -p $(AGE_DIR)
	@chmod 700 $(AGE_DIR)
	@if [ -f $(AGE_PRIVATE_KEY) ]; then \
		echo "$(YELLOW)==> Age key already exists$(NC)"; \
		echo ""; \
		read -p "Overwrite? (yes/no): " confirm; \
		if [ "$$confirm" = "yes" ]; then \
			echo "$(YELLOW)==> Backing up existing key$(NC)"; \
			cp $(AGE_PRIVATE_KEY) $(AGE_PRIVATE_KEY).backup.$$(date +%Y%m%d-%H%M%S); \
		else \
			echo "$(GREEN)==> Using existing key$(NC)"; \
			exit 0; \
		fi; \
	fi
	@age-keygen -o $(AGE_PRIVATE_KEY)
	@chmod 600 $(AGE_PRIVATE_KEY)
	@grep "^# public key:" $(AGE_PRIVATE_KEY) | sed 's/# public key: //' > $(AGE_PUBLIC_KEY)
	@chmod 644 $(AGE_PUBLIC_KEY)
	@echo "$(GREEN)==> Age key generated successfully$(NC)"
	@echo ""
	@$(MAKE) --no-print-directory age-info
	@echo ""
	@echo "$(YELLOW)==> SECURITY WARNING$(NC)"
	@echo "1. Store private key securely in password manager"
	@echo "2. Never commit private key to git"
	@echo "3. Backup private key in multiple secure locations"
	@echo "4. Update .sops.yaml with public key: $$(cat $(AGE_PUBLIC_KEY))"
	@echo "5. Store key in GitHub Secret: SOPS_AGE_KEY_TALOS_CLUSTER"

age-info: ## Display age key information
	@if [ ! -f $(AGE_PRIVATE_KEY) ]; then \
		echo "$(RED)Error: Age key not found. Run 'make age-keygen' first$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)==> Age Encryption Key Information$(NC)"
	@echo ""
	@echo "Private Key: $(AGE_PRIVATE_KEY)"
	@echo "Public Key:  $(AGE_PUBLIC_KEY)"
	@echo ""
	@echo "$(BLUE)Public Key (safe to share):$(NC)"
	@cat $(AGE_PUBLIC_KEY)

encrypt-backend: ## Encrypt backend.hcl with SOPS
	@echo "$(BLUE)==> Encrypting backend configuration$(NC)"
	@if [ ! -f $(AGE_PRIVATE_KEY) ]; then \
		echo "$(RED)Error: Age key not found. Run 'make age-keygen' first$(NC)"; \
		exit 1; \
	fi
	@if ! command -v sops >/dev/null 2>&1; then \
		echo "$(RED)Error: SOPS is not installed$(NC)"; \
		echo ""; \
		echo "Install SOPS:"; \
		echo "  macOS:   brew install sops"; \
		echo "  Linux:   See https://github.com/mozilla/sops/releases"; \
		exit 1; \
	fi
	@if [ ! -f $(BACKEND_HCL) ]; then \
		echo "$(RED)Error: $(BACKEND_HCL) not found$(NC)"; \
		echo ""; \
		echo "Create it first:"; \
		echo "  cp backend.hcl.example $(BACKEND_HCL)"; \
		echo "  vim $(BACKEND_HCL)  # Add your R2 credentials"; \
		exit 1; \
	fi
	@echo "$(BLUE)==> Encrypting $(BACKEND_HCL) to $(BACKEND_ENC)$(NC)"
	@SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops -e $(BACKEND_HCL) > $(BACKEND_ENC)
	@echo "$(GREEN)==> Encrypted successfully$(NC)"
	@echo ""
	@echo "$(YELLOW)==> Next steps:$(NC)"
	@echo "1. Remove unencrypted file: rm $(BACKEND_HCL)"
	@echo "2. Commit encrypted file: git add $(BACKEND_ENC)"

encrypt-tfvars: ## Encrypt terraform.tfvars with SOPS
	@echo "$(BLUE)==> Encrypting terraform.tfvars$(NC)"
	@if [ ! -f $(AGE_PRIVATE_KEY) ]; then \
		echo "$(RED)Error: Age key not found. Run 'make age-keygen' first$(NC)"; \
		exit 1; \
	fi
	@if ! command -v sops >/dev/null 2>&1; then \
		echo "$(RED)Error: SOPS is not installed$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f terraform.tfvars ]; then \
		echo "$(RED)Error: terraform.tfvars not found$(NC)"; \
		echo ""; \
		echo "Create it first:"; \
		echo "  cp terraform.tfvars.example terraform.tfvars"; \
		echo "  vim terraform.tfvars  # Add your secrets"; \
		exit 1; \
	fi
	@echo "$(BLUE)==> Encrypting terraform.tfvars to $(TFVARS_ENC)$(NC)"
	@SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops -e terraform.tfvars > $(TFVARS_ENC)
	@echo "$(GREEN)==> Encrypted successfully$(NC)"
	@echo ""
	@echo "$(YELLOW)==> Next steps:$(NC)"
	@echo "1. Remove unencrypted file: rm terraform.tfvars"
	@echo "2. Commit encrypted file: git add $(TFVARS_ENC)"
