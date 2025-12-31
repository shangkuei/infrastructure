# ============================================================================
# Makefile - Flux Instance SOPS Secret Management (shangkuei-lab)
# ============================================================================
# Generates SOPS-encrypted Kubernetes secrets for Flux GitOps
#
# Usage:
#   make help                    # Show all targets
#   make secret-sops-age         # Generate SOPS age secret
#   make secret-flux-git         # Generate Flux Git credentials
#   make setup                   # Generate all secrets
#   make sops-validate           # Validate encrypted files
# ============================================================================

# Configuration
SOPS_DOMAIN := kubernetes
SOPS_ENV_NAME := gitops-shangkuei-lab-flux
SOPS_KEY_STRATEGY := central

# Encrypted file variables (new naming convention: .enc.yaml)
SOPS_AGE_ENC := secret-sops-age.enc.yaml
FLUX_GIT_ENC := secret-flux-git-credentials.enc.yaml

# Include shared SOPS operations
include ../../../../makefiles/sops.mk

# ============================================================================
# Default Target
# ============================================================================

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "$(_SOPS_BOLD)Flux Instance SOPS Secret Management$(_SOPS_NC)"
	@echo "Environment: $(SOPS_ENV_NAME)"
	@echo "Strategy: $(SOPS_KEY_STRATEGY) | Key: $(SOPS_AGE_KEY_FILE)"
	@echo ""
	@echo "$(_SOPS_BOLD)Quick Start:$(_SOPS_NC)"
	@echo "  1. make setup          # Generate all secrets"
	@echo ""
	@echo "$(_SOPS_BOLD)Secret Generation:$(_SOPS_NC)"
	@echo "  secret-sops-age        Generate SOPS age key secret (encrypted)"
	@echo "  secret-flux-git        Generate Flux Git credentials secret"
	@echo "  setup                  Complete setup: generate all secrets"
	@echo ""
	@echo "$(_SOPS_BOLD)SOPS Operations:$(_SOPS_NC)"
	@echo "  sops-validate          Validate all encrypted files"
	@echo "  sops-decrypt FILE=x    Decrypt file to stdout"
	@echo "  sops-edit FILE=x       Edit encrypted file"
	@echo "  sops-info              Display encryption configuration"
	@echo "  sops-clean             Remove decrypted/temporary files"
	@echo ""
	@echo "$(_SOPS_BOLD)Maintenance:$(_SOPS_NC)"
	@echo "  encrypt-all            Re-encrypt all decrypted secrets"
	@echo "  clean                  Remove temporary files (keeps .enc.yaml)"
	@echo "  clean-all              Remove all generated files"
	@echo ""

# ============================================================================
# Secret Generation Targets
# ============================================================================

