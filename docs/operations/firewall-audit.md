# Firewall & Security Configuration Audit

> Audit date: 2026-02-24
> Scope: All firewall rules, IP/Port groups, DNS, mDNS, IDS/IPS, Authelia, Traefik TLS, Docker socket security
> Updated: 2026-02-25 — QTS-Management removed, Rule 8 now uses NAS Management; L8 resolved, M1/M3/M9 updated

---

## Summary

| Severity | Count |
|----------|-------|
| HIGH | 0 (2 fixed) |
| MEDIUM | 8 (1 fixed) |
| LOW | 8 |
| INFO | 7 |

Overall the firewall follows sound principles ("deny all, allow specific") with proper rule ordering. Two HIGH findings (H1, H2) have been resolved — the Authelia API bypass is now scoped to *arr domains, and Media VLAN can reach Traefik on port 443 for authenticated access. Remaining MEDIUM findings relate to direct-port exposure, DNS filtering gaps, and wireless management rules (Rules 8-9) that expose infrastructure admin interfaces to the Media VLAN. Rule 10 (Media → UniFi Controller) was removed as redundant — the UDM-SE controller is accessible at the VLAN gateway IP without a firewall rule.

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

**Current exploitability:** ~~Currently limited to intra-VLAN access from the Servers VLAN~~ After the H2 fix (Rule 7), Media VLAN can reach Traefik on port 443, so this API bypass was **immediately exploitable from consumer devices** (phones, tablets, Smart TVs). This is why H1 was fixed first — the API bypass was scoped to specific *arr domains before H2 (port 443 access) was added.

**Recommendation:** Restrict the bypass to specific *arr service domains:
```yaml
- domain:
    - sonarr.home.local
    - radarr.home.local
    - lidarr.home.local
    - prowlarr.home.local
    - bazarr.home.local
    - cleanuparr.home.local
  policy: bypass
  resources:
    - "^/api/.*$"
    - "^/ping$"
    - "^/health$"
    - "^/healthcheck$"
```

> **RESOLVED:** API bypass scoped to specific *arr domains in `docker/config/authelia/configuration.yml`. Portainer, Duplicati, Uptime Kuma, and Pi-hole `/api/` paths now require full authentication per their domain-specific policies.

### H2 — ~~No firewall rule for~~ Traefik (port 443) from Media VLAN ~~— forces auth bypass~~

**Location:** `docs/network/firewall-config.md` — LAN In Rules

**Issue:** Traefik listens on ports 80/443 on the NAS (192.168.3.10) and provides Authelia SSO authentication for all services. Port 80 only serves as an HTTP→HTTPS redirect (`--entrypoints.web.http.redirections.entryPoint.to=websecure`) — no content is served over plain HTTP. However, there is no firewall rule allowing Media VLAN (192.168.4.0/24) to reach NAS port 443.

Rule 4 allows Media → NAS only on the `Media Services` port group (specific service ports like 8989, 7878, etc.), which does **not** include 443.

**Verified by rule trace (before fix):** Media (192.168.4.x) → NAS (192.168.3.10):443 — no allow rule matched → catch-all Block All Inter-VLAN → **DROP**. After fix: Rule 7 (Allow Media to Traefik) → **ACCEPT**.

**Consequence — two-part problem:**
1. Media VLAN clients cannot use `https://sonarr.home.local` (Traefik) — blocked by firewall.
2. Media VLAN clients *can* reach `192.168.3.10:8989` directly (via Rule 4 Media Services ports) — this **bypasses Traefik and therefore bypasses Authelia authentication entirely**, since Docker publishes service ports directly on the host.

The firewall forces users to bypass the authentication layer.

**Recommendation:** Add a firewall rule (before catch-all block) allowing Media VLAN to NAS on TCP port 443 only. Port 80 does not need a rule — Traefik redirects HTTP→HTTPS, so clients that can reach port 443 will be served correctly, and clients that cannot reach port 80 simply use `https://` directly. Then consider removing individual service ports from the `Media Services` group so all Media access is funneled through Traefik+Authelia:

| Field | Value |
|-------|-------|
| Name | Allow Media to Traefik |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN Media |
| Destination | NAS (192.168.3.10) |
| Port | 443 |

