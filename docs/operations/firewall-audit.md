# Firewall & Security Configuration Audit

> Audit date: 2026-02-07
> Scope: All firewall rules, IP/Port groups, DNS, mDNS, IDS/IPS, Authelia, Traefik TLS, Docker socket security

---

## Summary

| Severity | Count |
|----------|-------|
| HIGH | 2 |
| MEDIUM | 7 |
| LOW | 6 |
| INFO | 4 |

Overall the firewall follows sound principles ("deny all, allow specific") with proper rule ordering. However, there are gaps where the authentication layer (Authelia) is undermined by firewall rules that force direct-port access, and an overly broad API bypass that affects critical services.

---

## HIGH Severity

### H1 — Authelia `/api/` bypass applies to all services including Portainer

**Location:** `docker/config/authelia/configuration.yml` (access_control rules)

**Issue:** The bypass rule:
```yaml
- domain: "*.home.local"
  policy: bypass
  resources:
    - "^/api/.*$"
```

...exempts any `/api/` path on *every* `*.home.local` service from authentication. While intended for *arr inter-service communication (which uses API keys), it also applies to:
- **Portainer** (`portainer.home.local/api/...`) — full Docker control, despite having `two_factor` policy on the UI
- **Duplicati** (`duplicati.home.local/api/...`) — backup management
- **Uptime Kuma** (`uptime.home.local/api/...`) — monitoring data
- **Pi-hole** (`pihole.home.local/api/...`) — DNS configuration

This directly undermines the `two_factor` policy set on Portainer. Authelia rules are evaluated first-match-wins, so the `*.home.local` bypass fires before the domain-specific `two_factor` rule for `portainer.home.local`.

**Current exploitability:** Currently limited to intra-VLAN access from the Servers VLAN (e.g., Desktop PC at 192.168.3.40 → Traefik at NAS:443) and Tailscale remote access, because Media VLAN cannot reach port 443 (see H2). However, this becomes **immediately exploitable from Media VLAN** if H2 is fixed by adding a port 443 rule. It is a latent vulnerability that undermines an explicit security intent.

**Recommendation:** Restrict the bypass to specific *arr service domains:
```yaml
- domain:
    - sonarr.home.local
    - radarr.home.local
    - lidarr.home.local
    - prowlarr.home.local
    - bazarr.home.local
    - huntarr.home.local
    - cleanuparr.home.local
  policy: bypass
  resources:
    - "^/api/.*$"
    - "^/ping$"
    - "^/health$"
    - "^/healthcheck$"
```

### H2 — No firewall rule for Traefik (port 443) from Media VLAN — forces auth bypass

**Location:** `docs/network/firewall-config.md` — LAN In Rules

**Issue:** Traefik listens on ports 80/443 on the NAS (192.168.3.10) and provides Authelia SSO authentication for all services. However, there is no firewall rule allowing Media VLAN (192.168.4.0/24) to reach NAS port 443.

Rule 4 allows Media → NAS only on the `Media-Services` port group (specific service ports like 8989, 7878, etc.), which does **not** include 443.

**Verified by rule trace:** Media (192.168.4.x) → NAS (192.168.3.10):443 — Rules 1-10 don't match → Rule 11 (Block All Inter-VLAN) → **DROP**.

**Consequence — two-part problem:**
1. Media VLAN clients cannot use `https://sonarr.home.local` (Traefik) — blocked by firewall.
2. Media VLAN clients *can* reach `192.168.3.10:8989` directly (via Rule 4 Media-Services ports) — this **bypasses Traefik and therefore bypasses Authelia authentication entirely**, since Docker publishes service ports directly on the host.

The firewall forces users to bypass the authentication layer.

**Recommendation:** Add a firewall rule (before Rule 11) allowing Media VLAN to NAS on TCP port 443, then consider removing individual service ports from the `Media-Services` group so all Media access is funneled through Traefik+Authelia:

| Field | Value |
|-------|-------|
| Name | Allow Media to Traefik |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | NAS (192.168.3.10) |
| Port | 443 |

If this rule is added, **fix H1 first** — otherwise the Authelia API bypass immediately becomes exploitable from Media VLAN.

---

## MEDIUM Severity

### M1 — Rule 4 grants Media VLAN direct access to Portainer (via Media-Services port group)

**Location:** `docs/network/firewall-config.md` — Rule 4 (`Media-Services` port group)

**Issue:** The `Media-Services` port group includes port 9443 (Portainer). Rule 4 allows Media VLAN (192.168.4.0/24) → NAS on all Media-Services ports, which means consumer devices — phones, tablets, Smart TVs — have direct network access to the Docker management interface.

**Verified by rule trace:** Media (192.168.4.x) → NAS (192.168.3.10):9443 — Rule 4 → **ACCEPT**.

