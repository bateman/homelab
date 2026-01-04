#!/bin/bash
# =============================================================================
# Setup script - Trash Guides compliant folder structure
# NAS QNAP TS-435XeU - Homelab
# =============================================================================

set -euo pipefail

# Configuration
DATA_ROOT="/share/data"
CONFIG_ROOT="./config"
PUID=1000
PGID=100

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if running as root (required for chown)
    if [[ $EUID -ne 0 ]]; then
        log_warn "Script not running as root. chown may fail."
        log_warn "Run with: sudo ./setup-folders.sh"
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

mkdir -p "${DATA_ROOT}/torrents/movies"
mkdir -p "${DATA_ROOT}/torrents/tv"
mkdir -p "${DATA_ROOT}/torrents/music"
mkdir -p "${DATA_ROOT}/usenet/incomplete"
mkdir -p "${DATA_ROOT}/usenet/complete/movies"
mkdir -p "${DATA_ROOT}/usenet/complete/tv"
mkdir -p "${DATA_ROOT}/usenet/complete/music"
mkdir -p "${DATA_ROOT}/media/movies"
mkdir -p "${DATA_ROOT}/media/tv"
mkdir -p "${DATA_ROOT}/media/music"

# Config folders for each service
log_info "Creating config folders in $CONFIG_ROOT..."

mkdir -p "${CONFIG_ROOT}/sonarr"
mkdir -p "${CONFIG_ROOT}/radarr"
mkdir -p "${CONFIG_ROOT}/lidarr"
mkdir -p "${CONFIG_ROOT}/prowlarr"
mkdir -p "${CONFIG_ROOT}/bazarr"
mkdir -p "${CONFIG_ROOT}/qbittorrent"
mkdir -p "${CONFIG_ROOT}/nzbget"
mkdir -p "${CONFIG_ROOT}/huntarr"
mkdir -p "${CONFIG_ROOT}/cleanuparr"
mkdir -p "${CONFIG_ROOT}/pihole/etc-pihole"
mkdir -p "${CONFIG_ROOT}/pihole/etc-dnsmasq.d"
mkdir -p "${CONFIG_ROOT}/homeassistant"
mkdir -p "${CONFIG_ROOT}/portainer"
mkdir -p "${CONFIG_ROOT}/duplicati"
mkdir -p "${CONFIG_ROOT}/recyclarr"
mkdir -p "${CONFIG_ROOT}/flaresolverr"
mkdir -p "${CONFIG_ROOT}/traefik"

# Permissions
log_info "Setting permissions (PUID=$PUID, PGID=$PGID)..."

if [[ $EUID -eq 0 ]]; then
    chown -R "${PUID}:${PGID}" "${DATA_ROOT}"
    chown -R "${PUID}:${PGID}" "${CONFIG_ROOT}"
    chmod -R 775 "${DATA_ROOT}"
    chmod -R 775 "${CONFIG_ROOT}"
    log_info "Permissions set correctly"
else
    log_warn "Skipping chown (not root). Run manually:"
    log_warn "  sudo chown -R ${PUID}:${PGID} ${DATA_ROOT} ${CONFIG_ROOT}"
    log_warn "  sudo chmod -R 775 ${DATA_ROOT} ${CONFIG_ROOT}"
fi

echo ""
log_info "=== Structure created ==="
echo ""

# Show created structure
if command -v tree &> /dev/null; then
    tree -L 3 "${DATA_ROOT}"
else
    find "${DATA_ROOT}" -type d | head -20
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