> **RESOLVED:** Rule 7 (Allow Media to Traefik, TCP 443) added to `docs/network/firewall-config.md`. H1 was fixed first (API bypass scoped). Direct-port access via Rule 4 (Media Services) is retained as a fallback during initial setup; planned for removal once Traefik+Authelia is validated, which will fully resolve the auth bypass path described in consequence #2.

---

## MEDIUM Severity

### M1 — Portainer direct-port accessible from Media VLAN without Authelia

**Location:** `docs/network/firewall-config.md` — Port Groups (`NAS Management`), Rule 8

**Issue:** Port 9443 (Portainer) is in the `NAS Management` port group. Rule 8 exposes NAS Management to Media VLAN, so Portainer is directly accessible from consumer devices (phones, tablets) at `https://192.168.3.10:9443`, bypassing Traefik and therefore bypassing Authelia authentication, relying solely on Portainer's built-in auth.

Portainer with direct Docker socket access (`/var/run/docker.sock`) has full control over all containers. A compromised Portainer instance means full Docker and effective host compromise. Portainer is also accessible through Traefik at `portainer.home.local` with `two_factor` Authelia policy, but Rule 8 provides an unprotected alternative path from any device on VLAN 3 or VLAN 4.

**Recommendation:** Access Portainer exclusively through Traefik (`portainer.home.local`) with Authelia 2FA. If the direct port must remain accessible for emergency Docker management, restrict it to the Desktop PC by adding host-level firewall rules (iptables) on the NAS. Alternatively, remove port 9443 from the `NAS Management` port group and access Portainer only via Traefik (Rule 7).

### M2 — Rule 13 is overly permissive (Servers → Management)

**Location:** `docs/network/firewall-config.md` — Rule 13

**Issue:** Rule 13 allows **all protocols** from the entire VLAN Servers subnet (192.168.3.0/24) to the entire VLAN Management subnet (192.168.2.0/24). The stated purpose is "desktop PC to access switch and AP management interfaces," but the rule grants access from every device on VLAN 3 (NAS, Proxmox, Printer, Desktop PC) to every device on VLAN 2 (UDM-SE, Switch, AP).

A compromised NAS or Proxmox host could pivot to the Management VLAN and access the UDM-SE controller (192.168.2.1), switch (192.168.2.10), and access point (192.168.2.20) management interfaces.

**Recommendation:** Restrict source to Desktop PC (`192.168.3.40`) and limit to TCP port 443 (HTTPS for UniFi management UIs). Create a `DesktopPC` IP group.

### M3 — Media Services port group exposes admin services to Media VLAN

**Location:** `docs/network/firewall-config.md` — Port Groups, Rule 4

**Issue:** The `Media Services` port group bundles 10 service ports. Rule 4 allows all Media VLAN devices to access all of them. This exposes admin-only and internal services to consumer devices:

| Service | Port | Media VLAN needs it? |
|---------|------|---------------------|
| FlareSolverr | 8191 | **No** — internal Prowlarr helper, has no authentication |
| qBittorrent | 8080 | Questionable — download client |
| NZBGet | 6789 | Questionable — download client |
| Prowlarr | 9696 | Questionable — indexer management |
| Cleanuparr | 11011 | Questionable — cleanup automation |
| Sonarr | 8989 | Yes |
| Radarr | 7878 | Yes |
| Lidarr | 8686 | Yes |
| Bazarr | 6767 | Yes |

FlareSolverr is especially concerning — it accepts arbitrary URL fetch requests and has no authentication mechanism at all.

**Note:** Portainer (9443), Duplicati (8200), Pi-hole admin (8081), and Uptime Kuma (3001) are in the `NAS Management` port group, which is exposed to Media VLAN via Rule 8. These services are therefore accessible both directly (bypassing Authelia) and through Traefik+Authelia (Rule 7). See M1 for Portainer-specific concerns.

**Recommendation:** Split into two port groups:
- `Media-User`: 8989 (Sonarr), 7878 (Radarr), 8686 (Lidarr), 6767 (Bazarr) — for Media VLAN
- `Media-Admin`: remaining ports — accessible only within Servers VLAN (no firewall rule needed)

Or better: now that H2 is resolved (Rule 7 allows port 443), route all Media traffic through Traefik+Authelia and remove direct-port access entirely.

### M4 — No DNS egress filtering (Pi-hole bypass possible)