Portainer with direct Docker socket access (`/var/run/docker.sock`) has full control over all containers. A compromised Portainer instance means full Docker and effective host compromise. Portainer has its own authentication, but exposing it to the Media VLAN:
- Increases attack surface (brute-force from compromised TV/phone)
- Bypasses the defense-in-depth Authelia layer (direct port, not through Traefik)

**Recommendation:** Remove port 9443 (Portainer) from the `Media-Services` port group. Portainer should only be accessible from the Servers VLAN (intra-VLAN, no firewall rule needed) via the Desktop PC. If remote management is needed, use Tailscale.

### M2 — Rule 10 is overly permissive (Servers → Management)

**Location:** `docs/network/firewall-config.md` — Rule 10

**Issue:** Rule 10 allows **all protocols** from the entire VLAN-Servers subnet (192.168.3.0/24) to the entire VLAN-Management subnet (192.168.2.0/24). The stated purpose is "desktop PC to access switch and AP management interfaces," but the rule grants access from every device on VLAN 3 (NAS, Proxmox, Printer, Desktop PC) to every device on VLAN 2 (UDM-SE, Switch, AP).

A compromised NAS or Proxmox host could pivot to the Management VLAN and access the UDM-SE controller (192.168.2.1), switch (192.168.2.10), and access point (192.168.2.20) management interfaces.

**Recommendation:** Restrict source to Desktop PC (`192.168.3.40`) and limit to TCP port 443 (HTTPS for UniFi management UIs). Create a `DesktopPC` IP group.

### M3 — Media-Services port group exposes admin services to Media VLAN

**Location:** `docs/network/firewall-config.md` — Port Groups, Rule 4

**Issue:** The `Media-Services` port group bundles 14 service ports. Rule 4 allows all Media VLAN devices to access all of them. This exposes admin-only and internal services to consumer devices:

| Service | Port | Media VLAN needs it? |
|---------|------|---------------------|
| Portainer | 9443 | **No** — Docker management, full host control (see M1) |
| FlareSolverr | 8191 | **No** — internal Prowlarr helper, has no authentication |
| Duplicati | 8200 | **No** — backup administration is sensitive |
| Pi-hole admin | 8081 | **No** — DNS admin interface |
| qBittorrent | 8080 | Questionable — download client |
| NZBGet | 6789 | Questionable — download client |
| Prowlarr | 9696 | Questionable — indexer management |
| Uptime Kuma | 3001 | Questionable — monitoring dashboard |
| Huntarr | 9705 | Questionable — monitoring tool |
| Cleanuparr | 11011 | Questionable — cleanup automation |
| Sonarr | 8989 | Yes |
| Radarr | 7878 | Yes |
| Lidarr | 8686 | Yes |
| Bazarr | 6767 | Yes |

FlareSolverr is especially concerning — it accepts arbitrary URL fetch requests and has no authentication mechanism at all.

**Recommendation:** Split into two port groups:
- `Media-User`: 8989 (Sonarr), 7878 (Radarr), 8686 (Lidarr), 6767 (Bazarr) — for Media VLAN
- `Media-Admin`: remaining ports — accessible only within Servers VLAN (no firewall rule needed)

Or better: fix H2 (allow port 443) and route all Media traffic through Traefik+Authelia, removing direct-port access entirely.

### M4 — No DNS egress filtering (Pi-hole bypass possible)

**Location:** `docs/network/firewall-config.md` — Rule 2

**Issue:** Rule 2 allows any VLAN to reach Pi-hole on port 53, but there is no rule blocking devices from querying external DNS servers directly (e.g., `8.8.8.8:53`). Since IoT and Media VLAN devices have Internet access (only RFC1918 is blocked, not public IPs), they can bypass Pi-hole entirely by querying public DNS.

This undermines Pi-hole's ad-blocking and any DNS-based security filtering.

**Trade-off:** The DNS architecture intentionally configures Cloudflare (1.1.1.1) as secondary DNS on VLANs 2, 4, and 6 so that DNS continues working during Pi-hole outages (`firewall-config.md` → DNS Configuration → Fallback Behavior). Blocking external DNS would break this fallback, leaving all VLANs with no DNS resolution when Pi-hole is down.

**Recommendation (choose one):**
- **Option A — Keep fallback, accept bypass risk:** No change. Accept that devices can bypass Pi-hole. This is the current trade-off.
- **Option B — Block external DNS, deploy redundant Pi-hole:** Add a LAN In rule (after Rule 2) that drops DNS (TCP/UDP 53) from VLANs 2, 4, and 6 to any destination except NAS. Then deploy a second Pi-hole on Proxmox with Gravity Sync (as suggested in the DNS doc) to restore redundancy. Guest VLAN should be exempt since it uses Cloudflare by design.

