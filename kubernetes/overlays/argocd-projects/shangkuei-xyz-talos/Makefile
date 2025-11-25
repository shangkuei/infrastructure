# Makefile for ArgoCD SOPS Age Key Management
# Generates and manages a dedicated Age key for ArgoCD KSOPS

.PHONY: help
help: ## Show this help message
	@echo "ArgoCD SOPS Age Key Management"
	@echo ""
	@echo "Usage:"
	@echo "  make <target>"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make generate-argocd-age-key   # Generate dedicated ArgoCD Age key"
	@echo "  make encrypt-secret            # Encrypt secret with Flux's Age key"
	@echo "  make setup                     # Complete setup (generate + encrypt)"

.PHONY: check-deps
check-deps: ## Check required dependencies
	@command -v sops >/dev/null 2>&1 || { echo "❌ sops not found. Install: brew install sops"; exit 1; }
	@command -v age >/dev/null 2>&1 || { echo "❌ age not found. Install: brew install age"; exit 1; }
	@command -v age-keygen >/dev/null 2>&1 || { echo "❌ age-keygen not found. Install: brew install age"; exit 1; }
	@echo "✅ All dependencies installed"

.PHONY: check-flux-key
check-flux-key: ## Verify Flux Age key exists
	@if [ ! -f $(HOME)/.config/sops/age/talos-gitops-flux.txt ]; then \
		echo "❌ Flux Age key not found at $(HOME)/.config/sops/age/talos-gitops-flux.txt"; \
		echo ""; \
		echo "Generate Flux Age keys first:"; \
		echo "  cd ../../../terraform/environments/talos-gitops"; \
		echo "  make age-keygen"; \
		exit 1; \
	fi
	@echo "✅ Flux Age key found"

.PHONY: generate-argocd-age-key
generate-argocd-age-key: check-deps ## Generate dedicated Age key for ArgoCD KSOPS
	@echo "🔑 Generating dedicated Age key for ArgoCD KSOPS..."
	@echo ""
	@echo "📋 Step 1: Creating keys directory..."
	@mkdir -p $(HOME)/.config/sops/age
	@echo "✅ Directory ready: $(HOME)/.config/sops/age"
	@echo ""
	@echo "📋 Step 2: Generating Age key pair..."
	@age-keygen -o $(HOME)/.config/sops/age/argocd-ksops.txt 2>&1 | tee /tmp/age-keygen-output.txt
	@echo ""
	@echo "✅ Age key generated: $(HOME)/.config/sops/age/argocd-ksops.txt"
	@echo ""
	@echo "📋 Step 3: Extracting public key..."
	@AGE_PUBLIC_KEY=$$(grep "^# public key:" $(HOME)/.config/sops/age/argocd-ksops.txt | awk '{print $$NF}'); \
	echo "   Public key: $$AGE_PUBLIC_KEY"; \
	echo "$$AGE_PUBLIC_KEY" > $(HOME)/.config/sops/age/argocd-ksops.txt.pub
	@echo "✅ Public key saved: $(HOME)/.config/sops/age/argocd-ksops.txt.pub"
	@echo ""
	@echo "📋 Step 4: Updating .sops.yaml for test apps..."
	@AGE_PUBLIC_KEY=$$(cat $(HOME)/.config/sops/age/argocd-ksops.txt.pub); \
	echo "# SOPS configuration for ArgoCD test applications" > ../../../../argocd-examples/.sops.yaml; \
	echo "# Uses dedicated ArgoCD Age key for KSOPS" >> ../../../../argocd-examples/.sops.yaml; \
	echo "" >> ../../../../argocd-examples/.sops.yaml; \
	echo "creation_rules:" >> ../../../../argocd-examples/.sops.yaml; \
	echo "  - path_regex: .*secret.*\\.(enc|yaml|yml)$$" >> ../../../../argocd-examples/.sops.yaml; \
	echo "    encrypted_regex: '^(data|stringData)$$'" >> ../../../../argocd-examples/.sops.yaml; \
	echo "    age: $$AGE_PUBLIC_KEY" >> ../../../../argocd-examples/.sops.yaml
	@echo "✅ Updated: ../../../../argocd-examples/.sops.yaml"
	@echo ""
	@echo "📋 Step 5: Updating .sops.yaml for ArgoCD overlay..."
	@AGE_PUBLIC_KEY=$$(cat $(HOME)/.config/sops/age/argocd-ksops.txt.pub); \
	FLUX_PUBLIC_KEY=$$(grep "^# public key:" $(HOME)/.config/sops/age/talos-gitops-flux.txt | awk '{print $$NF}'); \
	echo "# SOPS configuration for ArgoCD overlay secrets" > .sops.yaml; \
	echo "# Uses Flux Age key to encrypt the ArgoCD KSOPS Age key secret" >> .sops.yaml; \
	echo "# This allows Flux to decrypt and deploy the secret to ArgoCD namespace" >> .sops.yaml; \
	echo "" >> .sops.yaml; \
	echo "creation_rules:" >> .sops.yaml; \
	echo "  - path_regex: .*secret.*\\.(enc|yaml|yml)$$" >> .sops.yaml; \
	echo "    encrypted_regex: '^(data|stringData)$$'" >> .sops.yaml; \
	echo "    age: $$FLUX_PUBLIC_KEY" >> .sops.yaml
	@echo "✅ Updated: .sops.yaml"
	@echo ""
	@echo "✅ ArgoCD Age key generation complete!"
	@echo ""
	@echo "📋 Key Files Created:"
	@echo "   Private key: $(HOME)/.config/sops/age/argocd-ksops.txt"
	@echo "   Public key:  $(HOME)/.config/sops/age/argocd-ksops.txt.pub"
	@echo ""
	@echo "⚠️  IMPORTANT:"
	@echo "   1. Private key is stored at: $(HOME)/.config/sops/age/argocd-ksops.txt"
	@echo "   2. This key will be encrypted and deployed by Flux to ArgoCD namespace"
	@echo "   3. Test apps will use this key for SOPS encryption"
	@echo "   4. Backup the private key securely!"
	@echo ""
	@echo "📋 Next steps:"
	@echo "   make generate-secret   # Generate ArgoCD SOPS Age secret"

