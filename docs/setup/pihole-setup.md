# Pi-hole Setup

> DNS-level ad-blocking and local name resolution for the homelab

---

## Overview

Pi-hole runs as a Docker container on the QNAP NAS (`192.168.3.10`) and serves as the primary DNS server for all VLANs (except Guest). It provides ad-blocking, local DNS records for `*.home.local`, and DNS for Tailscale remote access.

| Detail | Value |
|--------|-------|
| Container | `pihole` |
| Image | `pihole/pihole:latest` |
| WebUI | `http://192.168.3.10:8081/admin` |
| Reverse proxy | `https://pihole.home.local` |
| DNS ports | 53/tcp, 53/udp |
| Compose file | `docker/compose.yml` |

---

## Setup Order

Follow these sections in order. Each links to the relevant guide where the actual steps live.

### 1. Free DNS Port on QNAP

QNAP's built-in `dnsmasq` occupies port 53. It must be disabled before Pi-hole can start.

| | |
|---|---|
| **Preconditions** | SSH access to NAS, QTS autorun support enabled |
| **When** | During initial NAS setup, before starting Docker containers for the first time |

**Guide:** [NAS Setup — Free DNS Port (Port 53)](nas-setup.md#free-dns-port-port-53)

Covers: enabling `autorun.sh`, disabling `dnsmasq`, verifying port 53 is free.

### 2. Set Pi-hole Web Password

The Pi-hole container reads its web password from `.env.secrets`.

| | |
|---|---|
| **Preconditions** | Repository cloned to NAS, `.env.secrets` file created from `.env.secrets.example` |
| **When** | While preparing environment files, before first `make up` |

**Guide:** [NAS Setup — Environment & Secrets](nas-setup.md#environment--secrets)

Set `FTLCONF_webserver_api_password` in `docker/.env.secrets`.

### 3. Start the Stack

Pi-hole is part of the infrastructure compose file and starts with the rest of the stack.

| | |
|---|---|
| **Preconditions** | Port 53 free (step 1), `.env` and `.env.secrets` configured (step 2), Docker installed |
| **When** | First startup of the full Docker stack |

**Guide:** [NAS Setup — First Startup](nas-setup.md#first-startup)

```bash
make up        # starts all services including Pi-hole
make health    # verify Pi-hole is healthy
```

### 4. Configure Pi-hole (DNS Settings & Adlists)

Log in to the Pi-hole WebUI and configure upstream DNS, interface settings, and import the curated blocklists.

| | |
|---|---|
| **Preconditions** | Pi-hole container running and healthy (`make health` shows green) |
| **When** | Immediately after first startup; can be revisited any time to add/remove blocklists |

**Guide:** [NAS Setup — Pi-hole Configuration](nas-setup.md#pi-hole-configuration)

Covers: upstream DNS verification, adlist bulk import script, UDM-SE DHCP DNS settings.

### 5. Add Local DNS Records for Reverse Proxy

Pi-hole resolves `*.home.local` domains to the NAS IP so Traefik can handle routing. This also enables the same URLs to work over Tailscale.

| | |
|---|---|
| **Preconditions** | Pi-hole running and accessible (step 4), Traefik running, Tailscale container running on NAS |
| **When** | During Traefik/reverse proxy setup; must be done before any `*.home.local` URL will resolve |

**Guide:** [Reverse Proxy Setup — Phase 1: Pi-hole Configuration as Tailscale DNS](reverse-proxy-setup.md#phase-1-pi-hole-configuration-as-tailscale-dns)

Covers: how DNS resolution works, Tailscale nameserver config, adding all `*.home.local` DNS records, verification commands.

### 6. Configure VLAN DNS to Use Pi-hole

Each VLAN (except Guest) should use Pi-hole as its primary DNS server with Cloudflare as fallback.

| | |
|---|---|
| **Preconditions** | Pi-hole running and verified (step 4), UDM-SE accessible, VLANs already created |
| **When** | During initial network setup, or retroactively if VLANs were created with default DNS; can also be done per-VLAN as they are added |

**Guide:** [Network Setup — VLAN creation (Phase 2)](network-setup.md#phase-2-vlan-creation)

Per-VLAN DNS settings are documented in each VLAN subsection (Management, Servers, Media, IoT).

---

## Related References

These sections reference Pi-hole but are not part of the initial setup flow.

| Topic | Location |
|-------|----------|
| Docker service definition | [`docker/compose.yml`](../../docker/compose.yml) — `pihole` service |
| Adlists config file | [`docker/config/pihole/adlists.txt`](../../docker/config/pihole/adlists.txt) |
| Firewall rule (cross-VLAN DNS) | [Firewall Config — Rule 2: Allow All to Pi-hole DNS](../network/firewall-config.md#rule-2--allow-all-to-pi-hole-dns) |
| DNS architecture & fallback | [Firewall Config — DNS Architecture](../network/firewall-config.md#dns-architecture) |
| Authelia DNS prerequisite | [Authelia Setup — Phase 3: Add DNS Record](authelia-setup.md#phase-3-add-dns-record) |
| Uptime Kuma monitoring | [Notifications Setup — monitor table](notifications-setup.md) — Pi-hole monitored via DNS query to `pi.hole` |
| Backup scope | [Backup Runbook](../operations/runbook-backup-restore.md) — Pi-hole config included in daily `./config/*` backup |
| Troubleshooting | [NAS Setup — Common Troubleshooting](nas-setup.md#common-troubleshooting) — "Pi-hole doesn't resolve" entry |
