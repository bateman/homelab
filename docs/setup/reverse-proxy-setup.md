# Reverse Proxy Setup - Traefik with Pi-hole DNS

> Guide to configure Traefik as reverse proxy and Pi-hole as DNS for Tailscale

---

## Overview

A reverse proxy allows accessing services using readable names (e.g., `sonarr.home.local`) instead of IP:port. This guide documents:

- **Traefik** as primary solution (Docker auto-discovery)
- **Nginx Proxy Manager** as alternative (WebUI configuration)
- **Pi-hole + Tailscale** to resolve same URLs from local and remote

---

## Solution Comparison

| Aspect | Traefik | Nginx Proxy Manager |
|--------|---------|---------------------|
| **Configuration** | Docker labels + YAML | WebUI point-and-click |
| **Learning curve** | Medium | Low |
| **Docker auto-discovery** | Native | No (manual) |
| **SSL certificates** | Automatic Let's Encrypt | Let's Encrypt via UI |
| **Dashboard** | Advanced | Simple |
| **Resources** | ~30MB RAM | ~50MB RAM |
| **Adding new service** | Add labels to container | Click in WebUI |
| **Ideal for** | Existing Docker stack | Mixed/non-Docker services |

**Recommendation**: With Docker stack already configured on NAS, **Traefik** integrates better thanks to auto-discovery.

---

## Prerequisites

- [ ] Docker stack running on NAS (192.168.3.10)
- [ ] Pi-hole configured and active
- [ ] Tailscale installed on Proxmox (see [proxmox-setup.md](proxmox-setup.md))

---

## Phase 1: Pi-hole Configuration as Tailscale DNS

> [!TIP]
> This configuration allows using the same URLs (e.g., `sonarr.home.local`) both from local network and remotely via Tailscale.

### 1.1 How It Works

```
                    +-------------+
                    |   Pi-hole   |
                    |192.168.3.10 |
                    +------+------+
                           |
         +-----------------+------------------+
         |                 |                  |
    +----v----+      +-----v-----+     +------v------+
    |   LAN   |      | Tailscale |     |  Tailscale  |
    | Client  |      |  (home)   |     |  (remote)   |
    +---------+      +-----------+     +-------------+
         |                 |                  |
         |    DNS query: sonarr.home.local    |
         |                 |                  |
         +-----------------+------------------+
                           v
                   All receive:
                    192.168.3.10
```

### 1.2 Configure Tailscale to use Pi-hole

1. Access https://login.tailscale.com/admin/dns
2. In **Nameservers** → Add nameserver → Custom
3. Enter: `192.168.3.10` (NAS IP with Pi-hole)
4. Enable **Override local DNS**

> [!NOTE]
> Make sure subnet routes are approved (see Phase 6 in proxmox-setup.md)

### 1.3 Add DNS Records in Pi-hole

Access Pi-hole: `http://192.168.3.10:8081`

**Local DNS → DNS Records**, add:

| Domain | IP |
|--------|-----|
| `auth.home.local` | 192.168.3.10 |
| `traefik.home.local` | 192.168.3.10 |
| `sonarr.home.local` | 192.168.3.10 |
| `radarr.home.local` | 192.168.3.10 |
| `lidarr.home.local` | 192.168.3.10 |
| `prowlarr.home.local` | 192.168.3.10 |
| `bazarr.home.local` | 192.168.3.10 |
| `qbit.home.local` | 192.168.3.10 |
| `nzbget.home.local` | 192.168.3.10 |
| `pihole.home.local` | 192.168.3.10 |
| `ha.home.local` | 192.168.3.10 |
| `portainer.home.local` | 192.168.3.10 |
| `duplicati.home.local` | 192.168.3.10 |
| `uptime.home.local` | 192.168.3.10 |
| `plex.home.local` | 192.168.3.21 |

### 1.4 Verification

```bash
# From LAN client
nslookup sonarr.home.local
# Should return 192.168.3.10

# From remote device via Tailscale
tailscale ping 192.168.3.10
nslookup sonarr.home.local
# Should return 192.168.3.10 (DNS via tunnel)
```

### Benefits of This Configuration

- **Zero costs**: no domain to purchase
- **Same URL everywhere**: `sonarr.home.local` works on LAN and via Tailscale
- **Ad-blocking also remotely**: Pi-hole filters Tailscale traffic too
- **No port forwarding**: Tailscale handles remote access

