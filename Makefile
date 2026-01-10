# =============================================================================
# Makefile - Media Stack Management
# NAS QNAP TS-435XeU - Homelab
# =============================================================================

.DEFAULT_GOAL := help

.PHONY: help setup setup-dry-run up down restart logs pull update status backup backup-qts verify-backup clean health show-urls urls \
        validate check-docker check-compose check-curl recyclarr-sync recyclarr-config \
        logs-% shell-%

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

check-curl:
	@command -v curl >/dev/null 2>&1 || { \
		echo "$(RED)Error: curl not found. Install curl before continuing.$(NC)"; \
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
	@echo "    $(CYAN)make setup$(NC)         - Create folder structure (run once)"
	@echo "    $(CYAN)make setup-dry-run$(NC) - Preview folder structure (no changes)"
	@echo "    $(CYAN)make validate$(NC)      - Verify compose configuration"
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
	@echo "    $(CYAN)make backup$(NC)        - Trigger Duplicati backup on demand"
	@echo "    $(CYAN)make backup-qts$(NC)    - Backup QNAP QTS system configuration"
	@echo "    $(CYAN)make verify-backup$(NC) - Verify backup integrity (extraction + SQLite)"
	@echo "                         Duplicati WebUI: http://$(HOST_IP):8200"
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
	@if [ ! -f docker/.env ]; then \
		echo ">>> Creating .env from template..."; \
		cp docker/.env.example docker/.env; \
	fi
	@if [ ! -f docker/.env.secrets ]; then \
		echo ">>> Creating .env.secrets from template..."; \
		cp docker/.env.secrets.example docker/.env.secrets; \
		echo "$(YELLOW)WARNING: Edit docker/.env.secrets with your passwords$(NC)"; \
	fi
	@echo "$(GREEN)>>> Setup complete$(NC)"

setup-dry-run:
	@echo ">>> Previewing folder structure (dry-run)..."
	@if [ ! -x scripts/setup-folders.sh ]; then \
		chmod +x scripts/setup-folders.sh; \
	fi
	@./scripts/setup-folders.sh --dry-run

# =============================================================================
# Container Management
# =============================================================================

up: validate
	@echo ">>> Starting stack..."
	@$(COMPOSE_CMD) up -d && \
		echo "$(GREEN)>>> Stack started$(NC)" && \
		$(MAKE) --no-print-directory status || \
		{ echo "$(RED)>>> Error starting stack$(NC)"; exit 1; }

down: check-compose
	@echo ">>> Stopping stack..."
	@$(COMPOSE_CMD) down
	@echo "$(GREEN)>>> Stack stopped$(NC)"

restart: down up

pull: check-compose
	@echo ">>> Pulling updated images..."
	@$(COMPOSE_CMD) pull && \
		echo "$(GREEN)>>> Pull complete. Run 'make restart' to apply$(NC)" || \
		{ echo "$(RED)>>> Error pulling images$(NC)"; exit 1; }

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

backup: check-docker check-curl
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

verify-backup:
	@echo ">>> Verifying backup integrity..."
	@if [ ! -x scripts/verify-backup.sh ]; then \
		chmod +x scripts/verify-backup.sh; \
	fi
	@./scripts/verify-backup.sh --verbose

backup-qts:
	@echo ">>> Backing up QNAP QTS configuration..."
	@if [ ! -x scripts/backup-qts-config.sh ]; then \
		chmod +x scripts/backup-qts-config.sh; \
	fi
	@./scripts/backup-qts-config.sh --verbose

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

health: check-docker check-curl
	@echo "=== Health Check ==="
	@echo ""
	$(call check_service,http://localhost:8989/ping,Sonarr)
	$(call check_service,http://localhost:7878/ping,Radarr)
	$(call check_service,http://localhost:8686/ping,Lidarr)
	$(call check_service,http://localhost:9696/ping,Prowlarr)
	$(call check_service,http://localhost:6767/ping,Bazarr)
	@# Gluetun health check (only when vpn profile is active)
	@if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^gluetun$$'; then \
		HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' gluetun 2>/dev/null); \
		if [ "$$HEALTH" = "healthy" ]; then \
			echo "Gluetun: $(GREEN)OK (VPN connected)$(NC)"; \
		elif [ "$$HEALTH" = "starting" ]; then \
			echo "Gluetun: $(YELLOW)STARTING$(NC)"; \
		else \
			echo "Gluetun: $(RED)UNHEALTHY$(NC)"; \
		fi; \
	else \
		echo "Gluetun: $(YELLOW)NOT RUNNING (novpn profile?)$(NC)"; \
	fi
	$(call check_service,http://localhost:8080,qBittorrent)
	$(call check_service,http://localhost:6789,NZBGet)
	$(call check_service,http://localhost:9705,Huntarr)
	$(call check_service,http://localhost:11011/health,Cleanuparr)
	$(call check_service,http://localhost:8191/health,FlareSolverr)
	$(call check_service,http://localhost:8081/admin,Pi-hole)
	# $(call check_service,http://localhost:8123/api/,HomeAssistant)  # Disabled - see compose.homeassistant.yml
	$(call check_service,http://localhost:8200,Duplicati)
	$(call check_service,http://localhost:3001,UptimeKuma)
	$(call check_service,http://localhost:8383/v1/metrics,Watchtower)
	$(call check_service,http://localhost:80,Traefik)
	@# Authelia health check
	@HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' authelia 2>/dev/null); \
	if [ "$$HEALTH" = "healthy" ]; then \
		echo "Authelia: $(GREEN)OK (healthy)$(NC)"; \
	elif [ "$$HEALTH" = "starting" ]; then \
		echo "Authelia: $(YELLOW)STARTING$(NC)"; \
	elif [ -z "$$HEALTH" ]; then \
		echo "Authelia: $(YELLOW)NOT RUNNING$(NC)"; \
	else \
		echo "Authelia: $(RED)UNHEALTHY$(NC)"; \
	fi
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
	@echo "  FlareSolverr: http://$(HOST_IP):8191"
	@echo ""
	@echo "$(GREEN)Monitoring$(NC)"
	@echo "  Uptime Kuma:  http://$(HOST_IP):3001"
	@echo "  Huntarr:      http://$(HOST_IP):9705"
	@echo "  Cleanuparr:   http://$(HOST_IP):11011"
	@echo "  Watchtower:   http://$(HOST_IP):8383/v1/metrics"
	@echo ""
	@echo "$(GREEN)Infrastructure$(NC)"
	@echo "  Pi-hole:      http://$(HOST_IP):8081/admin"
	# @echo "  Home Assist:  http://$(HOST_IP):8123"  # Disabled - see compose.homeassistant.yml
	@echo "  Portainer:    https://$(HOST_IP):9443"
	@echo "  Duplicati:    http://$(HOST_IP):8200"
	@echo "  Traefik:      https://traefik.home.local (requires DNS)"
	@echo ""
	@echo "$(GREEN)Authentication (SSO)$(NC)"
	@echo "  Authelia:     https://auth.home.local (requires DNS)"
	@echo ""
	@echo "$(YELLOW)Note: All services require Authelia SSO when accessed via *.home.local$(NC)"
	@echo ""

# Alias for show-urls
urls: show-urls
