# Firewall & Security Configuration Audit

> Audit date: 2026-02-07
> Scope: All firewall rules, IP/Port groups, DNS, mDNS, IDS/IPS, Authelia, Traefik TLS, Docker socket security

---

## Summary

| Severity | Count |
|----------|-------|
| HIGH | 2 |
| MEDIUM | 5 |
| LOW | 5 |
| INFO | 3 |

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
- **Duplicati** — backup management
- **Uptime Kuma** — monitoring data
- **Pi-hole** — DNS configuration

This directly undermines the `two_factor` policy set on Portainer.

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

### H2 — No firewall rule for Traefik (port 443) from Media VLAN

**Location:** `docs/network/firewall-config.md` — LAN In Rules

**Issue:** Traefik listens on ports 80/443 on the NAS (192.168.3.10) and provides Authelia SSO authentication for all services. However, there is no firewall rule allowing Media VLAN (192.168.4.0/24) to reach NAS port 443.

Rule 5 allows Media to NAS only on the `Arr-Stack` port group (specific service ports like 8989, 7878, etc.), which does not include 443.

**Consequence:** Media VLAN clients (phones, tablets) are forced to access services via direct IP:port (e.g., `192.168.3.10:8989`) rather than through Traefik (`https://sonarr.home.local`). Direct-port access **bypasses Authelia authentication entirely**, since Authelia is a Traefik middleware.

This creates a security paradox where the firewall forces users to bypass the auth layer.

**Recommendation:** Add a firewall rule (before Rule 13) allowing Media VLAN to NAS on TCP port 443. Then consider removing individual service ports from the `Arr-Stack` group so all Media access is funneled through Traefik+Authelia:

| Field | Value |
|-------|-------|
| Name | Allow Media to Traefik |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | NAS (192.168.3.10) |
| Port | 443 |

---

## MEDIUM Severity

### M1 — Rule 12 is overly permissive (Servers -> Management)

**Location:** `docs/network/firewall-config.md` — Rule 12

**Issue:** Rule 12 allows **all protocols** from the entire VLAN-Servers subnet (192.168.3.0/24) to the entire VLAN-Management subnet (192.168.2.0/24). The stated purpose is "desktop PC to access switch and AP management interfaces," but the rule grants access from every device on VLAN 3 (NAS, Proxmox, Printer, Desktop PC).

A compromised NAS or Proxmox host could pivot to the Management VLAN and access the UDM-SE controller, switch, and access point management interfaces.

**Recommendation:** Restrict source to Desktop PC (`192.168.3.40`) and limit to TCP port 443 (HTTPS for UniFi management UIs). Create a `DesktopPC` IP group.

### M2 — Arr-Stack port group exposes admin services to Media VLAN

**Location:** `docs/network/firewall-config.md` — Port Groups, Rule 5

**Issue:** The `Arr-Stack` port group bundles 13 service ports. Rule 5 allows all Media VLAN devices to access all of them. This exposes admin-only services to consumer devices:

| Service | Port | Media VLAN needs it? |
|---------|------|---------------------|
| FlareSolverr | 8191 | No — internal only, no auth |
| Duplicati | 8200 | No — backup admin |
| Pi-hole admin | 8081 | No — DNS admin |
| qBittorrent | 8080 | Questionable |
| NZBGet | 6789 | Questionable |
| Prowlarr | 9696 | Questionable |

**Recommendation:** Split into two port groups:
- `Arr-Media`: 8989 (Sonarr), 7878 (Radarr), 8686 (Lidarr), 6767 (Bazarr) — for Media VLAN
- `Arr-Admin`: remaining ports — accessible only within Servers VLAN (no firewall rule needed)

### M3 — No DNS egress filtering (Pi-hole bypass possible)

**Location:** `docs/network/firewall-config.md` — Rule 2

**Issue:** Rule 2 allows any VLAN to reach Pi-hole on port 53, but there is no rule blocking devices from querying external DNS servers directly (e.g., 8.8.8.8:53). A compromised IoT device or malware on a Media device can bypass Pi-hole entirely.

**Recommendation:** Add a rule (after Rule 2, before IoT/Guest blocks) that drops outbound DNS (TCP/UDP 53) from VLANs 2, 4, and 6 to any destination except NAS. Guest VLAN should be exempt since it uses Cloudflare directly by design.

### M4 — No brute-force protection in Authelia

**Location:** `docker/config/authelia/configuration.yml`

**Issue:** The Authelia configuration has no `regulation` block. Without it, there is no account lockout after failed login attempts. An attacker on any VLAN with access to Traefik can attempt unlimited password guesses.

