# Checklist Deployment — QNAP TS-435XeU

> Checklist completa per setup iniziale NAS QNAP con Container Station e media stack

---

## Pre-Installazione Hardware

### Rack e Fisico
- [ ] NAS montato in rack U2 (sotto pannello ventilato)
- [ ] Isolante neoprene 5mm posizionato tra NAS e UPS
- [ ] Ventilazione laterale non ostruita
- [ ] Cavi SFP+ 10G collegati (porta 1 verso switch)
- [ ] Cavo RJ45 2.5GbE di backup collegato (opzionale)

### Storage
- [ ] HDD installati nei bay (verificare compatibilità: qnap.com/compatibility)
- [ ] HDD dello stesso modello/capacità per RAID
- [ ] SSD M.2 NVMe per caching installato (opzionale ma raccomandato)

---

## Setup Iniziale QTS

### Primo Avvio
- [ ] Collegare monitor + tastiera oppure usare Qfinder Pro
- [ ] Accedere a `http://<ip>:8080` o `http://qnapnas.local:8080`
- [ ] Completare wizard iniziale
- [ ] Aggiornare firmware all'ultima versione stabile
- [ ] Riavviare dopo aggiornamento

### Configurazione Amministratore
- [ ] Cambiare password admin default
- [ ] Creare utente amministrativo secondario
- [ ] Abilitare 2FA per admin (Control Panel → Security → 2-Step Verification)
- [ ] Disabilitare account "admin" default (opzionale, dopo creazione altro admin)

### Configurazione Rete
- [ ] Assegnare IP statico: `192.168.3.10`
- [ ] Subnet mask: `255.255.255.0`
- [ ] Gateway: `192.168.3.1`
- [ ] DNS primario: `192.168.3.1` (UDM-SE) o `1.1.1.1`
- [ ] DNS secondario: `1.0.0.1`
- [ ] Hostname: `qnap-nas` (o nome scelto)
- [ ] Verificare MTU 9000 se Jumbo Frames abilitati su switch

**Percorso:** Control Panel → Network & Virtual Switch → Interfaces

---

## Configurazione Storage

### Scelta Filesystem: ext4 vs ZFS

| Aspetto | ext4 | ZFS |
|---------|------|-----|
| **RAM minima** | ~256MB | **8-16GB dedicati** (1GB/TB per ARC) |
| **CPU overhead** | Basso | Medio-alto (checksumming, compression) |
| **Complessità** | Semplice, maturo | Complesso, curva apprendimento ripida |
| **Integrità dati** | Base (journaling) | Eccellente (checksumming end-to-end) |
| **Snapshot** | No (serve LVM) | Sì, nativi e efficienti |
| **Self-healing** | No | Sì (con mirror/raidz) |
| **Compression** | No | Sì (LZ4, ZSTD) - guadagno 10-30% |
| **Hardlinking** | ✓ Ottimo | ✓ Ottimo |
| **QNAP QTS support** | Nativo, stabile | Limitato |

**Raccomandazione: ext4**
- QTS ha supporto nativo e stabile
- Il TS-435XeU ha RAM limitata (4-8GB tipici)
- Per media server le feature avanzate ZFS non sono critiche
- Hardlinking funziona perfettamente

> ZFS avrebbe senso con 16GB+ RAM e priorità massima su integrità dati, oppure su Proxmox/TrueNAS.

### Scelta RAID: RAID 5 vs RAID 10

| Aspetto | RAID 5 | RAID 10 |
|---------|--------|---------|
| **Capacità utile (4 dischi)** | **75%** (3 su 4) | 50% (2 su 4) |
| **Fault tolerance** | 1 disco | 1 disco (2 se in mirror diversi) |
| **Read performance** | Buona | **Eccellente** |
| **Write performance** | Degradata (parity calc) | **Eccellente** |
| **Rebuild time** | Lungo + stress dischi | **Veloce** |
| **Rischio durante rebuild** | Alto (URE può fallire) | **Basso** |
| **Random I/O (Docker)** | Medio | **Ottimo** |
| **Sequential I/O (streaming)** | Buono | Buono |
| **Costo per TB** | **Minore** | Maggiore |

**Performance indicative (4x HDD SATA):**
```
                    RAID 5          RAID 10
Sequential Read:    ~400 MB/s       ~400 MB/s
Sequential Write:   ~200 MB/s       ~300 MB/s
Random Read 4K:     ~300 IOPS       ~500 IOPS
Random Write 4K:    ~100 IOPS       ~400 IOPS  ← differenza critica per Docker
```

