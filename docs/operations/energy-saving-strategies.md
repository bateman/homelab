# Energy Saving Strategies — Homelab Power Management

> Strategies and procedures to reduce energy consumption during off-hours without compromising functionality

---

## Overview

This document covers power management strategies for the homelab infrastructure:

| Device | Always-On | Can Sleep/Shutdown | Notes |
|--------|-----------|-------------------|-------|
| UPS | Yes | No | Powers entire rack |
| UDM-SE | Yes | No | Gateway, firewall, routing |
| PoE Switch | Yes | No | Network backbone |
| QNAP NAS | Yes | Partial | HDD spindown, service scheduling |
| Mini PC (Proxmox) | No | Yes | WOL available, Plex on-demand |
| Wi-Fi AP (U6-Pro) | Partial | Yes | Schedule overnight shutdown |

**Estimated Savings**: 15-30% reduction in idle power consumption with overnight scheduling.

---

## 1. Wake-on-LAN for Proxmox Mini PC

The Lenovo Mini PC running Proxmox/Plex can be powered off when not in use and woken remotely.

> [!NOTE]
> Full WOL configuration is documented in [proxmox-setup.md](../setup/proxmox-setup.md#82-wake-on-lan-wol).

### Quick Reference

```bash
# Power off Mini PC
ssh root@192.168.3.20 "shutdown -h now"

# Wake Mini PC (from NAS or any LAN device)
wakeonlan AA:BB:CC:DD:EE:FF  # Replace with actual MAC

# Wake via Tailscale (from remote — Tailscale runs on NAS)
ssh admin@192.168.3.10 "wakeonlan AA:BB:CC:DD:EE:FF"
```

### Automation Options

| Method | Trigger | Setup |
|--------|---------|-------|
| iOS Shortcut | Manual | See proxmox-setup.md |
| Home Assistant | Automation | See [Section 6](#6-home-assistant-power-automations) |
| Cron (NAS) | Scheduled | See below |

**Scheduled wake via cron (NAS)**:
```bash
# Wake Mini PC at 18:00 on weekdays (before typical Plex usage)
0 18 * * 1-5 wakeonlan AA:BB:CC:DD:EE:FF
```

---

## 2. QNAP NAS Power Management

### 2.1 HDD Standby (Spindown)

Spinning down HDDs when idle significantly reduces power and extends drive life.

**Configuration via QTS:**

1. Access QTS: `https://192.168.3.10:5000`
2. Control Panel → Hardware → General
3. HDD Standby → Enable
4. Set idle time: **30 minutes** (recommended)

> [!WARNING]
> Setting spindown too aggressively (< 15 min) can increase wear from frequent spin-up/down cycles. 30 minutes balances power savings with drive longevity.

**Per-disk configuration** (if available):
- Media HDDs: 30 minutes (frequent access)
- Backup HDDs: 15 minutes (infrequent access)

### 2.2 LED Brightness Scheduling

Reduce LED brightness overnight to save minor power and reduce light pollution.

**Configuration via QTS:**

1. Control Panel → Hardware → General
2. LED Brightness → Schedule
3. Set schedule: 23:00–07:00 → Dim/Off

### 2.3 Scheduled Power On/Off (Optional)

> [!CAUTION]
> Only enable NAS power scheduling if you don't need 24/7 access to media services or backups. This is **not recommended** for most homelab setups.

If your usage pattern is predictable:

1. Control Panel → System → Power → Power Schedule
2. Configure:
   - Shutdown: 01:00 (after Duplicati backup at 23:00)
   - Power On: 07:00 (before Watchtower updates at 07:30)

**Prerequisites**:
- Duplicati backup (23:00) must complete before shutdown
- Watchtower (07:30), QTS backup (08:00 Sun), and verification (08:30 Sun) run after power on
- No services require overnight access (01:00-07:00)
- UPS must support scheduled wake (via RTC or network signal)

---

## 3. Wi-Fi Access Point Scheduling

> WiFi Blackout Schedule and guest network scheduling are configured during initial setup. See [`network-setup.md` Phase 7.4](../setup/network-setup.md#74-wifi-blackout-schedule-optional).

This section covers additional power-saving options beyond radio scheduling.

### 3.2 Alternative: Device-Level Scheduling

To completely power off the AP (saves more power than radio disable):

**Option A: Smart Plug with Schedule**
- Connect U6-Pro to a smart plug (e.g., Tapo, Shelly)
- Schedule power off 01:00–07:00
- Note: PoE passthrough is lost; requires separate power adapter

**Option B: PoE Port Control (via UniFi)**

> [!NOTE]
> Native PoE scheduling is not available in all UniFi controller versions. You can manually toggle PoE or use automation:

**Manual toggle (in UDM-SE Network application):**
1. Settings → Devices → USW-Pro-Max-16-PoE
2. Ports → Select AP port
3. Port Profile → PoE → Off/On

**Automated via UniFi API** (advanced):
```bash
# Example: Disable PoE on port 5 (requires UniFi API access)
# See: https://ubntwiki.com/products/software/unifi-controller/api
curl -k -X PUT "https://192.168.2.1:443/api/s/default/rest/device/<switch_id>" \
  -H "Cookie: unifises=<session>" \
  -d '{"port_overrides":[{"port_idx":5,"poe_mode":"off"}]}'
```

> [!TIP]
> For simplicity, use WiFi Blackout Schedule instead of PoE control. WiFi Blackout Schedule disables the radio but keeps the AP powered for management.

---

## 4. Container/Service Scheduling

Non-critical Docker containers can be stopped overnight to reduce CPU/memory usage and power.

### 4.1 Identify Non-Critical Services

| Service | Critical | Can Stop Overnight | Notes |
|---------|----------|-------------------|-------|
| Pi-hole | Yes | No | DNS resolution needed |
| Traefik | Yes | No | Reverse proxy needed |
| Socket-proxy | Yes | No | Required by Traefik/Watchtower |
| Authelia | Yes | No | SSO authentication |
| Portainer | Yes | No | Container management |
| Watchtower | Yes | No | Container updates (runs at 07:30) |
| Uptime Kuma | Yes | No | Monitoring should stay |
| Duplicati | Yes | No | Runs backups at 23:00 |
| Gluetun | No | Yes | VPN tunnel (only with vpn profile) |
| qBittorrent/NZBGet | No | Yes | Download clients |
| Sonarr/Radarr/Lidarr | No | Yes | No overnight downloads |
| Prowlarr | No | Yes | Indexer management |
| Huntarr/Cleanuparr | No | Yes | Monitoring/cleanup |
| Bazarr | No | Yes | Subtitle fetching |
| FlareSolverr | No | Yes | Only needed with *arr |
| Recyclarr | No | Yes | Profile sync |

### 4.2 Create Scheduling Scripts

**Stop non-critical services** (`scripts/power-save-start.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Stop non-critical media services for overnight power saving
# Run via cron at 00:00 (after Duplicati backup at 23:00)

# Path to the mediastack directory (adjust if different)
MEDIASTACK_DIR="/share/container/mediastack"

# Services to stop (order matters: stop dependents first)
SERVICES=(
    "sonarr"
    "radarr"
    "lidarr"
    "prowlarr"
    "bazarr"
    "huntarr"
    "cleanuparr"
    "flaresolverr"
    "recyclarr"
    "qbittorrent"
    "nzbget"
    "gluetun"  # Stop VPN last (download clients depend on it)
)

echo "[$(date)] Starting power save mode..."

cd "${MEDIASTACK_DIR}"

for service in "${SERVICES[@]}"; do
    # Check if container exists before stopping
    if docker ps -a --format '{{.Names}}' | grep -q "^${service}$"; then
        echo "Stopping ${service}..."
        docker compose -f docker/compose.yml -f docker/compose.media.yml stop "${service}" 2>/dev/null || true
    fi
done

echo "[$(date)] Power save mode active. Non-critical services stopped."
```

**Resume services** (`scripts/power-save-stop.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Resume non-critical media services after overnight power saving
# Run via cron at 07:00

# Path to the mediastack directory (adjust if different)
MEDIASTACK_DIR="/share/container/mediastack"

echo "[$(date)] Exiting power save mode..."

cd "${MEDIASTACK_DIR}"

# Use make up to ensure proper startup order and validation
make up

echo "[$(date)] All services resumed."
```

### 4.3 Configure Cron Jobs

> [!NOTE]
> If using **NAS scheduled shutdown** (01:00-07:00), skip this section—the NAS being off stops all containers automatically. Use power-save scripts only if you want to keep the NAS running but stop non-critical services.

```bash
# On NAS (ssh admin@192.168.3.10)
crontab -e

# Enter power save at 00:00 (after Duplicati backup at 23:00)
0 0 * * * /share/container/mediastack/scripts/power-save-start.sh >> /var/log/power-save.log 2>&1

# Exit power save at 07:00 (before Watchtower at 07:30)
0 7 * * * /share/container/mediastack/scripts/power-save-stop.sh >> /var/log/power-save.log 2>&1
```

> [!IMPORTANT]
> **Timing coordination with backups (NAS downtime 01:00-07:00):**
> - Duplicati backup runs at 23:00 (before NAS shutdown)
> - NAS shutdown at 01:00 / power on at 07:00
> - Watchtower updates run at 07:30 (after NAS is up)
> - QTS config backup runs at 08:00 Sunday (after NAS is up)
> - Backup verification runs at 08:30 Sunday
>
> All scheduled tasks avoid the 01:00-07:00 downtime window.

> [!NOTE]
> Adjust paths if you deployed the stack to a different directory.

### 4.4 Makefile Integration

Add to `Makefile`:

```makefile
## Energy saving
power-save-start: ## Enter power save mode (stop non-critical services)
	@./scripts/power-save-start.sh

power-save-stop: ## Exit power save mode (resume all services)
	@./scripts/power-save-stop.sh
```

---

## 5. UPS Monitoring with NUT

Network UPS Tools (NUT) provides power monitoring and automated shutdown on battery events.

### 5.1 Install NUT on Proxmox

```bash
# SSH into Proxmox
ssh root@192.168.3.20

# Install NUT
apt update && apt install -y nut

# Identify UPS (connected via USB)
lsusb | grep -i ups
# Or
nut-scanner -U
```

### 5.2 Configure NUT

**`/etc/nut/ups.conf`**:
```ini
[eaton]
    driver = usbhid-ups
    port = auto
    desc = "Eaton 5P 650i Rack G2"
    vendorid = 0463
    pollinterval = 15
```

**`/etc/nut/upsd.conf`**:
```ini
LISTEN 127.0.0.1 3493
LISTEN 192.168.3.20 3493
```

**`/etc/nut/upsd.users`**:
```ini
[admin]
    password = your_secure_password
    upsmon master
    actions = SET
    instcmds = ALL

[monitor]
    password = monitor_password
    upsmon slave
```

**`/etc/nut/upsmon.conf`**:
```ini
MONITOR eaton@localhost 1 admin your_secure_password master
MINSUPPLIES 1
SHUTDOWNCMD "/sbin/shutdown -h +0"
POLLFREQ 5
POLLFREQALERT 2
HOSTSYNC 15
DEADTIME 15
POWERDOWNFLAG /etc/killpower
NOTIFYFLAG ONLINE SYSLOG+WALL
NOTIFYFLAG ONBATT SYSLOG+WALL+EXEC
NOTIFYFLAG LOWBATT SYSLOG+WALL+EXEC
NOTIFYFLAG SHUTDOWN SYSLOG+WALL+EXEC
```

**`/etc/nut/nut.conf`**:
```ini
MODE=netserver
```

### 5.3 Start NUT Services

```bash
systemctl enable nut-server nut-monitor
systemctl start nut-server nut-monitor

# Verify UPS communication
upsc eaton
```

### 5.4 Monitor Power Consumption

```bash
# Current power draw (if supported by UPS)
upsc eaton ups.realpower
upsc eaton ups.load

# Battery status
upsc eaton battery.charge
upsc eaton battery.runtime

# All values
upsc eaton
```

### 5.5 NUT Client on NAS (Optional)

To receive shutdown signals on NAS when UPS battery is low:

```bash
# QNAP supports NUT via SSH or add-on packages
# Configure as NUT slave pointing to Proxmox

# /etc/nut/upsmon.conf on NAS
MONITOR eaton@192.168.3.20 1 monitor monitor_password slave
```

---

## 6. Home Assistant Power Automations

Home Assistant can centralize power management with intelligent automations.

### 6.1 Prerequisites

- Enable Home Assistant: Add `compose.homeassistant.yml` to compose files
- Install Wake-on-LAN integration
- Install NUT integration (if using UPS monitoring)

### 6.2 Example Automations

> [!NOTE]
> These examples require additional integrations:
> - **Wake-on-LAN**: Built-in, add via Settings → Integrations
> - **Plex**: Install via HACS or Settings → Integrations (for `sensor.plex`)
> - **Ping**: Built-in binary sensor for checking if Proxmox is online
> - **UniFi Network**: For AP control (PoE control requires custom scripts, see below)

**`docker/config/homeassistant/automations.yaml`**:

```yaml
# Wake Plex server when someone arrives home
- alias: "Wake Plex on Arrival"
  trigger:
    - platform: state
      entity_id: person.your_name
      to: "home"
  condition:
    - condition: state
      entity_id: binary_sensor.proxmox  # Create via Settings → Helpers → Ping
      state: "off"
  action:
    - service: wake_on_lan.send_magic_packet
      data:
        mac: "AA:BB:CC:DD:EE:FF"  # Replace with Mini PC MAC

# Shutdown Plex server at night if no active streams
# Requires Plex integration for sensor.plex
# Note: Scheduled before NAS shutdown (01:00) since HA runs on NAS
- alias: "Shutdown Plex Overnight"
  trigger:
    - platform: time
      at: "00:30:00"
  condition:
    - condition: template
      value_template: "{{ states('sensor.plex') | int(0) == 0 }}"
  action:
    - service: shell_command.shutdown_proxmox

# Time-based service control (alternative to cron)
# Use this if you prefer HA to manage power save instead of cron
# Note: Skip if using NAS scheduled shutdown (01:00-07:00)
- alias: "Enter Power Save Mode"
  trigger:
    - platform: time
      at: "00:00:00"  # After Duplicati backup at 23:00
  action:
    - service: shell_command.power_save_start

- alias: "Exit Power Save Mode"
  trigger:
    - platform: time
      at: "07:00:00"  # Before Watchtower at 07:30
  action:
    - service: shell_command.power_save_stop
```

> [!NOTE]
> Choose either cron (Section 4.3) OR Home Assistant automations for power save scheduling, not both.

> [!TIP]
> For UniFi AP PoE control, the built-in UniFi integration doesn't support PoE port toggling directly. Use the UniFi Controller's WiFi Blackout Schedule instead (see [`network-setup.md` Phase 7.4](../setup/network-setup.md#74-wifi-blackout-schedule-optional)), or create custom shell commands using the UniFi API.

**Shell commands** (`docker/config/homeassistant/configuration.yaml`):

```yaml
shell_command:
  # Proxmox control (requires SSH key setup)
  shutdown_proxmox: "ssh -o StrictHostKeyChecking=no -i /config/.ssh/id_rsa root@192.168.3.20 'shutdown -h now'"
  # Wake via NAS (wakeonlan not available in HA container by default)
  wake_proxmox: "ssh -o StrictHostKeyChecking=no -i /config/.ssh/id_rsa admin@192.168.3.10 'wakeonlan AA:BB:CC:DD:EE:FF'"

  # NAS power save scripts (requires SSH key setup to NAS)
  power_save_start: "ssh -o StrictHostKeyChecking=no -i /config/.ssh/id_rsa admin@192.168.3.10 '/share/container/mediastack/scripts/power-save-start.sh'"
  power_save_stop: "ssh -o StrictHostKeyChecking=no -i /config/.ssh/id_rsa admin@192.168.3.10 '/share/container/mediastack/scripts/power-save-stop.sh'"
```

> [!IMPORTANT]
> For shell commands to work, you must:
> 1. Generate SSH key in HA container: `ssh-keygen -t ed25519 -f /config/.ssh/id_rsa -N ""`
> 2. Copy public key to Proxmox: `ssh-copy-id -i /config/.ssh/id_rsa.pub root@192.168.3.20`
> 3. Copy public key to NAS: `ssh-copy-id -i /config/.ssh/id_rsa.pub admin@192.168.3.10`
> 4. Test connections from HA container before using automations

### 6.3 Power Monitoring Dashboard

Create a Lovelace dashboard card for power monitoring:

```yaml
type: entities
title: Power Management
entities:
  - entity: sensor.ups_load           # Requires NUT integration
    name: UPS Load
  - entity: sensor.ups_battery        # Requires NUT integration
    name: Battery Charge
  - entity: sensor.ups_runtime        # Requires NUT integration
    name: Est. Runtime
  - entity: binary_sensor.proxmox     # Create via Settings → Helpers → Ping
    name: Plex Server
  - entity: sensor.plex               # Requires Plex integration
    name: Active Plex Streams
```

> [!NOTE]
> Entity names vary based on your integration setup. Adjust as needed after installing the required integrations.

---

## 7. Proxmox Power Optimization

### 7.1 CPU Governor

Set CPU to power-saving mode when idle:

```bash
# Check current governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Set to powersave (persistent via systemd)
cat > /etc/systemd/system/cpu-governor.service << 'EOF'
[Unit]
Description=Set CPU Governor to Powersave
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable cpu-governor
systemctl start cpu-governor
```

> [!NOTE]
> Modern Intel CPUs with `intel_pstate` driver may use `powersave` by default but still scale up when needed. This is the recommended setting.

### 7.2 Intel P-State Configuration

For fine-grained control:

```bash
# Limit maximum frequency (optional, reduces heat/power)
echo 80 > /sys/devices/system/cpu/intel_pstate/max_perf_pct

# Check current settings
cat /sys/devices/system/cpu/intel_pstate/status
```

### 7.3 PCI Power Management

Enable ASPM (Active State Power Management):

```bash
# Check current ASPM policy
cat /sys/module/pcie_aspm/parameters/policy

# Enable powersave (if supported)
echo "powersave" > /sys/module/pcie_aspm/parameters/policy

# Make persistent via kernel parameter
# Add to /etc/default/grub: GRUB_CMDLINE_LINUX_DEFAULT="... pcie_aspm=force"
# Then: update-grub && reboot
```

---

## 8. Implementation Checklist

### Phase 1: Quick Wins (Immediate)

- [ ] Configure HDD spindown on NAS (30 min)
- [ ] Set LED brightness schedule on NAS
- [ ] Enable WiFi Blackout Schedule (see [`network-setup.md` Phase 7.4](../setup/network-setup.md#74-wifi-blackout-schedule-optional))

### Phase 2: Proxmox Optimization

- [ ] Document Mini PC MAC address for WOL
- [ ] Verify WOL configuration (see proxmox-setup.md)
- [ ] Set CPU governor to powersave
- [ ] Install NUT for UPS monitoring

### Phase 3: Service Scheduling

- [ ] Create power-save scripts
- [ ] Configure cron jobs on NAS
- [ ] Test service stop/start cycle
- [ ] Add Makefile targets

### Phase 4: Advanced Automation (Optional)

- [ ] Enable Home Assistant
- [ ] Configure HA automations
- [ ] Set up power monitoring dashboard
- [ ] Integrate arrival/departure triggers

---

## 9. Monitoring and Verification

### Power Consumption Baseline

Measure baseline power consumption with a smart plug or UPS monitoring:

| State | Expected Power | Notes |
|-------|---------------|-------|
| Full load | ~200-250W | All services active, transcoding |
| Normal idle | ~80-120W | All services running, no activity |
| Power save | ~50-70W | Non-critical services stopped |
| Minimal | ~30-40W | Mini PC off, HDDs spun down |

### Verify Savings

```bash
# UPS load percentage
upsc eaton ups.load

# Track over time (if HA is available)
# Create a sensor that logs hourly power readings
```

### Log Review

```bash
# Check power save script execution
tail -f /var/log/power-save.log

# Check container status
docker ps --format "table {{.Names}}\t{{.Status}}"
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Services don't stop | Script permissions | `chmod +x scripts/power-save-*.sh` |
| WOL doesn't work | Not on same VLAN | Send from device on VLAN 3 |
| HDD won't spin down | Constant access | Check which process with `iotop` |
| High idle power | Background tasks | Review container resource usage |
| AP won't power on | PoE budget exceeded | Check switch PoE allocation |
| NUT can't find UPS | USB permission | Add udev rule for USB device |

---

## References

- [Proxmox WOL Setup](../setup/proxmox-setup.md#82-wake-on-lan-wol)
- [QNAP Power Management Documentation](https://www.qnap.com/en/how-to/faq/article/how-to-configure-hard-drive-standby-mode)
- [UniFi WiFi Blackout Schedule](https://help.ui.com/hc/en-us/articles/115012723447)
- [NUT Documentation](https://networkupstools.org/docs/man/)
- [Home Assistant WOL Integration](https://www.home-assistant.io/integrations/wake_on_lan/)

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-01 | Document creation |
