# =============================================================================
# Makefile - Media Stack Management
# NAS QNAP TS-435XeU - Homelab
# =============================================================================

.DEFAULT_GOAL := help

.PHONY: help setup up down restart logs pull update status backup clean health show-urls \
        validate check-docker check-compose recyclarr-sync recyclarr-config

# Compose files
COMPOSE_FILES := -f docker/compose.yml -f docker/compose.media.yml
COMPOSE_CMD := docker compose $(COMPOSE_FILES)
HOST_IP := 192.168.3.10

# Colors for output (if terminal supports it)
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
CYAN := \033[0;36m
PURPLE := \033[0;35m
BOLD := \033[1m
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
	@echo ""
	@echo "  $(GREEN)$(BOLD)MEDIA STACK$(NC) - Available commands"
	@echo ""
	@echo "  $(PURPLE)Setup & Validation$(NC)"
	@echo "    $(CYAN)make setup$(NC)       - Create folder structure (run once)"
	@echo "    $(CYAN)make validate$(NC)    - Verify compose configuration"
	@echo ""
	@echo "  $(PURPLE)Container Management$(NC)"
	@echo "    $(CYAN)make up$(NC)          - Start all containers"
	@echo "    $(CYAN)make down$(NC)        - Stop all containers"
	@echo "    $(CYAN)make restart$(NC)     - Full restart"
	@echo "    $(CYAN)make pull$(NC)        - Update Docker images"
	@echo "    $(CYAN)make update$(NC)      - Pull images and restart (pull + restart)"
	@echo ""
	@echo "  $(PURPLE)Monitoring$(NC)"
	@echo "    $(CYAN)make logs$(NC)        - Show logs (follow)"
	@echo "    $(CYAN)make status$(NC)      - Container status and resources"
	@echo "    $(CYAN)make health$(NC)      - Health check all services"
	@echo "    $(CYAN)make show-urls$(NC)   - Show WebUI URLs"
	@echo ""
	@echo "  $(PURPLE)Backup$(NC)"
	@echo "    $(CYAN)make backup$(NC) - Trigger Duplicati backup on demand"
	@echo "                   Duplicati WebUI: http://$(HOST_IP):8200"
	@echo ""
	@echo "  $(PURPLE)Utilities$(NC)"
	@echo "    $(CYAN)make clean$(NC)            - Remove orphan Docker resources"
	@echo "    $(CYAN)make recyclarr-sync$(NC)   - Manual Trash Guides profile sync"
	@echo "    $(CYAN)make recyclarr-config$(NC) - Generate Recyclarr config template"
	@echo ""
	@echo "  $(PURPLE)Per service$(NC)"
	@echo "    $(CYAN)make logs-SERVICE$(NC)  - Single service logs (e.g., make logs-sonarr)"
	@echo "    $(CYAN)make shell-SERVICE$(NC) - Shell into container (e.g., make shell-radarr)"

# =============================================================================
# Setup
# =============================================================================

setup: check-compose
	@echo ">>> Creating folder structure..."
	@if [ ! -x scripts/setup-folders.sh ]; then \
		chmod +x scripts/setup-folders.sh; \
	fi
	@./scripts/setup-folders.sh
	@echo ">>> Creating additional config directories..."
	@mkdir -p ./config/recyclarr ./config/duplicati
	@if [ ! -f docker/.env ]; then \
		echo ">>> Creating .env from template..."; \
		cp docker/.env.example docker/.env 2>/dev/null || echo "PIHOLE_PASSWORD=changeme" > docker/.env; \
		echo "$(YELLOW)WARNING: Edit docker/.env with your passwords$(NC)"; \
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

update: pull restart
	@echo "$(GREEN)>>> Update complete$(NC)"

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
	@echo ">>> Triggering Duplicati backup..."
	@if docker ps --format '{{.Names}}' | grep -q '^duplicati$$'; then \
		BACKUP_ID=$$(curl -s http://localhost:8200/api/v1/backups 2>/dev/null | grep -o '"ID":"[^"]*"' | head -1 | cut -d'"' -f4); \
		if [ -n "$$BACKUP_ID" ]; then \
			curl -s -X POST "http://localhost:8200/api/v1/backup/$$BACKUP_ID/run" >/dev/null && \
			echo "$(GREEN)>>> Backup started (ID: $$BACKUP_ID)$(NC)" && \
			echo "Monitor progress at http://$(HOST_IP):8200"; \
		else \
			echo "$(YELLOW)No backup job configured yet$(NC)"; \
			echo "Configure backup via http://$(HOST_IP):8200"; \
		fi; \
	else \
		echo "$(RED)Error: duplicati container not running$(NC)"; \
		echo "Run 'make up' first"; \
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
	$(call check_service,http://localhost:8191/health,FlareSolverr)
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

show-urls:
	@echo "=== Web UI URLs ==="
	@echo ""
	@echo "$(GREEN)Media Stack$(NC)"
	@echo "  Sonarr:       http://$(HOST_IP):8989"
	@echo "  Radarr:       http://$(HOST_IP):7878"
	@echo "  Lidarr:       http://$(HOST_IP):8686"
	@echo "  Prowlarr:     http://$(HOST_IP):9696"
	@echo "  Bazarr:       http://$(HOST_IP):6767"
	@echo ""
	@echo "$(GREEN)Download$(NC)"
	@echo "  qBittorrent:  http://$(HOST_IP):8080"
	@echo "  NZBGet:       http://$(HOST_IP):6789"
	@echo ""
	@echo "$(GREEN)Monitoring$(NC)"
	@echo "  Huntarr:      http://$(HOST_IP):7500"
	@echo "  Cleanuparr:   http://$(HOST_IP):11011"
	@echo ""
	@echo "$(GREEN)Infrastructure$(NC)"
	@echo "  Pi-hole:      http://$(HOST_IP):8081/admin"
	@echo "  Home Assist:  http://$(HOST_IP):8123"
	@echo "  Portainer:    https://$(HOST_IP):9443"
	@echo "  Duplicati:    http://$(HOST_IP):8200"
	@echo ""
