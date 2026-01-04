# Homelab Infrastructure

Configurazione infrastructure-as-code per homelab basato su NAS QNAP e Proxmox con stack media completo.

> **Nuova installazione?** Inizia da [`START_HERE.md`](START_HERE.md) per una guida passo-passo completa.

## Hardware

| Dispositivo | Ruolo | IP |
|-------------|-------|-----|
| QNAP TS-435XeU | NAS + Docker stack media | 192.168.3.10 |
| Lenovo IdeaCentre | Proxmox + Plex | 192.168.3.20 |
| Ubiquiti UniFi UDM-SE | Router/Firewall | 192.168.2.1 |
| Ubiquiti USW-Enterprise-8-PoE | Switch | 192.168.2.10 |

## Stack Docker (NAS)

- **Sonarr** (8989) - Serie TV
- **Radarr** (7878) - Film
- **Lidarr** (8686) - Musica
- **Prowlarr** (9696) - Indexer
- **Bazarr** (6767) - Sottotitoli
- **qBittorrent** (8080) - Torrent
- **NZBGet** (6789) - Usenet
- **Pi-hole** (8081) - DNS/Ad-blocking
- **Home Assistant** (8123) - Domotica
- **Portainer** (9443) - Gestione Docker
- **Duplicati** (8200) - Backup automatizzati

## Struttura Cartelle

Configurato per supporto hardlinking secondo [Trash Guides](https://trash-guides.info/):

```
/share/data/
├── torrents/{movies,tv,music}/
├── usenet/complete/{movies,tv,music}/
└── media/{movies,tv,music}/
```

## Rete

- **VLAN 2**: Management
- **VLAN 3**: Servers
- **VLAN 4**: Media (TV, dispositivi streaming)
- **VLAN 5**: Guest
- **VLAN 6**: IoT

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
| `make show-urls` | Elenca URL di accesso a tutti i servizi (Sonarr, Radarr, Pi-hole, ecc.) |

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

- QNAP con Container Station 3
- Docker Compose v2
- Rete UniFi con VLAN configurate
