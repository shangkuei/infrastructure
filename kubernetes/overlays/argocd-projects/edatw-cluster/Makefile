# ============================================================================
# Makefile - ArgoCD SOPS Age Key Management (edatw-cluster)
# ============================================================================
# Generates and manages a dedicated Age key for ArgoCD KSOPS
#
# Usage:
#   make help                     # Show all targets
#   make generate-argocd-age-key  # Generate dedicated ArgoCD Age key
#   make encrypt-secret           # Encrypt secret with Flux's Age key
#   make sops-validate            # Validate encrypted files
# ============================================================================

# Configuration
SOPS_DOMAIN := kubernetes
SOPS_ENV_NAME := gitops-edatw-cluster-flux
SOPS_KEY_STRATEGY := central

# ArgoCD-specific key files
ARGOCD_KEY_FILE := $(HOME)/.config/sops/age/argocd-edatw-ksops.txt
ARGOCD_PUB_FILE := $(HOME)/.config/sops/age/argocd-edatw-ksops.txt.pub

# Secret file (single file with in-place encryption)
SECRET_FILE := secret-sops-age.enc.yaml

# Include shared SOPS operations
include ../../../../makefiles/sops.mk

# ============================================================================
# Default Target
# ============================================================================

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "$(_SOPS_BOLD)ArgoCD SOPS Age Key Management$(_SOPS_NC)"
	@echo "Environment: $(SOPS_ENV_NAME)"
	@echo "Strategy: $(SOPS_KEY_STRATEGY) | Key: $(SOPS_AGE_KEY_FILE)"
	@echo ""
	@echo "$(_SOPS_BOLD)Quick Start:$(_SOPS_NC)"
	@echo "  1. make generate-argocd-age-key"
	@echo "  2. make encrypt-secret"
	@echo ""
	@echo "$(_SOPS_BOLD)ArgoCD Operations:$(_SOPS_NC)"
	@echo "  generate-argocd-age-key  Generate dedicated ArgoCD Age key"
	@echo "  encrypt-secret           Encrypt secret in-place with Flux's Age key"
	@echo "  edit-secret              Edit encrypted ArgoCD secret in place"
	@echo "  setup                    Complete setup (generate key + encrypt)"
	@echo ""
	@echo "$(_SOPS_BOLD)SOPS Operations:$(_SOPS_NC)"
	@echo "  sops-validate            Validate all encrypted files"
	@echo "  sops-decrypt FILE=x      Decrypt file to stdout"
	@echo "  sops-edit FILE=x         Edit encrypted file"
	@echo "  sops-info                Display encryption configuration"
	@echo "  sops-clean               Remove decrypted/temporary files"
	@echo ""
	@echo "$(_SOPS_BOLD)Utilities:$(_SOPS_NC)"
	@echo "  show-keys                Show Age key information"
	@echo "  clean                    Remove temporary files"
	@echo "  clean-all                Remove all generated files"
	@echo ""

# ============================================================================
# ArgoCD Key Generation
# ============================================================================

