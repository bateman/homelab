#!/usr/bin/env bash
# =============================================================================
# Fix qBittorrent WebUI access (CSRF + Host Header Validation)
# =============================================================================
# qBittorrent v4.6+ enables CSRF protection and host header validation by
# default. This causes "Not Found" errors and redirect loops when accessing
# the WebUI via reverse proxy (Traefik) or direct IP.
#
# This script runs on every container start (via LinuxServer custom-cont-init.d)
# and patches the config BEFORE qBittorrent starts, so it's never overwritten.
#
# Safe to disable these checks because:
#   - Authelia SSO protects the Traefik route (qbit.home.local)
#   - Direct IP access (192.168.3.10:8080) is on the server VLAN only
# =============================================================================

QBIT_CONF="/config/qBittorrent/qBittorrent.conf"

# Wait for first-run config generation (max 30s)
if [[ ! -f "$QBIT_CONF" ]]; then
    echo "[99-fix-webui-access] Config not found, creating initial config..."
    mkdir -p "$(dirname "$QBIT_CONF")"
    cat > "$QBIT_CONF" << 'CONF'
[Preferences]
WebUI\CSRFProtection=false
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=false
WebUI\Address=*
CONF
    echo "[99-fix-webui-access] Created initial config with WebUI fixes applied"
    exit 0
fi

echo "[99-fix-webui-access] Patching qBittorrent.conf..."

# Ensure [Preferences] section exists
if ! grep -q '^\[Preferences\]' "$QBIT_CONF"; then
    echo "" >> "$QBIT_CONF"
    echo "[Preferences]" >> "$QBIT_CONF"
fi

# Patch or add each setting under [Preferences]
patch_setting() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" "$QBIT_CONF"; then
        # Setting exists — update it
        sed -i "s|^${key}=.*|${key}=${value}|" "$QBIT_CONF"
        echo "[99-fix-webui-access]   Updated: ${key}=${value}"
    else
        # Setting missing — add after [Preferences]
        sed -i "/^\[Preferences\]/a ${key}=${value}" "$QBIT_CONF"
        echo "[99-fix-webui-access]   Added: ${key}=${value}"
    fi
}

patch_setting "WebUI\\\\CSRFProtection" "false"
patch_setting "WebUI\\\\HostHeaderValidation" "false"
patch_setting "WebUI\\\\LocalHostAuth" "false"
patch_setting "WebUI\\\\Address" "*"

echo "[99-fix-webui-access] Done. WebUI should be accessible via IP and reverse proxy."