---

## Phase 2: Traefik Installation (Primary Solution)

### 2.1 Configuration Already Included

Traefik is already configured in `docker/compose.yml` with:
- **HTTPS enabled** with self-signed certificate for `*.home.local`
- Automatic HTTP → HTTPS redirect
- Dashboard accessible via reverse proxy at `traefik.home.local`
- Docker auto-discovery on `homelab_proxy` network
- File provider for non-Docker services (Home Assistant)
- Traefik labels already added to all services

**Dashboard Access**: https://traefik.home.local (requires Pi-hole DNS configured)

### 2.2 Services Already Configured

Traefik labels are already added to all services in compose files:

| Service | Traefik URL (HTTPS) | Direct Port (HTTP) |
|---------|---------------------|-------------------|
| Authelia | https://auth.home.local | :9091 |
| Sonarr | https://sonarr.home.local | :8989 |
| Radarr | https://radarr.home.local | :7878 |
| Lidarr | https://lidarr.home.local | :8686 |
| Prowlarr | https://prowlarr.home.local | :9696 |
| Bazarr | https://bazarr.home.local | :6767 |
| qBittorrent | https://qbit.home.local | :8080 |
| NZBGet | https://nzbget.home.local | :6789 |
| Huntarr | https://huntarr.home.local | :9705 |
| Cleanuparr | https://cleanuparr.home.local | :11011 |
| Pi-hole | https://pihole.home.local | :8081 |
| Portainer | https://portainer.home.local | :9443 (HTTPS) |
| Duplicati | https://duplicati.home.local | :8200 |
| Uptime Kuma | https://uptime.home.local | :3001 |
| Home Assistant | https://ha.home.local | :8123 |
| Traefik Dashboard | https://traefik.home.local | (via reverse proxy) |

### 2.3 Home Assistant Configuration

Home Assistant uses `network_mode: host`, so it cannot use Docker labels.
Configuration is already present in `docker/config/traefik/homeassistant.yml`.

### 2.4 HTTPS Certificate Generation

Before starting the stack, generate self-signed certificates:

```bash
# Generate wildcard certificate for *.home.local
./scripts/generate-certs.sh

# Certificates are created in:
# - docker/config/traefik/certs/home.local.crt
# - docker/config/traefik/certs/home.local.key
```

Certificate is valid for 10 years and covers:
- `*.home.local` (all subdomains)
- `home.local` (base domain)

### 2.5 Startup and Verification

```bash
# Create folder structure (includes traefik)
make setup

# Generate HTTPS certificates
./scripts/generate-certs.sh

# Start stack
make up

# Verify Traefik
docker logs traefik

# Access dashboard (requires Pi-hole DNS configured)
# https://traefik.home.local
```

### 2.6 Test Access via Name

```bash
# From browser or curl (-k ignores self-signed certificate)
curl -k https://sonarr.home.local
curl -k https://radarr.home.local
curl -k https://pihole.home.local
```

> [!NOTE]
> Browser will show warning on first access because certificate is self-signed. This is normal and safe for internal use. Accept certificate once and warning won't appear again.

---

## Alternative: Nginx Proxy Manager

> [!TIP]
> Use NPM if you prefer configuring via graphical interface or have non-Docker services.

### Installation on Proxmox (LXC Container)

```bash
# Create LXC container (ID 101)
# Install Docker
apt update && apt install docker.io docker-compose -y

# Create directory
mkdir -p /opt/npm && cd /opt/npm

# docker-compose.yml for NPM
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF

docker-compose up -d
```

### Access and Configuration

1. Access: `http://192.168.3.22:81`
2. Default login: `admin@example.com` / `changeme`
3. Change password on first access

### Add Proxy Host

For each service:

1. **Hosts → Proxy Hosts → Add Proxy Host**
2. **Domain Names**: `sonarr.home.local`
3. **Scheme**: `http`
4. **Forward Hostname/IP**: `192.168.3.10`
5. **Forward Port**: `8989`
6. **Block Common Exploits**: enabled
7. **Websockets Support**: enabled (for Home Assistant)

### When to Prefer NPM

- Visual configuration without modifying YAML files
- Non-Docker services (e.g., Proxmox WebUI, network devices)
- SSL with Let's Encrypt via guided interface
- Users less experienced with Docker

---

## Phase 3: Accept Self-Signed Certificate

