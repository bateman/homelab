# =============================================================================
# Makefile - Media Stack Management
# NAS QNAP TS-435XeU - Homelab
# =============================================================================

.PHONY: help setup up down restart logs pull status backup clean health urls \
        validate check-docker check-compose recyclarr-sync recyclarr-config

# Compose files
COMPOSE_FILES := -f compose.yml -f compose.media.yml
COMPOSE_CMD := docker compose $(COMPOSE_FILES)
BACKUP_DIR := ./backups

# Colors for output (if terminal supports it)
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

# =============================================================================
# Validation
# =============================================================================

check-docker:
	@command -v docker >/dev/null 2>&1 || { \
		echo "$(RED)Error: docker not found. Install Docker before continuing.$(NC)"; \
		exit 1; \
	}

check-compose: check-docker
	@docker compose version >/dev/null 2>&1 || { \
		echo "$(RED)Error: docker compose not available. Docker Compose v2 required.$(NC)"; \
		exit 1; \
	}

validate: check-compose
	@echo ">>> Validating configuration..."
	@$(COMPOSE_CMD) config --quiet && \
		echo "$(GREEN)Configuration valid$(NC)" || { \
		echo "$(RED)Error in compose configuration$(NC)"; \
		exit 1; \
	}

# =============================================================================
# Help
# =============================================================================

help:
	@echo "Media Stack - Available commands:"
	@echo ""
	@echo "  $(GREEN)Setup & Validation$(NC)"
	@echo "    make setup       - Create folder structure (run once)"
	@echo "    make validate    - Verify compose configuration"
	@echo ""
	@echo "  $(GREEN)Container Management$(NC)"
	@echo "    make up          - Start all containers"
	@echo "    make down        - Stop all containers"
	@echo "    make restart     - Full restart"
	@echo "    make pull        - Update Docker images"
	@echo ""
	@echo "  $(GREEN)Monitoring$(NC)"
	@echo "    make logs        - Show logs (follow)"
	@echo "    make status      - Container status and resources"
	@echo "    make health      - Health check all services"
	@echo "    make urls        - Show WebUI URLs"
	@echo ""
	@echo "  $(GREEN)Backup$(NC)"
	@echo "    make backup      - Quick config backup (local tar.gz)"
	@echo "    Duplicati WebUI  - http://192.168.3.10:8200 (scheduled backups)"
	@echo ""
	@echo "  $(GREEN)Utilities$(NC)"
	@echo "    make clean       - Remove orphan Docker resources"
	@echo "    make recyclarr-sync   - Manual Trash Guides profile sync"
	@echo "    make recyclarr-config - Generate Recyclarr config template"
	@echo ""
	@echo "  $(GREEN)Per service$(NC)"
	@echo "    make logs-SERVICE  - Single service logs (e.g.: make logs-sonarr)"
	@echo "    make shell-SERVICE - Shell into container (e.g.: make shell-radarr)"

# =============================================================================
# Setup
# =============================================================================

setup: check-compose
	@echo ">>> Creating folder structure..."
	@if [ ! -x setup-folders.sh ]; then \
		chmod +x setup-folders.sh; \
	fi
	@./setup-folders.sh
	@echo ">>> Creating additional config directories..."
	@mkdir -p ./config/recyclarr ./config/duplicati
	@if [ ! -f .env ]; then \
		echo ">>> Creating .env from template..."; \
		cp .env.example .env 2>/dev/null || echo "PIHOLE_PASSWORD=changeme" > .env; \
		echo "$(YELLOW)WARNING: Edit .env with your passwords$(NC)"; \
	fi
	@echo "$(GREEN)>>> Setup complete$(NC)"

# =============================================================================
# Container Management
# =============================================================================

up: validate
	@echo ">>> Starting stack..."
	@$(COMPOSE_CMD) up -d
	@if [ $$? -eq 0 ]; then \
		echo "$(GREEN)>>> Stack started$(NC)"; \
		$(MAKE) --no-print-directory status; \
	else \
		echo "$(RED)>>> Error starting stack$(NC)"; \
		exit 1; \
	fi

down: check-compose
	@echo ">>> Stopping stack..."
	@$(COMPOSE_CMD) down
	@echo "$(GREEN)>>> Stack stopped$(NC)"

restart: down up

pull: check-compose
	@echo ">>> Pulling updated images..."
	@$(COMPOSE_CMD) pull
	@if [ $$? -eq 0 ]; then \
		echo "$(GREEN)>>> Pull complete. Run 'make restart' to apply$(NC)"; \
	else \
		echo "$(RED)>>> Error pulling images$(NC)"; \
		exit 1; \
	fi

# =============================================================================
# Monitoring
# =============================================================================

logs: check-compose
	@$(COMPOSE_CMD) logs -f --tail=100

logs-%: check-compose
	@$(COMPOSE_CMD) logs -f --tail=100 $*

status: check-compose
	@echo ""
	@echo "=== Container Status ==="
	@$(COMPOSE_CMD) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "=== Resource Usage ==="
	@CONTAINERS=$$($(COMPOSE_CMD) ps -q 2>/dev/null); \
	if [ -n "$$CONTAINERS" ]; then \
		docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" $$CONTAINERS; \
	else \
		echo "$(YELLOW)No containers running$(NC)"; \
	fi
	@echo ""
	@echo "=== Disk Usage ==="
	@if [ -d /share/data ]; then \
		df -h /share/data; \
	else \
		df -h . | head -2; \
	fi

# =============================================================================
# Utilities
# =============================================================================

shell-%: check-compose
	@$(COMPOSE_CMD) exec $* /bin/bash 2>/dev/null || \
		$(COMPOSE_CMD) exec $* /bin/sh 2>/dev/null || { \
		echo "$(RED)Error: cannot open shell in $*$(NC)"; \
		exit 1; \
	}

