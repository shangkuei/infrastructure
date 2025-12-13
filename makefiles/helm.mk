# ============================================================================
# helm.mk - Unified Helm Operations
# ============================================================================
# Shared Makefile include for standardized Helm chart management operations.
#
# Usage:
#   Include this file in your environment Makefile after sops.mk:
#     include ../../../makefiles/sops.mk
#     include ../../../makefiles/helm.mk
#
# Required variables (set before including):
#   KUBECONFIG           - Path to kubeconfig file
#
# Optional variables:
#   HELM_DEFAULT_NS      - Default namespace for installations (default: default)
#   HELM_WAIT            - Wait for resources to be ready (default: true)
#   HELM_TIMEOUT         - Timeout for Helm operations (default: 5m)
#   HELM_ATOMIC          - Rollback on failure (default: false)
#
# Pre-configured chart repositories:
#   cilium               - https://helm.cilium.io/
#   jetstack             - https://charts.jetstack.io
#   ingress-nginx        - https://kubernetes.github.io/ingress-nginx
#   prometheus-community - https://prometheus-community.github.io/helm-charts
#   grafana              - https://grafana.github.io/helm-charts
#   bitnami              - https://charts.bitnami.com/bitnami
#   argo                 - https://argoproj.github.io/argo-helm
#
# Examples:
#   make helm-install chart=cilium values=cilium-values.yaml ns=kube-system
#   make helm-install chart=jetstack/cert-manager values=cert-manager.yaml ns=cert-manager
#   make helm-upgrade chart=cilium values=cilium-values.yaml ns=kube-system
#   make helm-uninstall release=cilium ns=kube-system
# ============================================================================

# ============================================================================
# Default Configuration
# ============================================================================

HELM_DEFAULT_NS ?= default
HELM_WAIT ?= true
HELM_TIMEOUT ?= 5m
HELM_ATOMIC ?= false

# ============================================================================
# Pre-configured Helm Repositories
# ============================================================================

# Map of known chart prefixes to repository URLs
# Format: chart-prefix|repo-name|repo-url
HELM_KNOWN_REPOS := \
	cilium|cilium|https://helm.cilium.io/ \
	jetstack|jetstack|https://charts.jetstack.io \
	ingress-nginx|ingress-nginx|https://kubernetes.github.io/ingress-nginx \
	prometheus-community|prometheus-community|https://prometheus-community.github.io/helm-charts \
	grafana|grafana|https://grafana.github.io/helm-charts \
	bitnami|bitnami|https://charts.bitnami.com/bitnami \
	argo|argo|https://argoproj.github.io/argo-helm \
	openebs|openebs|https://openebs.github.io/openebs \
	longhorn|longhorn|https://charts.longhorn.io \
	metallb|metallb|https://metallb.github.io/metallb \
	traefik|traefik|https://traefik.github.io/charts \
	hashicorp|hashicorp|https://helm.releases.hashicorp.com \
	external-secrets|external-secrets|https://charts.external-secrets.io

# ============================================================================
# Internal Functions
# ============================================================================

# Function to get repo URL for a known chart
# Usage: $(call helm_get_repo_url,chart_name)
define helm_get_repo_url
$(shell echo "$(HELM_KNOWN_REPOS)" | tr ' ' '\n' | grep "^$(1)|" | cut -d'|' -f3)
endef

# Function to get repo name for a known chart
define helm_get_repo_name
$(shell echo "$(HELM_KNOWN_REPOS)" | tr ' ' '\n' | grep "^$(1)|" | cut -d'|' -f2)
endef

# ============================================================================
# Validation
# ============================================================================

.PHONY: helm-check-deps
helm-check-deps: ## Verify helm is installed
	@if ! command -v helm >/dev/null 2>&1; then \
		echo "$(_SOPS_RED)Error: helm is not installed$(_SOPS_NC)"; \
		echo "Install: brew install helm"; \
		exit 1; \
	fi
	@echo "  [$(_SOPS_OK)] helm: $$(helm version --short)"

