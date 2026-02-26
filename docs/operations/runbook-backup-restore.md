# Runbook — Backup and Restore Homelab

> Operational procedures for backup and disaster recovery of QNAP NAS TS-435XeU and Mini PC Proxmox

---

## Backup Strategy Overview

The strategy follows the **3-2-1 rule**: three copies of data, on two different storage types, with one copy offsite.

| Component | Data | Frequency | Destination | Retention |
|-----------|------|-----------|-------------|-----------|
| Docker configs | ./config/* (includes *arr, Traefik, Pi-hole, etc.) | Daily | NAS + Cloud | 30 days |
| Docker compose | compose.yml, compose.media.yml, .env | On each change | Git + NAS | Unlimited |
| QNAP config | QTS system | Weekly | USB + Cloud | 5 versions |
| Proxmox VMs | All VMs | Weekly | NAS | 4 versions |
| Media library | /share/data/media | Never (rebuildable) | — | — |
| *arr databases | SQLite in ./config | Daily | Included in Docker configs | 30 days |

> [!NOTE]
> The `./config` folder contains configurations for all Docker services: Sonarr, Radarr, Lidarr, Prowlarr, Bazarr, qBittorrent, NZBGet, Pi-hole, Home Assistant, Portainer, Duplicati, Uptime Kuma, Recyclarr, Traefik, Cleanuparr.

---

## Backup Procedures

### 1. Docker Configurations Backup (Duplicati - Recommended)

The Duplicati container manages automatic backups with deduplication and encryption.

**Initial configuration:**

1. Access `http://192.168.3.10:8200`
2. Add backup → Configure:
   - **Name**: `docker-configs-local`
   - **Destination**: Folder path → `/backups`
   - **Source**: `/source/config`
   - **Schedule**: Daily at 23:00
   - **Retention**: Smart backup retention (7 daily, 4 weekly, 3 monthly)
   - **Encryption**: Optional but recommended for offsite backups

**Trigger manual backup:**
```bash
make backup  # Triggers Duplicati via API
```

**Verify backup:**
- Access Duplicati WebUI → Select backup → "Show log"
- Or: Restore → Browse to verify contents

#### Alternative: Manual backup with cron

If you prefer manual tar.gz backups without Duplicati:

```bash
# Create cron job on NAS (ssh admin@192.168.3.10)
crontab -e

# Backup at 23:00 (requires ~1 minute downtime, before NAS shutdown at 01:00)
# Note: adjust path to your installation
0 23 * * * cd /share/container/mediastack && make down && tar -czf /share/backup/docker-config-$(date +\%Y\%m\%d).tar.gz ./config && make up

# Clean old backups (keep last 30) - runs at 23:30 after backup
30 23 * * * find /share/backup -name "docker-config-*.tar.gz" -mtime +30 -delete
```

**Verify tar.gz backup:**
```bash
ls -lah /share/backup/docker-config-*.tar.gz
tar -tzf /share/backup/docker-config-YYYYMMDD.tar.gz | head -20
```

### 2. QNAP QTS Configuration Backup

The `scripts/backup-qts-config.sh` script automates QTS configuration backup.

**QTS backup contents:**
- User and group configuration
- Shared folders and permissions
- Network and VLAN configuration
- Installed apps and their configurations
- Scheduled tasks

**Manual backup:**
```bash
make backup-qts  # Runs backup and shows detailed output
```

**Automation with cron (recommended):**
```bash
# On NAS, add to crontab (ssh admin@192.168.3.10)
crontab -e

# Sunday at 08:00 (after NAS power-on at 07:00)
0 8 * * 0 /share/container/homelab/scripts/backup-qts-config.sh --notify >> /var/log/qts-backup.log 2>&1
```

**Configurable parameters (environment variables):**
| Variable | Default | Description |
|----------|---------|-------------|
| `QTS_BACKUP_DIR` | `/share/backup/qts-config` | Backup destination directory |
| `QTS_BACKUP_RETENTION` | `5` | Number of backups to keep |
| `HA_WEBHOOK_URL` | - | Home Assistant webhook URL for notifications |

**Check available backups:**
```bash
ls -la /share/backup/qts-config/
```

**Manual backup via web interface (alternative):**

1. Access `https://192.168.3.10:5001` (QTS HTTPS port)
2. Control Panel → System → Backup/Restore
3. Backup System Settings → Create Backup
4. Save the generated `.bin` file

### 3. Proxmox VM Backup

**Proxmox Backup Configuration:**

1. Access `https://192.168.3.20:8006`
2. Datacenter → Storage → Add → Directory
   - ID: `backup-nas`
   - Directory: `/mnt/nas-backup` (NFS mount from QNAP)
   - Content: VZDump backup file
3. Datacenter → Backup → Add
   - Storage: backup-nas
   - Schedule: `sun 08:00`
   - Selection mode: All
   - Mode: Snapshot (for running VMs)
   - Compression: ZSTD
   - Retention: Keep last 4

**Mount NFS from QNAP on Proxmox:**
```bash
# On NAS: enable NFS for backup shared folder
# Control Panel → Shared Folders → backup → Edit → NFS Permission
# Add: 192.168.3.20 (read/write, no_root_squash)

# On Proxmox:
mkdir -p /mnt/nas-backup
echo "192.168.3.10:/backup /mnt/nas-backup nfs defaults 0 0" >> /etc/fstab
mount -a
```

**Immediate manual backup:**
```bash
# Via Proxmox CLI
vzdump <vmid> --storage backup-nas --compress zstd --mode snapshot
```

### 4. Offsite Backup (Cloud)

**Duplicati to Dropbox or Google Drive**

Duplicati has built-in support for Dropbox and Google Drive:

1. Access `http://192.168.3.10:8200`
2. Add backup → Destination: **Google Drive** or **Dropbox**
3. Authenticate with OAuth (link in wizard)
4. Remote folder: `homelab-backup`
5. Source: `/source/config`
6. Schedule: daily
7. Retention: Smart (7 daily, 4 weekly, 3 monthly)

---

## Restore Procedures

### 1. Docker Configurations Restore

**Scenario: Single service config corruption**
```bash
# Stop the service (from project directory)
make logs-sonarr  # First check logs to understand the problem
docker compose -f docker/compose.yml -f docker/compose.media.yml stop sonarr

# Backup corrupted config (for analysis)
mv ./config/sonarr ./config/sonarr.corrupted

# Restore from backup
tar -xzf /share/backup/docker-config-YYYYMMDD.tar.gz ./config/sonarr

# Restart
docker compose -f docker/compose.yml -f docker/compose.media.yml start sonarr

# Verify logs
make logs-sonarr
```

**Scenario: Complete NAS reinstallation**
```bash
# 1. Reinstall Container Station on QTS
# 2. Clone repository
git clone <repo-url> /share/container/homelab
cd /share/container/homelab

# 3. Recreate folder structure
./scripts/setup-folders.sh

# 4. Restore all configs
tar -xzf /share/backup/docker-config-YYYYMMDD.tar.gz -C .

# 5. Verify permissions
sudo chown -R 1000:100 ./config
sudo chmod -R 775 ./config

# 6. Copy .env
cp docker/.env.example docker/.env
# Edit docker/.env with correct passwords

# 7. Start stack
make up

# 8. Verify all services
make health
```

### 2. QNAP QTS Configuration Restore

**Via web interface:**

1. After QTS reinstallation, access `https://<ip>:5001`
2. Control Panel → System → Backup/Restore
3. Restore System Settings
4. Upload backup `.bin` file
5. System will request reboot

**Post-restore checklist:**
- [ ] Verify shared folders
- [ ] Verify users and permissions
- [ ] Reinstall Container Station
- [ ] Verify network/VLAN configuration
- [ ] Restore Docker configurations (procedure above)

### 3. Proxmox VM Restore

**Via web interface:**

1. Access `https://192.168.3.20:8006`
2. Storage → backup-nas → Content
3. Select desired backup
4. Click "Restore"
5. Configure: VM ID, Storage target
6. Start after restore: optional

**Via CLI:**
```bash
# List available backups
ls -la /mnt/nas-backup/
# or
pvesm list backup-nas

# Restore VM
qmrestore /mnt/nas-backup/vzdump-qemu-<vmid>-<date>.vma.zst <new-vmid> --storage local-lvm

# If same VMID (overwrites)
qmrestore /mnt/nas-backup/vzdump-qemu-<vmid>-<date>.vma.zst <vmid> --force
```

### 4. Complete Disaster Recovery

**Scenario: Total loss of NAS + Proxmox**

Prerequisites: offsite backup available (cloud or secondary site)

**Phase 1: Hardware**
1. Replace/repair hardware
2. Install QTS on NAS
3. Install Proxmox on Mini PC

**Phase 2: Base configuration**
```bash
# NAS: manual network configuration
# IP: 192.168.3.10/24
# Gateway: 192.168.3.1
# DNS: 1.1.1.1

# Proxmox: manual network configuration
# IP: 192.168.3.20/24
# Gateway: 192.168.3.1
```

**Phase 3: Restore from offsite**
```bash
# Download backup from cloud (Google Drive)
rclone copy gdrive-backup:homelab-backup /share/backup --progress

# Or direct restore from Duplicati WebUI if configured

# Or from Tailscale remote
rsync -avz user@100.x.x.x:/backup/homelab/ /share/backup/
```

**Phase 4: Restore components**
1. Restore QTS config (procedure above)
2. Recreate folder structure: `./scripts/setup-folders.sh`
3. Restore Docker configs
4. Restore Proxmox VMs

**Phase 5: Verification**
- [ ] All containers running: `make status`
- [ ] Health check: `make health`
- [ ] Inter-VLAN connectivity
- [ ] Plex access from Media VLAN
- [ ] Tailscale connected

---

## Automatic Backup Verification

### Implemented Script

The `scripts/verify-backup.sh` script automatically verifies backup integrity:

1. **Archive extraction**: Verifies tar.gz is readable
2. **SQLite integrity**: Checks databases for Sonarr, Radarr, Lidarr, Prowlarr, Bazarr
3. **Backup age**: Warning if older than 7 days
4. **Critical files**: Verifies Traefik configuration presence

### Usage

```bash
# Manual verification (verbose)
make verify-backup

# Or directly
./scripts/verify-backup.sh --verbose

# With Home Assistant notification (requires HA_WEBHOOK_URL)
./scripts/verify-backup.sh --notify
```

### Automation with Cron

For automatic weekly verification (recommended):

```bash
# On NAS, add to crontab
crontab -e

# Sunday at 08:30 (after QTS backup at 08:00)
30 8 * * 0 /share/container/homelab/scripts/verify-backup.sh --notify >> /var/log/verify-backup.log 2>&1
```

### Home Assistant Notifications (Optional)

To receive alerts on errors:

1. Create webhook automation in Home Assistant
2. Set environment variable:
   ```bash
   # In docker/.env.secrets
   HA_WEBHOOK_URL=http://192.168.3.10:8123/api/webhook/backup-verify
   ```
3. Run with `--notify`

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Verification OK |
| 1 | Errors detected (corrupted backup) |
| 2 | No backup found |

### Advanced Options (Not Implemented)

**Duplicati Verify (built-in)**

Duplicati has a "Verify" function that checks backup integrity:
1. WebUI → Select backup
2. Operations → "Verify files"
3. Schedule via Advanced options → `--backup-test-samples=5`

**Automatic restore in isolated environment**

For advanced homelabs:
1. Dedicated Proxmox VM for restore testing
2. Script that weekly:
   - Restores config in temporary directory
   - Starts containers in isolated network
   - Verifies healthchecks
   - Deletes and notifies result

---

## Contacts and Escalation

| Resource | Contact |
|----------|---------|
| QNAP Documentation | qnap.com/en/how-to/knowledge-base |
| Proxmox Forum | forum.proxmox.com |
| Trash Guides Discord | trash-guides.info (link in homepage) |
| r/homelab | reddit.com/r/homelab |

---

## Changelog

| Date | Change |
|------|--------|
| 2026-01-06 | Added backup-qts-config.sh script for QTS backup automation |
| 2025-01-04 | Revision: Duplicati as primary method, docker compose command fixes, QTS port clarifications |
| 2025-01-02 | Document creation |