.PHONY: generate-secret
generate-secret: check-deps check-flux-key ## Generate ArgoCD SOPS Age secret (plain text)
	@echo "🔐 Generating ArgoCD SOPS Age secret (plain text)..."
	@if [ ! -f $(HOME)/.config/sops/age/argocd-ksops.txt ]; then \
		echo "❌ ArgoCD Age key not found. Run: make generate-argocd-age-key"; \
		exit 1; \
	fi
	@echo "---" > secret-sops-age.yaml
	@echo "# SOPS Age key secret for ArgoCD KSOPS" >> secret-sops-age.yaml
	@echo "# This secret will be encrypted with Flux's Age key" >> secret-sops-age.yaml
	@echo "# Flux will decrypt and deploy it to the ArgoCD namespace" >> secret-sops-age.yaml
	@echo "# ArgoCD repo-server will use this key to decrypt application secrets" >> secret-sops-age.yaml
	@echo "apiVersion: v1" >> secret-sops-age.yaml
	@echo "kind: Secret" >> secret-sops-age.yaml
	@echo "metadata:" >> secret-sops-age.yaml
	@echo "  name: sops-age" >> secret-sops-age.yaml
	@echo "  namespace: argocd" >> secret-sops-age.yaml
	@echo "type: Opaque" >> secret-sops-age.yaml
	@echo "stringData:" >> secret-sops-age.yaml
	@echo "  keys.txt: |" >> secret-sops-age.yaml
	@sed 's/^/    /' $(HOME)/.config/sops/age/argocd-ksops.txt >> secret-sops-age.yaml
	@echo "✅ Generated: secret-sops-age.yaml (plain text)"
	@echo ""
	@echo "📋 Next step:"
	@echo "   make encrypt-secret   # Encrypt with Flux's Age key"

.PHONY: encrypt-secret
encrypt-secret: check-deps check-flux-key ## Encrypt ArgoCD secret with Flux's Age key
	@echo "🔐 Encrypting ArgoCD SOPS Age secret with Flux's Age key..."
	@if [ ! -f secret-sops-age.yaml ]; then \
		echo "❌ secret-sops-age.yaml not found. Run: make generate-secret"; \
		exit 1; \
	fi
	@if [ ! -f .sops.yaml ]; then \
		echo "❌ .sops.yaml not found. Run: make generate-argocd-age-key"; \
		exit 1; \
	fi
	@echo "💡 Note: Using Flux's Age key for encryption (so Flux can decrypt it)"
	@SOPS_AGE_KEY_FILE=$(HOME)/.config/sops/age/talos-gitops-flux.txt \
		sops --config .sops.yaml --input-type yaml --output-type yaml --encrypt --in-place secret-sops-age.yaml
	@echo "✅ Secret encrypted: secret-sops-age.yaml"
	@echo ""
	@echo "✅ Setup complete!"
	@echo ""
	@echo "📋 Summary:"
	@echo "   • ArgoCD Age key: $(HOME)/.config/sops/age/argocd-ksops.txt"
	@echo "   • Secret file: secret-sops-age.yaml (encrypted with Flux's key)"
	@echo "   • Test apps config: ../../../argocd-examples/.sops.yaml"
	@echo ""
	@echo "📋 Next steps:"
	@echo "   1. Encrypt test app secrets: cd ../../../argocd-examples && make encrypt-all"
	@echo "   2. Commit changes: git add . && git commit -m 'feat(argocd): add KSOPS Age key'"
	@echo "   3. Push to repo: git push"
	@echo "   4. Flux will automatically deploy the secret to ArgoCD namespace"

