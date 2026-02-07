# Homelab Infrastructure

> [!TIP]
> **First installation**: Go directly to [`START_HERE.md`](START_HERE.md) for the complete step-by-step guide.

Infrastructure-as-code configuration for a homelab based on QNAP NAS and Proxmox with a complete media stack.

**What this project does:**
- Automated management of TV series, movies, and music (Sonarr, Radarr, Lidarr)
- Downloads from torrent and Usenet with hardlinking support
- Network-wide DNS ad-blocking (Pi-hole)
- Local and remote media streaming (Plex)
- Automated local and cloud backups
- Network segmentation with VLANs for security

## Hardware

| Device | Role | IP |
|--------|------|-----|
| [QNAP TS-435XeU](https://www.qnap.com/en/product/ts-435xeu) | NAS + Docker media stack | 192.168.3.10 |
| [Lenovo ThinkCentre neo 50q Gen 4](https://www.lenovo.com/us/en/p/desktops/thinkcentre/thinkcentre-neo-series/thinkcentre-neo-50q-gen-4-tiny-(intel)/12lmcto1wwit1) | Proxmox + Plex | 192.168.3.20 |
| [Ubiquiti UniFi Dream Machine SE](https://store.ui.com/us/en/category/cloud-gateways-large-scale/products/udm-se) | Router/Firewall | 192.168.2.1 |
| [Ubiquiti USW-Pro-Max-16-PoE](https://store.ui.com/us/en/products/usw-pro-max-16-poe) | PoE Switch | 192.168.2.10 |
| [Ubiquiti U6-Pro](https://store.ui.com/us/en/category/wifi-flagship-high-capacity/products/u6-pro) | Wi-Fi 6 Access Point | DHCP |
| [Eaton 5P 650i Rack G2](https://www.eaton.com/content/dam/eaton/products/backup-power-ups-surge-it-power-distribution/backup-power-ups/5P-Gen2-UPS---EMEA/eaton-5p-gen2-ups-emea-resources/eaton-5pgen2-rack-user-manual-en-us.pdf) | UPS / Uninterruptible Power Supply | - |

## Docker Stack (NAS)

- **[Sonarr](https://sonarr.tv/)** (8989) - TV Series
- **[Radarr](https://radarr.video/)** (7878) - Movies
- **[Lidarr](https://lidarr.audio/)** (8686) - Music
- **[Prowlarr](https://prowlarr.com/)** (9696) - Indexer
- **[Bazarr](https://www.bazarr.media/)** (6767) - Subtitles
- **[Gluetun](https://github.com/qdm12/gluetun)** - VPN container with kill switch
- **[qBittorrent](https://www.qbittorrent.org/)** (8080) - Torrent (via Gluetun)
- **[NZBGet](https://nzbget.com/)** (6789) - Usenet (via Gluetun)
- **[Recyclarr](https://recyclarr.dev/)** - Trash Guides profile sync
- **[Huntarr](https://github.com/plexguide/Huntarr.io)** (9705) - *arr Monitoring
- **[Cleanuparr](https://github.com/Cleanuparr/Cleanuparr)** (11011) - Automatic cleanup
- **[FlareSolverr](https://github.com/FlareSolverr/FlareSolverr)** (8191) - Cloudflare bypass
- **[Pi-hole](https://pi-hole.net/)** (8081) - DNS/Ad-blocking
- **[Home Assistant](https://www.home-assistant.io/)** (8123) - Home automation
- **[Portainer](https://www.portainer.io/)** (9443) - Docker management
- **[Duplicati](https://www.duplicati.com/)** (8200) - Automated backups
- **[Uptime Kuma](https://github.com/louislam/uptime-kuma)** (3001) - Monitoring and alerting
- **[Watchtower](https://containrrr.dev/watchtower/)** (8383) - Container auto-update
- **[Traefik](https://traefik.io/traefik/)** (80/443) - Reverse proxy

## Proxmox Stack (Mini PC)

The Mini PC runs Proxmox VE as hypervisor with LXC containers:

- **[Plex Media Server](https://www.plex.tv/)** (32400) - Media streaming with Intel Quick Sync hardware transcoding
- **[Tailscale](https://tailscale.com/)** - Mesh VPN remote access (subnet router for 192.168.3.0/24 and 192.168.4.0/24)

Proxmox WebUI: `https://192.168.3.20:8006`

Setup details in [`docs/setup/proxmox-setup.md`](docs/setup/proxmox-setup.md).

## Folder Structure

Configured for hardlinking support according to [Trash Guides](https://trash-guides.info/):

```
/share/data/
├── torrents/{movies,tv,music}/
├── usenet/
│   ├── incomplete/
│   └── complete/{movies,tv,music}/
└── media/{movies,tv,music}/
```

## Network

The network is segmented into VLANs to isolate traffic and improve security:

| VLAN | Subnet | Use |
|------|--------|-----|
| 2 | 192.168.2.0/24 | Management (switch, router, AP) |
| 3 | 192.168.3.0/24 | Servers (NAS, Proxmox) |
| 4 | 192.168.4.0/24 | Media (TV, streaming devices) |
| 5 | 192.168.5.0/24 | Guest (isolated internet access) |
| 6 | 192.168.6.0/24 | IoT (smart devices) |

Details in [`docs/setup/network-setup.md`](docs/setup/network-setup.md).

## Documentation

### Installation Guides
- [`START_HERE.md`](START_HERE.md) - **Complete installation guide (start here)**
- [`docs/setup/rack-mounting-guide.md`](docs/setup/rack-mounting-guide.md) - Rack mounting order and cable routing
- [`docs/setup/network-setup.md`](docs/setup/network-setup.md) - UniFi network and VLAN setup
- [`docs/setup/nas-setup.md`](docs/setup/nas-setup.md) - QNAP NAS and Docker setup
- [`docs/setup/proxmox-setup.md`](docs/setup/proxmox-setup.md) - Proxmox and Plex setup
- [`docs/setup/vpn-setup.md`](docs/setup/vpn-setup.md) - VPN protection for download clients (Gluetun)
- [`docs/setup/reverse-proxy-setup.md`](docs/setup/reverse-proxy-setup.md) - Traefik, HTTPS certificates, Pi-hole DNS
- [`docs/setup/notifications-setup.md`](docs/setup/notifications-setup.md) - Uptime Kuma notifications via Home Assistant

### Reference
- [`CLAUDE.md`](CLAUDE.md) - Project guide and development guidelines
- [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md) - Hardware layout and IP plan
- [`docs/network/firewall-config.md`](docs/network/firewall-config.md) - UDM-SE firewall rules
- [`docs/operations/runbook-backup-restore.md`](docs/operations/runbook-backup-restore.md) - Backup/restore procedures
- [`docs/operations/energy-saving-strategies.md`](docs/operations/energy-saving-strategies.md) - Power management and energy optimization

## Useful Commands

All commands should be run in the `/share/container/mediastack` directory on the NAS.

### Setup and Validation

| Command | Description |
|---------|-------------|
| `make setup` | Create folder structure and `.env` file (run once during installation) |
| `make validate` | Verify compose file syntax before startup |

### Container Management

| Command | Description |
|---------|-------------|
| `make up` | Start all containers (validates config automatically) |
| `make down` | Stop all containers |
| `make restart` | Full restart (down + up) |
| `make pull` | Download updated Docker image versions |
| `make update` | Update and restart in one command (pull + restart) |

### Monitoring

| Command | Description |
|---------|-------------|
| `make status` | Show container status, CPU/RAM usage, and disk space |
| `make logs` | Follow all container logs in real-time |
| `make logs-<service>` | Single service log (e.g., `make logs-sonarr`) |
| `make health` | HTTP health check of all services |
| `make urls` | List access URLs for all services (Sonarr, Radarr, Pi-hole, etc.) |

### Backup

| Command | Description |
|---------|-------------|
| `make backup` | Start Duplicati backup on-demand |
| Duplicati WebUI | http://192.168.3.10:8200 - configuration and scheduled backups |

### Utilities

| Command | Description |
|---------|-------------|
| `make shell-<service>` | Open shell in container (e.g., `make shell-radarr`) |
| `make clean` | Remove orphan Docker resources (asks for confirmation) |
| `make recyclarr-sync` | Manual Trash Guides quality profile sync |
| `make recyclarr-config` | Generate Recyclarr configuration template |
| `make help` | Show all available commands |

## Requirements

Before starting, make sure you have:

- **QNAP NAS** with Container Station 3 installed (provides Docker)
- **Docker Compose v2** (included in Container Station 3)
- **UniFi Network** (UDM-SE or similar) for VLAN management
- **Subscriptions** to indexer/Usenet for the media stack (optional but recommended)

For the complete hardware list and details, see [`docs/network/rack-homelab-config.md`](docs/network/rack-homelab-config.md).
