# Homelab Infrastructure

> **Prima installazione?** Vai direttamente a [`START_HERE.md`](START_HERE.md) per la guida passo-passo completa.

Configurazione infrastructure-as-code per homelab basato su NAS QNAP e Proxmox con stack media completo.

**Cosa fa questo progetto:**
- Gestione automatizzata di serie TV, film e musica (Sonarr, Radarr, Lidarr)
- Download da torrent e Usenet con supporto hardlinking
- DNS ad-blocking per tutta la rete (Pi-hole)
- Streaming media locale e remoto (Plex)
- Backup automatizzati locali e cloud
- Segmentazione rete con VLAN per sicurezza

## Hardware

| Dispositivo | Ruolo | IP |
|-------------|-------|-----|
| [QNAP TS-435XeU](https://www.qnap.com/it-it/product/ts-435xeu) | NAS + Docker stack media | 192.168.3.10 |
| [Lenovo ThinkCentre neo 50q Gen 4](https://www.lenovo.com/it/it/p/desktops/thinkcentre/thinkcentre-neo-series/thinkcentre-neo-50q-gen-4-tiny-(intel)/12lmcto1wwit1) | Proxmox + Plex | 192.168.3.20 |
| [Ubiquiti UniFi Dream Machine SE](https://store.ui.com/eu/en/category/cloud-gateways-large-scale/products/udm-se) | Router/Firewall | 192.168.2.1 |
| [Ubiquiti USW-Pro-Max-16-PoE](https://eu.store.ui.com/eu/en/products/usw-pro-max-16-poe) | Switch PoE | 192.168.2.10 |
| [Ubiquiti U6-Pro](https://store.ui.com/eu/en/category/wifi-flagship-high-capacity/products/u6-pro) | Access Point Wi-Fi 6 | DHCP |
| [Eaton 5P 650i Rack G2](https://www.eaton.com/it/it-it/skuPage.5P650IRG2.html) | UPS / Gruppo di continuità | - |

## Stack Docker (NAS)

- **[Sonarr](https://sonarr.tv/)** (8989) - Serie TV
- **[Radarr](https://radarr.video/)** (7878) - Film
- **[Lidarr](https://lidarr.audio/)** (8686) - Musica
- **[Prowlarr](https://prowlarr.com/)** (9696) - Indexer
- **[Bazarr](https://www.bazarr.media/)** (6767) - Sottotitoli
- **[qBittorrent](https://www.qbittorrent.org/)** (8080) - Torrent
- **[NZBGet](https://nzbget.com/)** (6789) - Usenet
- **[Recyclarr](https://recyclarr.dev/)** - Sync profili Trash Guides
- **[Huntarr](https://github.com/plexguide/Huntarr.io)** (9705) - Monitoring *arr
- **[Cleanuparr](https://github.com/Cleanuparr/Cleanuparr)** (11011) - Pulizia automatica
- **[FlareSolverr](https://github.com/FlareSolverr/FlareSolverr)** (8191) - Bypass Cloudflare
- **[Pi-hole](https://pi-hole.net/)** (8081) - DNS/Ad-blocking
- **[Home Assistant](https://www.home-assistant.io/)** (8123) - Domotica
- **[Portainer](https://www.portainer.io/)** (9443) - Gestione Docker
- **[Duplicati](https://www.duplicati.com/)** (8200) - Backup automatizzati
- **[Uptime Kuma](https://github.com/louislam/uptime-kuma)** (3001) - Monitoring e alerting
- **[Watchtower](https://containrrr.dev/watchtower/)** (8383) - Auto-update container
- **[Traefik](https://traefik.io/traefik/)** (80/443) - Reverse proxy

## Struttura Cartelle

Configurato per supporto hardlinking secondo [Trash Guides](https://trash-guides.info/):

```
/share/data/
├── torrents/{movies,tv,music}/
├── usenet/
│   ├── incomplete/
│   └── complete/{movies,tv,music}/
└── media/{movies,tv,music}/
```

## Rete

La rete è segmentata in VLAN per isolare il traffico e migliorare la sicurezza:

| VLAN | Subnet | Uso |
|------|--------|-----|
| 2 | 192.168.2.0/24 | Management (switch, router, AP) |
| 3 | 192.168.3.0/24 | Servers (NAS, Proxmox) |
| 4 | 192.168.4.0/24 | Media (TV, dispositivi streaming) |
| 5 | 192.168.5.0/24 | Guest (accesso internet isolato) |
| 6 | 192.168.6.0/24 | IoT (dispositivi smart) |

Dettagli in [`docs/setup/NETWORK_SETUP.md`](docs/setup/NETWORK_SETUP.md).

## Documentazione

### Guide Installazione
- [`START_HERE.md`](START_HERE.md) - **Guida installazione completa (inizia qui)**
- [`docs/setup/NETWORK_SETUP.md`](docs/setup/NETWORK_SETUP.md) - Setup rete UniFi e VLAN
- [`docs/setup/NAS_SETUP.md`](docs/setup/NAS_SETUP.md) - Setup NAS QNAP e Docker
- [`docs/setup/PROXMOX_SETUP.md`](docs/setup/PROXMOX_SETUP.md) - Setup Proxmox e Plex

### Riferimenti
- [`CLAUDE.md`](CLAUDE.md) - Guida completa progetto e sviluppo
- [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md) - Layout hardware e piano IP
- [`docs/network/firewall-config.md`](docs/network/firewall-config.md) - Regole firewall UDM-SE
- [`docs/operations/runbook-backup-restore.md`](docs/operations/runbook-backup-restore.md) - Procedure backup/restore

## Comandi Utili

Tutti i comandi vanno eseguiti nella directory `/share/container/mediastack` sul NAS.

### Setup e Validazione

| Comando | Descrizione |
|---------|-------------|
| `make setup` | Crea struttura cartelle e file `.env` (eseguire una sola volta all'installazione) |
| `make validate` | Verifica sintassi dei file compose prima dell'avvio |

### Gestione Container

| Comando | Descrizione |
|---------|-------------|
| `make up` | Avvia tutti i container (valida config automaticamente) |
| `make down` | Ferma tutti i container |
| `make restart` | Restart completo (down + up) |
| `make pull` | Scarica versioni aggiornate delle immagini Docker |
| `make update` | Aggiorna e riavvia in un comando (pull + restart) |

### Monitoraggio

| Comando | Descrizione |
|---------|-------------|
| `make status` | Mostra stato container, uso risorse CPU/RAM e spazio disco |
| `make logs` | Segui i log di tutti i container in tempo reale |
| `make logs-<servizio>` | Log di un singolo servizio (es: `make logs-sonarr`) |
| `make health` | Health check HTTP di tutti i servizi |
| `make urls` | Elenca URL di accesso a tutti i servizi (Sonarr, Radarr, Pi-hole, ecc.) |

### Backup

| Comando | Descrizione |
|---------|-------------|
| `make backup` | Avvia backup Duplicati on-demand |
| Duplicati WebUI | http://192.168.3.10:8200 - configurazione e backup schedulati |

### Utility

| Comando | Descrizione |
|---------|-------------|
| `make shell-<servizio>` | Apre shell nel container (es: `make shell-radarr`) |
| `make clean` | Rimuove risorse Docker orfane (chiede conferma) |
| `make recyclarr-sync` | Sync manuale profili qualità Trash Guides |
| `make recyclarr-config` | Genera template configurazione Recyclarr |
| `make help` | Mostra tutti i comandi disponibili |

## Requisiti

Prima di iniziare, assicurati di avere:

- **NAS QNAP** con Container Station 3 installato (fornisce Docker)
- **Docker Compose v2** (incluso in Container Station 3)
- **Rete UniFi** (UDM-SE o simile) per gestione VLAN
- **Abbonamenti** indexer/Usenet per lo stack media (opzionale ma consigliato)

Per la lista completa dell'hardware e i dettagli, vedi [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md).
