# ============================================================================
# sops.mk - Unified SOPS Operations
# ============================================================================
# Shared Makefile include for standardized SOPS secret management operations
# across Terraform, Kubernetes, and Docker domains.
#
# Usage:
#   Include this file in your domain Makefile:
#     include ../../../makefiles/sops.mk
#
# Required variables (set before including):
#   SOPS_DOMAIN        - Domain identifier (terraform|kubernetes|docker)
#   SOPS_ENV_NAME      - Environment name for key naming
#
# Optional variables:
#   SOPS_KEY_STRATEGY  - Key location strategy (central|local)
#                        central: ~/.config/sops/age/{env}.txt (default)
#                        local: ./age-key.txt in current directory
#   SOPS_AGE_DIR       - Central key directory (default: ~/.config/sops/age)
#   SOPS_LOCAL_KEY     - Local key filename (default: age-key.txt)
#   SOPS_CONFIG        - SOPS config filename (default: .sops.yaml)
#   SOPS_EDITOR        - Editor for sops edit (default: $EDITOR or vim)
#   SOPS_COLOR         - Enable color output (default: true)
#
# Reference:
#   specs/security/unified-sops-operations.md
# ============================================================================

# ============================================================================
# Default Configuration
# ============================================================================

# Key location strategy: central (user home) or local (current directory)
SOPS_KEY_STRATEGY ?= central

# Central key storage directory
SOPS_AGE_DIR ?= $(HOME)/.config/sops/age

# Local key filename (used when SOPS_KEY_STRATEGY=local)
SOPS_LOCAL_KEY ?= age-key.txt

# SOPS configuration file
SOPS_CONFIG ?= .sops.yaml

# Editor for sops edit command (default: VSCode with wait)
SOPS_EDITOR ?= $(if $(EDITOR),$(EDITOR),code --wait)

# Enable colored output
SOPS_COLOR ?= true

# ============================================================================
# Computed Variables
# ============================================================================

# Determine key file path based on strategy
ifeq ($(SOPS_KEY_STRATEGY),central)
  SOPS_AGE_KEY_FILE := $(SOPS_AGE_DIR)/$(SOPS_ENV_NAME).txt
  SOPS_AGE_PUB_FILE := $(SOPS_AGE_DIR)/$(SOPS_ENV_NAME).txt.pub
else ifeq ($(SOPS_KEY_STRATEGY),local)
  SOPS_AGE_KEY_FILE := $(CURDIR)/$(SOPS_LOCAL_KEY)
  SOPS_AGE_PUB_FILE :=
else
  $(error SOPS_KEY_STRATEGY must be 'central' or 'local', got '$(SOPS_KEY_STRATEGY)')
endif

# Color codes (conditional on SOPS_COLOR)
# Use $$(tput ...) for portable color support across shells
ifeq ($(SOPS_COLOR),true)
  _SOPS_RED    := $$(tput setaf 1)
  _SOPS_GREEN  := $$(tput setaf 2)
  _SOPS_YELLOW := $$(tput setaf 3)
  _SOPS_BLUE   := $$(tput setaf 4)
  _SOPS_CYAN   := $$(tput setaf 6)
  _SOPS_BOLD   := $$(tput bold)
  _SOPS_NC     := $$(tput sgr0)
else
  _SOPS_RED    :=
  _SOPS_GREEN  :=
  _SOPS_YELLOW :=
  _SOPS_BLUE   :=
  _SOPS_CYAN   :=
  _SOPS_BOLD   :=
  _SOPS_NC     :=
endif

# Status indicators
_SOPS_OK   := $(_SOPS_GREEN)OK$(_SOPS_NC)
_SOPS_FAIL := $(_SOPS_RED)FAIL$(_SOPS_NC)
_SOPS_WARN := $(_SOPS_YELLOW)WARN$(_SOPS_NC)
_SOPS_INFO := $(_SOPS_CYAN)INFO$(_SOPS_NC)

# ============================================================================
# Validation
# ============================================================================

# Ensure required variables are set
ifndef SOPS_DOMAIN
  $(warning SOPS_DOMAIN not set, defaulting to 'unknown')
  SOPS_DOMAIN := unknown
endif

