# Deployment Checklist — QNAP TS-435XeU

> Complete checklist for initial NAS setup with Container Station and media stack

---

## Pre-Installation Hardware

### Rack and Physical
- [ ] NAS mounted in rack U2 (below vented panel)
- [ ] 5mm neoprene insulation positioned between NAS and UPS
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
- [ ] Assign static IP: `192.168.3.10`
- [ ] Subnet mask: `255.255.255.0`
- [ ] Gateway: `192.168.3.1`
- [ ] Primary DNS: `192.168.3.1` (UDM-SE) or `1.1.1.1`
- [ ] Secondary DNS: `1.0.0.1`
- [ ] Hostname: `qnap-nas` (or chosen name)
- [ ] Verify MTU 9000 if Jumbo Frames enabled on switch

**Path:** Control Panel → Network & Virtual Switch → Interfaces

---

## Storage Configuration

### Filesystem Choice: ext4 vs ZFS

| Aspect | ext4 | ZFS |
|--------|------|-----|
| **Minimum RAM** | ~256MB | **8-16GB dedicated** (1GB/TB for ARC) |
| **CPU overhead** | Low | Medium-high (checksumming, compression) |
| **Complexity** | Simple, mature | Complex, steep learning curve |
| **Data integrity** | Basic (journaling) | Excellent (end-to-end checksumming) |
| **Snapshots** | No (requires LVM) | Yes, native and efficient |
| **Self-healing** | No | Yes (with mirror/raidz) |
| **Compression** | No | Yes (LZ4, ZSTD) - 10-30% gain |
| **Hardlinking** | ✓ Excellent | ✓ Excellent |
| **QNAP QTS support** | Native, stable | Limited |

**Recommendation: ext4**
- QTS has native and stable support
- TS-435XeU has limited RAM (typically 4-8GB)
- For media server, advanced ZFS features are not critical
- Hardlinking works perfectly

> [!NOTE]
> ZFS would make sense with 16GB+ RAM and maximum priority on data integrity, or on Proxmox/TrueNAS.

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
| **Filesystem** | ext4 | QTS compatibility, low RAM/CPU overhead |
| **RAID** | RAID 10 | I/O performance for Docker, safe rebuild |
| **Volume** | Static | Best hardlink performance |

---

### Storage Pool
- [ ] Control Panel → Storage & Snapshots → Storage/Snapshots
- [ ] Create → New Storage Pool
- [ ] Select all HDDs (4 disks)
- [ ] RAID type: **RAID 10** (recommended for media server)
  - Alternative for 2 disks: RAID 1 (mirror)
  - Alternative if capacity priority: RAID 5
- [ ] Alert threshold: 80%
- [ ] Complete creation (time varies based on capacity)

### SSD Cache (if M.2 present)
- [ ] Storage & Snapshots → Cache Acceleration
- [ ] Create
- [ ] Select M.2 SSD
- [ ] Cache mode: Read-Write (recommended for Container Station)
- [ ] Associate with main Storage Pool

### Static Volume
- [ ] Storage & Snapshots → Create → New Volume
- [ ] Volume type: **Static Volume** (recommended for hardlink performance)
  - Alternative: Thick Volume if you prefer native snapshots
- [ ] Allocate all available space (or desired quota)
- [ ] Name: `DataVol1`
- [ ] Filesystem: **ext4** (recommended for compatibility and low overhead)

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
- [ ] UID: verify it's 1000 (or note for PUID)
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
# Expected output: uid=1000(dockeruser) gid=100(everyone) ...
#                      ^^^^          ^^^
#                      PUID          PGID
```

> [!IMPORTANT]
> Note these values! They will be needed to configure the `.env` file after cloning the repository.

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

# Install git if not present (App Center -> Git)
# Or via Entware: opkg install git

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
# Example output: uid=1000(dockeruser) gid=100(everyone)
PUID=1000    # ← replace with dockeruser uid
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
# Example output for PUID=1000 PGID=100:
# drwxrwxr-x 1000 100 ... media
# drwxrwxr-x 1000 100 ... torrents
# drwxrwxr-x 1000 100 ... usenet
```

If permissions are incorrect:
```bash
# Replace 1000:100 with your PUID:PGID from .env
sudo chown -R 1000:100 /share/data
sudo chown -R 1000:100 /share/container/mediastack/config
sudo chmod -R 775 /share/data
sudo chmod -R 775 /share/container/mediastack/config
```

### Verify DNS Port

Before starting, verify port 53 is not already in use by QTS:

```bash
# Check if port 53 is occupied
ss -tulnp | grep :53

# If occupied, disable QTS local DNS:
# Control Panel → Network & Virtual Switch → DNS Server → Disable
```

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
- [ ] Huntarr: `http://192.168.3.10:9705` responds
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
| Pi-hole doesn't resolve | Port 53 in use | Verify other DNS services on NAS |
| WebUI not responding | Container crashed | `docker compose logs <service>` |
| Incorrect file permissions | PUID/PGID mismatch | Verify `id dockeruser` and update .env |

---

## References

- Trash Guides Docker Setup: https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/
- QNAP Container Station: https://www.qnap.com/en/how-to/tutorial/article/how-to-use-container-station-3
- LinuxServer.io Images: https://docs.linuxserver.io/
