# Proxmox Setup - Lenovo ThinkCentre neo 50q Gen 4

> Guide for installing Proxmox VE on the Mini PC and configuring Plex with remote access via Tailscale

---

## Prerequisites

- [ ] Lenovo ThinkCentre neo 50q Gen 4 Mini PC rack-mounted
- [ ] Connected to switch port VLAN 3 (Servers)
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

Before configuring NFS on Proxmox, enable NFS export on the NAS:

1. Access QTS: `https://192.168.3.10:5000`
2. Control Panel → Network & File Services → NFS Service
3. [ ] Enable NFS v3 and/or NFS v4 Service
4. Control Panel → Shared Folders
5. For each folder to export (data, backup):
   - Select folder → Edit → NFS Permissions → Add
   - Host/IP: `192.168.3.20` (Proxmox)
   - Permission: `read/write`
   - Squash: `no_root_squash` (for backup)
   - Apply

Verify available exports:
```bash
# From NAS
showmount -e 192.168.3.10
# Should show /share/data/media and /share/backup
```

#### Add NFS Storage in Proxmox

Datacenter → Storage → Add → NFS

| Field | Value |
|-------|--------|
| ID | nas-media |
| Server | 192.168.3.10 |
| Export | /share/data/media |
| Content | Disk image, Container |

Also add storage for backup:

| Field | Value |
|-------|--------|
| ID | nas-backup |
| Server | 192.168.3.10 |
| Export | /share/backup |
| Content | VZDump backup file |

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

**Tab General:**
| Field | Value |
|-------|--------|
| CT ID | 100 |
| Hostname | plex |
| Password | (secure password) |
| SSH Public Key | (optional) |

**Tab Template:**
- Template: debian-13-standard

**Tab Disks:**
| Field | Value |
|-------|--------|
| Storage | local-lvm |
| Disk size | 16 GB |

**Tab CPU:**
- Cores: 4 (or as available)

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

## Phase 6: Tailscale Installation

> [!NOTE]
> Tailscale provides secure remote access without port forwarding

### 6.1 Install on Proxmox Host

```bash
# SSH into Proxmox
ssh root@192.168.3.20

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start and authenticate
tailscale up

# Follow link for browser authentication
```

### 6.2 Configure as Subnet Router

To access the entire local network via Tailscale:

```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
sysctl -p

# Restart Tailscale as subnet router
tailscale up --advertise-routes=192.168.3.0/24,192.168.4.0/24
```

### 6.3 Approve Routes in Tailscale Admin

1. Access https://login.tailscale.com/admin/machines
2. Find "proxmox"
3. Click "..." → Edit route settings
4. Approve the advertised subnet routes

### 6.4 Install Tailscale in Plex Container (Alternative)

If you prefer direct access only to Plex:

```bash
# Enter container
pct enter 100

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

### Verify Tailscale

```bash
# On Proxmox
tailscale status

# From remote device with Tailscale
ping 192.168.3.20  # Should work via Tailscale
```

---

## Phase 7: Proxmox Backup Configuration

### 7.1 Add Backup Storage

If not already done:
Datacenter → Storage → Add → NFS
- ID: nas-backup
- Server: 192.168.3.10
- Export: /share/backup
- Content: VZDump backup file

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

# Identify network interface (usually enp* or eth0)
ip link show
# Note the interface name (e.g., enp2s0)

# Check current WOL status
ethtool enp2s0 | grep Wake-on
# Output: Wake-on: d (disabled) or g (enabled)

# Enable WOL (replace enp2s0 with your interface)
ethtool -s enp2s0 wol g
```

#### 8.2.3 Make WOL Persistent on Reboot

Create a systemd-networkd configuration file:

```bash
# Identify the correct interface name
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(enp|eth)' | head -1)
echo "Detected interface: $IFACE"

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

1. The NAS (192.168.3.10) must be always on
2. Install Tailscale on the NAS
3. From remote, connect via Tailscale to the NAS
4. Execute: `wakeonlan AA:BB:CC:DD:EE:FF`

```bash
# Example from remote terminal via Tailscale
ssh admin@100.x.x.x "wakeonlan AA:BB:CC:DD:EE:FF"
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
- [ ] Remote access via Tailscale working

### Tailscale Checklist

- [ ] `tailscale status` shows connected
- [ ] Subnet routes approved (if configured)
- [ ] Remote access to Plex working

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Container won't start | Insufficient resources | Increase RAM/CPU |
| NFS mount fails | Permissions or network | Verify NFS export on NAS |
| Plex doesn't see media | Wrong mount point | Verify /media in container |
| Tailscale won't connect | Firewall | Verify UDM-SE rules |
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

# Tailscale status
tailscale status

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