HTTPS is enabled by default with self-signed certificates. Traffic is encrypted, but browsers will show a warning because certificate is not issued by a public CA.

### 3.1 Accept in Browser (Simple Method)

On first access to each service:

1. Browser shows "Connection is not private" (or similar)
2. Click **Advanced** → **Proceed anyway**
3. Certificate is remembered and warning won't appear again

### 3.2 Import Certificate (Permanent Method)

To eliminate warning on all services, import certificate as trusted.

**Export certificate from NAS:**
```bash
# Certificate is in:
# docker/config/traefik/certs/home.local.crt
```

**Windows:**
1. Copy `home.local.crt` to PC
2. Double-click → **Install certificate**
3. Select **Local Machine** → **Next**
4. **Place all certificates in the following store** → **Browse**
5. Select **Trusted Root Certification Authorities**
6. **Finish** → Restart browser

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain home.local.crt
```

**Linux (Chrome/Chromium):**
```bash
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "Homelab" -i home.local.crt
```

**Firefox (all systems):**
1. Settings → Privacy & Security → Certificates → View Certificates
2. **Authorities** tab → **Import**
3. Select `home.local.crt`
4. Select **Trust this CA to identify websites**

### 3.3 Regenerate Certificates

If certificates expire or you want to regenerate:

```bash
./scripts/generate-certs.sh
# Answer 'y' to overwrite
make restart
```

---

## Access Summary

### With Traefik Configured (HTTPS)

| Service | URL (HTTPS) | Direct Port (HTTP, backup) |
|---------|-------------|---------------------------|
| Authelia (SSO) | https://auth.home.local | :9091 |
| Traefik Dashboard | https://traefik.home.local | (via reverse proxy) |
| Sonarr | https://sonarr.home.local | :8989 |
| Radarr | https://radarr.home.local | :7878 |
| Lidarr | https://lidarr.home.local | :8686 |
| Prowlarr | https://prowlarr.home.local | :9696 |
| Bazarr | https://bazarr.home.local | :6767 |
| qBittorrent | https://qbit.home.local | :8080 |
| NZBGet | https://nzbget.home.local | :6789 |
| Huntarr | https://huntarr.home.local | :9705 |
| Cleanuparr | https://cleanuparr.home.local | :11011 |
| Pi-hole | https://pihole.home.local | :8081 |
| Home Assistant | https://ha.home.local | :8123 |
| Portainer | https://portainer.home.local | :9443 (HTTPS) |
| Duplicati | https://duplicati.home.local | :8200 |
| Uptime Kuma | https://uptime.home.local | :3001 |
| Plex | https://plex.home.local | :32400 (on 192.168.3.21) |

> [!NOTE]
> URLs work both from local network and remotely via Tailscale (thanks to Pi-hole as DNS).
> HTTP (port 80) is automatically redirected to HTTPS (port 443).

> [!IMPORTANT]
> All services are protected by Authelia SSO. You must authenticate once at https://auth.home.local to access any service.
> See [Authelia Setup](authelia-setup.md) for configuration details.

---

## Troubleshooting

### DNS not resolving

```bash
# Verify Pi-hole is reachable
ping 192.168.3.10

# Verify DNS records in Pi-hole
# WebUI → Local DNS → DNS Records

# Force use of Pi-hole as DNS
# Linux: /etc/resolv.conf → nameserver 192.168.3.10
# Windows: Network settings → DNS: 192.168.3.10
```

### Traefik not finding containers

```bash
# Verify proxy network
docker network ls | grep proxy

# Verify containers are on proxy network
docker network inspect proxy

# Verify labels
docker inspect sonarr | grep -A 20 Labels
```

### 502 Bad Gateway

```bash
# Verify backend service is running
docker ps | grep sonarr
curl http://192.168.3.10:8989

# Check Traefik logs
docker logs traefik --tail 50
```

### Remote access not working

```bash
# Verify Tailscale
tailscale status

# Verify Tailscale DNS
# https://login.tailscale.com/admin/dns
# Should show 192.168.3.10 as nameserver

# Verify subnet routes approved
# https://login.tailscale.com/admin/machines
```

---

## Notes

- **Direct ports**: Remain accessible as backup if Traefik has issues
- **Home Assistant**: Requires separate file configuration (network_mode: host)
- **Plex**: If on Proxmox, add DNS record pointing to 192.168.3.20
- **Updates**: Watchtower automatically updates Traefik
