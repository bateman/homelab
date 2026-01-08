# UniFi Dream Machine SE — Firewall Configuration

> Firewall configuration with VLAN segmentation for homelab

---

## Network Topology

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                      Iliad Box                              │
│                   192.168.1.254                             │
│                                                             │
│   Legacy network 192.168.1.0/24 (Vimar, intercom, etc.)     │
│                                                             │
│   ┌─────────────────┐                                       │
│   │ Switch PoE Vimar│──► Vimar devices (static IPs)         │
│   └─────────────────┘                                       │
│                                                             │
│   DMZ -> 192.168.1.1 (UDM-SE WAN)                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                        UDM-SE                               │
│                  WAN: 192.168.1.1                           │
│                                                             │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────┐  │
│  │ VLAN 2  │ │ VLAN 3  │ │ VLAN 4  │ │ VLAN 5  │ │VLAN 6 │  │
│  │  Mgmt   │ │ Servers │ │  Media  │ │  Guest  │ │  IoT  │  │
│  │ .2.0/24 │ │ .3.0/24 │ │ .4.0/24 │ │ .5.0/24 │ │.6.0/24│  │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └───────┘  │
└─────────────────────────────────────────────────────────────┘
         │
         │ SFP+ 10G
         ▼
┌─────────────────┐
│ USW-Pro-Max     │
│   -16-PoE       │
└─────────────────┘
```

---

## VLAN Definition

| VLAN ID | Name | Subnet | Gateway | DHCP Range | Purpose |
|---------|------|--------|---------|------------|---------|
| 2 | Management | 192.168.2.0/24 | 192.168.2.1 | .100-.200 | UDM-SE, Switch, Access Point |
| 3 | Servers | 192.168.3.0/24 | 192.168.3.1 | Disabled* | NAS, Proxmox, printer, desktop PC (static IPs) |
| 4 | Media | 192.168.4.0/24 | 192.168.4.1 | .100-.200 | Smart TV, phones, tablets |
| 5 | Guest | 192.168.5.0/24 | 192.168.5.1 | .100-.200 | Guest WiFi |
| 6 | IoT | 192.168.6.0/24 | 192.168.6.1 | .100-.200 | Alexa, new camera, smart WiFi devices |

> [!NOTE]
> The 192.168.1.0/24 subnet is NOT managed by UDM-SE. It remains for Iliad Box and legacy Vimar devices connected to the PoE switch in the electrical panel.

> [!TIP]
> **DHCP Disabled on VLAN 3**: Server devices use static IPs configured directly on them. If you need to temporarily connect a new device to configure it, you can:
> 1. Connect it first to another VLAN with DHCP (e.g., Management), configure the static IP, then move it
> 2. Configure the static IP manually before connecting to the network

---

## Static IP Plan

### Legacy Network — Iliad/Vimar (192.168.1.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Iliad Box | 192.168.1.254 | Router/modem, telephony |
| UDM-SE (WAN) | 192.168.1.1 | Receives IP via DMZ |
| Vimar devices | 192.168.1.x | Intercom, alarm, actuators (static) |

> This network is managed by Iliad Box, not UDM-SE.

### VLAN 2 — Management (192.168.2.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Gateway (UDM-SE) | 192.168.2.1 | Integrated UniFi controller |
| USW-Pro-Max-16-PoE | 192.168.2.10 | Managed switch |
| U6-Pro Access Point | 192.168.2.20 | WiFi |

### VLAN 3 — Servers (192.168.3.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Gateway (UDM-SE) | 192.168.3.1 | — |
| NAS QNAP | 192.168.3.10 | Media stack, Pi-hole |
| Mini PC Proxmox | 192.168.3.20 | Plex, Tailscale |
| Printer | 192.168.3.30 | Printing from PC and Media devices |
| Desktop PC | 192.168.3.40 | Main workstation |

### VLAN 4 — Media (192.168.4.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Gateway (UDM-SE) | 192.168.4.1 | — |
| Smart TV bedroom | DHCP reservation | Wired |
| Smart TV living room | DHCP reservation | WiFi |
| Phones/Tablets | DHCP | Plex clients, *arr management |

### VLAN 5 — Guest (192.168.5.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Gateway (UDM-SE) | 192.168.5.1 | — |
| Guest clients | DHCP | Internet access only |

### VLAN 6 — IoT (192.168.6.0/24)

| Device | IP | Notes |
|--------|-----|-------|
| Gateway (UDM-SE) | 192.168.6.1 | — |
| Alexa | DHCP reservation | Cloud-dependent |
| New camera | DHCP reservation | Cloud-dependent (Vimar View) |
| Other IoT devices | DHCP | WiFi sensors, smart lights, etc. |

---

## Iliad Box Configuration

| Parameter | Value |
|-----------|-------|
| Mode | Router (NO bridge/ONT) |
| LAN IP | 192.168.1.254 (unchanged) |
| DHCP | Disabled (or limited range .200-.250 for Vimar) |
| DMZ | Enabled to 192.168.1.1 |
| VoIP Telephony | Working |

> [!IMPORTANT]
> Iliad Box IP should NOT be changed. The 192.168.1.0/24 subnet remains for legacy Vimar devices.

---

## WiFi Networks (SSID)

| SSID | VLAN | Security | Notes |
|------|------|----------|-------|
| Casa-Media | 4 | WPA3/WPA2 | TV, phones, tablets |
| Casa-Guest | 5 | WPA3/WPA2 | Guests, complete isolation |
| Casa-IoT | 6 | WPA3/WPA2 | Alexa, smart WiFi devices |

> [!NOTE]
> No SSID needed for Management (wired access only) or Servers (wired devices with static IPs).

---

## Firewall Rules

### Philosophy

The firewall follows the "deny all, allow specific" principle: all inter-VLAN traffic is blocked by default, then explicit exceptions are created for necessary flows.

Rules are organized in logical groups for easier maintenance.

### IP Groups

Before creating rules, define these groups in Settings -> Profiles -> IP Groups:

| Group Name | Type | Content |
|------------|------|---------|
| NAS | IP Address | 192.168.3.10 |
| MiniPC | IP Address | 192.168.3.20 |
| Printer | IP Address | 192.168.3.30 |
| Servers-All | IP Address | 192.168.3.10, 192.168.3.20, 192.168.3.30 |
| VLAN-Management | Subnet | 192.168.2.0/24 |
| VLAN-Servers | Subnet | 192.168.3.0/24 |
| VLAN-Media | Subnet | 192.168.4.0/24 |
| VLAN-Guest | Subnet | 192.168.5.0/24 |
| VLAN-IoT | Subnet | 192.168.6.0/24 |
| RFC1918 | Subnet | 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12 |

### Port Groups

Define in Settings -> Profiles -> Port Groups:

| Group Name | Ports |
|------------|-------|
| DNS | 53 |
| Plex | 32400 |
| Plex-Discovery | 32410-32414 |
| Arr-Stack | 8989, 7878, 8686, 9696, 6767, 8080, 6789, 9705, 11011, 8081, 8191, 8200, 3001 |
| HomeAssistant | 8123 |
| Portainer | 9443 |
| Printing | 631, 9100 |
| mDNS | 5353 |

> [!NOTE]
> Arr-Stack includes: Sonarr (8989), Radarr (7878), Lidarr (8686), Prowlarr (9696), Bazarr (6767), qBittorrent (8080), NZBGet (6789), Huntarr (9705), Cleanuparr (11011), Pi-hole (8081), FlareSolverr (8191), Duplicati (8200), Uptime Kuma (3001).

---

## LAN In Rules (Inter-VLAN)

Path: Settings -> Firewall & Security -> Firewall Rules -> LAN In

Rules are processed in order, from first to last. Order matters.

### Rule 1 — Allow Established/Related

| Field | Value |
|-------|-------|
| Name | Allow Established/Related |
| Action | Accept |
| Protocol | All |
| Source | Any |
| Destination | Any |
| States | Established, Related |

> [!IMPORTANT]
> Allows return traffic for already established connections. Essential for proper operation.

### Rule 2 — Allow All -> Pi-hole DNS

| Field | Value |
|-------|-------|
| Name | Allow DNS to Pi-hole |
| Action | Accept |
| Protocol | TCP/UDP |
| Source | Any |
| Destination | NAS (192.168.3.10) |
| Port | DNS (53) |

> Centralized DNS accessible from all VLANs.

### Rule 3 — Allow Media -> Plex

| Field | Value |
|-------|-------|
| Name | Allow Media to Plex |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | MiniPC (192.168.3.20) |
| Port | Plex (32400) |

### Rule 4 — Allow Media -> Plex Discovery

| Field | Value |
|-------|-------|
| Name | Allow Media to Plex Discovery |
| Action | Accept |
| Protocol | UDP |
| Source | VLAN-Media |
| Destination | MiniPC (192.168.3.20) |
| Port | Plex-Discovery (32410-32414) |

### Rule 5 — Allow Media -> Arr Stack

| Field | Value |
|-------|-------|
| Name | Allow Media to Arr Stack |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | NAS (192.168.3.10) |
| Port | Arr-Stack |

### Rule 6 — Allow Media -> Portainer

| Field | Value |
|-------|-------|
| Name | Allow Media to Portainer |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | NAS (192.168.3.10) |
| Port | Portainer (9443) |

### Rule 7 — Allow Media -> Printer

| Field | Value |
|-------|-------|
| Name | Allow Media to Printer |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | Printer (192.168.3.30) |
| Port | Printing (631, 9100) |

### Rule 8 — Allow Media -> Home Assistant

| Field | Value |
|-------|-------|
| Name | Allow Media to Home Assistant |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | NAS (192.168.3.10) |
| Port | HomeAssistant (8123) |

> Allows Media devices (phones, tablets) to access the Home Assistant interface.

### Rule 9 — Allow IoT -> Home Assistant

| Field | Value |
|-------|-------|
| Name | Allow IoT to Home Assistant |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-IoT |
| Destination | NAS (192.168.3.10) |
| Port | HomeAssistant (8123) |

> Allows IoT devices to communicate with Home Assistant for automations.

### Rule 10 — Block IoT -> All Private

| Field | Value |
|-------|-------|
| Name | Block IoT to Private Networks |
| Action | Drop |
| Protocol | All |
| Source | VLAN-IoT |
| Destination | RFC1918 |

> [!TIP]
> Blocks any attempt by IoT devices to reach other private networks. They can only access the Internet (required for Alexa and cloud services) and Home Assistant (rule 9).

### Rule 11 — Block Guest -> All Private

| Field | Value |
|-------|-------|
| Name | Block Guest to Private Networks |
| Action | Drop |
| Protocol | All |
| Source | VLAN-Guest |
| Destination | RFC1918 |

> Complete Guest network isolation. Internet access only.

### Rule 12 — Allow Management from Servers

| Field | Value |
|-------|-------|
| Name | Allow Servers to Management |
| Action | Accept |
| Protocol | All |
| Source | VLAN-Servers |
| Destination | VLAN-Management |

> Allows desktop PC (VLAN 3) to access switch and AP management interfaces.

### Rule 13 — Block All Inter-VLAN (Catch-All)

| Field | Value |
|-------|-------|
| Name | Block All Inter-VLAN |
| Action | Drop |
| Protocol | All |
| Source | RFC1918 |
| Destination | RFC1918 |

> Final catch-all: blocks all inter-VLAN traffic not explicitly allowed.

---

## mDNS Reflection

Path: Settings -> Networks -> (select VLAN) -> Advanced -> Multicast DNS

Enable mDNS reflection to allow automatic discovery across VLANs:
- **Printer**: discovery from Media devices
- **Home Assistant**: IoT device discovery (Alexa, smart devices)
- **Chromecast/AirPlay**: streaming from phones to TV

| VLAN | mDNS Enabled | Reason |
|------|--------------|--------|
| 2 (Management) | No | Management only, no discovery needed |
| 3 (Servers) | Yes | HA discovery, printer |
| 4 (Media) | Yes | Chromecast, AirPlay, printer |
| 5 (Guest) | No | Complete isolation |
| 6 (IoT) | Yes | HA smart device discovery |

> [!NOTE]
> mDNS reflection only exposes service names (e.g., "Printer._ipp._tcp.local"), it doesn't provide access. The firewall continues to block unauthorized traffic between VLANs.

---

## Threat Management (IDS/IPS)

Path: Settings -> Firewall & Security -> Threat Management

| Parameter | Value |
|-----------|-------|
| Status | Enabled |
| Mode | IPS (Intrusion Prevention) |
| Sensitivity | Medium |
| Restrict IoT | Enabled (VLAN 6) |
| Restrict Guest | Enabled (VLAN 5) |

> IPS on IoT and Guest adds a layer of protection against anomalous behavior from compromised devices.

---

## Traffic Rules (QoS)

Path: Settings -> Traffic Management -> Traffic Rules

### Plex Priority

| Field | Value |
|-------|-------|
| Name | Prioritize Plex |
| Action | Set DSCP |
| DSCP Value | 46 (EF - Expedited Forwarding) |
| Source | MiniPC (192.168.3.20) |
| Port | 32400 |

### Guest Bandwidth Limiting

| Field | Value |
|-------|-------|
| Name | Limit Guest Bandwidth |
| Action | Rate Limit |
| Download | 50 Mbps |
| Upload | 10 Mbps |
| Source | VLAN-Guest |

---

## DNS Configuration (DHCP)

### DNS Architecture

Pi-hole (192.168.3.10) is the primary DNS for all VLANs, providing ad-blocking and local name resolution (`*.home.local`). To avoid Single Point of Failure, configure a fallback DNS.

### Per-VLAN Configuration

Path: Settings -> Networks -> (select VLAN) -> DHCP -> DHCP DNS Server

| VLAN | Primary DNS | Secondary DNS | Notes |
|------|-------------|---------------|-------|
| 2 (Management) | 192.168.3.10 | 1.1.1.1 | Pi-hole + Cloudflare fallback |
| 3 (Servers) | N/A | N/A | Static IPs, DNS configured on each host |
| 4 (Media) | 192.168.3.10 | 1.1.1.1 | Pi-hole + Cloudflare fallback |
| 5 (Guest) | 1.1.1.1 | 1.0.0.1 | Cloudflare only (no Pi-hole) |
| 6 (IoT) | 192.168.3.10 | 1.1.1.1 | Pi-hole + Cloudflare fallback |

> **Note VLAN 5 (Guest)**: Guests use Cloudflare directly to prevent them from seeing local DNS records (`*.home.local`).

### Fallback Behavior

- **Normal**: Clients use Pi-hole (192.168.3.10) for all queries
- **Pi-hole down**: Clients automatically fallback to Cloudflare (1.1.1.1)
- **During fallback**: Ad-blocking disabled, `*.home.local` names don't resolve

### Verify Configuration

```bash
# From a DHCP client (e.g., phone on Media VLAN)
# Verify it receives both DNS
# Android: Settings -> WiFi -> Network details
# iOS: Settings -> WiFi -> (i) -> DNS