ifndef SOPS_ENV_NAME
  $(warning SOPS_ENV_NAME not set, defaulting to 'default')
  SOPS_ENV_NAME := default
endif

# ============================================================================
# Tier 1: Universal Targets
# ============================================================================

##@ SOPS General

.PHONY: sops-help
sops-help: ## Show SOPS operations help
	@echo ""
	@echo "$(_SOPS_BOLD)SOPS Operations$(_SOPS_NC) - $(SOPS_DOMAIN)/$(SOPS_ENV_NAME)"
	@echo "Strategy: $(SOPS_KEY_STRATEGY) | Key: $(SOPS_AGE_KEY_FILE)"
	@echo ""
	@echo "$(_SOPS_BOLD)Universal:$(_SOPS_NC)"
	@echo "  sops-help          Show this help message"
	@echo "  sops-check-deps    Verify sops and age are installed"
	@echo "  sops-check-config  Verify .sops.yaml configuration"
	@echo "  sops-info          Display encryption configuration"
	@echo "  sops-validate      Validate all encrypted files"
	@echo ""
	@echo "$(_SOPS_BOLD)Key Management:$(_SOPS_NC)"
	@echo "  sops-keygen        Generate new age key pair"
	@echo "  sops-import-key    Import existing key (AGE_KEY_FILE=path)"
	@echo "  sops-export-public Export public key for sharing"
	@echo "  sops-rotate-key    Rotate encryption key"
	@echo ""
	@echo "$(_SOPS_BOLD)Operations:$(_SOPS_NC)"
	@echo "  sops-encrypt       Encrypt file (FILE=path)"
	@echo "  sops-decrypt       Decrypt file to stdout (FILE=path)"
	@echo "  sops-edit          Edit encrypted file (FILE=path)"
	@echo "  sops-rekey         Re-encrypt with current key (FILE=path)"
	@echo "  sops-clean         Remove decrypted/temporary files"
	@echo ""
	@echo "$(_SOPS_BOLD)Variables:$(_SOPS_NC)"
	@echo "  FILE=path          Target file for encrypt/decrypt/edit"
	@echo "  AGE_KEY_FILE=path  Source key for import-key"
	@echo ""

.PHONY: sops-check-deps
sops-check-deps: ## Verify sops and age are installed
	@echo "$(_SOPS_BLUE)Checking dependencies...$(_SOPS_NC)"
	@_ok=true; \
	if command -v sops >/dev/null 2>&1; then \
		echo "  [$(_SOPS_OK)] sops: $$(sops --version 2>&1 | head -1 | sed 's/sops //')"; \
	else \
		echo "  [$(_SOPS_FAIL)] sops: not installed"; \
		echo "       Install: brew install sops"; \
		_ok=false; \
	fi; \
	if command -v age >/dev/null 2>&1; then \
		echo "  [$(_SOPS_OK)] age:  $$(age --version 2>&1 | head -1)"; \
	else \
		echo "  [$(_SOPS_FAIL)] age:  not installed"; \
		echo "       Install: brew install age"; \
		_ok=false; \
	fi; \
	if command -v age-keygen >/dev/null 2>&1; then \
		echo "  [$(_SOPS_OK)] age-keygen: available"; \
	else \
		echo "  [$(_SOPS_FAIL)] age-keygen: not installed"; \
		_ok=false; \
	fi; \
	if [ "$$_ok" = "false" ]; then \
		echo ""; \
		echo "$(_SOPS_RED)Missing dependencies. Please install and retry.$(_SOPS_NC)"; \
		exit 1; \
	fi; \
	echo "$(_SOPS_GREEN)All dependencies satisfied$(_SOPS_NC)"

