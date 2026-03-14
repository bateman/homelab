#!/bin/sh
# =============================================================================
# Proxmox Mini PC — Wake-on-LAN & Scheduled Shutdown Cron Jobs
# QNAP NAS (BusyBox-compatible)
# =============================================================================
#
# QNAP QTS regenerates the crontab on every reboot, wiping custom entries.
# This script re-injects the Mini PC power-cycle cron jobs and is meant to
# be called from QNAP's autorun.sh so the jobs survive reboots.
#
# Usage:
#   1. Enable autorun in QTS:
#        Control Panel → Hardware → General → "Run user defined startup
#        processes (autorun.sh)" — check the box and click Apply.
#   2. Mount flash config and append this script to autorun.sh:
#        sudo /etc/init.d/init_disk.sh mount_flash_config
#        sudo sh -c 'echo "/share/container/mediastack/scripts/proxmox-wol-cron.sh >> /var/log/minipc-power.log 2>&1" >> /tmp/nasconfig_tmp/autorun.sh'
#        sudo /etc/init.d/init_disk.sh umount_flash_config
#   3. Reboot and verify: crontab -l | grep -i "mini pc"
#
# See docs/operations/energy-saving-strategies.md for full context.
# =============================================================================

set -eu

# ---------------------------------------------------------------------------
# Configuration — edit these to match your environment
# ---------------------------------------------------------------------------
PROXMOX_IP="192.168.3.20"
SSH_KEY="/root/.ssh/id_proxmox_ed25519"
MAC_ADDRESS="AA:BB:CC:DD:EE:FF"       # Replace with Mini PC's real MAC (ip link show nic0)
LOG="/var/log/minipc-power.log"

# ---------------------------------------------------------------------------
# Cron entries to inject
# ---------------------------------------------------------------------------
# Each entry is a comment + cron line pair. The marker comment is used to
# detect whether the jobs are already present (idempotent).
MARKER="# === Mini PC Scheduled Power Cycle ==="

CRON_ENTRIES="${MARKER}
# Weeknights: 23:59 Sun-Thu (before 00:00 Mon-Fri NAS shutdown)
59 23 * * 0-4 ssh -i ${SSH_KEY} -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${PROXMOX_IP} \"shutdown -h now\" >> ${LOG} 2>&1
# Weekend nights: 00:59 Sat-Sun (before 01:00 Sat-Sun NAS shutdown)
59 0 * * 0,6 ssh -i ${SSH_KEY} -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${PROXMOX_IP} \"shutdown -h now\" >> ${LOG} 2>&1
# Wake Mini PC 2 minutes after NAS boots (handles scheduled power-on, reboots, and power outages)
@reboot sleep 120 && wakeonlan ${MAC_ADDRESS} >> ${LOG} 2>&1"

# ---------------------------------------------------------------------------
# Inject into crontab (idempotent — skips if marker already present)
# ---------------------------------------------------------------------------
CURRENT_CRONTAB=$(crontab -l 2>/dev/null || true)

if printf '%s\n' "${CURRENT_CRONTAB}" | grep -qF "${MARKER}"; then
    echo "[proxmox-wol-cron] Cron jobs already present — skipping."
else
    # Append entries to existing crontab (avoid leading blank line if empty)
    if [ -n "${CURRENT_CRONTAB}" ]; then
        printf '%s\n%s\n' "${CURRENT_CRONTAB}" "${CRON_ENTRIES}" | crontab -
    else
        printf '%s\n' "${CRON_ENTRIES}" | crontab -
    fi
    echo "[proxmox-wol-cron] Cron jobs injected successfully."
    # @reboot entries only fire at crond startup, which has already happened
    # by the time autorun.sh runs. Trigger WOL directly for this boot.
    ( sleep 120 && wakeonlan "${MAC_ADDRESS}" >> "${LOG}" 2>&1 ) &
    echo "[proxmox-wol-cron] WOL scheduled in background (120s delay)."
fi
