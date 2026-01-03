# Homelab Infrastructure

Configurazione infrastructure-as-code per homelab basato su NAS QNAP e Proxmox con stack media completo.

> **Nuova installazione?** Inizia da [`START_HERE.md`](START_HERE.md) per una guida passo-passo completa.

## Hardware

| Dispositivo | Ruolo | IP |
|-------------|-------|-----|
| QNAP TS-435XeU | NAS + Docker stack media | 192.168.3.10 |
| Lenovo IdeaCentre | Proxmox + Plex | 192.168.3.20 |
| UniFi UDM-SE | Router/Firewall | 192.168.2.1 |
| USW-Enterprise-8-PoE | Switch | 192.168.2.2 |

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

## Quick Start

```bash
# Setup iniziale (una sola volta)
make setup

# Avvia stack
make up

# Stato servizi
make status

# URL WebUI
make urls
```

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
- [`docs/NETWORK_SETUP.md`](docs/NETWORK_SETUP.md) - Setup rete UniFi e VLAN
- [`docs/PROXMOX_SETUP.md`](docs/PROXMOX_SETUP.md) - Setup Proxmox e Plex
- [`checklist-qnap-deployment.md`](checklist-qnap-deployment.md) - Checklist deployment QNAP

### Riferimenti
- [`CLAUDE.md`](CLAUDE.md) - Guida completa progetto e sviluppo
- [`rack-homelab-config.md`](rack-homelab-config.md) - Layout hardware e piano IP
- [`firewall-config.md`](firewall-config.md) - Regole firewall UDM-SE
- [`runbook-backup-restore.md`](runbook-backup-restore.md) - Procedure backup/restore

## Comandi Utili

```bash
make logs           # Tutti i logs
make logs-sonarr    # Log specifico
make health         # Health check
make backup         # Backup config
make pull           # Aggiorna immagini
```

## Requisiti

- QNAP con Container Station 3
- Docker Compose v2
- Rete UniFi con VLAN configurate