.PHONY: sops-check-config
sops-check-config: ## Verify .sops.yaml configuration exists
	@echo "$(_SOPS_BLUE)Checking SOPS configuration...$(_SOPS_NC)"
	@if [ ! -f "$(SOPS_CONFIG)" ]; then \
		echo "  [$(_SOPS_FAIL)] $(SOPS_CONFIG) not found"; \
		echo ""; \
		echo "To create configuration:"; \
		if [ "$(SOPS_KEY_STRATEGY)" = "central" ]; then \
			echo "  make sops-keygen"; \
			echo "  (Then manually create $(SOPS_CONFIG) with public key)"; \
		else \
			echo "  make sops-import-key AGE_KEY_FILE=/path/to/key.txt"; \
		fi; \
		exit 1; \
	fi
	@echo "  [$(_SOPS_OK)] Config: $(SOPS_CONFIG)"
	@echo ""
	@echo "Creation rules:"
	@grep -E "path_regex:|age:|encrypted_regex:" $(SOPS_CONFIG) 2>/dev/null | sed 's/^/  /' || echo "  (none found)"
	@echo ""
	@echo "$(_SOPS_GREEN)Configuration valid$(_SOPS_NC)"

.PHONY: sops-info
sops-info: sops-check-deps ## Display encryption configuration
	@echo ""
	@echo "$(_SOPS_BOLD)SOPS Configuration$(_SOPS_NC)"
	@echo "==============================================="
	@echo "Domain:         $(SOPS_DOMAIN)"
	@echo "Environment:    $(SOPS_ENV_NAME)"
	@echo "Key Strategy:   $(SOPS_KEY_STRATEGY)"
	@echo "Key File:       $(SOPS_AGE_KEY_FILE)"
	@echo "Config File:    $(SOPS_CONFIG)"
	@echo "==============================================="
	@echo ""
	@echo "$(_SOPS_BOLD)Key Status:$(_SOPS_NC)"
	@if [ -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "  [$(_SOPS_OK)] Private key exists"; \
		echo ""; \
		echo "  Public key:"; \
		age-keygen -y "$(SOPS_AGE_KEY_FILE)" 2>/dev/null | sed 's/^/    /'; \
	else \
		echo "  [$(_SOPS_WARN)] Private key not found"; \
		echo "       Expected: $(SOPS_AGE_KEY_FILE)"; \
		if [ "$(SOPS_KEY_STRATEGY)" = "central" ]; then \
			echo "       Run: make sops-keygen"; \
		else \
			echo "       Run: make sops-import-key AGE_KEY_FILE=/path/to/key.txt"; \
		fi; \
	fi
	@echo ""
	@echo "$(_SOPS_BOLD)Config Status:$(_SOPS_NC)"
	@if [ -f "$(SOPS_CONFIG)" ]; then \
		echo "  [$(_SOPS_OK)] $(SOPS_CONFIG) exists"; \
		echo ""; \
		echo "  Public key(s) in config:"; \
		grep -oE "age1[a-z0-9]+" $(SOPS_CONFIG) 2>/dev/null | sort -u | sed 's/^/    /' || echo "    (none found)"; \
	else \
		echo "  [$(_SOPS_WARN)] $(SOPS_CONFIG) not found"; \
	fi
	@echo ""

.PHONY: sops-validate
sops-validate: sops-check-deps sops-check-config ## Validate all encrypted files can be decrypted
	@echo "$(_SOPS_BLUE)Validating encrypted files...$(_SOPS_NC)"
	@if [ ! -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(_SOPS_RED)Error: Private key not found: $(SOPS_AGE_KEY_FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@_failed=0; _count=0; \
	for file in $$(find . -maxdepth 2 \( -name "*.enc" -o -name "*.enc.*" -o -name "*.yaml.enc" -o -name "*.yml.enc" -o -name "*.json.enc" \) -type f 2>/dev/null | sort); do \
		_count=$$(($$_count + 1)); \
		if SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops -d "$$file" > /dev/null 2>&1; then \
			echo "  [$(_SOPS_OK)] $$file"; \
		else \
			echo "  [$(_SOPS_FAIL)] $$file"; \
			_failed=$$(($$_failed + 1)); \
		fi; \
	done; \
	echo ""; \
	if [ $$_count -eq 0 ]; then \
		echo "$(_SOPS_YELLOW)No encrypted files found$(_SOPS_NC)"; \
	elif [ $$_failed -gt 0 ]; then \
		echo "$(_SOPS_RED)Validation failed: $$_failed/$$_count files$(_SOPS_NC)"; \
		exit 1; \
	else \
		echo "$(_SOPS_GREEN)All $$_count file(s) validated successfully$(_SOPS_NC)"; \
	fi

# ============================================================================
# Tier 2: Key Management Targets
# ============================================================================

##@ SOPS Key Management

.PHONY: sops-keygen
sops-keygen: sops-check-deps ## Generate new age key pair
	@echo "$(_SOPS_BLUE)Generating age key pair...$(_SOPS_NC)"
	@echo "Strategy: $(SOPS_KEY_STRATEGY)"
	@echo "Environment: $(SOPS_ENV_NAME)"
	@echo ""
ifeq ($(SOPS_KEY_STRATEGY),central)
	@mkdir -p "$(SOPS_AGE_DIR)"
	@if [ -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(_SOPS_YELLOW)Warning: Key already exists: $(SOPS_AGE_KEY_FILE)$(_SOPS_NC)"; \
		printf "Overwrite? [y/N] "; \
		read -r confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo "Aborted."; \
			exit 0; \
		fi; \
	fi
	@age-keygen -o "$(SOPS_AGE_KEY_FILE)" 2>&1
	@chmod 600 "$(SOPS_AGE_KEY_FILE)"
	@age-keygen -y "$(SOPS_AGE_KEY_FILE)" > "$(SOPS_AGE_PUB_FILE)"
	@chmod 644 "$(SOPS_AGE_PUB_FILE)"
	@echo ""
	@echo "$(_SOPS_GREEN)Key generated successfully$(_SOPS_NC)"
	@echo ""
	@echo "Files created:"
	@echo "  Private key: $(SOPS_AGE_KEY_FILE)"
	@echo "  Public key:  $(SOPS_AGE_PUB_FILE)"
	@echo ""
	@echo "Public key value:"
	@cat "$(SOPS_AGE_PUB_FILE)" | sed 's/^/  /'
	@echo ""
	@echo "$(_SOPS_YELLOW)IMPORTANT - Next steps:$(_SOPS_NC)"
	@echo "  1. $(_SOPS_BOLD)Backup$(_SOPS_NC) private key to password manager"
	@echo "  2. $(_SOPS_BOLD)Update$(_SOPS_NC) $(SOPS_CONFIG) with public key above"
	@echo "  3. $(_SOPS_BOLD)Never$(_SOPS_NC) commit private key to Git"
	@echo ""
else
	@echo "$(_SOPS_YELLOW)Local strategy uses import, not keygen$(_SOPS_NC)"
	@echo "Run: make sops-import-key AGE_KEY_FILE=/path/to/key.txt"
endif

.PHONY: sops-import-key
sops-import-key: sops-check-deps ## Import existing age key (AGE_KEY_FILE=path)
	@echo "$(_SOPS_BLUE)Importing age key...$(_SOPS_NC)"
ifndef AGE_KEY_FILE
	@echo "$(_SOPS_RED)Error: AGE_KEY_FILE not specified$(_SOPS_NC)"
	@echo ""
	@echo "Usage: make sops-import-key AGE_KEY_FILE=/path/to/key.txt"
	@exit 1
endif
	@if [ ! -f "$(AGE_KEY_FILE)" ]; then \
		echo "$(_SOPS_RED)Error: Key file not found: $(AGE_KEY_FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@# Validate age key format
	@if ! grep -q "AGE-SECRET-KEY" "$(AGE_KEY_FILE)"; then \
		echo "$(_SOPS_RED)Error: Invalid age key format$(_SOPS_NC)"; \
		echo "Expected file containing AGE-SECRET-KEY"; \
		exit 1; \
	fi
	@# Handle based on strategy
ifeq ($(SOPS_KEY_STRATEGY),local)
	@if [ -f "$(SOPS_LOCAL_KEY)" ]; then \
		echo "$(_SOPS_YELLOW)Warning: $(SOPS_LOCAL_KEY) already exists$(_SOPS_NC)"; \
		printf "Overwrite? [y/N] "; \
		read -r confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo "Aborted."; \
			exit 0; \
		fi; \
	fi
	@cp "$(AGE_KEY_FILE)" "$(SOPS_LOCAL_KEY)"
	@chmod 600 "$(SOPS_LOCAL_KEY)"
	@echo "  [$(_SOPS_OK)] Key copied to $(SOPS_LOCAL_KEY)"
	@# Extract public key
	@_pubkey=$$(age-keygen -y "$(SOPS_LOCAL_KEY)"); \
	echo "  [$(_SOPS_INFO)] Public key: $$_pubkey"
	@echo ""
	@echo "$(_SOPS_GREEN)Key imported successfully$(_SOPS_NC)"
	@echo ""
	@echo "$(_SOPS_YELLOW)Next step:$(_SOPS_NC) Create or update $(SOPS_CONFIG)"
	@echo "You may need to run a domain-specific target to generate the config."
else
	@mkdir -p "$(SOPS_AGE_DIR)"
	@cp "$(AGE_KEY_FILE)" "$(SOPS_AGE_KEY_FILE)"
	@chmod 600 "$(SOPS_AGE_KEY_FILE)"
	@age-keygen -y "$(SOPS_AGE_KEY_FILE)" > "$(SOPS_AGE_PUB_FILE)"
	@chmod 644 "$(SOPS_AGE_PUB_FILE)"
	@echo "  [$(_SOPS_OK)] Key imported to $(SOPS_AGE_KEY_FILE)"
	@echo "  [$(_SOPS_OK)] Public key: $(SOPS_AGE_PUB_FILE)"
	@echo ""
	@echo "$(_SOPS_GREEN)Key imported successfully$(_SOPS_NC)"
endif

.PHONY: sops-export-public
sops-export-public: sops-check-deps ## Export public key for sharing
	@if [ ! -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(_SOPS_RED)Error: Private key not found: $(SOPS_AGE_KEY_FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@age-keygen -y "$(SOPS_AGE_KEY_FILE)"

.PHONY: sops-rotate-key
sops-rotate-key: sops-check-deps sops-check-config ## Rotate encryption key (generates new key)
	@echo "$(_SOPS_BLUE)Key Rotation Procedure$(_SOPS_NC)"
	@echo ""
	@echo "This is a multi-step manual process:"
	@echo ""
	@echo "1. Generate new key:"
	@echo "   make sops-keygen SOPS_ENV_NAME=$(SOPS_ENV_NAME)-new"
	@echo ""
	@echo "2. Update $(SOPS_CONFIG) with BOTH keys (old + new)"
	@echo "   This allows decryption during transition"
	@echo ""
	@echo "3. Re-encrypt all files with new key:"
	@echo "   sops updatekeys <file>"
	@echo "   (or use: make sops-rekey FILE=<file>)"
	@echo ""
	@echo "4. Verify decryption with new key only"
	@echo ""
	@echo "5. Remove old key from $(SOPS_CONFIG)"
	@echo ""
	@echo "6. Update GitHub Secrets with new key"
	@echo ""
	@echo "7. Securely delete old key file"
	@echo ""
	@echo "See: docs/runbooks/0008-sops-secret-management.md"

# ============================================================================
# Tier 3: Encryption Operations
# ============================================================================

##@ SOPS Encryption

.PHONY: sops-encrypt
sops-encrypt: sops-check-deps sops-check-config ## Encrypt file (FILE=path)
ifndef FILE
	@echo "$(_SOPS_RED)Error: FILE not specified$(_SOPS_NC)"
	@echo ""
	@echo "Usage: make sops-encrypt FILE=path/to/file"
	@exit 1
endif
	@if [ ! -f "$(FILE)" ]; then \
		echo "$(_SOPS_RED)Error: File not found: $(FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@# Check if already encrypted
	@if head -5 "$(FILE)" | grep -q "sops:" 2>/dev/null; then \
		echo "$(_SOPS_YELLOW)Warning: File appears to be already encrypted$(_SOPS_NC)"; \
		printf "Continue anyway? [y/N] "; \
		read -r confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo "Aborted."; \
			exit 0; \
		fi; \
	fi
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --encrypt --in-place "$(FILE)"
	@echo "$(_SOPS_GREEN)Encrypted: $(FILE)$(_SOPS_NC)"

.PHONY: sops-decrypt
sops-decrypt: sops-check-deps ## Decrypt file to stdout (FILE=path)
ifndef FILE
	@echo "$(_SOPS_RED)Error: FILE not specified$(_SOPS_NC)"
	@echo ""
	@echo "Usage: make sops-decrypt FILE=path/to/file"
	@exit 1
endif
	@if [ ! -f "$(FILE)" ]; then \
		echo "$(_SOPS_RED)Error: File not found: $(FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --decrypt "$(FILE)"

.PHONY: sops-edit
sops-edit: sops-check-deps ## Edit encrypted file (FILE=path)
ifndef FILE
	@echo "$(_SOPS_RED)Error: FILE not specified$(_SOPS_NC)"
	@echo ""
	@echo "Usage: make sops-edit FILE=path/to/file"
	@exit 1
endif
	@if [ ! -f "$(FILE)" ]; then \
		echo "$(_SOPS_RED)Error: File not found: $(FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@EDITOR="$(SOPS_EDITOR)" SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops "$(FILE)"

.PHONY: sops-rekey
sops-rekey: sops-check-deps sops-check-config ## Re-encrypt file with current config (FILE=path)
ifndef FILE
	@echo "$(_SOPS_RED)Error: FILE not specified$(_SOPS_NC)"
	@echo ""
	@echo "Usage: make sops-rekey FILE=path/to/file"
	@echo ""
	@echo "This updates the file's encryption to match current .sops.yaml"
	@exit 1
endif
	@if [ ! -f "$(FILE)" ]; then \
		echo "$(_SOPS_RED)Error: File not found: $(FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops updatekeys -y "$(FILE)"
	@echo "$(_SOPS_GREEN)Re-keyed: $(FILE)$(_SOPS_NC)"

.PHONY: sops-clean
sops-clean: ## Remove decrypted/temporary files
	@echo "$(_SOPS_BLUE)Cleaning temporary files...$(_SOPS_NC)"
	@_count=0; \
	for pattern in "*.decrypted" "*.decrypted.*" "*.plaintext" "*.plain"; do \
		for file in $$(find . -maxdepth 2 -name "$$pattern" -type f 2>/dev/null); do \
			rm -f "$$file"; \
			echo "  Removed: $$file"; \
			_count=$$(($$_count + 1)); \
		done; \
	done; \
	if [ $$_count -eq 0 ]; then \
		echo "  No temporary files found"; \
	else \
		echo ""; \
		echo "$(_SOPS_GREEN)Removed $$_count file(s)$(_SOPS_NC)"; \
	fi

# ============================================================================
# Backward Compatibility Note
# ============================================================================
# Domain Makefiles should define their own backward compatibility aliases
# to avoid conflicts. Example:
#
#   age-keygen: sops-keygen
#   	@:
#
#   encrypt-backend: sops-encrypt-backend
#   	@:

# ============================================================================
# Helper Functions (for use by domain Makefiles)
# ============================================================================

# Function to check if a file is encrypted
# Usage: $(call sops_is_encrypted,filename)
# Returns: true if file appears encrypted, false otherwise
define sops_is_encrypted
$(shell head -5 "$(1)" 2>/dev/null | grep -q "sops:" && echo true || echo false)
endef

# Function to get public key from private key file
# Usage: $(call sops_get_public_key,keyfile)
define sops_get_public_key
$(shell age-keygen -y "$(1)" 2>/dev/null)
endef

# Function to generate .sops.yaml header
# Usage: $(call sops_config_header)
define sops_config_header
	@echo "# SOPS configuration for $(SOPS_ENV_NAME)" > $(SOPS_CONFIG)
	@echo "# Domain: $(SOPS_DOMAIN)" >> $(SOPS_CONFIG)
	@echo "# Generated: $$(date -Iseconds)" >> $(SOPS_CONFIG)
	@echo "# DO NOT manually add private keys to this file" >> $(SOPS_CONFIG)
	@echo "creation_rules:" >> $(SOPS_CONFIG)
endef

# Function to add a creation rule
# Usage: $(call sops_add_rule,path_regex,age_key,[encrypted_regex])
# Example: $(call sops_add_rule,.*\.tfvars$$,age1abc...,'')
define sops_add_rule
	@echo "  - path_regex: $(1)" >> $(SOPS_CONFIG)
	@if [ -n "$(3)" ]; then \
		echo "    encrypted_regex: '$(3)'" >> $(SOPS_CONFIG); \
	fi
	@echo "    age: $(2)" >> $(SOPS_CONFIG)
endef
