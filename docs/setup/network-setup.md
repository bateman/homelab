# Network Setup - UniFi UDM-SE and VLANs

> Complete guide to configure UniFi network with VLAN segmentation

---

## Prerequisites

- [ ] UDM-SE mounted in rack and powered on
- [ ] USW-Pro-Max-16-PoE mounted and powered on
- [ ] Ethernet cable from UDM-SE WAN port to Iliad Box LAN
- [ ] SFP+ DAC or fiber cable from UDM-SE LAN SFP+ to Switch SFP+ port 1
- [ ] PC connected to a UDM-SE LAN port

---

## Phase 1: Initial UDM-SE Setup

### 1.1 First Access

1. Connect PC directly to a UDM-SE LAN port
2. PC will receive IP via DHCP (192.168.0.x)
3. Open browser: `https://192.168.0.1`
4. Accept self-signed certificate

### 1.2 Initial Wizard

1. [ ] Select "Set up a new UniFi Console"
2. [ ] Create UniFi account or log in with existing
3. [ ] Console name: `Homelab`
4. [ ] WAN configuration:
   - Type: DHCP (Iliad Box will assign IP)
   - Verify Internet connection
5. [ ] Default LAN configuration:
   - Leave at default 192.168.0.0/24
   - We'll modify later

### 1.3 Firmware Update

1. [ ] In **UDM-SE** (Network application): Settings → System → Firmware
2. [ ] Check for available updates
3. [ ] Install latest stable version
4. [ ] Wait for reboot (~5 minutes)

---

## Phase 2: VLAN Creation

### 2.1 Delete Default Network (optional)

> [!NOTE]
> You may want to keep the default network for transition

In **UDM-SE** (Network application): Settings → Networks → Default → Delete (after creating VLAN 3 for Servers)

### 2.2 Create Management VLAN (VLAN 2)

In **UDM-SE** (Network application): Settings → Networks → Create New Network

| Field | Value |
|-------|-------|
| Name | Management |
| Router | UDM-SE |
| Gateway IP/Subnet | 192.168.2.1/24 |
| VLAN ID | 2 |
| DHCP Mode | DHCP Server |
| DHCP Range | 192.168.2.100 - 192.168.2.200 |
| Domain Name | management.local |

**DHCP Options:**
- [ ] Auto DNS Server: Disabled
- [ ] DNS Server 1: `192.168.3.10` (Pi-hole)
- [ ] DNS Server 2: `1.1.1.1` (Cloudflare fallback)

**Advanced Options:**
- [ ] IGMP Snooping: Enabled

Click "Add Network"

### 2.3 Create Servers VLAN (VLAN 3)

| Field | Value |
|-------|-------|
| Name | Servers |
| Gateway IP/Subnet | 192.168.3.1/24 |
| VLAN ID | 3 |
| DHCP Mode | None (static IPs) |
| Domain Name | servers.local |

**Advanced Options:**
- [ ] Multicast DNS: Enabled

> [!NOTE]
> Servers VLAN uses static IPs. Assign manually: NAS=.10, Proxmox=.20, Printer=.30, PC=.40

### 2.4 Create Media VLAN (VLAN 4)

| Field | Value |
|-------|-------|
| Name | Media |
| Gateway IP/Subnet | 192.168.4.1/24 |
| VLAN ID | 4 |
| DHCP Mode | DHCP Server |
| DHCP Range | 192.168.4.100 - 192.168.4.200 |
| Domain Name | media.local |

**DHCP Options:**
- [ ] Auto DNS Server: Disabled
- [ ] DNS Server 1: `192.168.3.10` (Pi-hole)
- [ ] DNS Server 2: `1.1.1.1` (Cloudflare fallback)

**Advanced Options:**
- [ ] Multicast DNS: Enabled

### 2.5 Create Guest VLAN (VLAN 5)

