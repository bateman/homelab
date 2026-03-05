#!/bin/bash
# =============================================================================
# backup-qts-config.sh - Automated QNAP QTS Configuration Backup
# Homelab - NAS QNAP TS-435XeU
#
# Performs automatic backup of QTS system configuration.
# Includes: users, groups, shared folders, permissions, network, installed apps.
#
# Usage:
#   ./scripts/backup-qts-config.sh              # Standard backup
#   ./scripts/backup-qts-config.sh --notify     # With Home Assistant notification
#   ./scripts/backup-qts-config.sh --verbose    # Detailed output
#
# Exit codes:
#   0 - Backup OK
#   1 - Errors during backup
#   2 - Missing prerequisites
#
# Cron example (Sunday at 08:00, after NAS power-on at 07:00):
#   0 8 * * 0 /share/container/homelab/scripts/backup-qts-config.sh --notify >> /var/log/qts-backup.log 2>&1
#
# Note: Compatible with QNAP BusyBox environment
# =============================================================================

set -uo pipefail
# Note: -e disabled because we handle errors manually and need glob failures to not exit

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

BACKUP_DIR="${QTS_BACKUP_DIR:-/share/backup/qts-config}"
RETENTION_COUNT="${QTS_BACKUP_RETENTION:-5}"  # Keep last N backups
HA_WEBHOOK_URL="${HA_WEBHOOK_URL:-}"  # Set in environment or .env.secrets
BACKUP_METHOD=""  # Set by check_qnap: "web_api" (qcli auth + curl download) or "config_util"
QCLI_SID=""       # Set by qcli_login: session ID for web API calls
QTS_PORT="${QTS_HTTPS_PORT:-5001}"  # QTS web UI HTTPS port
QNAP_ADMIN_USER="${QNAP_ADMIN_USER:-admin}"
QNAP_ADMIN_PASSWORD="${QNAP_ADMIN_PASSWORD:-}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="qts-config-${DATE}.bin"

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

while [ $# -gt 0 ]; do
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
            echo "  --notify, -n     Send notification to Home Assistant"
            echo ""
            echo "Environment:"
            echo "  QTS_BACKUP_DIR        Backup directory (default: /share/backup/qts-config)"
            echo "  QTS_BACKUP_RETENTION  Number of backups to keep (default: 5)"
            echo "  HA_WEBHOOK_URL        Home Assistant webhook URL for notifications"
            echo "  QNAP_ADMIN_USER       QNAP admin username (default: admin)"
            echo "  QNAP_ADMIN_PASSWORD   QNAP admin password (required for QCLI 5.x+)"
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
    local level="${2:-info}"  # info, warning, error

    if [ "$NOTIFY" = true ] && [ -n "$HA_WEBHOOK_URL" ]; then
        curl -s -X POST "$HA_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"message\": \"$message\", \"level\": \"$level\", \"source\": \"qts-backup\"}" \
            >/dev/null 2>&1 || true
        log_verbose "Notification sent to Home Assistant"
    fi
}

check_qnap() {
    # Verify we're running on QNAP NAS
    # Check for QNAP-specific paths (either qpkg.conf or /share should exist)
    if [ ! -f /etc/config/qpkg.conf ] && [ ! -d /share/CACHEDEV1_DATA ]; then
        log "${RED}ERROR: This script must be run on a QNAP NAS${NC}"
        return 1
    fi

    # Determine backup method
    # QCLI 5.x+: authenticate via qcli, download backup via QTS web API (sysRequest.cgi)
    # Older firmware: use config_util which writes directly to a file
    if [ -x /sbin/qcli ]; then
        # Verify curl is available (needed for web API download)
        if ! command -v curl >/dev/null 2>&1; then
            log "${RED}ERROR: curl not found (required for QTS backup download)${NC}"
            return 1
        fi
        BACKUP_METHOD="web_api"
    elif [ -x /sbin/config_util ]; then
        BACKUP_METHOD="config_util"
    else
        log "${RED}ERROR: No QNAP backup utility found (/sbin/qcli or /sbin/config_util)${NC}"
        log "Make sure you're running as admin/root"
        return 1
    fi

    return 0
}

qcli_login() {
    # Authenticate with qcli and obtain a session ID
    # Required for QTS web API backup download on QCLI 5.x+ firmware
    if [ -z "$QNAP_ADMIN_PASSWORD" ]; then
        log "${RED}ERROR: QNAP_ADMIN_PASSWORD not set${NC}"
        log "Set it in docker/.env.secrets or export it before running"
        return 1
    fi

    log_verbose "Authenticating with qcli as '${QNAP_ADMIN_USER}'..."

    local login_output
    login_output=$(/sbin/qcli -l "user=${QNAP_ADMIN_USER}" "pw=${QNAP_ADMIN_PASSWORD}" 2>&1)

    # Extract session ID from qcli output
    # Format: "sid is <id>" (QCLI 5.x) or "sid:<id>" (older)
    # Strip non-printable characters with tr to avoid "Malformed input" curl errors
    QCLI_SID=$(echo "$login_output" | sed -n 's/.*sid[: ]*is *\([^ ]*\)/\1/p; s/.*sid:\([^ ]*\)/\1/p' | head -1 | tr -d '\r\n ')

    if [ -z "$QCLI_SID" ]; then
        log "${RED}ERROR: qcli login failed${NC}"
        log "Output: ${login_output}"
        return 1
    fi

    log_verbose "qcli session obtained (SID: ${QCLI_SID})"
    return 0
}

