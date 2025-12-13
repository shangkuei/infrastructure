# ============================================================================
# Makefile - Kubernetes Cluster Secret Management (shangkuei-dev)
# ============================================================================
# Manages SOPS-encrypted Kubernetes secrets for Flux GitOps
#
# Usage:
#   make help                                    # Show all targets
#   make secret-create NAME=<name> NAMESPACE=<ns>  # Create encrypted secret
#   make secret-edit FILE=<path>                 # Edit encrypted secret
#   make sops-validate                           # Validate encrypted files
# ============================================================================

# Configuration
SOPS_DOMAIN := kubernetes
SOPS_ENV_NAME := cluster-shangkuei-dev
SOPS_KEY_STRATEGY := central

# Cluster configuration
CLUSTER_NAME := shangkuei-dev

# Flux age key (for encrypting Kubernetes manifests)
AGE_FLUX_PRIVATE_KEY := $(HOME)/.config/sops/age/gitops-shangkuei-dev-flux.txt
AGE_FLUX_PUBLIC_KEY := $(HOME)/.config/sops/age/gitops-shangkuei-dev-flux.txt.pub

# Override SOPS_AGE_KEY_FILE for central strategy
SOPS_AGE_KEY_FILE := $(AGE_FLUX_PRIVATE_KEY)
export SOPS_AGE_KEY_FILE

# Directories
SECRETS_DIR := secrets

# Include shared SOPS operations
include ../../../makefiles/sops.mk

# ============================================================================
# Default Target
# ============================================================================

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "$(_SOPS_BOLD)Kubernetes Cluster: $(CLUSTER_NAME)$(_SOPS_NC)"
	@echo "Environment: $(SOPS_ENV_NAME)"
	@echo "Strategy: $(SOPS_KEY_STRATEGY) | Key: $(SOPS_AGE_KEY_FILE)"
	@echo ""
	@echo "$(_SOPS_BOLD)Secret Management:$(_SOPS_NC)"
	@echo "  secret-create NAME=x NS=y  Create encrypted secret interactively"
	@echo "  secret-edit FILE=<path>    Edit encrypted secret"
	@echo "  secret-view FILE=<path>    View decrypted secret"
	@echo "  secret-encrypt FILE=<path> Encrypt existing secret file"
	@echo "  secret-decrypt FILE=<path> Decrypt and display secret"
	@echo ""
	@echo "$(_SOPS_BOLD)Validation:$(_SOPS_NC)"
	@echo "  secret-validate FILE=<path> Validate secret is encrypted"
	@echo "  validate-all                Validate all YAML files in cluster"
	@echo "  sops-validate               Validate all encrypted files"
	@echo ""
	@echo "$(_SOPS_BOLD)SOPS Operations:$(_SOPS_NC)"
	@echo "  sops-decrypt FILE=x        Decrypt file to stdout"
	@echo "  sops-edit FILE=x           Edit encrypted file"
	@echo "  sops-info                  Display encryption configuration"
	@echo "  sops-clean                 Remove decrypted/temporary files"
	@echo ""
	@echo "$(_SOPS_BOLD)Flux Operations:$(_SOPS_NC)"
	@echo "  flux-reconcile             Force reconcile cluster resources"
	@echo "  flux-status                Show Flux Kustomization status"
	@echo ""
	@echo "$(_SOPS_BOLD)Examples:$(_SOPS_NC)"
	@echo "  make secret-create NAME=db-credentials NAMESPACE=production"
	@echo "  make secret-edit FILE=secrets/db-credentials.yaml"
	@echo ""

# ============================================================================
# Secret Management
# ============================================================================