**Location:** `docs/network/firewall-config.md` — Rule 2

**Issue:** Rule 2 allows any VLAN to reach Pi-hole on port 53, but there is no rule blocking devices from querying external DNS servers directly (e.g., `8.8.8.8:53`). Since IoT and Media VLAN devices have Internet access (only RFC1918 is blocked, not public IPs), they can bypass Pi-hole entirely by querying public DNS.

This undermines Pi-hole's ad-blocking and any DNS-based security filtering.

**Trade-off:** The DNS architecture intentionally configures Cloudflare (1.1.1.1) as secondary DNS on VLANs 2, 4, and 6 so that DNS continues working during Pi-hole outages (`firewall-config.md` → DNS Configuration → Fallback Behavior). Blocking external DNS would break this fallback, leaving all VLANs with no DNS resolution when Pi-hole is down.

**Recommendation (choose one):**
- **Option A — Keep fallback, accept bypass risk:** No change. Accept that devices can bypass Pi-hole. This is the current trade-off.
- **Option B — Block external DNS, deploy redundant Pi-hole:** Add a LAN In rule (after Rule 2) that drops DNS (TCP/UDP 53) from VLANs 2, 4, and 6 to any destination except NAS. Then deploy a second Pi-hole on Proxmox with Gravity Sync (as suggested in the DNS doc) to restore redundancy. Guest VLAN should be exempt since it uses Cloudflare by design.

### M5 — Guest VLAN can reach Pi-hole DNS (information leak)

**Location:** `docs/network/firewall-config.md` — Rules 2 and 12

**Issue:** Rule 2 (`Allow Any → NAS:53`) fires **before** Rule 12 (`Block Guest → RFC1918`). This means Guest devices can reach Pi-hole.

**Verified by rule trace:** Guest (192.168.5.x) → NAS (192.168.3.10):53 — Rule 2 matches → **ACCEPT**. Rule 12 never evaluates.

While DHCP only configures Cloudflare DNS for Guest VLAN, a technically savvy guest can manually set their DNS to `192.168.3.10` and:
- Resolve `*.home.local` names (sonarr.home.local, portainer.home.local, etc.)
- Discover internal service topology and hostnames
- Identify the NAS IP address and running services

This is an information leak that aids reconnaissance, though the guest still cannot reach those services (blocked by Rule 12 on other ports).

**Recommendation:** Add a rule before Rule 2 that blocks Guest VLAN → NAS:53 specifically, or restructure Rule 2 to exclude Guest VLAN as a source:

| Field | Value |
|-------|-------|
| Name | Block Guest DNS to Pi-hole |
| Action | Drop |
| Protocol | TCP/UDP |
| Source | VLAN Guest |
| Destination | NAS (192.168.3.10) |
| Port | DNS (53) |

Place this **before** Rule 2.

### M6 — No brute-force protection in Authelia

**Location:** `docker/config/authelia/configuration.yml`

**Issue:** The Authelia configuration has no `regulation` block. Without it, there is no account lockout after failed login attempts. An attacker on any VLAN with access to Traefik (Servers VLAN intra-VLAN, and Media VLAN via Rule 7) can attempt unlimited password guesses.

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

### M8 — ~~Rule 10 pierces Management VLAN boundary from consumer network~~

**Location:** `docs/network/firewall-config.md` — ~~Rule 10~~ (removed)

**Issue:** Rule 10 allowed the entire VLAN Media subnet (192.168.4.0/24) to reach the UDM-SE (192.168.2.1) on port 443. This was the only rule that allowed a consumer VLAN to cross into the Management VLAN.

> **RESOLVED:** Rule 10 removed. The UniFi Controller on the UDM-SE is already accessible at the VLAN gateway IP (e.g., `https://192.168.4.1` from Media VLAN) without requiring a cross-VLAN firewall rule — the gateway IP is local to each VLAN. The explicit rule to 192.168.2.1 was redundant and unnecessarily pierced the Management VLAN boundary. The `UDM-SE` IP group was also removed from network lists.

### M9 — Rule 8 includes QTS HTTP port 5000 (cleartext credentials)

**Location:** `docs/network/firewall-config.md` — Rule 8, Port Groups (`NAS Management`)

