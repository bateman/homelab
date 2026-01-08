# Network Setup - UniFi UDM-SE and VLANs

> Complete guide to configure UniFi network with VLAN segmentation

---

## Prerequisites

- [ ] UDM-SE mounted in rack and powered on
- [ ] USW-Pro-Max-16-PoE mounted and powered on
- [ ] Ethernet cable from UDM-SE WAN port to Iliad Box LAN
- [ ] Ethernet cable from UDM-SE port 1 to Switch port 1
- [ ] PC connected to a UDM-SE LAN port

---

## Phase 1: Initial UDM-SE Setup

### 1.1 First Access

1. Connect PC directly to a UDM-SE LAN port
2. PC will receive IP via DHCP (192.168.1.x)
3. Open browser: `https://192.168.1.1`
4. Accept self-signed certificate

### 1.2 Initial Wizard

1. [ ] Select "Set up a new UniFi Console"
2. [ ] Create UniFi account or log in with existing
3. [ ] Console name: `Homelab`
4. [ ] WAN configuration:
   - Type: DHCP (Iliad Box will assign IP)
   - Verify Internet connection
5. [ ] Default LAN configuration:
   - Leave temporarily at 192.168.1.0/24
   - We'll modify later

### 1.3 Firmware Update

1. [ ] Settings → System → Firmware
2. [ ] Check for available updates
3. [ ] Install latest stable version
4. [ ] Wait for reboot (~5 minutes)

---

## Phase 2: VLAN Creation

### 2.1 Delete Default Network (optional)

> [!NOTE]
> You may want to keep the default network for transition

Settings → Networks → Default → Delete (after creating VLAN 3 for Servers)

### 2.2 Create Management VLAN (VLAN 2)

Settings → Networks → Create New Network

| Field | Value |
|-------|-------|
| Name | Management |
| Router | UDM-SE |
| Gateway IP/Subnet | 192.168.2.1/24 |
| VLAN ID | 2 |
| DHCP Mode | DHCP Server |
| DHCP Range | 192.168.2.100 - 192.168.2.200 |
| Domain Name | management.local |

**Advanced Options:**
- [ ] IGMP Snooping: Enabled
- [ ] Multicast DNS: Enabled

Click "Add Network"

### 2.3 Create Servers VLAN (VLAN 3)

| Field | Value |
|-------|-------|
| Name | Servers |
| Gateway IP/Subnet | 192.168.3.1/24 |
| VLAN ID | 3 |
| DHCP Mode | None (static IPs) |
| Domain Name | servers.local |

> [!NOTE]
> Servers VLAN uses static IPs. Assign manually: NAS=.10, Proxmox=.20, Printer=.30, PC=.40

### 2.4 Create Media VLAN (VLAN 4)

| Field | Value |
|-------|-------|
| Name | Media |
| Gateway IP/Subnet | 192.168.4.1/24 |
| VLAN ID | 4 |
| DHCP Range | 192.168.4.100 - 192.168.4.200 |
| Domain Name | media.local |

### 2.5 Create Guest VLAN (VLAN 5)

| Field | Value |
|-------|-------|
| Name | Guest |
| Gateway IP/Subnet | 192.168.5.1/24 |
| VLAN ID | 5 |
| DHCP Range | 192.168.5.100 - 192.168.5.200 |
| Network Type | Guest Network |

**Guest Options:**
- [ ] Guest Network Isolation: Enabled
- [ ] Apply Guest Policies: Enabled

### 2.6 Create IoT VLAN (VLAN 6)

| Field | Value |
|-------|-------|
| Name | IoT |
| Gateway IP/Subnet | 192.168.6.1/24 |
| VLAN ID | 6 |
| DHCP Range | 192.168.6.100 - 192.168.6.200 |
| Domain Name | iot.local |

### Verify Created VLANs

Settings → Networks should show:

```
Management  192.168.2.0/24  VLAN 2
Servers     192.168.3.0/24  VLAN 3
Media       192.168.4.0/24  VLAN 4
Guest       192.168.5.0/24  VLAN 5
IoT         192.168.6.0/24  VLAN 6
```

---

## Phase 3: Switch Configuration

### 3.1 Switch Adoption

1. [ ] Connect switch to UDM-SE port 1
2. [ ] UniFi Devices → should show "USW-Pro-Max-16-PoE"
3. [ ] Click "Adopt"
4. [ ] Wait for provisioning (~2 minutes)
5. [ ] Update firmware if available

### 3.2 Switch Port Configuration

Settings → Devices → USW-Pro-Max-16-PoE → Ports