.PHONY: secret-sops-age
secret-sops-age: sops-check-deps sops-check-config ## Generate SOPS age secret (encrypted)
	@echo "$(_SOPS_BLUE)Generating SOPS age secret...$(_SOPS_NC)"
	@if [ ! -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(_SOPS_RED)Error: $(SOPS_AGE_KEY_FILE) not found$(_SOPS_NC)"; \
		echo "Generate the flux key first:"; \
		echo "  cd terraform/environments/gitops-shangkuei-lab && make flux-keygen"; \
		exit 1; \
	fi
	@echo "---" > $(SOPS_AGE_ENC)
	@echo "# SOPS age encryption key secret (ENCRYPTED)" >> $(SOPS_AGE_ENC)
	@echo "# Managed by Terraform: kubernetes_secret.sops_age" >> $(SOPS_AGE_ENC)
	@echo "# Only stringData section is encrypted (metadata, kind, apiVersion are plaintext)" >> $(SOPS_AGE_ENC)
	@echo "apiVersion: v1" >> $(SOPS_AGE_ENC)
	@echo "kind: Secret" >> $(SOPS_AGE_ENC)
	@echo "metadata:" >> $(SOPS_AGE_ENC)
	@echo "  name: sops-age" >> $(SOPS_AGE_ENC)
	@echo "  namespace: flux-system" >> $(SOPS_AGE_ENC)
	@echo "type: Opaque" >> $(SOPS_AGE_ENC)
	@echo "stringData:" >> $(SOPS_AGE_ENC)
	@echo "  age.agekey: |" >> $(SOPS_AGE_ENC)
	@sed 's/^/    /' $(SOPS_AGE_KEY_FILE) >> $(SOPS_AGE_ENC)
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --config $(SOPS_CONFIG) --input-type yaml --output-type yaml --encrypt --in-place $(SOPS_AGE_ENC)
	@echo "$(_SOPS_GREEN)Generated: $(SOPS_AGE_ENC)$(_SOPS_NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Review: make sops-decrypt FILE=$(SOPS_AGE_ENC)"
	@echo "  2. Commit to git"

.PHONY: secret-flux-git
secret-flux-git: sops-check-deps sops-check-config ## Generate Flux Git credentials secret (encrypted)
	@echo "$(_SOPS_BLUE)Generating Flux Git credentials secret...$(_SOPS_NC)"
	@if [ ! -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(_SOPS_RED)Error: $(SOPS_AGE_KEY_FILE) not found$(_SOPS_NC)"; \
		echo "Generate the flux key first:"; \
		echo "  cd terraform/environments/gitops-shangkuei-lab && make flux-keygen"; \
		exit 1; \
	fi
	@read -p "GitHub Username: " GITHUB_USER; \
	read -sp "GitHub Token (PAT): " GITHUB_TOKEN; \
	echo ""; \
	echo "---" > $(FLUX_GIT_ENC); \
	echo "# Flux Git credentials secret (ENCRYPTED)" >> $(FLUX_GIT_ENC); \
	echo "# Managed by Terraform: kubernetes_secret.flux_git_credentials" >> $(FLUX_GIT_ENC); \
	echo "# Only stringData section is encrypted (metadata, kind, apiVersion are plaintext)" >> $(FLUX_GIT_ENC); \
	echo "apiVersion: v1" >> $(FLUX_GIT_ENC); \
	echo "kind: Secret" >> $(FLUX_GIT_ENC); \
	echo "metadata:" >> $(FLUX_GIT_ENC); \
	echo "  name: flux-system" >> $(FLUX_GIT_ENC); \
	echo "  namespace: flux-system" >> $(FLUX_GIT_ENC); \
	echo "type: Opaque" >> $(FLUX_GIT_ENC); \
	echo "stringData:" >> $(FLUX_GIT_ENC); \
	echo "  username: $$GITHUB_USER" >> $(FLUX_GIT_ENC); \
	echo "  password: $$GITHUB_TOKEN" >> $(FLUX_GIT_ENC); \
	SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --config $(SOPS_CONFIG) --input-type yaml --output-type yaml --encrypt --in-place $(FLUX_GIT_ENC); \
	echo ""; \
	echo "$(_SOPS_GREEN)Generated: $(FLUX_GIT_ENC)$(_SOPS_NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Review: make sops-decrypt FILE=$(FLUX_GIT_ENC)"
	@echo "  2. Commit to git"

.PHONY: setup
setup: secret-sops-age secret-flux-git ## Complete setup: generate all secrets
	@echo ""
	@echo "$(_SOPS_GREEN)Setup complete!$(_SOPS_NC)"
	@echo ""
	@echo "Generated files:"
	@ls -1 *.enc.yaml 2>/dev/null || echo "  (no encrypted files)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. git add *.enc.yaml"
	@echo "  2. git commit -m 'feat(flux): add SOPS secrets for shangkuei-lab'"
	@echo "  3. git push"

# ============================================================================
# Bulk Operations
# ============================================================================

.PHONY: encrypt-all
encrypt-all: sops-check-deps sops-check-config ## Encrypt all decrypted secrets
	@echo "$(_SOPS_BLUE)Encrypting secrets...$(_SOPS_NC)"
	@for file in *.decrypted; do \
		if [ -f "$$file" ]; then \
			base=$${file%.decrypted}; \
			cp "$$file" "$$base.enc.yaml"; \
			$(MAKE) --no-print-directory sops-encrypt FILE="$$base.enc.yaml"; \
		fi; \
	done
	@echo "$(_SOPS_GREEN)All secrets encrypted$(_SOPS_NC)"

# ============================================================================
# Cleanup
# ============================================================================

.PHONY: clean
clean: sops-clean ## Remove generated files (keeps encrypted files)
	@echo "$(_SOPS_GREEN)Cleanup complete$(_SOPS_NC)"
	@echo "Encrypted files preserved"

.PHONY: clean-all
clean-all: clean ## Remove all generated files including encrypted secrets
	@echo "$(_SOPS_YELLOW)Removing all generated files...$(_SOPS_NC)"
	@rm -f *.enc.yaml *.yaml.enc
	@echo "$(_SOPS_GREEN)All generated files removed$(_SOPS_NC)"

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