create_backup() {
    log "Creating backup..."

    # Create backup directory if needed
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log_verbose "Directory created: $BACKUP_DIR"
    fi

    local backup_path="${BACKUP_DIR}/${BACKUP_FILE}"

    # Execute QNAP config backup
    local cmd_result=0
    if [ "$BACKUP_METHOD" = "web_api" ]; then
        # QCLI 5.x+: download backup via QTS web API (sysRequest.cgi)
        # Note: qcli_backuprestore -B does NOT write to disk — it stages for HTTP download.
        # We must use curl against the QTS web API to get the actual .bin file.
        local api_url="https://localhost:${QTS_PORT}/cgi-bin/sys/sysRequest.cgi"
        log_verbose "Downloading backup from QTS web API (port ${QTS_PORT})..."

        # Build URL separately to avoid shell expansion issues with curl
        local full_url="${api_url}?subfunc=backup_setting&sid=${QCLI_SID}"

        curl -sk --max-time 60 --output "$backup_path" "$full_url" 2>/dev/null || cmd_result=$?
    else
        # Older firmware: config_util writes directly to file
        /sbin/config_util -e "$backup_path" 2>/dev/null || cmd_result=$?
    fi

    if [ "$cmd_result" -ne 0 ]; then
        log "${RED}ERROR: Backup download failed (exit code: ${cmd_result})${NC}"
        log "Verify QTS web UI is accessible on port ${QTS_PORT}"
        rm -f "$backup_path" 2>/dev/null
        return 1
    fi

    # Verify file was created and has content
    if [ -f "$backup_path" ] && [ -s "$backup_path" ]; then
        # Check it's not an HTML error page (QTS returns HTML on auth failure)
        if head -c 20 "$backup_path" 2>/dev/null | grep -qi "<!DOCTYPE\|<html"; then
            log "${RED}ERROR: QTS returned HTML instead of backup (authentication may have failed)${NC}"
            log "Try regenerating the session: verify QNAP_ADMIN_PASSWORD is correct"
            rm -f "$backup_path" 2>/dev/null
            return 1
        fi

        local size
        size=$(du -h "$backup_path" | cut -f1)
        log "${GREEN}Backup created: ${backup_path}${NC}"
        log "Size: $size"
        return 0
    else
        log "${RED}ERROR: Backup file empty or not created${NC}"
        rm -f "$backup_path" 2>/dev/null
        return 1
    fi
}

cleanup_old_backups() {
    log "Cleaning old backups (keeping last ${RETENTION_COUNT})..."

    # Count existing backups (BusyBox compatible)
    # Using find to avoid glob expansion issues when no files exist
    # Using arithmetic expansion to strip whitespace from wc output
    local count
    count=$(($(find "$BACKUP_DIR" -maxdepth 1 -name "qts-config-*.bin" -type f 2>/dev/null | wc -l) + 0))

    if [ "$count" -le "$RETENTION_COUNT" ]; then
        log_verbose "No cleanup needed ($count backups present)"
        return 0
    fi

    # Remove oldest backups beyond retention count
    # Using ls -t (sort by modification time, newest first) - BusyBox compatible
    local to_delete
    to_delete=$((count - RETENTION_COUNT))

    # Get oldest files and delete them
    # shellcheck disable=SC2012
    ls -1t "$BACKUP_DIR"/qts-config-*.bin 2>/dev/null | tail -n "$to_delete" | while read -r file; do
        log_verbose "Removing: $(basename "$file")"
        rm -f "$file"
    done

    log "${GREEN}Removed $to_delete old backups${NC}"
}

list_backups() {
    log ""
    log "Available backups:"

    if [ -d "$BACKUP_DIR" ]; then
        # Check if any backup files exist using find (avoids glob issues)
        # Using arithmetic expansion to strip whitespace from wc output
        local file_count
        file_count=$(($(find "$BACKUP_DIR" -maxdepth 1 -name "qts-config-*.bin" -type f 2>/dev/null | wc -l) + 0))

        if [ "$file_count" -eq 0 ]; then
            echo "  No backups found"
            return 0
        fi

        # BusyBox compatible listing (ls -lt sorts by time, newest first)
        # shellcheck disable=SC2012
        ls -lht "$BACKUP_DIR"/qts-config-*.bin 2>/dev/null | head -10 | while read -r line; do
            # Extract filename and size from ls -lh output
            local filename size
            filename=$(echo "$line" | awk '{print $NF}')
            size=$(echo "$line" | awk '{print $5}')
            if [ -n "$filename" ]; then
                echo "  - $(basename "$filename") ($size)"
            fi
        done
    else
        echo "  No backups found"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

log "${CYAN}=== QNAP QTS Configuration Backup ===${NC}"
log ""

ERRORS=0

# Check prerequisites
if ! check_qnap; then
    notify_ha "QTS backup failed: missing prerequisites" "error"
    exit 2
fi

# Authenticate with qcli (required for web API backup on QCLI 5.x+ firmware)
if [ "$BACKUP_METHOD" = "web_api" ]; then
    if ! qcli_login; then
        notify_ha "QTS backup failed: qcli authentication failed" "error"
        exit 2
    fi
fi

# Create backup
if create_backup; then
    log ""
else
    ERRORS=$((ERRORS + 1))
fi

# Cleanup old backups
if [ $ERRORS -eq 0 ]; then
    cleanup_old_backups
fi

# List available backups
if [ "$VERBOSE" = true ]; then
    list_backups
fi

log ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

if [ $ERRORS -gt 0 ]; then
    log "${RED}=== BACKUP FAILED ===${NC}"
    notify_ha "QTS backup FAILED" "error"
    exit 1
else
    log "${GREEN}=== BACKUP COMPLETED ===${NC}"
    notify_ha "QTS backup completed: ${BACKUP_FILE}" "info"
    exit 0
fi