### M5 — Guest VLAN can reach Pi-hole DNS (information leak)

**Location:** `docs/network/firewall-config.md` — Rules 2 and 9

**Issue:** Rule 2 (`Allow Any → NAS:53`) fires **before** Rule 9 (`Block Guest → RFC1918`). This means Guest devices can reach Pi-hole.

**Verified by rule trace:** Guest (192.168.5.x) → NAS (192.168.3.10):53 — Rule 2 matches → **ACCEPT**. Rule 9 never evaluates.

While DHCP only configures Cloudflare DNS for Guest VLAN, a technically savvy guest can manually set their DNS to `192.168.3.10` and:
- Resolve `*.home.local` names (sonarr.home.local, portainer.home.local, etc.)
- Discover internal service topology and hostnames
- Identify the NAS IP address and running services

This is an information leak that aids reconnaissance, though the guest still cannot reach those services (blocked by Rule 9 on other ports).

**Recommendation:** Add a rule before Rule 2 that blocks Guest VLAN → NAS:53 specifically, or restructure Rule 2 to exclude Guest VLAN as a source:

| Field | Value |
|-------|-------|
| Name | Block Guest DNS to Pi-hole |
| Action | Drop |
| Protocol | TCP/UDP |
| Source | VLAN-Guest |
| Destination | NAS (192.168.3.10) |
| Port | DNS (53) |

Place this **before** Rule 2.

### M6 — No brute-force protection in Authelia

**Location:** `docker/config/authelia/configuration.yml`

**Issue:** The Authelia configuration has no `regulation` block. Without it, there is no account lockout after failed login attempts. An attacker on any VLAN with access to Traefik (currently only Servers VLAN, but Media if H2 is fixed) can attempt unlimited password guesses.

**Recommendation:** Add:
```yaml
regulation:
  max_retries: 5
  find_time: 2m
  ban_time: 10m
```

### M7 — Default admin user with known password hash committed

**Location:** `docker/config/authelia/users_database.yml`

**Issue:** The file ships with user `admin` and the argon2id hash of password `changeme`. While comments warn to change it, the hash is committed to the repository. If deployed as-is (or if the user forgets to change it), anyone on the network who can reach Authelia can authenticate as admin.

**Recommendation:** Replace the password hash with a placeholder that cannot be used to authenticate (e.g., `CHANGE_ME`), or move this file to a `.example` pattern like the `.env.secrets.example` approach.

---

## LOW Severity

### L1 — Plex IP likely mismatched in firewall rules

**Location:** `docs/network/firewall-config.md` Rule 3; `docs/network/rack-homelab-config.md` service table

**Issue:** Firewall Rule 3 allows Media VLAN to reach Plex at MiniPC IP group (`192.168.3.20`). However, the rack config documents Plex running in an LXC container at `192.168.3.21`:

| Source | IP |
|--------|----|
| Firewall MiniPC group | 192.168.3.20 |
| rack-homelab-config.md Plex entry | 192.168.3.21 |

If the LXC container has its own network interface at `.21`, Proxmox host at `.20` does not forward traffic to it. Rule 3 would allow traffic to `.20:32400` where nothing is listening, while Plex at `.21:32400` has no matching allow rule and is **blocked by Rule 11**.

**Potential impact:** Plex may be unreachable from Media VLAN, which is a functional failure of the primary media streaming use case.

**Recommendation:** Verify the actual Plex network configuration. If Plex binds to `.21`, create a `Plex-LXC` IP group and update Rule 3 to target it.

### L2 — Home Assistant Traefik route has no Authelia middleware

**Location:** `docker/config/traefik/homeassistant.yml`

**Issue:** The Home Assistant Traefik dynamic configuration defines a router without Authelia middleware:
```yaml
routers:
  homeassistant:
    rule: "Host(`ha.home.local`)"
    service: homeassistant
    entryPoints:
      - websecure
    tls: {}
    # No middlewares reference to authelia
```

All other services routed through Traefik have `middlewares=authelia@docker` (except Authelia itself at `auth.home.local`, which cannot self-protect — that is expected). HA is the only *protectable* service that relies solely on its own authentication. While likely intentional (HA webhooks and API integrations need direct access), this is inconsistent with the defense-in-depth approach applied to all other protected services.

**Note:** If H2 is fixed (adding port 443 for Media VLAN), `ha.home.local` becomes accessible from Media VLAN through Traefik without Authelia protection.

### L3 — `Servers-All` IP group is inconsistent

**Location:** `docs/network/firewall-config.md` — IP Groups

