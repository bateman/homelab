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
- [ ] Tailscale running as Docker container on NAS (see [Tailscale Setup](tailscale-setup.md))

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
> Make sure subnet routes are approved (see [Tailscale Setup — Phase 3.2](tailscale-setup.md#32-approve-subnet-routes))

### 1.3 Add DNS Records in Pi-hole

Access Pi-hole: `http://192.168.3.10:8081`

**Settings → Local DNS Records**, add:

| Domain | IP |
|--------|-----|
| `auth.home.local` | 192.168.3.10 |
| `traefik.home.local` | 192.168.3.10 |
| `sonarr.home.local` | 192.168.3.10 |
| `radarr.home.local` | 192.168.3.10 |
| `lidarr.home.local` | 192.168.3.10 |
| `prowlarr.home.local` | 192.168.3.10 |
| `bazarr.home.local` | 192.168.3.10 |
| `cleanuparr.home.local` | 192.168.3.10 |
| `certs.home.local` | 192.168.3.10 |
| `qbit.home.local` | 192.168.3.10 |
| `nzbget.home.local` | 192.168.3.10 |
| `pihole.home.local` | 192.168.3.10 |
| `ha.home.local` | 192.168.3.10 |
| `portainer.home.local` | 192.168.3.10 |
| `duplicati.home.local` | 192.168.3.10 |
| `uptime.home.local` | 192.168.3.10 |
| `plex.home.local` | 192.168.3.10 |

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
- **HTTPS enabled** with certificate signed by a private Root CA for `*.home.local`
- Automatic HTTP → HTTPS redirect
- Dashboard accessible via reverse proxy at `traefik.home.local`
- Docker auto-discovery on `homelab_proxy` network
- File provider for non-Docker services (Home Assistant, Plex)
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
| Cleanuparr | https://cleanuparr.home.local | :11011 |
| Cert Page | https://certs.home.local | (via reverse proxy) |
| Pi-hole | https://pihole.home.local | :8081 |
| Portainer | https://portainer.home.local | :9443 (HTTPS) |
| Duplicati | https://duplicati.home.local | :8200 |
| Uptime Kuma | https://uptime.home.local | :3001 |
| Home Assistant | https://ha.home.local | :8123 |
| Plex | https://plex.home.local | :32400 (on 192.168.3.21) |
| Traefik Dashboard | https://traefik.home.local | (via reverse proxy) |

### 2.3 Home Assistant Configuration

Home Assistant uses `network_mode: host`, so it cannot use Docker labels.
Configuration is already present in `docker/config/traefik/homeassistant.yml`.

### 2.4 Plex Configuration

Plex runs as an LXC container on Proxmox (`192.168.3.21`), not in Docker.
Configuration is already present in `docker/config/traefik/plex.yml`.

> [!NOTE]
> Plex is **not** protected by Authelia — it has its own authentication (Plex account) and client apps (iOS, Android, Smart TV) need direct API access.

### 2.5 HTTPS Certificate Generation

Before starting the stack, generate the Root CA and server certificates. `make setup` runs this automatically, but you can also run it manually:

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

### 2.6 Startup and Verification

```bash
# Create folder structure, secrets, and certificates
make setup

# Start stack
make up

# Verify Traefik
docker logs traefik

# Access dashboard (requires Pi-hole DNS configured)
# https://traefik.home.local
```

### 2.7 Test Access via Name

```bash
# From browser or curl (-k ignores untrusted certificate)
curl -k https://sonarr.home.local
curl -k https://radarr.home.local
curl -k https://pihole.home.local
```

> [!NOTE]
> Browser will show a warning on first access because the Root CA is not publicly trusted. This is normal for internal use. Install the CA certificate (see [Phase 3](#phase-3-trust-the-homelab-ca-certificate)) to permanently remove the warning on all devices.

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

## Phase 3: Trust the Homelab CA Certificate

HTTPS is enabled by default using a private Root CA that signs the `*.home.local` wildcard certificate. Traffic is encrypted, but browsers show a warning until you install the CA certificate on your device. **This is a one-time setup per device** — once the CA is trusted, all current and future `*.home.local` services work without warnings.

### 3.1 Install via Download Page (Recommended)

A certificate download page is available at **https://certs.home.local** with per-platform instructions and one-click downloads.

> [!NOTE]
> The first visit to `https://certs.home.local` will show a certificate warning — this is expected. Click through it once, install the CA, and all warnings disappear permanently.

### 3.2 iPhone / iPad (via .mobileconfig profile)

1. Open **Safari** and go to `https://certs.home.local`
2. Tap **Install Profile** — a prompt says "Profile Downloaded"
3. Open **Settings** → **General** → **Profiles**
4. Tap the downloaded profile → **Install** → enter passcode
5. Go to **Settings** → **General** → **About** → **Certificate Trust Settings**
6. Enable **Full Trust** for **Homelab Root CA**

### 3.3 macOS

Using the .mobileconfig profile (same as iOS), or manually:
```bash
sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain docker/config/traefik/certs/ca.crt
```

### 3.4 Windows

1. Download `ca.crt` from `https://certs.home.local`
2. Double-click → **Install Certificate**
3. Select **Local Machine** → **Next**
4. **Place all certificates in the following store** → **Browse**
5. Select **Trusted Root Certification Authorities**
6. **Finish** → Restart browser

### 3.5 Linux (Chrome/Chromium)

```bash
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "Homelab Root CA" -i ca.crt
```

### 3.6 Firefox (all systems)

1. Settings → Privacy & Security → Certificates → View Certificates
2. **Authorities** tab → **Import**
3. Select `ca.crt` → check **Trust this CA to identify websites**

### 3.7 Regenerate Certificates

The server certificate can be regenerated without re-importing on any device (the CA stays the same):

```bash
./scripts/generate-certs.sh
make restart s=traefik
```

To regenerate the CA itself (all devices must re-trust):

```bash
./scripts/generate-certs.sh --force-ca
make restart s=traefik
# Then re-install the new CA on all devices
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
| Cleanuparr | https://cleanuparr.home.local | :11011 |
| Cert Page | https://certs.home.local | (via reverse proxy) |
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
> All services accessed **via Traefik** (i.e., `https://<service>.home.local`) are protected by Authelia SSO — you authenticate once and access everything. **Exceptions:** `certs.home.local` has no Authelia middleware so devices can download the CA cert before authenticating. `plex.home.local` has no Authelia middleware because Plex has its own authentication and client apps need direct API access. Direct IP:port access (e.g., `http://192.168.3.10:8989`) bypasses Traefik and Authelia entirely.
> See [Authelia Setup](authelia-setup.md) for configuration details.

---

## Troubleshooting

### Certificate errors: "failed to find any PEM data"

If Traefik logs show:

```
ERR Unable to append certificate ... "tls: failed to find any PEM data in certificate input"
```

**Cause**: The TLS certificate files are missing or corrupt (empty). This happens when `make setup` was not run, or a previous run failed partway through leaving empty cert files.

**Fix**: Re-run setup — it validates certificate PEM content with `openssl x509` and automatically regenerates corrupt or missing certificates:

```bash
make setup
make down && make up
```

### Middleware errors: "authelia@docker does not exist"

If Traefik logs show:

```
ERR error="middleware \"authelia@docker\" does not exist"
```

**Cause**: Traefik started before Authelia was ready. `compose.yml` uses `depends_on` with `condition: service_healthy` so Traefik waits for Authelia to pass its healthcheck before starting.

**Fix**: Restart the stack:

```bash
make down && make up
```

If Traefik fails to start entirely with "dependency failed to start: container authelia is unhealthy", then Authelia's healthcheck is failing:

```bash
# Check Authelia health status
docker inspect --format='{{.State.Health.Status}}' authelia

# Test the healthcheck manually
docker exec authelia /app/healthcheck.sh

# If unhealthy, check its logs for the root cause
docker logs authelia --tail 30

# Common causes: missing secrets (run make setup), bad configuration
```

> **Note**: Authelia's healthcheck uses `/app/healthcheck.sh` (a wget-based script bundled in the image). The `authelia` CLI does not have a `healthcheck` subcommand — do not use `["CMD", "authelia", "healthcheck"]` in compose.

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

### Plex not accessible via `plex.home.local`

**Symptom: 502 Bad Gateway**

The Mini PC (Proxmox) may be powered off. It shuts down at 00:30 and wakes at ~07:02 (see [energy saving strategies](../operations/energy-saving-strategies.md)).

```bash
# Check if Plex LXC is reachable
ping -c 3 192.168.3.21

# Check Plex service
curl -s -o /dev/null -w "%{http_code}" http://192.168.3.21:32400/web
# Expected: 200

# If Mini PC is off, wake it (from NAS)
wakeonlan AA:BB:CC:DD:EE:FF  # Replace with actual MAC
```

**Symptom: DNS not resolving or connection timeout**

Verify DNS points to Traefik (`192.168.3.10`), not directly to Plex (`192.168.3.21`):

```bash
nslookup plex.home.local
# Should return 192.168.3.10 (Traefik on NAS)
# If it returns 192.168.3.21, update the Pi-hole DNS record
```

**Direct access fallback**: `http://192.168.3.21:32400/web` (bypasses Traefik, requires Mini PC to be on)

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
- **Plex**: Runs on Proxmox LXC (`192.168.3.21`). Routed via Traefik file provider (`plex.yml`), no Authelia.
- **Updates**: Watchtower automatically updates Traefik
