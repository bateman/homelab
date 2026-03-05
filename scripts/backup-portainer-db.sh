#!/bin/bash
# =============================================================================
# backup-portainer-db.sh - Pre-backup snapshot of Portainer database
# Homelab - NAS QNAP TS-435XeU
#
# Portainer keeps portainer.db locked while running, preventing Duplicati
# from reading it. This script briefly stops Portainer (~2s), uses docker cp
# to extract the database, and restarts it. The copy (portainer.db.bak) lives
# in the same config directory so Duplicati backs it up automatically.
#
# Uses `docker cp` instead of filesystem cp to avoid needing sudo/root
# permissions on the host — works for both interactive and cron usage.
#
# Usage:
#   ./scripts/backup-portainer-db.sh              # Standard run
#   ./scripts/backup-portainer-db.sh --verbose    # Detailed output
#
# Exit codes:
#   0 - Snapshot OK
#   1 - Error during snapshot
#   2 - Portainer not running / DB not found
#
# Cron example (daily at 22:55, 5 minutes before Duplicati backup at 23:00):
#   55 22 * * * /share/container/homelab/scripts/backup-portainer-db.sh >> /var/log/backup-portainer-db.log 2>&1
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

CONTAINER_NAME="portainer"
CONTAINER_DB_PATH="/data/portainer.db"
# Resolve paths relative to this script's location (homelab/scripts/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BAK_PATH="${REPO_DIR}/docker/config/portainer/portainer.db.bak"
VERBOSE=false

# Colors (disabled if not terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

# -----------------------------------------------------------------------------
# Parse Arguments
# -----------------------------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=true ;;
        --help|-h)
            echo "Usage: $0 [--verbose]"
            echo "Stops Portainer, copies portainer.db via docker cp, restarts Portainer."
            exit 0
            ;;
    esac
done

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1"; }
log_verbose() { [ "$VERBOSE" = true ] && log "$1"; }

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

# Check Portainer container exists (running or stopped)
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log "${RED}Error: ${CONTAINER_NAME} container not found${NC}"
    exit 2
fi

# Check if Portainer is running — if so, stop it first
WAS_RUNNING=false
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    WAS_RUNNING=true
    log_verbose "Stopping ${CONTAINER_NAME}..."
    if ! docker stop "$CONTAINER_NAME" >/dev/null 2>&1; then
        log "${RED}Error: failed to stop ${CONTAINER_NAME}${NC}"
        exit 1
    fi
fi

# Copy database using docker cp (no sudo needed)
# Remove old .bak first — may be root-owned from a previous sudo cp
rm -f "$BAK_PATH" 2>/dev/null || true
log_verbose "Copying portainer.db -> portainer.db.bak..."
if docker cp "${CONTAINER_NAME}:${CONTAINER_DB_PATH}" "$BAK_PATH"; then
    log_verbose "${GREEN}Snapshot created${NC}"
else
    log "${RED}Error: failed to copy database${NC}"
    # Restart if it was running
    [ "$WAS_RUNNING" = true ] && docker start "$CONTAINER_NAME" >/dev/null 2>&1
    exit 1
fi

# Restart Portainer if it was running
if [ "$WAS_RUNNING" = true ]; then
    log_verbose "Starting ${CONTAINER_NAME}..."
    if docker start "$CONTAINER_NAME" >/dev/null 2>&1; then
        log "${GREEN}OK — portainer.db.bak created (Portainer downtime: ~2s)${NC}"
    else
        log "${RED}Error: failed to restart ${CONTAINER_NAME} — start it manually!${NC}"
        exit 1
    fi
else
    log "${GREEN}OK — portainer.db.bak created (Portainer was already stopped)${NC}"
fi
