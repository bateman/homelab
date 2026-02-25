# Proxmox Setup - Lenovo ThinkCentre neo 50q Gen 4

> Guide for installing Proxmox VE on the Mini PC and configuring Plex

---

## Prerequisites

- [ ] Lenovo ThinkCentre neo 50q Gen 4 Mini PC rack-mounted
- [ ] Connected to switch VLAN 3 (Servers) — Port 6 (management) + Port 5 (1GbE WOL)
- [ ] Monitor and keyboard for initial installation
- [ ] USB drive (8GB+) for Proxmox ISO
- [ ] VLAN 3 configured (see [network-setup.md](network-setup.md))

---

## Phase 1: Bootable USB Preparation

### 1.1 Download Proxmox ISO

1. Download from: https://www.proxmox.com/en/downloads
2. Select: Proxmox VE ISO Installer (latest stable version)
3. Verify SHA256 checksum

### 1.2 Create Bootable USB

**Linux/macOS:**
```bash
# Identify USB device
lsblk

# Write ISO (replace /dev/sdX with correct device)
sudo dd bs=4M if=proxmox-ve_*.iso of=/dev/sdX conv=fsync status=progress
```

**Windows:**
- Use Rufus or balenaEtcher
- Select Proxmox ISO
- Mode: DD Image

---

## Phase 2: Proxmox Installation

### 2.1 Boot from USB

1. [ ] Insert USB into Mini PC
2. [ ] Power on and press F12 (or Lenovo boot menu key)
3. [ ] Select USB as boot device
4. [ ] Select "Install Proxmox VE"

### 2.2 Installation Wizard

1. [ ] Accept EULA
2. [ ] Select installation disk
   - Select NVMe SSD
   - **Filesystem: ext4** (recommended for single NVMe)

> [!NOTE]
> ZFS requires at least 8GB dedicated RAM and offers advantages (snapshots, integrity) mainly with multi-disk configurations. For single NVMe, ext4 is more resource-efficient.

3. [ ] Locale settings:
   - Country: Italy
   - Timezone: Europe/Rome
   - Keyboard: Italian

### 2.3 Network Configuration

