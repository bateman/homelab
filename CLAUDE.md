# CLAUDE.md - Guida Repository Homelab

## Panoramica Progetto

Questo repository contiene la configurazione infrastructure-as-code completa per un homelab basato su NAS QNAP TS-435XeU e Mini PC Lenovo con Proxmox. Il setup segue le best practice di Trash Guides per la gestione media con supporto hardlinking.

## Architettura

### Hardware
- **NAS**: [QNAP TS-435XeU](https://www.qnap.com/it-it/product/ts-435xeu) (192.168.3.10) - Esegue lo stack Docker media
- **Mini PC**: [Lenovo ThinkCentre neo 50q Gen 4](https://www.lenovo.com/it/it/p/desktops/thinkcentre/thinkcentre-neo-series/thinkcentre-neo-50q-gen-4-tiny-(intel)/12lmcto1wwit1) (192.168.3.20) - Esegue Proxmox con Plex
- **Router**: [Ubiquiti UniFi Dream Machine SE](https://store.ui.com/eu/en/category/cloud-gateways-large-scale/products/udm-se) (192.168.2.1) - Router/Firewall
- **Switch**: [Ubiquiti USW-Pro-Max-16-PoE](https://eu.store.ui.com/eu/en/products/usw-pro-max-16-poe) (192.168.2.10) - Switch PoE gestito
- **Access Point**: [Ubiquiti U6-Pro](https://store.ui.com/eu/en/category/wifi-flagship-high-capacity/products/u6-pro) - Wi-Fi 6
- **UPS**: [Eaton 5P 650i Rack G2](https://www.eaton.com/it/it-it/skuPage.5P650IRG2.html) - Gruppo di continuità
- **Rack**: 8U con ottimizzazione raffreddamento passivo
- **PC Desktop**: (192.168.3.40) - Workstation
- **Stampante**: (192.168.3.30) - Stampante di rete

### Topologia di Rete
- **VLAN 2** (192.168.2.0/24): Management - UDM-SE, Switch, AP
- **VLAN 3** (192.168.3.0/24): Servers - NAS, Proxmox, PC Desktop, Stampante
- **VLAN 4** (192.168.4.0/24): Media - Smart TV, telefoni, tablet
- **VLAN 5** (192.168.5.0/24): Guest - Accesso internet isolato
- **VLAN 6** (192.168.6.0/24): IoT - Alexa, dispositivi smart
- **Legacy** (192.168.1.0/24): Iliad Box + dispositivi Vimar (non gestita da UDM-SE)

## Struttura Repository

```
homelab/
├── Makefile                        # Comandi gestione stack
├── docker/                         # Stack Docker
│   ├── compose.yml                 # Stack infrastruttura (Pi-hole, HA, Portainer, Duplicati)
│   ├── compose.media.yml           # Stack media (*arr, download clients, monitoring)
│   ├── .env.example                # Template config non sensibile
│   ├── .env.secrets.example        # Template credenziali (gitignored dopo copia)
│   └── recyclarr.yml               # Esempio config profili qualita' Trash Guides
├── scripts/                        # Script operativi
│   ├── setup-folders.sh            # Creazione struttura cartelle iniziale
│   ├── generate-certs.sh           # Generazione certificati HTTPS self-signed
│   ├── backup-qts-config.sh        # Backup automatico configurazione QNAP QTS
│   └── verify-backup.sh            # Verifica integrita' backup Docker
└── docs/                           # Documentazione
    ├── setup/                      # Guide setup iniziale
    │   ├── NETWORK_SETUP.md        # Setup rete UniFi e VLAN
    │   ├── NAS_SETUP.md            # Setup NAS QNAP e Docker
    │   ├── NOTIFICATIONS_SETUP.md  # Setup notifiche Uptime Kuma via HA
    │   ├── PROXMOX_SETUP.md        # Setup Proxmox e Plex
    │   └── REVERSE_PROXY_SETUP.md  # Traefik, NPM, Pi-hole DNS Tailscale
    ├── network/                    # Config rete
    │   ├── firewall-config.md      # Regole firewall UDM-SE e config VLAN
    │   └── rack-homelab-config.md  # Layout rack hardware e piano IP
    └── operations/                 # Runbook operativi
        └── runbook-backup-restore.md   # Procedure backup/restore
```

## Servizi Docker (su NAS 192.168.3.10)

| Servizio | Porta | Descrizione |
|----------|-------|-------------|
| Sonarr | 8989 | Gestione serie TV |
| Radarr | 7878 | Gestione film |
| Lidarr | 8686 | Gestione musica |
| Prowlarr | 9696 | Gestione indexer |
| Bazarr | 6767 | Gestione sottotitoli |
| qBittorrent | 8080 | Client torrent |
| NZBGet | 6789 | Client Usenet |
| Huntarr | 9705 | Monitoring *arr |
| Cleanuparr | 11011 | Pulizia automatica |
| Pi-hole | 8081 | DNS ad-blocking |
| Home Assistant | 8123 | Automazione domotica |
| Portainer | 9443 | Gestione Docker (accesso socket diretto) |
| FlareSolverr | 8191 | Bypass Cloudflare |
| Recyclarr | - | Sync profili Trash Guides |
| Watchtower | 8383 | Auto-update container (via socket proxy) |
| Duplicati | 8200 | Backup incrementale con UI |
| Uptime Kuma | 3001 | Monitoring e alerting (vedi `docs/setup/NOTIFICATIONS_SETUP.md`) |
| Traefik | 80/443 | Reverse proxy HTTPS (via socket proxy) |
| Socket Proxy | - | Proxy sicuro Docker socket (interno) |

## Servizi Proxmox (su Mini PC 192.168.3.20)

| Servizio | Porta | Descrizione |
|----------|-------|-------------|
| Proxmox VE | 8006 | WebUI hypervisor |
| Plex Media Server | 32400 | Streaming media (LXC container 100, IP 192.168.3.21) |
| Tailscale | - | VPN mesh, subnet router per VLAN 3 e 4 |

## Comandi Comuni

```bash
# Gestione stack (via Makefile)
make setup      # Crea struttura cartelle (eseguire una volta)
./scripts/generate-certs.sh  # Genera certificati HTTPS (eseguire una volta)
make validate   # Verifica configurazione compose
make up         # Avvia tutti i container
make down       # Ferma tutti i container
make restart    # Restart completo
make pull       # Aggiorna immagini Docker
make logs       # Segui tutti i logs
make status     # Stato container e utilizzo risorse
make health     # Health check tutti i servizi
make backup     # Trigger backup Duplicati on-demand
make backup-qts # Backup configurazione QNAP QTS
make verify-backup  # Verifica integrita' backup (estrazione + SQLite)
make urls       # Mostra tutti gli URL WebUI
make update     # Aggiorna immagini e restart (pull + restart)
make clean      # Rimuove container, immagini e volumi orfani

# Recyclarr (sync profili qualita')
make recyclarr-sync     # Sync manuale profili Trash Guides
make recyclarr-config   # Genera template configurazione

# Specifici per servizio
make logs-sonarr    # Logs per servizio specifico
make shell-radarr   # Shell nel container
```

## Configurazioni Chiave

### Variabili Ambiente
- `PUID=1000` / `PGID=100` - ID utente/gruppo container
- `TZ=Europe/Rome` - Fuso orario
- `UMASK=002` - Permessi file

### Struttura Cartelle NAS
```
/share/
├── data/                           # Dati media (conforme Trash Guides)
│   ├── torrents/
│   │   ├── movies/
│   │   ├── tv/
│   │   └── music/
│   ├── usenet/
│   │   ├── incomplete/
│   │   └── complete/{movies,tv,music}/
│   └── media/
│       ├── movies/
│       ├── tv/
│       └── music/
├── container/                      # Configurazioni container Docker
│   └── <servizio>/config/
└── backup/                         # Destinazione backup locali
```

**Critico**: Tutti i path sotto `/share/data` devono essere sullo stesso filesystem perche' l'hardlinking funzioni.

### Verifica Hardlinking
```bash
ls -li /share/data/torrents/movies/file.mkv /share/data/media/movies/Film/file.mkv
# Stesso numero inode = hardlink funzionante
```

## Linee Guida Sviluppo

### Quando modifichi i file compose
1. `docker/compose.yml` contiene servizi infrastruttura (Pi-hole, Home Assistant, Portainer, Watchtower)
2. `docker/compose.media.yml` contiene lo stack media (*arr, download clients, monitoring)
3. Sonarr/Radarr/Lidarr e download clients (qBittorrent, NZBGet) montano `/share/data:/data` per supporto hardlink; Bazarr monta solo `/share/data/media:/data/media`
4. Usa anchor YAML (`&common-env`, `&common-logging`, `&common-healthcheck`) per config condivise
5. Mantieni relazioni `depends_on` tra servizi
6. Conserva label Watchtower per auto-update
7. Ogni servizio deve avere: healthcheck, logging, deploy.resources

### Quando modifichi regole firewall
1. Le regole sono processate in ordine - la posizione conta
2. Includi sempre "Allow Established/Related" come prima regola
3. Usa gruppi IP/Porte per manutenibilita'
4. Le regole di blocco devono venire dopo le regole allow specifiche
5. Termina con catch-all "Block All Inter-VLAN"

### Quando aggiungi nuovi servizi
1. Aggiungi a `docker/compose.yml` (infrastruttura) o `docker/compose.media.yml` (media stack)
2. Includi: healthcheck, logging, deploy.resources, labels watchtower
3. Aggiorna `scripts/setup-folders.sh` se servono nuove directory config
4. Aggiungi endpoint health check al target health del `Makefile`
5. Aggiorna target urls del `Makefile` con nuova WebUI
6. Documenta nella tabella servizi sopra e in `docs/network/rack-homelab-config.md`
7. Aggiungi regole firewall se serve accesso inter-VLAN

## Gestione Secrets

Le credenziali sono separate dalla configurazione:
- **`docker/.env`** - Configurazione non sensibile (PUID, PGID, TZ, porte)
- **`docker/.env.secrets`** - Password e API key (gitignored)

### Posizione API Key

Le API key sono salvate nella config di ogni servizio e vanno recuperate da:
- Sonarr/Radarr/Lidarr/Prowlarr: Settings -> General -> API Key
- qBittorrent: Settings -> WebUI -> Authentication
- NZBGet: Settings -> Security -> ControlUsername/ControlPassword

Le password di sistema vanno in `docker/.env.secrets`:
- `PIHOLE_PASSWORD` - Password Pi-hole
- `TRAEFIK_DASHBOARD_AUTH` - Basic auth Traefik (hash bcrypt)
- `WATCHTOWER_API_TOKEN` - Token API Watchtower

## Strategia Backup

### Duplicati (consigliato)
Container dedicato con WebUI per backup automatizzati:
- **URL**: https://duplicati.home.local (o http://192.168.3.10:8200)
- **Sorgente**: `/source/config` (tutte le config dei servizi)
- **Destinazione locale**: `/backups` -> `/share/backup`
- **Destinazione offsite**: Google Drive o Dropbox (configurare via WebUI)
- **Retention consigliata**: 7 daily, 4 weekly, 3 monthly

### Backup on-demand via Makefile
```bash
make backup  # Avvia backup Duplicati (richiede job configurato in WebUI)
```

### Altri backup
- **Compose files**: Versionati in Git (questo repository)
- **Config QTS**: Settimanale via Control Panel -> Backup/Restore
- **VM Proxmox**: Settimanale su NAS via mount NFS

Vedi `docs/operations/runbook-backup-restore.md` per procedure dettagliate.

## Troubleshooting

### Container non parte
```bash
docker compose logs <service>
# Verifica permessi
chown -R 1000:100 ./config/<service>
```

### Hardlink non funzionano
- Verifica che sorgente e destinazione siano sullo stesso filesystem
- Controlla `Use Hardlinks instead of Copy: Yes` nelle impostazioni *arr
- Testa manualmente con comando `ln`

### Problemi connettivita' rete
- Verifica assegnazione VLAN sulla porta switch
- Controlla regole firewall in UDM-SE
- Testa con `ping` dalla VLAN rilevante

### Servizio non accessibile da altra VLAN
- Controlla regole firewall in `docs/network/firewall-config.md`
- Verifica che mDNS reflection sia abilitato se necessario
- Verifica che il gruppo porte includa la porta del servizio

## Sicurezza Docker Socket

Il Docker socket (`/var/run/docker.sock`) e' un vettore di attacco critico: un container compromesso con accesso al socket puo' ottenere controllo completo dell'host.

**Architettura implementata**:
- **Socket Proxy** (tecnativa/docker-socket-proxy): espone solo le API Docker necessarie su rete interna
- **Traefik**: usa socket proxy (solo lettura container/network)
- **Watchtower**: usa socket proxy (lettura + restart container)
- **Portainer**: accesso diretto al socket (richiede API complete)

**Perche' Portainer non usa il proxy**: Portainer necessita di EXEC, VOLUMES, BUILD e altre API per funzionalita' complete (console, gestione volumi). Il proxy blocca queste API per sicurezza.

**Mitigazione rischio Portainer**:
- Accessibile solo via HTTPS con autenticazione
- Limitare accesso a utenti fidati
- In ambienti ad alta sicurezza: rimuovere Portainer e usare solo CLI

## Note Importanti

- **HTTPS abilitato**: Tutti i servizi sono accessibili via HTTPS (certificato self-signed). HTTP viene reindirizzato automaticamente a HTTPS
- **DNS con fallback**: Pi-hole e' DNS primario, Cloudflare (1.1.1.1) come fallback. Se Pi-hole e' down, `*.home.local` non risolve ma internet funziona. Vedi `docs/network/firewall-config.md` per configurazione DHCP.
- Home Assistant usa `network_mode: host` per discovery dispositivi
- Iliad Box (192.168.1.254) resta come router upstream (double NAT)
- Tailscale su Mini PC fornisce accesso remoto senza port forwarding
- Container Station 3 richiesto su QNAP per Docker Compose v2
