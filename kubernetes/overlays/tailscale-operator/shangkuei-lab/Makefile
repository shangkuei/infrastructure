# ============================================================================
# Makefile - Tailscale Operator SOPS Secret Management (shangkuei-lab)
# ============================================================================
# Generates SOPS-encrypted Kubernetes secrets for Tailscale Operator
#
# Usage:
#   make help                    # Show all targets
#   make secret-tailscale-oauth  # Generate Tailscale OAuth secret
#   make setup                   # Generate all secrets
#   make sops-validate           # Validate encrypted files
#
# Prerequisites:
#   1. Create OAuth client at https://login.tailscale.com/admin/settings/oauth
#   2. Required scopes: Devices Core, Auth Keys, Services (write access)
#   3. Tag the client with tag:k8s-operator
# ============================================================================

# Configuration
SOPS_DOMAIN := kubernetes
SOPS_ENV_NAME := gitops-shangkuei-lab-flux
SOPS_KEY_STRATEGY := central

# Encrypted file variables
TAILSCALE_OAUTH_ENC := secret-operator-oauth.enc.yaml

# Include shared SOPS operations
include ../../../../makefiles/sops.mk

# ============================================================================
# Default Target
# ============================================================================

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "$(_SOPS_BOLD)Tailscale Operator SOPS Secret Management$(_SOPS_NC)"
	@echo "Environment: $(SOPS_ENV_NAME)"
	@echo "Strategy: $(SOPS_KEY_STRATEGY) | Key: $(SOPS_AGE_KEY_FILE)"
	@echo ""
	@echo "$(_SOPS_BOLD)Quick Start:$(_SOPS_NC)"
	@echo "  1. make setup          # Generate all secrets"
	@echo ""
	@echo "$(_SOPS_BOLD)Secret Generation:$(_SOPS_NC)"
	@echo "  secret-tailscale-oauth Generate Tailscale OAuth credentials secret"
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
	@echo "  clean                  Remove temporary files (keeps .enc.yaml)"
	@echo "  clean-all              Remove all generated files"
	@echo ""
	@echo "$(_SOPS_BOLD)Prerequisites:$(_SOPS_NC)"
	@echo "  1. Create OAuth client at https://login.tailscale.com/admin/settings/oauth"
	@echo "  2. Required scopes: Devices Core, Auth Keys, Services (write)"
	@echo "  3. Tag the client with tag:k8s-operator"
	@echo ""

# ============================================================================
# Secret Generation Targets
# ============================================================================

.PHONY: secret-tailscale-oauth
secret-tailscale-oauth: sops-check-deps sops-check-config ## Generate Tailscale OAuth credentials secret (encrypted)
	@echo "$(_SOPS_BLUE)Generating Tailscale OAuth credentials secret...$(_SOPS_NC)"
	@if [ ! -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(_SOPS_RED)Error: $(SOPS_AGE_KEY_FILE) not found$(_SOPS_NC)"; \
		echo "Generate the flux key first:"; \
		echo "  cd terraform/environments/gitops-shangkuei-lab && make flux-keygen"; \
		exit 1; \
	fi
	@echo ""
	@echo "Create OAuth client at: https://login.tailscale.com/admin/settings/oauth"
	@echo "Required scopes: Devices Core, Auth Keys, Services (write access)"
	@echo "Tag: tag:k8s-operator"
	@echo ""
	@read -p "OAuth Client ID: " CLIENT_ID; \
	read -p "OAuth Client Secret: " CLIENT_SECRET; \
	echo ""; \
	echo "---" > $(TAILSCALE_OAUTH_ENC); \
	echo "# Tailscale OAuth credentials secret (ENCRYPTED)" >> $(TAILSCALE_OAUTH_ENC); \
	echo "# Expected by tailscale-operator chart when oauth values are not set" >> $(TAILSCALE_OAUTH_ENC); \
	echo "# Keys must be 'client_id' and 'client_secret' (underscores, not camelCase)" >> $(TAILSCALE_OAUTH_ENC); \
	echo "apiVersion: v1" >> $(TAILSCALE_OAUTH_ENC); \
	echo "kind: Secret" >> $(TAILSCALE_OAUTH_ENC); \
	echo "metadata:" >> $(TAILSCALE_OAUTH_ENC); \
	echo "  name: operator-oauth" >> $(TAILSCALE_OAUTH_ENC); \
	echo "  namespace: tailscale" >> $(TAILSCALE_OAUTH_ENC); \
	echo "type: Opaque" >> $(TAILSCALE_OAUTH_ENC); \
	echo "stringData:" >> $(TAILSCALE_OAUTH_ENC); \
	echo "  client_id: \"$$CLIENT_ID\"" >> $(TAILSCALE_OAUTH_ENC); \
	echo "  client_secret: \"$$CLIENT_SECRET\"" >> $(TAILSCALE_OAUTH_ENC); \
	SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --config $(SOPS_CONFIG) --input-type yaml --output-type yaml --encrypt --in-place $(TAILSCALE_OAUTH_ENC); \
	echo ""; \
	echo "$(_SOPS_GREEN)Generated: $(TAILSCALE_OAUTH_ENC)$(_SOPS_NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Review: make sops-decrypt FILE=$(TAILSCALE_OAUTH_ENC)"
	@echo "  2. Commit to git"

.PHONY: setup
setup: secret-tailscale-oauth ## Complete setup: generate all secrets
	@echo ""
	@echo "$(_SOPS_GREEN)Setup complete!$(_SOPS_NC)"
	@echo ""
	@echo "Generated files:"
	@ls -1 *.enc.yaml 2>/dev/null || echo "  (no encrypted files)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. git add *.enc.yaml"
	@echo "  2. git commit -m 'feat(tailscale): add SOPS secrets for shangkuei-lab'"
	@echo "  3. git push"

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
