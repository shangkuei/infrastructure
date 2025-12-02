# ============================================================================
# terraform.mk - Unified Terraform Operations
# ============================================================================
# Shared Makefile include for standardized Terraform operations with SOPS
# encryption integration.
#
# Usage:
#   Include this file in your Terraform environment Makefile after sops.mk:
#     include ../../../makefiles/sops.mk
#     include ../../../makefiles/terraform.mk
#
# Required:
#   - sops.mk must be included before this file
#   - SOPS_DOMAIN and SOPS_ENV_NAME must be set
#
# Optional variables (set before including):
#   TF_TFVARS_ENC        - Encrypted tfvars filename (default: terraform.tfvars.enc)
#   TF_TFVARS_PLAIN      - Plaintext tfvars filename (default: terraform.tfvars)
#   TF_TFVARS_EXAMPLE    - Example tfvars filename (default: terraform.tfvars.example)
#   TF_BACKEND_HCL       - Plaintext backend config (default: backend.hcl)
#   TF_BACKEND_ENC       - Encrypted backend config (default: backend.hcl.enc)
#   TF_BACKEND_EXAMPLE   - Example backend config (default: backend.hcl.example)
#   TF_AUTO_INIT         - Auto-run init before plan/apply (default: false)
#   TF_GENERATED_DIR     - Directory for generated files (default: generated)
#
# Reference:
#   specs/security/unified-sops-operations.md
# ============================================================================

# ============================================================================
# Validation
# ============================================================================

ifndef SOPS_AGE_KEY_FILE
  $(error terraform.mk requires sops.mk to be included first)
endif

# ============================================================================
# Default Configuration
# ============================================================================

# Encrypted files
TF_TFVARS_ENC ?= terraform.tfvars.enc
TF_TFVARS_PLAIN ?= terraform.tfvars
TF_TFVARS_EXAMPLE ?= terraform.tfvars.example

# Backend configuration
TF_BACKEND_HCL ?= backend.hcl
TF_BACKEND_ENC ?= backend.hcl.enc
TF_BACKEND_EXAMPLE ?= backend.hcl.example

# Auto-init before plan/apply
TF_AUTO_INIT ?= false

# Generated files directory
TF_GENERATED_DIR ?= generated

# ============================================================================
# Helper Functions
# ============================================================================

# Run terraform with encrypted tfvars
# Usage: $(call tf_with_vars,command)
define tf_with_vars
	@if [ -f "$(TF_TFVARS_ENC)" ]; then \
		SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops exec-file "$(TF_TFVARS_ENC)" 'terraform $(1) -var-file={}'; \
	elif [ -f "$(TF_TFVARS_PLAIN)" ]; then \
		terraform $(1) -var-file="$(TF_TFVARS_PLAIN)"; \
	else \
		terraform $(1); \
	fi
endef

# Run terraform init with encrypted backend
# Usage: $(call tf_init_backend,extra_args)
define tf_init_backend
	@if [ -f "$(TF_BACKEND_ENC)" ]; then \
		echo "$(_SOPS_BLUE)==> Using encrypted backend: $(TF_BACKEND_ENC)$(_SOPS_NC)"; \
		SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops exec-file "$(TF_BACKEND_ENC)" 'terraform init $(1) -backend-config={}'; \
	elif [ -f "$(TF_BACKEND_HCL)" ]; then \
		echo "$(_SOPS_YELLOW)==> Using plaintext backend: $(TF_BACKEND_HCL)$(_SOPS_NC)"; \
		terraform init $(1) -backend-config="$(TF_BACKEND_HCL)"; \
	else \
		echo "$(_SOPS_YELLOW)==> No backend config, using local state$(_SOPS_NC)"; \
		terraform init $(1); \
	fi
endef

# ============================================================================
# Core Terraform Operations
# ============================================================================

##@ Terraform Core

.PHONY: tf-init
tf-init: ## Initialize Terraform with encrypted backend support
	@echo "$(_SOPS_BLUE)==> Initializing Terraform$(_SOPS_NC)"
	$(call tf_init_backend,)

.PHONY: tf-plan
tf-plan: ## Generate Terraform execution plan
ifeq ($(TF_AUTO_INIT),true)
	@$(MAKE) -s tf-init
endif
	@echo "$(_SOPS_BLUE)==> Generating Terraform plan$(_SOPS_NC)"
	$(call tf_with_vars,plan)

.PHONY: tf-apply
tf-apply: ## Apply Terraform changes
ifeq ($(TF_AUTO_INIT),true)
	@$(MAKE) -s tf-init
endif
	@echo "$(_SOPS_BLUE)==> Applying Terraform changes$(_SOPS_NC)"
	$(call tf_with_vars,apply)

.PHONY: tf-destroy
tf-destroy: ## Destroy Terraform-managed infrastructure
	@echo "$(_SOPS_RED)==> WARNING: This will destroy infrastructure$(_SOPS_NC)"
	@printf "Type 'yes' to confirm: "; \
	read -r confirm; \
	if [ "$$confirm" != "yes" ]; then \
		echo "Aborted."; \
		exit 0; \
	fi
	$(call tf_with_vars,destroy)