**Issue:** The `NAS Management` port group includes port 5000 (QTS HTTP) alongside port 5001 (QTS HTTPS). Port 5000 serves the QTS admin interface over unencrypted HTTP. When a user logs into QTS via `http://192.168.3.10:5000` from their phone on WiFi, credentials are transmitted in cleartext and can be intercepted by any device on VLAN 4 (ARP spoofing, rogue AP, compromised device running a sniffer).

**Verified by rule trace:** Media (192.168.4.x) → NAS (192.168.3.10):5000 — Rule 8 → **ACCEPT**.

QNAP QTS supports "Force Secure Connection (HTTPS)" in Control Panel → System → General Settings → System Administration, which redirects port 5000 to HTTPS on port 5001. If this is enabled, port 5000 only serves a redirect and credentials are never sent in cleartext. However, this depends on QTS configuration — the firewall should not assume it.

**Note:** QNAP QTS factory defaults are 8080 (HTTP) and 443 (HTTPS) — ports were changed to 5000/5001 in this setup to avoid conflicts with qBittorrent (8080) and Traefik (443). A port change step has been added to `nas-setup.md`. Multiple files previously referenced `https://192.168.3.10:5000` labeling it as QTS HTTPS — this was incorrect. QTS HTTPS is port 5001, not 5000. All instances have been corrected to `https://192.168.3.10:5001` in the backup runbook, proxmox-setup, and energy-saving-strategies docs.

**Recommendation:** Remove port 5000 from the `NAS Management` port group, keeping only port 5001 (HTTPS). Users should access QTS via `https://192.168.3.10:5001`. If QTS "Force Secure Connection" is enabled, port 5000 is not needed in the firewall rule at all (the redirect happens server-side, but the initial HTTP request still transmits in cleartext before the redirect).

---

## LOW Severity

### L1 — ~~Plex LXC IP not in any reusable IP group~~ RESOLVED

**Location:** `docs/network/firewall-config.md` Rule 3, IP Address Network Lists

**Resolution:** Created `Plex Server` IP group (`192.168.3.21`) in UDM-SE network lists. Rule 3 now references `Plex Server (192.168.3.21)`. Added `.21` to `Servers All` group. Documentation updated to match.

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

**Note:** Since H2 is resolved (Rule 7 allows Media VLAN → port 443), `ha.home.local` is now accessible from Media VLAN through Traefik without Authelia protection. HA's built-in authentication is the only barrier.

### L3 — ~~`Servers All` IP group is inconsistent~~ PARTIALLY RESOLVED

**Location:** `docs/network/firewall-config.md` — IP Groups

**Resolution:** `Servers All` now includes Plex LXC at `.21` (`192.168.3.10, 192.168.3.20, 192.168.3.21, 192.168.3.30`). Documentation updated to match UDM.

**Remaining:** Desktop PC (`.40`) is still excluded. The name "Servers All" refers to infrastructure servers, not all VLAN 3 devices. This group is not used in any current rule.

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

### L7 — Watchtower port 8383 not in Media Services port group

**Location:** `docs/network/firewall-config.md` — Port Groups; `Makefile` — `show-urls` target

**Issue:** Watchtower exposes a metrics endpoint on port 8383 (`docker/compose.yml`). The `Makefile` `show-urls` target advertises `http://NAS_IP:8383` alongside other services, and the `health` target checks it. However, port 8383 is not in the `Media Services` port group and has no firewall rule allowing access from Media VLAN.

This is likely correct (Watchtower is admin-only), but the `show-urls` output presents it alongside user-facing services, giving users a URL they cannot reach from Media VLAN devices.

**Recommendation:** Either add 8383 to `Media Services` (if metrics should be accessible from Media VLAN), or document in the Makefile output that Watchtower is only accessible from Servers VLAN. The latter is the safer option.

### L8 — ~~QTS-Management port group duplicates a subset of NAS Management~~

**Location:** `docs/network/firewall-config.md` — Port Groups

**Issue:** The `QTS-Management` port group (5000, 5001) was a proper subset of `NAS Management` (5000, 5001, 8081, 9443, 8200, 3001). Both were defined in the port network lists, creating redundancy.