| Field | Value |
|-------|-------|
| Name | Guest |
| Gateway IP/Subnet | 192.168.5.1/24 |
| VLAN ID | 5 |
| DHCP Mode | DHCP Server |
| DHCP Range | 192.168.5.100 - 192.168.5.200 |
| Network Type | Guest Network |

**DHCP Options:**
- [ ] Auto DNS Server: Disabled
- [ ] DNS Server 1: `1.1.1.1` (Cloudflare)
- [ ] DNS Server 2: `1.0.0.1` (Cloudflare fallback)

**Guest Options:**
- [ ] Guest Network Isolation: Enabled
- [ ] Apply Guest Policies: Enabled
- [ ] Guest Portal/Hotspot: Disabled

**Advanced Options:**
- [ ] IGMP Snooping: Disabled (guests don't use multicast services)
- [ ] Multicast DNS: Disabled (no service discovery for guests)

> [!NOTE]
> The Guest Network type provides built-in client isolation — guests cannot see or reach other clients on the same VLAN, nor access devices on other VLANs. This is stronger than Device Isolation (ACL) and doesn't need to be configured separately in Global Switch Settings.
>
> DNS is pointed to Cloudflare (not Pi-hole) so guest traffic doesn't depend on local infrastructure.

### 2.6 Create IoT VLAN (VLAN 6)

| Field | Value |
|-------|-------|
| Name | IoT |
| Gateway IP/Subnet | 192.168.6.1/24 |
| VLAN ID | 6 |
| DHCP Mode | DHCP Server |
| DHCP Range | 192.168.6.100 - 192.168.6.200 |
| Domain Name | iot.local |

**DHCP Options:**
- [ ] Auto DNS Server: Disabled
- [ ] DNS Server 1: `192.168.3.10` (Pi-hole)
- [ ] DNS Server 2: `1.1.1.1` (Cloudflare fallback)

**Advanced Options:**
- [ ] IGMP Snooping: Enabled
- [ ] Multicast DNS: Enabled

### Verify Created VLANs

In **UDM-SE** (Network application): Settings → Networks should show:

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

1. [ ] Connect switch SFP+ port 1 to UDM-SE LAN SFP+ port (10GbE uplink)
2. [ ] UniFi Devices → should show "USW-Pro-Max-16-PoE"
3. [ ] Click "Adopt"
4. [ ] Wait for provisioning (~2 minutes)
5. [ ] Update firmware if available

### 3.2 Switch Port Configuration

In **UDM-SE** (Network application): Settings → Devices → USW-Pro-Max-16-PoE → Ports

| Port | Profile | VLAN | Device |
|------|---------|------|--------|
| 1 | Servers | 3 | Mini PC Proxmox |
| 2 | Management | 2 | U6-Pro Access Point |
| 3 | Media | 4 | Studio (via PP-03) |
| 4 | Media | 4 | Living Room (via PP-04) |
| 5 | Media | 4 | Bedroom (via PP-05) |
| 6 | IoT | 6 | (available) |
| SFP+ 1 | All | Trunk | UDM-SE Uplink (10GbE) |
| SFP+ 2 | Servers | 3 | NAS QNAP 10GbE |

### 3.3 Create Port Profiles

In **UDM-SE** (Network application): Settings → Profiles → Switch Ports → Create New Profile

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

### 3.5 Global Switch Settings

In **UDM-SE** (Network application): Settings → Devices → USW-Pro-Max-16-PoE → Settings

#### IGMP Snooping

- [ ] IGMP Snooping: Enabled
- [ ] VLANs: Management, IoT
- [ ] Forward Unknown Multicast Traffic: Drop
- [ ] Flood Known Protocols: Enabled
- [ ] Fast Leave: Disabled

> [!NOTE]
> IGMP Snooping controls multicast traffic per-VLAN. Enable it on Management (network devices) and IoT (mDNS/SSDP discovery). Media and Servers VLANs don't need it — media clients use unicast (Plex) and servers communicate via Docker networking. Guest VLAN is excluded because guests don't use multicast services and the Guest Network type already isolates traffic.
>
> Fast Leave is disabled because it can cause brief multicast interruptions on ports with multiple clients — only useful for single-receiver setups (e.g., IPTV set-top boxes).

#### Device Isolation (ACL)

- [ ] Device Isolation: Enabled
- [ ] Networks: IoT

> [!NOTE]
> Prevents IoT devices from communicating with each other within VLAN 6. A compromised smart device cannot pivot to attack other devices on the same VLAN. This works because IoT devices communicate through Home Assistant (on Servers VLAN), not directly with each other.
>
> Guest VLAN is not included here because UniFi's Guest Network type already provides stronger client isolation — guests are automatically prevented from accessing other clients and local network resources.
>
> Device Isolation does not apply to clients connected directly to the UDM-SE's built-in LAN ports — only to devices connected via the switch or Wi-Fi AP.

#### Other Global Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Spanning Tree Protocol | RSTP | Rapid convergence, prevents loops |
| Rogue DHCP Server Detection | Enabled | Prevents compromised devices from serving rogue DHCP |
| Jumbo Frames | Enabled | Benefits 10GbE NAS link; ignored by devices that don't support it |
| 802.1X Control | Disabled | IoT devices don't support 802.1X |
| L3 Network Isolation (ACL) | Disabled | UDM-SE firewall handles inter-VLAN blocking with stateful rules and port-level control |

---

## Phase 4: Static IP Configuration

> [!IMPORTANT]
> Static IPs for NAS and Proxmox are configured **directly on the devices** during their initial setup (see [nas-setup.md](nas-setup.md) and [proxmox-setup.md](proxmox-setup.md)).
>
> "Fixed IP" in UniFi is **optional** and only needed if you prefer DHCP with reservation instead of static IPs configured on devices.

### 4.1 Option A: Static IPs on Devices (Recommended)

Configure static IPs directly on:
- **NAS QNAP**: Control Panel → Network → Static IP `192.168.3.10`
- **Mini PC Proxmox**: During installation, IP `192.168.3.20`

### 4.2 Option B: DHCP Reservation in UniFi (Alternative)

If you prefer managing IPs centrally from UniFi:

1. Temporarily connect devices to make them appear in Client Devices
2. In **UDM-SE** (Network application): Settings → Client Devices → (search by MAC address)
3. Click device → Fixed IP Address: assign desired IP

### 4.3 Fixed IP for Switch

Switch should already have IP in Management VLAN after adoption.
Verify in **UDM-SE** (Network application): Settings → Devices → Switch → IP: should be 192.168.2.x

---

## Phase 5: Network Lists

> Required for firewall rules. See [`firewall-config.md`](../network/firewall-config.md) for the complete list.

### 5.1 Create IP Address Network Lists

In **UDM-SE** (Network application): Settings → Profiles → Network Lists → Create New

**List: RFC1918 (Private Networks)**
- Type: IPv4 Address/Subnet
- Addresses:
  - `10.0.0.0/8`
  - `172.16.0.0/12`
  - `192.168.0.0/16`

**List: NAS Server**
- Type: IPv4 Address/Subnet
- Addresses:
  - `192.168.3.10`

**List: Media Clients**
- Type: IPv4 Address/Subnet
- Addresses:
  - `192.168.4.0/24`

**List: Plex Server**
- Type: IPv4 Address/Subnet
- Addresses:
  - `192.168.3.21`

### 5.2 Create Port Network Lists

In **UDM-SE** (Network application): Settings → Profiles → Network Lists → Create New

**List: Media Services Ports**
- Ports:
  - `8989` (Sonarr)
  - `7878` (Radarr)
  - `8686` (Lidarr)
  - `6767` (Bazarr)

> [!NOTE]
> Plex (32400) is not included because it runs on Mini PC, not NAS. qBittorrent (8080) and NZBGet (6789) are not included because Media VLAN devices (TVs, phones) don't need direct access. *arr services communicate with download clients internally via Docker network, not through firewall.

**List: Infrastructure Ports**
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

In **UDM-SE** (Network application): Settings → Firewall & Security → Firewall Rules → LAN → Create New Rule

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
| Destination | Network List: NAS Server |
| Port | Network List: Media Services Ports |

### Rule 3: Allow Media to Plex

| Field | Value |
|-------|-------|
| Type | LAN In |
| Description | Media VLAN to Plex |
| Action | Allow |
| Source | Network: Media |
| Destination | Network List: Plex Server |
| Port | 32400 |

### Rule 4: Allow IoT to Home Assistant

| Field | Value |
|-------|-------|
| Type | LAN In |
| Description | IoT to Home Assistant |
| Action | Allow |
| Source | Network: IoT |
| Destination | Network List: NAS Server |
| Port | 8123 |

### Rule 5: Block All Inter-VLAN (LAST)

| Field | Value |
|-------|-------|
| Type | LAN In |
| Description | Block All Inter-VLAN Traffic |
| Action | Drop |
| Source | Network List: RFC1918 |
| Destination | Network List: RFC1918 |

> [!WARNING]
> This rule MUST be last. It blocks all inter-VLAN traffic not explicitly allowed.

---

## Phase 7: Wi-Fi Access Point Setup

### 7.1 AP Adoption

1. [ ] Connect U6-Pro to switch port 2 (PoE+, Management VLAN 2)
2. [ ] In **UDM-SE** (Network application): Devices → should show "U6-Pro"
3. [ ] Click "Adopt"
4. [ ] Wait for provisioning (~2 minutes)
5. [ ] Update firmware if available

**Verify AP details after adoption:**

| Spec | Value |
|------|-------|
| Model | U6-Pro |
| Location | Ceiling/wall mounted (not in rack) |
| Power | PoE from USW-Pro-Max-16-PoE port 2 |
| IP | 192.168.2.20 (DHCP or fixed in Management VLAN) |

### 7.2 Radio Settings

In **UDM-SE** (Network application): Devices → U6-Pro → Settings (gear icon) → Radios

**2.4 GHz**

| Setting | Value | Reason |
|---------|-------|--------|
| Channel Width | **20 MHz** | Only 3 non-overlapping channels (1, 6, 11) at 20 MHz — wider channels cause co-channel interference |
| Channel | **Auto** | Fine for single AP; manually pick 1, 6, or 11 if you know your RF environment |
| Transmit Power | **Auto** | Appropriate for single AP |
| Minimum RSSI | **Unchecked** | Only useful with multiple APs for roaming |

**5 GHz**

| Setting | Value | Reason |
|---------|-------|--------|
| Channel Width | **80 MHz** | Sweet spot for Wi-Fi 6 throughput; 40 MHz leaves performance on the table, 160 MHz is limited by DFS channel constraints |
| Channel | **Auto** | Fine for single AP |
| Transmit Power | **Auto** | Appropriate for single AP |
| Roaming Assistant | **Unchecked** | Only useful with multiple APs |
| Minimum RSSI | **Unchecked** | Only useful with multiple APs for roaming |

> [!NOTE]
> If you add a second AP in the future, revisit Transmit Power (set to Medium/Low to reduce overlap), enable Minimum RSSI (~-75 dBm), and consider enabling Roaming Assistant to improve client handoff.

### 7.3 Create WiFi Networks (SSIDs)

In **UDM-SE** (Network application): Settings → WiFi → Create New WiFi Network

**Network 1: Homelab**

| Field | Value |
|-------|-------|
| Name/SSID | Homelab |
| Network | Media (VLAN 4) |
| Security | WPA3/WPA2 |
| Password | (set a strong password) |
| Notes | TVs, phones, tablets |

**Network 2: Homelab-Guest**

| Field | Value |
|-------|-------|
| Name/SSID | Homelab-Guest |
| Network | Guest (VLAN 5) |
| Security | WPA3/WPA2 |
| Password | (set a strong password) |
| Notes | Guests, complete isolation |

**Network 3: Homelab-IoT**

| Field | Value |
|-------|-------|
| Name/SSID | Homelab-IoT |
| Network | IoT (VLAN 6) |
| Security | WPA3/WPA2 |
| Password | (set a strong password) |
| Notes | Alexa, smart WiFi devices |

> [!NOTE]
> No SSID needed for Management or Servers — the devices on these VLANs (switch, AP, NAS, Proxmox) are all wired.
>
> **You can still manage everything from WiFi.** The UniFi controller on the UDM-SE is accessible at the gateway IP of whichever VLAN you're connected to. From "Homelab" WiFi (Media VLAN): open `https://192.168.4.1` or use the UniFi mobile app. This manages the UDM-SE, switch, and AP — no need to be on the Management VLAN itself.

### 7.4 WLAN Scheduling (Optional)

Wi-Fi radios can be scheduled to disable overnight when not needed, reducing power consumption.

In **UDM-SE** (Network application): Settings → WiFi → Select Network → Advanced → WLAN Schedule

| Day | Active Hours | Notes |
|-----|--------------|-------|
| Mon–Fri | 06:00–00:00 | Off overnight |
| Sat–Sun | 06:00–02:00 | Extended weekend |

**Guest network scheduling** (shorter window):

1. Settings → WiFi → Homelab-Guest
2. WLAN Schedule → Enable
3. Active: 08:00–23:00

> [!TIP]
> WLAN scheduling disables the radio but keeps the AP powered for management. For complete power-off options (PoE control, smart plugs), see [`energy-saving-strategies.md`](../operations/energy-saving-strategies.md#32-alternative-device-level-scheduling).

### 7.5 Verify WiFi

1. Connect a phone to each SSID
2. Verify correct VLAN assignment:
   - Homelab → should get 192.168.4.x IP
   - Homelab-Guest → should get 192.168.5.x IP
   - Homelab-IoT → should get 192.168.6.x IP
3. Verify Internet connectivity on each network

---

## Phase 8: Iliad Box Configuration

### 8.1 Access Iliad Box

1. Connect PC directly to Iliad Box (temporarily)
2. Access `http://192.168.1.254`
3. Login with Iliad credentials

### 8.2 DMZ Configuration (Optional)

> [!TIP]
> DMZ forwards all incoming traffic to UDM-SE. Useful for port forwarding managed by UniFi.

1. In **Iliad Box** web interface: Settings → NAT/Firewall → DMZ
2. Enable DMZ
3. DMZ Host IP: UDM-SE WAN IP (check in Iliad Box → Connected devices)

### 8.3 Disable Iliad Wi-Fi (Recommended)

1. In **Iliad Box** web interface: Settings → Wi-Fi
2. Disable all Wi-Fi networks
3. Wi-Fi is now managed by the UniFi AP (configured in Phase 7)

---

## Phase 9: Configuration Verification

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
                    ┌──────┴───────┐
                    │  Iliad Box   │
                    │ 192.168.1.254│
                    └──────┬───────┘
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
            ┌────────┘     │     └─────────┐
            │              │               │
     ┌──────┴──────┐ ┌─────┴──────┐ ┌──────┴──────┐
     │    QNAP     │ │  Proxmox   │ │  Other      │
     │192.168.3.10 │ │192.168.3.20│ │  Devices    │
     │  VLAN 3     │ │  VLAN 3    │ │             │
     └─────────────┘ └────────────┘ └─────────────┘
```

---

## Next Steps

After completing network setup:

1. → Proceed with [NAS QNAP Setup](nas-setup.md)
2. → Return to [START_HERE.md](../../START_HERE.md) Phase 3