# ============================================================================
# Validation Operations
# ============================================================================

##@ Terraform Validation

.PHONY: tf-validate
tf-validate: ## Validate Terraform configuration
	@echo "$(_SOPS_BLUE)==> Validating Terraform configuration$(_SOPS_NC)"
	@terraform validate

.PHONY: tf-fmt
tf-fmt: ## Format Terraform files
	@echo "$(_SOPS_BLUE)==> Formatting Terraform files$(_SOPS_NC)"
	@terraform fmt -recursive

.PHONY: tf-lint
tf-lint: tf-validate tf-fmt ## Run validate + format
	@echo "$(_SOPS_GREEN)==> All checks passed$(_SOPS_NC)"

# ============================================================================
# SOPS Encryption Operations
# ============================================================================

##@ Terraform SOPS

.PHONY: tf-encrypt-backend
tf-encrypt-backend: sops-check-deps sops-check-config ## Encrypt backend.hcl
	@if [ ! -f "$(TF_BACKEND_HCL)" ]; then \
		echo "$(_SOPS_RED)Error: $(TF_BACKEND_HCL) not found$(_SOPS_NC)"; \
		echo ""; \
		if [ -f "$(TF_BACKEND_EXAMPLE)" ]; then \
			echo "Create from example: cp $(TF_BACKEND_EXAMPLE) $(TF_BACKEND_HCL)"; \
		fi; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)==> Encrypting $(TF_BACKEND_HCL)$(_SOPS_NC)"
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops -e "$(TF_BACKEND_HCL)" > "$(TF_BACKEND_ENC)"
	@echo "$(_SOPS_GREEN)==> Encrypted to $(TF_BACKEND_ENC)$(_SOPS_NC)"
	@echo ""
	@echo "$(_SOPS_YELLOW)Next:$(_SOPS_NC) rm $(TF_BACKEND_HCL)"

.PHONY: tf-encrypt-tfvars
tf-encrypt-tfvars: sops-check-deps sops-check-config ## Encrypt terraform.tfvars
	@if [ ! -f "$(TF_TFVARS_PLAIN)" ]; then \
		echo "$(_SOPS_RED)Error: $(TF_TFVARS_PLAIN) not found$(_SOPS_NC)"; \
		echo ""; \
		if [ -f "$(TF_TFVARS_EXAMPLE)" ]; then \
			echo "Create from example: cp $(TF_TFVARS_EXAMPLE) $(TF_TFVARS_PLAIN)"; \
		fi; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)==> Encrypting $(TF_TFVARS_PLAIN)$(_SOPS_NC)"
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops -e "$(TF_TFVARS_PLAIN)" > "$(TF_TFVARS_ENC)"
	@echo "$(_SOPS_GREEN)==> Encrypted to $(TF_TFVARS_ENC)$(_SOPS_NC)"
	@echo ""
	@echo "$(_SOPS_YELLOW)Next:$(_SOPS_NC) rm $(TF_TFVARS_PLAIN)"

.PHONY: tf-edit-backend
tf-edit-backend: sops-check-deps ## Edit encrypted backend.hcl
	@if [ ! -f "$(TF_BACKEND_ENC)" ]; then \
		echo "$(_SOPS_RED)Error: $(TF_BACKEND_ENC) not found$(_SOPS_NC)"; \
		echo ""; \
		echo "Create and encrypt first: make tf-encrypt-backend"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)==> Editing $(TF_BACKEND_ENC)$(_SOPS_NC)"
	@EDITOR="$(SOPS_EDITOR)" SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops "$(TF_BACKEND_ENC)"

.PHONY: tf-edit-tfvars
tf-edit-tfvars: sops-check-deps ## Edit encrypted terraform.tfvars
	@if [ ! -f "$(TF_TFVARS_ENC)" ]; then \
		echo "$(_SOPS_RED)Error: $(TF_TFVARS_ENC) not found$(_SOPS_NC)"; \
		echo ""; \
		echo "Create and encrypt first: make tf-encrypt-tfvars"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)==> Editing $(TF_TFVARS_ENC)$(_SOPS_NC)"
	@EDITOR="$(SOPS_EDITOR)" SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops "$(TF_TFVARS_ENC)"

