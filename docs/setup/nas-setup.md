# Deployment Checklist — QNAP TS-435XeU

> Complete checklist for initial NAS setup with Container Station and media stack

---

## Pre-Installation Hardware

### Rack and Physical
- [ ] NAS mounted in rack U2 (below vented panel)
- [ ] Side ventilation not obstructed
- [ ] 10G SFP+ cables connected (port 1 to switch)
- [ ] 2.5GbE RJ45 backup cable connected (optional)

### Storage
- [ ] HDDs installed in bays (check compatibility: qnap.com/compatibility)
- [ ] HDDs of same model/capacity for RAID
- [ ] M.2 NVMe SSD for caching installed (optional but recommended)

---

## Initial QTS Setup

### First Boot
- [ ] Connect monitor + keyboard or use Qfinder Pro
- [ ] Access `http://<ip>:8080` or `http://qnapnas.local:8080`
- [ ] Complete initial wizard
- [ ] Update firmware to latest stable version
- [ ] Reboot after update

### Administrator Configuration
- [ ] Change default admin password
- [ ] Create secondary admin user
- [ ] Enable 2FA for admin (Control Panel → Security → 2-Step Verification)
- [ ] Disable default "admin" account (optional, after creating another admin)

### Network Configuration

> IP address (`192.168.3.10`) is assigned via DHCP reservation on the UDM-SE — no static IP configuration needed on the NAS itself. See [`network-setup.md` Phase 4](network-setup.md#phase-4-dhcp-reservations).

- [ ] Verify network adapter is set to **DHCP** (Control Panel → Network → Edit interface → DHCP)
- [ ] Hostname: `qnap-nas` (or chosen name)
- [ ] After connecting to the Servers VLAN switch port, verify the NAS receives `192.168.3.10` from the DHCP reservation
- [ ] Verify MTU 9000 if Jumbo Frames enabled on switch

**Path:** Control Panel → Network & Virtual Switch → Interfaces

---

## Storage Configuration

### Filesystem: ext4

QTS uses **ext4** — this is not a user-configurable option during storage pool or volume creation. ext4 is well suited for this setup:

- Native QTS filesystem with stable, mature support
- Low RAM/CPU overhead
- Hardlinking works perfectly (critical for the media stack)

> [!NOTE]
> ZFS is only available on platforms like TrueNAS or Proxmox. With 16GB RAM installed, ZFS would be viable on those platforms if data integrity were a priority.

### RAID Choice: RAID 5 vs RAID 10

| Aspect | RAID 5 | RAID 10 |
|--------|--------|---------|
| **Usable capacity (4 disks)** | **75%** (3 of 4) | 50% (2 of 4) |
| **Fault tolerance** | 1 disk | 1 disk (2 if in different mirrors) |
| **Read performance** | Good | **Excellent** |
| **Write performance** | Degraded (parity calc) | **Excellent** |
| **Rebuild time** | Long + disk stress | **Fast** |
| **Risk during rebuild** | High (URE can fail) | **Low** |
| **Random I/O (Docker)** | Medium | **Excellent** |
| **Sequential I/O (streaming)** | Good | Good |
| **Cost per TB** | **Lower** | Higher |

**Indicative performance (4x HDD SATA):**
```
                    RAID 5          RAID 10
Sequential Read:    ~400 MB/s       ~400 MB/s
Sequential Write:   ~200 MB/s       ~300 MB/s
Random Read 4K:     ~300 IOPS       ~500 IOPS
Random Write 4K:    ~100 IOPS       ~400 IOPS  ← critical difference for Docker
```

**Recommendation: RAID 10**
- Container Station generates heavy random I/O
- SQLite databases of *arr apps benefit from fast writes
- Safer and faster rebuild
- Instant hardlinking and imports

> [!TIP]
> RAID 5 makes sense if capacity is absolute priority and disk budget is limited.

### Recommended Configuration Summary

| Component | Choice | Reason |
|-----------|--------|--------|
| **Filesystem** | ext4 | QTS default — not user-configurable |
| **RAID** | RAID 10 | I/O performance for Docker, safe rebuild |
| **Volume** | Thick | Preallocated space on Storage Pool; near-identical performance to Static |

---

### Storage Pool
- [ ] Control Panel → Storage & Snapshots → Storage/Snapshots
- [ ] Create → New Storage Pool
- [ ] Select all HDDs (4 disks)
- [ ] RAID type: **RAID 10** (recommended for media server)
  - Alternative for 2 disks: RAID 1 (mirror)
  - Alternative if capacity priority: RAID 5
- [ ] Features screen:
  - Qtier (Auto Tiering): **Disable** — not needed; SSD caching is configured separately below
  - SED (Self-Encrypting Drive): **Disable** — adds overhead and complicates data recovery with no benefit for a homelab media server
- [ ] Configure screen:
  - Pool Guaranteed Snapshot Space: **Uncheck** — not needed for a media server; backups are handled by Duplicati
  - Alert threshold: **80%**
- [ ] Complete creation (time varies based on capacity)

### Volume

> [!NOTE]
> **Why Thick instead of Static?** Static Volumes are created directly on raw disks (RAID groups), bypassing the storage pool layer. Since our disks are already in Storage Pool 1 (required for SSD cache association), Static Volumes are not available. Thick Volumes preallocate the full space on the storage pool, so I/O performance is nearly identical to Static.

- [ ] Storage & Snapshots → Storage Pool 1 → Create → New Volume
- [ ] Volume type: **Thick Volume** (preallocated space, best performance on a storage pool)
- [ ] Allocate all available space (or desired quota)
- [ ] Name: `DataVol1`
- [ ] Advanced settings:
  - Alert threshold: **80%**
  - Create a shared folder on the volume: **Uncheck** — shared folders are created manually in the next step

> [!TIP]
> QTS defaults to **16K bytes per inode** which is ideal for mixed workloads (small Docker configs/SQLite alongside large media files). If you ever need to change it, use Storage & Snapshots → Volume → Actions → Format.

### SSD Cache (if M.2 present)

> [!IMPORTANT]
> Create the SSD cache **after** the volume exists — QTS requires a volume to associate the cache with.

- [ ] Storage & Snapshots → Cache Acceleration
- [ ] Create
- [ ] Select M.2 SSD
- [ ] RAID type: Single (only option with one SSD)
- [ ] Cache mode: **Read-Write** (recommended for Container Station)
- [ ] Configure screen:
  - Over-provisioning: **10%** (default) — reserves space for SSD wear leveling and garbage collection
  - Cache Mode: **Random I/O** — Docker containers and *arr SQLite databases generate random I/O; sequential media reads are fast enough on RAID 10 HDDs
  - Bypass Block Size: **1MB** (default) — operations larger than 1MB skip the cache and go directly to HDDs
- [ ] Associate with Storage Pool 1 / DataVol1

> [!NOTE]
> A single-SSD write cache has a small risk: if the SSD fails before flushing writes to the HDDs, that data is lost. This is acceptable for a media server — files are re-downloadable and configs are backed up via Duplicati. For zero risk, use Read-Only mode instead (no write acceleration).

### Global Storage Settings

**Path:** Control Panel → Storage & Snapshots → Storage/Snapshots → Global Settings (gear icon)

**RAID Resync Priority:**
- [ ] Set to **Medium** — balances rebuild speed with service availability

**RAID Scrubbing Schedule:**
- [ ] Enable scheduled scrubbing: **Monthly** — detects silent data corruption (bit rot) on RAID arrays
- [ ] Schedule during low-usage window (e.g., 1st of month, 03:00)

**File System Check (e2fsck):**
- [ ] Auto file system check: **Enable** — runs e2fsck on the next reboot after unclean shutdown
- [ ] Scheduled file system check: **Enable** — periodic integrity check
  - Frequency: **Monthly** (or every 30 days)
  - Schedule during maintenance window (e.g., 1st of month, 04:00)

**Auto Reclaim (SSD TRIM):**
- [ ] Auto Reclaim: **Enable** — sends TRIM commands to SSDs to reclaim unused blocks, maintaining write performance over time

> [!TIP]
> RAID scrubbing and e2fsck are different layers of protection: scrubbing checks RAID consistency (disk-level), while e2fsck checks filesystem integrity (ext4-level). Both should be enabled.

### Shared Folders
Create the following shared folders on DataVol1:

| Name | Path | Purpose |
|------|------|---------|
| data | /share/data | Main mount for hardlinking |
| container | /share/container | Docker configs and compose files |
| backup | /share/backup | Local backups |

**Path:** Control Panel → Shared Folders → Create

For each folder:
- [ ] Create folder
- [ ] Permissions: admin RW, everyone RO (or per policy)
- [ ] Enable Recycle Bin (optional)

---

## Users and Permissions Configuration

### Docker User
- [ ] Control Panel → Users → Create
- [ ] Username: `dockeruser` (or chosen name)
- [ ] UID: verify it's 1001 (or note for PUID)
- [ ] Password: generate secure password
- [ ] Shared folder permissions:
  - data: RW
  - container: RW
  - backup: RO

### Enable SSH
- [ ] Control Panel → Network Services → Telnet/SSH
- [ ] Enable SSH service: **On**
- [ ] Port: 22 (default)
- [ ] Apply

### Verify PUID/PGID
```bash
# Connect via SSH
ssh admin@192.168.3.10

# Verify user ID
id dockeruser
# Expected output: uid=1001(dockeruser) gid=100(everyone) ...
#                      ^^^^          ^^^
#                      PUID          PGID
```

> [!IMPORTANT]
> Note these values! They will be needed to configure the `.env` file after cloning the repository.

### Change QTS System Ports

> [!IMPORTANT]
> QTS factory defaults (HTTP: 8080, HTTPS: 443) conflict with Docker services deployed later — qBittorrent uses port 8080, and Traefik uses port 443. Change QTS system ports before deploying the Docker stack.

**Path:** Control Panel → System → General Settings → System Administration

- [ ] System Port: `5000` (was 8080)
- [ ] Enable Secure Connection (HTTPS): **On**
- [ ] HTTPS Port: `5001`
- [ ] Force Secure Connection (HTTPS): **Recommended** (redirects HTTP 5000 → HTTPS 5001)
- [ ] Apply (QTS will reload on new ports)
- [ ] Verify access: `https://192.168.3.10:5001`

> [!TIP]
> With "Force Secure Connection" enabled, accessing `http://192.168.3.10:5000` automatically redirects to `https://192.168.3.10:5001`. This prevents cleartext credential transmission.

---

## Container Station Installation

### Installation
- [ ] App Center → Search "Container Station"
- [ ] Install Container Station 3
- [ ] Wait for completion
- [ ] Open Container Station
- [ ] Complete initial wizard

### Container Station Configuration
- [ ] Settings → Docker root path: leave default or move to DataVol1
- [ ] Settings → Default registry: Docker Hub (default)
- [ ] Verify Docker version: `docker version`

### Media Stack Folder Structure

> [!NOTE]
> The homelab repository should be cloned/copied **only on the NAS**, not on Proxmox.
> Proxmox only hosts the Plex container which accesses media via NFS.

#### Option A: Git Clone (recommended)

```bash
# Via SSH on NAS
ssh admin@192.168.3.10

# Install git via MyQNAP repo (https://www.myqnap.org/install-the-repo/):
# 1. App Center → Settings (gear icon) → App Repository → Add
#    Name: MyQNAP  URL: https://www.myqnap.org/repo.xml
# 2. App Center → MyQNAP (left sidebar) → Install QGit

cd /share/container
git clone https://github.com/<your-username>/homelab.git mediastack
cd mediastack
```

#### Option B: Manual Copy (if git not available)

```bash
# Via SSH on NAS
cd /share/container
mkdir -p mediastack
cd mediastack

# From a PC with the cloned repository, copy via SCP:
# scp -r docker/ scripts/ Makefile admin@192.168.3.10:/share/container/mediastack/

# Or use File Station to upload files
```

---

## Docker Stack Deployment

### Initial Setup and .env Configuration

The `make setup` command creates the folder structure and environment files (`.env` and `.env.secrets`). **It must be run before first startup.**

```bash
cd /share/container/mediastack

# Run setup (creates data, config folders and .env from template)
make setup

# Edit .env with correct values
nano docker/.env

# Edit .env.secrets with passwords and credentials
nano docker/.env.secrets
```

**Mandatory** configuration in `docker/.env`:

```bash
# PUID and PGID must match the dockeruser created earlier
# Get values with: id dockeruser
# Example output: uid=1001(dockeruser) gid=100(everyone)
PUID=1001    # ← replace with dockeruser uid
PGID=100     # ← replace with dockeruser gid

# Timezone
TZ=Europe/Rome
```

**Mandatory** credentials in `docker/.env.secrets`:

```bash
# Password for Pi-hole web interface (generate with: openssl rand -base64 24)
PIHOLE_PASSWORD=<secure-password>

# VPN credentials (if using vpn profile) — see docs/setup/vpn-setup.md
# VPN_SERVICE_PROVIDER=nordvpn
# OPENVPN_USER=...
# OPENVPN_PASSWORD=...
```

> [!IMPORTANT]
> If PUID/PGID don't match the user owning `/share/data`, containers won't have correct permissions to write files and hardlinking won't work.

### Verify Structure and Permissions

After `make setup`, verify the structure was created:

```bash
# Verify data folders
ls -la /share/data/
# Should contain: torrents/, usenet/, media/

# Verify config folders
ls -la ./config/
# Should contain subfolders for each service

# Verify ownership (must match PUID:PGID configured)
ls -ln /share/data
# Example output for PUID=1001 PGID=100:
# drwxrwxr-x 1001 100 ... media
# drwxrwxr-x 1001 100 ... torrents
# drwxrwxr-x 1001 100 ... usenet
```

If permissions are incorrect:
```bash
# Replace 1001:100 with your PUID:PGID from .env
sudo chown -R 1001:100 /share/data
sudo chown -R 1001:100 /share/container/mediastack/config
sudo chmod -R 775 /share/data
sudo chmod -R 775 /share/container/mediastack/config
```

### Free DNS Port (Port 53)

QTS ships with a built-in `dnsmasq` that binds port 53. Pi-hole needs this port, so `dnsmasq` must be disabled. There is no GUI toggle for this — it requires an `autorun.sh` script on the boot partition.

**Step 1** — Enable autorun support (required since QTS 4.3.3):

> **Control Panel → Hardware → General → "Run user defined startup processes (autorun.sh)"** — check the box and click Apply.

**Step 2** — Verify port 53 is in use:

```bash
netstat -tulnp | grep ':53 '
```

**Step 3** — Mount the boot partition:

```bash
mount $(/sbin/hal_app --get_boot_pd port_id=0)6 /tmp/config
```

**Step 4** — Create or edit `/tmp/config/autorun.sh` and add the following lines:

```bash
# Disable dnsmasq DNS listener so Pi-hole can bind port 53
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
sed 's/port=53/port=0/g' < /etc/dnsmasq.conf.orig > /etc/dnsmasq.conf
/usr/bin/killall dnsmasq
```

> [!IMPORTANT]
> If `autorun.sh` already exists, append the lines above to it. If creating a new file, add `#!/bin/sh` as the first line.

**Step 5** — Make executable and unmount:

```bash
chmod +x /tmp/config/autorun.sh
umount /tmp/config
```

**Step 6** — Apply now without rebooting (run the same commands directly):

```bash
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
sed 's/port=53/port=0/g' < /etc/dnsmasq.conf.orig > /etc/dnsmasq.conf
/usr/bin/killall dnsmasq
```

**Step 7** — Verify port 53 is free:

```bash
netstat -tulnp | grep ':53 '
```

> [!NOTE]
> Setting `port=0` disables dnsmasq's DNS listener while keeping the process available for other internal QTS functions. The `autorun.sh` script runs on every boot so the change persists across reboots.

> [!WARNING]
> QNAP's **Malware Remover** may delete `autorun.sh` during scans (it targets this file regardless of content, because malware historically abused it). If Pi-hole stops resolving after a Malware Remover scan, re-create `autorun.sh` by repeating Steps 3–6. If you also use the [custom fan control script](#step-5--persistent-fix-custom-fan-control-script), remember to re-add that entry too.

### First Startup
```bash
cd /share/container/mediastack

# Validate configuration
make validate

# Pull images
make pull

# Start stack
make up

# Verify status
make status

# Check logs for errors
make logs | grep -i error
```

### Verify Services
- [ ] Sonarr: `http://192.168.3.10:8989` responds
- [ ] Radarr: `http://192.168.3.10:7878` responds
- [ ] Lidarr: `http://192.168.3.10:8686` responds
- [ ] Prowlarr: `http://192.168.3.10:9696` responds
- [ ] Bazarr: `http://192.168.3.10:6767` responds
- [ ] qBittorrent: `http://192.168.3.10:8080` responds
- [ ] NZBGet: `http://192.168.3.10:6789` responds
- [ ] Gluetun (if using VPN profile): `docker inspect --format='{{.State.Health.Status}}' gluetun` returns `healthy`
- [ ] Pi-hole: `http://192.168.3.10:8081/admin` responds
- [ ] Portainer: `https://192.168.3.10:9443` responds
- [ ] Uptime Kuma: `http://192.168.3.10:3001` responds
- [ ] Duplicati: `http://192.168.3.10:8200` responds
- [ ] Cleanuparr: `http://192.168.3.10:11011` responds
- [ ] FlareSolverr: `http://192.168.3.10:8191/health` responds
- [ ] Watchtower: `http://192.168.3.10:8383/v1/metrics` responds
- [ ] Traefik: `http://192.168.3.10:80` redirects to HTTPS
- [ ] Authelia: `https://auth.home.local` responds (requires DNS/hosts entry)

> [!NOTE]
> **Optional service:** Home Assistant (`http://192.168.3.10:8123`) is only available if you started the stack with `compose.homeassistant.yml`. See the compose file for details.

---

## *arr Services Configuration

### Prowlarr (first)
- [ ] Access `http://192.168.3.10:9696`
- [ ] Settings → General → Authentication: Forms
- [ ] Create username/password
- [ ] Settings → General → Note API Key
- [ ] Indexers → Add desired indexers
- [ ] Settings → Apps → Add Sonarr
  - Prowlarr Server: `http://prowlarr:9696`
  - Sonarr Server: `http://sonarr:8989`
  - API Key: (from Sonarr)
- [ ] Repeat for Radarr and Lidarr

### qBittorrent
- [ ] Access `http://192.168.3.10:8080`
- [ ] **First access credentials**:
  - Username: `admin`
  - Password: randomly generated on first boot
  - Retrieve password from logs:
    ```bash
    docker logs qbittorrent 2>&1 | grep -i password
    # Output: "The WebUI administrator password was not set. A temporary password is provided: XXXXXX"
    ```
- [ ] Options → Downloads:
  - Default Save Path: `/data/torrents`
  - Keep incomplete in: disabled (use same path)
- [ ] Options → Downloads → Default Torrent Management Mode: **Automatic**
- [ ] Options → BitTorrent:
  - Seeding limits per preferences
- [ ] Options → WebUI:
  - Change password
- [ ] Categories (right-click in left panel → Add category):
  - `movies` → Save path: `movies`
  - `tv` → Save path: `tv`
  - `music` → Save path: `music`

### NZBGet
- [ ] Access `http://192.168.3.10:6789`
- [ ] Complete initial wizard
- [ ] Settings → Paths:
  - MainDir: `/data/usenet`
  - DestDir: `/data/usenet/complete`
  - InterDir: `/data/usenet/incomplete`
- [ ] Settings → Categories:
  - `movies` → DestDir: `movies`
  - `tv` → DestDir: `tv`
  - `music` → DestDir: `music`
- [ ] Settings → Security → ControlUsername/ControlPassword: note them

### Sonarr
- [ ] Access `http://192.168.3.10:8989`
- [ ] Settings → Media Management:
  - Rename Episodes: Yes
  - Standard Episode Format: configure per preferences
  - **Use Hardlinks instead of Copy: Yes** ← CRITICAL
  - Root Folders → Add: `/data/media/tv`
- [ ] Settings → Download Clients:
  - Add → qBittorrent
    - Host: `gluetun` (if using VPN profile) or `qbittorrent` (if using novpn profile)
    - Port: `8080`
    - Category: `tv`
  - Add → NZBGet
    - Host: `gluetun` (if using VPN profile) or `nzbget` (if using novpn profile)
    - Port: `6789`
    - Username/Password: (from NZBGet)
    - Category: `tv`
- [ ] Settings → General → API Key: note (for Prowlarr)

> [!IMPORTANT]
> **VPN Profile:** When using `COMPOSE_PROFILES=vpn`, download clients (qBittorrent/NZBGet) run inside the Gluetun container's network. Use `gluetun` as the hostname in *arr apps, not `qbittorrent` or `nzbget`.

### Radarr
- [ ] Access `http://192.168.3.10:7878`
- [ ] Settings → Media Management:
  - Rename Movies: Yes
  - **Use Hardlinks instead of Copy: Yes** ← CRITICAL
  - Root Folders → Add: `/data/media/movies`
- [ ] Settings → Download Clients: (like Sonarr, category: `movies`)
- [ ] Settings → General → API Key: note

### Lidarr
- [ ] Access `http://192.168.3.10:8686`
- [ ] Settings → Media Management:
  - **Use Hardlinks instead of Copy: Yes** ← CRITICAL
  - Root Folders → Add: `/data/media/music`
- [ ] Settings → Download Clients: (like Sonarr, category: `music`)
- [ ] Settings → General → API Key: note

### Bazarr
- [ ] Access `http://192.168.3.10:6767`
- [ ] Settings → Sonarr:
  - Address: `sonarr`
  - Port: `8989`
  - API Key: (from Sonarr)
  - Test → Save
- [ ] Settings → Radarr: (similar configuration)
- [ ] Settings → Languages: configure subtitle languages
- [ ] Settings → Providers: add subtitle providers

---

## Hardlinking Verification

Critical test to verify hardlinking works:

```bash
# Via SSH on NAS (host path)
# Containers see these paths as /data/...

# 1. Create test file in torrents
echo "test hardlink" > /share/data/torrents/movies/test.txt

# 2. Create hardlink in media
ln /share/data/torrents/movies/test.txt /share/data/media/movies/test.txt

# 3. Verify same inode
ls -li /share/data/torrents/movies/test.txt /share/data/media/movies/test.txt

# Expected output: same inode number (first column)
# Example:
# 12345 -rw-r--r-- 2 dockeruser everyone 15 Jan  2 10:00 /share/data/torrents/movies/test.txt
# 12345 -rw-r--r-- 2 dockeruser everyone 15 Jan  2 10:00 /share/data/media/movies/test.txt
#   ^-- same inode = hardlink OK

# 4. Cleanup
rm /share/data/torrents/movies/test.txt /share/data/media/movies/test.txt
```

> [!NOTE]
> On NAS host, paths are `/share/data/...`, while containers see `/data/...` thanks to the mount `-v /share/data:/data`. Both point to the same filesystem, so hardlinks work.

> [!WARNING]
> If inodes are different, verify both paths are on the same volume/filesystem.

---

## Pi-hole Configuration

- [ ] Access `http://192.168.3.10:8081/admin`
- [ ] Login with password from `.env.secrets` (PIHOLE_PASSWORD)
- [ ] Settings → DNS:
  - Upstream DNS: verify 1.1.1.1, 1.0.0.1
  - Interface: respond on all interfaces
- [ ] Adlists → Add additional lists (optional):
  - `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
  - `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/multi.txt` (Hagezi Multi - recommended)
  - `https://small.oisd.nl/domainswild` (OISD - unified blocklist)
  - `https://v.firebog.net/hosts/lists.php?type=tick` (Firebog Ticked - community curated)

### Configure UDM-SE to use Pi-hole
- [ ] UDM-SE → Settings → Networks → (each VLAN)
- [ ] DHCP Name Server: `192.168.3.10`
- [ ] Or: use Pi-hole only for specific VLANs

---

## Recyclarr Configuration

Recyclarr automatically syncs Quality Profiles from [Trash Guides](https://trash-guides.info/).

### Generate Base Configuration

On first boot, Recyclarr creates a template file. To generate a complete configuration:

```bash
# Generate config template
make recyclarr-config

# Or manually
docker exec recyclarr recyclarr config create
```

### Configure recyclarr.yml

Edit `./config/recyclarr/recyclarr.yml`:

```yaml
# Minimal configuration example
sonarr:
  series:
    base_url: http://sonarr:8989
    api_key: <SONARR_API_KEY>  # From Sonarr → Settings → General
    quality_definition:
      type: series
    quality_profiles:
      - name: WEB-1080p

radarr:
  movies:
    base_url: http://radarr:7878
    api_key: <RADARR_API_KEY>  # From Radarr → Settings → General
    quality_definition:
      type: movie
    quality_profiles:
      - name: HD Bluray + WEB
```

> [!TIP]
> Full documentation: https://recyclarr.dev/wiki/yaml/config-reference/

### Synchronization

```bash
# Manual sync
make recyclarr-sync

# Or
docker exec recyclarr recyclarr sync
```

### Verification

- [ ] Verify Quality Profiles created in Sonarr (Settings → Profiles)
- [ ] Verify Quality Profiles created in Radarr (Settings → Profiles)
- [ ] Verify Custom Formats imported

---

## Post-Installation

### Initial Configuration Backup
```bash
cd /share/container/mediastack
make backup
```
- [ ] Backup created in `/share/backup` (Duplicati destination)
- [ ] Copy backup offsite (USB, cloud)

### QTS Config Backup
- [ ] Control Panel → System → Backup/Restore → Backup System Settings
- [ ] Save `.bin` file in secure location

### Documentation
- [ ] Note all API keys in password manager
- [ ] Update documentation with any modifications
- [ ] Screenshot important configurations

---

## Common Troubleshooting

| Problem | Probable Cause | Solution |
|---------|----------------|----------|
| Container won't start | Folder permissions | `chown -R $PUID:$PGID ./config` (use values from .env) |
| Hardlink doesn't work | Paths on different filesystems | Verify mount points |
| qBittorrent "stalled" | Port not reachable | Verify port forwarding 50413 |
| Pi-hole doesn't resolve | Port 53 in use by dnsmasq | Disable dnsmasq via autorun.sh (see [Free DNS Port](#free-dns-port-port-53)) |
| WebUI not responding | Container crashed | `docker compose logs <service>` |
| Incorrect file permissions | PUID/PGID mismatch | Verify `id dockeruser` and update .env |
| Fans at max speed despite cool HDDs | M.2 SSD ≥70°C triggers hardcoded override | See [Fan Noise Fix](#fan-noise-fix-m2-ssd-thermal-override) below |

---

## Fan Noise Fix (M.2 SSD Thermal Override)

The TS-435XeU has three 40mm fans (QNAP part FAN-4CM-R01) rated up to ~9,000 RPM. If fans run at maximum speed despite HDD temps of 38–40°C, the cause is almost certainly the **hardcoded M.2 SSD thermal override**: QTS forces 100% fan speed when any M.2 drive reaches 70°C. This threshold is not configurable through the QTS GUI. NVMe drives in a cramped 1U chassis routinely hit 70°C under sustained I/O.

A second, less likely cause is a Smart Fan bug where Quiet/Normal/Performance modes produce no actual RPM change — this has been confirmed across multiple QNAP models and QTS versions.

### Step 1 — Diagnose: Check M.2 SSD Temperature

Before changing anything, confirm the M.2 drive is actually hitting the 70°C threshold.

**Via QTS GUI:**

- [ ] Storage & Snapshots → Disks/VJBOD → select the M.2 disk → Disk Health → check temperature

**Via SSH:**

```bash
ssh admin@192.168.3.10

# Check system and CPU temps (what Smart Fan uses internally)
getsysinfo systmp
getsysinfo cputmp

# Check HDD temps (one per disk, 1-indexed)
getsysinfo hdtmp 1
getsysinfo hdtmp 2

# Check M.2 SSD temp via smartctl (if available)
smartctl -a /dev/nvme0 | grep -i temperature
# Or on some QTS versions:
smartctl -a /dev/nvme0n1 | grep -i temperature
```

> [!TIP]
> If `smartctl` is not found, install it from the MyQNAP repo (App Center → MyQNAP → QSmart Tools) or check the temperature from the QTS GUI as described above.

**If M.2 temp is at or above 70°C** → the override is active. Proceed to Step 2 (hardware fix) first, then optionally Steps 3–5 for additional software tuning.

**If M.2 temp is below 70°C** → the cause is likely a Smart Fan firmware bug. Skip to Step 3.

### Step 2 — Hardware Fix: M.2 Heatsink (Recommended First Action)

Addressing the root cause (M.2 overheating) is more effective than fighting the firmware. An aftermarket M.2 heatsink can reduce NVMe temps by 10–15°C, potentially keeping the drive below the 70°C threshold permanently.

- [ ] Power down the NAS
- [ ] Install an M.2 2280 heatsink with thermal pad on the NVMe drive
  - Look for low-profile heatsinks (under 10mm height) to fit the TS-435XeU's internal clearance
  - Ensure the heatsink does not contact other components or obstruct airflow
- [ ] Power on and monitor temps for 24–48 hours under normal workload

> [!IMPORTANT]
> Verify internal clearance before purchasing a heatsink. The TS-435XeU's 1U form factor has limited vertical space above the M.2 slot. Measure before buying.

If the heatsink alone drops the M.2 below 70°C, the fan override disengages and no further action is needed. If temps still hover near 70°C, combine with the software workarounds below.

### Step 3 — Software Fix: Adjust Smart Fan Thresholds via SSH

The least invasive software fix. This raises the temperature thresholds in QTS's Smart Fan configuration file so fans stay at lower speeds longer. This does **not** override the hardcoded 70°C M.2 cutoff — it only affects the normal Smart Fan curve based on the system temperature sensor.

```bash
ssh admin@192.168.3.10

# View current thresholds
getcfg Misc "system stop temp" -f /etc/config/uLinux.conf
getcfg Misc "system low temp" -f /etc/config/uLinux.conf
getcfg Misc "system high temp" -f /etc/config/uLinux.conf

# Raise thresholds (adjust values for your environment)
setcfg Misc "system stop temp" 34 -f /etc/config/uLinux.conf
setcfg Misc "system low temp" 44 -f /etc/config/uLinux.conf
setcfg Misc "system high temp" 60 -f /etc/config/uLinux.conf

# Verify the changes took effect
getcfg Misc "system low temp" -f /etc/config/uLinux.conf
```

After editing, force `hal_daemon` to reload by toggling Smart Fan mode in the QTS GUI:

- [ ] Control Panel → Hardware → Smart Fan
- [ ] Switch to Manual mode → Apply
- [ ] Switch back to your preferred mode (Quiet) → Apply

> [!WARNING]
> These changes survive reboots but **may be overwritten by firmware updates**. After any QTS firmware update, re-check the values and reapply if needed.

### Step 4 — Software Fix: Manual Fan Speed via `hal_app`

If Smart Fan threshold tweaks aren't enough (or if the Smart Fan mode-switching bug applies to your firmware), bypass Smart Fan entirely using `hal_app` to set fan speeds directly.

**Prerequisite:** Set Smart Fan to **Manual** mode in QTS first, otherwise `hal_daemon` overrides your settings within minutes.

- [ ] Control Panel → Hardware → Smart Fan → Manual → Apply

**Step 4a — Discover hardware layout:**

```bash
# Show fan count and hardware info
hal_app --se_sys_getinfo enc_sys_id=root
# Expected: max_fan_num = 3

# Check MCU firmware version
hal_app --get_mcu_version mode=0
```

**Step 4b — Read current fan speeds:**

```bash
# Fan RPMs (obj_index 0, 1, 2 for three fans)
hal_app --se_sys_get_fan enc_sys_id=root,obj_index=0
hal_app --se_sys_get_fan enc_sys_id=root,obj_index=1
hal_app --se_sys_get_fan enc_sys_id=root,obj_index=2
```

**Step 4c — Set fan speed:**

```bash
# Mode 0–7: 0 = lowest (~3,500 RPM), 7 = maximum (~9,000 RPM)
# Start with mode 1 and increase if temps rise above safe levels
hal_app --se_sys_set_fan_mode enc_sys_id=root,obj_index=0,mode=1
hal_app --se_sys_set_fan_mode enc_sys_id=root,obj_index=1,mode=1
hal_app --se_sys_set_fan_mode enc_sys_id=root,obj_index=2,mode=1
```

> [!IMPORTANT]
> Even in Manual mode, the **firmware-level 70°C M.2 override may still engage** and force fans to max. If this happens, the M.2 heatsink (Step 2) is the only way to prevent it. The `hal_app` commands only work reliably when M.2 temps are below the override threshold.

**Step 4d — Monitor after changing fan speed:**

```bash
# Check temps periodically after reducing fan speed
getsysinfo systmp    # System temp (keep below 60°C)
getsysinfo cputmp    # CPU temp
getsysinfo hdtmp 1   # HDD 1 (keep below 45°C for longevity)
getsysinfo hdtmp 2   # HDD 2
```

### Step 5 — Persistent Fix: Custom Fan Control Script

For a solution that survives reboots and automatically adjusts fan speed based on temperature, deploy a custom script that replaces Smart Fan logic entirely.

> [!IMPORTANT]
> This NAS already uses `autorun.sh` to [disable dnsmasq for Pi-hole](#free-dns-port-port-53). The fan control daemon must be **appended** to the existing `autorun.sh` — do not overwrite it.

**Prerequisite:** Autorun must be enabled in QTS. If you already completed the [Free DNS Port](#free-dns-port-port-53) setup, this is already done. If not:

- [ ] Control Panel → Hardware → General → check **"Run user defined startup processes (autorun.sh)"** → Apply

**Step 5a — Create the fan control script:**

```bash
cat > /share/CACHEDEV1_DATA/scripts/fan_control.sh << 'SCRIPT'
#!/bin/bash
# Custom fan control for QNAP TS-435XeU
# Bypasses QTS Smart Fan to provide temperature-based fan curve.
# Monitors CPU temp and adjusts all three 40mm fans accordingly.
#
# Prerequisites:
#   - Smart Fan set to Manual mode in QTS GUI
#   - autorun.sh configured to start this script on boot
#
# Fan modes: 0 = ~3,500 RPM (quiet), 7 = ~9,000 RPM (max)

POLL_INTERVAL=60
FAN_COUNT=3

# Temperature thresholds (°C) and corresponding fan modes (0–7)
# At CPU temp X or above, use fan mode Y
declare -a TEMP_THRESHOLDS=(40 45 50 55 60 65 70 75)
declare -a FAN_MODES=(       0  1  2  3  4  5  6  7)

set_all_fans() {
    local mode=$1
    for ((i = 0; i < FAN_COUNT; i++)); do
        hal_app --se_sys_set_fan_mode enc_sys_id=root,obj_index=$i,mode=$mode
    done
}

while true; do
    CPU_TEMP=$(getsysinfo cputmp | grep -o '[0-9]*' | head -1)

    # Default to lowest mode, then walk up the threshold table
    TARGET_MODE=0
    for ((j = 0; j < ${#TEMP_THRESHOLDS[@]}; j++)); do
        if (( CPU_TEMP >= TEMP_THRESHOLDS[j] )); then
            TARGET_MODE=${FAN_MODES[$j]}
        fi
    done

    set_all_fans "$TARGET_MODE"
    sleep "$POLL_INTERVAL"
done
SCRIPT

chmod +x /share/CACHEDEV1_DATA/scripts/fan_control.sh
```

> [!NOTE]
> This script monitors **CPU temperature**, not M.2 temperature, because `getsysinfo` does not expose M.2 temps directly. If the M.2 70°C firmware override is your primary issue, you **must** also install an M.2 heatsink (Step 2) — this script cannot prevent the firmware-level override from engaging.

**Step 5b — Add to existing `autorun.sh`:**

```bash
# Mount the boot partition
mount $(/sbin/hal_app --get_boot_pd port_id=0)6 /tmp/config

# Verify existing autorun.sh content (should contain dnsmasq fix)
cat /tmp/config/autorun.sh
```

Append the fan control daemon start command:

```bash
cat >> /tmp/config/autorun.sh << 'EOF'

# Start custom fan control daemon (bypasses Smart Fan)
/sbin/daemon_mgr fanCtrl start "/share/CACHEDEV1_DATA/scripts/fan_control.sh &" &
EOF
```

Verify the file now contains both the dnsmasq fix and the fan control line:

```bash
cat /tmp/config/autorun.sh
```

Expected contents (order may vary):

```bash
#!/bin/sh
# Disable dnsmasq DNS listener so Pi-hole can bind port 53
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
sed 's/port=53/port=0/g' < /etc/dnsmasq.conf.orig > /etc/dnsmasq.conf
/usr/bin/killall dnsmasq

# Start custom fan control daemon (bypasses Smart Fan)
/sbin/daemon_mgr fanCtrl start "/share/CACHEDEV1_DATA/scripts/fan_control.sh &" &
```

Unmount:

```bash
umount /tmp/config
```

> [!WARNING]
> QNAP's **Malware Remover** may delete `autorun.sh` during scans (see the [same warning in the dnsmasq section](#free-dns-port-port-53)). If fans return to max speed after a Malware Remover scan, re-create `autorun.sh` with **both** the dnsmasq fix and the fan control line.

**Step 5c — Activate now without rebooting:**

```bash
# Set Smart Fan to Manual first (via QTS GUI), then:
/sbin/daemon_mgr fanCtrl start "/share/CACHEDEV1_DATA/scripts/fan_control.sh &" &
```

**Step 5d — Verify it's running:**

```bash
ps aux | grep fan_control
# Should show the script running

# Check current fan RPMs
hal_app --se_sys_get_fan enc_sys_id=root,obj_index=0
hal_app --se_sys_get_fan enc_sys_id=root,obj_index=1
hal_app --se_sys_get_fan enc_sys_id=root,obj_index=2
```

### Step 6 — Hardware Alternative: Noctua Fan Swap

If software fixes are insufficient or you want a permanent noise floor reduction, the stock fans can be replaced with quieter units.

| Spec | Stock (FAN-4CM-R01) | Noctua NF-A4x20 PWM |
|------|---------------------|----------------------|
| Size | 40×40×20mm | 40×40×20mm |
| Max RPM | ~9,000 | ~5,000 (4,400 with LNA) |
| Connector | 4-pin PWM, 12V | 4-pin PWM, 12V |
| Noise at max | High | Significantly lower |
| Max airflow | 100% (baseline) | ~56% of stock |

- [ ] Purchase 3x **Noctua NF-A4x20 PWM** (the 12V version — **not** the 5V variant)
- [ ] Power down the NAS and swap all three fans
- [ ] Power on and monitor HDD temps for 48+ hours

> [!WARNING]
> The ~44% reduction in maximum airflow is significant in a 1U chassis. At your current HDD temps (38–40°C) there is thermal headroom, but monitor closely during summer months or sustained heavy I/O. If HDD temps approach 50°C, consider reverting or improving case airflow.

### Summary: Recommended Order of Actions

| Priority | Action | Addresses |
|----------|--------|-----------|
| 1 | [Check M.2 temp](#step-1--diagnose-check-m2-ssd-temperature) | Confirms root cause |
| 2 | [Install M.2 heatsink](#step-2--hardware-fix-m2-heatsink-recommended-first-action) | Root cause (M.2 ≥70°C override) |
| 3 | [Raise Smart Fan thresholds](#step-3--software-fix-adjust-smart-fan-thresholds-via-ssh) | Normal fan curve too aggressive |
| 4 | [Manual `hal_app` control](#step-4--software-fix-manual-fan-speed-via-hal_app) | Smart Fan mode bug / fine-tuning |
| 5 | [Custom fan script](#step-5--persistent-fix-custom-fan-control-script) | Long-term automated control |
| 6 | [Noctua fan swap](#step-6--hardware-alternative-noctua-fan-swap) | Permanent noise floor reduction |

> [!TIP]
> Most users find that an M.2 heatsink (Step 2) alone solves the problem. If the M.2 stays below 70°C, the firmware override never triggers and Smart Fan behaves normally. The software and fan-swap options are fallbacks for cases where the heatsink isn't enough or the Smart Fan firmware bug applies.

---

## References

- Trash Guides Docker Setup: https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/
- QNAP Container Station: https://www.qnap.com/en/how-to/tutorial/article/how-to-use-container-station-3
- LinuxServer.io Images: https://docs.linuxserver.io/
