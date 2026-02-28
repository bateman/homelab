#!/bin/bash
# =============================================================================
# Setup script - Trash Guides compliant folder structure
# NAS QNAP TS-435XeU - Homelab
# =============================================================================

set -euo pipefail

# Script directory (for relative paths)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
DATA_ROOT="/share/data"
BACKUP_ROOT="/share/backup"
CONFIG_ROOT="${SCRIPT_DIR}/../config"
DRY_RUN=false

# Default PUID/PGID (can be overridden by .env)
PUID=1001
PGID=100

# Load from .env if present
ENV_FILE="${SCRIPT_DIR}/../docker/.env"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    PUID=$(grep -E "^PUID=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "$PUID")
    PGID=$(grep -E "^PGID=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "$PGID")
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage help
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Setup Trash Guides compliant folder structure for homelab media stack.

OPTIONS:
    -h, --help      Show this help message
    -n, --dry-run   Show what would be done without making changes

CONFIGURATION:
    DATA_ROOT:   ${DATA_ROOT}
    BACKUP_ROOT: ${BACKUP_ROOT}
    CONFIG_ROOT: ${CONFIG_ROOT}
    PUID/PGID:   ${PUID}/${PGID}

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Wrapper for mkdir that respects DRY_RUN
make_dir() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would create: $1"
    else
        mkdir -p "$1"
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Skipping prerequisite checks"
        return 0
    fi

    # Check if sudo is available (needed for chown/chmod when not root)
    if [[ $EUID -ne 0 ]] && ! command -v sudo &> /dev/null; then
        log_warn "Not running as root and sudo not available. chown/chmod will be skipped."
    fi

    # Check if DATA_ROOT exists or can be created
    if [[ ! -d "$DATA_ROOT" ]]; then
        log_warn "Directory $DATA_ROOT does not exist. Attempting to create..."
        if ! mkdir -p "$DATA_ROOT" 2>/dev/null; then
            log_error "Cannot create $DATA_ROOT. Check permissions."
            exit 1
        fi
    fi

    # Check write access
    if ! touch "$DATA_ROOT/.write_test" 2>/dev/null; then
        log_error "Cannot write to $DATA_ROOT. Check permissions."
        exit 1
    fi
    rm -f "$DATA_ROOT/.write_test"

    log_info "Prerequisites OK"
}

echo "=== Creating Trash Guides folder structure ==="
echo ""

check_prerequisites

# Main data structure (for hardlinking)
log_info "Creating data structure in $DATA_ROOT..."

make_dir "${DATA_ROOT}/torrents/movies"
make_dir "${DATA_ROOT}/torrents/tv"
make_dir "${DATA_ROOT}/torrents/music"
make_dir "${DATA_ROOT}/usenet/incomplete"
make_dir "${DATA_ROOT}/usenet/complete/movies"
make_dir "${DATA_ROOT}/usenet/complete/tv"
make_dir "${DATA_ROOT}/usenet/complete/music"
make_dir "${DATA_ROOT}/media/movies"
make_dir "${DATA_ROOT}/media/tv"
make_dir "${DATA_ROOT}/media/music"

# Backup destination (for Duplicati)
log_info "Creating backup destination in $BACKUP_ROOT..."

make_dir "${BACKUP_ROOT}"

# Config folders for each service
log_info "Creating config folders in $CONFIG_ROOT..."

# Media stack (*arr apps)
make_dir "${CONFIG_ROOT}/sonarr"
make_dir "${CONFIG_ROOT}/radarr"
make_dir "${CONFIG_ROOT}/lidarr"
make_dir "${CONFIG_ROOT}/prowlarr"
make_dir "${CONFIG_ROOT}/bazarr"
make_dir "${CONFIG_ROOT}/recyclarr"

# Download clients
make_dir "${CONFIG_ROOT}/qbittorrent"
make_dir "${CONFIG_ROOT}/nzbget"

# VPN (protects download clients)
make_dir "${CONFIG_ROOT}/gluetun"

# Monitoring/automation
make_dir "${CONFIG_ROOT}/cleanuparr"

# Infrastructure services
make_dir "${CONFIG_ROOT}/pihole/etc-pihole"
make_dir "${CONFIG_ROOT}/pihole/etc-dnsmasq.d"
make_dir "${CONFIG_ROOT}/homeassistant"
make_dir "${CONFIG_ROOT}/portainer"
make_dir "${CONFIG_ROOT}/duplicati"
make_dir "${CONFIG_ROOT}/uptime-kuma"
make_dir "${CONFIG_ROOT}/traefik"
make_dir "${CONFIG_ROOT}/authelia"
make_dir "${CONFIG_ROOT}/tailscale"

# Secrets directory (for Authelia secrets)
SECRETS_ROOT="${SCRIPT_DIR}/../docker/secrets"
make_dir "${SECRETS_ROOT}/authelia"

# Permissions
log_info "Setting permissions (PUID=$PUID, PGID=$PGID)..."

if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Would set ownership ${PUID}:${PGID} on ${DATA_ROOT}, ${BACKUP_ROOT}, ${CONFIG_ROOT}"
    log_info "[DRY-RUN] Would set permissions 775 on ${DATA_ROOT}, ${BACKUP_ROOT}, ${CONFIG_ROOT}"
else
    # Use sudo when not running as root
    SUDO=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            SUDO="sudo"
        else
            log_warn "Skipping chown/chmod (not root and sudo not available). Run manually:"
            log_warn "  chown -R ${PUID}:${PGID} ${DATA_ROOT} ${BACKUP_ROOT} ${CONFIG_ROOT}"
            log_warn "  chmod -R 775 ${DATA_ROOT} ${BACKUP_ROOT} ${CONFIG_ROOT}"
        fi
    fi

    if [[ $EUID -eq 0 ]] || [[ -n "${SUDO}" ]]; then
        $SUDO chown -R "${PUID}:${PGID}" "${DATA_ROOT}" 2>/dev/null
        $SUDO chown -R "${PUID}:${PGID}" "${BACKUP_ROOT}" 2>/dev/null
        $SUDO chown -R "${PUID}:${PGID}" "${CONFIG_ROOT}" 2>/dev/null
        $SUDO chmod -R 775 "${DATA_ROOT}" 2>/dev/null
        $SUDO chmod -R 775 "${BACKUP_ROOT}" 2>/dev/null
        $SUDO chmod -R 775 "${CONFIG_ROOT}" 2>/dev/null

        # Verify permissions actually took effect (QNAP shared folders may ignore chown/chmod)
        ACTUAL_UID=$(stat -c '%u' "${DATA_ROOT}" 2>/dev/null || stat -f '%u' "${DATA_ROOT}" 2>/dev/null)
        if [[ "$ACTUAL_UID" != "$PUID" ]]; then
            log_warn "chown did not take effect on ${DATA_ROOT} (expected UID ${PUID}, got ${ACTUAL_UID})"
            log_warn "QNAP shared folders may ignore standard chown/chmod commands."
            log_warn "Set PUID=${ACTUAL_UID} in docker/.env to match the actual file owner,"
            log_warn "or change folder ownership via QTS Control Panel → Shared Folders → Permissions."
        else
            log_info "Permissions set correctly"
        fi
    fi
fi

echo ""
if [[ "$DRY_RUN" == true ]]; then
    log_info "=== DRY-RUN complete (no changes made) ==="
else
    log_info "=== Structure created ==="
fi
echo ""

# Show created structure
if [[ "$DRY_RUN" != true ]]; then
    echo "--- Data Structure (${DATA_ROOT}) ---"
    if command -v tree &> /dev/null; then
        tree -L 3 "${DATA_ROOT}"
    else
        find "${DATA_ROOT}" -type d | head -20
    fi

    echo ""
    echo "--- Config Structure (${CONFIG_ROOT}) ---"
    if command -v tree &> /dev/null; then
        tree -L 2 "${CONFIG_ROOT}"
    else
        find "${CONFIG_ROOT}" -type d | head -20
    fi
fi

echo ""
echo "============================================================================="
echo "                              NEXT STEPS"
echo "============================================================================="
echo ""
echo "1. CONFIGURE qBittorrent (http://192.168.3.10:8080)"
echo "   -----------------------------------------------------------------------------"
echo "   Options -> Saving Management -> Default Torrent Management Mode: Automatic"
echo "   Default Save Path: /data/torrents"
echo "   Categories: movies, tv, music (relative paths, e.g., 'movies' not '/data/torrents/movies')"
echo ""
echo "2. CONFIGURE NZBGet (http://192.168.3.10:6789)"
echo "   -----------------------------------------------------------------------------"
echo "   Settings -> Paths:"
echo "     MainDir: /data/usenet"
echo "     DestDir: /data/usenet/complete"
echo "     InterDir: /data/usenet/incomplete"
echo "   Settings -> Categories:"
echo "     movies -> DestDir: movies"
echo "     tv     -> DestDir: tv"
echo "     music  -> DestDir: music"
echo ""
echo "3. CONFIGURE Sonarr/Radarr/Lidarr"
echo "   -----------------------------------------------------------------------------"
echo "   Root Folder: /data/media/tv (or movies, music)"
echo "   Settings -> Media Management -> Use Hardlinks instead of Copy: ON"
echo "   Download Client path mapping NOT required (same mount)"
echo ""
echo "4. VERIFY hardlinking"
echo "   -----------------------------------------------------------------------------"
echo "   ls -li /data/torrents/movies/file.mkv /data/media/movies/Film/file.mkv"
echo "   (same inode = hardlink working)"
echo ""
echo "============================================================================="
