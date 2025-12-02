# ============================================================================
# docker-compose.mk - Unified Docker Compose Operations
# ============================================================================
# Shared Makefile include for standardized Docker Compose operations
# with SOPS-encrypted secrets across docker overlay environments.
#
# Usage:
#   Include this file in your overlay Makefile after sops.mk:
#     include ../../../../makefiles/sops.mk
#     include ../../../../makefiles/docker-compose.mk
#
# Required variables (set before including):
#   SERVICE_NAME       - Service identifier (e.g., immich, gitea)
#   BASE_DIR           - Path to base directory (e.g., ../../../base/$(SERVICE_NAME))
#   BASE_COMPOSE       - Path to base compose file
#   ENV_ENC            - Encrypted environment file (e.g., .enc.env)
#
# Optional variables:
#   COMPOSE_ENC_FILES  - Space-separated list of encrypted compose files
#   COMPOSE_RAW_FILES  - Space-separated list of non-encrypted compose files
#   DC_PROJECT_NAME    - Docker compose project name (default: SERVICE_NAME)
#   DC_NO_INTERPOLATE  - Disable variable interpolation in config (default: true)
#
# Reference:
#   specs/security/unified-sops-operations.md
# ============================================================================

# ============================================================================
# Default Configuration
# ============================================================================

# Docker compose project name (defaults to SERVICE_NAME)
DC_PROJECT_NAME ?= $(SERVICE_NAME)

# Disable variable interpolation by default (shows raw ${VAR} syntax)
DC_NO_INTERPOLATE ?= true

# ============================================================================
# Validation
# ============================================================================

ifndef SERVICE_NAME
  $(error SERVICE_NAME must be set before including docker-compose.mk)
endif

ifndef BASE_COMPOSE
  $(error BASE_COMPOSE must be set before including docker-compose.mk)
endif

ifndef ENV_ENC
  $(error ENV_ENC must be set before including docker-compose.mk)
endif

# ============================================================================
# Docker Compose Operations
# ============================================================================

##@ Docker Compose

.PHONY: dc-env
dc-env: sops-check-deps ## Show decrypted .enc.env file
	@if [ ! -f "$(ENV_ENC)" ]; then \
		echo "$(_SOPS_RED)Error: $(ENV_ENC) not found$(_SOPS_NC)"; \
		exit 1; \
	fi
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops -d $(ENV_ENC)

.PHONY: dc-config
dc-config: sops-check-deps ## Output merged docker-compose configuration
	@export SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)"; \
	tmpdir=$$(mktemp -d); \
	trap "rm -rf $$tmpdir" EXIT; \
	_compose_files="-f $(BASE_COMPOSE)"; \
	for file in $(COMPOSE_ENC_FILES); do \
		if [ -f "$$file" ]; then \
			_base=$$(basename "$$file" .enc.yml); \
			sops -d "$$file" > "$$tmpdir/$${_base}.yml"; \
			_compose_files="$$_compose_files -f $$tmpdir/$${_base}.yml"; \
		fi; \
	done; \
	for file in $(COMPOSE_RAW_FILES); do \
		if [ -f "$$file" ]; then \
			_compose_files="$$_compose_files -f $$file"; \
		fi; \
	done; \
	if [ "$(DC_NO_INTERPOLATE)" = "true" ]; then \
		eval docker compose --project-directory . $$_compose_files config --no-interpolate; \
	else \
		eval docker compose --project-directory . $$_compose_files config; \
	fi

# Helper function for running docker compose with decrypted files
# Usage: $(call dc_run,<command>)
# Example: $(call dc_run,up -d)
define dc_run
	@export SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)"; \
	tmpdir=$$(mktemp -d); \
	trap "rm -rf $$tmpdir" EXIT; \
	_compose_files="-f $(BASE_COMPOSE)"; \
	_env_file=""; \
	if [ -f "$(ENV_ENC)" ]; then \
		sops -d $(ENV_ENC) > "$$tmpdir/.env"; \
		_env_file="--env-file $$tmpdir/.env"; \
	fi; \
	for file in $(COMPOSE_ENC_FILES); do \
		if [ -f "$$file" ]; then \
			_base=$$(basename "$$file" .enc.yml); \
			sops -d "$$file" > "$$tmpdir/$${_base}.yml"; \
			_compose_files="$$_compose_files -f $$tmpdir/$${_base}.yml"; \
		fi; \
	done; \
	for file in $(COMPOSE_RAW_FILES); do \
		if [ -f "$$file" ]; then \
			_compose_files="$$_compose_files -f $$file"; \
		fi; \
	done; \
	eval docker compose --project-directory . $$_compose_files $$_env_file $(1)
