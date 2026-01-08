#!/bin/bash
# =============================================================================
# verify-backup.sh - Automated Backup Integrity Verification
# Homelab - NAS QNAP TS-435XeU
#
# Verifies that backups are extractable and SQLite databases are readable.
# Run weekly via cron to detect corruptions before disaster strikes.
#
# Usage:
#   ./scripts/verify-backup.sh              # Verify most recent backup
#   ./scripts/verify-backup.sh --notify     # With Home Assistant notification
#   ./scripts/verify-backup.sh --verbose    # Detailed output
#
# Exit codes:
#   0 - Verification OK
#   1 - Errors detected
#   2 - No backup found
#
# Cron example (Sunday at 05:00):
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
            echo "  --verbose, -v    Detailed output"
            echo "  --notify, -n     Send notification to Home Assistant on failure"
            echo ""
            echo "Environment:"
            echo "  BACKUP_DIR       Backup directory (default: /share/backup)"
            echo "  HA_WEBHOOK_URL   Home Assistant webhook URL for notifications"
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
        log_verbose "Notification sent to Home Assistant"
    fi
}

cleanup() {
    if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log_verbose "Cleanup: removed temporary directory"
    fi
}

trap cleanup EXIT

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

log "${CYAN}=== Backup Integrity Verification ===${NC}"
log ""

ERRORS=0
WARNINGS=0

# Find latest backup
if [ ! -d "$BACKUP_DIR" ]; then
    log "${RED}ERROR: Backup directory not found: $BACKUP_DIR${NC}"
    notify_ha "Backup verification failed: directory not found" "error"
    exit 2
fi

LATEST=$(find "$BACKUP_DIR" -name "$BACKUP_PATTERN" -type f 2>/dev/null | sort -r | head -1)

if [ -z "$LATEST" ]; then
    log "${RED}ERROR: No backup found in $BACKUP_DIR${NC}"
    notify_ha "Backup verification failed: no backup files found" "error"
    exit 2
fi

BACKUP_DATE=$(stat -c %y "$LATEST" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm -t %Y-%m-%d "$LATEST" 2>/dev/null || echo "unknown")
BACKUP_SIZE=$(du -h "$LATEST" | cut -f1)

log "Backup: ${CYAN}$(basename "$LATEST")${NC}"
log "Date: $BACKUP_DATE | Size: $BACKUP_SIZE"
log ""

# Check backup age (warn if older than 7 days)
BACKUP_AGE_DAYS=$(( ($(date +%s) - $(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null || echo 0)) / 86400 ))
if [ "$BACKUP_AGE_DAYS" -gt 7 ]; then
    log "${YELLOW}WARNING: Backup is $BACKUP_AGE_DAYS days old${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
log_verbose "Temporary directory: $TEMP_DIR"

# Test 1: Archive extraction
log "1. Testing archive extraction..."
if tar -tzf "$LATEST" >/dev/null 2>&1; then
    log "   ${GREEN}✓ Archive intact${NC}"
else
    log "   ${RED}✗ ERROR: Archive corrupted or not extractable${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Test 2: Full extraction to temp
log "2. Full extraction..."
if tar -xzf "$LATEST" -C "$TEMP_DIR" 2>/dev/null; then
    log "   ${GREEN}✓ Extraction completed${NC}"

    # Count extracted files
    FILE_COUNT=$(find "$TEMP_DIR" -type f | wc -l)
    log_verbose "   Files extracted: $FILE_COUNT"
else
    log "   ${RED}✗ ERROR: Unable to extract${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Test 3: SQLite database integrity
log "3. Verifying SQLite databases..."

# Check if sqlite3 is available
if ! command -v sqlite3 >/dev/null 2>&1; then
    log "   ${YELLOW}⚠ sqlite3 not available, skipping DB verification${NC}"
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
            log_verbose "   - $db_name: not found (may be normal)"
            continue
        fi

        # Integrity check
        if sqlite3 "$db_file" "PRAGMA integrity_check;" 2>/dev/null | grep -q "^ok$"; then
            log "   ${GREEN}✓ $db_name: OK${NC}"
        else
            log "   ${RED}✗ $db_name: CORRUPTED${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    done
fi

# Test 4: Check critical files exist
log "4. Verifying critical files..."

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
        log_verbose "   - $cf: not found"
    fi
done

log ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

if [ $ERRORS -gt 0 ]; then
    log "${RED}=== VERIFICATION FAILED ===${NC}"
    log "${RED}Errors: $ERRORS | Warnings: $WARNINGS${NC}"
    log ""
    log "Action required: manually verify backup or run new backup"
    notify_ha "Backup verification FAILED: $ERRORS errors, $WARNINGS warnings" "error"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    log "${YELLOW}=== VERIFICATION OK WITH WARNINGS ===${NC}"
    log "${YELLOW}Warnings: $WARNINGS${NC}"
    notify_ha "Backup verification passed with $WARNINGS warnings" "warning"
    exit 0
else
    log "${GREEN}=== VERIFICATION OK ===${NC}"
    log "${GREEN}Backup intact and verified${NC}"
    exit 0
fi
