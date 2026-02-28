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

QTS ships with a built-in `dnsmasq` that binds port 53. Pi-hole needs this port, so `dnsmasq` must be disabled. There is no GUI toggle for this — it requires an `autorun.sh` script on the flash config partition. See [QNAP FAQ: Running Your Own Application at Startup](https://www.qnap.com/en/how-to/faq/article/running-your-own-application-at-startup) for official documentation on `autorun.sh`.

**Step 1** — Enable autorun support (required since QTS 4.3.3):

> **Control Panel → Hardware → General → "Run user defined startup processes (autorun.sh)"** — check the box and click Apply.

**Step 2** — Verify port 53 is in use:

```bash
netstat -tulnp | grep ':53 '
```

**Step 3** — Mount flash config, write `autorun.sh`, and unmount:

```bash
# Mount the flash config partition
sudo /etc/init.d/init_disk.sh mount_flash_config

# Write the autorun script (disables dnsmasq DNS listener)
sudo tee /tmp/nasconfig_tmp/autorun.sh << 'EOF'
#!/bin/sh
/bin/echo "autorun.sh fired at $(/bin/date)" >> /tmp/autorun.log
/bin/cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
/bin/sed 's/port=53/port=0/g' < /etc/dnsmasq.conf.orig > /etc/dnsmasq.conf
/usr/bin/killall dnsmasq
# Point NAS DNS at Pi-hole (once running) with external fallback
/bin/echo -e "nameserver 192.168.3.10\nnameserver 1.1.1.1" > /etc/resolv.conf
/bin/echo "dnsmasq killed, resolv.conf updated at $(/bin/date)" >> /tmp/autorun.log
EOF

# Make executable and verify contents
sudo chmod +x /tmp/nasconfig_tmp/autorun.sh
cat /tmp/nasconfig_tmp/autorun.sh

# Unmount flash config
sudo /etc/init.d/init_disk.sh umount_flash_config
```

> [!IMPORTANT]
> If `autorun.sh` already exists, check its contents first with `cat /tmp/nasconfig_tmp/autorun.sh` and append the dnsmasq lines rather than overwriting the file.

**Step 4** — Apply now without rebooting (run the same commands directly):

```bash
sudo /bin/cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
sudo /bin/sed 's/port=53/port=0/g' < /etc/dnsmasq.conf.orig > /etc/dnsmasq.conf
sudo /usr/bin/killall dnsmasq
sudo /bin/echo -e "nameserver 192.168.3.10\nnameserver 1.1.1.1" > /etc/resolv.conf
```

**Step 5** — Verify port 53 is free:

```bash
netstat -tulnp | grep ':53 '
```

> [!NOTE]
> Setting `port=0` disables dnsmasq's DNS listener while keeping the process available for other internal QTS functions. Because dnsmasq also served as the NAS's local resolver, the script rewrites `/etc/resolv.conf` to use Pi-hole (`192.168.3.10`) with Cloudflare (`1.1.1.1`) as fallback — this ensures the NAS can still resolve names at boot before Pi-hole's container is up. The `autorun.sh` script runs on every boot so the change persists across reboots. Log entries are written to `/tmp/autorun.log` for troubleshooting.

> [!WARNING]
> QNAP's **Malware Remover** may delete `autorun.sh` during scans (it targets this file regardless of content, because malware historically abused it). If Pi-hole stops resolving after a Malware Remover scan, re-create `autorun.sh` by repeating Step 3.

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
| Pi-hole doesn't resolve | Port 53 in use by dnsmasq | Disable dnsmasq via autorun.sh (see [Free DNS Port](#free-dns-port-port-53)); check `/tmp/autorun.log` for status |
| WebUI not responding | Container crashed | `docker compose logs <service>` |
| Incorrect file permissions | PUID/PGID mismatch | Verify `id dockeruser` and update .env |

---

## References

- Trash Guides Docker Setup: https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/
- QNAP Container Station: https://www.qnap.com/en/how-to/tutorial/article/how-to-use-container-station-3
- LinuxServer.io Images: https://docs.linuxserver.io/
