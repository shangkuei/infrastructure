# Makefile for Vaultwarden Docker overlay - shangkuei-xyz-unraid
SHELL := /bin/bash
.DEFAULT_GOAL := help

# ============================================================================
# SOPS Configuration (must be set before including sops.mk)
# ============================================================================
SOPS_DOMAIN := docker
SOPS_ENV_NAME := vaultwarden-shangkuei-xyz-unraid
SOPS_KEY_STRATEGY := local

# Include shared SOPS operations
include ../../../../makefiles/sops.mk

# ============================================================================
# Docker Configuration
# ============================================================================
SERVICE_NAME := vaultwarden
BASE_DIR := ../../../base/$(SERVICE_NAME)

# Encrypted files (committed to git, encrypted in-place)
ENV_ENC := .enc.env
OVERRIDE_ENC := docker-compose.override.enc.yml
TAILSCALE_ENC := docker-compose.tailscale.override.enc.yml

# Non-encrypted files
TAILSCALE_RAW := docker-compose.tailscale.override.yml

# Base compose file
BASE_COMPOSE := $(BASE_DIR)/docker-compose.yml

# Docker compose file lists (for docker-compose.mk)
COMPOSE_ENC_FILES := $(OVERRIDE_ENC) $(TAILSCALE_ENC)
COMPOSE_RAW_FILES := $(TAILSCALE_RAW)

# Include shared Docker Compose operations
include ../../../../makefiles/docker-compose.mk

# ============================================================================
# Help
# ============================================================================
.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "Vaultwarden Docker Overlay - shangkuei-xyz-unraid"
	@echo "=================================================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Docker Compose Operations:"
	@echo "  env                  Show decrypted .enc.env file"
	@echo "  config               Output merged docker-compose config"
	@echo "  up                   Start services"
	@echo "  down                 Stop services"
	@echo "  logs                 View logs (follow mode)"
	@echo "  ps                   Show running containers"
	@echo "  restart              Restart services"
	@echo "  pull                 Pull latest images"
	@echo ""
	@echo "Docker SOPS Operations:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | \
		grep -v "^sops-" | grep -v "^help:" | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "SOPS Operations: (run 'make sops-help' for details)"
	@echo "  sops-help          Show SOPS operations help"
	@echo "  sops-info          Display encryption configuration"
	@echo "  sops-validate      Validate all encrypted files"
	@echo ""

# ============================================================================
# Docker-Specific SOPS Operations
# ============================================================================
.PHONY: encrypt
encrypt: sops-check-deps sops-check-config ## Encrypt plaintext files (first-time setup)
	@echo "$(_SOPS_BLUE)Encrypting Docker files in-place...$(_SOPS_NC)"
	@export SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)"; \
	if [ -f "$(ENV_ENC)" ] && ! head -1 "$(ENV_ENC)" | grep -q "^sops:\|^#ENC\["; then \
		sops --encrypt --in-place $(ENV_ENC); \
		echo "  [$(_SOPS_OK)] Encrypted $(ENV_ENC)"; \
	elif [ -f "$(ENV_ENC)" ]; then \
		echo "  [$(_SOPS_INFO)] $(ENV_ENC) already encrypted"; \
	fi; \
	if [ -f "$(OVERRIDE_ENC)" ] && ! head -1 "$(OVERRIDE_ENC)" | grep -q "^sops:"; then \
		sops --encrypt --in-place $(OVERRIDE_ENC); \
		echo "  [$(_SOPS_OK)] Encrypted $(OVERRIDE_ENC)"; \
	elif [ -f "$(OVERRIDE_ENC)" ]; then \
		echo "  [$(_SOPS_INFO)] $(OVERRIDE_ENC) already encrypted"; \
	fi; \
	if [ -f "$(TAILSCALE_ENC)" ] && ! head -1 "$(TAILSCALE_ENC)" | grep -q "^sops:"; then \
		sops --encrypt --in-place $(TAILSCALE_ENC); \
		echo "  [$(_SOPS_OK)] Encrypted $(TAILSCALE_ENC)"; \
	elif [ -f "$(TAILSCALE_ENC)" ]; then \
		echo "  [$(_SOPS_INFO)] $(TAILSCALE_ENC) already encrypted"; \
	fi
	@echo "$(_SOPS_GREEN)Encryption complete$(_SOPS_NC)"