.PHONY: helm-check-kubeconfig
helm-check-kubeconfig: ## Verify kubeconfig is available
	@if [ -z "$(KUBECONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: KUBECONFIG not set$(_SOPS_NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(KUBECONFIG)" ]; then \
		echo "$(_SOPS_RED)Error: kubeconfig not found: $(KUBECONFIG)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@echo "  [$(_SOPS_OK)] kubeconfig: $(KUBECONFIG)"

# ============================================================================
# Repository Management
# ============================================================================

##@ Helm Repository Management

.PHONY: helm-repo-add
helm-repo-add: helm-check-deps ## Add a Helm repository (repo=name url=https://...)
	@if [ -z "$(repo)" ]; then \
		echo "$(_SOPS_RED)Error: repo not specified$(_SOPS_NC)"; \
		echo "Usage: make helm-repo-add repo=cilium url=https://helm.cilium.io/"; \
		exit 1; \
	fi
	@if [ -z "$(url)" ]; then \
		echo "$(_SOPS_RED)Error: url not specified$(_SOPS_NC)"; \
		echo "Usage: make helm-repo-add repo=cilium url=https://helm.cilium.io/"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)Adding Helm repository: $(repo)$(_SOPS_NC)"
	@helm repo add $(repo) $(url) && \
		helm repo update && \
		echo "$(_SOPS_GREEN)✓ Repository $(repo) added$(_SOPS_NC)"

.PHONY: helm-repo-update
helm-repo-update: helm-check-deps ## Update all Helm repositories
	@echo "$(_SOPS_BLUE)Updating Helm repositories...$(_SOPS_NC)"
	@helm repo update && \
		echo "$(_SOPS_GREEN)✓ Repositories updated$(_SOPS_NC)"

.PHONY: helm-repo-list
helm-repo-list: helm-check-deps ## List configured Helm repositories
	@echo "$(_SOPS_BLUE)Configured Helm repositories:$(_SOPS_NC)"
	@helm repo list

# ============================================================================
# Chart Operations
# ============================================================================

##@ Helm Chart Operations

