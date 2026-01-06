#!/bin/bash
# =============================================================================
# verify-backup.sh - Automated Backup Integrity Verification
# Homelab - NAS QNAP TS-435XeU
#
# Verifica che i backup siano estraibili e i database SQLite leggibili.
# Eseguire settimanalmente via cron per rilevare corruzioni prima del disaster.
#
# Usage:
#   ./scripts/verify-backup.sh              # Verifica backup piu' recente
#   ./scripts/verify-backup.sh --notify     # Con notifica Home Assistant
#   ./scripts/verify-backup.sh --verbose    # Output dettagliato
#
# Exit codes:
#   0 - Verifica OK
#   1 - Errori rilevati
#   2 - Nessun backup trovato
#
# Cron example (domenica alle 05:00):
#   0 5 * * 0 /path/to/scripts/verify-backup.sh --notify >> /var/log/verify-backup.log 2>&1
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

BACKUP_DIR="${BACKUP_DIR:-/share/backup}"
BACKUP_PATTERN="docker-config-*.tar.gz"
HA_WEBHOOK_URL="${HA_WEBHOOK_URL:-}"  # Set in environment or .env.secrets

# Databases to verify (path relative to config/)
SQLITE_DATABASES=(
    "sonarr/sonarr.db"
    "radarr/radarr.db"
    "lidarr/lidarr.db"
    "prowlarr/prowlarr.main.db"
    "bazarr/db/bazarr.db"
)

# Colors (disabled if not terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# -----------------------------------------------------------------------------
# Parse Arguments
# -----------------------------------------------------------------------------

VERBOSE=false
NOTIFY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --notify|-n)
            NOTIFY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--verbose] [--notify]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v    Output dettagliato"
            echo "  --notify, -n     Invia notifica a Home Assistant se fallisce"
            echo ""
            echo "Environment:"
            echo "  BACKUP_DIR       Directory backup (default: /share/backup)"
            echo "  HA_WEBHOOK_URL   URL webhook Home Assistant per notifiche"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        log "$1"
    fi
}

notify_ha() {
    local message="$1"
    local level="${2:-warning}"  # info, warning, error

    if [ "$NOTIFY" = true ] && [ -n "$HA_WEBHOOK_URL" ]; then
        curl -s -X POST "$HA_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"message\": \"$message\", \"level\": \"$level\"}" \
            >/dev/null 2>&1 || true
        log_verbose "Notifica inviata a Home Assistant"
    fi
}

cleanup() {
    if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log_verbose "Cleanup: rimossa directory temporanea"
    fi
}

trap cleanup EXIT

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

log "${CYAN}=== Verifica Integrità Backup ===${NC}"
log ""

ERRORS=0
WARNINGS=0

# Find latest backup
if [ ! -d "$BACKUP_DIR" ]; then
    log "${RED}ERRORE: Directory backup non trovata: $BACKUP_DIR${NC}"
    notify_ha "Backup verification failed: directory not found" "error"
    exit 2
fi

LATEST=$(find "$BACKUP_DIR" -name "$BACKUP_PATTERN" -type f 2>/dev/null | sort -r | head -1)

if [ -z "$LATEST" ]; then
    log "${RED}ERRORE: Nessun backup trovato in $BACKUP_DIR${NC}"
    notify_ha "Backup verification failed: no backup files found" "error"
    exit 2
fi

BACKUP_DATE=$(stat -c %y "$LATEST" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm -t %Y-%m-%d "$LATEST" 2>/dev/null || echo "unknown")
BACKUP_SIZE=$(du -h "$LATEST" | cut -f1)

log "Backup: ${CYAN}$(basename "$LATEST")${NC}"
log "Data: $BACKUP_DATE | Size: $BACKUP_SIZE"
log ""

# Check backup age (warn if older than 7 days)
BACKUP_AGE_DAYS=$(( ($(date +%s) - $(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null || echo 0)) / 86400 ))
if [ "$BACKUP_AGE_DAYS" -gt 7 ]; then
    log "${YELLOW}WARNING: Backup vecchio di $BACKUP_AGE_DAYS giorni${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
log_verbose "Directory temporanea: $TEMP_DIR"

# Test 1: Archive extraction
log "1. Test estrazione archivio..."
if tar -tzf "$LATEST" >/dev/null 2>&1; then
    log "   ${GREEN}✓ Archivio integro${NC}"
else
    log "   ${RED}✗ ERRORE: Archivio corrotto o non estraibile${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Test 2: Full extraction to temp
log "2. Estrazione completa..."
if tar -xzf "$LATEST" -C "$TEMP_DIR" 2>/dev/null; then
    log "   ${GREEN}✓ Estrazione completata${NC}"

    # Count extracted files
    FILE_COUNT=$(find "$TEMP_DIR" -type f | wc -l)
    log_verbose "   File estratti: $FILE_COUNT"
else
    log "   ${RED}✗ ERRORE: Impossibile estrarre${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Test 3: SQLite database integrity
log "3. Verifica database SQLite..."

# Check if sqlite3 is available
if ! command -v sqlite3 >/dev/null 2>&1; then
    log "   ${YELLOW}⚠ sqlite3 non disponibile, skip verifica DB${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    for db_path in "${SQLITE_DATABASES[@]}"; do
        db_name=$(dirname "$db_path" | cut -d'/' -f1)

        # Try to find the database (structure may vary)
        db_file=""
        for prefix in "config" ""; do
            test_path="$TEMP_DIR/$prefix/$db_path"
            if [ -f "$test_path" ]; then
                db_file="$test_path"
                break
            fi
        done

        if [ -z "$db_file" ]; then
            log_verbose "   - $db_name: non trovato (potrebbe essere normale)"
            continue
        fi

        # Integrity check
        if sqlite3 "$db_file" "PRAGMA integrity_check;" 2>/dev/null | grep -q "^ok$"; then
            log "   ${GREEN}✓ $db_name: OK${NC}"
        else
            log "   ${RED}✗ $db_name: CORROTTO${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    done
fi

# Test 4: Check critical files exist
log "4. Verifica file critici..."

CRITICAL_FILES=(
    "traefik/tls.yml"
    "traefik/homeassistant.yml"
)

for cf in "${CRITICAL_FILES[@]}"; do
    found=false
    for prefix in "config" ""; do
        if [ -f "$TEMP_DIR/$prefix/$cf" ]; then
            found=true
            break
        fi
    done

    if [ "$found" = true ]; then
        log_verbose "   ✓ $cf"
    else
        log_verbose "   - $cf: non trovato"
    fi
done

log ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

if [ $ERRORS -gt 0 ]; then
    log "${RED}=== VERIFICA FALLITA ===${NC}"
    log "${RED}Errori: $ERRORS | Warning: $WARNINGS${NC}"
    log ""
    log "Azione richiesta: verificare manualmente il backup o eseguire nuovo backup"
    notify_ha "Backup verification FAILED: $ERRORS errors, $WARNINGS warnings" "error"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    log "${YELLOW}=== VERIFICA OK CON WARNING ===${NC}"
    log "${YELLOW}Warning: $WARNINGS${NC}"
    notify_ha "Backup verification passed with $WARNINGS warnings" "warning"
    exit 0
else
    log "${GREEN}=== VERIFICA OK ===${NC}"
    log "${GREEN}Backup integro e verificato${NC}"
    exit 0
fi