# Test fallback (from desktop PC)
# 1. Stop Pi-hole
docker stop pihole

# 2. Verify DNS still works (uses fallback)
nslookup google.com
# Should work via 1.1.1.1

# 3. Verify *.home.local does NOT work (normal during fallback)
nslookup sonarr.home.local
# Fails - use direct IP or restart Pi-hole

# 4. Restart Pi-hole
docker start pihole
```

### Fallback DNS Limitations

- **Local names**: `*.home.local` don't resolve during Pi-hole outage
- **Ad-blocking**: Disabled during fallback
- **Workaround**: Access services via direct IP (e.g., `https://192.168.3.10:8989`)

> [!TIP]
> For complete redundancy with ad-blocking, install second Pi-hole on Proxmox with Gravity Sync. See Gravity Sync documentation: https://github.com/vmstan/gravity-sync

---

## Port Forwarding

For remote access via Tailscale, no port forwarding is needed: Tailscale uses NAT traversal.

If in the future you need to open specific ports (e.g., for remote Plex without Tailscale):

| Name | External Port | Internal Port | Destination | Protocol |
|------|---------------|---------------|-------------|----------|
| Plex Remote | 32400 | 32400 | 192.168.3.20 | TCP |

> [!WARNING]
> Opening ports exposes services to the Internet. Prefer Tailscale when possible.

