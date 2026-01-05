# START HERE - Guida Installazione Completa

> Questa guida fornisce l'ordine corretto per installare e configurare l'intero homelab dall'inizio alla fine.

---

## Prerequisiti

Prima di iniziare, assicurati di avere:

- [ ] Tutto l'hardware elencato in [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md)
- [ ] Accesso alla rete locale e a un computer per la configurazione
- [ ] Account per servizi cloud (opzionale: Google Drive o Dropbox per backup offsite)
- [ ] Abbonamenti indexer/Usenet (per lo stack media)

---

## Panoramica Fasi

| Fase | Descrizione | Documenti di Riferimento |
|------|-------------|--------------------------|
| 1 | Installazione Hardware | [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md) |
| 2 | Setup Rete UniFi | [`docs/setup/NETWORK_SETUP.md`](docs/setup/NETWORK_SETUP.md) |
| 3 | Setup NAS QNAP | [`docs/setup/NAS_SETUP.md`](docs/setup/NAS_SETUP.md) |
| 4 | Deploy Stack Docker | [`docs/setup/NAS_SETUP.md`](docs/setup/NAS_SETUP.md), [`Makefile`](Makefile) |
| 5 | Configurazione Servizi | [`docs/setup/NAS_SETUP.md`](docs/setup/NAS_SETUP.md) |
| 5b | Reverse Proxy *(opzionale)* | [`docs/setup/REVERSE_PROXY_SETUP.md`](docs/setup/REVERSE_PROXY_SETUP.md) |
| 6 | Setup Proxmox/Plex | [`docs/setup/PROXMOX_SETUP.md`](docs/setup/PROXMOX_SETUP.md) |
| 7 | Configurazione Backup | [`docs/operations/runbook-backup-restore.md`](docs/operations/runbook-backup-restore.md) |
| 8 | Verifica Finale | Questa guida |

---

## Fase 1: Installazione Hardware

**Riferimento:** [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md)

### Layout Rack (dal basso verso l'alto)