.PHONY: secret-create
secret-create: sops-check-deps sops-check-config ## Create encrypted secret interactively (NAME=, NAMESPACE=)
	@if [ -z "$(NAME)" ] || [ -z "$(NAMESPACE)" ]; then \
		echo "$(_SOPS_RED)Usage: make secret-create NAME=<name> NAMESPACE=<namespace>$(_SOPS_NC)"; \
		echo ""; \
		echo "Example: make secret-create NAME=db-credentials NAMESPACE=production"; \
		exit 1; \
	fi
	@mkdir -p $(SECRETS_DIR)
	@SECRET_FILE="$(SECRETS_DIR)/$(NAME).yaml"; \
	if [ -f "$$SECRET_FILE" ]; then \
		echo "$(_SOPS_YELLOW)Warning: Secret file already exists: $$SECRET_FILE$(_SOPS_NC)"; \
		printf "Overwrite? (yes/no): "; \
		read confirm; \
		if [ "$$confirm" != "yes" ]; then \
			echo "$(_SOPS_CYAN)Cancelled$(_SOPS_NC)"; \
			exit 0; \
		fi; \
	fi; \
	echo "$(_SOPS_BLUE)==> Creating secret: $(NAME) in namespace: $(NAMESPACE)$(_SOPS_NC)"; \
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
	echo "$(_SOPS_GREEN)==> Created template: $$SECRET_FILE$(_SOPS_NC)"; \
	echo ""; \
	echo "$(_SOPS_YELLOW)==> Opening editor to add secret data...$(_SOPS_NC)"; \
	$${EDITOR:-vim} $$SECRET_FILE; \
	echo ""; \
	echo "$(_SOPS_BLUE)==> Encrypting secret with SOPS...$(_SOPS_NC)"; \
	echo "$(_SOPS_YELLOW)==> Note: Only stringData section will be encrypted (metadata remains plaintext)$(_SOPS_NC)"; \
	SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --config $(SOPS_CONFIG) --input-type yaml --output-type yaml -e -i $$SECRET_FILE; \
	echo "$(_SOPS_GREEN)==> Secret encrypted successfully!$(_SOPS_NC)"; \
	echo ""; \
	echo "$(_SOPS_CYAN)Next steps:$(_SOPS_NC)"; \
	echo "  1. Review encrypted file: make secret-view FILE=$$SECRET_FILE"; \
	echo "  2. Add to kustomization.yaml"; \
	echo "  3. Commit to git: git add $$SECRET_FILE && git commit -m 'feat(secrets): add $(NAME)'"; \
	echo "  4. Flux will decrypt and apply automatically"

.PHONY: secret-edit
secret-edit: sops-check-deps sops-check-config ## Edit encrypted secret (FILE=)
	@if [ -z "$(FILE)" ]; then \
		echo "$(_SOPS_RED)Usage: make secret-edit FILE=<path>$(_SOPS_NC)"; \
		echo ""; \
		echo "Example: make secret-edit FILE=secrets/db-credentials.yaml"; \
		exit 1; \
	fi
	@if [ ! -f $(FILE) ]; then \
		echo "$(_SOPS_RED)Error: File not found: $(FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)==> Editing encrypted secret: $(FILE)$(_SOPS_NC)"
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --config $(SOPS_CONFIG) $(FILE)
	@echo "$(_SOPS_GREEN)==> Secret saved and re-encrypted$(_SOPS_NC)"

.PHONY: secret-view
secret-view: sops-check-deps sops-check-config ## View decrypted secret (FILE=)
	@if [ -z "$(FILE)" ]; then \
		echo "$(_SOPS_RED)Usage: make secret-view FILE=<path>$(_SOPS_NC)"; \
		echo ""; \
		echo "Example: make secret-view FILE=secrets/db-credentials.yaml"; \
		exit 1; \
	fi
	@if [ ! -f $(FILE) ]; then \
		echo "$(_SOPS_RED)Error: File not found: $(FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)==> Decrypted contents of $(FILE):$(_SOPS_NC)"
	@echo ""
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --config $(SOPS_CONFIG) -d $(FILE)

.PHONY: secret-encrypt
secret-encrypt: sops-check-deps sops-check-config ## Encrypt existing secret file (FILE=)
	@if [ -z "$(FILE)" ]; then \
		echo "$(_SOPS_RED)Usage: make secret-encrypt FILE=<path>$(_SOPS_NC)"; \
		echo ""; \
		echo "Example: make secret-encrypt FILE=secrets/db-credentials.yaml"; \
		exit 1; \
	fi
	@if [ ! -f $(FILE) ]; then \
		echo "$(_SOPS_RED)Error: File not found: $(FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)==> Encrypting $(FILE) with SOPS...$(_SOPS_NC)"
	@echo "$(_SOPS_YELLOW)==> Note: Only data/stringData sections will be encrypted (metadata remains plaintext)$(_SOPS_NC)"
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --config $(SOPS_CONFIG) --input-type yaml --output-type yaml -e -i $(FILE)
	@echo "$(_SOPS_GREEN)==> File encrypted successfully$(_SOPS_NC)"

.PHONY: secret-decrypt
secret-decrypt: secret-view ## Decrypt secret (alias for secret-view)

