.PHONY: help age-keygen age-info sops-encrypt sops-decrypt flux-check flux-logs flux-reconcile flux-version
.PHONY: init plan apply destroy validate fmt upgrade
.PHONY: encrypt-backend encrypt-tfvars

# Configuration
AGE_DIR := $(HOME)/.config/sops/age

# Terraform age key (for encrypting terraform.tfvars, backend.hcl)
AGE_TERRAFORM_PRIVATE_KEY := $(AGE_DIR)/talos-gitops.txt
AGE_TERRAFORM_PUBLIC_KEY := $(AGE_DIR)/talos-gitops.txt.pub

# Flux age key (for encrypting Kubernetes manifests in Git)
AGE_FLUX_PRIVATE_KEY := $(AGE_DIR)/talos-gitops-flux.txt
AGE_FLUX_PUBLIC_KEY := $(AGE_DIR)/talos-gitops-flux.txt.pub

# Default SOPS key file for Terraform operations
SOPS_AGE_KEY_FILE := $(AGE_TERRAFORM_PRIVATE_KEY)

# SOPS encrypted files
TFVARS_ENC := terraform.tfvars.enc
BACKEND_HCL := backend.hcl
BACKEND_ENC := backend.hcl.enc

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
help:
	@echo "Talos Flux Terraform Environment"
	@echo ""
	@echo "Terraform Operations:"
	@echo "  make init               Initialize Terraform"
	@echo "  make plan               Show Terraform plan"
	@echo "  make apply              Apply Terraform changes"
	@echo "  make destroy            Destroy Terraform resources"
	@echo "  make validate           Validate Terraform configuration"
	@echo "  make fmt                Format Terraform files"
	@echo "  make upgrade            Upgrade Terraform providers"
	@echo ""
	@echo "SOPS/Age Key Management:"
	@echo "  make age-keygen         Generate age keys (Terraform + Flux)"
	@echo "  make age-info           Display age key information"
	@echo ""
	@echo "Flux Operations:"
	@echo "  make flux-check         Check Flux installation and components"
	@echo "  make flux-version       Show installed Flux version"
	@echo "  make flux-logs          Show Flux controller logs"
	@echo "  make flux-reconcile     Force reconcile all Flux resources"
	@echo ""
	@echo "SOPS Operations:"
	@echo "  make encrypt-backend       Encrypt backend.hcl with SOPS"
	@echo "  make encrypt-tfvars        Encrypt terraform.tfvars with SOPS"
	@echo "  make sops-encrypt FILE=<path>  Encrypt a file with SOPS"
	@echo "  make sops-decrypt FILE=<path>  Decrypt a SOPS-encrypted file"

# Generate age keys for SOPS encryption (Terraform + Flux)
age-keygen: $(AGE_TERRAFORM_PRIVATE_KEY) $(AGE_FLUX_PRIVATE_KEY)

# Generate Terraform age key (for encrypting terraform.tfvars, backend.hcl)
$(AGE_TERRAFORM_PRIVATE_KEY):
	@echo "$(BLUE)==> Generating Terraform age encryption key$(NC)"
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
	@if [ -f $(AGE_TERRAFORM_PRIVATE_KEY) ]; then \
		echo "$(YELLOW)==> Terraform age key already exists$(NC)"; \
		echo ""; \
		read -p "Overwrite? (yes/no): " confirm; \
		if [ "$$confirm" = "yes" ]; then \
			echo "$(YELLOW)==> Backing up existing key$(NC)"; \
			cp $(AGE_TERRAFORM_PRIVATE_KEY) $(AGE_TERRAFORM_PRIVATE_KEY).backup.$$(date +%Y%m%d-%H%M%S); \
		else \
			echo "$(GREEN)==> Using existing Terraform key$(NC)"; \
			exit 0; \
		fi; \
	fi
	@age-keygen -o $(AGE_TERRAFORM_PRIVATE_KEY)
	@chmod 600 $(AGE_TERRAFORM_PRIVATE_KEY)
	@grep "^# public key:" $(AGE_TERRAFORM_PRIVATE_KEY) | sed 's/# public key: //' > $(AGE_TERRAFORM_PUBLIC_KEY)
	@chmod 644 $(AGE_TERRAFORM_PUBLIC_KEY)
	@echo "$(GREEN)==> Terraform age key generated successfully$(NC)"

