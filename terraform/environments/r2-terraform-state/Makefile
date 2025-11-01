# Makefile for Terraform State Backend Environment
# Manages R2 backend deployment and age encryption setup

.PHONY: help init plan apply destroy clean age-keygen age-info validate fmt check output outputs encrypt-backend

# Configuration
AGE_DIR := $(HOME)/.config/sops/age
AGE_PRIVATE_KEY := $(AGE_DIR)/r2-terraform-state.txt
AGE_PUBLIC_KEY := $(AGE_DIR)/r2-terraform-state.txt.pub
GENERATED_DIR := generated
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

## help: Show this help message
help:
	@echo "$(BLUE)Terraform State Backend - Makefile Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Setup Commands:$(NC)"
	@echo "  make init          - Initialize Terraform (loads encrypted backend config)"
	@echo "  make age-keygen    - Generate age encryption key"
	@echo "  make age-info      - Display age key information"
	@echo ""
	@echo "$(GREEN)Deployment Commands:$(NC)"
	@echo "  make plan          - Show Terraform plan"
	@echo "  make apply         - Deploy R2 backend"
	@echo "  make destroy       - Destroy R2 backend (use with caution)"
	@echo ""
	@echo "$(GREEN)Validation Commands:$(NC)"
	@echo "  make validate      - Validate Terraform configuration"
	@echo "  make fmt           - Format Terraform files"
	@echo "  make check         - Run all validation checks"
	@echo ""
	@echo "$(GREEN)SOPS Encryption Commands:$(NC)"
	@echo "  make encrypt-backend - Encrypt backend.hcl with SOPS"
	@echo ""
	@echo "$(GREEN)Utility Commands:$(NC)"
	@echo "  make output        - Show all outputs (including sensitive)"
	@echo "  make clean         - Clean generated files and Terraform state"
	@echo "  make help          - Show this help message"

## init: Initialize Terraform with backend configuration
init:
	@echo "$(BLUE)==> Initializing Terraform$(NC)"
	@if [ -f $(BACKEND_ENC) ]; then \
		echo "$(BLUE)==> Using encrypted backend config from $(BACKEND_ENC)$(NC)"; \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(BACKEND_ENC) 'terraform init -backend-config={}'; \
	else \
		echo "$(YELLOW)==> No backend config found, using local state$(NC)"; \
		terraform init; \
	fi

## validate: Validate Terraform configuration
validate:
	@echo "$(BLUE)==> Validating Terraform configuration$(NC)"
	terraform validate

## fmt: Format Terraform files
fmt:
	@echo "$(BLUE)==> Formatting Terraform files$(NC)"
	terraform fmt -recursive

## check: Run all validation checks
check: fmt validate
	@echo "$(GREEN)==> All checks passed$(NC)"

## plan: Show Terraform plan
plan: init
	@echo "$(BLUE)==> Generating Terraform plan$(NC)"
	@if [ -f $(TFVARS_ENC) ]; then \
		echo "$(BLUE)==> Using encrypted variables from $(TFVARS_ENC)$(NC)"; \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(TFVARS_ENC) 'terraform plan -var-file={}'; \
	else \
		echo "$(YELLOW)==> Warning: $(TFVARS_ENC) not found, using default variables$(NC)"; \
		terraform plan; \
	fi

## apply: Deploy R2 backend
apply: init
	@echo "$(BLUE)==> Deploying R2 backend$(NC)"
	@if [ -f $(TFVARS_ENC) ]; then \
		echo "$(BLUE)==> Using encrypted variables from $(TFVARS_ENC)$(NC)"; \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(TFVARS_ENC) 'terraform apply -var-file={}'; \
	else \
		echo "$(YELLOW)==> Warning: $(TFVARS_ENC) not found, using default variables$(NC)"; \
		terraform apply; \
	fi
	@echo ""
	@echo "$(GREEN)==> Deployment complete!$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "1. Review bucket outputs: make output"
	@echo "2. Create R2 API token at https://dash.cloudflare.com → R2 → Manage R2 API Tokens"
	@echo "3. Configure backend: cp backend.hcl.example backend.hcl && vim backend.hcl"
	@echo "4. Encrypt backend config: make encrypt-backend && rm backend.hcl"
	@echo "5. Migrate state to R2: make init (answer 'yes' when prompted)"

