# 19" 8U Rack — Home Lab Configuration v3

> Configuration optimized for passive ventilation (rack open on top and bottom)

## Rack Diagram

```
┏━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ U8  │ 🖥️  Lenovo Mini PC (Proxmox)                                            ┃
┃     │   • Main heat source -> dissipates upward (open top)                    ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U7  │ 🌀 Vented Panel #1                                                      ┃
┃     │   • Thermally isolates Mini PC from rest of rack                        ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U6  │ 🌐 UDM-SE                                                               ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U5  │ 🔀 PoE Switch (USW-Pro-Max-16-PoE)                                      ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U4  │ 🔌 Patch Panel                                                          ┃
┃     │   • Passive, no heat — acts as natural buffer                           ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U3  │ 🌀 Vented Panel #2                                                      ┃
┃     │   • Airflow between NAS and networking                                  ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U2  │ 💾 QNAP NAS                                                             ┃
┃     │   • HDDs in coolest zone of rack                                        ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U1  │ ⚡ UPS                                                                  ┃
┃     │   • Weight at bottom, minimal heat generation                           ┃
┗━━━━━┷━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        ↑↑↑ HOT AIR EXITS FROM OPEN TOP ↑↑↑

        ↓↓↓ COOL AIR ENTERS FROM BOTTOM ↓↓↓
```

---

## Component Details

### Rack — StarTech WALLSHELF8U