# Generate Flux age key (for encrypting Kubernetes manifests in Git)
$(AGE_FLUX_PRIVATE_KEY):
	@echo ""
	@echo "$(BLUE)==> Generating Flux age encryption key$(NC)"
	@mkdir -p $(AGE_DIR)
	@chmod 700 $(AGE_DIR)
	@if [ -f $(AGE_FLUX_PRIVATE_KEY) ]; then \
		echo "$(YELLOW)==> Flux age key already exists$(NC)"; \
		echo ""; \
		read -p "Overwrite? (yes/no): " confirm; \
		if [ "$$confirm" = "yes" ]; then \
			echo "$(YELLOW)==> Backing up existing key$(NC)"; \
			cp $(AGE_FLUX_PRIVATE_KEY) $(AGE_FLUX_PRIVATE_KEY).backup.$$(date +%Y%m%d-%H%M%S); \
		else \
			echo "$(GREEN)==> Using existing Flux key$(NC)"; \
			exit 0; \
		fi; \
	fi
	@age-keygen -o $(AGE_FLUX_PRIVATE_KEY)
	@chmod 600 $(AGE_FLUX_PRIVATE_KEY)
	@grep "^# public key:" $(AGE_FLUX_PRIVATE_KEY) | sed 's/# public key: //' > $(AGE_FLUX_PUBLIC_KEY)
	@chmod 644 $(AGE_FLUX_PUBLIC_KEY)
	@echo "$(GREEN)==> Flux age key generated successfully$(NC)"
	@echo ""
	@$(MAKE) --no-print-directory age-info
	@echo ""
	@echo "$(YELLOW)==> SECURITY WARNING$(NC)"
	@echo "1. Store private keys securely (password manager, encrypted filesystem)"
	@echo "2. Never commit private keys to git"
	@echo "3. Backup private keys in multiple secure locations"
	@echo "4. Terraform key: For local terraform.tfvars and backend.hcl encryption"
	@echo "5. Flux key: Add public key to .sops.yaml for Kubernetes manifest encryption"
	@echo "6. Flux key will be stored in Kubernetes as a secret (sops-age)"

# Display age key information
age-info:
	@if [ ! -f $(AGE_TERRAFORM_PRIVATE_KEY) ] && [ ! -f $(AGE_FLUX_PRIVATE_KEY) ]; then \
		echo "$(RED)Error: Age keys not found. Run 'make age-keygen' first$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)==> Age Encryption Key Information$(NC)"
	@echo ""
	@if [ -f $(AGE_TERRAFORM_PRIVATE_KEY) ]; then \
		echo "$(GREEN)Terraform Key (for local terraform.tfvars, backend.hcl):$(NC)"; \
		echo "  Private: $(AGE_TERRAFORM_PRIVATE_KEY)"; \
		echo "  Public:  $(AGE_TERRAFORM_PUBLIC_KEY)"; \
		echo "  Public Key: $$(cat $(AGE_TERRAFORM_PUBLIC_KEY))"; \
		echo ""; \
	fi
	@if [ -f $(AGE_FLUX_PRIVATE_KEY) ]; then \
		echo "$(GREEN)Flux Key (for Kubernetes manifests in Git):$(NC)"; \
		echo "  Private: $(AGE_FLUX_PRIVATE_KEY)"; \
		echo "  Public:  $(AGE_FLUX_PUBLIC_KEY)"; \
		echo "  Public Key: $$(cat $(AGE_FLUX_PUBLIC_KEY))"; \
		echo ""; \
	fi
	@echo "$(BLUE)Usage Examples:$(NC)"
	@echo ""
	@echo "$(YELLOW)Terraform - Encrypt terraform.tfvars:$(NC)"
	@echo "  sops -e --age \"$$(cat $(AGE_TERRAFORM_PUBLIC_KEY))\" terraform.tfvars > terraform.tfvars.enc"
	@echo "  sops -d terraform.tfvars.enc"
	@echo ""
	@echo "$(YELLOW)Flux - Encrypt Kubernetes manifests (.sops.yaml required):$(NC)"
	@echo "  # Add to .sops.yaml:"
	@echo "  #   creation_rules:"
	@echo "  #     - path_regex: .*.yaml"
	@echo "  #       encrypted_regex: ^(data|stringData)$$"
	@echo "  #       age: $$(cat $(AGE_FLUX_PUBLIC_KEY))"
	@echo "  sops -e --in-place kubernetes/secrets/my-secret.yaml"
	@echo ""
	@echo "$(YELLOW)Store Flux key in GitHub Secrets (for CI/CD):$(NC)"
	@echo "  gh secret set SOPS_AGE_KEY < $(AGE_FLUX_PRIVATE_KEY)"

# Encrypt a file with SOPS
sops-encrypt:
	@if [ -z "$(FILE)" ]; then \
		echo "❌ Usage: make sops-encrypt FILE=<path>"; \
		exit 1; \
	fi
	@if [ ! -f $(FILE) ]; then \
		echo "❌ File not found: $(FILE)"; \
		exit 1; \
	fi
	@echo "🔒 Encrypting $(FILE)..."
	@sops -e $(FILE) > $(FILE).enc
	@echo "✅ Encrypted to $(FILE).enc"