**Raccomandazione: RAID 10**
- Container Station genera molto random I/O
- Database SQLite degli *arr beneficiano di write veloci
- Rebuild più sicuro e veloce
- Hardlinking e import istantanei

> RAID 5 ha senso se la capacità è priorità assoluta e il budget per dischi è limitato.

### Riepilogo Configurazione Raccomandata

| Componente | Scelta | Motivo |
|------------|--------|--------|
| **Filesystem** | ext4 | Compatibilità QTS, basso overhead RAM/CPU |
| **RAID** | RAID 10 | Performance I/O per Docker, rebuild sicuro |
| **Volume** | Static | Miglior performance hardlink |

---

### Storage Pool
- [ ] Control Panel → Storage & Snapshots → Storage/Snapshots
- [ ] Create → New Storage Pool
- [ ] Selezionare tutti gli HDD (4 dischi)
- [ ] RAID type: **RAID 10** (raccomandato per media server)
  - Alternativa 2 dischi: RAID 1 (mirror)
  - Alternativa se capacità prioritaria: RAID 5
- [ ] Alert threshold: 80%
- [ ] Completare creazione (tempo variabile in base a capacità)

### SSD Cache (se presente M.2)
- [ ] Storage & Snapshots → Cache Acceleration
- [ ] Create
- [ ] Selezionare SSD M.2
- [ ] Cache mode: Read-Write (raccomandato per Container Station)
- [ ] Associare allo Storage Pool principale

### Static Volume
- [ ] Storage & Snapshots → Create → New Volume
- [ ] Volume type: **Static Volume** (raccomandato per hardlink performance)
  - Alternativa: Thick Volume se preferisci snapshots nativi
- [ ] Allocare tutto lo spazio disponibile (o quota desiderata)
- [ ] Nome: `DataVol1`
- [ ] Filesystem: **ext4** (raccomandato per compatibilità e basso overhead)

### Shared Folders
Creare le seguenti shared folders su DataVol1:

| Nome | Percorso | Scopo |
|------|----------|-------|
| data | /share/data | Mount principale per hardlinking |
| container | /share/container | Docker configs e compose files |
| backup | /share/backup | Backup locali |

**Percorso:** Control Panel → Shared Folders → Create

Per ogni folder:
- [ ] Creare folder
- [ ] Permessi: admin RW, everyone RO (o secondo policy)
- [ ] Abilitare Recycle Bin (opzionale)

---

## Configurazione Utenti e Permessi

### Utente Docker
- [ ] Control Panel → Users → Create
- [ ] Username: `dockeruser` (o nome scelto)
- [ ] UID: verificare che sia 1000 (o annotare per PUID)
- [ ] Password: generare password sicura
- [ ] Permessi shared folders:
  - data: RW
  - container: RW
  - backup: RO

### Abilitare SSH
- [ ] Control Panel → Network Services → Telnet/SSH
- [ ] Enable SSH service: **On**
- [ ] Port: 22 (default)
- [ ] Apply

### Verificare PUID/PGID
```bash
# Connettersi via SSH
ssh admin@192.168.3.10

# Verificare ID utente
id dockeruser
# Output atteso: uid=1000(dockeruser) gid=100(everyone) ...
#                     ^^^^          ^^^
#                     PUID          PGID
```

> **Importante**: Annota questi valori! Serviranno per configurare il file `.env` dopo aver clonato il repository.

---

## Installazione Container Station

### Installazione
- [ ] App Center → Search "Container Station"
- [ ] Installare Container Station 3
- [ ] Attendere completamento
- [ ] Aprire Container Station
- [ ] Completare wizard iniziale

### Configurazione Container Station
- [ ] Settings → Docker root path: lasciare default o spostare su DataVol1
- [ ] Settings → Default registry: Docker Hub (default)
- [ ] Verificare versione Docker: `docker version`

### Struttura Cartelle Media Stack

> **Nota**: Il repository homelab va clonato/copiato **solo sul NAS**, non su Proxmox.
> Proxmox ospita solo il container Plex che accede ai media via NFS.

#### Opzione A: Clone Git (consigliato)

```bash
# Via SSH sul NAS
ssh admin@192.168.3.10

# Installare git se non presente (App Center -> Git)
# Oppure via Entware: opkg install git

cd /share/container
git clone https://github.com/<tuo-username>/homelab.git mediastack
cd mediastack
```

