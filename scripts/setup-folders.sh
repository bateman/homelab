#!/bin/bash
# =============================================================================
# Setup script - Trash Guides compliant folder structure
# NAS QNAP TS-435XeU - Homelab
# =============================================================================

set -euo pipefail

# Configurazione
DATA_ROOT="/share/data"
CONFIG_ROOT="./config"
PUID=1000
PGID=100

# Colori per output
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

# Verifica prerequisiti
check_prerequisites() {
    log_info "Verifica prerequisiti..."
    
    # Verifica se eseguito come root (necessario per chown)
    if [[ $EUID -ne 0 ]]; then
        log_warn "Script non eseguito come root. chown potrebbe fallire."
        log_warn "Esegui con: sudo ./setup-folders.sh"
    fi
    
    # Verifica esistenza DATA_ROOT o possibilita' di crearlo
    if [[ ! -d "$DATA_ROOT" ]]; then
        log_warn "Directory $DATA_ROOT non esiste. Tento di crearla..."
        if ! mkdir -p "$DATA_ROOT" 2>/dev/null; then
            log_error "Impossibile creare $DATA_ROOT. Verifica i permessi."
            exit 1
        fi
    fi
    
    # Verifica scrittura
    if ! touch "$DATA_ROOT/.write_test" 2>/dev/null; then
        log_error "Impossibile scrivere in $DATA_ROOT. Verifica i permessi."
        exit 1
    fi
    rm -f "$DATA_ROOT/.write_test"
    
    log_info "Prerequisiti OK"
}

echo "=== Creazione struttura cartelle Trash Guides ==="
echo ""

check_prerequisites

# Struttura dati principale (per hardlinking)
log_info "Creazione struttura dati in $DATA_ROOT..."

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

# Cartelle config per ogni servizio
log_info "Creazione cartelle config in $CONFIG_ROOT..."

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

# Permessi
log_info "Impostazione permessi (PUID=$PUID, PGID=$PGID)..."

if [[ $EUID -eq 0 ]]; then
    chown -R "${PUID}:${PGID}" "${DATA_ROOT}"
    chown -R "${PUID}:${PGID}" "${CONFIG_ROOT}"
    chmod -R 775 "${DATA_ROOT}"
    chmod -R 775 "${CONFIG_ROOT}"
    log_info "Permessi impostati correttamente"
else
    log_warn "Skippo chown (non root). Esegui manualmente:"
    log_warn "  sudo chown -R ${PUID}:${PGID} ${DATA_ROOT} ${CONFIG_ROOT}"
    log_warn "  sudo chmod -R 775 ${DATA_ROOT} ${CONFIG_ROOT}"
fi

echo ""
log_info "=== Struttura creata ==="
echo ""

# Mostra struttura creata
if command -v tree &> /dev/null; then
    tree -L 3 "${DATA_ROOT}"
else
    find "${DATA_ROOT}" -type d | head -20
fi

echo ""
echo "============================================================================="
echo "                           PROSSIMI PASSI"
echo "============================================================================="
echo ""
echo "1. CONFIGURA qBittorrent (http://192.168.3.10:8080)"
echo "   -----------------------------------------------------------------------------"
echo "   Options -> Saving Management -> Default Torrent Management Mode: Automatic"
echo "   Default Save Path: /data/torrents"
echo "   Categories: movies, tv, music (path relativi, es: 'movies' non '/data/torrents/movies')"
echo ""
echo "2. CONFIGURA NZBGet (http://192.168.3.10:6789)"
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
echo "3. CONFIGURA Sonarr/Radarr/Lidarr"
echo "   -----------------------------------------------------------------------------"
echo "   Root Folder: /data/media/tv (o movies, music)"
echo "   Settings -> Media Management -> Use Hardlinks instead of Copy: ON"
echo "   Download Client path mapping NON necessario (stesso mount)"
echo ""
echo "4. VERIFICA hardlinking"
echo "   -----------------------------------------------------------------------------"
echo "   ls -li /data/torrents/movies/file.mkv /data/media/movies/Film/file.mkv"
echo "   (stesso inode = hardlink funzionante)"
echo ""
echo "============================================================================="