.PHONY: check-flux-key
check-flux-key: ## Verify Flux Age key exists
	@if [ ! -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(_SOPS_RED)Error: Flux Age key not found at $(SOPS_AGE_KEY_FILE)$(_SOPS_NC)"; \
		echo ""; \
		echo "Generate Flux Age keys first:"; \
		echo "  cd terraform/environments/gitops-edatw-cluster"; \
		echo "  make sops-keygen"; \
		exit 1; \
	fi
	@echo "$(_SOPS_GREEN)Flux Age key found$(_SOPS_NC)"

.PHONY: generate-argocd-age-key
generate-argocd-age-key: sops-check-deps ## Generate dedicated Age key for ArgoCD KSOPS
	@echo "$(_SOPS_BLUE)Generating dedicated Age key for ArgoCD KSOPS...$(_SOPS_NC)"
	@echo ""
	@mkdir -p $(HOME)/.config/sops/age
	@if [ -f "$(ARGOCD_KEY_FILE)" ]; then \
		echo "$(_SOPS_YELLOW)Warning: ArgoCD key already exists: $(ARGOCD_KEY_FILE)$(_SOPS_NC)"; \
		printf "Overwrite? [y/N] "; \
		read -r confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo "Aborted."; \
			exit 0; \
		fi; \
		rm -f "$(ARGOCD_KEY_FILE)"; \
	fi; \
	age-keygen -o "$(ARGOCD_KEY_FILE)" 2>&1
	@chmod 600 "$(ARGOCD_KEY_FILE)"
	@age-keygen -y "$(ARGOCD_KEY_FILE)" > "$(ARGOCD_PUB_FILE)"
	@chmod 644 "$(ARGOCD_PUB_FILE)"
	@echo ""
	@echo "$(_SOPS_GREEN)ArgoCD Age key generated$(_SOPS_NC)"
	@echo ""
	@echo "Files created:"
	@echo "  Private key: $(ARGOCD_KEY_FILE)"
	@echo "  Public key:  $(ARGOCD_PUB_FILE)"
	@echo ""
	@echo "Public key value:"
	@cat "$(ARGOCD_PUB_FILE)" | sed 's/^/  /'
	@echo ""
	@# Update local .sops.yaml with Flux public key
	@FLUX_PUBLIC_KEY=$$(grep "^# public key:" "$(SOPS_AGE_KEY_FILE)" 2>/dev/null | awk '{print $$NF}' || echo ""); \
	if [ -n "$$FLUX_PUBLIC_KEY" ]; then \
		echo "# SOPS configuration for ArgoCD overlay secrets" > .sops.yaml; \
		echo "# Uses Flux Age key to encrypt the ArgoCD KSOPS Age key secret" >> .sops.yaml; \
		echo "# This allows Flux to decrypt and deploy the secret to ArgoCD namespace" >> .sops.yaml; \
		echo "" >> .sops.yaml; \
		echo "creation_rules:" >> .sops.yaml; \
		echo "  - path_regex: \\.enc\\.yaml$$" >> .sops.yaml; \
		echo "    encrypted_regex: '^(data|stringData)$$'" >> .sops.yaml; \
		echo "    age: $$FLUX_PUBLIC_KEY" >> .sops.yaml; \
		echo "Updated: .sops.yaml"; \
	fi
	@# Create secret file with ArgoCD age key
	@echo "---" > $(SECRET_FILE)
	@echo "# ArgoCD SOPS Age key secret (to be encrypted)" >> $(SECRET_FILE)
	@echo "# This secret is deployed to argocd namespace for KSOPS decryption" >> $(SECRET_FILE)
	@echo "apiVersion: v1" >> $(SECRET_FILE)
	@echo "kind: Secret" >> $(SECRET_FILE)
	@echo "metadata:" >> $(SECRET_FILE)
	@echo "  name: sops-age" >> $(SECRET_FILE)
	@echo "  namespace: argocd" >> $(SECRET_FILE)
	@echo "type: Opaque" >> $(SECRET_FILE)
	@echo "stringData:" >> $(SECRET_FILE)
	@echo "  keys.txt: |" >> $(SECRET_FILE)
	@sed 's/^/    /' "$(ARGOCD_KEY_FILE)" >> $(SECRET_FILE)
	@echo ""
	@echo "$(_SOPS_GREEN)Created: $(SECRET_FILE)$(_SOPS_NC)"
	@echo ""
	@echo "$(_SOPS_YELLOW)IMPORTANT:$(_SOPS_NC)"
	@echo "  1. Backup the private key securely"
	@echo "  2. Test apps will use this key for SOPS encryption"
	@echo ""
	@echo "Next step: make encrypt-secret"

.PHONY: encrypt-secret
encrypt-secret: sops-check-deps sops-check-config check-flux-key ## Encrypt ArgoCD secret in-place with Flux's Age key
	@echo "$(_SOPS_BLUE)Encrypting ArgoCD SOPS Age secret with Flux's Age key...$(_SOPS_NC)"
	@if [ ! -f "$(SECRET_FILE)" ]; then \
		echo "$(_SOPS_RED)Error: $(SECRET_FILE) not found$(_SOPS_NC)"; \
		echo "Create the secret file first, then run this command."; \
		exit 1; \
	fi
	@# Check if already encrypted
	@if head -5 "$(SECRET_FILE)" | grep -q "sops:" 2>/dev/null; then \
		echo "$(_SOPS_YELLOW)File is already encrypted. Use 'make edit-secret' to modify.$(_SOPS_NC)"; \
		exit 0; \
	fi
	@echo "Note: Using Flux's Age key for encryption (so Flux can decrypt it)"
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --config $(SOPS_CONFIG) --encrypt --in-place "$(SECRET_FILE)"
	@echo "$(_SOPS_GREEN)Encrypted: $(SECRET_FILE)$(_SOPS_NC)"
	@echo ""
	@echo "Summary:"
	@echo "  ArgoCD Age key: $(ARGOCD_KEY_FILE)"
	@echo "  Encrypted secret: $(SECRET_FILE)"
	@echo ""
	@echo "Commit the encrypted secret to Git."

.PHONY: edit-secret
edit-secret: check-flux-key ## Edit encrypted ArgoCD secret in place
	@$(MAKE) sops-edit FILE=$(SECRET_FILE)

.PHONY: setup
setup: generate-argocd-age-key encrypt-secret ## Complete setup: generate key and encrypt secret
	@echo ""
	@echo "$(_SOPS_GREEN)ArgoCD KSOPS setup complete!$(_SOPS_NC)"
	@echo ""
	@echo "What was created:"
	@echo "  - Dedicated Age key for ArgoCD KSOPS"
	@echo "  - Encrypted secret for Flux to deploy"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Review changes: git status"
	@echo "  2. Commit: git add . && git commit -m 'feat(argocd): add KSOPS Age key'"
	@echo "  3. Push: git push"
	@echo "  4. Flux will deploy the secret automatically"
	@echo ""
	@echo "$(_SOPS_YELLOW)Remember to backup: $(ARGOCD_KEY_FILE)$(_SOPS_NC)"

# ============================================================================
# Utilities
# ============================================================================

.PHONY: show-keys
show-keys: ## Show Age key information
	@echo "$(_SOPS_BOLD)Age Key Information:$(_SOPS_NC)"
	@echo ""
	@echo "Flux Age Key (for encrypting ArgoCD secret):"
	@if [ -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		grep "^# public key:" "$(SOPS_AGE_KEY_FILE)" | sed 's/# /  /' || echo "  Not found"; \
	else \
		echo "  $(_SOPS_RED)Not found$(_SOPS_NC)"; \
	fi
	@echo ""
	@echo "ArgoCD Age Key (for encrypting test app secrets):"
	@if [ -f "$(ARGOCD_KEY_FILE)" ]; then \
		grep "^# public key:" "$(ARGOCD_KEY_FILE)" | sed 's/# /  /' || echo "  Not found"; \
	else \
		echo "  $(_SOPS_YELLOW)Not found (run: make generate-argocd-age-key)$(_SOPS_NC)"; \
	fi

# ============================================================================
# Cleanup
# ============================================================================

.PHONY: clean
clean: sops-clean ## Remove temporary files (keeps encrypted secrets)
	@echo "$(_SOPS_GREEN)Cleanup complete$(_SOPS_NC)"

.PHONY: clean-all
clean-all: clean ## Remove all generated files including encrypted secrets
	@echo "$(_SOPS_YELLOW)Removing all generated files...$(_SOPS_NC)"
	@printf "This will delete encrypted secrets. Continue? [y/N] "
	@read -r confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		rm -f $(SECRET_FILE) secret-sops-age.yaml; \
		echo "$(_SOPS_GREEN)All files removed$(_SOPS_NC)"; \
	else \
		echo "Cancelled"; \
	fi

# ============================================================================
# Backward Compatibility Aliases
# ============================================================================

.PHONY: check-deps check-sops-config validate
check-deps: sops-check-deps ## Alias for sops-check-deps
	@:
check-sops-config: sops-check-config ## Alias for sops-check-config
	@:
validate: sops-validate ## Alias for sops-validate
	@:
