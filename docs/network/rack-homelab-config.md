# 19" 8U Rack — Home Lab Configuration v3

> Configuration optimized for passive ventilation (rack open on sides and top)

## Rack Diagram

```
┏━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ U8  │ 🖥️  Lenovo Mini PC (Proxmox)                                            ┃
┃     │   • Main heat source -> dissipates upward (open top)                    ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U7  │ 🌀 Vented Panel #1                                                      ┃
┃     │   • Thermally isolates Mini PC from rest of rack                        ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U6  │ 🔀 PoE Switch (USW-Pro-Max-16-PoE)                                      ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U5  │ 🌐 UDM-SE                                                               ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U4  │ 🔌 Patch Panel                                                          ┃
┃     │   • Passive, no heat — acts as natural buffer                           ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U3  │ 🔌 Rack Power Strip                                                     ┃
┃     │   • Power for devices with standard plugs (e.g. Mini PC)                ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U2  │ 💾 QNAP NAS                                                             ┃
┃     │   • HDDs in coolest zone of rack                                        ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃     │ ████ INSULATION: EVA 5mm ██████████████████████████████████████████████ ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U1  │ ⚡ UPS                                                                  ┃
┃     │   • Weight at bottom, minimal heat generation                           ┃
┗━━━━━┷━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        ↑↑↑ HOT AIR EXITS FROM OPEN TOP ↑↑↑

   <-  cool air enters from sides  ->
```

---

## Component Details

### U8 — Lenovo ThinkCentre neo 50q Gen 4

| Spec | Value |
|------|-------|
| CPU | Intel Core i5-13420H (Quick Sync) |
| RAM | 16GB DDR5 |
| Storage | 1TB M.2 NVMe PCIe Gen4 (Opal 2.0) |
| Network | 1x 1GbE RJ45 (integrated) + 1x 2.5GbE USB-C (adapter) |
| Adapter | StarTech US2GC30 (USB-C 3.0 to 2.5GbE) |
| OS | Proxmox VE |
| Services | Plex, Docker, Tailscale |
| IP | 192.168.3.20 |

### U7 — Vented Panel #1

- Ubiquiti UACC-Rack-Panel-Vented-1U
- Thermal isolation between Mini PC and networking

### U6 — UniFi USW-Pro-Max-16-PoE

| Spec | Value |
|------|-------|
| GbE RJ45 Ports | 12x 1GbE (PoE+) |
| 2.5GbE RJ45 Ports | 4x 2.5GbE (PoE++) |
| SFP+ Ports | 2x 10GbE |
| SFP+ Port 1 | Uplink to UDM-SE |
| SFP+ Port 2 | QNAP NAS |
| PoE Budget | 180W |
| IP | 192.168.2.10 |

### U5 — UniFi Dream Machine SE (UDM-SE-EU)