#### Opzione B: Copia manuale (se git non disponibile)

```bash
# Via SSH sul NAS
cd /share/container
mkdir -p mediastack
cd mediastack

# Da un PC con il repository clonato, copiare via SCP:
# scp -r docker/ scripts/ Makefile admin@192.168.3.10:/share/container/mediastack/

# Oppure usare File Station per upload dei file
```

---

## Deploy Docker Stack

### Setup Iniziale e Configurazione .env

Il comando `make setup` crea la struttura cartelle e il file `.env`. **Deve essere eseguito prima del primo avvio.**

```bash
cd /share/container/mediastack

# Eseguire setup (crea cartelle data, config e .env da template)
make setup

# Editare .env con i valori corretti
nano docker/.env
```

Configurazione **obbligatoria** in `docker/.env`:

```bash
# PUID e PGID devono corrispondere all'utente dockeruser creato in precedenza
# Ottieni i valori con: id dockeruser
# Esempio output: uid=1000(dockeruser) gid=100(everyone)
PUID=1000    # ← sostituisci con uid di dockeruser
PGID=100     # ← sostituisci con gid di dockeruser

# Timezone
TZ=Europe/Rome

# Password per Pi-hole (genera con: openssl rand -base64 24)
PIHOLE_PASSWORD=<password-sicura>
```

> **Critico**: Se PUID/PGID non corrispondono all'utente proprietario di `/share/data`, i container non avranno i permessi corretti per scrivere i file e l'hardlinking non funzionerà.

### Verifica Struttura e Permessi

Dopo `make setup`, verificare che la struttura sia stata creata:

```bash
# Verificare cartelle data
ls -la /share/data/
# Deve contenere: torrents/, usenet/, media/

# Verificare cartelle config
ls -la ./config/
# Deve contenere sottocartelle per ogni servizio

# Verificare ownership (deve corrispondere a PUID:PGID configurati)
ls -ln /share/data
# Esempio output per PUID=1000 PGID=100:
# drwxrwxr-x 1000 100 ... media
# drwxrwxr-x 1000 100 ... torrents
# drwxrwxr-x 1000 100 ... usenet
```

Se i permessi non sono corretti:
```bash
# Sostituire 1000:100 con i tuoi PUID:PGID da .env
sudo chown -R 1000:100 /share/data
sudo chown -R 1000:100 /share/container/mediastack/config
sudo chmod -R 775 /share/data
sudo chmod -R 775 /share/container/mediastack/config
```

### Verifica Porta DNS

Prima di avviare, verificare che la porta 53 non sia già in uso da QTS:

```bash
# Verificare se porta 53 è occupata
ss -tulnp | grep :53

# Se occupata, disabilitare DNS locale QTS:
# Control Panel → Network & Virtual Switch → DNS Server → Disabilita
```

### Primo Avvio
```bash
cd /share/container/mediastack

# Validare configurazione
make validate

# Pull immagini
make pull

# Avvio stack
make up

# Verificare status
make status

# Verificare logs per errori
make logs | grep -i error
```

### Verifica Servizi
- [ ] Sonarr: `http://192.168.3.10:8989` risponde
- [ ] Radarr: `http://192.168.3.10:7878` risponde
- [ ] Lidarr: `http://192.168.3.10:8686` risponde
- [ ] Prowlarr: `http://192.168.3.10:9696` risponde
- [ ] Bazarr: `http://192.168.3.10:6767` risponde
- [ ] qBittorrent: `http://192.168.3.10:8080` risponde
- [ ] NZBGet: `http://192.168.3.10:6789` risponde
- [ ] Pi-hole: `http://192.168.3.10:8081/admin` risponde
- [ ] Home Assistant: `http://192.168.3.10:8123` risponde
- [ ] Portainer: `https://192.168.3.10:9443` risponde
- [ ] Uptime Kuma: `http://192.168.3.10:3001` risponde
- [ ] Duplicati: `http://192.168.3.10:8200` risponde

---

## Configurazione Servizi *arr

### Prowlarr (primo)
- [ ] Accedere a `http://192.168.3.10:9696`
- [ ] Settings → General → Authentication: Forms
- [ ] Creare username/password
- [ ] Settings → General → Annotare API Key
- [ ] Indexers → Add indexers desiderati
- [ ] Settings → Apps → Add Sonarr
  - Prowlarr Server: `http://prowlarr:9696`
  - Sonarr Server: `http://sonarr:8989`
  - API Key: (da Sonarr)