> [!NOTE]
> The Proxmox installer requires a static IP. Use `192.168.3.20` during installation — after setup, the bridge will be switched to DHCP and the UDM-SE DHCP reservation will assign this same IP. See [Phase 8.4](#84-switch-to-25gbe-usb-adapter).

| Field | Value |
|-------|--------|
| Management Interface | eth0 (or main interface) |
| Hostname (FQDN) | proxmox.servers.local |
| IP Address | 192.168.3.20 |
| Netmask | 255.255.255.0 (/24) |
| Gateway | 192.168.3.1 |
| DNS Server | 192.168.3.1 (or 1.1.1.1) |

### 2.4 Credentials

- [ ] Set secure root password
- [ ] Email: your@email.com (for notifications)

### 2.5 Complete Installation

1. [ ] Review configuration summary
2. [ ] Click "Install"
3. [ ] Wait for completion (~5-10 minutes)
4. [ ] Remove USB on reboot
5. [ ] System boots into Proxmox

### Verify Installation

```bash
# From a PC on the same VLAN
ping 192.168.3.20
```

Open browser: `https://192.168.3.20:8006`
- Accept self-signed certificate
- Login: root / password set

---

## Phase 3: Post-Installation Configuration

### 3.1 Disable Enterprise Repository

```bash
# SSH into Proxmox
ssh root@192.168.3.20

# Disable enterprise repo
# Proxmox 8+ uses .sources (DEB822 format), older versions use .list
if [ -f /etc/apt/sources.list.d/pve-enterprise.sources ]; then
    mv /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/pve-enterprise.sources.disabled
elif [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
    sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
fi

# Also disable Ceph enterprise repo if present
if [ -f /etc/apt/sources.list.d/ceph.sources ]; then
    mv /etc/apt/sources.list.d/ceph.sources /etc/apt/sources.list.d/ceph.sources.disabled
elif [ -f /etc/apt/sources.list.d/ceph.list ]; then
    sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/ceph.list
fi

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
```

### 3.2 Update System

```bash
apt update && apt full-upgrade -y
reboot
```

### 3.3 Remove Subscription Popup

```bash
# Optional - removes license popup in WebUI
sed -Ezi.bak "s/(Ext.Msg.show\(\{[^}]*license[^}]*\}\);)/void(0);/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy
```

### 3.4 Configure NFS Storage from NAS

#### Prerequisite: Enable NFS Export on QNAP

Before configuring NFS on Proxmox, enable NFS export on the NAS.

> [!NOTE]
> The NFS **service** (v4.1) should already be enabled from [NAS setup](nas-setup.md#enable-nfs-service). This section configures the **per-folder export permissions**.

1. Access QTS: `https://192.168.3.10:5001`
2. Control Panel → Shared Folders
3. For each folder to export (data, backup):
   - Select folder → Edit → NFS Permissions → Add
   - Host/IP: `192.168.3.20` (Proxmox)
   - Permission: `read/write`
   - Squash: `no_root_squash` (for backup)
   - Apply

Verify NFS connectivity from Proxmox:
```bash
# Test mount (NFS v4.1 only — showmount doesn't work without v3)
mount -t nfs4 -o vers=4.1 192.168.3.10:/share/data/media /mnt/test
ls /mnt/test
umount /mnt/test
```

#### Add NFS Storage in Proxmox

Datacenter → Storage → Add → NFS

| Field | Value |
|-------|--------|
| ID | nas-media |
| Server | 192.168.3.10 |
| Export | /share/data/media |
| Content | Disk image, Container |
| NFS Version | 4.1 |

Also add storage for backup:

| Field | Value |
|-------|--------|
| ID | nas-backup |
| Server | 192.168.3.10 |
| Export | /share/backup |
| Content | VZDump backup file |
| NFS Version | 4.1 |

> [!TIP]
> If NFS mount fails, verify that the QNAP firewall allows connections from 192.168.3.20 and that NFS services are active.

---

## Phase 4: Creating LXC Container for Plex

> [!TIP]
> LXC is lighter than a full VM and sufficient for Plex

### 4.1 Download Template

Datacenter → proxmox → local → CT Templates → Templates

Download: `debian-13-standard` (Trixie)

> [!TIP]
> **Why Debian instead of Ubuntu?**
> - Reduced footprint (~150MB vs ~400MB base image)
> - Lower RAM consumption (~50-80MB idle vs ~150-200MB)
> - Less frequent/more stable updates
> - Same base as Proxmox (optimal compatibility)
> - Sufficient for Plex which has minimal dependencies

### 4.2 Create Container

Datacenter → proxmox → Create CT

> [!IMPORTANT]
> **Uncheck "Unprivileged container"** — GPU passthrough for Intel Quick Sync hardware transcoding (Phase 8.3) requires a privileged container. Unprivileged containers need complex UID/GID mapping to access `/dev/dri` devices.

**Tab General:**
| Field | Value |
|-------|--------|
| CT ID | 100 |
| Hostname | plex |
| Unprivileged | ❌ Unchecked (privileged — required for GPU passthrough) |
| Password | (secure password) |
| SSH Public Key | (optional, see below) |

> [!TIP]
> **Optional: Generate SSH key for container access**
>
> On the machine you'll SSH from:
> ```bash
> # Generate key with custom name
> ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/proxmox_plex
>
> # Copy public key to clipboard
> cat ~/.ssh/proxmox_plex.pub
> ```
> Paste the output into the SSH Public Key field above.
>
> Then add to `~/.ssh/config` for easy access:
> ```
> Host plex
>     HostName 192.168.3.21
>     User root
>     IdentityFile ~/.ssh/proxmox_plex
> ```
> Connect with just `ssh plex`.

**Tab Template:**
- Template: debian-13-standard

**Tab Disks:**
| Field | Value |
|-------|--------|
| Storage | local-lvm |
| Disk size | 16 GB |

**Tab CPU:**
- Cores: 8 (i5-13420H has 12 threads; 8 for Plex, 4 reserved for Proxmox host)

**Tab Memory:**
| Field | Value |
|-------|--------|
| Memory | 4096 MB |
| Swap | 512 MB |

**Tab Network:**
| Field | Value |
|-------|--------|
| Bridge | vmbr0 |
| IPv4 | Static |
| IPv4/CIDR | 192.168.3.21/24 |
| Gateway | 192.168.3.1 |

**Tab DNS:**
- Use host settings (default)

### 4.3 Configure NFS Mount Point

Before starting, add mount point for media:

```bash
# On Proxmox host
pct set 100 -mp0 /mnt/nas-media,mp=/media
```

Or via WebUI:
Container 100 → Resources → Add → Mount Point
- Storage: nas-media
- Mount Point: /media

### 4.4 Start Container and Install Plex

```bash
# Start container
pct start 100

# Enter container
pct enter 100

# Update system
apt update && apt upgrade -y

# Add Plex repository
curl https://downloads.plex.tv/plex-keys/PlexSign.key | gpg --dearmor -o /usr/share/keyrings/plex-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/plex-archive-keyring.gpg] https://downloads.plex.tv/repo/deb public main" > /etc/apt/sources.list.d/plexmediaserver.list

# Install Plex
apt update
apt install plexmediaserver -y

# Verify status
systemctl status plexmediaserver
```

### Verify Plex

Open browser: `http://192.168.3.21:32400/web`

---

## Phase 5: Plex Configuration (Trash Guides)

> [!NOTE]
> This section follows the [official Trash Guides recommendations](https://trash-guides.info/Plex/Tips/Plex-media-server/) to optimize Plex Media Server.

### 5.1 Initial Setup

1. [ ] Access `http://192.168.3.21:32400/web`
2. [ ] Login with Plex account (or create one)
3. [ ] Name the server: "Homelab Plex"
4. [ ] Guided initial configuration

### 5.2 Add Libraries

Add Library → Movies:
- Name: Movies
- Folders: /media/movies

Add Library → TV Shows:
- Name: TV Shows
- Folders: /media/tv

Add Library → Music:
- Name: Music
- Folders: /media/music

### 5.3 Library Settings (Settings → Library)

> [!IMPORTANT]
> **Trash Guides Philosophy**: Plex should never modify your media files. Use Sonarr/Radarr to manage the library. For extra security, configure Plex with **Read Only** access to the media library.

| Setting | Value | Rationale |
|---------|-------|-----------|
| Scan my library automatically | ✅ Enabled | Automatically detects changes in source folders |
| Run a partial scan when changes are detected | ✅ Enabled | Scans only the modified folder, not the entire library |
| Run scanner tasks at a lower priority | ✅ Enabled | Reduces impact on resource-limited systems |
| Empty trash automatically after every scan | ✅ Enabled | Removes deleted files from library on next scan |
| Allow media deletion | ❌ Disabled | **Critical**: Plex must not manage files, use Radarr/Sonarr |
| Generate video preview thumbnails | ❌ Never | Uses lots of disk space and I/O without significant benefits |
| Generate intro video markers | As scheduled task | Enables "Skip Intro" feature |
| Generate credits video markers | As scheduled task | Enables "Skip Credits" feature |
| Generate chapter thumbnails | As scheduled task | Minimal storage impact, useful functionality |

**Database Cache Size** (advanced settings):
- For large collections (hundreds of thousands of items): `1024-2048 MB`
- Default sufficient for most users

### 5.4 Transcoder Settings (Settings → Transcoder)

| Setting | Value | Rationale |
|---------|-------|-----------|
| Transcoder quality | Automatic | Recommended for most users |
| Transcoder temporary directory | `/tmp/plex` or RAM disk | Reduces I/O; **NEVER use network share** |
| Enable HDR tone mapping | Depends on setup | Requires significant resources for 4K content |
| Tone mapping algorithm | Hable | Better preserves details in bright and dark areas |
| Use hardware acceleration when available | ✅ Enabled | Significantly improves performance |
| Use hardware-accelerated video encoding | ✅ Enabled | Reduces CPU load (requires Plex Pass) |
| Maximum simultaneous video transcode | Based on hardware | 2-4 for modern CPUs with Quick Sync |

#### Configure Temporary Directory on RAM

For optimal transcoding performance, use a RAM disk:

```bash
# In Plex container (pct enter 100)

# Create directory for transcoding
mkdir -p /tmp/plex

# Optional: dedicated tmpfs mount (persists until reboot)
mount -t tmpfs -o size=2G tmpfs /tmp/plex

# To make permanent, add to /etc/fstab:
echo "tmpfs /tmp/plex tmpfs size=2G,mode=1777 0 0" >> /etc/fstab
```

> [!TIP]
> Transcoding on RAM reduces SSD wear and speeds up operations, since transcode data is temporary.

### 5.5 Network Settings (Settings → Network)

| Setting | Value | Rationale |
|---------|-------|-----------|
| Enable IPv6 support | ❌ Disabled | Enable only if network fully supports IPv6 |
| Secure connections | Preferred | Accepts and prefers secure connections when available |
| Enable local network discovery (GDM) | ✅ Enabled | Allows automatic server/app discovery on local network |
| Enable Relay | ❌ Disabled | Limited to ~2 Mbps, causes playback issues. We'll use Tailscale |
| Custom server access URLs | (empty) | Configure if using reverse proxy |
| LAN Networks | `192.168.3.0/24,192.168.4.0/24` | **Important**: Specify local networks to prevent LAN devices from appearing as remote |
| Treat WAN IP As LAN Bandwidth | ✅ Enabled | Useful if you have DNS rebinding protection active |

> [!IMPORTANT]
> If your local devices are seen as "remote", properly configure **LAN Networks** with your subnets.

### 5.6 Specific Library Settings

#### For Movie Library

Edit Library → Advanced:

| Setting | Value | Rationale |
|---------|-------|-----------|
| Scanner | Plex Movie | Native scanner, faster |
| Agent | Plex Movie | Faster metadata retrieval |
| Prefer local metadata | ✅ Enabled | Uses local files (poster, fanart) if available |
| Use local assets | ✅ Enabled | Priority to local artwork |
| Prefer embedded tags | ❌ Disabled | Avoids unwanted naming conventions |
| Enable credits detection | ✅ Enabled | Skip credits feature |
| Collections | Create automatically (2+ items) | Organizes content into logical collections |

#### For TV Show Library

Edit Library → Advanced:

| Setting | Value | Rationale |
|---------|-------|-----------|
| Scanner | Plex TV Series | Optimized native scanner |
| Agent | Plex TV Series | Faster metadata retrieval |
| Prefer local metadata | ✅ Enabled | Uses local files if available |
| Episode sorting | Library default | Or based on preferences |
| Enable intro detection | ✅ Enabled | "Skip Intro" feature |
| Enable credits detection | ✅ Enabled | "Skip Credits" feature |

### 5.7 Recommended Client Settings

> Reference: [Media Clients Wiki](https://mediaclients.wiki/Plex) for device-specific settings.

#### Universal Client Settings

For each Plex client (TV, phone, tablet, web):

**Quality → Video:**

| Scenario | Setting | Value |
|----------|---------|-------|
| Home Streaming | Quality | Maximum / Original |
| Remote Streaming | Quality | Maximum / Original (with good connection) |
| Limit remote quality | Depends | Only if limited bandwidth |

**Important**: Set quality to "Original" or "Maximum" to avoid unnecessary transcoding and preserve quality.

**Player Settings:**
- [ ] Direct Play: ✅ Enabled
- [ ] Direct Stream: ✅ Enabled
- [ ] Auto Adjust Quality: ❌ Disabled (if stable connection)

**Subtitles:**
- [ ] Burn subtitles: Only image formats (avoids transcoding for SRT/ASS)
- [ ] Subtitle size: Medium
- [ ] Subtitle position: Bottom

### 5.8 4K Transcoding Prevention (Optional)

> [!WARNING]
> Transcoding 4K/HDR content is very resource-intensive and can degrade quality. It's better to prevent it.

#### Why Prevent 4K Transcoding

- Requires **enormous** CPU/GPU resources
- **Degrades quality** HDR → SDR
- Can cause **stuttering and buffering**
- Devices that don't support 4K should use a separate 1080p version

#### Solution: Tautulli + JBOPS (requires Plex Pass)

1. **Install Tautulli** (Plex monitoring)
2. **Configure JBOPS script** to block 4K transcoding
3. The system **automatically terminates** 4K streams requiring transcoding

Complete guide: [Trash Guides - 4K Transcoding Prevention](https://trash-guides.info/Plex/)

#### Alternative Approach: Separate Libraries

Create separate libraries for 4K:

```
/media/
├── movies/           # 1080p Movies
├── movies-4k/        # 4K Movies (separate library)
├── tv/               # 1080p TV Shows
└── tv-4k/            # 4K TV Shows (separate library)
```

Then in Plex:
- Library "Movies" → /media/movies
- Library "Movies 4K" → /media/movies-4k
- Share only "Movies" with users who don't have 4K devices

### 5.9 Additional Optimizations

#### Read-Only Access for Security

For greater security, configure Plex with read-only access to media:

```bash
# On NAS, export with ro (read-only) option
# In /etc/exports (if direct NFS) or in QNAP NFS settings
/share/data/media 192.168.3.21(ro,sync,no_subtree_check)
```

#### Scheduled Tasks

In **Plex** (web interface): Settings → Scheduled Tasks:
- [ ] **Perform extensive media analysis during maintenance**: Consider disabling if causing slowdowns
- [ ] **Backup database every three days**: ✅ Enabled
- [ ] **Optimize database every week**: ✅ Enabled
- [ ] **Remove old bundles every week**: ✅ Enabled
- [ ] **Remove old cache files every week**: ✅ Enabled

Maintenance schedule: Set during low-usage hours (e.g., 08:00-10:00 or 22:00-23:00)

### 5.10 Configuration Verification

Post-configuration checklist:

- [ ] Libraries added and scan completed
- [ ] Direct Play working on local client
- [ ] LAN Networks configured correctly (devices don't appear as "remote")
- [ ] Hardware transcoding active (verify with `intel_gpu_top` during transcoding)
- [ ] Relay disabled
- [ ] Transcoder temporary directory on RAM/local SSD

#### Test Direct Play

1. Play a file on local client
2. Dashboard → Now Playing
3. Verify it shows "Direct Play" and not "Transcoding"

If it shows "Transcoding":
- Check client quality settings
- Check codec compatibility
- Check subtitles (image subs force transcoding)

---

## Phase 6: Remote Access (Tailscale)

> [!NOTE]
> Tailscale runs as a Docker container on the NAS (always-on) instead of on the Mini PC, so remote access remains available even when the Mini PC is powered off.

See the Tailscale service in `docker/compose.yml` for configuration. Setup steps:

1. Generate an auth key at https://login.tailscale.com/admin/settings/keys
2. Add `TS_AUTHKEY` to `docker/.env.secrets`
3. Start the stack: `make up`
4. Approve subnet routes at https://login.tailscale.com/admin/machines

For full details, see the Tailscale section in `docker/compose.yml` and `docker/.env.secrets.example`.

---

## Phase 7: Proxmox Backup Configuration

### 7.1 Add Backup Storage

If not already done:
Datacenter → Storage → Add → NFS
- ID: nas-backup
- Server: 192.168.3.10
- Export: /share/backup
- Content: VZDump backup file
- NFS Version: 4.1

> [!NOTE]
> Proxmox backups will be saved in an automatic subfolder (`dump/`).

### 7.2 Create Scheduled Backup Job

Datacenter → Backup → Add

| Field | Value |
|-------|--------|
| Storage | nas-backup |
| Schedule | Weekly (Sun 08:00) |
| Selection mode | All |
| Mode | Snapshot |
| Compression | ZSTD |
| Retention | Keep Last: 4 |

### 7.3 Manual Backup

For immediate backup:
Container/VM → Backup → Backup now

---

## Phase 8: Optional Configuration

### 8.1 Reverse Proxy (Optional)

To access services with readable names (e.g., `sonarr.home.local`) instead of IP:port, configure a reverse proxy.

> [!TIP]
> See [reverse-proxy-setup.md](reverse-proxy-setup.md) for the complete guide.

The guide documents:
- **Traefik** (recommended): Docker auto-discovery, configuration via labels
- **Nginx Proxy Manager** (alternative): configuration via WebUI
- **Pi-hole + Tailscale DNS**: same URL from local and remote

### 8.2 Wake-on-LAN (WOL)

The Mini PC can be powered on remotely via Wake-on-LAN, useful for saving energy
when Plex is not in use and powering it on only when needed.

> [!IMPORTANT]
> **Dual-NIC setup:** WOL only works on the integrated Intel NIC (enp2s0), not on the USB-C 2.5GbE adapter. USB ports lose power when the system is off. If you migrated management to the USB-C adapter (see [Section 8.4](#84-network-interface-migration-25gbe-usb-c-adapter)), ensure WOL is configured on the integrated NIC and that the WOL magic packet uses the integrated NIC's MAC address.

#### 8.2.1 Enable WOL in BIOS

1. Power on the Mini PC and press F1 (or F2) to enter BIOS
2. Navigate to: Power → Wake on LAN
3. Set to **Enabled** (or "Primary" if available)
4. Save and exit (F10)

#### 8.2.2 Configure Persistent WOL on Proxmox

```bash
# SSH into Proxmox
ssh root@192.168.3.20

# Install WOL tools
apt install -y ethtool wakeonlan

# Identify network interface (usually enp*, eth0, or nic*)
ip link show
# Note the interface name (e.g., enp2s0, nic1)

# Check current WOL status
ethtool enp2s0 | grep Wake-on
# Expected output:
#   Supports Wake-on: pumbg
#   Wake-on: g
#
# "Supports Wake-on: pumbg" = NIC supports WOL (p=PHY, u=unicast, m=multicast, b=broadcast, g=magic packet)
# "Wake-on: g" = WOL is enabled (magic packet). If "d", WOL is disabled — enable it below

# Enable WOL only if Wake-on shows "d" (replace enp2s0 with your interface)
ethtool -s enp2s0 wol g
```

> [!TIP]
> If `Wake-on: g` is already shown (typically set by BIOS), you can skip the `ethtool -s` command above. However, some drivers reset WOL on reboot even when BIOS enables it, so the persistent configuration below is still recommended as a safeguard.

#### 8.2.3 Make WOL Persistent on Reboot

Create a systemd-networkd configuration file:

```bash
# Identify the integrated NIC (enp*, eth*, nic* — NOT enx* USB adapters)
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(enp|eth|nic)' | head -1)
echo "Detected interface: $IFACE"

# IMPORTANT: if using dual-NIC setup (see Section 8.4), ensure this
# matches the INTEGRATED Intel NIC, not the USB-C adapter.
# USB adapters use enx* names and do NOT support WOL.

# Create persistent WOL configuration
cat > /etc/systemd/network/99-wol.link << EOF
[Match]
Name=$IFACE

[Link]
WakeOnLan=magic
EOF

# Restart networking
systemctl restart systemd-networkd

# Verify applied configuration
ethtool $IFACE | grep Wake-on
# Should show: Wake-on: g
```

#### 8.2.4 Note MAC Address

```bash
# Get MAC address for WOL
ip link show $IFACE | grep ether
# Example output: link/ether AA:BB:CC:DD:EE:FF brd ff:ff:ff:ff:ff:ff

# Note the MAC address (AA:BB:CC:DD:EE:FF)
```

Save the MAC address in a safe place - you'll need it to send the magic packet.

#### 8.2.5 Test Wake-on-LAN

**From another device on the same network (e.g., NAS or Desktop PC):**

```bash
# Install wakeonlan if not present
apt install -y wakeonlan  # Debian/Ubuntu
# or
brew install wakeonlan    # macOS

# Shut down the Mini PC
ssh root@192.168.3.20 "shutdown -h now"

# Wait 30 seconds for complete shutdown

# Send magic packet (replace with your MAC)
wakeonlan AA:BB:CC:DD:EE:FF

# Verify it powers on
ping 192.168.3.20
```

#### 8.2.6 WOL from iPhone with Shortcuts

You can create an iOS shortcut to power on the Mini PC and open Plex:

1. Open **Shortcuts** app
2. Create new shortcut

**Action 1: Run SSH script** (requires accessible SSH server, e.g., NAS)
- Host: 192.168.3.10 (NAS)
- User: admin
- Script: `wakeonlan AA:BB:CC:DD:EE:FF`

**Action 2: Wait** 30 seconds

**Action 3: Open URL**
- URL: `plex://` (opens Plex app)

**Alternative without SSH**: Use dedicated apps like "Wake On Lan" or "Mocha WOL" from the App Store.

#### 8.2.7 WOL via Tailscale (Remote)

To power on the Mini PC when away from home:

1. The NAS (192.168.3.10) must be always on (it is)
2. Tailscale runs on the NAS as a Docker container (see `docker/compose.yml`)
3. From remote, connect via Tailscale to the NAS
4. Execute: `wakeonlan AA:BB:CC:DD:EE:FF`

```bash
# Example from remote terminal via Tailscale
ssh admin@192.168.3.10 "wakeonlan AA:BB:CC:DD:EE:FF"
```

#### 8.2.8 WOL Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| WOL doesn't work | Not enabled in BIOS | Verify BIOS settings |
| Wake-on: d after reboot | Config not persistent | Verify 99-wol.link |
| Works only sometimes | Fast Startup Windows | Not applicable (Proxmox) |
| Doesn't work from another VLAN | Broadcast doesn't pass | Send from same VLAN |
| Doesn't work via Tailscale | Magic packet not routed | Use device on LAN |

> [!NOTE]
> The WOL magic packet is Layer 2 broadcast, so it must be sent from a device on the same VLAN/subnet as the Mini PC.

### 8.3 Intel Quick Sync GPU Passthrough for LXC

The Lenovo ThinkCentre neo 50q Gen 4 Mini PC has an Intel i5-13420H CPU with integrated iGPU that supports Quick Sync
for hardware transcoding in Plex. This drastically reduces CPU load.

#### 8.3.1 Verify iGPU on Proxmox Host

```bash
# SSH into Proxmox
ssh root@192.168.3.20

# Verify DRI (Direct Rendering Infrastructure) device presence
ls -la /dev/dri/
# Expected output:
# drwxr-xr-x 3 root root       100 date time .
# drwxr-xr-x 18 root root     4600 date time ..
# drwxr-xr-x 2 root root        80 date time by-path
# crw-rw---- 1 root video  226,  0 date time card0
# crw-rw---- 1 root render 226, 128 date time renderD128

# Verify Intel driver loaded
lspci -k | grep -A 3 VGA
# Should show "Kernel driver in use: i915"
```

#### 8.3.2 Load Kernel Modules (if necessary)

```bash
# Verify i915 is loaded
lsmod | grep i915

# If not present, load manually
modprobe i915

# Make permanent
echo "i915" >> /etc/modules
```

#### 8.3.3 Configure Device Permissions

```bash
# Identify GID of render and video groups
getent group render video
# Typical output: render:x:108:  video:x:44:

# Note the numbers (108 and 44 in the example)
```

#### 8.3.4 Configure LXC for GPU Passthrough

**IMPORTANT**: Stop the container before modifying the configuration.

```bash
# Stop Plex container
pct stop 100

# Edit LXC configuration
nano /etc/pve/lxc/100.conf
```

Add the following lines at the end of the file:

```bash
# Intel iGPU Passthrough for Quick Sync
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/dri/card0 dev/dri/card0 none bind,optional,create=file
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
```

> [!NOTE]
> `c 226:0` is card0, `c 226:128` is renderD128. The major number 226 is standard for DRI devices on Linux.

#### 8.3.5 Start Container and Verify

```bash
# Start container
pct start 100

# Enter container
pct enter 100

# Verify available devices
ls -la /dev/dri/
# Should show card0 and renderD128

# Install vainfo to test Quick Sync
apt update && apt install -y vainfo

# Test VA-API (Video Acceleration API)
vainfo
# Expected output with list of supported profiles (H.264, HEVC, VP9, AV1)
```

Example `vainfo` output for i5-13420H:
```
libva info: VA-API version 1.17.0
libva info: Trying to open /usr/lib/x86_64-linux-gnu/dri/iHD_drv_video.so
libva info: Found init function __vaDriverInit_1_17
libva info: va_openDriver() returns 0
vainfo: VA-API version: 1.17 (libva 2.12.0)
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 23.1.1
vainfo: Supported profile and entrypoints
      VAProfileH264Main               : VAEntrypointVLD
      VAProfileH264Main               : VAEntrypointEncSlice
      VAProfileHEVCMain               : VAEntrypointVLD
      VAProfileHEVCMain               : VAEntrypointEncSlice
      ...
```

#### 8.3.6 Configure Plex for Hardware Transcoding

1. Access **Plex** web interface: `http://192.168.3.21:32400/web`
2. Settings → Transcoder
3. [ ] **Hardware transcoding**: Enabled (requires Plex Pass)
4. [ ] **Use hardware acceleration when available**: Checked
5. [ ] **Use hardware-accelerated video encoding**: Checked

#### 8.3.7 Verify Active Hardware Transcoding

During playback with transcoding:

```bash
# In Plex container
# Monitor Intel GPU usage
apt install -y intel-gpu-tools
intel_gpu_top
```

Or in Plex Dashboard → Now Playing, verify it shows "(hw)" next to
the codec during transcoding.

#### 8.3.8 GPU Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| /dev/dri doesn't exist | i915 driver not loaded | `modprobe i915` |
| Permission denied | Wrong cgroup permissions | Verify LXC config |
| vainfo fails | Missing drivers in container | `apt install intel-media-va-driver-non-free` |
| Still software transcoding | Plex Pass not active | Verify subscription |
| renderD128 not present | Kernel too old | Update Proxmox |

> [!IMPORTANT]
> Hardware transcoding requires **Plex Pass** subscription.

### 8.4 Network Interface Migration (2.5GbE USB-C Adapter)

The Mini PC has two network interfaces:
- **Integrated**: 1x 1GbE RJ45 (Intel) — supports WOL
- **USB-C adapter**: 1x 2.5GbE (StarTech US2GC30) — does NOT support WOL

This section documents how to move Proxmox management to the 2.5GbE adapter while keeping the integrated 1GbE connected for Wake-on-LAN only.

> [!IMPORTANT]
> USB network adapters cannot receive magic packets when the system is powered off (USB ports lose power in S5 state). The integrated Intel NIC must remain connected to the switch for WOL to work.

#### 8.4.1 Physical Cabling

Connect both interfaces to the switch:

| Interface | Switch Port | Type | Profile | Purpose |
|-----------|-------------|------|---------|---------|
| 2.5GbE USB adapter | Port 6 | 1GbE | Servers (VLAN 3) | Management + traffic |
| 1GbE integrated | Port 5 | 1GbE | Servers (VLAN 3) | WOL only (no IP) |

#### 8.4.2 Identify Interface Names

```bash
# SSH into Proxmox
ssh root@192.168.3.20

# List all network interfaces
ip link show

# Identify which is which:
# - Integrated Intel NIC: typically enp* (e.g., enp2s0)
# - USB-C adapter: typically enx* (MAC-based name) or usb0
#
# Verify with ethtool:
ethtool enp2s0 | grep -i speed    # Should show 1000Mb/s
ethtool enxAABBCCDDEEFF | grep -i speed  # Should show 2500Mb/s
```

> [!TIP]
> USB network adapters on Linux typically get a name starting with `enx` followed by the MAC address (e.g., `enxaabbccddeeff`). This naming is deterministic and won't change across reboots.

#### 8.4.3 Install DHCP Client

> [!IMPORTANT]
> The Proxmox installer sets a static IP. This step switches the host to DHCP so the UDM-SE DHCP reservation assigns `192.168.3.20` based on MAC address. This must be done **before** editing the network configuration.

Proxmox VE 9+ does not ship with `dhclient`. Install `dhcpcd` as the DHCP client:

```bash
ssh root@192.168.3.20

# Install dhcpcd and remove the (non-functional) ISC client
apt update
apt -y install dhcpcd
apt -y purge isc-dhcp-common isc-dhcp-client

# Restrict dhcpcd to only manage the bridge interface
# (prevents it from requesting IPs on physical NICs or tap devices)
cat >> /etc/dhcpcd.conf << 'EOF'
allowinterfaces vmbr0
EOF
```

> [!NOTE]
> On PVE 8.x, the ISC `dhclient` is available by default and no extra package is needed. You can skip the install step, but the `allowinterfaces` restriction is still recommended if using `dhcpcd`.

#### 8.4.4 Reconfigure Network Interfaces

1. [ ] Backup current configuration:

```bash
cp /etc/network/interfaces /etc/network/interfaces.bak
```

2. [ ] Edit `/etc/network/interfaces`:

```bash
nano /etc/network/interfaces
```

3. [ ] Replace the network configuration with (adjust interface names to match your system):

```
auto lo
iface lo inet loopback

# Integrated 1GbE Intel NIC — WOL only, no IP
auto enp2s0
iface enp2s0 inet manual
    # Keep link up for WOL but no IP address

# 2.5GbE USB-C adapter — Proxmox management
auto enxAABBCCDDEEFF
iface enxAABBCCDDEEFF inet manual

# Bridge on 2.5GbE adapter (management + LXC containers)
# IP 192.168.3.20 assigned via DHCP reservation on UDM-SE
auto vmbr0
iface vmbr0 inet dhcp
    bridge-ports enxAABBCCDDEEFF
    bridge-stp off
    bridge-fd 0
```

Key changes from the installer defaults:
- `vmbr0` changed from `inet static` to `inet dhcp` — no `address`/`gateway` lines
- Bridge ports moved from the integrated NIC to the USB-C adapter
- Integrated NIC kept as `manual` (link up for WOL, no IP)

> [!WARNING]
> **This will disconnect your SSH session.** You'll need physical access (monitor + keyboard) or apply via the Proxmox WebUI (System → Network) if the change doesn't work.

#### 8.4.5 Apply Configuration

**Option A: Via Proxmox WebUI (safer)**

1. Navigate to: proxmox → System → Network
2. Edit `vmbr0`: change Bridge ports from the old interface to the USB-C adapter name
3. Remove the static IPv4 address and gateway, set IPv4/CIDR to `dhcp`
4. Add the integrated NIC as a standalone interface (no IP, manual)
5. Click "Apply Configuration"

**Option B: Via command line**

```bash
# Apply the new configuration (this WILL disconnect SSH if connected via the old interface)
ifreload -a

# If something goes wrong, reboot — Proxmox will apply /etc/network/interfaces on boot
# Worst case, connect monitor + keyboard and restore backup:
# cp /etc/network/interfaces.bak /etc/network/interfaces && ifreload -a
```

#### 8.4.6 Verify Configuration

```bash
# Verify bridge is on the 2.5GbE adapter
bridge link show
# Should show enxAABBCCDDEEFF as member of vmbr0

# Verify IP was assigned via DHCP
ip addr show vmbr0
# Should show 192.168.3.20/24 (from UDM-SE DHCP reservation)

# Verify DHCP lease is active
cat /var/lib/dhcpcd/vmbr0.lease 2>/dev/null || cat /var/lib/dhcp/dhclient.vmbr0.leases 2>/dev/null
# Should show lease with fixed-address 192.168.3.20

# Verify 2.5GbE link speed
ethtool enxAABBCCDDEEFF | grep Speed
# Should show: Speed: 2500Mb/s

# Verify integrated NIC is up (for WOL) but has no IP
ip addr show enp2s0
# Should show UP but no inet address

# Verify connectivity
ping 192.168.3.1   # Gateway
ping 192.168.3.10  # NAS
```

#### 8.4.7 Update WOL Configuration

Since WOL must use the integrated NIC, update the persistent WOL configuration:

```bash
# WOL must target the integrated NIC (enp2s0), NOT the USB adapter
cat > /etc/systemd/network/99-wol.link << EOF
[Match]
# Match the integrated Intel NIC by MAC address for reliability
MACAddress=XX:XX:XX:XX:XX:XX

[Link]
WakeOnLan=magic
EOF

# Restart networking
systemctl restart systemd-networkd

# Verify WOL is enabled on the integrated NIC
ethtool enp2s0 | grep Wake-on
# Should show: Wake-on: g
```

> [!NOTE]
> **Update your saved MAC address.** The MAC for WOL magic packets must be the integrated NIC's MAC (enp2s0), not the USB adapter's.

#### 8.4.8 Dual-NIC Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| USB adapter not detected | Driver missing | `apt install r8152` or check `dmesg \| grep usb` |
| Interface name changes after reboot | USB enumeration order | Use `enx*` MAC-based name (stable) |
| No link on 2.5GbE | Wrong switch port speed | Verify switch port is 2.5GbE (ports 13-16) |
| WOL stopped working | WOL configured on wrong NIC | Must be on integrated NIC (enp2s0) |
| LXC containers lose network | Bridge on wrong interface | Verify `bridge-ports` in vmbr0 |
| Lost SSH after change | New interface not up | Use Proxmox console (monitor+keyboard) to fix |
| No IP after switching to DHCP | `dhclient` missing (PVE 9+) | Install `dhcpcd` (see [8.4.3](#843-install-dhcp-client)) |
| Wrong IP from DHCP | Reservation not set | Check UDM-SE DHCP reservation matches MAC of `enxAABBCCDDEEFF` |

---

## Final Verification

### Proxmox Checklist

- [ ] WebUI accessible: `https://192.168.3.20:8006`
- [ ] No errors in System → Syslog
- [ ] NFS storage mounted and accessible
- [ ] Backup job configured

### Plex Checklist

- [ ] WebUI accessible: `http://192.168.3.21:32400/web`
- [ ] Libraries synced
- [ ] Local playback working
- [ ] Remote access via Tailscale working (Tailscale runs on NAS — see `docker/compose.yml`)

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Container won't start | Insufficient resources | Increase RAM/CPU |
| NFS mount fails | Permissions or network | Verify NFS export on NAS |
| Plex doesn't see media | Wrong mount point | Verify /media in container |
| Slow transcoding | No GPU | Enable hardware acceleration |
| Backup fails | Insufficient space | Verify retention policy |

---

## Useful Commands

```bash
# Container status
pct list

# Enter container
pct enter 100

# Container log
pct console 100

# Restart container
pct restart 100

# Update Plex (in container)
apt update && apt upgrade plexmediaserver -y

# Verify NFS mount
df -h | grep nfs
```

---

## Next Steps

After completing Proxmox setup:

1. → Proceed with [Backup Configuration](../operations/runbook-backup-restore.md)
2. → Return to [START_HERE.md](../../START_HERE.md) Phase 7
