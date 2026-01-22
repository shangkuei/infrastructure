# Makefile for cAdvisor Docker overlay - shangkuei-xyz-unraid
SHELL := /bin/bash
.DEFAULT_GOAL := help

# ============================================================================
# SOPS Configuration (must be set before including sops.mk)
# ============================================================================
SOPS_DOMAIN := docker
SOPS_ENV_NAME := cadvisor-shangkuei-xyz-unraid
SOPS_KEY_STRATEGY := local

# Include shared SOPS operations
include ../../../../makefiles/sops.mk

# ============================================================================
# Docker Configuration
# ============================================================================
SERVICE_NAME := cadvisor
BASE_DIR := ../../../base/$(SERVICE_NAME)

# Encrypted files (none for this service)
ENV_ENC := .enc.env

# Base compose file
BASE_COMPOSE := $(BASE_DIR)/docker-compose.yml

# Docker compose file lists (for docker-compose.mk)
COMPOSE_ENC_FILES :=
COMPOSE_RAW_FILES := docker-compose.override.yml

# Include shared Docker Compose operations
include ../../../../makefiles/docker-compose.mk

# ============================================================================
# Help
# ============================================================================
.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "cAdvisor Docker Overlay - shangkuei-xyz-unraid"
	@echo "==============================================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Docker Compose Operations:"
	@echo "  config               Output docker-compose config"
	@echo "  up                   Start services"
	@echo "  down                 Stop services"
	@echo "  logs                 View logs (follow mode)"
	@echo "  ps                   Show running containers"
	@echo "  restart              Restart services"
	@echo "  pull                 Pull latest images"
	@echo ""
	@echo "Verification:"
	@echo "  test-metrics         Test metrics endpoint"
	@echo "  test-health          Test health endpoint"
	@echo ""

# ============================================================================
# Verification
# ============================================================================
.PHONY: test-metrics
test-metrics: ## Test metrics endpoint (via docker exec)
	@echo "Testing metrics endpoint..."
	@docker exec cadvisor wget -qO- http://localhost:8080/metrics | head -20
	@echo ""
	@echo "Metrics endpoint is working!"

.PHONY: test-health
test-health: ## Test health endpoint (via docker exec)
	@echo "Testing health endpoint..."
	@docker exec cadvisor wget -qO- http://localhost:8080/healthz && echo " - Healthy!"