> **RESOLVED:** `QTS-Management` port group removed. Rule 8 now uses `NAS Management` directly, eliminating the redundancy. This intentionally exposes all NAS admin ports (QTS, Pi-hole, Portainer, Duplicati, Uptime Kuma) to Media VLAN — all services have their own authentication. See M1 for Portainer-specific security considerations.

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

### I5 — ~~Mini PC and~~ Servers All IP group~~s~~ defined but unused

The `Servers All` (`192.168.3.10, 192.168.3.20, 192.168.3.21, 192.168.3.30`) IP group is defined in the UDM-SE network lists but never referenced by any firewall rule. Similar to I1 (mDNS port group), this is a dead configuration entry. Not harmful, but could cause confusion during maintenance or give a false sense of coverage.

> **Partially resolved:** The `Mini PC` group is now referenced by Rule 9 (Allow Media to Proxmox). `Servers All` remains unused.

### I6 — Plex GDM broadcast discovery does not work cross-VLAN

Plex GDM (G'Day Mate) discovery uses UDP broadcast packets (destination `255.255.255.255` or subnet broadcast) on ports 32410-32414. While Rule 3 allows directed UDP from Media VLAN to Plex LXC on these ports, GDM broadcasts originate on the Media VLAN subnet and never cross the VLAN boundary — broadcast traffic is Layer 2 and is confined to the originating VLAN.

In practice this is not a problem: Plex clients discover servers via Plex account login (cloud-mediated discovery), not local GDM. The 32410-32414 ports in Rule 3 remain useful for Plex Companion (remote control) features, which use directed unicast UDP. No action needed, but worth documenting for troubleshooting if a user expects automatic local discovery.

### I7 — Firewall rules are IPv4-only

All firewall rules use IPv4 subnets (192.168.x.0/24, RFC1918). If any service or device enables IPv6, inter-VLAN traffic over IPv6 would not be covered by these rules. Currently mitigated by Gluetun explicitly disabling IPv6 (`net.ipv6.conf.all.disable_ipv6=1`) and UDM-SE not having IPv6 configured on internal VLANs. If IPv6 is ever enabled on the network, equivalent `ip6tables` rules must be created.

---

## Positive Findings

The following security measures are well-implemented:

- **Rule ordering**: Established/Related first, catch-all deny last — correct and robust
- **VLAN segmentation**: Clean separation of Management, Servers, Media, Guest, IoT
- **Traefik+Authelia access path**: Rule 7 enables Media VLAN to access services through Traefik with SSO authentication
- **Wireless management scoping**: Rules 8-9 are narrowly scoped — TCP-only, specific destination IPs (not subnets), specific ports. NAS admin services (QTS, Pi-hole, Portainer, Duplicati, Uptime Kuma) and Proxmox (8006) each have their own authentication. UniFi Controller is accessed via the VLAN gateway IP without crossing into the Management VLAN
- **Guest isolation**: RFC1918 block (Rule 12) prevents access to internal services (note: DNS exception exists per M5)
- **IoT isolation**: RFC1918 block (Rule 11) with targeted HA exception (Rule 10) — well-scoped
- **Docker socket proxy**: Deny-by-default with explicit API permissions (14 endpoints explicitly denied)
- **Socket proxy network**: `internal: true` prevents external access to the socket proxy
- **IDS/IPS**: Enabled in prevention mode (not just detection) on IoT and Guest VLANs
- **QoS**: Plex traffic prioritized (DSCP 46/EF), Guest bandwidth limited (50/10 Mbps)
- **VPN for downloads**: Gluetun with kill switch protects torrent traffic; IPv6 disabled to prevent leaks
- **Authelia 2FA**: Required for Portainer and Traefik dashboard (the two most sensitive admin tools)
- **WebAuthn/Passkey**: Modern passwordless authentication supported
- **Argon2id**: Strong password hashing (65536 KiB memory, 3 iterations, 4 parallelism)
- **HTTP→HTTPS redirect**: Traefik redirects all port 80 requests to port 443 — no content is served over plain HTTP
- **TLS cipher suites**: Modern, secure selection (ECDHE + AEAD only; no CBC, no RSA key exchange)
- **Self-signed cert**: 4096-bit RSA key, SHA-256, SAN with wildcard — appropriate for internal use
- **Tailscale**: Remote access via NAT traversal without port forwarding — eliminates WAN exposure
- **Legacy network risk assessment**: Documented with clear risk acceptance rationale