| Port | Profile | VLAN | Device |
|------|---------|------|--------|
| 1 | All | Trunk | UDM-SE Uplink |
| 2 | Servers | 3 | Mini PC Proxmox |
| 3 | Management | 2 | (reserved) |
| 4 | Servers | 3 | (expansion) |
| 5 | Media | 4 | (expansion) |
| 6 | IoT | 6 | (expansion) |
| SFP+ 1 | Servers | 3 | NAS QNAP 10GbE |
| SFP+ 2 | - | - | (unused) |

### 3.3 Create Port Profiles

Settings → Profiles → Switch Ports → Create New Profile

**Profile "Servers":**
- Native Network: Servers (VLAN 3)
- Tagged Networks: None
- PoE: Off (for data ports)

**Profile "Management":**
- Native Network: Management (VLAN 2)
- Tagged Networks: None

**Profile "Media":**
- Native Network: Media (VLAN 4)
- Tagged Networks: None

**Profile "IoT":**
- Native Network: IoT (VLAN 6)
- Tagged Networks: None

### 3.4 Apply Profiles to Ports

For each port, click → Port Profile → select appropriate profile

---

## Phase 4: Static IP Configuration

> [!IMPORTANT]
> Static IPs for NAS and Proxmox are configured **directly on the devices** during their initial setup (see [NAS_SETUP.md](NAS_SETUP.md) and [PROXMOX_SETUP.md](PROXMOX_SETUP.md)).
>
> "Fixed IP" in UniFi is **optional** and only needed if you prefer DHCP with reservation instead of static IPs configured on devices.

### 4.1 Option A: Static IPs on Devices (Recommended)

Configure static IPs directly on:
- **NAS QNAP**: Control Panel → Network → Static IP `192.168.3.10`
- **Mini PC Proxmox**: During installation, IP `192.168.3.20`

### 4.2 Option B: DHCP Reservation in UniFi (Alternative)

If you prefer managing IPs centrally from UniFi:

1. Temporarily connect devices to make them appear in Client Devices
2. Settings → Client Devices → (search by MAC address)
3. Settings → Fixed IP Address: assign desired IP

### 4.3 Fixed IP for Switch

Switch should already have IP in Management VLAN after adoption.
Verify: Settings → Devices → Switch → IP: should be 192.168.2.x

---

## Phase 5: IP and Port Groups

> Required for firewall rules. See [`firewall-config.md`](../network/firewall-config.md) for the complete list.

### 5.1 Create IP Groups

Settings → Profiles → IP Groups → Create New Group

**Group: RFC1918 (Private Networks)**
- Type: IPv4 Address/Subnet
- Addresses:
  - `10.0.0.0/8`
  - `172.16.0.0/12`
  - `192.168.0.0/16`

**Group: NAS Server**
- Type: IPv4 Address/Subnet
- Addresses:
  - `192.168.3.10/32`

**Group: Media Clients**
- Type: IPv4 Address/Subnet
- Addresses:
  - `192.168.4.0/24`

**Group: Plex Server**
- Type: IPv4 Address/Subnet
- Addresses:
  - `192.168.3.20/32`

### 5.2 Create Port Groups

Settings → Profiles → Port Groups → Create New Group

**Group: Media Services Ports**
- Ports:
  - `8989` (Sonarr)
  - `7878` (Radarr)
  - `8686` (Lidarr)
  - `6767` (Bazarr)

> [!NOTE]
> Plex (32400) is not included because it runs on Mini PC, not NAS. qBittorrent (8080) and NZBGet (6789) are not included because Media VLAN devices (TVs, phones) don't need direct access. *arr services communicate with download clients internally via Docker network, not through firewall.

**Group: Infrastructure Ports**
- Ports:
  - `53` (DNS)
  - `8081` (Pi-hole)
  - `8123` (Home Assistant)

---

## Phase 6: Firewall Rules

**Full reference:** [`firewall-config.md`](../network/firewall-config.md)

> [!IMPORTANT]
> This section contains only essential rules to get started.
> For complete configuration (13 rules), see [`firewall-config.md`](../network/firewall-config.md).
>
> Rules below are a **minimal subset** to make media stack work.
> Add missing rules from firewall-config.md for complete security.

### 6.1 Rule Order (CRITICAL)

Rules are processed in order. Insert exactly in this sequence:

Settings → Firewall & Security → Firewall Rules → LAN → Create New Rule

### Rule 1: Allow Established/Related

| Field | Value |
|-------|-------|
| Type | LAN In |
| Description | Allow Established and Related |
| Action | Allow |
| States | Established, Related |
| Source | Any |
| Destination | Any |

### Rule 2: Allow Media to NAS Media Services

