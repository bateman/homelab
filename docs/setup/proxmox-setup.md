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
> The Proxmox installer requires a static IP. Use `192.168.3.20` during installation. For dual-NIC configuration (adding the integrated NIC for Wake-on-LAN), see [Section 8.4](#84-dual-nic-configuration-25gbe-usb-c--1gbe-integrated).

| Field | Value |
|-------|--------|
| Management Interface | USB 2.5GbE adapter (`enx*`) — see tip below |
| Hostname (FQDN) | proxmox.servers.local |
| IP Address | 192.168.3.20 |
| Netmask | 255.255.255.0 (/24) |
| Gateway | 192.168.3.1 |
| DNS Server | 192.168.3.1 (or 1.1.1.1) |

> [!TIP]
> **Which NIC to select?** During installation, Proxmox lists detected network interfaces. If the USB 2.5GbE adapter (StarTech US2GC30) is connected, it appears as `enx*` (MAC-based name). The integrated Intel NIC appears as `enp*`. Select the **USB adapter** (`enx*`) — this gives 2.5GbE throughput for management and keeps the integrated NIC available for Wake-on-LAN (USB ports lose power when the system is off, so only the integrated NIC can receive WoL magic packets). After installation, add the integrated NIC for WoL — see [Section 8.4.3](#843-add-integrated-nic-for-wol-installed-on-usb-adapter).

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

## SSH Key Setup (Workstation → Proxmox)

Set up passwordless SSH before proceeding — all remaining phases use `ssh root@192.168.3.20`.

**On your workstation** (Mac/PC):

```bash
# Generate key (skip if you already have ~/.ssh/id_ed25519)
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/proxmox

# Copy public key to Proxmox host
ssh-copy-id -i ~/.ssh/proxmox.pub root@192.168.3.20
```

Add to `~/.ssh/config` for convenience:

```
Host proxmox
    HostName 192.168.3.20
    User root
    IdentityFile ~/.ssh/proxmox
```

Verify: `ssh proxmox` should connect without a password prompt.

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

# Add no-subscription repo (DEB822 format for Proxmox 9+/trixie)
cat > /etc/apt/sources.list.d/pve-no-subscription.sources << 'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
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

To persist the patch across Proxmox upgrades, create a dpkg post-install hook:

```bash
cat > /etc/apt/apt.conf.d/99-no-subscription-popup << 'EOF'
DPkg::Post-Invoke {
    "if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then sed -Ezi 's/(Ext.Msg.show\(\{[^}]*license[^}]*\}\);)/void(0);/g' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy 2>/dev/null || true; fi";
};
EOF
```

> [!NOTE]
> The hook runs after every `dpkg` operation. It checks if `proxmoxlib.js` exists, re-applies the patch, and restarts the proxy. The `|| true` ensures apt never fails due to the hook.

### 3.4 Configure NFS Storage from NAS

#### Prerequisite: Enable NFS Export on QNAP

Before configuring NFS on Proxmox, enable NFS export on the NAS:

1. Access QTS: `https://192.168.3.10:5001`
2. Control Panel → Win/Mac/NFS/WebDav → NFS Service
3. [ ] Enable NFS v3 and/or NFS v4 Service
4. Control Panel → Shared Folders
5. For each folder to export (data, backup):
   - Select folder → Edit Shared Folder Permissions → Select permission type: NSF host access
   - Host/IP: `192.168.3.20` (Proxmox)
   - Permission: `read/write`
   - Squash: `Squash no users`
   - Apply

Verify available exports:
```bash
# From Proxmox (showmount not available on QNAP BusyBox)
showmount -e 192.168.3.10
# Should show /share/data/media and /share/backup

# From NAS
cat /etc/exports
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
> **After creation — configure SSH key with `ssh-copy-id`:**
>
> If you skipped the SSH Public Key field during creation, copy your key to the running container:
> ```bash
> ssh-copy-id -i ~/.ssh/proxmox_plex.pub root@192.168.3.21
> ```
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

### 4.3 Enable Auto-Start

Enable the container to start automatically when Proxmox boots:

```bash
pct set 100 -onboot 1
```

Or via WebUI: select CT 100 → Options → Start at boot → ✅ Yes

> [!IMPORTANT]
> Without this, the Plex LXC stays stopped after a Proxmox reboot or power cycle. This is critical if using Wake-on-LAN scheduling (see [energy saving strategies](../operations/energy-saving-strategies.md)) — the Mini PC wakes but Plex won't be available until the container is manually started.

Verify:
```bash
pct config 100 | grep onboot
# Should show: onboot: 1
```

### 4.4 Configure NFS Mount Point

Before starting, add a bind mount for media (container must be stopped):

```bash
# On Proxmox host
pct set 100 -mp0 /mnt/pve/nas-media,mp=/media
```

> [!WARNING]
> Do **not** use the WebUI "Add → Mount Point" with "Storage: nas-media" — that creates
> a virtual disk image on the NAS, not a bind mount of the media files.
> Use the CLI command above instead.

Verify the mount point was set correctly:

```bash
pct config 100 | grep mp
# Should show: mp0: /mnt/pve/nas-media,mp=/media
# NOT: mp0: nas-media:100/vm-100-disk-0.raw (this is wrong — it's a disk image)
```

### 4.5 Start Container and Install Plex

```bash
# Start container
pct start 100

# Enter container
pct enter 100

# Update system and install prerequisites
apt update && apt upgrade -y
apt install -y curl gnupg locales

# Fix locale warnings (LXC containers have minimal locale config)
sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
# Exit and re-enter container (exit → pct enter 100) for locale to take effect

# Add Plex repository
curl https://downloads.plex.tv/plex-keys/PlexSign.key | gpg --dearmor -o /usr/share/keyrings/plex-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/plex-archive-keyring.gpg] https://downloads.plex.tv/repo/deb public main" > /etc/apt/sources.list.d/plexmediaserver.list

# Workaround: Plex GPG key uses SHA1 binding signatures, rejected by Debian Trixie's
# Sequoia PGP policy since 2026-02-01. Extend the deadline until Plex updates their key.
# See: https://forums.plex.tv/t/debian-13-gpg-key-is-not-bound-no-binding-signature-at-time-sha1/919206
mkdir -p /etc/crypto-policies/back-ends
cp /usr/share/apt/default-sequoia.config /etc/crypto-policies/back-ends/apt-sequoia.config
sed -i 's/^sha1.second_preimage_resistance.*/sha1.second_preimage_resistance = 2027-01-01/' /etc/crypto-policies/back-ends/apt-sequoia.config

# Install Plex
apt update
apt install plexmediaserver -y

# Verify status
systemctl status plexmediaserver
```

### Verify NFS Mount

Before configuring Plex, verify that the NFS mount is working and permissions are correct:

```bash
# Check mount is active
df -h /media
# Should show 192.168.3.10:/share/data/media

# Verify directory structure exists
ls -la /media/
# Should show: movies/ tv/ music/

# Verify Plex user can read files (plex user is created by the package)
sudo -u plex ls /media/movies/

# Check UID/GID match (should match PUID/PGID from Docker stack)
stat -c '%u:%g' /media/movies/
# Should show 1001:100 (dockeruser)
```

> [!WARNING]
> If `/media` is empty or shows "Permission denied", check:
> 1. NFS export permissions on QNAP (Section 3.4)
> 2. Mount point configuration: `pct config 100 | grep mp0`
>    - Must show `/mnt/pve/nas-media,mp=/media`
>    - If it shows `nas-media:100/vm-100-disk-0.raw`, you have a disk image instead of a bind mount — see Section 4.4
> 3. NFS service status on NAS: `showmount -e 192.168.3.10`

### Verify Plex

Open browser: `http://192.168.3.21:32400/web`

---

## Phase 5: Plex Configuration (Trash Guides)

> [!NOTE]
> This section follows the [official Trash Guides recommendations](https://trash-guides.info/Plex/Tips/Plex-media-server/) to optimize Plex Media Server.

### 5.1 Claim Server (Initial Setup)

Plex requires the server to be "claimed" (linked to your Plex account). New servers only allow claiming from **localhost**, so you need an SSH tunnel since Plex runs inside an LXC container.

**From your workstation** (the machine where you'll open the browser):

```bash
# Create SSH tunnel: local port 8888 → Plex LXC port 32400 via Proxmox
ssh -L 8888:192.168.3.21:32400 root@192.168.3.20
```

Then open your browser and go to:

```
http://localhost:8888/web
```

> [!IMPORTANT]
> You **must** use `localhost:8888`, not `192.168.3.21:32400`. Plex checks the connecting IP — only localhost is allowed to claim an unclaimed server.

1. [ ] Login with your Plex account (or create one)
2. [ ] Name the server: "Homelab Plex"
3. [ ] Skip the "Add Library" wizard (we'll configure libraries properly in 5.2)
4. [ ] Close the SSH tunnel (Ctrl+C) once claimed

After claiming, access Plex normally at `http://192.168.3.21:32400/web`.

### 5.2 Add Libraries

> [!NOTE]
> This Plex instance serves **Movies/TV only**. Music runs on a separate always-on Plex server on the NAS (Docker container `plex-music` in `compose.media.yml`). Home Assistant manages this Mini PC's power state — waking it via WoL when Fire TV turns on, and shutting it down via Proxmox API when idle.

Add Library → Movies:
- Name: Movies
- Folders: /media/movies

Add Library → TV Shows:
- Name: TV Shows
- Folders: /media/tv

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
| Enable HEVC video Encoding (experimental) | Never | Leave disabled unless clients support HEVC |
| Hardware transcoding device | Auto | Auto-detects Intel iGPU |
| Maximum simultaneous GPU transcodes | Unlimited | Adjust if sharing GPU resources |
| Maximum simultaneous CPU transcodes | Unlimited | Fallback when GPU can't handle a codec |
| Maximum simultaneous background video transcode | 1 | Limits optimizer/download I/O impact |

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
| Custom server access URLs | `http://192.168.3.21:32400` | Add Tailscale URL after setup (see [Phase 6](#phase-6-remote-access-tailscale)) |
| LAN Networks | `192.168.3.0/24,192.168.4.0/24,100.64.0.0/10` | **Important**: Include Tailscale CGNAT range so Tailscale clients get LAN treatment (Direct Play, no bandwidth limits) |
| Treat WAN IP As LAN Bandwidth | ✅ Enabled | Useful if you have DNS rebinding protection active |
| Remote Access | ❌ Disabled | **Critical**: Do NOT enable. We use Tailscale instead of Plex's built-in remote access (which requires port forwarding) |

> [!IMPORTANT]
> **LAN Networks** must include `100.64.0.0/10` (Tailscale CGNAT range). Without this, Tailscale clients appear as "remote" and Plex applies bandwidth limits / forces transcoding. See [Phase 6](#phase-6-remote-access-tailscale) for details.

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
- [ ] LAN Networks configured correctly with Tailscale CGNAT (`192.168.3.0/24,192.168.4.0/24,100.64.0.0/10`)
- [ ] Hardware transcoding active (verify with `intel_gpu_top` during transcoding)
- [ ] Relay disabled
- [ ] Remote Access disabled (using Tailscale instead)
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
> Tailscale runs as a Docker container on the NAS instead of on the Mini PC, so remote access remains available when the Mini PC is powered off (during NAS uptime hours, 07:00–01:00). The NAS subnet router advertises `192.168.3.0/24` (Servers VLAN), making Plex at `192.168.3.21:32400` reachable from any Tailscale-connected device.

For the complete Tailscale setup guide, see **[Tailscale Setup](tailscale-setup.md)**. In summary:

1. Generate an auth key at https://login.tailscale.com/admin/settings/keys
2. Add `TS_AUTHKEY` to `docker/.env.secrets`
3. Start the stack: `make up`
4. Approve subnet routes at https://login.tailscale.com/admin/machines

### 6.1 Why Tailscale Instead of Port Forwarding

| Approach | Security | Setup | Double NAT |
|----------|----------|-------|------------|
| **Tailscale (chosen)** | Encrypted mesh, no exposed ports | Simple | No issue (NAT traversal) |
| Port forwarding (32400) | Service exposed to Internet | Requires UDM-SE + Iliad Box | Doesn't work (Double NAT) |
| Plex Relay | Encrypted but ~2 Mbps limit | Automatic | Works |

Tailscale is the best option: zero exposed ports, full bandwidth, and works despite the Double NAT limitation (see [firewall-config.md — Double NAT](../network/firewall-config.md#double-nat-known-limitation)).

### 6.2 Configure Plex Network Settings for Tailscale

In **Plex** web interface (`http://192.168.3.21:32400/web`): Settings → Network

#### 6.2.1 Disable Remote Access

Settings → Remote Access → **Disable Remote Access**

Plex's built-in remote access requires port forwarding (which doesn't work with Double NAT). With Tailscale, remote devices reach Plex through the mesh network using the local IP — no port forwarding needed.

> [!WARNING]
> Do NOT enable "Remote Access". It's unnecessary with Tailscale and would attempt to punch through the firewall via UPnP/NAT-PMP.

#### 6.2.2 Add Tailscale Subnet to LAN Networks

Settings → Network → **LAN Networks**:

```
192.168.3.0/24,192.168.4.0/24,100.64.0.0/10
```

| Subnet | Purpose |
|--------|---------|
| `192.168.3.0/24` | Servers VLAN (local) |
| `192.168.4.0/24` | Media VLAN (local) |
| `100.64.0.0/10` | Tailscale CGNAT range |

> [!IMPORTANT]
> `100.64.0.0/10` is the Tailscale IP range. Without it, Tailscale clients appear as "remote" in Plex, which causes:
> - Bandwidth throttling (remote streaming quality limits)
> - Forced transcoding instead of Direct Play
> - Incorrect "remote" badge on the Plex dashboard

#### 6.2.3 Disable Relay

Settings → Network → **Enable Relay**: ❌ Disabled

Relay is limited to ~2 Mbps. With Tailscale providing full-bandwidth connectivity, the relay is unnecessary and would degrade quality if used as fallback.

### 6.3 Configure Tailscale Client (Remote Devices)

Install Tailscale on each device that needs remote Plex access:

| Platform | Install | Notes |
|----------|---------|-------|
| iPhone/iPad | [App Store](https://apps.apple.com/app/tailscale/id1470499037) | Always-on VPN mode recommended |
| Android | [Google Play](https://play.google.com/store/apps/details?id=com.tailscale.ipn) | Always-on VPN mode recommended |
| macOS | [Mac App Store](https://apps.apple.com/app/tailscale/id1475387142) | Menu bar app |
| Windows | [tailscale.com/download](https://tailscale.com/download) | System tray app |

After installing:
1. Log in with the same Tailscale account
2. Tailscale connects automatically
3. Access Plex at `http://192.168.3.21:32400/web` — same URL as local

### 6.4 Configure Plex App on Remote Clients

In the Plex app on each remote device:

1. **Quality** → Remote Streaming → **Maximum / Original**
   - Since Tailscale provides full bandwidth, treat remote like local
2. **Direct Play**: ✅ Enabled
3. **Direct Stream**: ✅ Enabled

> [!WARNING]
> **Cellular quality is capped separately.** Plex and Plexamp have independent quality settings for cellular (mobile data) that default to low values. Without changing these, streaming over mobile data will be slow and heavily transcoded — even though Tailscale treats you as local.

#### 6.4.1 Plex (Video) — Cellular Quality

Settings → Video & Audio → **Cellular Quality** → **Maximum / Original**

The default is **720p HD / 2 Mbps**, which forces the server to transcode all video down to 2 Mbps. With Tailscale + 5G/4G, there is no reason to limit this.

#### 6.4.2 Plexamp (Music) — Cellular Quality

> [!NOTE]
> These are **client-side** settings for the Plexamp app. The Music Plex **server** runs on the NAS — see [NAS Setup → Plex Music Configuration](nas-setup.md#plex-music-configuration) for server-side library and network settings.

Settings → Quality → **Dati cellulare / Cellular Data** → **Maximum**

The default is **128 Kbps**, which forces FLAC files to be transcoded to 128 Kbps Opus — a massive quality loss. A typical FLAC track is 800–1400 Kbps, well within mobile data speeds.

Also set **Bitrate di conversione / Conversion Bitrate** to the highest value (320 Kbps) as a fallback, so if conversion ever kicks in it uses acceptable quality.

> [!TIP]
> With Tailscale + `100.64.0.0/10` in LAN Networks, Plex treats your remote device as "local". You get the same Direct Play quality as if you were at home — but only if the **client-side** quality settings (including cellular) are set to Maximum.

### 6.5 Verify Remote Access

From a remote device (connected to Tailscale, NOT on home WiFi):

```bash
# 1. Verify Tailscale is connected
tailscale status

# 2. Ping the Plex LXC container
tailscale ping 192.168.3.21

# 3. Verify Plex is reachable
curl -s -o /dev/null -w "%{http_code}" http://192.168.3.21:32400/web
# Expected: 200

# 4. Open Plex in browser
# http://192.168.3.21:32400/web
```

On the Plex dashboard, your remote device should appear as **local** (not "remote") — confirming that the `100.64.0.0/10` LAN Networks setting is working.

### 6.6 Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Plex shows device as "remote" | Missing Tailscale CGNAT in LAN Networks | Add `100.64.0.0/10` to Settings → Network → LAN Networks |
| Remote playback buffers/transcodes | Quality set to "limited" for remote | Set remote quality to Maximum/Original in client settings |
| Slow streaming on mobile data | Cellular quality capped (separate from Wi-Fi/remote) | Plex app: Cellular Quality → Maximum. Plexamp: Cellular Data → Maximum (see [Section 6.4](#64-configure-plex-app-on-remote-clients)) |
| Can't reach Plex from remote | Tailscale subnet routes not approved | Approve in [Tailscale Admin](https://login.tailscale.com/admin/machines) → nas-tailscale → Edit route settings |
| Can't reach Plex from remote | Mini PC is off (energy saving) | Wake via WOL (see [Section 8.2](#82-wake-on-lan-wol)) |
| Plex relay active (slow ~2 Mbps) | Relay enabled as fallback | Disable relay in Settings → Network |

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

> [!IMPORTANT]
> **Dual-NIC setup:** WOL only works on the integrated Intel NIC (nic0), not on the USB-C 2.5GbE adapter. USB ports lose power when the system is off. If you have a dual-NIC setup (see [Section 8.4](#84-dual-nic-configuration-25gbe-usb-c--1gbe-integrated)), ensure WOL is configured on the integrated NIC and that the WOL magic packet uses the integrated NIC's MAC address.

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
# Note the interface name (e.g., nic0, enp2s0)

# Check current WOL status
ethtool nic0 | grep Wake-on
# Expected output:
#   Supports Wake-on: pumbg
#   Wake-on: g
#
# "Supports Wake-on: pumbg" = NIC supports WOL (p=PHY, u=unicast, m=multicast, b=broadcast, g=magic packet)
# "Wake-on: g" = WOL is enabled (magic packet). If "d", WOL is disabled — enable it below

# Enable WOL only if Wake-on shows "d" (replace nic0 with your interface)
ethtool -s nic0 wol g
```

> [!TIP]
> If `Wake-on: g` is already shown (typically set by BIOS), you can skip the `ethtool -s` command above. However, some drivers reset WOL on reboot even when BIOS enables it, so the persistent configuration below is still recommended as a safeguard.

#### 8.2.3 Make WOL Persistent on Reboot

Proxmox uses `ifupdown` (`/etc/network/interfaces`), not `systemd-networkd`. Use a `post-up` hook to enable WOL on every boot:

```bash
# Edit network interfaces
nano /etc/network/interfaces

# Find the integrated NIC stanza and add the post-up line:
#
#   auto nic0
#   iface nic0 inet manual
#       post-up /usr/sbin/ethtool -s nic0 wol g
#
# Replace nic0 with your interface name if different.
# IMPORTANT: if using dual-NIC setup (see Section 8.4), ensure this
# matches the INTEGRATED Intel NIC, not the USB-C adapter.
# USB adapters use enx* names and do NOT support WOL.

# Apply without reboot
ifreload -a

# Verify applied configuration
ethtool nic0 | grep Wake-on
# Should show: Wake-on: g
```

> [!WARNING]
> Do **not** use `systemd-networkd` `.link` files (e.g., `99-wol.link`) — Proxmox's networking is managed by `ifupdown`, so `.link` files are silently ignored.

#### 8.2.4 Note MAC Address

```bash
# Get MAC address for WOL
ip link show nic0 | grep ether
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
- Script: `/opt/bin/wakeonlan AA:BB:CC:DD:EE:FF`

**Action 2: Wait** 30 seconds

**Action 3: Open URL**
- URL: `plex://` (opens Plex app)

**Alternative without SSH**: Use dedicated apps like "Wake On Lan" or "Mocha WOL" from the App Store.

#### 8.2.7 WOL via Tailscale (Remote)

To power on the Mini PC when away from home:

1. The NAS (192.168.3.10) must be on (available 07:00–00:00 weekdays / 08:00–01:00 weekends)
2. Tailscale runs on the NAS as a Docker container (see `docker/compose.yml`)
3. From remote, connect via Tailscale to the NAS
4. Execute: `/opt/bin/wakeonlan AA:BB:CC:DD:EE:FF`

```bash
# Example from remote terminal via Tailscale
ssh admin@192.168.3.10 "/opt/bin/wakeonlan AA:BB:CC:DD:EE:FF"
```

#### 8.2.8 WOL Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| WOL doesn't work | Not enabled in BIOS | Verify BIOS settings |
| Wake-on: d after reboot | Config not persistent | Add `post-up /usr/sbin/ethtool -s nic0 wol g` to `/etc/network/interfaces` |
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

#### 8.3.3 Identify Device Group IDs

On the **Proxmox host**, find the GIDs for the `render` and `video` groups:

```bash
getent group render video
# Typical output: render:x:108:  video:x:44:
```

Note these GIDs — you'll need them in Section 8.3.5 to grant the Plex user GPU access inside the container.

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

# Create render/video groups with same GIDs as host (use numbers from 8.3.3)
groupadd -g 108 render 2>/dev/null; groupadd -g 44 video 2>/dev/null

# Add plex user to GPU groups
usermod -aG render,video plex

# Restart Plex to pick up new group membership
systemctl restart plexmediaserver

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
libva info: VA-API version 1.22.0
libva info: Trying to open /usr/lib/x86_64-linux-gnu/dri/iHD_drv_video.so
libva info: Found init function __vaDriverInit_1_22
libva info: va_openDriver() returns 0
vainfo: VA-API version: 1.22 (libva 2.22.0)
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 25.2.3 ()
vainfo: Supported profile and entrypoints
      VAProfileH264Main               : VAEntrypointVLD
      VAProfileH264Main               : VAEntrypointEncSliceLP
      VAProfileH264High               : VAEntrypointVLD
      VAProfileH264High               : VAEntrypointEncSliceLP
      VAProfileHEVCMain               : VAEntrypointVLD
      VAProfileHEVCMain               : VAEntrypointEncSliceLP
      VAProfileHEVCMain10             : VAEntrypointVLD
      VAProfileHEVCMain10             : VAEntrypointEncSliceLP
      VAProfileVP9Profile0            : VAEntrypointVLD
      VAProfileVP9Profile0            : VAEntrypointEncSliceLP
      ...
```

#### 8.3.6 Configure Plex for Hardware Transcoding

1. Access **Plex** web interface: `http://192.168.3.21:32400/web`
2. Settings → Transcoder (requires Plex Pass)

| Setting | Value | Notes |
|---------|-------|-------|
| Disable video stream transcoding | Unchecked | Must be unchecked for transcoding to work |
| Use hardware acceleration when available | Checked | Enables Quick Sync decode/encode |
| Use hardware-accelerated video encoding | Checked | Uses GPU for encoding, not just decoding |
| Enable HEVC video Encoding (experimental) | Never | Can cause client compatibility issues |
| Hardware transcoding device | Auto | Auto-detects Intel iGPU |
| Maximum simultaneous GPU transcodes | Unlimited | Adjust if sharing resources |
| Maximum simultaneous CPU transcodes | Unlimited | Fallback when GPU can't handle a codec |
| Maximum simultaneous background video transcode | 1 | Limits optimizer/download I/O impact |
| Background transcoding x264 preset | Very Fast | CPU preset for background transcodes; faster = less CPU |

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

### 8.4 Dual-NIC Configuration (2.5GbE USB-C + 1GbE Integrated)

The Mini PC has two network interfaces:
- **Integrated**: 1x 1GbE RJ45 (Intel) — supports WOL
- **USB-C adapter**: 1x 2.5GbE (StarTech US2GC30) — does NOT support WOL

This section covers configuring both NICs: the USB adapter for Proxmox management and the integrated NIC for Wake-on-LAN.

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
# - Integrated Intel NIC: typically nic* (e.g., nic0) or enp*
# - USB-C adapter: typically enx* (MAC-based name) or usb0
#
# Verify with ethtool:
ethtool nic0 | grep -i speed    # Should show 1000Mb/s
ethtool enxAABBCCDDEEFF | grep -i speed  # Should show 2500Mb/s
```

> [!TIP]
> USB network adapters on Linux typically get a name starting with `enx` followed by the MAC address (e.g., `enxaabbccddeeff`). This naming is deterministic and won't change across reboots.

#### 8.4.3 Add Integrated NIC for WOL (Installed on USB Adapter)

> [!NOTE]
> If you selected the USB 2.5GbE adapter during Proxmox installation ([Section 2.3](#23-network-configuration)), `vmbr0` is already on the USB adapter. You only need to add the integrated NIC for WOL. If you installed on the integrated NIC instead, skip to [Section 8.4.4](#844-bridge-migration-installed-on-integrated-nic).

1. [ ] Backup current configuration:

```bash
cp /etc/network/interfaces /etc/network/interfaces.bak
```

2. [ ] Add the integrated NIC stanza to `/etc/network/interfaces`:

```bash
cat >> /etc/network/interfaces << 'EOF'

# Integrated 1GbE Intel NIC — WOL only, no IP
auto nic0
iface nic0 inet manual
    post-up /usr/sbin/ethtool -s nic0 wol g
EOF
```

> [!TIP]
> Replace `nic0` with your integrated NIC name from [Section 8.4.2](#842-identify-interface-names) if different.

3. [ ] Apply the configuration:

```bash
ifreload -a
```

4. [ ] Verify the integrated NIC is up with no IP:

```bash
ip addr show nic0
# Should show state UP but no inet address
```

5. [ ] Configure WOL on the integrated NIC — follow [Section 8.2.1](#821-enable-wol-in-bios) through [Section 8.2.5](#825-test-wake-on-lan)

#### 8.4.4 Bridge Migration (Installed on Integrated NIC)

> [!NOTE]
> This section is for users who installed Proxmox on the **integrated NIC** (`nic*`/`enp*`) and need to move the bridge to the USB 2.5GbE adapter. If you already installed on the USB adapter, see [Section 8.4.3](#843-add-integrated-nic-for-wol-installed-on-usb-adapter) instead.

##### Install DHCP Client

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

##### Reconfigure Network Interfaces

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
auto nic0
iface nic0 inet manual
    post-up /usr/sbin/ethtool -s nic0 wol g

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
    mtu 9000
```

Key changes from the installer defaults:
- `vmbr0` changed from `inet static` to `inet dhcp` — no `address`/`gateway` lines
- Bridge ports moved from the integrated NIC to the USB-C adapter
- Integrated NIC kept as `manual` (link up for WOL, no IP)

> [!WARNING]
> **This will disconnect your SSH session.** You'll need physical access (monitor + keyboard) or apply via the Proxmox WebUI (System → Network) if the change doesn't work.

##### Apply Configuration

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

##### Verify WOL Configuration

The `post-up` line in the interfaces file above already enables WOL on nic0. Verify it's working:

```bash
# Apply updated interfaces
ifreload -a

# Verify WOL is enabled on the integrated NIC (nic0), NOT the USB adapter
ethtool nic0 | grep Wake-on
# Should show: Wake-on: g
```

> [!NOTE]
> **Update your saved MAC address.** The MAC for WOL magic packets must be the integrated NIC's MAC (nic0), not the USB adapter's.

#### 8.4.5 Verify Configuration (Bridge Migration)

> [!NOTE]
> These checks apply after bridge migration ([Section 8.4.4](#844-bridge-migration-installed-on-integrated-nic)). If you followed [Section 8.4.3](#843-add-integrated-nic-for-wol-installed-on-usb-adapter), verification is already included in those steps.

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
ip addr show nic0
# Should show UP but no inet address

# Verify connectivity
ping 192.168.3.1   # Gateway
ping 192.168.3.10  # NAS
```

#### 8.4.6 Dual-NIC Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| USB adapter not detected | Driver missing | `apt install r8152` or check `dmesg \| grep usb` |
| Interface name changes after reboot | USB enumeration order | Use `enx*` MAC-based name (stable) |
| No link on 2.5GbE | Wrong switch port speed | Verify switch port is 2.5GbE (ports 13-16) |
| WOL stopped working | WOL configured on wrong NIC | Must be on integrated NIC (nic0) |
| LXC containers lose network | Bridge on wrong interface | Verify `bridge-ports` in vmbr0 |
| Lost SSH after change | New interface not up | Use Proxmox console (monitor+keyboard) to fix |
| No IP after switching to DHCP | `dhclient` missing (PVE 9+) | Install `dhcpcd` (see [8.4.4](#844-bridge-migration-installed-on-integrated-nic)) |
| Wrong IP from DHCP | Reservation not set | Check UDM-SE DHCP reservation matches MAC of `enxAABBCCDDEEFF` |

### 8.5 Automatic Plex Updates

Plex is installed via apt inside the LXC container. Use `unattended-upgrades` to automatically install new Plex releases from the official repo.

```bash
# Enter Plex container
pct enter 100

# Install unattended-upgrades
apt update && apt install -y unattended-upgrades

# Fix locale if not done during initial setup (Phase 4)
# Without this, dpkg-reconfigure shows perl locale warnings
apt install -y locales
sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
# Exit and re-enter container (exit → pct enter 100) for locale to take effect

# Enable automatic updates
dpkg-reconfigure -plow unattended-upgrades
# Select "Yes" when prompted
```

Add the Plex repo to the allowed origins (separate file to avoid editing the default config):

```bash
cat > /etc/apt/apt.conf.d/51unattended-upgrades-plex << 'EOF'
// Auto-update Plex Media Server
Unattended-Upgrade::Origins-Pattern {
    "origin=Artifactory,label=Artifactory";
};
EOF
```

Configure update frequency:

```bash
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
```

Verify the configuration:

```bash
# Confirm Plex origin is in the allowed list
unattended-upgrade --dry-run --debug 2>&1 | grep "Allowed origins"
# Should include: origin=Artifactory,label=Artifactory
```

> [!NOTE]
> `unattended-upgrades` runs daily via systemd timer. Plex restarts automatically after package upgrade. Check logs at `/var/log/unattended-upgrades/`.

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
- [ ] Automatic updates configured (Section 8.5)

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