.PHONY: edit
edit: ## Edit encrypted file with sops (interactive menu)
	@echo "Select file to edit:"
	@echo "  1) .enc.env"
	@echo "  2) docker-compose.override.enc.yml"
	@echo "  3) docker-compose.tailscale.override.enc.yml"
	@export SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)"; \
	read -p "Choice [1-3]: " choice; \
	case $$choice in \
		1) EDITOR="$(SOPS_EDITOR)" sops $(ENV_ENC) ;; \
		2) EDITOR="$(SOPS_EDITOR)" sops $(OVERRIDE_ENC) ;; \
		3) EDITOR="$(SOPS_EDITOR)" sops $(TAILSCALE_ENC) ;; \
		*) echo "Invalid choice" ;; \
	esac

.PHONY: edit-env
edit-env: sops-check-deps ## Edit .enc.env with sops
	@EDITOR="$(SOPS_EDITOR)" SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops $(ENV_ENC)

.PHONY: edit-override
edit-override: sops-check-deps ## Edit docker-compose.override.enc.yml with sops
	@EDITOR="$(SOPS_EDITOR)" SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops $(OVERRIDE_ENC)

.PHONY: edit-tailscale
edit-tailscale: sops-check-deps ## Edit docker-compose.tailscale.override.enc.yml with sops
	@EDITOR="$(SOPS_EDITOR)" SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops $(TAILSCALE_ENC)

.PHONY: validate
validate: sops-check-deps ## Validate all encrypted secrets can be decrypted
	@echo "$(_SOPS_BLUE)Validating Docker encrypted files...$(_SOPS_NC)"
	@_failed=0; _count=0; \
	export SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)"; \
	for file in $(ENV_ENC) $(OVERRIDE_ENC) $(TAILSCALE_ENC); do \
		if [ -f "$$file" ]; then \
			_count=$$((_count + 1)); \
			if sops --decrypt "$$file" > /dev/null 2>&1; then \
				echo "  [$(_SOPS_OK)] $$file"; \
			else \
				echo "  [$(_SOPS_FAIL)] $$file"; \
				_failed=$$((_failed + 1)); \
			fi; \
		fi; \
	done; \
	echo ""; \
	if [ $$_failed -gt 0 ]; then \
		echo "$(_SOPS_RED)Validation failed: $$_failed/$$_count files$(_SOPS_NC)"; \
		exit 1; \
	else \
		echo "$(_SOPS_GREEN)All $$_count file(s) validated successfully$(_SOPS_NC)"; \
	fi

# ============================================================================
# Backward Compatibility Aliases
# ============================================================================
.PHONY: import-age-key
import-age-key: sops-import-key sops-generate-config ## Import Age key (backward compat)
	@:

.PHONY: sops-generate-config
sops-generate-config: ## Generate .sops.yaml from current key
	@if [ ! -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(_SOPS_RED)Error: Key file not found: $(SOPS_AGE_KEY_FILE)$(_SOPS_NC)"; \
		echo "Run: make sops-import-key AGE_KEY_FILE=/path/to/key.txt"; \
		exit 1; \
	fi
	@_pubkey=$$(age-keygen -y "$(SOPS_AGE_KEY_FILE)"); \
	echo "# SOPS configuration for $(SERVICE_NAME) secrets" > .sops.yaml; \
	echo "# Domain: $(SOPS_DOMAIN) | Environment: $(SOPS_ENV_NAME)" >> .sops.yaml; \
	echo "# Generated: $$(date -Iseconds)" >> .sops.yaml; \
	echo "" >> .sops.yaml; \
	echo "creation_rules:" >> .sops.yaml; \
	echo "  # Encrypted environment file (.enc.env)" >> .sops.yaml; \
	echo "  - path_regex: \\.enc\\.env$$" >> .sops.yaml; \
	echo "    age: $$_pubkey" >> .sops.yaml; \
	echo "" >> .sops.yaml; \
	echo "  # Encrypted docker compose override files (*.enc.yml)" >> .sops.yaml; \
	echo "  - path_regex: \\.enc\\.yml$$" >> .sops.yaml; \
	echo "    age: $$_pubkey" >> .sops.yaml
	@echo "$(_SOPS_GREEN).sops.yaml generated successfully$(_SOPS_NC)"