.PHONY: tf-sops-validate
tf-sops-validate: sops-check-deps sops-check-config ## Validate encrypted Terraform files
	@echo "$(_SOPS_BLUE)Validating Terraform encrypted files...$(_SOPS_NC)"
	@if [ ! -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(_SOPS_RED)Error: Private key not found: $(SOPS_AGE_KEY_FILE)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@_failed=0; _count=0; \
	for file in $(TF_BACKEND_ENC) $(TF_TFVARS_ENC); do \
		if [ -f "$$file" ]; then \
			_count=$$((_count + 1)); \
			if SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops -d "$$file" > /dev/null 2>&1; then \
				echo "  [$(_SOPS_OK)] $$file"; \
			else \
				echo "  [$(_SOPS_FAIL)] $$file"; \
				_failed=$$((_failed + 1)); \
			fi; \
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
# Utility Operations
# ============================================================================

##@ Terraform Utilities

.PHONY: tf-output
tf-output: ## Show Terraform outputs
	@echo "$(_SOPS_BLUE)==> Terraform Outputs$(_SOPS_NC)"
	@terraform output

.PHONY: tf-clean
tf-clean: ## Remove .terraform directory and local state
	@echo "$(_SOPS_YELLOW)==> Cleaning Terraform files$(_SOPS_NC)"
	@rm -rf .terraform .terraform.lock.hcl
	@rm -f terraform.tfstate terraform.tfstate.backup
	@if [ -d "$(TF_GENERATED_DIR)" ]; then \
		rm -rf "$(TF_GENERATED_DIR)"; \
		echo "  Removed: $(TF_GENERATED_DIR)/"; \
	fi
	@echo "$(_SOPS_GREEN)==> Clean complete$(_SOPS_NC)"

.PHONY: tf-upgrade
tf-upgrade: ## Upgrade Terraform providers
	@echo "$(_SOPS_BLUE)==> Upgrading Terraform providers$(_SOPS_NC)"
	$(call tf_init_backend,-upgrade)

# ============================================================================
# Help Target
# ============================================================================

.PHONY: tf-help
tf-help: ## Show Terraform operations help
	@echo ""
	@echo "$(_SOPS_BOLD)Terraform Operations$(_SOPS_NC) - $(SOPS_ENV_NAME)"
	@echo ""
	@echo "$(_SOPS_BOLD)Core Commands:$(_SOPS_NC)"
	@echo "  tf-init            Initialize Terraform (auto-decrypts backend)"
	@echo "  tf-plan            Generate execution plan (auto-decrypts tfvars)"
	@echo "  tf-apply           Apply changes (auto-decrypts tfvars)"
	@echo "  tf-destroy         Destroy infrastructure (with confirmation)"
	@echo ""
	@echo "$(_SOPS_BOLD)Validation:$(_SOPS_NC)"
	@echo "  tf-validate        Validate Terraform configuration"
	@echo "  tf-fmt             Format Terraform files"
	@echo "  tf-lint            Run validate + format"
	@echo ""
	@echo "$(_SOPS_BOLD)SOPS Encryption:$(_SOPS_NC)"
	@echo "  tf-encrypt-backend Encrypt backend.hcl"
	@echo "  tf-encrypt-tfvars  Encrypt terraform.tfvars"
	@echo "  tf-edit-backend    Edit encrypted backend.hcl"
	@echo "  tf-edit-tfvars     Edit encrypted terraform.tfvars"
	@echo "  tf-sops-validate   Validate encrypted files"
	@echo ""
	@echo "$(_SOPS_BOLD)Utilities:$(_SOPS_NC)"
	@echo "  tf-output          Show Terraform outputs"
	@echo "  tf-clean           Remove .terraform and local state"
	@echo "  tf-upgrade         Upgrade Terraform providers"
	@echo ""
	@echo "$(_SOPS_BOLD)Files:$(_SOPS_NC)"
	@echo "  Backend enc:       $(TF_BACKEND_ENC)"
	@echo "  Tfvars enc:        $(TF_TFVARS_ENC)"
	@echo ""

# ============================================================================
# Workflow Target
# ============================================================================

.PHONY: tf-workflow
tf-workflow: ## Show Terraform + SOPS setup workflow
	@echo ""
	@echo "$(_SOPS_BOLD)Terraform + SOPS Setup Workflow$(_SOPS_NC)"
	@echo "========================================"
	@echo ""
	@echo "$(_SOPS_YELLOW)1. Initial Setup:$(_SOPS_NC)"
	@echo "   make sops-keygen          # Generate age key"
	@echo "   # Update .sops.yaml with public key"
	@echo ""
	@echo "$(_SOPS_YELLOW)2. Backend Configuration:$(_SOPS_NC)"
	@echo "   cp $(TF_BACKEND_EXAMPLE) $(TF_BACKEND_HCL)"
	@echo "   # Edit $(TF_BACKEND_HCL) with credentials"
	@echo "   make tf-encrypt-backend"
	@echo "   rm $(TF_BACKEND_HCL)"
	@echo ""
	@echo "$(_SOPS_YELLOW)3. Variables Configuration:$(_SOPS_NC)"
	@echo "   cp $(TF_TFVARS_EXAMPLE) $(TF_TFVARS_PLAIN)"
	@echo "   # Edit $(TF_TFVARS_PLAIN) with secrets"
	@echo "   make tf-encrypt-tfvars"
	@echo "   rm $(TF_TFVARS_PLAIN)"
	@echo ""
	@echo "$(_SOPS_YELLOW)4. Daily Usage:$(_SOPS_NC)"
	@echo "   make tf-init     # Auto-decrypts backend"
	@echo "   make tf-plan     # Auto-decrypts tfvars"
	@echo "   make tf-apply    # Auto-decrypts tfvars"
	@echo ""