---

## Configuration Checklist

1. [ ] Verify Iliad Box IP (192.168.1.254) and DMZ to 192.168.1.1
2. [ ] Create VLANs 2, 3, 4, 5, 6 in Settings -> Networks
3. [ ] Create IP Groups in Settings -> Profiles
4. [ ] Create Port Groups in Settings -> Profiles
5. [ ] Configure firewall rules in order
6. [ ] Enable mDNS reflection on VLANs 3, 4, and 6
7. [ ] Configure Threat Management
8. [ ] Create WiFi SSIDs (Casa-Media, Casa-Guest, Casa-IoT)
9. [ ] Assign static IPs to Server devices
10. [ ] Test inter-VLAN communication

---

## Troubleshooting

### Verify inter-VLAN connectivity

From desktop PC (192.168.3.40):

```bash
# Test DNS
nslookup google.com 192.168.3.10

# Test Plex
curl -I http://192.168.3.20:32400/web

# Test Iliad Box reachability (from Servers VLAN)
ping 192.168.1.254
```

### Firewall logs

Path: Settings -> Firewall & Security -> Firewall Rules -> (rule) -> Enable Logging

Enable logging on Drop rules to diagnose blocked traffic.

### Useful commands from SSH on UDM-SE

```bash
# View iptables rules
iptables -L -n -v

# Real-time traffic monitor
tcpdump -i br0 -n

# Verify VLAN tagging
cat /sys/class/net/br0/bridge/vlan_filtering
```

