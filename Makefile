# =============================================================================
# Makefile - Media Stack Management
# NAS QNAP TS-435XeU - Homelab
# =============================================================================

.DEFAULT_GOAL := help

.PHONY: help setup setup-dry-run up down restart logs pull update status backup backup-portainer backup-qts verify-backup clean fix-ports health show-urls urls \
        validate check-docker check-compose check-curl recyclarr-sync recyclarr-config \
        vpn-check logs-% shell-%

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

check-openssl:
	@command -v openssl >/dev/null 2>&1 || { \
		printf "$(RED)Error: openssl not found. Install openssl before continuing.$(NC)\n"; \
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
	@printf "    $(CYAN)make restart$(NC)     - Full restart (or make restart s=radarr)\n"
	@printf "    $(CYAN)make pull$(NC)        - Update Docker images\n"
	@printf "    $(CYAN)make update$(NC)      - Pull images and restart (pull + restart)\n"
	@printf "\n"
	@printf "  $(PURPLE)Monitoring$(NC)\n"
	@printf "    $(CYAN)make logs$(NC)        - Show logs (follow)\n"
	@printf "    $(CYAN)make status$(NC)      - Container status and resources\n"
	@printf "    $(CYAN)make health$(NC)      - Health check all services\n"
	@printf "    $(CYAN)make vpn-check$(NC)   - Verify VPN is working (no leaks)\n"
	@printf "    $(CYAN)make show-urls$(NC)   - Show WebUI URLs\n"
	@printf "\n"
	@printf "  $(PURPLE)Backup$(NC)\n"
	@printf "    $(CYAN)make backup$(NC)           - Trigger Duplicati backup on demand\n"
	@printf "    $(CYAN)make backup-portainer$(NC) - Snapshot portainer.db (stop/copy/start ~2s)\n"
	@printf "    $(CYAN)make backup-qts$(NC)       - Backup QNAP QTS system configuration\n"
	@printf "    $(CYAN)make verify-backup$(NC)    - Verify backup integrity (extraction + SQLite)\n"
	@printf "                         Duplicati WebUI: http://$(HOST_IP):8200\n"
	@printf "\n"
	@printf "  $(PURPLE)Utilities$(NC)\n"
	@printf "    $(CYAN)make clean$(NC)            - Remove orphan Docker resources\n"
	@printf "    $(CYAN)make fix-ports$(NC)        - Fix stale Docker port allocations\n"
	@printf "    $(CYAN)make recyclarr-sync$(NC)   - Manual Trash Guides profile sync (adopt=true to adopt existing)\n"
	@printf "    $(CYAN)make recyclarr-config$(NC) - Install Recyclarr config from template\n"
	@printf "\n"
	@printf "  $(PURPLE)Per service$(NC)\n"
	@printf "    $(CYAN)make logs-SERVICE$(NC)  - Single service logs (e.g., make logs-sonarr)\n"
	@printf "    $(CYAN)make shell-SERVICE$(NC) - Shell into container (e.g., make shell-radarr)\n"

# =============================================================================
# Setup
# =============================================================================

setup: check-compose check-openssl
	@if [ ! -f docker/.env ]; then \
		echo ">>> Creating .env from template..."; \
		cp docker/.env.example docker/.env; \
		printf "$(YELLOW)>>> Review docker/.env (PUID/PGID must match file owner of /share/data)$(NC)\n"; \
	fi
	@if [ ! -f docker/.env.secrets ]; then \
		echo ">>> Creating .env.secrets from template..."; \
		cp docker/.env.secrets.example docker/.env.secrets; \
		echo ">>> Generating secure passwords..."; \
		PIHOLE_PASS=$$(openssl rand -base64 24); \
		DUPLICATI_PASS=$$(openssl rand -base64 24); \
		ENCRYPTION_KEY=$$(openssl rand -base64 32); \
		sed -i "s|^FTLCONF_webserver_api_password=CHANGE_ME_IMMEDIATELY|FTLCONF_webserver_api_password=$$PIHOLE_PASS|" docker/.env.secrets; \
		sed -i "s|^DUPLICATI__WEBSERVICE_PASSWORD=CHANGE_ME_IMMEDIATELY|DUPLICATI__WEBSERVICE_PASSWORD=$$DUPLICATI_PASS|" docker/.env.secrets; \
		sed -i "s|^SETTINGS_ENCRYPTION_KEY=CHANGE_ME_IMMEDIATELY|SETTINGS_ENCRYPTION_KEY=$$ENCRYPTION_KEY|" docker/.env.secrets; \
		printf "$(GREEN)>>> Passwords auto-generated for: Pi-hole, Duplicati (web UI + encryption key)$(NC)\n"; \
		printf "$(YELLOW)WARNING: Review docker/.env.secrets — configure VPN credentials if needed$(NC)\n"; \
	fi
	@if [ -f docker/.env.secrets ]; then \
		chmod 600 docker/.env.secrets; \
		printf "$(GREEN)>>> docker/.env.secrets permissions set to 600 (owner-only)$(NC)\n"; \
	fi
	@echo ">>> Creating folder structure..."
	@if [ ! -x scripts/setup-folders.sh ]; then \
		chmod +x scripts/setup-folders.sh; \
	fi
	@./scripts/setup-folders.sh || printf "$(YELLOW)>>> Folder setup had errors (continuing with remaining setup)$(NC)\n"
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
	@if [ ! -x scripts/generate-certs.sh ]; then \
		chmod +x scripts/generate-certs.sh; \
	fi
	@if [ ! -f docker/config/traefik/certs/ca.crt ] || ! openssl x509 -noout -in docker/config/traefik/certs/ca.crt 2>/dev/null; then \
		echo ">>> No valid CA found — generating CA + server certificate..."; \
		./scripts/generate-certs.sh; \
	elif [ ! -f docker/config/traefik/certs/home.local.crt ] || ! openssl x509 -noout -in docker/config/traefik/certs/home.local.crt 2>/dev/null; then \
		echo ">>> CA exists but server cert is missing/invalid — regenerating server cert..."; \
		./scripts/generate-certs.sh; \
	elif ! openssl verify -CAfile docker/config/traefik/certs/ca.crt docker/config/traefik/certs/home.local.crt >/dev/null 2>&1; then \
		echo ">>> Server cert not signed by current CA — regenerating..."; \
		./scripts/generate-certs.sh; \
	else \
		printf "$(GREEN)>>> TLS certificates already exist and are valid (skipping)$(NC)\n"; \
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
	@$(COMPOSE_CMD) up -d --remove-orphans && \
		printf "$(GREEN)>>> Stack started$(NC)\n" && \
		$(MAKE) --no-print-directory status || \
		{ printf "$(RED)>>> Error starting stack$(NC)\n"; exit 1; }

down: check-compose
	@echo ">>> Stopping stack..."
	@$(COMPOSE_CMD) down --remove-orphans
	@printf "$(GREEN)>>> Stack stopped$(NC)\n"

restart: check-compose
ifdef s
	@printf ">>> Restarting $(s)...\n"
	@$(COMPOSE_CMD) stop $(s) && \
	 $(COMPOSE_CMD) up -d --force-recreate $(s) && \
		printf "$(GREEN)>>> $(s) restarted$(NC)\n" || \
		{ printf "$(RED)>>> Error restarting $(s)$(NC)\n"; exit 1; }
else
	@$(MAKE) --no-print-directory down
	@$(MAKE) --no-print-directory up
endif

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

backup: check-docker check-curl backup-portainer
	@echo ">>> Triggering Duplicati backup..."
	@if docker ps --format '{{.Names}}' | grep -q '^duplicati$$'; then \
		PASS=$$(grep '^DUPLICATI__WEBSERVICE_PASSWORD=' docker/.env.secrets 2>/dev/null | cut -d= -f2-); \
		if [ -z "$$PASS" ]; then \
			printf "$(RED)Error: DUPLICATI__WEBSERVICE_PASSWORD not found in docker/.env.secrets$(NC)\n"; \
			exit 1; \
		fi; \
		PASS_ESC=$$(printf '%s' "$$PASS" | sed 's/[\\"]/\\&/g'); \
		TOKEN=$$(curl -sf -X POST http://localhost:8200/api/v1/auth/login \
			-H "Content-Type: application/json" \
			-d "{\"password\":\"$$PASS_ESC\"}" \
			| grep -o '"AccessToken":"[^"]*"' | cut -d'"' -f4); \
		if [ -z "$$TOKEN" ]; then \
			printf "$(RED)Error: Duplicati login failed (check password or container health)$(NC)\n"; \
			exit 1; \
		fi; \
		BACKUP_IDS=$$(curl -sf http://localhost:8200/api/v1/backups \
			-H "Authorization: Bearer $$TOKEN" \
			| grep -o '"ID":"[^"]*"' | cut -d'"' -f4); \
		if [ -z "$$BACKUP_IDS" ]; then \
			printf "$(YELLOW)No backup job configured yet$(NC)\n"; \
			echo "Configure backup via http://$(HOST_IP):8200"; \
		else \
			for ID in $$BACKUP_IDS; do \
				curl -sf -X POST "http://localhost:8200/api/v1/backup/$$ID/run" \
					-H "Authorization: Bearer $$TOKEN" >/dev/null && \
				printf "$(GREEN)>>> Backup queued (ID: $$ID)$(NC)\n"; \
			done; \
			echo "Monitor progress at http://$(HOST_IP):8200"; \
		fi; \
	else \
		printf "$(RED)Error: duplicati container not running$(NC)\n"; \
		echo "Run 'make up' first"; \
		exit 1; \
	fi

backup-portainer: check-docker
	@if [ ! -x scripts/backup-portainer-db.sh ]; then \
		chmod +x scripts/backup-portainer-db.sh; \
	fi
	@./scripts/backup-portainer-db.sh --verbose

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
	@export QNAP_ADMIN_USER=$$(grep '^QNAP_ADMIN_USER=' docker/.env.secrets 2>/dev/null | cut -d= -f2-); \
	export QNAP_ADMIN_PASSWORD=$$(grep '^QNAP_ADMIN_PASSWORD=' docker/.env.secrets 2>/dev/null | cut -d= -f2-); \
	./scripts/backup-qts-config.sh --verbose

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

fix-ports: check-docker
	@echo ">>> Checking for port conflicts..."
	@stale=$$(docker ps -a --filter "status=exited" --filter "status=dead" --filter "status=created" -q); \
	if [ -n "$$stale" ]; then \
		printf "$(YELLOW)>>> Removing stale containers...$(NC)\n"; \
		docker rm -f $$stale; \
	else \
		echo ">>> No stale containers found"; \
	fi
	@docker network prune -f >/dev/null 2>&1 && \
		echo ">>> Pruned unused networks" || true
	@printf "$(GREEN)>>> Port cleanup complete. Try 'make up' now.$(NC)\n"
	@printf "$(YELLOW)>>> If ports are still stuck, restart Docker: systemctl restart docker$(NC)\n"

# =============================================================================
# Recyclarr
# =============================================================================

recyclarr-sync: check-compose
	@echo ">>> Syncing Trash Guides quality profiles..."
	@if docker ps --format '{{.Names}}' | grep -q '^recyclarr$$'; then \
		if [ "$(adopt)" = "true" ]; then \
			echo ">>> Adopting existing profiles..."; \
			docker exec recyclarr recyclarr state repair --adopt && \
			printf "$(GREEN)>>> Adopt complete$(NC)\n"; \
		fi; \
		docker exec recyclarr recyclarr sync && \
		printf "$(GREEN)>>> Sync complete$(NC)\n"; \
	else \
		printf "$(RED)Error: recyclarr container not running$(NC)\n"; \
		echo "Run 'make up' before syncing"; \
		exit 1; \
	fi

recyclarr-config: check-compose
	@echo ">>> Installing Recyclarr configuration..."
	@docker cp docker/recyclarr.yml recyclarr:/config/recyclarr.yml
	@printf "$(GREEN)>>> Configuration installed to docker/config/recyclarr/recyclarr.yml$(NC)\n"
	@printf "$(YELLOW)>>> Remember to set SONARR_API_KEY and RADARR_API_KEY in docker/.env.secrets$(NC)\n"

# =============================================================================
# Health Check
# =============================================================================

define check_service
	@STATUS=$$(curl -sLk -o /dev/null -w '%{http_code}' --max-time 5 $(1) 2>/dev/null); \
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
		PROFILE=$$(grep -s '^COMPOSE_PROFILES=' docker/.env | cut -d= -f2); \
		if [ "$$PROFILE" = "novpn" ]; then \
			printf "Gluetun: $(YELLOW)DISABLED (novpn profile)$(NC)\n"; \
		else \
			printf "Gluetun: $(RED)NOT RUNNING (vpn profile active — should be running)$(NC)\n"; \
		fi; \
	fi
	$(call check_service,http://localhost:8080,qBittorrent)
	$(call check_service,http://localhost:6789,NZBGet)
	$(call check_service,http://localhost:11011/health,Cleanuparr)
	$(call check_service,http://localhost:32400/identity,Plex-Music)
	$(call check_service,http://localhost:8191/health,FlareSolverr)
	$(call check_service,http://localhost:8081/admin/,Pi-hole)
	@# Home Assistant uses network_mode: host (no Docker network)
	@if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^homeassistant$$'; then \
		STATUS=$$(curl -sLk -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:8123/manifest.json 2>/dev/null); \
		if [ "$$STATUS" = "200" ]; then \
			printf "HomeAssistant: $(GREEN)OK ($$STATUS)$(NC)\n"; \
		elif [ -n "$$STATUS" ] && [ "$$STATUS" != "000" ]; then \
			printf "HomeAssistant: $(YELLOW)$$STATUS$(NC)\n"; \
		else \
			printf "HomeAssistant: $(RED)DOWN$(NC)\n"; \
		fi; \
	else \
		printf "HomeAssistant: $(YELLOW)NOT RUNNING$(NC)\n"; \
	fi
	$(call check_service,http://localhost:8200,Duplicati)
	$(call check_service,http://localhost:3001,UptimeKuma)
	$(call check_service,http://localhost:8383/v1/metrics,Watchtower)
	@# Traefik health check (uses Docker healthcheck via --ping=true)
	@HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' traefik 2>/dev/null); \
	if [ "$$HEALTH" = "healthy" ]; then \
		printf "Traefik: $(GREEN)OK (healthy)$(NC)\n"; \
	elif [ "$$HEALTH" = "starting" ]; then \
		printf "Traefik: $(YELLOW)STARTING$(NC)\n"; \
	elif [ -z "$$HEALTH" ]; then \
		printf "Traefik: $(YELLOW)NOT RUNNING$(NC)\n"; \
	else \
		printf "Traefik: $(RED)UNHEALTHY$(NC)\n"; \
	fi
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
	@# Cert download page (no host port — Traefik only)
	@if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^cert-page$$'; then \
		HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' cert-page 2>/dev/null); \
		if [ "$$HEALTH" = "healthy" ]; then \
			printf "Cert-Page: $(GREEN)OK (healthy)$(NC)\n"; \
		elif [ "$$HEALTH" = "starting" ]; then \
			printf "Cert-Page: $(YELLOW)STARTING$(NC)\n"; \
		else \
			printf "Cert-Page: $(RED)UNHEALTHY$(NC)\n"; \
		fi; \
	else \
		printf "Cert-Page: $(YELLOW)NOT RUNNING$(NC)\n"; \
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
	@echo "  Plex Music:   http://$(HOST_IP):32400"
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
	@echo "  Home Assist:  http://$(HOST_IP):8123"
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
	@printf "$(GREEN)Utilities$(NC)\n"
	@echo "  Cert Page:    https://certs.home.local (CA cert download)"
	@echo ""
	@printf "$(YELLOW)Note: All services require Authelia SSO via *.home.local (except certs.home.local)$(NC)\n"
	@echo ""

# Alias for show-urls
urls: show-urls

# =============================================================================
# VPN Verification
# =============================================================================

vpn-check: check-docker check-curl
	@echo "=== VPN Leak Check ==="
	@echo ""
	@FAIL=0; \
	PROFILE=$$(grep -s '^COMPOSE_PROFILES=' docker/.env | cut -d= -f2); \
	if ! echo "$$PROFILE" | grep -q 'vpn' || echo "$$PROFILE" | grep -q 'novpn'; then \
		printf "$(YELLOW)VPN profile not active (COMPOSE_PROFILES=%s)$(NC)\n" "$$PROFILE"; \
		printf "$(YELLOW)Set COMPOSE_PROFILES=vpn in docker/.env to use VPN$(NC)\n"; \
		exit 0; \
	fi; \
	printf "Profile: $(GREEN)vpn$(NC)\n"; \
	\
	if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^gluetun$$'; then \
		printf "Gluetun: $(RED)NOT RUNNING — skipping all checks$(NC)\n"; \
		printf "\n$(RED)$(BOLD)=== SOME CHECKS FAILED ===$(NC)\n\n"; \
		exit 1; \
	fi; \
	HEALTH=$$(docker inspect --format='{{.State.Health.Status}}' gluetun 2>/dev/null); \
	if [ "$$HEALTH" = "healthy" ]; then \
		printf "Gluetun: $(GREEN)healthy$(NC)\n"; \
	else \
		printf "Gluetun: $(RED)%s$(NC)\n" "$$HEALTH"; \
		FAIL=1; \
	fi; \
	\
	printf "\n--- IP Leak Test ---\n"; \
	HOST_PUBLIC_IP=$$(curl -s --max-time 10 https://ipinfo.io/ip 2>/dev/null); \
	VPN_IP=$$(docker exec gluetun wget -qO- --timeout=10 https://ipinfo.io/ip 2>/dev/null); \
	if [ -z "$$HOST_PUBLIC_IP" ]; then \
		printf "Host public IP:    $(YELLOW)could not determine (offline?)$(NC)\n"; \
	else \
		printf "Host public IP:    %s\n" "$$HOST_PUBLIC_IP"; \
	fi; \
	if [ -z "$$VPN_IP" ]; then \
		printf "Gluetun tunnel IP: $(RED)no connectivity through VPN$(NC)\n"; \
		FAIL=1; \
	else \
		printf "Gluetun tunnel IP: %s\n" "$$VPN_IP"; \
	fi; \
	if [ -n "$$HOST_PUBLIC_IP" ] && [ -n "$$VPN_IP" ]; then \
		if [ "$$HOST_PUBLIC_IP" = "$$VPN_IP" ]; then \
			printf "Result: $(RED)FAIL — same IP! Traffic is NOT tunneled$(NC)\n"; \
			FAIL=1; \
		else \
			printf "Result: $(GREEN)PASS — IPs differ, traffic is tunneled$(NC)\n"; \
		fi; \
	fi; \
	\
	printf "\n--- IPv6 Leak Test ---\n"; \
	IPV6_RESULT=$$(docker exec gluetun wget -qO- --timeout=5 https://api64.ipify.org 2>/dev/null); \
	if [ -n "$$IPV6_RESULT" ] && echo "$$IPV6_RESULT" | grep -q ':'; then \
		printf "IPv6: $(RED)FAIL — IPv6 reachable: %s$(NC)\n" "$$IPV6_RESULT"; \
		FAIL=1; \
	elif [ -n "$$IPV6_RESULT" ]; then \
		printf "IPv6: $(GREEN)PASS — only IPv4 detected (%s)$(NC)\n" "$$IPV6_RESULT"; \
	else \
		printf "IPv6: $(GREEN)PASS — no IPv6 connectivity$(NC)\n"; \
	fi; \
	\
	printf "\n--- DNS Leak Test ---\n"; \
	DNS_SERVERS=$$(docker exec gluetun cat /etc/resolv.conf 2>/dev/null | grep '^nameserver' | awk '{print $$2}'); \
	if [ -n "$$DNS_SERVERS" ]; then \
		printf "DNS resolvers: %s\n" "$$DNS_SERVERS"; \
		printf "$(YELLOW)Verify these are NOT your ISP's DNS servers$(NC)\n"; \
	else \
		printf "DNS: $(YELLOW)could not read /etc/resolv.conf$(NC)\n"; \
	fi; \
	\
	printf "\n--- Port Forwarding ---\n"; \
	FWD_PORT=$$(docker exec gluetun cat /gluetun/forwarded_port 2>/dev/null); \
	if [ -n "$$FWD_PORT" ] && [ "$$FWD_PORT" != "0" ]; then \
		printf "Forwarded port: $(GREEN)%s$(NC)\n" "$$FWD_PORT"; \
	else \
		printf "Forwarded port: $(YELLOW)none (provider may not support it)$(NC)\n"; \
	fi; \
	\
	printf "\n--- Kill Switch ---\n"; \
	VPN_DEPENDENTS="qbittorrent nzbget"; \
	RUNNING_DEPS=""; \
	for dep in $$VPN_DEPENDENTS; do \
		if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$${dep}$$"; then \
			RUNNING_DEPS="$$RUNNING_DEPS $$dep"; \
		fi; \
	done; \
	docker exec gluetun ip link set tun0 down 2>/dev/null; \
	KSTEST=$$(docker exec gluetun wget -O- --timeout=5 https://ipinfo.io/ip 2>&1); \
	KSRC=$$?; \
	docker restart gluetun >/dev/null 2>&1; \
	if [ -n "$$RUNNING_DEPS" ]; then \
		printf "Waiting for gluetun to be healthy...\n"; \
		WAIT=0; \
		while [ $$WAIT -lt 60 ]; do \
			GSTATUS=$$(docker inspect --format='{{.State.Health.Status}}' gluetun 2>/dev/null); \
			if [ "$$GSTATUS" = "healthy" ]; then break; fi; \
			sleep 2; \
			WAIT=$$((WAIT + 2)); \
		done; \
		if [ "$$GSTATUS" = "healthy" ]; then \
			printf "Restarting VPN dependents:%s\n" "$$RUNNING_DEPS"; \
			for dep in $$RUNNING_DEPS; do \
				docker restart $$dep >/dev/null 2>&1; \
			done; \
		else \
			printf "$(YELLOW)Gluetun not healthy after 60s — skipping dependent restart$(NC)\n"; \
		fi; \
	fi; \
	if [ $$KSRC -ne 0 ] && ! echo "$$KSTEST" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$$'; then \
		printf "Kill switch: $(GREEN)PASS — traffic blocked when tunnel is down$(NC)\n"; \
	else \
		printf "Kill switch: $(RED)FAIL — traffic leaked: %s$(NC)\n" "$$KSTEST"; \
		FAIL=1; \
	fi; \
	\
	echo ""; \
	if [ "$$FAIL" -eq 0 ]; then \
		printf "$(GREEN)$(BOLD)=== ALL CHECKS PASSED ===$(NC)\n"; \
	else \
		printf "$(RED)$(BOLD)=== SOME CHECKS FAILED ===$(NC)\n"; \
		exit 1; \
	fi; \
	echo ""