**Issue:** `Servers-All` contains NAS (`.10`), MiniPC (`.20`), and Printer (`.30`) but excludes Desktop PC (`.40`). The name "Servers-All" is misleading. Additionally, if the Plex LXC at `.21` is a separate network entity, it is also missing. This group is not used in any current rule but could cause issues if referenced in the future.

### L4 — TLS minimum version could be TLS 1.3

**Location:** `docker/config/traefik/tls.yml`

**Issue:** `minVersion: VersionTLS12`. All modern clients in this homelab (recent phones, PCs, TVs) support TLS 1.3. Raising the minimum would eliminate older cipher negotiation and remove the TLS 1.2 cipher suites entirely (TLS 1.3 uses its own fixed set).

**Risk:** Low — TLS 1.2 with the configured cipher suites (ECDHE + AEAD only) is still secure.

### L5 — `sniStrict: false` allows unknown hostname connections

**Location:** `docker/config/traefik/tls.yml`

**Issue:** With `sniStrict: false`, requests to the NAS IP on port 443 without a valid `Host` header (or with an unknown hostname) will still receive a TLS connection and the default certificate. This could allow probing of the Traefik instance. Setting `sniStrict: true` would reject TLS connections to unknown hostnames at the handshake level.

### L6 — Uptime Kuma has direct Docker socket access

**Location:** `docker/compose.yml` line 291

**Issue:** Uptime Kuma mounts `/var/run/docker.sock:/var/run/docker.sock:ro`. While read-only, this still exposes full container metadata (names, environment variables, labels, network configuration) to Uptime Kuma. If Uptime Kuma is compromised, the attacker gains visibility into the entire Docker environment.

The existing socket-proxy was designed specifically to prevent this pattern. Consider routing Uptime Kuma's Docker monitoring through the socket-proxy instead.

---

## INFO

### I1 — mDNS port group defined but unused

The `mDNS` port group (5353) is defined in UDM-SE profiles but never referenced in any firewall rule. mDNS reflection operates at the UDM-SE level and does not require a firewall rule. Not a security issue, but unused configuration could cause confusion during maintenance.

### I2 — No WAN Local / WAN In rules documented

The firewall config only documents LAN In rules. The "Legacy Network Security Considerations" section mentions a future WAN Local rule to restrict management access from 192.168.1.0/24, but it hasn't been implemented. If port forwarding is ever enabled (e.g., for remote Plex), WAN In rules should be documented.

### I3 — Home Assistant runs with host networking

Home Assistant uses `network_mode: host` for device discovery (Zigbee, Bluetooth, mDNS). This gives it full access to all host network interfaces. A compromised HA instance would have NAS-level network access to all VLANs. This is standard for HA and the trade-off is documented.

### I4 — Docker socket-proxy runs as privileged

The `socket-proxy` container (`docker/compose.yml` line 67) runs with `privileged: true`, which is required for the Tecnativa docker-socket-proxy to function. However, this gives the container nearly equivalent permissions to root on the host. The entire security model (isolating Traefik and Watchtower from the raw Docker socket) depends on the integrity of this single container image. A supply-chain compromise of `tecnativa/docker-socket-proxy:latest` would bypass all socket restrictions.

---

## Positive Findings

The following security measures are well-implemented:

- **Rule ordering**: Established/Related first, catch-all deny last — correct and robust
- **VLAN segmentation**: Clean separation of Management, Servers, Media, Guest, IoT
- **Guest isolation**: RFC1918 block (Rule 9) prevents access to internal services (note: DNS exception exists per M5)
- **IoT isolation**: RFC1918 block (Rule 8) with targeted HA exception (Rule 7) — well-scoped
- **Docker socket proxy**: Deny-by-default with explicit API permissions (14 endpoints explicitly denied)
- **Socket proxy network**: `internal: true` prevents external access to the socket proxy
- **IDS/IPS**: Enabled in prevention mode (not just detection) on IoT and Guest VLANs
- **QoS**: Plex traffic prioritized (DSCP 46/EF), Guest bandwidth limited (50/10 Mbps)
- **VPN for downloads**: Gluetun with kill switch protects torrent traffic; IPv6 disabled to prevent leaks
- **Authelia 2FA**: Required for Portainer and Traefik dashboard (the two most sensitive admin tools)
- **WebAuthn/Passkey**: Modern passwordless authentication supported
- **Argon2id**: Strong password hashing (65536 KiB memory, 3 iterations, 4 parallelism)
- **TLS cipher suites**: Modern, secure selection (ECDHE + AEAD only; no CBC, no RSA key exchange)
- **Self-signed cert**: 4096-bit RSA key, SHA-256, SAN with wildcard — appropriate for internal use
- **Tailscale**: Remote access via NAT traversal without port forwarding — eliminates WAN exposure
- **Legacy network risk assessment**: Documented with clear risk acceptance rationale