| Field | Value |
|-------|-------|
| Type | LAN In |
| Description | Media VLAN to NAS Media Services |
| Action | Allow |
| Source | Network: Media |
| Destination | IP Group: NAS Server |
| Port Group | Media Services Ports |

### Rule 3: Allow Media to Plex

| Field | Value |
|-------|-------|
| Type | LAN In |
| Description | Media VLAN to Plex |
| Action | Allow |
| Source | Network: Media |
| Destination | IP Group: Plex Server |
| Port | 32400 |

### Rule 4: Allow IoT to Home Assistant

| Field | Value |
|-------|-------|
| Type | LAN In |
| Description | IoT to Home Assistant |
| Action | Allow |
| Source | Network: IoT |
| Destination | IP Group: NAS Server |
| Port | 8123 |

### Rule 5: Block All Inter-VLAN (LAST)

| Field | Value |
|-------|-------|
| Type | LAN In |
| Description | Block All Inter-VLAN Traffic |
| Action | Drop |
| Source | IP Group: RFC1918 |
| Destination | IP Group: RFC1918 |

> [!WARNING]
> This rule MUST be last. It blocks all inter-VLAN traffic not explicitly allowed.

---

## Phase 7: Iliad Box Configuration

### 7.1 Access Iliad Box

1. Connect PC directly to Iliad Box (temporarily)
2. Access `http://192.168.1.254`
3. Login with Iliad credentials

### 7.2 DMZ Configuration (Optional)

> [!TIP]
> DMZ forwards all incoming traffic to UDM-SE. Useful for port forwarding managed by UniFi.

1. Settings → NAT/Firewall → DMZ
2. Enable DMZ
3. DMZ Host IP: UDM-SE WAN IP (check in Iliad Box → Connected devices)

### 7.3 Disable Iliad Wi-Fi (Recommended)

1. Settings → Wi-Fi
2. Disable all Wi-Fi networks
3. Wi-Fi will be managed by UniFi AP

---

## Phase 8: Configuration Verification

### Basic Connectivity Test

```bash
# From a PC on Servers VLAN (192.168.3.x)

# Test gateway
ping 192.168.3.1

# Test inter-VLAN (should work - established)
ping 192.168.2.1

# Test Internet
ping 8.8.8.8
ping google.com
```

### Firewall Rules Test

```bash
# From Media VLAN (192.168.4.x)

# Should work (allow rule)
curl http://192.168.3.10:8989  # Sonarr

# Should be blocked (no rule)
ping 192.168.3.10  # ICMP blocked by catch-all

# From Guest VLAN (192.168.5.x)
# Everything to other VLANs should be blocked
ping 192.168.3.10  # Blocked
curl http://192.168.3.10:8989  # Blocked
```

### DNS Test

```bash
# After Pi-hole configuration
nslookup google.com 192.168.3.10
```

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Switch not adopted | Different network | Temporarily connect to same subnet |
| VLAN not reachable | Port not tagged | Verify switch port profile |
| Inter-VLAN blocked | Firewall rule | Verify rule order |
| No Internet from VLAN | Wrong gateway | Verify DHCP options |
| Device wrong IP | Old DHCP lease | Renew lease or set fixed IP |

---

## Final Network Diagram

```
                    ┌─────────────┐
                    │  Internet   │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │  Iliad Box  │
                    │ 192.168.1.254│
                    └──────┬──────┘
                           │ WAN
                    ┌──────┴──────┐
                    │   UDM-SE    │
                    │ 192.168.2.1 │ ← Management
                    │ 192.168.3.1 │ ← Servers
                    │ 192.168.4.1 │ ← Media
                    │ 192.168.5.1 │ ← Guest
                    │ 192.168.6.1 │ ← IoT
                    └──────┬──────┘
                           │ Trunk (All VLANs)
                    ┌──────┴──────┐
                    │   Switch    │
                    │USW-Pro-Max  │
                    └┬─────┬─────┬┘
                     │     │     │
            ┌────────┘     │     └────────┐
            │              │              │
     ┌──────┴──────┐ ┌─────┴─────┐ ┌──────┴──────┐
     │    QNAP     │ │  Proxmox  │ │  Other      │
     │192.168.3.10 │ │192.168.3.20│ │  Devices    │
     │  VLAN 3     │ │  VLAN 3   │ │             │
     └─────────────┘ └───────────┘ └─────────────┘
```

---

## Next Steps

After completing network setup:

1. → Proceed with [NAS QNAP Setup](NAS_SETUP.md)
2. → Return to [START_HERE.md](../../START_HERE.md) Phase 3