.PHONY: encrypt-test-app-secrets
encrypt-test-app-secrets: check-deps ## Encrypt test application secrets with ArgoCD Age key
	@echo "🔐 Encrypting test application secrets..."
	@if [ ! -f $(HOME)/.config/sops/age/argocd-ksops.txt ]; then \
		echo "❌ ArgoCD Age key not found. Run: make generate-argocd-age-key"; \
		exit 1; \
	fi
	@SOPS_AGE_KEY_FILE=$(HOME)/.config/sops/age/argocd-ksops.txt \
		sops -e -i ../../../../argocd-examples/app1/overlays/shangkuei-xyz-talos/secret-app1.yaml
	@echo "✅ Encrypted: app1/secret-app1.yaml"
	@SOPS_AGE_KEY_FILE=$(HOME)/.config/sops/age/argocd-ksops.txt \
		sops -e -i ../../../../argocd-examples/app2/overlays/shangkuei-xyz-talos/secret-app2.yaml
	@echo "✅ Encrypted: app2/secret-app2.yaml"
	@echo ""
	@echo "✅ All test app secrets encrypted!"

.PHONY: decrypt-secret
decrypt-secret: check-deps check-flux-key ## Decrypt and view ArgoCD secret
	@echo "🔓 Decrypting ArgoCD SOPS Age secret..."
	@if [ ! -f secret-sops-age.yaml ]; then \
		echo "❌ secret-sops-age.yaml not found"; \
		exit 1; \
	fi
	@SOPS_AGE_KEY_FILE=$(HOME)/.config/sops/age/talos-gitops-flux.txt \
		sops -d secret-sops-age.yaml

.PHONY: validate
validate: check-deps check-flux-key ## Validate encrypted secret can be decrypted
	@echo "✅ Validating encrypted secret..."
	@if [ ! -f secret-sops-age.yaml ]; then \
		echo "❌ secret-sops-age.yaml not found"; \
		exit 1; \
	fi
	@echo -n "  📄 secret-sops-age.yaml ... "
	@if SOPS_AGE_KEY_FILE=$(HOME)/.config/sops/age/talos-gitops-flux.txt \
		sops -d secret-sops-age.yaml > /dev/null 2>&1; then \
		echo "✅ Valid"; \
	else \
		echo "❌ Invalid"; \
		exit 1; \
	fi
	@echo ""
	@echo "✅ Secret is valid and can be decrypted by Flux"

.PHONY: show-keys
show-keys: ## Show Age key information
	@echo "📋 Age Key Information:"
	@echo ""
	@echo "Flux Age Key (for encrypting ArgoCD secret):"
	@if [ -f $(HOME)/.config/sops/age/talos-gitops-flux.txt ]; then \
		grep "^# public key:" $(HOME)/.config/sops/age/talos-gitops-flux.txt || echo "  Not found"; \
	else \
		echo "  ❌ Not found"; \
	fi
	@echo ""
	@echo "ArgoCD Age Key (for encrypting test app secrets):"
	@if [ -f $(HOME)/.config/sops/age/argocd-ksops.txt ]; then \
		grep "^# public key:" $(HOME)/.config/sops/age/argocd-ksops.txt || echo "  Not found"; \
	else \
		echo "  ❌ Not found (run: make generate-argocd-age-key)"; \
	fi
	@echo ""
	@echo "Test Apps .sops.yaml:"
	@if [ -f ../../../argocd-examples/.sops.yaml ]; then \
		grep "age:" ../../../argocd-examples/.sops.yaml | head -1 || echo "  Not configured"; \
	else \
		echo "  ❌ Not found"; \
	fi

.PHONY: setup
setup: generate-argocd-age-key generate-secret encrypt-secret encrypt-test-app-secrets ## Complete setup: generate key, create and encrypt secret
	@echo ""
	@echo "🎉 ArgoCD KSOPS setup complete!"
	@echo ""
	@echo "📋 What was created:"
	@echo "   • Dedicated Age key for ArgoCD KSOPS"
	@echo "   • Encrypted secret for Flux to deploy"
	@echo "   • Test app secrets encrypted"
	@echo "   • SOPS configurations updated"
	@echo ""
	@echo "📋 Next steps:"
	@echo "   1. Review changes: git status"
	@echo "   2. Commit: git add . && git commit -m 'feat(argocd): add KSOPS Age key and test apps'"
	@echo "   3. Push: git push"
	@echo "   4. Flux will deploy the secret automatically"
	@echo "   5. Deploy test apps: kubectl apply -k ../../../argocd-examples/argocd-apps/base/"
	@echo ""
	@echo "⚠️  Remember to backup: $(HOME)/.config/sops/age/argocd-ksops.txt"

.PHONY: clean
clean: ## Remove generated plain text files (keeps encrypted secrets)
	@echo "🧹 Cleaning up..."
	@rm -f secret-sops-age.yaml.decrypted
	@echo "✅ Cleanup complete"

.PHONY: clean-all
clean-all: ## Remove all generated files including encrypted secrets
	@echo "🧹 Removing all generated files..."
	@read -p "This will delete encrypted secrets. Continue? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		rm -f secret-sops-age.yaml secret-sops-age.yaml.decrypted; \
		rm -f .sops.yaml; \
		echo "✅ All files removed"; \
	else \
		echo "❌ Cancelled"; \
	fi