---

## Legacy Network Security Considerations (192.168.1.0/24)

The 192.168.1.0/24 network is not managed by UDM-SE and represents a potential attack vector.

### Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────┐
│         Iliad Box                   │
│       192.168.1.254                 │
│                                     │
│   ┌─────────────┐  ┌─────────────┐  │
│   │ Switch PoE  │  │  UDM-SE WAN │  │
│   │   Vimar     │  │ 192.168.1.1 │  │
│   └──────┬──────┘  └──────┬──────┘  │
│          │                │         │
│    Vimar devices      DMZ (all)     │
│    .1.x                             │
└─────────────────────────────────────┘
```

### Theoretical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Compromised Vimar device attacks UDM-SE WAN | Low | Medium | UDM-SE protected by default |
| Lateral movement from 192.168.1.x to internal VLANs | Very low | High | No route, UDM-SE blocks |
| Attack on Iliad Box | Low | Medium | ISP-managed device |

### Existing Mitigations

1. **UDM-SE WAN protection**: WAN→LAN traffic blocked by default
2. **No routing**: 192.168.1.x devices have no route to 192.168.2-6.x
3. **Threat Management**: IDS/IPS active on UDM-SE detects anomalies
4. **Trusted devices**: Professionally installed Vimar, not consumer IoT

### Risk Acceptance

For this homelab, the risk is accepted because:
- Vimar are professional devices with controlled firmware
- They require physical compromise or specific 0-day vulnerability
- The alternative (complete rewiring) has disproportionate cost to benefit
- UDM-SE provides adequate protection on the WAN interface

> **Future improvement (optional)**: Add WAN Local rule on UDM-SE to block management access (port 443) from 192.168.1.0/24 subnet except 192.168.1.254 (Iliad Box).

---

## Double NAT (Known Limitation)

### Current Architecture

```
Internet
    │
    ▼
