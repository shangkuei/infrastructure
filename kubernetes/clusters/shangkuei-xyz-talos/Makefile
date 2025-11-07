.PHONY: help secret-create secret-edit secret-view secret-encrypt secret-decrypt
.PHONY: secret-validate validate-all flux-reconcile flux-status

# Configuration
CLUSTER_NAME := shangkuei-xyz-talos
AGE_DIR := $(HOME)/.config/sops/age

# Flux age key (for encrypting Kubernetes manifests)
AGE_FLUX_PRIVATE_KEY := $(AGE_DIR)/talos-gitops-flux.txt
AGE_FLUX_PUBLIC_KEY := $(AGE_DIR)/talos-gitops-flux.txt.pub

# Default SOPS key file for Flux operations
export SOPS_AGE_KEY_FILE := $(AGE_FLUX_PRIVATE_KEY)

# Directories
SECRETS_DIR := secrets
CLUSTER_DIR := $(shell pwd)
BASE_DIR := ../../base

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
CYAN := \033[0;36m
NC := \033[0m # No Color

# Default target
help:
	@echo "$(CYAN)Kubernetes Cluster: $(CLUSTER_NAME)$(NC)"
	@echo ""
	@echo "$(BLUE)Secret Management:$(NC)"
	@echo "  make secret-create NAME=<name> NAMESPACE=<ns>  Create encrypted secret interactively"
	@echo "  make secret-edit FILE=<path>                   Edit encrypted secret"
	@echo "  make secret-view FILE=<path>                   View decrypted secret"
	@echo "  make secret-encrypt FILE=<path>                Encrypt existing secret file"
	@echo "  make secret-decrypt FILE=<path>                Decrypt and display secret"
	@echo ""
	@echo "$(BLUE)Validation:$(NC)"
	@echo "  make secret-validate FILE=<path>               Validate secret is properly encrypted"
	@echo "  make validate-all                              Validate all YAML files in cluster"
	@echo ""
	@echo "$(BLUE)Flux Operations:$(NC)"
	@echo "  make flux-reconcile                            Force reconcile cluster resources"
	@echo "  make flux-status                               Show Flux Kustomization status"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make secret-create NAME=db-credentials NAMESPACE=production"
	@echo "  make secret-edit FILE=secrets/db-credentials.yaml"
	@echo "  make secret-view FILE=secrets/db-credentials.yaml"

# Check if SOPS and age are installed
check-tools:
	@if ! command -v sops >/dev/null 2>&1; then \
		echo "$(RED)Error: sops is not installed$(NC)"; \
		echo ""; \
		echo "Install sops:"; \
		echo "  macOS:   brew install sops"; \
		echo "  Linux:   see https://github.com/getsops/sops"; \
		exit 1; \
	fi
	@if ! command -v age >/dev/null 2>&1; then \
		echo "$(RED)Error: age is not installed$(NC)"; \
		echo ""; \
		echo "Install age:"; \
		echo "  macOS:   brew install age"; \
		echo "  Linux:   apt install age"; \
		exit 1; \
	fi
	@if [ ! -f $(AGE_FLUX_PRIVATE_KEY) ]; then \
		echo "$(RED)Error: Flux age key not found at $(AGE_FLUX_PRIVATE_KEY)$(NC)"; \
		echo ""; \
		echo "Generate age keys:"; \
		echo "  cd ../../terraform/environments/talos-gitops"; \
		echo "  make age-keygen"; \
		exit 1; \
	fi

# Create a new encrypted secret interactively
secret-create: check-tools
	@if [ -z "$(NAME)" ] || [ -z "$(NAMESPACE)" ]; then \
		echo "$(RED)Usage: make secret-create NAME=<name> NAMESPACE=<namespace>$(NC)"; \
		echo ""; \
		echo "Example: make secret-create NAME=db-credentials NAMESPACE=production"; \
		exit 1; \
	fi
	@mkdir -p $(SECRETS_DIR)
	@SECRET_FILE="$(SECRETS_DIR)/$(NAME).yaml"; \
	if [ -f "$$SECRET_FILE" ]; then \
		echo "$(YELLOW)Warning: Secret file already exists: $$SECRET_FILE$(NC)"; \
		read -p "Overwrite? (yes/no): " confirm; \
		if [ "$$confirm" != "yes" ]; then \
			echo "$(CYAN)Cancelled$(NC)"; \
			exit 0; \
		fi; \
	fi; \
	echo "$(BLUE)==> Creating secret: $(NAME) in namespace: $(NAMESPACE)$(NC)"; \
	echo "---" > $$SECRET_FILE; \
	echo "apiVersion: v1" >> $$SECRET_FILE; \
	echo "kind: Secret" >> $$SECRET_FILE; \
	echo "metadata:" >> $$SECRET_FILE; \
	echo "  name: $(NAME)" >> $$SECRET_FILE; \
	echo "  namespace: $(NAMESPACE)" >> $$SECRET_FILE; \
	echo "type: Opaque" >> $$SECRET_FILE; \
	echo "stringData:" >> $$SECRET_FILE; \
	echo "  # Add your secret data below (will be encrypted)" >> $$SECRET_FILE; \
	echo "  # example-key: example-value" >> $$SECRET_FILE; \
	echo "$(GREEN)==> Created template: $$SECRET_FILE$(NC)"; \
	echo ""; \
	echo "$(YELLOW)==> Opening editor to add secret data...$(NC)"; \
	$${EDITOR:-vim} $$SECRET_FILE; \
	echo ""; \
	echo "$(BLUE)==> Encrypting secret with SOPS...$(NC)"; \
	echo "$(YELLOW)==> Note: Only stringData section will be encrypted (metadata remains plaintext)$(NC)"; \
	sops --input-type yaml --output-type yaml --encrypted-regex '^(data|stringData)$$' -e -i $$SECRET_FILE; \
	echo "$(GREEN)==> Secret encrypted successfully!$(NC)"; \
	echo ""; \
	echo "$(CYAN)Next steps:$(NC)"; \
	echo "  1. Review encrypted file: make secret-view FILE=$$SECRET_FILE"; \
	echo "  2. Add to kustomization.yaml: ../../base/<namespace>/kustomization.yaml"; \
	echo "  3. Commit to git: git add $$SECRET_FILE && git commit -m 'feat(secrets): add $(NAME)'"; \
	echo "  4. Flux will decrypt and apply automatically"

# Edit an encrypted secret
secret-edit: check-tools
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Usage: make secret-edit FILE=<path>$(NC)"; \
		echo ""; \
		echo "Example: make secret-edit FILE=secrets/db-credentials.yaml"; \
		exit 1; \
	fi
	@if [ ! -f $(FILE) ]; then \
		echo "$(RED)Error: File not found: $(FILE)$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)==> Editing encrypted secret: $(FILE)$(NC)"
	@sops $(FILE)
	@echo "$(GREEN)==> Secret saved and re-encrypted$(NC)"

# View decrypted secret
secret-view: check-tools
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Usage: make secret-view FILE=<path>$(NC)"; \
		echo ""; \
		echo "Example: make secret-view FILE=secrets/db-credentials.yaml"; \
		exit 1; \
	fi
	@if [ ! -f $(FILE) ]; then \
		echo "$(RED)Error: File not found: $(FILE)$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)==> Decrypted contents of $(FILE):$(NC)"
	@echo ""
	@sops -d $(FILE)

# Encrypt an existing unencrypted secret file
secret-encrypt: check-tools
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Usage: make secret-encrypt FILE=<path>$(NC)"; \
		echo ""; \
		echo "Example: make secret-encrypt FILE=secrets/db-credentials.yaml"; \
		exit 1; \
	fi
	@if [ ! -f $(FILE) ]; then \
		echo "$(RED)Error: File not found: $(FILE)$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)==> Encrypting $(FILE) with SOPS...$(NC)"
	@echo "$(YELLOW)==> Note: Only data/stringData sections will be encrypted (metadata remains plaintext)$(NC)"
	@sops --input-type yaml --output-type yaml --encrypted-regex '^(data|stringData)$$' -e -i $(FILE)
	@echo "$(GREEN)==> File encrypted successfully$(NC)"

# Decrypt secret (same as secret-view)
secret-decrypt: secret-view

# Validate that a secret is properly encrypted
secret-validate: check-tools
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Usage: make secret-validate FILE=<path>$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f $(FILE) ]; then \
		echo "$(RED)Error: File not found: $(FILE)$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)==> Validating $(FILE)$(NC)"
	@if grep -q "sops:" $(FILE) && grep -q "mac:" $(FILE); then \
		echo "$(GREEN)✓ File is encrypted with SOPS$(NC)"; \
	else \
		echo "$(RED)✗ File does not appear to be encrypted$(NC)"; \
		exit 1; \
	fi
	@if sops -d $(FILE) > /dev/null 2>&1; then \
		echo "$(GREEN)✓ File can be decrypted$(NC)"; \
	else \
		echo "$(RED)✗ Cannot decrypt file$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Secret is valid$(NC)"

# Validate all YAML files in cluster directory
validate-all:
	@echo "$(BLUE)==> Validating all YAML files in cluster$(NC)"
	@echo ""
	@VALID=0; INVALID=0; \
	for file in $$(find . -name "*.yaml" -o -name "*.yml"); do \
		echo -n "Checking $$file... "; \
		if grep -q "kind: Secret" $$file 2>/dev/null; then \
			if grep -q "sops:" $$file && grep -q "mac:" $$file; then \
				echo "$(GREEN)encrypted ✓$(NC)"; \
				VALID=$$((VALID + 1)); \
			else \
				echo "$(RED)NOT ENCRYPTED ✗$(NC)"; \
				INVALID=$$((INVALID + 1)); \
			fi; \
		else \
			if python3 -c "import yaml; yaml.safe_load(open('$$file'))" 2>/dev/null; then \
				echo "$(GREEN)valid ✓$(NC)"; \
				VALID=$$((VALID + 1)); \
			else \
				echo "$(RED)invalid ✗$(NC)"; \
				INVALID=$$((INVALID + 1)); \
			fi; \
		fi; \
	done; \
	echo ""; \
	echo "$(CYAN)==> Summary$(NC)"; \
	echo "  Valid:   $$VALID"; \
	echo "  Invalid: $$INVALID"; \
	if [ $$INVALID -gt 0 ]; then \
		exit 1; \
	fi

# Force reconcile all cluster Kustomizations
flux-reconcile:
	@echo "$(BLUE)==> Reconciling cluster Kustomizations$(NC)"
	@if ! command -v flux >/dev/null 2>&1; then \
		echo "$(YELLOW)Warning: flux CLI not installed$(NC)"; \
		echo "Install: brew install fluxcd/tap/flux"; \
		exit 1; \
	fi
	@flux reconcile source git flux-system
	@flux reconcile kustomization kube-system --with-source
	@flux reconcile kustomization kube-addons --with-source
	@echo "$(GREEN)==> Reconciliation triggered$(NC)"

# Show Flux Kustomization status
flux-status:
	@echo "$(BLUE)==> Flux Kustomization Status$(NC)"
	@if ! command -v flux >/dev/null 2>&1; then \
		echo "$(YELLOW)Warning: flux CLI not installed$(NC)"; \
		echo "Install: brew install fluxcd/tap/flux"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(CYAN)GitRepository:$(NC)"
	@kubectl -n flux-system get gitrepository flux-system
	@echo ""
	@echo "$(CYAN)Kustomizations:$(NC)"
	@kubectl -n flux-system get kustomization
	@echo ""
	@echo "$(CYAN)Cluster Resources:$(NC)"
	@kubectl get ns kube-system kube-addons 2>/dev/null || true