1. [ ] **U1**: UPS (peso in basso, minima generazione calore)
2. [ ] **Isolante**: Neoprene 5mm tra UPS e NAS
3. [ ] **U2**: QNAP TS-435XeU (zona fresca per HDD)
4. [ ] **U3**: Multipresa rack (alimentazione dispositivi)
5. [ ] **U4**: Patch panel (passivo, buffer termico)
6. [ ] **U5**: UDM-SE
7. [ ] **U6**: USW-Enterprise-8-PoE
8. [ ] **U7**: Pannello ventilato (isolamento termico)
9. [ ] **U8**: Lenovo Mini PC (top, dissipazione verso l'alto)

### Cablaggio

- [ ] Collegare UDM-SE porta WAN → Iliad Box LAN
- [ ] Collegare UDM-SE porta 1 → Switch porta 1 (trunk VLAN)
- [ ] Collegare Switch porta SFP+ → NAS porta SFP+ (10GbE)
- [ ] Collegare Switch porta 2 → Mini PC (2.5GbE via adattatore USB-C)
- [ ] Collegare tutti i dispositivi a UPS

### Verifica

```bash
# Tutti i LED di stato dovrebbero essere accesi
# UPS dovrebbe mostrare carico attivo
```

---

## Fase 2: Setup Rete UniFi

**Riferimento:** [`docs/setup/NETWORK_SETUP.md`](docs/setup/NETWORK_SETUP.md)

> ⚠️ Completare questa fase PRIMA di configurare qualsiasi altro dispositivo

### 2.1 Setup Iniziale UDM-SE

1. [ ] Collegare PC direttamente a UDM-SE porta LAN
2. [ ] Accedere a `https://192.168.1.1` (IP default)
3. [ ] Completare wizard UniFi
4. [ ] Creare account UniFi o usare esistente

### 2.2 Creazione VLAN

Creare le seguenti reti in **Settings → Networks**:

| VLAN ID | Nome | Subnet | Gateway | DHCP Range |
|---------|------|--------|---------|------------|
| 2 | Management | 192.168.2.0/24 | 192.168.2.1 | .100-.200 |
| 3 | Servers | 192.168.3.0/24 | 192.168.3.1 | Disabilitato (IP statici) |
| 4 | Media | 192.168.4.0/24 | 192.168.4.1 | .100-.200 |
| 5 | Guest | 192.168.5.0/24 | 192.168.5.1 | .100-.200 |
| 6 | IoT | 192.168.6.0/24 | 192.168.6.1 | .100-.200 |

### 2.3 Configurazione Switch

1. [ ] Adottare switch in UniFi Controller
2. [ ] Configurare porte switch:
   - Porta 1: Trunk (tutte le VLAN)
   - Porta SFP+: VLAN 3 (Servers)
   - Porta 2: VLAN 3 (Servers)

### 2.4 Regole Firewall

**Riferimento:** [`docs/network/firewall-config.md`](docs/network/firewall-config.md)

1. [ ] Creare gruppi IP (vedi `firewall-config.md` sezione "IP Groups")
2. [ ] Creare gruppi porte (vedi `firewall-config.md` sezione "Port Groups")
3. [ ] Inserire regole firewall nell'ordine esatto specificato

### Verifica Fase 2

```bash
# Da un PC su VLAN 3
ping 192.168.3.1    # Gateway
ping 8.8.8.8        # Internet
ping 192.168.2.1    # Management VLAN (dovrebbe funzionare)
```

---

## Fase 3: Setup NAS QNAP

**Riferimento:** [`docs/setup/NAS_SETUP.md`](docs/setup/NAS_SETUP.md)

Seguire la checklist completa. Punti chiave:

### 3.1 Setup QTS

1. [ ] Primo avvio e wizard iniziale
2. [ ] Aggiornamento firmware
3. [ ] Configurazione IP statico: `192.168.3.10`
4. [ ] Creazione utenti e sicurezza

### 3.2 Configurazione Storage

1. [ ] Creazione Storage Pool (RAID)
2. [ ] Creazione Static Volume
3. [ ] Creazione Shared Folders:
   - `/share/data` - Dati media e download
   - `/share/container` - File Docker
   - `/share/backup` - Backup

### 3.3 Container Station

1. [ ] Installare Container Station 3 da App Center
2. [ ] Completare wizard iniziale
3. [ ] Verificare Docker funzionante:
   ```bash
   ssh admin@192.168.3.10
   docker version
   ```

### Verifica Fase 3

- [ ] QTS accessibile: `http://192.168.3.10:8080` (o `https://192.168.3.10:8443`)
- [ ] SSH funzionante
- [ ] Docker installato
- [ ] Shared folders create

---

## Fase 4: Deploy Stack Docker

### 4.1 Preparazione File

```bash
# SSH nel NAS
ssh admin@192.168.3.10

# Creare directory
mkdir -p /share/container/mediastack
cd /share/container/mediastack

# Copiare i file dal repository (via SCP o SFTP):
# - docker/compose.yml
# - docker/compose.media.yml
# - Makefile
# - scripts/setup-folders.sh
# - docker/.env.example
```

### 4.2 Setup Struttura Cartelle

```bash
# Eseguire setup completo (crea cartelle data, config e file .env)
make setup

# Editare file .env con i valori corretti
nano docker/.env
```

**Configurazione obbligatoria in `.env`:**

```bash
# Verificare prima PUID/PGID dell'utente dockeruser creato in Fase 3
ssh admin@192.168.3.10 "id dockeruser"
# Output: uid=1000(dockeruser) gid=100(everyone)

# Impostare in docker/.env:
PUID=1000          # ← valore uid da comando id
PGID=100           # ← valore gid da comando id
TZ=Europe/Rome
PIHOLE_PASSWORD=<password-sicura>
```

> **Critico**: Se PUID/PGID non corrispondono all'utente proprietario delle cartelle, i container non avranno permessi di scrittura.

### 4.2.1 Verifica Permessi

```bash
# Verificare ownership cartelle (deve corrispondere a PUID:PGID)
ls -ln /share/data

# Se necessario, correggere permessi:
sudo chown -R 1000:100 /share/data
sudo chown -R 1000:100 ./config
```

### 4.2.2 Verifica Porta DNS

Prima di avviare lo stack, verificare che la porta 53 non sia già in uso:

```bash
ss -tulnp | grep :53

# Se occupata, disabilitare DNS locale QTS:
# Control Panel → Network & Virtual Switch → DNS Server → Disabilita
```

### 4.3 Avvio Container

```bash
# Validare configurazione
make validate

# Pull immagini
make pull

# Avviare stack
make up

# Verificare stato
make status
```

### Verifica Fase 4

```bash
# Tutti i container devono essere "Up" e "healthy"
make health

# Visualizzare URL servizi
make urls
```

---

## Fase 5: Configurazione Servizi

**Riferimento:** [`docs/setup/NAS_SETUP.md`](docs/setup/NAS_SETUP.md) sezione "Configurazione Servizi *arr"

### Ordine di Configurazione (IMPORTANTE)

Seguire esattamente questo ordine per le dipendenze:

```
1. Prowlarr        → Indexer manager (configurare per primo)
2. qBittorrent     → Download client torrent
3. NZBGet          → Download client Usenet
4. Sonarr          → TV (connette a Prowlarr + download client)
5. Radarr          → Film (connette a Prowlarr + download client)
6. Lidarr          → Musica (connette a Prowlarr + download client)
7. Bazarr          → Sottotitoli (connette a Sonarr + Radarr)
8. Recyclarr       → Quality profiles (connette a Sonarr + Radarr)
9. Pi-hole         → DNS (indipendente)
10. Home Assistant → Domotica (indipendente)
```

> **Nota**: Prowlarr si configura per primo, poi i download client, poi le app *arr che li collegano tutti insieme.

### Primo Accesso qBittorrent

qBittorrent genera una password casuale al primo avvio. Per recuperarla:

```bash
# Recuperare password temporanea dai log
docker logs qbittorrent 2>&1 | grep -i password
# Output: "The WebUI administrator password was not set. A temporary password is provided: XXXXXX"
```

- Username: `admin`
- Password: dal log sopra
- Dopo il login: Options → WebUI → cambiare password

### Configurazioni Critiche

Per ogni servizio *arr, verificare:

- [ ] **Hardlinks abilitati**: Settings → Media Management → Use Hardlinks instead of Copy: **Yes**
- [ ] **Root folder corretto**: `/data/media/{movies,tv,music}`
- [ ] **Download client path**: `/data/torrents` o `/data/usenet/complete`

### Raccolta API Key

Annotare le API key (per password manager):

| Servizio | Percorso API Key |
|----------|------------------|
| Sonarr | Settings → General → API Key |
| Radarr | Settings → General → API Key |
| Lidarr | Settings → General → API Key |
| Prowlarr | Settings → General → API Key |
| Bazarr | Settings → General → API Key |

### Verifica Hardlinking

```bash
# Test critico - eseguire dopo prima importazione
ls -li /share/data/torrents/movies/file.mkv /share/data/media/movies/Film/file.mkv

# Stesso numero inode = hardlink funzionante
```

---

## Fase 6: Setup Proxmox/Plex

**Riferimento:** [`docs/setup/PROXMOX_SETUP.md`](docs/setup/PROXMOX_SETUP.md)

### 6.1 Installazione Proxmox

1. [ ] Scaricare ISO Proxmox VE
2. [ ] Creare USB avviabile
3. [ ] Installare su Mini PC Lenovo
4. [ ] Configurare IP: `192.168.3.20`

### 6.2 Setup Plex

1. [ ] Creare VM o LXC container per Plex
2. [ ] Montare NFS share dal NAS
3. [ ] Configurare librerie Plex

### 6.3 Configurazione Tailscale

1. [ ] Installare Tailscale su Proxmox
2. [ ] Configurare come exit node (opzionale)
3. [ ] Abilitare accesso remoto

### Verifica Fase 6

- [ ] Proxmox accessibile: `https://192.168.3.20:8006`
- [ ] Plex accessibile: `http://192.168.3.21:32400/web` (container LXC)
- [ ] Tailscale connesso

---

## Fase 7: Configurazione Backup

**Riferimento:** [`docs/operations/runbook-backup-restore.md`](docs/operations/runbook-backup-restore.md)

### 7.1 Duplicati (Container)

1. [ ] Accedere a `http://192.168.3.10:8200`
2. [ ] Configurare backup job:
   - Sorgente: `/source/config`
   - Destinazione locale: `/backups`
   - Destinazione cloud: Google Drive o Dropbox (opzionale)
3. [ ] Impostare schedule: giornaliero
4. [ ] Retention: 7 daily, 4 weekly, 3 monthly

### 7.2 Backup QTS

1. [ ] Control Panel → System → Backup/Restore
2. [ ] Backup System Settings → Salva file .bin

### 7.3 Backup VM Proxmox

1. [ ] Proxmox → Datacenter → Storage → Add NFS
2. [ ] Configurare backup schedule settimanale

### 7.4 Test Restore

- [ ] Testare restore di un file config
- [ ] Documentare procedura

---

## Fase 8: Verifica Finale

### Checklist Funzionalità

**Rete:**
- [ ] Tutte le VLAN raggiungibili
- [ ] Internet funzionante da ogni VLAN
- [ ] Regole firewall attive (testare blocchi)

**NAS/Docker:**
- [ ] Tutti i container healthy: `make health`
- [ ] WebUI accessibili: `make urls`
- [ ] Logs senza errori critici: `make logs`

**Media Stack:**
- [ ] Prowlarr: indexer configurati e funzionanti
- [ ] Sonarr/Radarr/Lidarr: possono cercare contenuti
- [ ] Download client: test download completato
- [ ] Hardlinking: verificato con `ls -li`
- [ ] Bazarr: sottotitoli scaricati automaticamente

**Plex:**
- [ ] Librerie sincronizzate
- [ ] Streaming funzionante (locale e remoto via Tailscale)

**Backup:**
- [ ] Duplicati job schedulato
- [ ] Test restore completato
- [ ] Backup offsite configurato

---

## Manutenzione Ordinaria

### Giornaliera (automatica)
- Watchtower aggiorna container
- Duplicati esegue backup
- Cleanuparr pulisce file obsoleti

### Settimanale
```bash
make status      # Verificare stato container
make health      # Health check
```

### Mensile
```bash
make pull        # Aggiornare immagini manualmente se necessario
make backup      # Backup manuale aggiuntivo
```

---

## Risoluzione Problemi Comuni

| Problema | Soluzione Rapida |
|----------|------------------|
| Container non parte | `docker compose logs <servizio>` |
| Permessi negati | `sudo chown -R $PUID:$PGID ./config` (usa valori da .env) |
| Hardlink fallisce | Verificare stesso filesystem |
| Servizio non raggiungibile | Verificare regole firewall |
| Pi-hole non risolve | Verificare porta 53 libera (`ss -tulnp \| grep :53`) |
| qBittorrent login fallisce | Recuperare password: `docker logs qbittorrent 2>&1 \| grep password` |
| PUID/PGID errati | Verificare con `id dockeruser` e aggiornare docker/.env |

Per problemi specifici, consultare la sezione Troubleshooting in [`docs/setup/NAS_SETUP.md`](docs/setup/NAS_SETUP.md).

---

## Documenti di Riferimento

| Documento | Contenuto |
|-----------|-----------|
| [`CLAUDE.md`](CLAUDE.md) | Guida completa progetto e linee guida sviluppo |
| [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md) | Layout hardware e piano IP |
| [`docs/network/firewall-config.md`](docs/network/firewall-config.md) | Regole firewall complete |
| [`docs/setup/NAS_SETUP.md`](docs/setup/NAS_SETUP.md) | Checklist dettagliata QNAP |
| [`docs/operations/runbook-backup-restore.md`](docs/operations/runbook-backup-restore.md) | Procedure backup e restore |
| [`docs/setup/NETWORK_SETUP.md`](docs/setup/NETWORK_SETUP.md) | Setup rete UniFi |
| [`docs/setup/PROXMOX_SETUP.md`](docs/setup/PROXMOX_SETUP.md) | Setup Proxmox e Plex |
| [`docs/setup/REVERSE_PROXY_SETUP.md`](docs/setup/REVERSE_PROXY_SETUP.md) | Traefik, Nginx Proxy Manager, DNS Tailscale |
