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

# Colors for output (use with printf, not echo)
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
CYAN := \033[0;36m
PURPLE := \033[0;35m
BOLD := \033[1m
NC := \033[0m

# =============================================================================
# Validation
# =============================================================================

check-docker:
	@command -v docker >/dev/null 2>&1 || { \
		printf "$(RED)Error: docker not found. Install Docker before continuing.$(NC)\n"; \
		exit 1; \
	}

check-compose: check-docker
	@docker compose version >/dev/null 2>&1 || { \
		printf "$(RED)Error: docker compose not available. Docker Compose v2 required.$(NC)\n"; \
		exit 1; \
	}

check-curl:
	@command -v curl >/dev/null 2>&1 || { \
		printf "$(RED)Error: curl not found. Install curl before continuing.$(NC)\n"; \
		exit 1; \
	}

validate: check-compose
	@echo ">>> Validating configuration..."
	@if grep -q 'COMPOSE_PROFILES=.*vpn' docker/.env 2>/dev/null && \
		! grep -q 'COMPOSE_PROFILES=.*novpn' docker/.env 2>/dev/null; then \
		if ! grep -q '^VPN_SERVICE_PROVIDER=' docker/.env.secrets 2>/dev/null; then \
			printf "$(RED)Error: VPN_SERVICE_PROVIDER not set in docker/.env.secrets (required for vpn profile)$(NC)\n"; \
			exit 1; \
		fi; \
	fi
	@$(COMPOSE_CMD) config --quiet && \
		printf "$(GREEN)Configuration valid$(NC)\n" || { \
		printf "$(RED)Error in compose configuration$(NC)\n"; \
		exit 1; \
	}

# =============================================================================
# Help
# =============================================================================

help:
	@printf "\n"
	@printf "  $(GREEN)$(BOLD)MEDIA STACK$(NC) - Available commands\n"
	@printf "\n"
	@printf "  $(PURPLE)Setup & Validation$(NC)\n"
	@printf "    $(CYAN)make setup$(NC)         - Create folders, secrets, and certs (run once)\n"
	@printf "    $(CYAN)make setup-dry-run$(NC) - Preview folder structure (no changes)\n"
	@printf "    $(CYAN)make validate$(NC)      - Verify compose configuration\n"
	@printf "\n"
	@printf "  $(PURPLE)Container Management$(NC)\n"
	@printf "    $(CYAN)make up$(NC)          - Start all containers\n"
	@printf "    $(CYAN)make down$(NC)        - Stop all containers\n"
	@printf "    $(CYAN)make restart$(NC)     - Full restart\n"
	@printf "    $(CYAN)make pull$(NC)        - Update Docker images\n"
	@printf "    $(CYAN)make update$(NC)      - Pull images and restart (pull + restart)\n"
	@printf "\n"
	@printf "  $(PURPLE)Monitoring$(NC)\n"
	@printf "    $(CYAN)make logs$(NC)        - Show logs (follow)\n"
	@printf "    $(CYAN)make status$(NC)      - Container status and resources\n"
	@printf "    $(CYAN)make health$(NC)      - Health check all services\n"
	@printf "    $(CYAN)make show-urls$(NC)   - Show WebUI URLs\n"
	@printf "\n"
	@printf "  $(PURPLE)Backup$(NC)\n"
	@printf "    $(CYAN)make backup$(NC)        - Trigger Duplicati backup on demand\n"
	@printf "    $(CYAN)make backup-qts$(NC)    - Backup QNAP QTS system configuration\n"
	@printf "    $(CYAN)make verify-backup$(NC) - Verify backup integrity (extraction + SQLite)\n"
	@printf "                         Duplicati WebUI: http://$(HOST_IP):8200\n"
	@printf "\n"
	@printf "  $(PURPLE)Utilities$(NC)\n"
	@printf "    $(CYAN)make clean$(NC)            - Remove orphan Docker resources\n"
	@printf "    $(CYAN)make recyclarr-sync$(NC)   - Manual Trash Guides profile sync\n"
	@printf "    $(CYAN)make recyclarr-config$(NC) - Generate Recyclarr config template\n"
	@printf "\n"
	@printf "  $(PURPLE)Per service$(NC)\n"
	@printf "    $(CYAN)make logs-SERVICE$(NC)  - Single service logs (e.g., make logs-sonarr)\n"
	@printf "    $(CYAN)make shell-SERVICE$(NC) - Shell into container (e.g., make shell-radarr)\n"

# =============================================================================
# Setup
# =============================================================================

setup: check-compose
	@if [ ! -f docker/.env ]; then \
		echo ">>> Creating .env from template..."; \
		cp docker/.env.example docker/.env; \
		printf "$(YELLOW)>>> Review docker/.env (PUID/PGID must match file owner of /share/data)$(NC)\n"; \
	fi
	@if [ ! -f docker/.env.secrets ]; then \
		echo ">>> Creating .env.secrets from template..."; \
		cp docker/.env.secrets.example docker/.env.secrets; \
		printf "$(YELLOW)WARNING: Edit docker/.env.secrets with your passwords$(NC)\n"; \
	fi
	@echo ">>> Creating folder structure..."
	@if [ ! -x scripts/setup-folders.sh ]; then \
		chmod +x scripts/setup-folders.sh; \
	fi
	@./scripts/setup-folders.sh
	@echo ">>> Generating Authelia secrets..."
	@if [ ! -f docker/secrets/authelia/JWT_SECRET ]; then \
		if [ ! -x scripts/generate-authelia-secrets.sh ]; then \
			chmod +x scripts/generate-authelia-secrets.sh; \
		fi; \
		./scripts/generate-authelia-secrets.sh; \
	else \
		printf "$(GREEN)>>> Authelia secrets already exist (skipping)$(NC)\n"; \
	fi
	@echo ">>> Generating TLS certificates..."
	@if [ ! -f docker/config/traefik/certs/home.local.crt ]; then \
		if [ ! -x scripts/generate-certs.sh ]; then \
			chmod +x scripts/generate-certs.sh; \
		fi; \
		./scripts/generate-certs.sh; \
	else \
		printf "$(GREEN)>>> TLS certificates already exist (skipping)$(NC)\n"; \
	fi
	@printf "$(GREEN)>>> Setup complete$(NC)\n"

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
		printf "$(GREEN)>>> Stack started$(NC)\n" && \
		$(MAKE) --no-print-directory status || \
		{ printf "$(RED)>>> Error starting stack$(NC)\n"; exit 1; }

down: check-compose
	@echo ">>> Stopping stack..."
	@$(COMPOSE_CMD) down
	@printf "$(GREEN)>>> Stack stopped$(NC)\n"

restart: down up

pull: check-compose
	@echo ">>> Pulling updated images..."
	@$(COMPOSE_CMD) pull && \
		printf "$(GREEN)>>> Pull complete. Run 'make restart' to apply$(NC)\n" || \
		{ printf "$(RED)>>> Error pulling images$(NC)\n"; exit 1; }

update: pull restart
	@printf "$(GREEN)>>> Update complete$(NC)\n"

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
		printf "$(YELLOW)No containers running$(NC)\n"; \
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
		printf "$(RED)Error: cannot open shell in $*$(NC)\n"; \
		exit 1; \
	}

backup: check-docker check-curl
	@echo ">>> Triggering Duplicati backup..."
	@if docker ps --format '{{.Names}}' | grep -q '^duplicati$$'; then \
		BACKUP_ID=$$(curl -s http://localhost:8200/api/v1/backups 2>/dev/null | grep -o '"ID":"[^"]*"' | head -1 | cut -d'"' -f4); \
		if [ -n "$$BACKUP_ID" ]; then \
			curl -s -X POST "http://localhost:8200/api/v1/backup/$$BACKUP_ID/run" >/dev/null && \
			printf "$(GREEN)>>> Backup started (ID: $$BACKUP_ID)$(NC)\n" && \
			echo "Monitor progress at http://$(HOST_IP):8200"; \
		else \
			printf "$(YELLOW)No backup job configured yet$(NC)\n"; \
			echo "Configure backup via http://$(HOST_IP):8200"; \
		fi; \
	else \
		printf "$(RED)Error: duplicati container not running$(NC)\n"; \
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
	@printf "$(YELLOW)WARNING: This will remove unused containers, images and volumes$(NC)\n"
	@read -p "Continue? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker system prune -f && docker volume prune -f; \
		printf "$(GREEN)>>> Cleanup complete$(NC)\n"; \
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
		printf "$(GREEN)>>> Sync complete$(NC)\n"; \
	else \
		printf "$(RED)Error: recyclarr container not running$(NC)\n"; \
		echo "Run 'make up' before syncing"; \
		exit 1; \
	fi

recyclarr-config: check-compose
	@echo ">>> Generating Recyclarr configuration template..."
	@if docker ps --format '{{.Names}}' | grep -q '^recyclarr$$'; then \
		docker exec recyclarr recyclarr config create && \
		printf "$(GREEN)>>> Template created in ./config/recyclarr/$(NC)\n"; \
	else \
		printf "$(RED)Error: recyclarr container not running$(NC)\n"; \
		exit 1; \
	fi

# =============================================================================
# Health Check
# =============================================================================

define check_service
	@STATUS=$$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 $(1) 2>/dev/null); \
	if [ "$$STATUS" = "200" ] || [ "$$STATUS" = "401" ]; then \
		printf "$(2): $(GREEN)OK ($$STATUS)$(NC)\n"; \
	elif [ -n "$$STATUS" ] && [ "$$STATUS" != "000" ]; then \
		printf "$(2): $(YELLOW)$$STATUS$(NC)\n"; \
	else \
		printf "$(2): $(RED)DOWN$(NC)\n"; \
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
			printf "Gluetun: $(GREEN)OK (VPN connected)$(NC)\n"; \
		elif [ "$$HEALTH" = "starting" ]; then \
			printf "Gluetun: $(YELLOW)STARTING$(NC)\n"; \
		else \
			printf "Gluetun: $(RED)UNHEALTHY$(NC)\n"; \
		fi; \
	else \
		printf "Gluetun: $(YELLOW)NOT RUNNING (novpn profile?)$(NC)\n"; \
	fi
	$(call check_service,http://localhost:8080,qBittorrent)
	$(call check_service,http://localhost:6789,NZBGet)
	$(call check_service,http://localhost:11011/health,Cleanuparr)
	$(call check_service,http://localhost:8191/health,FlareSolverr)
	$(call check_service,http://localhost:8081/admin,Pi-hole)
	# $(call check_service,http://localhost:8123/api/,HomeAssistant)  # Disabled - see compose.homeassistant.yml
	$(call check_service,http://localhost:8200,Duplicati)
	$(call check_service,http://localhost:3001,UptimeKuma)
	$(call check_service,http://localhost:8383/v1/metrics,Watchtower)
	$(call check_service,http://localhost:80,Traefik)
	@# Tailscale health check
	@if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^tailscale$$'; then \
		HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' tailscale 2>/dev/null); \
		if [ "$$HEALTH" = "healthy" ]; then \
			printf "Tailscale: $(GREEN)OK (connected)$(NC)\n"; \
		elif [ "$$HEALTH" = "starting" ]; then \
			printf "Tailscale: $(YELLOW)STARTING$(NC)\n"; \
		else \
			printf "Tailscale: $(RED)UNHEALTHY$(NC)\n"; \
		fi; \
	else \
		printf "Tailscale: $(YELLOW)NOT RUNNING$(NC)\n"; \
	fi
	@# Authelia health check
	@HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' authelia 2>/dev/null); \
	if [ "$$HEALTH" = "healthy" ]; then \
		printf "Authelia: $(GREEN)OK (healthy)$(NC)\n"; \
	elif [ "$$HEALTH" = "starting" ]; then \
		printf "Authelia: $(YELLOW)STARTING$(NC)\n"; \
	elif [ -z "$$HEALTH" ]; then \
		printf "Authelia: $(YELLOW)NOT RUNNING$(NC)\n"; \
	else \
		printf "Authelia: $(RED)UNHEALTHY$(NC)\n"; \
	fi
	@# Portainer uses HTTPS
	@STATUS=$$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 https://localhost:9443 2>/dev/null); \
	if [ "$$STATUS" = "200" ] || [ "$$STATUS" = "303" ]; then \
		printf "Portainer: $(GREEN)OK ($$STATUS)$(NC)\n"; \
	elif [ -n "$$STATUS" ] && [ "$$STATUS" != "000" ]; then \
		printf "Portainer: $(YELLOW)$$STATUS$(NC)\n"; \
	else \
		printf "Portainer: $(RED)DOWN$(NC)\n"; \
	fi
	@echo ""

# =============================================================================
# Quick Reference
# =============================================================================

show-urls:
	@echo "=== Web UI URLs ==="
	@echo ""
	@printf "$(GREEN)Media Stack$(NC)\n"
	@echo "  Sonarr:       http://$(HOST_IP):8989"
	@echo "  Radarr:       http://$(HOST_IP):7878"
	@echo "  Lidarr:       http://$(HOST_IP):8686"
	@echo "  Prowlarr:     http://$(HOST_IP):9696"
	@echo "  Bazarr:       http://$(HOST_IP):6767"
	@echo ""
	@printf "$(GREEN)Download$(NC)\n"
	@echo "  qBittorrent:  http://$(HOST_IP):8080"
	@echo "  NZBGet:       http://$(HOST_IP):6789"
	@echo "  FlareSolverr: http://$(HOST_IP):8191"
	@echo ""
	@printf "$(GREEN)Monitoring$(NC)\n"
	@echo "  Uptime Kuma:  http://$(HOST_IP):3001"
	@echo "  Cleanuparr:   http://$(HOST_IP):11011"
	@echo "  Watchtower:   http://$(HOST_IP):8383/v1/metrics"
	@echo ""
	@printf "$(GREEN)Infrastructure$(NC)\n"
	@echo "  Pi-hole:      http://$(HOST_IP):8081/admin"
	# @echo "  Home Assist:  http://$(HOST_IP):8123"  # Disabled - see compose.homeassistant.yml
	@echo "  Portainer:    https://$(HOST_IP):9443"
	@echo "  Duplicati:    http://$(HOST_IP):8200"
	@echo "  Traefik:      https://traefik.home.local (requires DNS)"
	@echo ""
	@printf "$(GREEN)Remote Access$(NC)\n"
	@echo "  Tailscale:    https://login.tailscale.com/admin/machines"
	@echo ""
	@printf "$(GREEN)Authentication (SSO)$(NC)\n"
	@echo "  Authelia:     https://auth.home.local (requires DNS)"
	@echo ""
	@printf "$(YELLOW)Note: All services require Authelia SSO when accessed via *.home.local$(NC)\n"
	@echo ""

# Alias for show-urls
urls: show-urls