.PHONY: helm-install
helm-install: helm-check-deps helm-check-kubeconfig ## Install a Helm chart (chart=name values=file.yaml ns=namespace [version=x.y.z])
	@if [ -z "$(chart)" ]; then \
		echo "$(_SOPS_RED)Error: chart not specified$(_SOPS_NC)"; \
		echo ""; \
		echo "Usage: make helm-install chart=<name> values=<file> [ns=<namespace>] [version=<x.y.z>]"; \
		echo ""; \
		echo "Examples:"; \
		echo "  make helm-install chart=cilium values=cilium-values.yaml ns=kube-system"; \
		echo "  make helm-install chart=jetstack/cert-manager values=cm.yaml ns=cert-manager version=1.14.0"; \
		echo ""; \
		echo "Pre-configured charts: cilium, jetstack, ingress-nginx, prometheus-community,"; \
		echo "                       grafana, bitnami, argo, openebs, longhorn, metallb,"; \
		echo "                       traefik, hashicorp, external-secrets"; \
		exit 1; \
	fi
	@if [ -z "$(values)" ]; then \
		echo "$(_SOPS_RED)Error: values file not specified$(_SOPS_NC)"; \
		echo "Usage: make helm-install chart=$(chart) values=<file.yaml>"; \
		exit 1; \
	fi
	@if [ ! -f "$(values)" ]; then \
		echo "$(_SOPS_RED)Error: values file not found: $(values)$(_SOPS_NC)"; \
		exit 1; \
	fi
	@export KUBECONFIG=$(KUBECONFIG); \
	NAMESPACE="$(if $(ns),$(ns),$(HELM_DEFAULT_NS))"; \
	CHART_NAME="$(chart)"; \
	REPO_NAME=""; \
	CHART_REF=""; \
	RELEASE_NAME=""; \
	VERSION_FLAG=""; \
	WAIT_FLAG=""; \
	ATOMIC_FLAG=""; \
	if echo "$$CHART_NAME" | grep -q "/"; then \
		REPO_NAME=$$(echo "$$CHART_NAME" | cut -d'/' -f1); \
		RELEASE_NAME=$$(echo "$$CHART_NAME" | cut -d'/' -f2); \
		CHART_REF="$$CHART_NAME"; \
	else \
		REPO_NAME="$$CHART_NAME"; \
		RELEASE_NAME="$$CHART_NAME"; \
		CHART_REF="$$CHART_NAME/$$CHART_NAME"; \
	fi; \
	REPO_URL=$$(echo "$(HELM_KNOWN_REPOS)" | tr ' ' '\n' | grep "^$$REPO_NAME|" | cut -d'|' -f3); \
	if [ -n "$$REPO_URL" ]; then \
		echo "$(_SOPS_BLUE)==> Adding repository: $$REPO_NAME$(_SOPS_NC)"; \
		helm repo add $$REPO_NAME $$REPO_URL 2>/dev/null || true; \
		helm repo update $$REPO_NAME; \
	else \
		echo "$(_SOPS_YELLOW)==> Repository $$REPO_NAME not pre-configured, assuming already added$(_SOPS_NC)"; \
	fi; \
	if [ -n "$(version)" ]; then \
		VERSION_FLAG="--version $(version)"; \
	fi; \
	if [ "$(HELM_WAIT)" = "true" ]; then \
		WAIT_FLAG="--wait --timeout $(HELM_TIMEOUT)"; \
	fi; \
	if [ "$(HELM_ATOMIC)" = "true" ]; then \
		ATOMIC_FLAG="--atomic"; \
	fi; \
	echo "$(_SOPS_BLUE)Installing Helm chart...$(_SOPS_NC)"; \
	echo "  Chart:     $$CHART_REF"; \
	echo "  Release:   $$RELEASE_NAME"; \
	echo "  Namespace: $$NAMESPACE"; \
	echo "  Values:    $(values)"; \
	if [ -n "$(version)" ]; then echo "  Version:   $(version)"; fi; \
	echo ""; \
	helm upgrade --install $$RELEASE_NAME $$CHART_REF \
		--namespace $$NAMESPACE \
		--create-namespace \
		--values $(values) \
		$$VERSION_FLAG \
		$$WAIT_FLAG \
		$$ATOMIC_FLAG && \
	echo "$(_SOPS_GREEN)✓ Chart $$RELEASE_NAME installed in $$NAMESPACE$(_SOPS_NC)" || \
	(echo "$(_SOPS_RED)✗ Chart installation failed$(_SOPS_NC)"; exit 1)

.PHONY: helm-upgrade
helm-upgrade: helm-check-deps helm-check-kubeconfig ## Upgrade a Helm release (chart=name values=file.yaml ns=namespace [version=x.y.z])
	@# This is an alias to helm-install since we use upgrade --install
	@$(MAKE) helm-install chart="$(chart)" values="$(values)" ns="$(ns)" version="$(version)"

.PHONY: helm-uninstall
helm-uninstall: helm-check-deps helm-check-kubeconfig ## Uninstall a Helm release (release=name ns=namespace)
	@if [ -z "$(release)" ]; then \
		echo "$(_SOPS_RED)Error: release not specified$(_SOPS_NC)"; \
		echo "Usage: make helm-uninstall release=<name> [ns=<namespace>]"; \
		exit 1; \
	fi
	@export KUBECONFIG=$(KUBECONFIG); \
	NAMESPACE="$(if $(ns),$(ns),$(HELM_DEFAULT_NS))"; \
	echo "$(_SOPS_YELLOW)Uninstalling Helm release: $(release) from $$NAMESPACE$(_SOPS_NC)"; \
	helm uninstall $(release) --namespace $$NAMESPACE && \
	echo "$(_SOPS_GREEN)✓ Release $(release) uninstalled$(_SOPS_NC)" || \
	(echo "$(_SOPS_RED)✗ Uninstall failed$(_SOPS_NC)"; exit 1)