**Recommendation:** Add:
```yaml
regulation:
  max_retries: 5
  find_time: 2m
  ban_time: 10m
```

### M5 — Default admin user with known password hash committed

**Location:** `docker/config/authelia/users_database.yml`

**Issue:** The file ships with user `admin` and the argon2id hash of password `changeme`. While comments warn to change it, the hash is committed to the repository. If deployed as-is (or if the user forgets to change it), anyone on the local network can authenticate as admin.

**Recommendation:** Replace the password hash with a placeholder that cannot be used to authenticate (e.g., `CHANGE_ME`), or use a `.example` pattern for this file.

---

## LOW Severity

### L1 — Plex IP may be mismatched

**Location:** `docs/network/firewall-config.md` Rules 3-4; `docs/network/rack-homelab-config.md` service table

**Issue:** Firewall Rules 3-4 allow Media VLAN to reach Plex at MiniPC (`192.168.3.20`), but the rack config shows Plex runs in an LXC container at `192.168.3.21`. If the LXC has its own IP, traffic to `.20` would not reach Plex.

**Recommendation:** Verify whether Plex binds to host IP (`.20`) or LXC IP (`.21`). Update firewall rules or IP groups accordingly.

### L2 — `Servers-All` IP group is inconsistent

**Location:** `docs/network/firewall-config.md` — IP Groups

**Issue:** `Servers-All` contains NAS (`.10`), MiniPC (`.20`), and Printer (`.30`) but excludes Desktop PC (`.40`). The name "Servers-All" is misleading. This group is not used in any current rule but could cause issues if referenced in the future.

### L3 — TLS minimum version could be TLS 1.3

**Location:** `docker/config/traefik/tls.yml`

**Issue:** `minVersion: VersionTLS12`. All modern clients in this homelab (recent phones, PCs, TVs) support TLS 1.3. Raising the minimum would eliminate older cipher negotiation.

**Risk:** Low — TLS 1.2 with the configured cipher suites is still secure.

### L4 — `sniStrict: false` allows unknown hostname connections

**Location:** `docker/config/traefik/tls.yml`

**Issue:** Requests to the NAS IP on port 443 without a valid `Host` header (or with an unknown hostname) will still receive a TLS connection and potentially reach a service. Setting `sniStrict: true` would reject these.

### L5 — Uptime Kuma has direct Docker socket access

**Location:** `docker/compose.yml` (uptime-kuma service)

**Issue:** Uptime Kuma mounts `/var/run/docker.sock:/var/run/docker.sock:ro`. While read-only, this exposes container metadata (names, environment variables, labels). Consider routing through the socket-proxy if Docker monitoring is needed.

---

## INFO

### I1 — mDNS port group defined but unused

The `mDNS` port group (5353) is defined in UDM-SE profiles but never referenced in any firewall rule. mDNS reflection operates at the UDM-SE level and does not require a firewall rule. Not a security issue, but unused configuration could cause confusion.

### I2 — No WAN Local / WAN In rules documented

The firewall config only documents LAN In rules. The "Legacy Network Security Considerations" section mentions a future WAN Local rule to restrict management access from 192.168.1.0/24, but it hasn't been implemented. If port forwarding is ever enabled (e.g., for remote Plex), WAN In rules should be documented.

### I3 — Home Assistant runs with host networking

Home Assistant uses `network_mode: host` for device discovery (Zigbee, Bluetooth, mDNS). This gives it full access to all host network interfaces. A compromised HA instance would have NAS-level network access to all VLANs. This is standard for HA and the trade-off is documented.

---

## Positive Findings

The following security measures are well-implemented:

- **Rule ordering**: Established/Related first, catch-all deny last
- **VLAN segmentation**: Clean separation of Management, Servers, Media, Guest, IoT
- **Guest isolation**: Complete RFC1918 block + external-only DNS
- **IoT isolation**: RFC1918 block with targeted HA exception
- **Docker socket proxy**: Deny-by-default with explicit permissions
- **Socket proxy network**: `internal: true` prevents external access
- **IDS/IPS**: Enabled in prevention mode on IoT and Guest
- **QoS**: Plex traffic prioritized, Guest bandwidth limited
- **VPN for downloads**: Gluetun kill switch protects torrent traffic
- **Authelia 2FA**: Required for Portainer and Traefik dashboard
- **WebAuthn/Passkey**: Modern passwordless authentication supported
- **Argon2id**: Strong password hashing with good parameters
- **TLS cipher suites**: Modern, secure selection (ECDHE + AEAD only)
- **Self-signed cert**: 4096-bit RSA key, SHA-256, 10-year validity with SAN
- **Tailscale**: Remote access without port forwarding