endef

# ============================================================================
# Docker Compose Lifecycle
# ============================================================================

.PHONY: dc-up
dc-up: sops-check-deps ## Start services (decrypts and runs)
	$(call dc_run,up -d)

.PHONY: dc-down
dc-down: sops-check-deps ## Stop services
	$(call dc_run,down)

.PHONY: dc-logs
dc-logs: sops-check-deps ## View service logs (follow mode)
	$(call dc_run,logs -f)

.PHONY: dc-ps
dc-ps: sops-check-deps ## Show running containers
	$(call dc_run,ps)

.PHONY: dc-restart
dc-restart: sops-check-deps ## Restart services
	$(call dc_run,restart)

.PHONY: dc-pull
dc-pull: sops-check-deps ## Pull latest images
	$(call dc_run,pull)

.PHONY: dc-exec
dc-exec: sops-check-deps ## Execute command in container (SERVICE= CMD=)
ifndef SERVICE
	@echo "$(_SOPS_RED)Error: SERVICE not specified$(_SOPS_NC)"
	@echo "Usage: make dc-exec SERVICE=<service> CMD=<command>"
	@exit 1
endif
ifndef CMD
	@echo "$(_SOPS_RED)Error: CMD not specified$(_SOPS_NC)"
	@echo "Usage: make dc-exec SERVICE=<service> CMD=<command>"
	@exit 1
endif
	$(call dc_run,exec $(SERVICE) $(CMD))

# ============================================================================
# Docker Compose Help
# ============================================================================

.PHONY: dc-help
dc-help: ## Show Docker Compose operations help
	@echo ""
	@echo "$(_SOPS_BOLD)Docker Compose Operations$(_SOPS_NC) - $(SERVICE_NAME)"
	@echo "Base: $(BASE_COMPOSE)"
	@echo ""
	@echo "$(_SOPS_BOLD)View Operations:$(_SOPS_NC)"
	@echo "  dc-env             Show decrypted environment file"
	@echo "  dc-config          Output merged docker-compose config"
	@echo ""
	@echo "$(_SOPS_BOLD)Lifecycle:$(_SOPS_NC)"
	@echo "  dc-up              Start services"
	@echo "  dc-down            Stop services"
	@echo "  dc-restart         Restart services"
	@echo "  dc-logs            View logs (follow mode)"
	@echo "  dc-ps              Show running containers"
	@echo "  dc-pull            Pull latest images"
	@echo "  dc-exec            Execute command (SERVICE= CMD=)"
	@echo ""
	@echo "$(_SOPS_BOLD)Files:$(_SOPS_NC)"
	@echo "  Encrypted env:     $(ENV_ENC)"
	@echo "  Encrypted compose: $(COMPOSE_ENC_FILES)"
	@echo "  Raw compose:       $(COMPOSE_RAW_FILES)"
	@echo ""

# ============================================================================
# Backward Compatibility Aliases
# ============================================================================
# Domain Makefiles can override these or add their own aliases

.PHONY: env config up down logs ps restart pull
env: dc-env ## Alias for dc-env
	@:
config: dc-config ## Alias for dc-config
	@:
up: dc-up ## Alias for dc-up
	@:
down: dc-down ## Alias for dc-down
	@:
logs: dc-logs ## Alias for dc-logs
	@:
ps: dc-ps ## Alias for dc-ps
	@:
restart: dc-restart ## Alias for dc-restart
	@:
pull: dc-pull ## Alias for dc-pull
	@:
