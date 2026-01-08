# VPN Guide for Download Clients

> Gluetun setup as VPN container to protect qBittorrent and NZBGet

---

## Overview

This guide explains how to configure **Gluetun** as a VPN container to route download client traffic through a secure VPN connection.

### Why Use a VPN for Download Clients?

| Risk without VPN | Protection with VPN |
|------------------|---------------------|
| ISP sees all traffic | Encrypted traffic, invisible to ISP |
| Real IP exposed (torrent: to peers) | VPN server IP visible |
| Possible DMCA letters | IP not traceable to you |
| ISP throttling | ISP cannot identify traffic type |

### Why Gluetun?

[Gluetun](https://github.com/qdm12/gluetun) is the most popular VPN container for this purpose:

- **Built-in kill switch**: if VPN drops, traffic stops automatically
- **Supports 30+ VPN providers**: NordVPN, Mullvad, Surfshark, PIA, ProtonVPN, etc.
- **Automatic port forwarding**: for some providers (ProtonVPN, PIA, AirVPN)
- **Health checks**: automatic restart if connection fails
- **Lightweight**: ~15MB RAM

---

## Prerequisites

### VPN Account

You need an account with a VPN provider supported by Gluetun.

> **Port forwarding** is important for optimal torrent speeds. It allows incoming connections from peers. If your provider doesn't support it (e.g., Mullvad), torrents will still work but may be slower.

### VPN Credentials

Retrieve credentials from your provider. See the [Provider-Specific Configurations](#provider-specific-configurations) section for detailed instructions for each provider.

---

## Quick Start

VPN is **already configured** in compose files via Docker Compose profiles. You just need to:

1. **Configure VPN credentials** in `docker/.env.secrets`
2. **Enable VPN profile** in `docker/.env`
3. **Start the stack** with `make up`

---

## Configuration

### Step 1: Enable VPN Profile

In `docker/.env`, set:

```bash
COMPOSE_PROFILES=vpn
```

> **Alternative without VPN**: use `COMPOSE_PROFILES=novpn` to start download clients without VPN protection.

### Step 2: Configure VPN Credentials

Add your provider credentials to `docker/.env.secrets`:

```bash
# -----------------------------------------------------------------------------
# VPN (Gluetun) - REQUIRED when using COMPOSE_PROFILES=vpn
# -----------------------------------------------------------------------------
# Docs: https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers

# VPN Provider (required)
VPN_SERVICE_PROVIDER=nordvpn

# Connection type: openvpn or wireguard
VPN_TYPE=openvpn

# Server location
SERVER_COUNTRIES=Switzerland

# --- OpenVPN (NordVPN, PIA, Surfshark) ---
OPENVPN_USER=your_service_username
OPENVPN_PASSWORD=your_service_password

# --- WireGuard (Mullvad, ProtonVPN) - leave empty for OpenVPN ---
# WIREGUARD_PRIVATE_KEY=your_private_key_here
# WIREGUARD_ADDRESSES=10.x.x.x/32

# --- Port Forwarding (ProtonVPN, PIA, AirVPN only) ---
# VPN_PORT_FORWARDING=on
```

### Step 3: Start the Stack

```bash
# Create folders (first time only)
make setup

# Start all services
make up

# Verify VPN is working
docker exec gluetun curl -s https://ipinfo.io/ip
# Should show VPN IP, NOT your real IP
```

### Step 4: Configure Hostname in *arr Apps (IMPORTANT!)

With the `vpn` profile, qBittorrent and NZBGet are reachable via hostname `gluetun`:

**In Sonarr/Radarr/Lidarr → Settings → Download Clients:**

| Download Client | Host | Port |
|-----------------|------|------|
| qBittorrent | `gluetun` | `8080` |
| NZBGet | `gluetun` | `6789` |

> **Why?** Containers with `network_mode: "service:gluetun"` share the network stack with Gluetun. So qBittorrent and NZBGet are reachable at Gluetun's address.

---

## Available Profiles

| Profile | Command | Download Clients Host |
|---------|---------|----------------------|
| `vpn` | `COMPOSE_PROFILES=vpn make up` | `gluetun:8080` / `gluetun:6789` |
| `novpn` | `COMPOSE_PROFILES=novpn make up` | `qbittorrent:8080` / `nzbget:6789` |

**When changing profiles**, remember to update hostnames in *arr apps!

---

## Provider-Specific Configurations

### NordVPN (OpenVPN)

```bash
# .env.secrets
VPN_SERVICE_PROVIDER=nordvpn
VPN_TYPE=openvpn
OPENVPN_USER=<your_service_username>
OPENVPN_PASSWORD=<your_service_password>
SERVER_COUNTRIES=Switzerland
```

To get credentials:
1. Log in to https://my.nordaccount.com/
2. Go to **NordVPN** → **Manual configuration**
3. Verify your identity (email)
4. Copy **Service username** and **Service password** (NOT your login credentials!)

> **Important**: NordVPN requires "Service credentials", not account username/password. Find them in the panel under "Manual setup".

### ProtonVPN (WireGuard with Port Forwarding)

```bash
# .env.secrets
VPN_SERVICE_PROVIDER=protonvpn
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=<your_private_key>
WIREGUARD_ADDRESSES=10.x.x.x/32
SERVER_COUNTRIES=Switzerland
VPN_PORT_FORWARDING=on
```

To get credentials:
1. Go to https://account.protonvpn.com/downloads
2. Generate WireGuard configuration (requires Plus plan or higher)
3. Copy `PrivateKey` and `Address`

> **Note**: ProtonVPN port forwarding requires Plus plan or higher.

### Private Internet Access (OpenVPN with Port Forwarding)

```bash
# .env.secrets
VPN_SERVICE_PROVIDER=private internet access
VPN_TYPE=openvpn
OPENVPN_USER=<your_username>
OPENVPN_PASSWORD=<your_password>
SERVER_REGIONS=Switzerland
VPN_PORT_FORWARDING=on
```

> **Note**: PIA uses `SERVER_REGIONS` instead of `SERVER_COUNTRIES`.

### Mullvad (WireGuard)

```bash
# .env.secrets
VPN_SERVICE_PROVIDER=mullvad
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=<your_private_key>
WIREGUARD_ADDRESSES=10.x.x.x/32
SERVER_COUNTRIES=Switzerland
```

To get credentials:
1. Go to https://mullvad.net/account
2. Download a WireGuard configuration
3. Open the `.conf` file and copy `PrivateKey` and `Address`

> **Note**: Mullvad no longer supports port forwarding since 2023.

### PrivadoVPN (OpenVPN with Port Forwarding)

```bash
# .env.secrets
VPN_SERVICE_PROVIDER=privado
VPN_TYPE=openvpn
OPENVPN_USER=<your_username>
OPENVPN_PASSWORD=<your_password>
SERVER_COUNTRIES=Switzerland
VPN_PORT_FORWARDING=on
```

To get credentials:
1. Log in to https://privadovpn.com/control-panel/
2. Go to **Account** → **OpenVPN/IKEv2 Username**
3. Copy your **Username** and **Password**

> **Note**: PrivadoVPN supports port forwarding, which improves torrent speeds.

---

## Verify Functionality

### 1. Startup and VPN Connection Verification

```bash
# Start the stack
make up

# Check Gluetun logs
docker logs gluetun | grep -i "connected\|healthy"

# Expected output:
# INFO [vpn] connected to server...
# INFO [healthcheck] healthy!
```

### 2. Verify Public IP

```bash
# Host IP (without VPN)
curl -s https://ipinfo.io/ip
# Output: <your_real_IP>

# Download clients IP (through VPN)
docker exec gluetun curl -s https://ipinfo.io/ip
# Output: <VPN_server_IP>  ← Must be DIFFERENT from your real IP!
```

Both qBittorrent and NZBGet use this same VPN IP for all connections.

### 3. Verify Kill Switch

```bash
# Simulate VPN disconnection (stop the tunnel)
docker exec gluetun killall -STOP openvpn 2>/dev/null || docker exec gluetun killall -STOP wireguard-go 2>/dev/null

# Try to reach internet
docker exec gluetun curl -s --max-time 5 https://ipinfo.io/ip
# Output: (timeout or error) ← Kill switch works!

# Restart to restore
docker restart gluetun
```

> **Note**: The kill switch is managed by iptables in Gluetun. If VPN connection drops, all traffic is automatically blocked.

### 4. Verify qBittorrent Port

If provider supports port forwarding:

```bash
# Check assigned port
docker exec gluetun cat /gluetun/forwarded_port
# Output: 12345 (example)
```

Configure this port in qBittorrent:
1. Options → Connection → Listening Port
2. Enter the port shown above
3. Save

Verify with an online port checker or:
```bash
# From outside local network
nc -zv <VPN_IP> <forwarded_port>
```

---

## Troubleshooting

| Problem | Probable Cause | Solution |
|---------|----------------|----------|
| Gluetun won't connect | Wrong credentials | Check `.env.secrets`, regenerate credentials |
| `AUTH_FAILED` | Wrong username/password | For Mullvad: use private key, not account number |
| qBittorrent/NZBGet not reachable | Ports not exposed on gluetun | Check gluetun `ports` section |
| Slow speeds | VPN server too far | Change `SERVER_COUNTRIES` |
| Torrents "stalled" | No port forwarding | Check provider support or change provider |
| Container in restart loop | `/dev/net/tun` not available | Verify tun module is loaded on NAS |
| *arr can't reach download clients | Wrong network_mode | Verify qbit/nzbget use `network_mode: "service:gluetun"` |

### Verify TUN Module

```bash
# On NAS via SSH
lsmod | grep tun

# If not present, load it
insmod /lib/modules/$(uname -r)/tun.ko
# Or
modprobe tun
```

On QNAP, you may need to enable the module permanently. Check Container Station documentation.

### Useful Logs

```bash
# Full Gluetun logs
docker logs -f gluetun

# Errors only
docker logs gluetun 2>&1 | grep -i error

# Connection status
docker exec gluetun wget -qO- https://ipinfo.io
```

---

## References

- [Gluetun Wiki](https://github.com/qdm12/gluetun-wiki)
- [Supported Provider List](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)
- [Trash Guides - VPN Setup](https://trash-guides.info/Downloaders/qBittorrent/VPN/)
- [LinuxServer qBittorrent](https://docs.linuxserver.io/images/docker-qbittorrent/)
- [LinuxServer NZBGet](https://docs.linuxserver.io/images/docker-nzbget/)