## destroy: Destroy R2 backend (use with caution)
destroy:
	@echo "$(RED)==> WARNING: This will destroy the R2 backend$(NC)"
	@echo "$(RED)==> All environment states stored in R2 will become inaccessible!$(NC)"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	@if [ -f $(TFVARS_ENC) ]; then \
		echo "$(BLUE)==> Using encrypted variables from $(TFVARS_ENC)$(NC)"; \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(TFVARS_ENC) 'terraform destroy -var-file={}'; \
	else \
		echo "$(YELLOW)==> Warning: $(TFVARS_ENC) not found, using default variables$(NC)"; \
		terraform destroy; \
	fi

## output: Show all outputs including sensitive values
output outputs:
	@echo "$(BLUE)==> Terraform Outputs$(NC)"
	@echo ""
	@echo "$(YELLOW)Bucket Information:$(NC)"
	@terraform output bucket_name
	@terraform output bucket_id
	@terraform output bucket_location
	@echo ""
	@echo "$(YELLOW)Sensitive Outputs (use with caution):$(NC)"
	@terraform output -json bucket_endpoint | jq -r
	@terraform output -json account_id | jq -r
	@echo ""
	@echo "$(YELLOW)Backend Configuration:$(NC)"
	@terraform output -json backend_configuration | jq
	@echo ""
	@echo "$(YELLOW)Setup Instructions:$(NC)"
	@terraform output -raw setup_instructions

## age-keygen: Generate age encryption key
age-keygen: $(AGE_PRIVATE_KEY)

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
	@echo "1. Store private key securely (password manager, encrypted filesystem)"
	@echo "2. Never commit private key to git"
	@echo "3. Backup private key in multiple secure locations"
	@echo "4. Add public key to terraform.tfvars:"
	@echo "   age_public_key = \"$$(cat $(AGE_PUBLIC_KEY))\""

## age-info: Display age key information
age-info:
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
	@echo ""
	@echo "$(BLUE)Usage Examples:$(NC)"
	@echo ""
	@echo "Encrypt a value:"
	@echo "  echo 'sensitive-data' | age -r \"$$(cat $(AGE_PUBLIC_KEY))\" > encrypted.age"
	@echo ""
	@echo "Decrypt a value:"
	@echo "  age -d -i $(AGE_PRIVATE_KEY) encrypted.age"
	@echo ""
	@echo "Use with SOPS:"
	@echo "  sops -e --age \"$$(cat $(AGE_PUBLIC_KEY))\" terraform.tfvars > terraform.tfvars.enc"
	@echo "  sops -d terraform.tfvars.enc | terraform apply -var-file=-"

## encrypt-backend: Encrypt backend.hcl file with SOPS
encrypt-backend:
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
		echo "  vim $(BACKEND_HCL)  # Add your R2 credentials and endpoint"; \
		exit 1; \
	fi
	@echo "$(BLUE)==> Encrypting $(BACKEND_HCL) to $(BACKEND_ENC)$(NC)"
	@SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops -e $(BACKEND_HCL) > $(BACKEND_ENC)
	@echo "$(GREEN)==> Encrypted successfully$(NC)"
	@echo ""
	@echo "$(YELLOW)==> Next steps:$(NC)"
	@echo "1. Remove unencrypted backend config: rm $(BACKEND_HCL)"
	@echo "2. Commit encrypted file to git: git add $(BACKEND_ENC)"
	@echo "3. Initialize Terraform: make init"
	@echo ""
	@echo "$(YELLOW)==> To edit encrypted backend config:$(NC)"
	@echo "  sops $(BACKEND_ENC)"
	@echo ""
	@echo "$(BLUE)Note:$(NC) Backend config is loaded automatically by 'make init'"

## clean: Clean generated files and Terraform state
clean:
	@echo "$(YELLOW)==> Cleaning generated files$(NC)"
	@rm -rf $(GENERATED_DIR)
	@rm -rf .terraform
	@rm -f .terraform.lock.hcl
	@rm -f terraform.tfstate*
	@rm -f SETUP.md
	@echo "$(GREEN)==> Clean complete$(NC)"
	@echo ""
	@echo "$(YELLOW)Note: Age keys in $(AGE_DIR)/ were NOT removed$(NC)"
	@echo "To remove age keys: rm -rf $(AGE_DIR)/"
