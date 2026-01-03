# =============================================================================
# Makefile - Media Stack Management
# NAS QNAP TS-435XeU - Homelab
# =============================================================================

.PHONY: help setup up down restart logs pull status backup clean

COMPOSE_FILE := docker-compose.yml
BACKUP_DIR := ./backups

# Default target
help:
	@echo "Media Stack - Comandi disponibili:"
	@echo ""
	@echo "  make setup     - Crea struttura cartelle (run once)"
	@echo "  make up        - Avvia tutti i container"
	@echo "  make down      - Ferma tutti i container"
	@echo "  make restart   - Restart completo"
	@echo "  make pull      - Aggiorna immagini Docker"
	@echo "  make logs      - Mostra logs (follow)"
	@echo "  make status    - Stato container e risorse"
	@echo "  make backup    - Backup configurazioni"
	@echo "  make clean     - Rimuove container e volumi orfani"
	@echo ""
	@echo "  make logs-SERVICE  - Logs singolo servizio (es: make logs-sonarr)"
	@echo "  make shell-SERVICE - Shell nel container (es: make shell-radarr)"

# =============================================================================
# Setup
# =============================================================================

setup:
	@echo ">>> Creazione struttura cartelle..."
	@chmod +x setup-folders.sh
	@./setup-folders.sh
	@echo ">>> Setup completato"

# =============================================================================
# Container Management
# =============================================================================

up:
	@echo ">>> Avvio stack..."
	docker compose -f $(COMPOSE_FILE) up -d
	@echo ">>> Stack avviato"
	@$(MAKE) status

down:
	@echo ">>> Arresto stack..."
	docker compose -f $(COMPOSE_FILE) down
	@echo ">>> Stack arrestato"

restart: down up

pull:
	@echo ">>> Pull immagini aggiornate..."
	docker compose -f $(COMPOSE_FILE) pull
	@echo ">>> Pull completato. Esegui 'make restart' per applicare"

# =============================================================================
# Monitoring
# =============================================================================

logs:
	docker compose -f $(COMPOSE_FILE) logs -f --tail=100

logs-%:
	docker compose -f $(COMPOSE_FILE) logs -f --tail=100 $*

status:
	@echo ""
	@echo "=== Container Status ==="
	@docker compose -f $(COMPOSE_FILE) ps
	@echo ""
	@echo "=== Resource Usage ==="
	@docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
		$$(docker compose -f $(COMPOSE_FILE) ps -q) 2>/dev/null || true
	@echo ""
	@echo "=== Disk Usage ==="
	@df -h /share/data 2>/dev/null || df -h . | head -2

# =============================================================================
# Utilities
# =============================================================================

shell-%:
	docker compose -f $(COMPOSE_FILE) exec $* /bin/bash || \
	docker compose -f $(COMPOSE_FILE) exec $* /bin/sh

backup:
	@echo ">>> Backup configurazioni..."
	@mkdir -p $(BACKUP_DIR)
	@BACKUP_NAME="config-backup-$$(date +%Y%m%d-%H%M%S).tar.gz"; \
	tar -czf "$(BACKUP_DIR)/$$BACKUP_NAME" ./config && \
	echo ">>> Backup creato: $(BACKUP_DIR)/$$BACKUP_NAME"

clean:
	@echo ">>> Pulizia risorse Docker orfane..."
	docker system prune -f
	docker volume prune -f
	@echo ">>> Pulizia completata"

# =============================================================================
# Health Check
# =============================================================================

health:
	@echo "=== Health Check ==="
	@echo ""
	@echo "Sonarr:      $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8989/ping 2>/dev/null || echo 'DOWN')"
	@echo "Radarr:      $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:7878/ping 2>/dev/null || echo 'DOWN')"
	@echo "Lidarr:      $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8686/ping 2>/dev/null || echo 'DOWN')"
	@echo "Prowlarr:    $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:9696/ping 2>/dev/null || echo 'DOWN')"
	@echo "qBittorrent: $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080 2>/dev/null || echo 'DOWN')"
	@echo "NZBGet:      $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:6789 2>/dev/null || echo 'DOWN')"
	@echo "Bazarr:      $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:6767/api 2>/dev/null || echo 'DOWN')"
	@echo "Cleanuparr:  $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:11011/health 2>/dev/null || echo 'DOWN')"
	@echo "Pi-hole:     $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8081/admin 2>/dev/null || echo 'DOWN')"
	@echo "Portainer:   $$(curl -sk -o /dev/null -w '%{http_code}' https://localhost:9443 2>/dev/null || echo 'DOWN')"

# =============================================================================
# Quick Reference
# =============================================================================

urls:
	@echo "=== Web UI URLs ==="
	@echo ""
	@echo "Sonarr:       http://192.168.3.10:8989"
	@echo "Radarr:       http://192.168.3.10:7878"
	@echo "Lidarr:       http://192.168.3.10:8686"
	@echo "Prowlarr:     http://192.168.3.10:9696"
	@echo "Bazarr:       http://192.168.3.10:6767"
	@echo "qBittorrent:  http://192.168.3.10:8080"
	@echo "NZBGet:       http://192.168.3.10:6789"
	@echo "Huntarr:      http://192.168.3.10:7500"
	@echo "Cleanuparr:   http://192.168.3.10:11011"
	@echo "Pi-hole:      http://192.168.3.10:8081/admin"
	@echo "Home Assist:  http://192.168.3.10:8123"
	@echo "Portainer:    https://192.168.3.10:9443"