- [ ] Ripetere per Radarr e Lidarr

### qBittorrent
- [ ] Accedere a `http://192.168.3.10:8080`
- [ ] **Credenziali primo accesso**:
  - Username: `admin`
  - Password: generata casualmente al primo avvio
  - Recuperare la password dai log:
    ```bash
    docker logs qbittorrent 2>&1 | grep -i password
    # Output: "The WebUI administrator password was not set. A temporary password is provided: XXXXXX"
    ```
- [ ] Options → Downloads:
  - Default Save Path: `/data/torrents`
  - Keep incomplete in: disabilitato (usa stesso path)
- [ ] Options → Downloads → Default Torrent Management Mode: **Automatic**
- [ ] Options → BitTorrent:
  - Seeding limits secondo preferenze
- [ ] Options → WebUI:
  - Cambiare password
- [ ] Categories (click destro nel pannello sinistro → Add category):
  - `movies` → Save path: `movies`
  - `tv` → Save path: `tv`
  - `music` → Save path: `music`

### NZBGet
- [ ] Accedere a `http://192.168.3.10:6789`
- [ ] Completare wizard iniziale
- [ ] Settings → Paths:
  - MainDir: `/data/usenet`
  - DestDir: `/data/usenet/complete`
  - InterDir: `/data/usenet/incomplete`
- [ ] Settings → Categories:
  - `movies` → DestDir: `movies`
  - `tv` → DestDir: `tv`
  - `music` → DestDir: `music`
- [ ] Settings → Security → ControlUsername/ControlPassword: annotare

### Sonarr
- [ ] Accedere a `http://192.168.3.10:8989`
- [ ] Settings → Media Management:
  - Rename Episodes: Yes
  - Standard Episode Format: configurare secondo preferenze
  - **Use Hardlinks instead of Copy: Yes** ← CRITICO
  - Root Folders → Add: `/data/media/tv`
- [ ] Settings → Download Clients:
  - Add → qBittorrent
    - Host: `qbittorrent`
    - Port: `8080`
    - Category: `tv`
  - Add → NZBGet
    - Host: `nzbget`
    - Port: `6789`
    - Username/Password: (da NZBGet)
    - Category: `tv`
- [ ] Settings → General → API Key: annotare (per Prowlarr)

### Radarr
- [ ] Accedere a `http://192.168.3.10:7878`
- [ ] Settings → Media Management:
  - Rename Movies: Yes
  - **Use Hardlinks instead of Copy: Yes** ← CRITICO
  - Root Folders → Add: `/data/media/movies`
- [ ] Settings → Download Clients: (come Sonarr, category: `movies`)
- [ ] Settings → General → API Key: annotare

### Lidarr
- [ ] Accedere a `http://192.168.3.10:8686`
- [ ] Settings → Media Management:
  - **Use Hardlinks instead of Copy: Yes** ← CRITICO
  - Root Folders → Add: `/data/media/music`
- [ ] Settings → Download Clients: (come Sonarr, category: `music`)
- [ ] Settings → General → API Key: annotare

### Bazarr
- [ ] Accedere a `http://192.168.3.10:6767`
- [ ] Settings → Sonarr:
  - Address: `sonarr`
  - Port: `8989`
  - API Key: (da Sonarr)
  - Test → Save
- [ ] Settings → Radarr: (configurazione analoga)
- [ ] Settings → Languages: configurare lingue sottotitoli
- [ ] Settings → Providers: aggiungere provider sottotitoli

---

## Verifica Hardlinking

Test critico per verificare che hardlinking funzioni:

```bash
# Via SSH sul NAS (path host)
# I container vedono questi path come /data/...

# 1. Creare file di test in torrents
echo "test hardlink" > /share/data/torrents/movies/test.txt

# 2. Creare hardlink in media
ln /share/data/torrents/movies/test.txt /share/data/media/movies/test.txt

# 3. Verificare stesso inode
ls -li /share/data/torrents/movies/test.txt /share/data/media/movies/test.txt

# Output atteso: stesso numero inode (prima colonna)
# Esempio:
# 12345 -rw-r--r-- 2 dockeruser everyone 15 Jan  2 10:00 /share/data/torrents/movies/test.txt
# 12345 -rw-r--r-- 2 dockeruser everyone 15 Jan  2 10:00 /share/data/media/movies/test.txt
#   ^-- stesso inode = hardlink OK

# 4. Cleanup
rm /share/data/torrents/movies/test.txt /share/data/media/movies/test.txt
```