backup: check-docker
	@echo ">>> Backing up configurations..."
	@mkdir -p $(BACKUP_DIR)
	@if [ ! -d ./config ]; then \
		echo "$(RED)Error: config directory not found$(NC)"; \
		exit 1; \
	fi
	@BACKUP_NAME="config-backup-$$(date +%Y%m%d-%H%M%S).tar.gz"; \
	if tar -czf "$(BACKUP_DIR)/$$BACKUP_NAME" ./config; then \
		echo "$(GREEN)>>> Backup created: $(BACKUP_DIR)/$$BACKUP_NAME$(NC)"; \
		ls -lh "$(BACKUP_DIR)/$$BACKUP_NAME"; \
	else \
		echo "$(RED)>>> Error creating backup$(NC)"; \
		exit 1; \
	fi

clean: check-docker
	@echo ">>> Cleaning orphan Docker resources..."
	@echo "$(YELLOW)WARNING: This will remove unused containers, images and volumes$(NC)"
	@read -p "Continue? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker system prune -f && docker volume prune -f; \
		echo "$(GREEN)>>> Cleanup complete$(NC)"; \
	else \
		echo ">>> Operation cancelled"; \
	fi

# =============================================================================
# Recyclarr
# =============================================================================

recyclarr-sync: check-compose
	@echo ">>> Syncing Trash Guides quality profiles..."
	@if docker ps --format '{{.Names}}' | grep -q '^recyclarr$$'; then \
		docker exec recyclarr recyclarr sync && \
		echo "$(GREEN)>>> Sync complete$(NC)"; \
	else \
		echo "$(RED)Error: recyclarr container not running$(NC)"; \
		echo "Run 'make up' before syncing"; \
		exit 1; \
	fi

recyclarr-config: check-compose
	@echo ">>> Generating Recyclarr configuration template..."
	@if docker ps --format '{{.Names}}' | grep -q '^recyclarr$$'; then \
		docker exec recyclarr recyclarr config create && \
		echo "$(GREEN)>>> Template created in ./config/recyclarr/$(NC)"; \
	else \
		echo "$(RED)Error: recyclarr container not running$(NC)"; \
		exit 1; \
	fi

# =============================================================================
# Health Check
# =============================================================================

define check_service
	@STATUS=$$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 $(1) 2>/dev/null); \
	if [ "$$STATUS" = "200" ] || [ "$$STATUS" = "401" ]; then \
		echo "$(2): $(GREEN)OK ($$STATUS)$(NC)"; \
	elif [ -n "$$STATUS" ] && [ "$$STATUS" != "000" ]; then \
		echo "$(2): $(YELLOW)$$STATUS$(NC)"; \
	else \
		echo "$(2): $(RED)DOWN$(NC)"; \
	fi
endef

health: check-docker
	@echo "=== Health Check ==="
	@echo ""
	$(call check_service,http://localhost:8989/ping,Sonarr)
	$(call check_service,http://localhost:7878/ping,Radarr)
	$(call check_service,http://localhost:8686/ping,Lidarr)
	$(call check_service,http://localhost:9696/ping,Prowlarr)
	$(call check_service,http://localhost:6767/ping,Bazarr)
	$(call check_service,http://localhost:8080,qBittorrent)
	$(call check_service,http://localhost:6789,NZBGet)
	$(call check_service,http://localhost:7500,Huntarr)
	$(call check_service,http://localhost:11011/health,Cleanuparr)
	$(call check_service,http://localhost:8081/admin,Pi-hole)
	$(call check_service,http://localhost:8123/api/,HomeAssistant)
	$(call check_service,http://localhost:8200,Duplicati)
	@# Portainer uses HTTPS
	@STATUS=$$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 https://localhost:9443 2>/dev/null); \
	if [ "$$STATUS" = "200" ] || [ "$$STATUS" = "303" ]; then \
		echo "Portainer: $(GREEN)OK ($$STATUS)$(NC)"; \
	elif [ -n "$$STATUS" ] && [ "$$STATUS" != "000" ]; then \
		echo "Portainer: $(YELLOW)$$STATUS$(NC)"; \
	else \
		echo "Portainer: $(RED)DOWN$(NC)"; \
	fi
	@echo ""

# =============================================================================
# Quick Reference
# =============================================================================

urls:
	@echo "=== Web UI URLs ==="
	@echo ""
	@echo "$(GREEN)Media Stack$(NC)"
	@echo "  Sonarr:       http://192.168.3.10:8989"
	@echo "  Radarr:       http://192.168.3.10:7878"
	@echo "  Lidarr:       http://192.168.3.10:8686"
	@echo "  Prowlarr:     http://192.168.3.10:9696"
	@echo "  Bazarr:       http://192.168.3.10:6767"
	@echo ""
	@echo "$(GREEN)Download$(NC)"
	@echo "  qBittorrent:  http://192.168.3.10:8080"
	@echo "  NZBGet:       http://192.168.3.10:6789"
	@echo ""
	@echo "$(GREEN)Monitoring$(NC)"
	@echo "  Huntarr:      http://192.168.3.10:7500"
	@echo "  Cleanuparr:   http://192.168.3.10:11011"
	@echo ""
	@echo "$(GREEN)Infrastructure$(NC)"
	@echo "  Pi-hole:      http://192.168.3.10:8081/admin"
	@echo "  Home Assist:  http://192.168.3.10:8123"
	@echo "  Portainer:    https://192.168.3.10:9443"
	@echo "  Duplicati:    http://192.168.3.10:8200"
	@echo ""