┌─────────────────┐
│   Iliad Box     │  ◄── NAT #1 (ISP)
│  192.168.1.254  │
│   (router mode) │
└────────┬────────┘
         │ 192.168.1.1
         ▼
┌─────────────────┐
│    UDM-SE       │  ◄── NAT #2 (Homelab)
│   WAN: .1.1     │
│   LAN: .2-6.x   │
└─────────────────┘
```

### Impact

| Feature | Impact | Workaround |
|---------|--------|------------|
| **Port forwarding** | Doesn't work | Tailscale (already implemented) |
| **UPnP/NAT-PMP** | Doesn't work | Manual configuration not possible |
| **Online gaming** | Possible NAT strict issues | Use Tailscale or tolerate |
| **VoIP/SIP** | Possible issues | Not used in this homelab |
| **Latency** | +1-2ms theoretical | Negligible |
| **Throughput** | No impact | - |

### Why Not Resolved

1. **Iliad Box doesn't support bridge mode**: Iliad ISP doesn't allow putting the router in bridge/modem-only mode
2. **Separate ONT not available**: Iliad uses integrated router, doesn't provide standalone ONT
3. **DMZ active**: Iliad Box has DMZ to UDM-SE (192.168.1.1), partially mitigates the issue

### Implemented Mitigations

- **Tailscale**: Remote access without port forwarding (NAT traversal)
- **DMZ on Iliad Box**: All traffic forwarded to UDM-SE
- **Internal services**: All homelab services work correctly on local network

### Definitive Solution (Not Implemented)

To eliminate Double NAT:
1. Change ISP to one providing separate ONT or bridge mode
2. Use PPPoE directly on UDM-SE (requires ISP credentials)

> **Acceptance**: For this homelab Double NAT is accepted. Tailscale solves remote access and internal services are not impacted.

---

## Notes

- **Legacy Network**: The 192.168.1.0/24 subnet remains for Iliad Box and Vimar devices. Not managed by UDM-SE.
- **Double NAT**: See dedicated section above.
- **Tailscale**: Installed on Mini PC Proxmox, provides mesh VPN access without port forwarding.
- **Home Assistant**: Accessible from Media VLAN (phones/tablets) and IoT VLAN (smart devices).
- **Config backup**: Export regularly from Settings -> System -> Backup.