> **Nota sui path**: Sul NAS host i path sono `/share/data/...`, mentre i container vedono `/data/...` grazie al mount `-v /share/data:/data`. Entrambi puntano allo stesso filesystem, quindi gli hardlink funzionano.

Se inode diversi: **PROBLEMA** — verificare che entrambi i path siano sullo stesso volume/filesystem.

---

## Configurazione Pi-hole

- [ ] Accedere a `http://192.168.3.10:8081/admin`
- [ ] Login con password da `.env`
- [ ] Settings → DNS:
  - Upstream DNS: verificare 1.1.1.1, 1.0.0.1
  - Interface: rispondere su tutte le interfacce
- [ ] Adlists → Aggiungere liste aggiuntive (opzionale):
  - `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
  - `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/multi.txt` (Hagezi Multi - consigliata)
  - `https://small.oisd.nl/domainswild` (OISD - blocklist unificata)
  - `https://v.firebog.net/hosts/lists.php?type=tick` (Firebog Ticked - curate dalla community)

### Configurare UDM-SE per usare Pi-hole
- [ ] UDM-SE → Settings → Networks → (ogni VLAN)
- [ ] DHCP Name Server: `192.168.3.10`
- [ ] Oppure: usare Pi-hole solo per VLAN specifiche

---

## Configurazione Recyclarr

Recyclarr sincronizza automaticamente i Quality Profiles da [Trash Guides](https://trash-guides.info/).

### Generare Configurazione Base

Al primo avvio, Recyclarr crea un file template. Per generare una configurazione completa:

```bash
# Generare template configurazione
make recyclarr-config

# Oppure manualmente
docker exec recyclarr recyclarr config create
```

### Configurare recyclarr.yml

Editare `./config/recyclarr/recyclarr.yml`:

```yaml
# Esempio configurazione minima
sonarr:
  series:
    base_url: http://sonarr:8989
    api_key: <API_KEY_SONARR>  # Da Sonarr → Settings → General
    quality_definition:
      type: series
    quality_profiles:
      - name: WEB-1080p

radarr:
  movies:
    base_url: http://radarr:7878
    api_key: <API_KEY_RADARR>  # Da Radarr → Settings → General
    quality_definition:
      type: movie
    quality_profiles:
      - name: HD Bluray + WEB
```

> **Documentazione completa**: https://recyclarr.dev/wiki/yaml/config-reference/

### Sincronizzazione

```bash
# Sync manuale
make recyclarr-sync

# Oppure
docker exec recyclarr recyclarr sync
```

### Verifica

- [ ] Verificare Quality Profiles creati in Sonarr (Settings → Profiles)
- [ ] Verificare Quality Profiles creati in Radarr (Settings → Profiles)
- [ ] Verificare Custom Formats importati

---

## Post-Installazione

### Backup Configurazione Iniziale
```bash
cd /share/container/mediastack
make backup
```
- [ ] Backup creato in `./backups/`
- [ ] Copiare backup offsite (USB, cloud)

### Backup QTS Config
- [ ] Control Panel → System → Backup/Restore → Backup System Settings
- [ ] Salvare file `.bin` in location sicura

### Documentazione
- [ ] Annotare tutti gli API key in password manager
- [ ] Aggiornare documentazione con eventuali modifiche
- [ ] Screenshot configurazioni importanti

---

## Troubleshooting Comune

| Problema | Causa Probabile | Soluzione |
|----------|-----------------|-----------|
| Container non parte | Permessi cartelle | `chown -R $PUID:$PGID ./config` (usa valori da .env) |
| Hardlink non funziona | Path su filesystem diversi | Verificare mount points |
| qBittorrent "stalled" | Porta non raggiungibile | Verificare port forwarding 50413 |
| Pi-hole non risolve | Porta 53 in uso | Verificare altri servizi DNS su NAS |
| WebUI non risponde | Container crashed | `docker compose logs <service>` |
| Permessi errati sui file | PUID/PGID non corrispondono | Verificare `id dockeruser` e aggiornare .env |

---

## Riferimenti

- Trash Guides Docker Setup: https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/
- QNAP Container Station: https://www.qnap.com/en/how-to/tutorial/article/how-to-use-container-station-3
- LinuxServer.io Images: https://docs.linuxserver.io/
