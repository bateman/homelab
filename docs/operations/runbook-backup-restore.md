# Runbook — Backup e Restore Homelab

> Procedure operative per backup e disaster recovery di NAS QNAP TS-435XeU e Mini PC Proxmox

---

## Panoramica Strategia Backup

La strategia segue la regola **3-2-1**: tre copie dei dati, su due tipi di storage diversi, con una copia offsite.

| Componente | Dati | Frequenza | Destinazione | Retention |
|------------|------|-----------|--------------|-----------|
| Docker configs | ./config/* (include *arr, Traefik, Pi-hole, etc.) | Giornaliero | NAS + Cloud | 30 giorni |
| Docker compose | compose.yml, compose.media.yml, .env | Ad ogni modifica | Git + NAS | Illimitato |
| QNAP config | Sistema QTS | Settimanale | USB + Cloud | 5 versioni |
| Proxmox VMs | Tutte le VM | Settimanale | NAS | 4 versioni |
| Media library | /share/data/media | Mai (ricostruibile) | — | — |
| Database *arr | SQLite in ./config | Giornaliero | Incluso in Docker configs | 30 giorni |

> **Nota**: La cartella `./config` contiene le configurazioni di tutti i servizi Docker: Sonarr, Radarr, Lidarr, Prowlarr, Bazarr, qBittorrent, NZBGet, Pi-hole, Home Assistant, Portainer, Duplicati, Uptime Kuma, Recyclarr, Traefik, Huntarr, Cleanuparr.

---

## Procedure di Backup

### 1. Backup Configurazioni Docker (Duplicati - Raccomandato)

Il container Duplicati gestisce backup automatici con deduplicazione e cifratura.

**Configurazione iniziale:**

1. Accedere a `http://192.168.3.10:8200`
2. Add backup → Configurare:
   - **Nome**: `docker-configs-local`
   - **Destinazione**: Folder path → `/backups`
   - **Sorgente**: `/source/config`
   - **Schedule**: Giornaliero alle 02:00
   - **Retention**: Smart backup retention (7 daily, 4 weekly, 3 monthly)
   - **Encryption**: Opzionale ma consigliato per backup offsite

**Trigger backup manuale:**
```bash
make backup  # Triggera Duplicati via API
```

**Verifica backup:**
- Accedere a Duplicati WebUI → Selezionare backup → "Show log"
- Oppure: Restore → Browse per verificare contenuti

#### Alternativa: Backup manuale con cron

Se preferisci backup tar.gz manuali senza Duplicati:

```bash
# Creare cron job sul NAS (ssh admin@192.168.3.10)
crontab -e

# Backup alle 02:00 (richiede downtime ~1 minuto)
# Nota: adattare il path alla propria installazione
0 2 * * * cd /share/container/mediastack && make down && tar -czf /share/backup/docker-config-$(date +\%Y\%m\%d).tar.gz ./config && make up

# Pulizia backup vecchi (mantieni ultimi 30)
0 3 * * * find /share/backup -name "docker-config-*.tar.gz" -mtime +30 -delete
```

**Verifica backup tar.gz:**
```bash
ls -lah /share/backup/docker-config-*.tar.gz
tar -tzf /share/backup/docker-config-YYYYMMDD.tar.gz | head -20
```

### 2. Backup Configurazione QNAP QTS

Lo script `scripts/backup-qts-config.sh` automatizza il backup della configurazione QTS.

**Contenuto del backup QTS:**
- Configurazione utenti e gruppi
- Shared folders e permessi
- Configurazione rete e VLAN
- App installate e relative configurazioni
- Scheduled tasks

**Backup manuale:**
```bash
make backup-qts  # Esegue backup e mostra output dettagliato
```

**Automazione con cron (consigliato):**
```bash
# Sul NAS, aggiungere a crontab (ssh admin@192.168.3.10)
crontab -e

# Domenica alle 03:00
0 3 * * 0 /share/container/homelab/scripts/backup-qts-config.sh --notify >> /var/log/qts-backup.log 2>&1
```

**Parametri configurabili (variabili ambiente):**
| Variabile | Default | Descrizione |
|-----------|---------|-------------|
| `QTS_BACKUP_DIR` | `/share/backup/qts-config` | Directory destinazione backup |
| `QTS_BACKUP_RETENTION` | `5` | Numero backup da mantenere |
| `HA_WEBHOOK_URL` | - | URL webhook Home Assistant per notifiche |

**Verifica backup disponibili:**
```bash
ls -la /share/backup/qts-config/
```

**Backup manuale via interfaccia web (alternativa):**

1. Accedere a `https://192.168.3.10:5000` (porta HTTPS di QTS)
2. Control Panel → System → Backup/Restore
3. Backup System Settings → Create Backup
4. Salvare il file `.bin` generato

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
# Fermare il servizio (dalla directory del progetto)
make logs-sonarr  # Prima verificare i log per capire il problema
docker compose -f docker/compose.yml -f docker/compose.media.yml stop sonarr

# Backup config corrotta (per analisi)
mv ./config/sonarr ./config/sonarr.corrupted

# Restore da backup
tar -xzf /share/backup/docker-config-YYYYMMDD.tar.gz ./config/sonarr

# Riavviare
docker compose -f docker/compose.yml -f docker/compose.media.yml start sonarr

# Verificare logs
make logs-sonarr
```

**Scenario: Reinstallazione completa NAS**
```bash
# 1. Reinstallare Container Station su QTS
# 2. Clonare repository
git clone <repo-url> /share/container/homelab
cd /share/container/homelab

# 3. Ricreare struttura cartelle
./scripts/setup-folders.sh

# 4. Restore tutte le config
tar -xzf /share/backup/docker-config-YYYYMMDD.tar.gz -C .

# 5. Verificare permessi
sudo chown -R 1000:100 ./config
sudo chmod -R 775 ./config

# 6. Copiare .env
cp docker/.env.example docker/.env
# Editare docker/.env con le password corrette

# 7. Avviare stack
make up

# 8. Verificare tutti i servizi
make health
```

### 2. Restore Configurazione QNAP QTS

**Via interfaccia web:**

1. Dopo reinstallazione QTS, accedere a `https://<ip>:5000`
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
ls -la /mnt/nas-backup/
# oppure
pvesm list backup-nas

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

```bash
# 1. Verificare esistenza backup Docker (ultimi 5 giorni)
ls -la /share/backup/docker-config-*.tar.gz | tail -5

# 2. Verificare esistenza backup QTS (ultima settimana)
ls -la /share/backup/qts-config/

# 3. Verificare esistenza backup Proxmox (su Proxmox, ultima settimana)
ls /mnt/nas-backup/

# 4. Verificare integrità backup Docker
tar -tzf /share/backup/docker-config-$(date +%Y%m%d).tar.gz > /dev/null && echo "OK"

# 5. Verificare spazio disco (< 80%)
df -h /share/backup

# 6. Verificare sync offsite (se configurato rclone)
rclone check /share/backup gdrive-backup:homelab-backup
```

**Test restore trimestrale:**

Ogni 3 mesi, eseguire restore di test:
1. Restore config Sonarr in directory temporanea
2. Verificare che database SQLite sia leggibile
3. Restore VM Proxmox con nuovo VMID temporaneo
4. Verificare boot e funzionamento
5. Eliminare VM di test

---

## Verifica Automatica Backup

### Script Implementato

Lo script `scripts/verify-backup.sh` verifica automaticamente l'integrita' dei backup:

1. **Estrazione archivio**: Verifica che il tar.gz sia leggibile
2. **Integrita' SQLite**: Controlla i database di Sonarr, Radarr, Lidarr, Prowlarr, Bazarr
3. **Eta' backup**: Warning se piu' vecchio di 7 giorni
4. **File critici**: Verifica presenza configurazioni Traefik

### Utilizzo

```bash
# Verifica manuale (verbose)
make verify-backup

# Oppure direttamente
./scripts/verify-backup.sh --verbose

# Con notifica Home Assistant (richiede HA_WEBHOOK_URL)
./scripts/verify-backup.sh --notify
```

### Automazione con Cron

Per verifica automatica settimanale (consigliato):

```bash
# Sul NAS, aggiungere a crontab
crontab -e

# Domenica alle 05:00, dopo il backup notturno
0 5 * * 0 /share/container/homelab/scripts/verify-backup.sh --notify >> /var/log/verify-backup.log 2>&1
```

### Notifiche Home Assistant (Opzionale)

Per ricevere alert in caso di errori:

1. Creare automazione webhook in Home Assistant
2. Impostare variabile ambiente:
   ```bash
   # In docker/.env.secrets
   HA_WEBHOOK_URL=http://192.168.3.10:8123/api/webhook/backup-verify
   ```
3. Eseguire con `--notify`

### Exit Codes

| Codice | Significato |
|--------|-------------|
| 0 | Verifica OK |
| 1 | Errori rilevati (backup corrotto) |
| 2 | Nessun backup trovato |

### Opzioni Avanzate (Non Implementate)

**Duplicati Verify (integrato)**

Duplicati ha una funzione "Verify" che controlla l'integrita' dei backup:
1. WebUI → Selezionare backup
2. Operazioni → "Verify files"
3. Schedulare via Advanced options → `--backup-test-samples=5`

**Restore automatico in ambiente isolato**

Per homelab avanzati:
1. VM Proxmox dedicata per test restore
2. Script che ogni settimana:
   - Restore config in directory temporanea
   - Avvia container in rete isolata
   - Verifica healthcheck
   - Elimina e notifica risultato

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
| 2026-01-06 | Aggiunto script backup-qts-config.sh per automazione backup QTS |
| 2025-01-04 | Revisione: Duplicati come metodo primario, fix comandi docker compose, chiarimenti porte QTS |
| 2025-01-02 | Creazione documento |
