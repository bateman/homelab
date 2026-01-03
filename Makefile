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

# Colori per output (se terminale supporta)
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

# =============================================================================
# Validazione
# =============================================================================

check-docker:
	@command -v docker >/dev/null 2>&1 || { \
		echo "$(RED)Errore: docker non trovato. Installa Docker prima di continuare.$(NC)"; \
		exit 1; \
	}

check-compose: check-docker
	@docker compose version >/dev/null 2>&1 || { \
		echo "$(RED)Errore: docker compose non disponibile. Serve Docker Compose v2.$(NC)"; \
		exit 1; \
	}

validate: check-compose
	@echo ">>> Validazione configurazione..."
	@$(COMPOSE_CMD) config --quiet && \
		echo "$(GREEN)Configurazione valida$(NC)" || { \
		echo "$(RED)Errore nella configurazione compose$(NC)"; \
		exit 1; \
	}

# =============================================================================
# Help
# =============================================================================

help:
	@echo "Media Stack - Comandi disponibili:"
	@echo ""
	@echo "  $(GREEN)Setup & Validazione$(NC)"
	@echo "    make setup       - Crea struttura cartelle (run once)"
	@echo "    make validate    - Verifica configurazione compose"
	@echo ""
	@echo "  $(GREEN)Gestione Container$(NC)"
	@echo "    make up          - Avvia tutti i container"
	@echo "    make down        - Ferma tutti i container"
	@echo "    make restart     - Restart completo"
	@echo "    make pull        - Aggiorna immagini Docker"
	@echo ""
	@echo "  $(GREEN)Monitoring$(NC)"
	@echo "    make logs        - Mostra logs (follow)"
	@echo "    make status      - Stato container e risorse"
	@echo "    make health      - Health check tutti i servizi"
	@echo "    make urls        - Mostra URL WebUI"
	@echo ""
	@echo "  $(GREEN)Utilities$(NC)"
	@echo "    make backup      - Backup configurazioni"
	@echo "    make clean       - Rimuove risorse Docker orfane"
	@echo "    make recyclarr-sync   - Sync manuale profili Trash Guides"
	@echo "    make recyclarr-config - Genera config Recyclarr template"
	@echo ""
	@echo "  $(GREEN)Per servizio$(NC)"
	@echo "    make logs-SERVICE  - Logs singolo servizio (es: make logs-sonarr)"
	@echo "    make shell-SERVICE - Shell nel container (es: make shell-radarr)"

# =============================================================================
# Setup
# =============================================================================

setup: check-compose
	@echo ">>> Creazione struttura cartelle..."
	@if [ ! -x setup-folders.sh ]; then \
		chmod +x setup-folders.sh; \
	fi
	@./setup-folders.sh
	@echo ">>> Creazione directory config/recyclarr..."
	@mkdir -p ./config/recyclarr
	@if [ ! -f .env ]; then \
		echo ">>> Creazione .env da template..."; \
		cp .env.example .env 2>/dev/null || echo "PIHOLE_PASSWORD=changeme" > .env; \
		echo "$(YELLOW)ATTENZIONE: Modifica .env con le tue password$(NC)"; \
	fi
	@echo "$(GREEN)>>> Setup completato$(NC)"

# =============================================================================
# Container Management
# =============================================================================

up: validate
	@echo ">>> Avvio stack..."
	@$(COMPOSE_CMD) up -d
	@if [ $$? -eq 0 ]; then \
		echo "$(GREEN)>>> Stack avviato$(NC)"; \
		$(MAKE) --no-print-directory status; \
	else \
		echo "$(RED)>>> Errore durante l'avvio dello stack$(NC)"; \
		exit 1; \
	fi

down: check-compose
	@echo ">>> Arresto stack..."
	@$(COMPOSE_CMD) down
	@echo "$(GREEN)>>> Stack arrestato$(NC)"

restart: down up

pull: check-compose
	@echo ">>> Pull immagini aggiornate..."
	@$(COMPOSE_CMD) pull
	@if [ $$? -eq 0 ]; then \
		echo "$(GREEN)>>> Pull completato. Esegui 'make restart' per applicare$(NC)"; \
	else \
		echo "$(RED)>>> Errore durante il pull delle immagini$(NC)"; \
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
		echo "$(YELLOW)Nessun container in esecuzione$(NC)"; \
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
		echo "$(RED)Errore: impossibile aprire shell in $*$(NC)"; \
		exit 1; \
	}

backup: check-docker
	@echo ">>> Backup configurazioni..."
	@mkdir -p $(BACKUP_DIR)
	@if [ ! -d ./config ]; then \
		echo "$(RED)Errore: directory config non trovata$(NC)"; \
		exit 1; \
	fi
	@BACKUP_NAME="config-backup-$$(date +%Y%m%d-%H%M%S).tar.gz"; \
	if tar -czf "$(BACKUP_DIR)/$$BACKUP_NAME" ./config; then \
		echo "$(GREEN)>>> Backup creato: $(BACKUP_DIR)/$$BACKUP_NAME$(NC)"; \
		ls -lh "$(BACKUP_DIR)/$$BACKUP_NAME"; \
	else \
		echo "$(RED)>>> Errore durante la creazione del backup$(NC)"; \
		exit 1; \
	fi

clean: check-docker
	@echo ">>> Pulizia risorse Docker orfane..."
	@echo "$(YELLOW)ATTENZIONE: Questa operazione rimuove container, immagini e volumi non utilizzati$(NC)"
	@read -p "Continuare? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker system prune -f && docker volume prune -f; \
		echo "$(GREEN)>>> Pulizia completata$(NC)"; \
	else \
		echo ">>> Operazione annullata"; \
	fi

# =============================================================================
# Recyclarr
# =============================================================================

recyclarr-sync: check-compose
	@echo ">>> Sync profili qualita' Trash Guides..."
	@if docker ps --format '{{.Names}}' | grep -q '^recyclarr$$'; then \
		docker exec recyclarr recyclarr sync && \
		echo "$(GREEN)>>> Sync completato$(NC)"; \
	else \
		echo "$(RED)Errore: container recyclarr non in esecuzione$(NC)"; \
		echo "Esegui 'make up' prima di sincronizzare"; \
		exit 1; \
	fi

recyclarr-config: check-compose
	@echo ">>> Generazione template configurazione Recyclarr..."
	@if docker ps --format '{{.Names}}' | grep -q '^recyclarr$$'; then \
		docker exec recyclarr recyclarr config create && \
		echo "$(GREEN)>>> Template creato in ./config/recyclarr/$(NC)"; \
	else \
		echo "$(RED)Errore: container recyclarr non in esecuzione$(NC)"; \
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
	@# Portainer usa HTTPS
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
	@echo ""