.PHONY: helm-rollback
helm-rollback: helm-check-deps helm-check-kubeconfig ## Rollback a Helm release (release=name ns=namespace [revision=n])
	@if [ -z "$(release)" ]; then \
		echo "$(_SOPS_RED)Error: release not specified$(_SOPS_NC)"; \
		echo "Usage: make helm-rollback release=<name> [ns=<namespace>] [revision=<n>]"; \
		exit 1; \
	fi
	@export KUBECONFIG=$(KUBECONFIG); \
	NAMESPACE="$(if $(ns),$(ns),$(HELM_DEFAULT_NS))"; \
	REVISION="$(if $(revision),$(revision),0)"; \
	echo "$(_SOPS_YELLOW)Rolling back Helm release: $(release) in $$NAMESPACE$(_SOPS_NC)"; \
	helm rollback $(release) $$REVISION --namespace $$NAMESPACE && \
	echo "$(_SOPS_GREEN)✓ Release $(release) rolled back$(_SOPS_NC)" || \
	(echo "$(_SOPS_RED)✗ Rollback failed$(_SOPS_NC)"; exit 1)

# ============================================================================
# Status & Information
# ============================================================================

##@ Helm Status

.PHONY: helm-list
helm-list: helm-check-deps helm-check-kubeconfig ## List installed Helm releases ([ns=namespace|all])
	@export KUBECONFIG=$(KUBECONFIG); \
	if [ "$(ns)" = "all" ]; then \
		echo "$(_SOPS_BLUE)All Helm releases:$(_SOPS_NC)"; \
		helm list --all-namespaces; \
	elif [ -n "$(ns)" ]; then \
		echo "$(_SOPS_BLUE)Helm releases in $(ns):$(_SOPS_NC)"; \
		helm list --namespace $(ns); \
	else \
		echo "$(_SOPS_BLUE)All Helm releases:$(_SOPS_NC)"; \
		helm list --all-namespaces; \
	fi

.PHONY: helm-status
helm-status: helm-check-deps helm-check-kubeconfig ## Show status of a Helm release (release=name ns=namespace)
	@if [ -z "$(release)" ]; then \
		echo "$(_SOPS_RED)Error: release not specified$(_SOPS_NC)"; \
		echo "Usage: make helm-status release=<name> [ns=<namespace>]"; \
		exit 1; \
	fi
	@export KUBECONFIG=$(KUBECONFIG); \
	NAMESPACE="$(if $(ns),$(ns),$(HELM_DEFAULT_NS))"; \
	echo "$(_SOPS_BLUE)Status of $(release) in $$NAMESPACE:$(_SOPS_NC)"; \
	helm status $(release) --namespace $$NAMESPACE

.PHONY: helm-history
helm-history: helm-check-deps helm-check-kubeconfig ## Show release history (release=name ns=namespace)
	@if [ -z "$(release)" ]; then \
		echo "$(_SOPS_RED)Error: release not specified$(_SOPS_NC)"; \
		echo "Usage: make helm-history release=<name> [ns=<namespace>]"; \
		exit 1; \
	fi
	@export KUBECONFIG=$(KUBECONFIG); \
	NAMESPACE="$(if $(ns),$(ns),$(HELM_DEFAULT_NS))"; \
	echo "$(_SOPS_BLUE)History of $(release) in $$NAMESPACE:$(_SOPS_NC)"; \
	helm history $(release) --namespace $$NAMESPACE

.PHONY: helm-values
helm-values: helm-check-deps helm-check-kubeconfig ## Show values of a Helm release (release=name ns=namespace)
	@if [ -z "$(release)" ]; then \
		echo "$(_SOPS_RED)Error: release not specified$(_SOPS_NC)"; \
		echo "Usage: make helm-values release=<name> [ns=<namespace>]"; \
		exit 1; \
	fi
	@export KUBECONFIG=$(KUBECONFIG); \
	NAMESPACE="$(if $(ns),$(ns),$(HELM_DEFAULT_NS))"; \
	helm get values $(release) --namespace $$NAMESPACE

