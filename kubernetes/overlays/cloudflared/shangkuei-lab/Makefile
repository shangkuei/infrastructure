# ============================================================================
# Makefile - Cloudflared SOPS Secret Management (shangkuei-lab)
# ============================================================================
# Manages SOPS-encrypted Kubernetes secrets for Cloudflare Tunnel credentials
#
# Usage:
#   make help                    # Show all targets
#   make encrypt                 # Encrypt tunnel credentials secret
#   make sops-validate           # Validate encrypted files
# ============================================================================

# Configuration
SOPS_DOMAIN := kubernetes
SOPS_ENV_NAME := gitops-shangkuei-lab-flux
SOPS_KEY_STRATEGY := central

# Encrypted file variables
# Note: Secret name inside file is "cloudflared" (matches cloudflare.secretName)
TUNNEL_CREDS_ENC := secret-tunnel-credentials.enc.yaml

# Include shared SOPS operations
include ../../../../makefiles/sops.mk

# ============================================================================
# Default Target
# ============================================================================

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "$(_SOPS_BOLD)Cloudflared SOPS Secret Management$(_SOPS_NC)"
	@echo "Environment: $(SOPS_ENV_NAME)"
	@echo "Strategy: $(SOPS_KEY_STRATEGY) | Key: $(SOPS_AGE_KEY_FILE)"
	@echo ""
	@echo "$(_SOPS_BOLD)Quick Start:$(_SOPS_NC)"
	@echo "  1. Copy: cp secret-tunnel-credentials.enc.yaml.example $(TUNNEL_CREDS_ENC)"
	@echo "  2. Edit: Fill in values from terraform output"
	@echo "  3. Encrypt: make encrypt"
	@echo ""
	@echo "$(_SOPS_BOLD)Secret Management:$(_SOPS_NC)"
	@echo "  encrypt                Encrypt tunnel credentials secret"
	@echo "  decrypt                Decrypt and view credentials"
	@echo "  edit                   Edit encrypted credentials"
	@echo ""
	@echo "$(_SOPS_BOLD)SOPS Operations:$(_SOPS_NC)"
	@echo "  sops-validate          Validate all encrypted files"
	@echo "  sops-info              Display encryption configuration"
	@echo "  sops-clean             Remove decrypted/temporary files"
	@echo ""

# ============================================================================
# Secret Management Targets
# ============================================================================

.PHONY: encrypt
encrypt: sops-check-deps sops-check-config ## Encrypt tunnel credentials secret
	@if [ ! -f "$(TUNNEL_CREDS_ENC)" ]; then \
		echo "$(_SOPS_RED)Error: $(TUNNEL_CREDS_ENC) not found$(_SOPS_NC)"; \
		echo ""; \
		echo "Create from template:"; \
		echo "  cp secret-tunnel-credentials.enc.yaml.example $(TUNNEL_CREDS_ENC)"; \
		echo "  # Edit and fill in values from: terraform output"; \
		echo "  make encrypt"; \
		exit 1; \
	fi
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --config $(SOPS_CONFIG) --input-type yaml --output-type yaml --encrypt --in-place $(TUNNEL_CREDS_ENC)
	@echo "$(_SOPS_GREEN)Encrypted: $(TUNNEL_CREDS_ENC)$(_SOPS_NC)"

.PHONY: decrypt
decrypt: sops-check-deps ## Decrypt and view credentials
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --decrypt $(TUNNEL_CREDS_ENC)

.PHONY: edit
edit: sops-check-deps ## Edit encrypted credentials
	@EDITOR="$(SOPS_EDITOR)" SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops $(TUNNEL_CREDS_ENC)

# ============================================================================
# Cleanup
# ============================================================================

.PHONY: clean
clean: sops-clean ## Remove temporary files
	@echo "$(_SOPS_GREEN)Cleanup complete$(_SOPS_NC)"