| Spec | Value |
|------|-------|
| Model | [WALLSHELF8U](https://www.startech.com/en-us/server-management/wallshelf8u) |
| Type | 2-post wall-mount, closed side panels, open top and bottom |
| Rack Units | 8U |
| Rail Type | 10-32 tapped (threaded) — no cage nuts needed |
| Mounting Depth | 12"–18" (adjustable) |
| Dimensions | 17.6" H x 19.0" W x 18.0" D (44.6 x 48.3 x 45.7 cm) |
| Weight Capacity | 75 lb (34 kg) |
| Shelf | Built-in 12" dual-position shelf (top or bottom) |
| Wall Studs | Mounting holes at 16" spacing (standard US framing) |

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

### U5 — UniFi USW-Pro-Max-16-PoE

| Spec | Value |
|------|-------|
| GbE RJ45 Ports | 12x 1GbE (PoE+) |
| 2.5GbE RJ45 Ports | 4x 2.5GbE (PoE++) |
| SFP+ Ports | 2x 10GbE |
| SFP+ Port 1 | Uplink to UDM-SE |
| SFP+ Port 2 | QNAP NAS |
| PoE Budget | 180W |
| IP | 192.168.2.10 |

#### Port Assignments

| Port | Type | Profile | VLAN | Device/Destination | Cable Label |
|------|------|---------|------|-------------------|-------------|
| 1 | 1GbE PoE+ | Servers | 3 | Mini PC — integrated NIC (WOL only) | — |
| 2 | 1GbE PoE+ | Management | 2 | U6-Pro Access Point | WHT-01 AP |
| 3 | 1GbE PoE+ | Media | 4 | Studio (via PP-03) | GRN-01 Studio |
| 4 | 1GbE PoE+ | Media | 4 | Living Room (via PP-04) | GRN-02 Living |
| 5 | 1GbE PoE+ | Media | 4 | Bedroom (via PP-05) | GRN-03 Bedroom |
| 6-12 | 1GbE PoE+ | — | — | — (available) | — |
| 13 | 2.5GbE PoE++ | Servers | 3 | Mini PC — USB-C 2.5GbE (management) | — |
| 14-16 | 2.5GbE PoE++ | — | — | — (available) | — |
| SFP+ 1 | 10GbE | All | Trunk | Uplink to UDM-SE | — |
| SFP+ 2 | 10GbE | Servers | 3 | QNAP NAS | — |

#### Global Switch Settings

| Setting | Value |
|---------|-------|
| IGMP Snooping | Enabled (Management, IoT) |
| Device Isolation | Enabled (IoT) |
| Spanning Tree | RSTP |
| Rogue DHCP Detection | Enabled |
| Jumbo Frames | Enabled |
| L3 Network Isolation | Disabled |
| 802.1X | Disabled |

> For detailed configuration and rationale, see [`network-setup.md` Phase 3.5](../setup/network-setup.md#35-global-switch-settings).

### U6 — UniFi Dream Machine SE (UDM-SE-EU)

| Spec | Value |
|------|-------|
| Function | Firewall / Router / UniFi Controller |
| WAN RJ45 | 1x 2.5GbE (fiber/ISP input) |
| WAN SFP+ | 1x 10GbE (unused - ISP doesn't support 10G) |
| LAN RJ45 | 8x 1GbE |
| LAN SFP+ | 1x 10GbE (uplink to switch) |
| IP | 192.168.2.1 |

### U4 — LogiLink NK4077 Patch Panel

| Spec | Value |
|------|-------|
| Ports | 16x RJ45 Keystone |
| Category | CAT6A/CAT7 |
| Certification | 10 Gbit/s |

#### Port Assignments

| Patch Port | Room/Destination | Switch Port | VLAN | Cable Label |
|------------|------------------|-------------|------|-------------|
| PP-03 | Studio | Port 3 | Media (4) | GRN-01 Studio |
| PP-04 | Living Room | Port 4 | Media (4) | GRN-02 Living |
| PP-05 | Bedroom | Port 5 | Media (4) | GRN-03 Bedroom |
| PP-01, 02, 06-16 | — (available) | — | — | — |

> [!TIP]
> Patch panel ports mirror switch port numbers for easy troubleshooting.

### U3 — Vented Panel #2

- Ubiquiti UACC-Rack-Panel-Vented-1U
- Airflow between NAS and networking gear

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

### U1 — UPS Eaton 5P 650i Rack G2

| Spec | Value |
|------|-------|
| Power | 650VA / 420W |
| Technology | Line-interactive |
| Outlets | 4x IEC C13 (all battery backed + surge protected) |
| Outlet types | 2x always-on, 2x remotely manageable |
| Runtime | ~10-15 min (average load) |
| Output Voltage | 230V (adjustable: 200 / 208 / 220 / 230 / 240V) |
| Power Quality | Good (tightest thresholds) |
| Management | USB -> Proxmox (NUT) |

---

## Non-Rack Components

### UniFi U6-Pro Access Point

| Spec | Value |
|------|-------|
| Model | U6-Pro |
| Location | Ceiling/wall mounted (not in rack) |
| Power | PoE from USW-Pro-Max-16-PoE port 2 |
| IP | 192.168.2.20 |
| VLAN | Management (VLAN 2) |

> For AP adoption, WiFi SSID setup, and WiFi Blackout Schedule, see [`network-setup.md` Phase 7](../setup/network-setup.md#phase-7-wi-fi-access-point-setup).

---

## Thermal Logic

| Zone | Units | Strategy |
|------|-------|----------|
| Top (U8) | Mini PC | Maximum dissipation outward |
| U7 | Vented | Cuts heat rise from networking |
| Center (U4-U6) | Networking + Patch | Moderate heat, ventilated via top/bottom airflow |
| U3 | Vented | Airflow between NAS and networking |
| Bottom (U1-U2) | NAS + UPS | Coolest zone, ideal for HDDs (< 40C) |

---

## Power Distribution

All 4 devices connect **directly** to the UPS C13 outlets — no power strip needed.

```
                         ┌──────────────────────────────────────┐
                         │          UPS Eaton 5P 650i           │
                         │             (4x C13)                 │
                         │  ┌────────────┬────────────────────┐ │
                         │  │ Always-on  │ Remotely manageable│ │
                         │  │  C13 #1    │  C13 #3            │ │
                         │  │  C13 #2    │  C13 #4            │ │
                         │  └────────────┴────────────────────┘ │
                         └───┬──────┬──────────┬──────────┬─────┘
                             │      │          │          │
                             ▼      ▼          ▼          ▼
                        ┌──────┐ ┌──────┐ ┌───────┐ ┌─────────┐
                        │UDM-SE│ │Switch│ │  NAS  │ │ Mini PC │
                        │      │ │ PoE  │ │ QNAP  │ │ Lenovo  │
                        └──────┘ └──────┘ └───────┘ └─────────┘
```

| UPS Outlet | Type | Device | Cable | Length |
|-----------|------|--------|-------|--------|
| C13 #1 | Always-on | UDM-SE (U6) | IEC C13→C14 | 1.0 m |
| C13 #2 | Always-on | PoE Switch (U5) | IEC C13→C14 | 1.0 m |
| C13 #3 | Remotely manageable | QNAP NAS (U2) | IEC C13→C14 | 0.5 m |
| C13 #4 | Remotely manageable | Lenovo Mini PC (U8) | IEC C13→Schuko adapter + power brick | 1.5 m |

> [!NOTE]
> **Outlet logic:** Network infrastructure (UDM-SE, Switch) on **always-on** outlets — they must stay powered for remote management. Storage and compute (NAS, Mini PC) on **remotely manageable** outlets — NUT can shut them down during extended outages to extend battery runtime for the network.

> [!NOTE]
> The Mini PC uses an external power brick with Schuko plug. It requires a **C13→Schuko adapter cable** (IEC C14 plug → Schuko socket). All other devices have native IEC C14 power inlets.

---

## Network Backbone

```
UDM-SE (LAN SFP+) <--10G--> Switch (SFP+ Port 1)
                                   │
                             (SFP+ Port 2)
                                   │
                                   │ 10G
                                   ↓
                             NAS (SFP+ Port 1)

                             Switch (Port 13)
                                   │
                                   │ 2.5G (management)
                                   ↓
                             Mini PC (USB-C adapter)

                             Switch (Port 1)
                                   │
                                   │ 1G (WOL only)
                                   ↓
                             Mini PC (integrated NIC)
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
| Recyclarr | — | Trash Guides profile sync |
| Huntarr | 9705 | *arr monitoring |
| Cleanuparr | 11011 | Automatic cleanup |
| FlareSolverr | 8191 | Cloudflare bypass |
| Pi-hole | 8081 | DNS ad-blocking |
| Portainer | 9443 | Docker management |
| Authelia | — | SSO authentication (via auth.home.local only) |
| Duplicati | 8200 | Incremental backup |
| Uptime Kuma | 3001 | Monitoring and alerting |
| Watchtower | 8383 | Container auto-update |
| Traefik | 80/443 | Reverse proxy (dashboard via traefik.home.local) |

> [!NOTE]
> **Optional service:** Home Assistant (port 8123) is available via `compose.homeassistant.yml` but not included in the default stack. To enable, add `-f compose.homeassistant.yml` to your docker compose command.

### Proxmox Mini PC (192.168.3.20)

| Service | Port | IP | Description |
|---------|------|-----|-------------|
| Plex | 32400 | 192.168.3.21 | Media server (LXC container) |
| Tailscale | — | 192.168.3.20 | Mesh VPN (host) |

---

## Network Cable Color Coding

Cables are identified by **colored straps** (not by cable jacket color). Attach a colored strap near each end of the cable to indicate its role.

| Strap Color | Use | Example |
|-------------|-----|---------|
| 🩶 Grey | Rack internal | NAS, Mini PC |
| 🟢 Green | Room devices | Bedroom, Office, Living Room |
| ⚪ White | Management / Uplink | UDM-SE, Switch, Access Point |

> [!TIP]
> Every cable must have a colored strap and a label on both ends with: color + number + destination (e.g. "GRN-01 Office/PC", "GRY-01 Proxmox")

---

## Notes

- **Rack**: StarTech WALLSHELF8U — 2-post wall-mount, closed side panels, open top and bottom, 10-32 threaded rails (see [product page](https://www.startech.com/en-us/server-management/wallshelf8u))
- **Vented panels**: U7 (thermal isolation between Mini PC and networking) and U3 (airflow between NAS and networking)
- **UPS**: All 4 devices connect directly to UPS C13 outlets (no power strip). Consider upgrade to 1000-1500VA if using PoE intensively
- **Installation order**: See [Rack Mounting Guide](../setup/rack-mounting-guide.md) for recommended bottom-up installation sequence

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