# Decrypt a SOPS-encrypted file
sops-decrypt:
	@if [ -z "$(FILE)" ]; then \
		echo "❌ Usage: make sops-decrypt FILE=<path>"; \
		exit 1; \
	fi
	@if [ ! -f $(FILE) ]; then \
		echo "❌ File not found: $(FILE)"; \
		exit 1; \
	fi
	@echo "🔓 Decrypting $(FILE)..."
	@sops -d $(FILE)

# Check Flux installation
flux-check:
	@echo "🔍 Checking Flux installation..."
	@flux check

# Show Flux version
flux-version:
	@echo "📦 Flux version:"
	@flux version

# Show Flux logs
flux-logs:
	@echo "📋 Flux controller logs:"
	@flux logs --level=info --all-namespaces

# Force reconcile all Flux resources
flux-reconcile:
	@echo "🔄 Reconciling Flux resources..."
	@flux reconcile source git flux-system
	@flux reconcile kustomization --all

# Terraform operations
init:
	@echo "🔧 Initializing Terraform..."
	@if [ -f $(BACKEND_ENC) ]; then \
		echo "🔓 Using encrypted backend configuration..."; \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(BACKEND_ENC) 'terraform init -backend-config={}'; \
	else \
		terraform init; \
	fi

plan:
	@echo "📋 Planning Terraform changes..."
	@if [ -f $(TFVARS_ENC) ]; then \
		echo "🔓 Using encrypted tfvars..."; \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(TFVARS_ENC) 'terraform plan -var-file={}'; \
	else \
		terraform plan; \
	fi

apply:
	@echo "🚀 Applying Terraform changes..."
	@if [ -f $(TFVARS_ENC) ]; then \
		echo "🔓 Using encrypted tfvars..."; \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops exec-file $(TFVARS_ENC) 'terraform apply -var-file={}'; \
	else \
		terraform apply; \
	fi

destroy:
	@echo "💥 Destroying Terraform resources..."
	@terraform destroy

validate:
	@echo "✓ Validating Terraform configuration..."
	@terraform validate

fmt:
	@echo "✨ Formatting Terraform files..."
	@terraform fmt -recursive

upgrade:
	@echo "⬆️  Upgrading Terraform providers..."
	@terraform init -upgrade
	@echo ""
	@echo "✅ Providers upgraded"
	@echo ""
	@echo "💡 To see what changed:"
	@echo "   git diff .terraform.lock.hcl"

# Encrypt backend.hcl
encrypt-backend:
	@if [ ! -f $(AGE_TERRAFORM_PRIVATE_KEY) ]; then \
		echo "$(RED)Error: Terraform age key not found. Run 'make age-keygen' first$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f $(BACKEND_HCL) ]; then \
		echo "$(RED)Error: backend.hcl not found$(NC)"; \
		echo ""; \
		echo "Create backend.hcl with your Terraform backend configuration:"; \
		echo "  cp backend.hcl.example backend.hcl"; \
		echo "  # Edit backend.hcl with your settings"; \
		exit 1; \
	fi
	@echo "$(BLUE)==> Encrypting backend.hcl$(NC)"
	@SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops -e --age "$$(cat $(AGE_TERRAFORM_PUBLIC_KEY))" $(BACKEND_HCL) > $(BACKEND_ENC)
	@echo "$(GREEN)==> Backend configuration encrypted to $(BACKEND_ENC)$(NC)"
	@echo ""
	@echo "$(YELLOW)==> IMPORTANT$(NC)"
	@echo "1. Add $(BACKEND_HCL) to .gitignore (unencrypted version)"
	@echo "2. Commit $(BACKEND_ENC) to git (encrypted version)"
	@echo "3. Delete unencrypted $(BACKEND_HCL) after verification"

# Encrypt terraform.tfvars
encrypt-tfvars:
	@if [ ! -f $(AGE_TERRAFORM_PRIVATE_KEY) ]; then \
		echo "$(RED)Error: Terraform age key not found. Run 'make age-keygen' first$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f terraform.tfvars ]; then \
		echo "$(RED)Error: terraform.tfvars not found$(NC)"; \
		echo ""; \
		echo "Create terraform.tfvars with your configuration:"; \
		echo "  cp terraform.tfvars.example terraform.tfvars"; \
		echo "  # Edit terraform.tfvars with your settings"; \
		exit 1; \
	fi
	@echo "$(BLUE)==> Encrypting terraform.tfvars$(NC)"
	@SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops -e --age "$$(cat $(AGE_TERRAFORM_PUBLIC_KEY))" terraform.tfvars > $(TFVARS_ENC)
	@echo "$(GREEN)==> Variables encrypted to $(TFVARS_ENC)$(NC)"
	@echo ""
	@echo "$(YELLOW)==> IMPORTANT$(NC)"
	@echo "1. Add terraform.tfvars to .gitignore (unencrypted version)"
	@echo "2. Commit $(TFVARS_ENC) to git (encrypted version)"
	@echo "3. Delete unencrypted terraform.tfvars after verification"
