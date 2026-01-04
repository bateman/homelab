# Runbook — Backup e Restore Homelab

> Procedure operative per backup e disaster recovery di NAS QNAP TS-435XeU e Mini PC Proxmox

---

## Panoramica Strategia Backup

La strategia segue la regola **3-2-1**: tre copie dei dati, su due tipi di storage diversi, con una copia offsite.

| Componente | Dati | Frequenza | Destinazione | Retention |
|------------|------|-----------|--------------|-----------|
| Docker configs | ./config/* | Giornaliero | NAS + Cloud | 30 giorni |
| Docker compose | docker-compose.yml, .env | Ad ogni modifica | Git + NAS | Illimitato |
| QNAP config | Sistema QTS | Settimanale | USB + Cloud | 5 versioni |
| Proxmox VMs | Tutte le VM | Settimanale | NAS | 4 versioni |
| Media library | /share/data/media | Mai (ricostruibile) | — | — |
| Database *arr | SQLite in ./config | Giornaliero | Incluso in Docker configs | 30 giorni |

---

## Procedure di Backup

### 1. Backup Configurazioni Docker (Automatico)

Il Makefile include già `make backup`. Per automatizzare:

```bash
# Creare cron job sul NAS
# Accedere via SSH: ssh admin@192.168.3.10

# Editare crontab
crontab -e

# Aggiungere (backup alle 02:00 ogni notte)
0 2 * * * cd /share/container/mediastack && /usr/local/bin/docker compose stop && tar -czf /share/backup/docker-config-$(date +\%Y\%m\%d).tar.gz ./config && /usr/local/bin/docker compose start

# Pulizia backup vecchi (mantieni ultimi 30)
0 3 * * * find /share/backup -name "docker-config-*.tar.gz" -mtime +30 -delete
```

**Verifica backup:**
```bash
# Listar backup disponibili
ls -lah /share/backup/docker-config-*.tar.gz

# Verificare integrità
tar -tzf /share/backup/docker-config-YYYYMMDD.tar.gz | head -20
```

### 2. Backup Configurazione QNAP QTS

**Via interfaccia web (raccomandato):**

1. Accedere a `http://192.168.3.10:8080`
2. Control Panel → System → Backup/Restore
3. Backup System Settings → Create Backup
4. Salvare il file `.bin` generato

**Contenuto del backup QTS:**
- Configurazione utenti e gruppi
- Shared folders e permessi
- Configurazione rete e VLAN
- App installate e relative configurazioni
- Scheduled tasks

**Automazione con script:**
```bash
#!/bin/bash
# backup-qts-config.sh
# Eseguire sul NAS via SSH

BACKUP_DIR="/share/backup/qts-config"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

# Backup configurazione sistema (richiede admin)
/sbin/config_util -e "$BACKUP_DIR/qts-config-$DATE.bin"

# Mantieni ultime 5 versioni
ls -t "$BACKUP_DIR"/qts-config-*.bin | tail -n +6 | xargs -r rm
```

### 3. Backup VM Proxmox

**Configurazione Proxmox Backup:**

1. Accedere a `https://192.168.3.20:8006`
2. Datacenter → Storage → Add → Directory
   - ID: `backup-nas`
   - Directory: `/mnt/nas-backup` (NFS mount da QNAP)
   - Content: VZDump backup file
3. Datacenter → Backup → Add
   - Storage: backup-nas
   - Schedule: `sun 03:00`
   - Selection mode: All
   - Mode: Snapshot (per VM running)
   - Compression: ZSTD
   - Retention: Keep last 4

**Mount NFS da QNAP su Proxmox:**
```bash
# Sul NAS: abilitare NFS per la shared folder backup
# Control Panel → Shared Folders → backup → Edit → NFS Permission
# Aggiungi: 192.168.3.20 (read/write, no_root_squash)

# Su Proxmox:
mkdir -p /mnt/nas-backup
echo "192.168.3.10:/backup /mnt/nas-backup nfs defaults 0 0" >> /etc/fstab
mount -a
```

**Backup manuale immediato:**
```bash
# Via CLI Proxmox
vzdump <vmid> --storage backup-nas --compress zstd --mode snapshot
```

### 4. Backup Offsite (Cloud)

**Opzione A: Duplicati verso Dropbox o Google Drive (consigliato)**

Duplicati ha supporto integrato per Dropbox e Google Drive:

1. Accedere a `http://192.168.3.10:8200`
2. Add backup → Destinazione: **Google Drive** o **Dropbox**
3. Autenticarsi con OAuth (link nel wizard)
4. Cartella remota: `homelab-backup`
5. Sorgente: `/source/config`
6. Schedule: giornaliero
7. Retention: Smart (7 daily, 4 weekly, 3 monthly)

**Opzione B: Rclone verso cloud storage**
```bash
# Installare rclone sul NAS
# https://rclone.org/install/

# Configurare remote (esempio: Google Drive)
rclone config
# Seguire wizard per creare remote "gdrive-backup"

# Sync backup folder
rclone sync /share/backup gdrive-backup:homelab-backup --progress

# Automatizzare via cron (domenica alle 04:00)
0 4 * * 0 rclone sync /share/backup gdrive-backup:homelab-backup --log-file=/var/log/rclone-backup.log
```

**Opzione C: Sync via Tailscale verso altro dispositivo**
```bash
# Se hai un secondo NAS/server raggiungibile via Tailscale
rsync -avz --delete /share/backup/ user@100.x.x.x:/backup/homelab/
```

---

## Procedure di Restore

### 1. Restore Configurazioni Docker

**Scenario: Corruzione config singolo servizio**
```bash
# Fermare il servizio
docker compose stop sonarr

# Backup config corrotta (per analisi)
mv ./config/sonarr ./config/sonarr.corrupted

# Restore da backup
tar -xzf /share/backup/docker-config-YYYYMMDD.tar.gz ./config/sonarr

# Riavviare
docker compose start sonarr

# Verificare logs
docker compose logs -f sonarr
```

**Scenario: Reinstallazione completa NAS**
```bash
# 1. Reinstallare Container Station su QTS
# 2. Ricreare struttura cartelle
./scripts/setup-folders.sh

# 3. Restore tutte le config
tar -xzf /share/backup/docker-config-YYYYMMDD.tar.gz -C /share/container/mediastack/

# 4. Verificare permessi
chown -R 1000:100 ./config
chmod -R 775 ./config

# 5. Avviare stack
docker compose up -d

# 6. Verificare tutti i servizi
make health
```

### 2. Restore Configurazione QNAP QTS

**Via interfaccia web:**

1. Dopo reinstallazione QTS, accedere a `http://<ip>:8080`
2. Control Panel → System → Backup/Restore
3. Restore System Settings
4. Caricare il file `.bin` di backup
5. Sistema richiederà riavvio

**Post-restore checklist:**
- [ ] Verificare shared folders
- [ ] Verificare utenti e permessi
- [ ] Reinstallare Container Station
- [ ] Verificare configurazione rete/VLAN
- [ ] Restore configurazioni Docker (procedura sopra)

### 3. Restore VM Proxmox

**Via interfaccia web:**

1. Accedere a `https://192.168.3.20:8006`
2. Storage → backup-nas → Content
3. Selezionare backup desiderato
4. Click "Restore"
5. Configurare: VM ID, Storage target
6. Start after restore: opzionale

**Via CLI:**
```bash
# Listare backup disponibili
qmrestore --list backup-nas

# Restore VM
qmrestore /mnt/nas-backup/vzdump-qemu-<vmid>-<date>.vma.zst <new-vmid> --storage local-lvm

# Se stesso VMID (sovrascrive)
qmrestore /mnt/nas-backup/vzdump-qemu-<vmid>-<date>.vma.zst <vmid> --force
```

### 4. Disaster Recovery Completo

**Scenario: Perdita totale NAS + Proxmox**

Prerequisiti: backup offsite disponibile (cloud o secondo sito)

**Fase 1: Hardware**
1. Sostituire/riparare hardware
2. Installare QTS su NAS
3. Installare Proxmox su Mini PC

**Fase 2: Configurazione base**
```bash
# NAS: configurazione rete manuale
# IP: 192.168.3.10/24
# Gateway: 192.168.3.1
# DNS: 1.1.1.1

# Proxmox: configurazione rete manuale
# IP: 192.168.3.20/24
# Gateway: 192.168.3.1
```

**Fase 3: Restore da offsite**
```bash
# Scaricare backup da cloud (Google Drive)
rclone copy gdrive-backup:homelab-backup /share/backup --progress

# Oppure restore diretto da Duplicati WebUI se configurato

# Oppure da Tailscale remote
rsync -avz user@100.x.x.x:/backup/homelab/ /share/backup/
```

**Fase 4: Restore componenti**
1. Restore QTS config (procedura sopra)
2. Ricreare struttura cartelle: `./scripts/setup-folders.sh`
3. Restore Docker configs
4. Restore VM Proxmox

**Fase 5: Verifica**
- [ ] Tutti i container running: `make status`
- [ ] Health check: `make health`
- [ ] Connettività inter-VLAN
- [ ] Accesso Plex da VLAN Media
- [ ] Tailscale connesso

---

## Verifica Periodica Backup

**Checklist mensile:**

| Verifica | Comando | Expected |
|----------|---------|----------|
| Backup Docker esistono | `ls -la /share/backup/docker-config-*.tar.gz \| tail -5` | File ultimi 5 giorni |
| Backup QTS esiste | `ls -la /share/backup/qts-config/` | File ultima settimana |
| Backup Proxmox esiste | `ls /mnt/nas-backup/` (su Proxmox) | File ultima settimana |
| Integrità Docker backup | `tar -tzf /share/backup/docker-config-$(date +%Y%m%d).tar.gz > /dev/null && echo OK` | OK |
| Spazio disco backup | `df -h /share/backup` | < 80% usage |
| Sync offsite OK | `rclone check /share/backup gdrive-backup:homelab-backup` | 0 differences |

**Test restore trimestrale:**

Ogni 3 mesi, eseguire restore di test:
1. Restore config Sonarr in directory temporanea
2. Verificare che database SQLite sia leggibile
3. Restore VM Proxmox con nuovo VMID temporaneo
4. Verificare boot e funzionamento
5. Eliminare VM di test

---

## Contatti e Escalation

| Risorsa | Contatto |
|---------|----------|
| Documentazione QNAP | qnap.com/en/how-to/knowledge-base |
| Forum Proxmox | forum.proxmox.com |
| Trash Guides Discord | trash-guides.info (link in homepage) |
| r/homelab | reddit.com/r/homelab |

---

## Changelog

| Data | Modifica |
|------|----------|
| 2025-01-02 | Creazione documento |