# ============================================================================
# Search & Discovery
# ============================================================================

##@ Helm Search

.PHONY: helm-search
helm-search: helm-check-deps ## Search for Helm charts (query=<term>)
	@if [ -z "$(query)" ]; then \
		echo "$(_SOPS_RED)Error: query not specified$(_SOPS_NC)"; \
		echo "Usage: make helm-search query=<term>"; \
		exit 1; \
	fi
	@echo "$(_SOPS_BLUE)Searching for: $(query)$(_SOPS_NC)"
	@helm search repo $(query)

.PHONY: helm-show-values
helm-show-values: helm-check-deps ## Show default values for a chart (chart=repo/name)
	@if [ -z "$(chart)" ]; then \
		echo "$(_SOPS_RED)Error: chart not specified$(_SOPS_NC)"; \
		echo "Usage: make helm-show-values chart=<repo/name>"; \
		exit 1; \
	fi
	@helm show values $(chart)

# ============================================================================
# Help Target
# ============================================================================

.PHONY: helm-help
helm-help: ## Show Helm operations help
	@echo ""
	@echo "$(_SOPS_BOLD)Helm Operations$(_SOPS_NC)"
	@echo ""
	@echo "$(_SOPS_BOLD)Repository Management:$(_SOPS_NC)"
	@echo "  helm-repo-add      Add a repository (repo=name url=https://...)"
	@echo "  helm-repo-update   Update all repositories"
	@echo "  helm-repo-list     List configured repositories"
	@echo ""
	@echo "$(_SOPS_BOLD)Chart Operations:$(_SOPS_NC)"
	@echo "  helm-install       Install/upgrade a chart"
	@echo "                     chart=<name|repo/name> values=<file> [ns=namespace] [version=x.y.z]"
	@echo "  helm-upgrade       Upgrade a release (alias for helm-install)"
	@echo "  helm-uninstall     Uninstall a release (release=name ns=namespace)"
	@echo "  helm-rollback      Rollback a release (release=name [revision=n])"
	@echo ""
	@echo "$(_SOPS_BOLD)Status:$(_SOPS_NC)"
	@echo "  helm-list          List releases ([ns=namespace|all])"
	@echo "  helm-status        Show release status (release=name)"
	@echo "  helm-history       Show release history (release=name)"
	@echo "  helm-values        Show release values (release=name)"
	@echo ""
	@echo "$(_SOPS_BOLD)Search:$(_SOPS_NC)"
	@echo "  helm-search        Search for charts (query=term)"
	@echo "  helm-show-values   Show chart default values (chart=repo/name)"
	@echo ""
	@echo "$(_SOPS_BOLD)Pre-configured Repositories:$(_SOPS_NC)"
	@echo "  cilium, jetstack, ingress-nginx, prometheus-community,"
	@echo "  grafana, bitnami, argo, openebs, longhorn, metallb,"
	@echo "  traefik, hashicorp, external-secrets"
	@echo ""
	@echo "$(_SOPS_BOLD)Examples:$(_SOPS_NC)"
	@echo "  make helm-install chart=cilium values=generated/cilium-values.yaml ns=kube-system"
	@echo "  make helm-install chart=jetstack/cert-manager values=cm.yaml ns=cert-manager"
	@echo "  make helm-list ns=all"
	@echo "  make helm-uninstall release=cilium ns=kube-system"
	@echo ""
	@echo "$(_SOPS_BOLD)Configuration Variables:$(_SOPS_NC)"
	@echo "  HELM_WAIT=$(HELM_WAIT)       Wait for resources"
	@echo "  HELM_TIMEOUT=$(HELM_TIMEOUT)     Operation timeout"
	@echo "  HELM_ATOMIC=$(HELM_ATOMIC)     Rollback on failure"
	@echo ""
