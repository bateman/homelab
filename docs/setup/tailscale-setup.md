# Tailscale Setup — Mesh VPN Remote Access

> Guide to configure Tailscale as a Docker container on the NAS for secure remote access without port forwarding.

---

## Overview

Tailscale runs as a **subnet router** on the QNAP NAS (`192.168.3.10`), advertising the homelab subnets to the Tailscale mesh network. This allows remote devices to access all homelab services (Sonarr, Radarr, Plex, etc.) as if they were on the local network — without opening any ports on the router.

### Why on the NAS?

The NAS is always-on, so remote access remains available even when the Mini PC (Proxmox) is powered off. This also enables Wake-on-LAN of the Mini PC from remote via SSH through Tailscale.

### Architecture

```
                   Internet
                      |
              +-------+-------+
              |   Tailscale   |
              | Coordination  |
              +-------+-------+
                      |
         NAT traversal (no port forwarding)
                      |
    +-----------------+------------------+
    |                                    |
+---v-----------+              +---------v-------+
| NAS (Docker)  |              | Remote Device   |
| nas-tailscale |              | (phone/laptop)  |
| Subnet Router |              | Tailscale client|
| 192.168.3.0/24|              |                 |
| 192.168.4.0/24|              |                 |
+---------------+              +-----------------+
```

---

## Prerequisites

- [ ] QNAP NAS with Docker working
- [ ] Tailscale account created at [tailscale.com](https://tailscale.com)
- [ ] Files `docker/.env` and `docker/.env.secrets` created from examples (see `docker/.env.example` and `docker/.env.secrets.example`)

---

## Phase 1: Generate Auth Key

1. Go to [Tailscale Admin Console — Keys](https://login.tailscale.com/admin/settings/keys)
2. Click **Generate auth key**
3. Configure the key:

| Setting | Value | Reason |
|---------|-------|--------|
| **Reusable** | Yes | Container can restart without re-authenticating |
| **Ephemeral** | No | Device stays visible in Admin Console after restarts |
| **Tags** | `tag:server` (optional) | For ACL policy targeting |
| **Expiration** | 90 days (default) | After first auth, state is persisted and the key is no longer needed |

4. Copy the generated key (format: `tskey-auth-xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`)

> [!IMPORTANT]
> The key is only visible at creation time. Save it immediately.

---

## Phase 2: Configure Environment Variables

### 2.1 Secrets (`.env.secrets`)

Add the auth key to `docker/.env.secrets`:

```bash
# Tailscale - Remote Access (Mesh VPN)
TS_AUTHKEY=tskey-auth-xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

> After first successful authentication, state is persisted in `docker/config/tailscale/` and `TS_AUTHKEY` is no longer needed. You can remove it from `.env.secrets` or leave it (it will be ignored).

### 2.2 Configuration (`.env`)

Default values in `docker/.env`:

```bash
# Subnet routes to advertise (comma-separated CIDR ranges)
TS_ROUTES=192.168.3.0/24,192.168.4.0/24
```

| Variable | Default | Description |
|----------|---------|-------------|
| `TS_ROUTES` | `192.168.3.0/24,192.168.4.0/24` | Subnets to make reachable via Tailscale. `192.168.3.0/24` = Server VLAN, `192.168.4.0/24` = IoT VLAN |

> [!TIP]
> If you only have the Server VLAN (192.168.3.0/24), you can remove the IoT subnet from `TS_ROUTES`.

---

## Phase 3: Start and Verify

### 3.1 Start the Stack

```bash
make up
```

Tailscale starts, authenticates with the key, and registers the device as `nas-tailscale` in the Tailscale network.

### 3.2 Approve Subnet Routes

On first start, subnet routes must be approved manually:

1. Go to [Tailscale Admin Console — Machines](https://login.tailscale.com/admin/machines)
2. Find the machine **nas-tailscale**
3. Click the three dots (**...**) → **Edit route settings**
4. Enable the advertised subnets:
   - `192.168.3.0/24` (Server VLAN)
   - `192.168.4.0/24` (IoT VLAN)
5. Click **Save**

> [!IMPORTANT]
> Without this step, remote devices cannot reach the local subnets.

### 3.3 Verify Connection

```bash
# Check that Tailscale is connected
docker exec tailscale tailscale status

# Show the Tailscale IP assigned to the NAS
docker exec tailscale tailscale ip -4

# Verify advertised subnet routes (look for AdvertiseRoutes)
docker exec tailscale tailscale debug prefs | grep AdvertiseRoutes
```

Expected output of `tailscale status`:

```
100.x.x.x   nas-tailscale        user@     linux   -
```

### 3.4 Test from Remote Device

On a remote device (with Tailscale installed and connected):

```bash
# Ping the NAS via local IP (routed through the tunnel)
tailscale ping 192.168.3.10

# Verify access to services
curl -s http://192.168.3.10:8989/ping   # Sonarr
curl -s http://192.168.3.10:3001        # Uptime Kuma
```

---

## Phase 4: Pi-hole as Tailscale DNS (Optional but Recommended)

By configuring Pi-hole as Tailscale's DNS, you can use the same `*.home.local` URLs both from LAN and remotely.

For full instructions, see: [Reverse Proxy Setup — Phase 1: Pi-hole Configuration as Tailscale DNS](reverse-proxy-setup.md#phase-1-pi-hole-configuration-as-tailscale-dns)

In short:

1. [Tailscale Admin Console — DNS](https://login.tailscale.com/admin/dns)
2. **Nameservers** → Add nameserver → Custom → `192.168.3.10`
3. Enable **Override local DNS**

Result: `sonarr.home.local`, `radarr.home.local`, etc. also work remotely.

---

## Docker Compose Reference

The Tailscale service in `docker/compose.yml`:

```yaml
tailscale:
  image: tailscale/tailscale:latest
  container_name: tailscale
  hostname: nas-tailscale
  env_file:
    - .env.secrets
  environment:
    TS_STATE_DIR: /var/lib/tailscale
    TS_ROUTES: ${TS_ROUTES:-192.168.3.0/24,192.168.4.0/24}
    TS_USERSPACE: "false"
  volumes:
    - ./config/tailscale:/var/lib/tailscale
  cap_add:
    - NET_ADMIN
    - NET_RAW
  devices:
    - /dev/net/tun:/dev/net/tun
  network_mode: host
  restart: unless-stopped
```

Key configuration notes:

| Setting | Required | Reason |
|---------|----------|--------|
| `env_file: .env.secrets` | Yes | Loads `TS_AUTHKEY` from the secrets file |
| `network_mode: host` | Yes | Subnet router needs direct access to the host network |
| `cap_add: NET_ADMIN, NET_RAW` | Yes | Required to create the tunnel interface and manage routing |
| `/dev/net/tun` | Yes | TUN device for the VPN tunnel |
| `TS_USERSPACE: "false"` | Recommended | Uses kernel networking (better performance) instead of userspace |
| `TS_STATE_DIR` + volume | Yes | Auth state survives container restarts |

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| `tailscale status` shows "Logged out" | Auth key expired or invalid | Generate a new key and restart: `docker restart tailscale` |
| Subnet routes not reachable | Routes not approved in Admin Console | Approve in [Machines](https://login.tailscale.com/admin/machines) → nas-tailscale → Edit route settings |
| `tailscale ping` fails from remote | Tailscale not installed/connected on remote device | Install Tailscale and log in |
| DNS `*.home.local` doesn't work remotely | Pi-hole not configured as Tailscale DNS | See [Phase 4](#phase-4-pi-hole-as-tailscale-dns-optional-but-recommended) |
| Container won't start: "permission denied" | Missing capabilities or TUN device | Verify `cap_add` and `devices` in `compose.yml` |
| Tailscale IP changes after restart | Ephemeral key or state not persisted | Use non-ephemeral key; verify `./config/tailscale` volume |

---

## Useful Commands

```bash
# Connection status
docker exec tailscale tailscale status

# NAS Tailscale IP
docker exec tailscale tailscale ip -4

# Ping another Tailscale node
docker exec tailscale tailscale ping <hostname-or-ip>

# Container logs
docker logs tailscale --tail 50

# Force re-authentication (if needed)
docker exec tailscale tailscale logout
# Then update TS_AUTHKEY in .env.secrets and restart
docker restart tailscale
```

---

## Related Documentation

| Topic | File |
|-------|------|
| Pi-hole DNS for Tailscale | [reverse-proxy-setup.md — Phase 1](reverse-proxy-setup.md#phase-1-pi-hole-configuration-as-tailscale-dns) |
| Firewall and subnet routing | [firewall-config.md](../network/firewall-config.md) |
| Remote WOL via Tailscale | [proxmox-setup.md — Section 8.2.7](proxmox-setup.md#827-wol-via-tailscale-remote) |
| Monitoring (Uptime Kuma) | [uptime-kuma-monitors.md](../operations/uptime-kuma-monitors.md) |
| Compose service definition | [docker/compose.yml](../../docker/compose.yml) |