.PHONY: secret-validate
secret-validate: sops-check-deps ## Validate secret is properly encrypted (FILE=)
	@if [ -z "$(FILE)" ]; then \
		echo "$(_SOPS_RED)Usage: make secret-validate FILE=<path>$(_SOPS_NC)"; \
		exit 1; \
	fi
	@if [ ! -f $(FILE) ]; then \
		echo "$(_SOPS_RED)Error: File not found: $(FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)==> Validating $(FILE)$(_SOPS_NC)"
	@if grep -q "sops:" $(FILE) && grep -q "mac:" $(FILE); then \
		echo "$(_SOPS_GREEN)✓ File is encrypted with SOPS$(_SOPS_NC)"; \
	else \
		echo "$(_SOPS_RED)✗ File does not appear to be encrypted$(_SOPS_NC)"; \
		exit 1; \
	fi
	@if SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --config $(SOPS_CONFIG) -d $(FILE) > /dev/null 2>&1; then \
		echo "$(_SOPS_GREEN)✓ File can be decrypted$(_SOPS_NC)"; \
	else \
		echo "$(_SOPS_RED)✗ Cannot decrypt file$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "$(_SOPS_GREEN)✓ Secret is valid$(_SOPS_NC)"

# ============================================================================
# Validation
# ============================================================================

.PHONY: validate-all
validate-all: ## Validate all YAML files in cluster directory
	@echo "$(_SOPS_BLUE)==> Validating all YAML files in cluster$(_SOPS_NC)"
	@echo ""
	@VALID=0; INVALID=0; \
	for file in $$(find . -name "*.yaml" -o -name "*.yml"); do \
		printf "Checking $$file... "; \
		if grep -q "kind: Secret" $$file 2>/dev/null; then \
			if grep -q "sops:" $$file && grep -q "mac:" $$file; then \
				echo "$(_SOPS_GREEN)encrypted ✓$(_SOPS_NC)"; \
				VALID=$$((VALID + 1)); \
			else \
				echo "$(_SOPS_RED)NOT ENCRYPTED ✗$(_SOPS_NC)"; \
				INVALID=$$((INVALID + 1)); \
			fi; \
		else \
			if python3 -c "import yaml; yaml.safe_load(open('$$file'))" 2>/dev/null; then \
				echo "$(_SOPS_GREEN)valid ✓$(_SOPS_NC)"; \
				VALID=$$((VALID + 1)); \
			else \
				echo "$(_SOPS_RED)invalid ✗$(_SOPS_NC)"; \
				INVALID=$$((INVALID + 1)); \
			fi; \
		fi; \
	done; \
	echo ""; \
	echo "$(_SOPS_CYAN)==> Summary$(_SOPS_NC)"; \
	echo "  Valid:   $$VALID"; \
	echo "  Invalid: $$INVALID"; \
	if [ $$INVALID -gt 0 ]; then \
		exit 1; \
	fi

# ============================================================================
# Flux Operations
# ============================================================================

.PHONY: flux-reconcile
flux-reconcile: ## Force reconcile cluster resources
	@echo "$(_SOPS_BLUE)==> Reconciling cluster Kustomizations$(_SOPS_NC)"
	@if ! command -v flux >/dev/null 2>&1; then \
		echo "$(_SOPS_YELLOW)Warning: flux CLI not installed$(_SOPS_NC)"; \
		echo "Install: brew install fluxcd/tap/flux"; \
		exit 1; \
	fi
	@flux reconcile source git flux-system
	@flux reconcile kustomization flux-system --with-source
	@echo "$(_SOPS_GREEN)==> Reconciliation triggered$(_SOPS_NC)"

.PHONY: flux-status
flux-status: ## Show Flux Kustomization status
	@echo "$(_SOPS_BLUE)==> Flux Kustomization Status$(_SOPS_NC)"
	@if ! command -v flux >/dev/null 2>&1; then \
		echo "$(_SOPS_YELLOW)Warning: flux CLI not installed$(_SOPS_NC)"; \
		echo "Install: brew install fluxcd/tap/flux"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(_SOPS_CYAN)GitRepository:$(_SOPS_NC)"
	@kubectl -n flux-system get gitrepository flux-system
	@echo ""
	@echo "$(_SOPS_CYAN)Kustomizations:$(_SOPS_NC)"
	@kubectl -n flux-system get kustomization
	@echo ""
	@echo "$(_SOPS_CYAN)HelmReleases:$(_SOPS_NC)"
	@kubectl get helmrelease -A

# ============================================================================
# Cleanup
# ============================================================================

.PHONY: clean
clean: sops-clean ## Remove temporary files
	@echo "$(_SOPS_GREEN)Cleanup complete$(_SOPS_NC)"

# ============================================================================
# Backward Compatibility Aliases
# ============================================================================

.PHONY: check-tools check-deps
check-tools: sops-check-deps ## Alias for sops-check-deps
	@:
check-deps: sops-check-deps ## Alias for sops-check-deps
	@:
