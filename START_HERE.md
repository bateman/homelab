# START HERE - Complete Installation Guide

> This guide provides the correct order to install and configure the entire homelab from start to finish.

---

## Prerequisites

Before starting, make sure you have:

- [ ] All hardware listed in [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md)
- [ ] Access to local network and a computer for configuration
- [ ] Indexer/Usenet subscriptions (for media stack)

---

## Phase Overview

| Phase | Description | Reference Documents |
|-------|-------------|---------------------|
| 1 | Hardware Installation | [`docs/setup/rack-mounting-guide.md`](docs/setup/rack-mounting-guide.md), [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md) |
| 2 | UniFi Network Setup | [`docs/setup/network-setup.md`](docs/setup/network-setup.md) |
| 3 | QNAP NAS Setup | [`docs/setup/nas-setup.md`](docs/setup/nas-setup.md) |
| 4 | Docker Stack Deploy | [`docs/setup/nas-setup.md`](docs/setup/nas-setup.md), [`Makefile`](Makefile) |
| 5 | Services Configuration | [`docs/setup/nas-setup.md`](docs/setup/nas-setup.md) |
| 5b | Reverse Proxy *(optional)* | [`docs/setup/reverse-proxy-setup.md`](docs/setup/reverse-proxy-setup.md) |
| 6 | Proxmox/Plex Setup | [`docs/setup/proxmox-setup.md`](docs/setup/proxmox-setup.md) |
| 7 | Backup Configuration | [`docs/operations/runbook-backup-restore.md`](docs/operations/runbook-backup-restore.md) |
| 8 | Final Verification | This guide |
| 9 | Energy Saving *(optional)* | [`docs/operations/energy-saving-strategies.md`](docs/operations/energy-saving-strategies.md) |

---

## Phase 1: Hardware Installation

**Reference:** [`docs/setup/rack-mounting-guide.md`](docs/setup/rack-mounting-guide.md) (installation order), [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md) (component specs)

### Rack Layout (bottom to top)

1. [ ] **U1**: UPS (weight at bottom, minimal heat generation)
2. [ ] **U2**: QNAP TS-435XeU (cool zone for HDDs)
3. [ ] **U3**: Vented panel (airflow between NAS and networking)
4. [ ] **U4**: Patch panel (passive, thermal buffer)
5. [ ] **U5**: USW-Pro-Max-16-PoE
6. [ ] **U6**: UDM-SE
7. [ ] **U7**: Vented panel (thermal isolation)
8. [ ] **U8**: Lenovo Mini PC (top, dissipation upward)

### Cabling

- [ ] Connect UDM-SE WAN port → Iliad Box LAN
- [ ] Connect UDM-SE LAN SFP+ → Switch SFP+ port 1 (10GbE trunk)
- [ ] Connect Switch SFP+ port 2 → NAS SFP+ port 1 (10GbE)
- [ ] Connect Switch port 5 → Mini PC integrated NIC (1GbE, WOL only)
- [ ] Connect Switch port 6 → Mini PC USB adapter (2.5GbE, management)
- [ ] Connect all devices directly to UPS C13 outlets (no power strip)

### Verification

```bash
# All status LEDs should be on
# UPS should show active load
```

---

## Phase 2: UniFi Network Setup

**Reference:** [`docs/setup/network-setup.md`](docs/setup/network-setup.md)

> [!WARNING]
> Complete this phase BEFORE configuring any other device

### 2.1 UDM-SE Initial Setup

1. [ ] Connect PC directly to UDM-SE LAN port
2. [ ] Access `https://192.168.0.1` (UDM-SE factory default LAN IP)
3. [ ] Complete UniFi wizard
4. [ ] Create UniFi account or use existing

### 2.2 VLAN Creation

Create the following networks in **Settings → Networks**:

| VLAN ID | Name | Subnet | Gateway | DHCP Range |
|---------|------|--------|---------|------------|
| 2 | Management | 192.168.2.0/24 | 192.168.2.1 | .100-.200 |
| 3 | Servers | 192.168.3.0/24 | 192.168.3.1 | .100-.200 (DHCP reservations) |
| 4 | Media | 192.168.4.0/24 | 192.168.4.1 | .100-.200 |
| 5 | Guest | 192.168.5.0/24 | 192.168.5.1 | .100-.200 |
| 6 | IoT | 192.168.6.0/24 | 192.168.6.1 | .100-.200 |

### 2.3 Switch Configuration

1. [ ] Adopt switch in UniFi Controller
2. [ ] Configure switch port profiles (see [`network-setup.md` Phase 3](docs/setup/network-setup.md#phase-3-switch-configuration) for full details):
   - Port 1: Management (VLAN 2) — AP
   - Ports 2-4: Media (VLAN 4) — Living Room, Bedroom, Studio
   - Ports 5-6: Servers (VLAN 3) — Mini PC
   - Port 9: Servers (VLAN 3) — Printer
   - SFP+ 1: Trunk (all VLANs) — UDM-SE uplink
   - SFP+ 2: Servers (VLAN 3) — NAS

### 2.4 Firewall Rules

**Reference:** [`docs/network/firewall-config.md`](docs/network/firewall-config.md)

1. [ ] Create IP address network lists (see `firewall-config.md` section "IP Address Network Lists")
2. [ ] Create port network lists (see `firewall-config.md` section "Port Network Lists")
3. [ ] Insert firewall rules in the exact order specified

### Phase 2 Verification

```bash
# From a PC on VLAN 3
ping 192.168.3.1    # Gateway
ping 8.8.8.8        # Internet
ping 192.168.2.1    # Management VLAN (should work)
```

---

## Phase 3: QNAP NAS Setup

**Reference:** [`docs/setup/nas-setup.md`](docs/setup/nas-setup.md)

Follow the complete checklist. Key points:

### 3.1 QTS Setup

1. [ ] First boot and initial wizard
2. [ ] Firmware update
3. [ ] Verify DHCP reservation assigns `192.168.3.10` (configured on UDM-SE)
4. [ ] User creation and security

### 3.2 Storage Configuration

1. [ ] Create Storage Pool (RAID)
2. [ ] Create Thick Volume (NOT Static — see [`nas-setup.md`](docs/setup/nas-setup.md#volume) for why)
3. [ ] Create Shared Folders:
   - `/share/data` - Media and download data
   - `/share/container` - Docker files
   - `/share/backup` - Backups

### 3.3 Change QTS System Ports

> QTS factory ports (8080/443) conflict with Docker services. Change before deploying containers.

1. [ ] Control Panel → System → General Settings → System Administration
2. [ ] Set System Port: `5000`, HTTPS Port: `5001`
3. [ ] Enable Force Secure Connection (HTTPS)
4. [ ] Verify: `https://192.168.3.10:5001`

### 3.4 Container Station

1. [ ] Install Container Station 3 from App Center
2. [ ] Complete initial wizard
3. [ ] Verify Docker is working:
   ```bash
   ssh admin@192.168.3.10
   docker version
   ```

### Phase 3 Verification

- [ ] QTS accessible: `https://192.168.3.10:5001`
- [ ] SSH working
- [ ] Docker installed
- [ ] Shared folders created

---

## Phase 4: Docker Stack Deploy

### 4.1 Clone Repository

See [`nas-setup.md` — Media Stack Folder Structure](docs/setup/nas-setup.md#media-stack-folder-structure) for full details (including git installation via MyQNAP repo).

```bash
# SSH into NAS
ssh admin@192.168.3.10

# Option A: Git clone (recommended)
cd /share/container
git clone https://github.com/<your-username>/homelab.git mediastack
cd mediastack

# Option B: Manual copy (if git not available)
# scp -r docker/ scripts/ Makefile admin@192.168.3.10:/share/container/mediastack/
```

### 4.2 Folder Structure Setup

```bash
# Run complete setup (creates data, config folders and .env file)
make setup

# Edit .env file with correct values
nano docker/.env
```

**Required configuration in `docker/.env`:**

```bash
# First verify PUID/PGID of dockeruser created in Phase 3
ssh admin@192.168.3.10 "id dockeruser"
# Output: uid=1001(dockeruser) gid=100(everyone)

# Set in docker/.env:
PUID=1001          # ← uid value from id command
PGID=100           # ← gid value from id command
TZ=Europe/Rome
```

**Required credentials in `docker/.env.secrets`:**

```bash
# Pi-hole WebUI password (generate with: openssl rand -base64 24)
PIHOLE_PASSWORD=<secure-password>

# VPN credentials (if using vpn profile) — see docs/setup/vpn-setup.md
```

> [!IMPORTANT]
> If PUID/PGID don't match the user owning the folders, containers won't have write permissions.

### 4.2.1 Permissions Verification

```bash
# Verify folder ownership (must match PUID:PGID)
ls -ln /share/data

# If needed, fix permissions:
sudo chown -R 1001:100 /share/data
sudo chown -R 1001:100 ./config
```

### 4.2.2 Free DNS Port (Port 53)

QTS ships with a built-in `dnsmasq` that binds port 53. Pi-hole needs this port, so `dnsmasq` must be disabled. There is no GUI toggle — it requires an `autorun.sh` script persisted in QNAP's flash config. See [`nas-setup.md`](docs/setup/nas-setup.md#free-dns-port-port-53) for full step-by-step details.

Quick summary:

1. **Enable autorun**: Control Panel → Hardware → General → check "Run user defined startup processes (autorun.sh)"
2. **Create** `/tmp/nasconfig_tmp/autorun.sh` — use `sudo tee` (shell redirection does not inherit sudo):
   ```bash
   sudo tee /tmp/nasconfig_tmp/autorun.sh << 'EOF'
   #!/bin/sh
   /bin/echo "autorun.sh fired at $(/bin/date)" >> /tmp/autorun.log
   /bin/cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
   /bin/sed 's/port=53/port=0/g' < /etc/dnsmasq.conf.orig > /etc/dnsmasq.conf
   /usr/bin/killall dnsmasq
   /bin/echo "dnsmasq killed at $(/bin/date)" >> /tmp/autorun.log
   EOF
   ```
3. **Make executable**: `sudo chmod +x /tmp/nasconfig_tmp/autorun.sh`
4. **Persist to flash**: `sudo /etc/init.d/init_disk.sh umount_flash_config`
5. **Apply now**: `sudo /bin/cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig && sudo /bin/sed 's/port=53/port=0/g' < /etc/dnsmasq.conf.orig > /etc/dnsmasq.conf && sudo /usr/bin/killall dnsmasq`
6. **Verify**: `sudo netstat -tulnp | grep ':53 '` — no output means port 53 is free
7. **After reboot, check log**: `cat /tmp/autorun.log`

> [!WARNING]
> QNAP's Malware Remover may delete `autorun.sh` during scans. If Pi-hole stops resolving after a scan, re-create it (see [`nas-setup.md`](docs/setup/nas-setup.md#free-dns-port-port-53)).

### 4.3 Container Startup

```bash
# Validate configuration
make validate

# Pull images
make pull

# Start stack
make up

# Verify status
make status
```

### Phase 4 Verification

```bash
# All containers must be "Up" and "healthy"
make health

# Display service URLs
make urls
```

---

## Phase 5: Services Configuration

**Reference:** [`docs/setup/nas-setup.md`](docs/setup/nas-setup.md) section "*arr Services Configuration"

### Configuration Order (IMPORTANT)

Follow exactly this order for dependencies:

```
1. Prowlarr        → Indexer manager (configure first)
2. qBittorrent     → Torrent download client
3. NZBGet          → Usenet download client
4. Sonarr          → TV (connects to Prowlarr + download client)
5. Radarr          → Movies (connects to Prowlarr + download client)
6. Lidarr          → Music (connects to Prowlarr + download client)
7. Bazarr          → Subtitles (connects to Sonarr + Radarr)
8. Recyclarr       → Quality profiles (connects to Sonarr + Radarr)
9. Pi-hole         → DNS (independent)
10. Home Assistant → Home automation (independent)
```

> [!NOTE]
> Prowlarr is configured first, then download clients, then *arr apps that connect them all together.

### qBittorrent First Access

qBittorrent generates a random password on first boot. To retrieve it:

```bash
# Retrieve temporary password from logs
docker logs qbittorrent 2>&1 | grep -i password
# Output: "The WebUI administrator password was not set. A temporary password is provided: XXXXXX"
```

- Username: `admin`
- Password: from log above
- After login: Options → WebUI → change password

### Critical Configurations

For each *arr service, verify:

- [ ] **Hardlinks enabled**: Settings → Media Management → Use Hardlinks instead of Copy: **Yes**
- [ ] **Correct root folder**: `/data/media/{movies,tv,music}`
- [ ] **Download client path**: `/data/torrents` or `/data/usenet/complete`

### API Key Collection

Note the API keys (for password manager):

| Service | API Key Path |
|---------|--------------|
| Sonarr | Settings → General → API Key |
| Radarr | Settings → General → API Key |
| Lidarr | Settings → General → API Key |
| Prowlarr | Settings → General → API Key |
| Bazarr | Settings → General → API Key |

### Hardlinking Verification

```bash
# Critical test - run after first import
ls -li /share/data/torrents/movies/file.mkv /share/data/media/movies/Film/file.mkv

# Same inode number = hardlink working
```

---

## Phase 6: Proxmox/Plex Setup

**Reference:** [`docs/setup/proxmox-setup.md`](docs/setup/proxmox-setup.md)

### 6.1 Proxmox Installation

1. [ ] Download Proxmox VE ISO
2. [ ] Create bootable USB
3. [ ] Install on Lenovo Mini PC
4. [ ] Configure IP: `192.168.3.20` (static during install, then switches to DHCP reservation)

### 6.2 Plex Setup

1. [ ] Create VM or LXC container for Plex
2. [ ] Mount NFS share from NAS
3. [ ] Configure Plex libraries

### 6.3 Tailscale Configuration

> Tailscale runs as a Docker container on the NAS (always-on), not on the Mini PC.
> See `docker/compose.yml` for configuration.

1. [ ] Generate auth key at https://login.tailscale.com/admin/settings/keys
2. [ ] Add `TS_AUTHKEY` to `docker/.env.secrets`
3. [ ] Start the stack: `make up`
4. [ ] Approve subnet routes at https://login.tailscale.com/admin/machines

### Phase 6 Verification

- [ ] Proxmox accessible: `https://192.168.3.20:8006`
- [ ] Plex accessible: `http://192.168.3.21:32400/web` (LXC container)
- [ ] Tailscale connected (`docker exec tailscale tailscale status`)

---

## Phase 7: Backup Configuration

**Reference:** [`docs/operations/runbook-backup-restore.md`](docs/operations/runbook-backup-restore.md)

### 7.1 Duplicati (Container)

1. [ ] Access `http://192.168.3.10:8200`
2. [ ] Configure backup job:
   - Source: `/source/config`
   - Local destination: `/backups`
   - Cloud destination: Google Drive or Dropbox (optional)
3. [ ] Set schedule: daily
4. [ ] Retention: 7 daily, 4 weekly, 3 monthly

### 7.2 QTS Backup

1. [ ] Control Panel → System → Backup/Restore
2. [ ] Backup System Settings → Save .bin file

### 7.3 Proxmox VM Backup

1. [ ] Proxmox → Datacenter → Storage → Add NFS
2. [ ] Configure weekly backup schedule

### 7.4 Restore Test

- [ ] Test restoring a config file
- [ ] Document procedure

---

## Phase 8: Final Verification

### Functionality Checklist

**Network:**
- [ ] All VLANs reachable
- [ ] Internet working from every VLAN
- [ ] Firewall rules active (test blocks)

**NAS/Docker:**
- [ ] All containers healthy: `make health`
- [ ] WebUIs accessible: `make urls`
- [ ] Logs without critical errors: `make logs`

**Media Stack:**
- [ ] Prowlarr: indexers configured and working
- [ ] Sonarr/Radarr/Lidarr: can search for content
- [ ] Download client: test download completed
- [ ] Hardlinking: verified with `ls -li`
- [ ] Bazarr: subtitles downloaded automatically

**Plex:**
- [ ] Libraries synced
- [ ] Streaming working (local and remote via Tailscale)

**Backup:**
- [ ] Duplicati job scheduled
- [ ] Restore test completed
- [ ] Offsite backup configured

---

## Phase 9: Energy Saving (Optional)

**Reference:** [`docs/operations/energy-saving-strategies.md`](docs/operations/energy-saving-strategies.md)

> [!TIP]
> Configure energy saving after your homelab is fully operational and verified. These optimizations can reduce idle power consumption by 15-30%.

### 9.1 Quick Wins (Recommended)

1. [ ] Configure HDD spindown on NAS (30 minutes idle)
2. [ ] Set LED brightness schedule (dim overnight)
3. [ ] Enable WiFi Blackout Schedule in UniFi (disable overnight if not needed)

### 9.2 Proxmox Power Management

1. [ ] Document Mini PC MAC address for Wake-on-LAN
2. [ ] Verify WOL is configured (see [`proxmox-setup.md`](docs/setup/proxmox-setup.md#82-wake-on-lan-wol))
3. [ ] Set CPU governor to powersave
4. [ ] Install NUT for UPS monitoring (optional)

### 9.3 Service Scheduling (Optional)

1. [ ] Create power-save scripts for non-critical services
2. [ ] Configure cron jobs (stop services 00:00, resume 07:00)
3. [ ] Add Makefile targets: `make power-save-start`, `make power-save-stop`

### 9.4 Advanced Automation (Optional)

1. [ ] Enable Home Assistant
2. [ ] Configure presence-based WOL automation
3. [ ] Set up power monitoring dashboard

### Phase 9 Verification

```bash
# Check UPS load (if NUT configured)
upsc eaton ups.load

# Verify services resume correctly after power-save
make health
```

---

## Routine Maintenance

### Daily (automatic)
- Watchtower updates containers
- Duplicati runs backup
- Cleanuparr cleans obsolete files

### Weekly
```bash
make status      # Verify container status
make health      # Health check
```

### Monthly
```bash
make pull        # Update images manually if needed
make backup      # Additional manual backup
```

---

## Common Troubleshooting

| Problem | Quick Solution |
|---------|----------------|
| Container won't start | `docker compose logs <service>` |
| Permission denied | `sudo chown -R $PUID:$PGID ./config` (use values from .env) |
| Hardlink fails | Verify same filesystem |
| Service unreachable | Verify firewall rules |
| Pi-hole doesn't resolve | Verify port 53 is free (`netstat -tulnp \| grep ':53 '`), disable dnsmasq if needed (see §4.2.2) |
| qBittorrent login fails | Retrieve password: `docker logs qbittorrent 2>&1 \| grep password` |
| Wrong PUID/PGID | Verify with `id dockeruser` and update docker/.env |

For specific problems, consult the Troubleshooting section in [`docs/setup/nas-setup.md`](docs/setup/nas-setup.md).

---

## Reference Documents

| Document | Contents |
|----------|----------|
| [`CLAUDE.md`](CLAUDE.md) | Project guide and development guidelines |
| [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md) | Hardware layout and IP plan |
| [`docs/setup/rack-mounting-guide.md`](docs/setup/rack-mounting-guide.md) | Rack mounting order and cable routing |
| [`docs/network/firewall-config.md`](docs/network/firewall-config.md) | Complete firewall rules |
| [`docs/setup/nas-setup.md`](docs/setup/nas-setup.md) | Detailed QNAP checklist |
| [`docs/setup/network-setup.md`](docs/setup/network-setup.md) | UniFi network setup |
| [`docs/setup/proxmox-setup.md`](docs/setup/proxmox-setup.md) | Proxmox and Plex setup |
| [`docs/setup/reverse-proxy-setup.md`](docs/setup/reverse-proxy-setup.md) | Traefik, Nginx Proxy Manager, Tailscale DNS |
| [`docs/operations/runbook-backup-restore.md`](docs/operations/runbook-backup-restore.md) | Backup and restore procedures |
| [`docs/operations/energy-saving-strategies.md`](docs/operations/energy-saving-strategies.md) | Power management and energy optimization |
