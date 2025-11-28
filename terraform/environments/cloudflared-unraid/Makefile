# Cloudflared EDATW Environment - Makefile
# Manages Cloudflared tunnel configuration with SOPS encryption

.PHONY: help init plan apply destroy clean validate lint format
.PHONY: age-keygen age-info encrypt-backend encrypt-tfvars

# Default target
.DEFAULT_GOAL := help

# SOPS configuration
AGE_DIR := $(HOME)/.config/sops/age
AGE_PRIVATE_KEY := $(AGE_DIR)/cloudflared-unraid.txt
AGE_PUBLIC_KEY := $(AGE_DIR)/cloudflared-unraid.txt.pub
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

apply: ## Apply Terraform configuration
	@echo "$(BLUE)Applying Terraform changes...$(NC)"
	@if [ -f $(TFVARS_ENC) ]; then \
		echo "$(BLUE)==> Using encrypted variables from $(TFVARS_ENC)$(NC)"; \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(TFVARS_ENC) 'terraform apply -var-file={}'; \
	else \
		echo "$(YELLOW)==> Warning: $(TFVARS_ENC) not found, using default variables$(NC)"; \
		terraform apply; \
	fi

destroy: ## Destroy Terraform-managed infrastructure
	@echo "$(RED)Destroying Terraform-managed infrastructure...$(NC)"
	@if [ -f $(TFVARS_ENC) ]; then \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(TFVARS_ENC) 'terraform destroy -var-file={}'; \
	else \
		terraform destroy; \
	fi

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	@terraform validate

format: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	@terraform fmt -recursive

lint: validate format ## Run validation and formatting

##@ Maintenance

clean: ## Remove Terraform local files
	@echo "$(YELLOW)Removing Terraform local files...$(NC)"
	@rm -rf .terraform .terraform.lock.hcl
	@echo "$(GREEN)✓ Local files removed$(NC)"

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
	@echo "5. Store key in GitHub Secret: SOPS_AGE_KEY_CLOUDFLARED_EDATW"

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

##@ Workflow

workflow: ## Show SOPS setup workflow
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)SOPS Encryption Setup Workflow$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Initial Setup:$(NC)"
	@echo "  1. make age-keygen                 # Generate age encryption key"
	@echo "  2. Update .sops.yaml with public key"
	@echo ""
	@echo "$(YELLOW)Backend Configuration:$(NC)"
	@echo "  3. cp backend.hcl.example backend.hcl"
	@echo "  4. vim backend.hcl                 # Add R2 credentials"
	@echo "  5. make encrypt-backend            # Encrypt backend config"
	@echo "  6. rm backend.hcl                  # Remove plaintext"
	@echo "  7. Edit backend.tf, uncomment terraform { backend \"s3\" {} }"
	@echo ""
	@echo "$(YELLOW)Variables Configuration:$(NC)"
	@echo "  8. cp terraform.tfvars.example terraform.tfvars"
	@echo "  9. vim terraform.tfvars            # Add secrets"
	@echo "  10. make encrypt-tfvars            # Encrypt variables"
	@echo "  11. rm terraform.tfvars            # Remove plaintext"
	@echo ""
	@echo "$(YELLOW)Daily Usage:$(NC)"
	@echo "  make init                          # Auto-decrypts backend.hcl.enc"
	@echo "  make plan                          # Auto-decrypts terraform.tfvars.enc"
	@echo "  make apply                         # Auto-decrypts terraform.tfvars.enc"