| Spec | Value |
|------|-------|
| Function | Firewall / Router / UniFi Controller |
| WAN RJ45 | 1x 2.5GbE (fiber/ISP input) |
| WAN SFP+ | 1x 10GbE (unused - ISP doesn't support 10G) |
| LAN RJ45 | 8x 1GbE |
| LAN SFP+ | 1x 10GbE (uplink to switch) |
| IP | 192.168.2.1 |

### U4 — deleyCON Patch Panel

| Spec | Value |
|------|-------|
| Ports | 12x RJ45 Keystone |
| Category | CAT6A/CAT7 |
| Certification | 10 Gbit/s |

### U3 — 1U Rack Power Strip

| Spec | Value |
|------|-------|
| Outlets | 8x Schuko |
| Input | IEC C14 (connected to UPS) |
| Function | Power for devices with standard plugs |
| Connected Devices | Lenovo Mini PC |

### U2 — QNAP TS-435XeU

| Spec | Value |
|------|-------|
| CPU | Marvell Octeon TX2 CN9131 quad-core 2.2GHz |
| Bays | 4x 3.5" HDD (configurable RAID) |
| SFP+ | 2x 10GbE |
| SFP+ Port 1 | Uplink to Switch (VLAN trunk) |
| SFP+ Port 2 | Spare/backup |
| RJ45 | 2x 2.5GbE (management/backup) |
| Function | Media, Docker volumes, Backup |
| IP | 192.168.3.10 |

### Insulation — Neoprene 5mm

- Positioned between NAS (U2) and UPS (U1)
- Absorbs HDD vibrations
- Protects UPS from residual heat

### U1 — UPS Eaton 5P 650i Rack G2

| Spec | Value |
|------|-------|
| Power | 650VA / 420W |
| Technology | Line-interactive |
| Runtime | ~10-15 min (average load) |
| Management | USB -> Proxmox (NUT) |

---

## Non-Rack Components

### UniFi U6-Pro Access Point

| Spec | Value |
|------|-------|
| Model | U6-Pro |
| Location | Ceiling/wall mounted (not in rack) |
| Power | PoE from USW-Pro-Max-16-PoE |
| Switch Port | RJ45 port with PoE+ |
| IP | 192.168.2.20 |
| VLAN | Management (VLAN 2) |

> [!NOTE]
> The Access Point is powered via PoE from the switch and mounted centrally for optimal WiFi coverage. It broadcasts SSIDs for Media, Guest, and IoT VLANs.

---

## Thermal Logic

| Zone | Units | Strategy |
|------|-------|----------|
| Top (U8) | Mini PC | Maximum dissipation outward |
| U7 | Vented | Cuts heat rise from networking |
| Center (U4-U6) | Networking + Patch | Moderate heat, good side ventilation |
| U3 | Power Strip | Passive, no heat generated |
| Bottom (U1-U2) | NAS + UPS | Coolest zone, ideal for HDDs (< 40C) |

---

## Power Distribution

```
                    ┌─────────────────────────────────────────┐
                    │           UPS Eaton 5P 650i             │
                    │              (4x C13)                   │
                    └─────┬─────┬─────┬─────┬─────────────────┘
                          │     │     │     │
                    C13 #1│     │     │     │C13 #4
                          │     │     │     │
                          ▼     │     │     ▼
                      ┌───────┐ │     │ ┌────────────────┐
                      │  NAS  │ │     │ │ Power Strip 1U │
                      │ QNAP  │ │     │ │   (U3)         │
                      └───────┘ │     │ └───────┬────────┘
                                │     │         │
                          C13 #2│     │C13 #3   │ Schuko
                                │     │         │
                                ▼     ▼         ▼
                          ┌───────┐ ┌───────┐ ┌─────────┐
                          │UDM-SE │ │Switch │ │ Mini PC │
                          │       │ │  PoE  │ │ Lenovo  │
                          └───────┘ └───────┘ └─────────┘
```

| UPS Outlet | Device | Connector |
|-----------|--------|-----------|
| C13 #1 | QNAP NAS | IEC C14 |
| C13 #2 | UDM-SE | IEC C14 |
| C13 #3 | PoE Switch | IEC C14 |
| C13 #4 | Rack Power Strip (U3) | IEC C14 |

| Power Strip Outlet | Device | Notes |
|-------------------|--------|-------|
| Schuko #1 | Lenovo Mini PC | External power supply |
| Schuko #2-8 | Available | Future expansion |

> [!NOTE]
> All devices are protected by UPS battery. Devices with IEC connectors go directly to UPS, those with standard plugs go through the power strip.

---

## Network Backbone (SFP+ 10GbE)

```
UDM-SE (LAN SFP+) <--10G--> Switch (SFP+ Port 1)
                                   │
                             (SFP+ Port 2)
                                   │
                                   │ 10G
                                   ↓
                             NAS (SFP+ Port 1)
```

---

## Running Services

### QNAP NAS (192.168.3.10)

| Service | Port | Description |
|---------|------|-------------|
| Sonarr | 8989 | TV series management |
| Radarr | 7878 | Movie management |
| Lidarr | 8686 | Music management |
| Prowlarr | 9696 | Indexer management |
| Bazarr | 6767 | Automatic subtitles |
| qBittorrent | 8080 | Torrent client |
| NZBGet | 6789 | Usenet client |
| Recyclarr | - | Trash Guides profile sync |
| Huntarr | 9705 | *arr monitoring |
| Cleanuparr | 11011 | Automatic cleanup |
| FlareSolverr | 8191 | Cloudflare bypass |
| Pi-hole | 8081 | DNS ad-blocking |
| Home Assistant | 8123 | Home automation |
| Portainer | 9443 | Docker management |
| Duplicati | 8200 | Incremental backup |
| Uptime Kuma | 3001 | Monitoring and alerting |
| Watchtower | 8383 | Container auto-update |
| Traefik | 80/443 | Reverse proxy (dashboard via traefik.home.local) |

### Proxmox Mini PC (192.168.3.20)

| Service | Port | IP | Description |
|---------|------|-----|-------------|
| Plex | 32400 | 192.168.3.21 | Media server (LXC container) |
| Tailscale | — | 192.168.3.20 | Mesh VPN (host) |

---

## Network Cable Color Coding

| Color | Use | Example |
|-------|-----|---------|
| ⚫ Black | Rack internal | NAS, Mini PC |
| 🟢 Green | Room devices | Bedroom, Office, Living Room |
| ⚪ White | Management / Uplink | UDM-SE, Switch, Access Point |

> [!TIP]
> Every cable must have labels on both ends with: color + number + destination (e.g. "GRN-01 Office/PC")

---

## Notes

- **Rack**: Open on sides and top (optimal passive ventilation)
- **Vented panel**: In U7 to thermally isolate Mini PC from networking
- **Rack power strip**: In U3, connected to UPS for devices with standard plugs
- **UPS**: Consider upgrade to 1000-1500VA if using PoE intensively

---

## IP Plan

### Network Topology

```
Internet <-> Iliad Box (router) <-> UDM-SE <-> Homelab (segmented VLANs)
              192.168.1.254       192.168.1.1    192.168.x.0/24
                    ↑               (WAN)
              Legacy network          ↓
              Vimar/IoT          VLAN Gateway
```

### Iliad Box Configuration

| Parameter | Value |
|-----------|-------|
| Mode | Router (NO bridge/ONT) |
| IP | 192.168.1.254 |
| DHCP | **Disabled** (managed by UDM-SE) |
| DMZ | Enabled to 192.168.1.1 |
| VoIP Telephony | Working |

### IP Addresses

> See `firewall-config.md` for complete VLAN configuration.

#### Legacy Network — Iliad/Vimar (192.168.1.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Iliad Box | 192.168.1.254 | Router/modem, telephony |
| UDM-SE (WAN) | 192.168.1.1 | Receives IP via DMZ |
| Vimar Devices | 192.168.1.x | Video intercom, alarm, actuators (static) |

> [!NOTE]
> This network is NOT managed by UDM-SE. Remains for Vimar legacy devices connected to PoE switch in electrical panel.

#### VLAN 2 — Management (192.168.2.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Gateway (UDM-SE) | 192.168.2.1 | UniFi Controller |
| UniFi Switch | 192.168.2.10 | USW-Pro-Max-16-PoE |
| Access Point | 192.168.2.20 | U6-Pro |

#### VLAN 3 — Servers (192.168.3.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Gateway (UDM-SE) | 192.168.3.1 | — |
| QNAP NAS | 192.168.3.10 | Media stack, Pi-hole |
| Proxmox Mini PC | 192.168.3.20 | Plex, Tailscale |
| Printer | 192.168.3.30 | Printing |
| Desktop PC | 192.168.3.40 | Workstation |

#### VLAN 4 — Media (192.168.4.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Gateway (UDM-SE) | 192.168.4.1 | — |
| Smart TV, phones | DHCP (.100-.200) | Plex clients, *arr management |

#### VLAN 5 — Guest (192.168.5.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Gateway (UDM-SE) | 192.168.5.1 | — |
| Guest clients | DHCP (.100-.200) | Internet access only |

#### VLAN 6 — IoT (192.168.6.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Gateway (UDM-SE) | 192.168.6.1 | — |
| Alexa, new camera | DHCP (.100-.200) | Smart WiFi devices |

### Notes

- **Legacy Network**: The 192.168.1.0/24 subnet remains for Iliad Box and Vimar devices. Not managed by UDM-SE.
- **Double NAT**: Technically present, but irrelevant for homelab
- **Iliad Access**: Available at 192.168.1.254 from network (routing through WAN)
- **Telephony**: Works because Iliad remains in router mode
- **VLAN Documentation**: See `firewall-config.md`
