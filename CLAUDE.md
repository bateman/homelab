# CLAUDE.md - Homelab Repository Guide

## CRITICAL: Cross-File Consistency

**This is the #1 cause of errors. Read this before ANY change.**

### Before Editing, Complete This Checklist:

1. **Search the entire repo** for what you're modifying:
   ```bash
   # Search for term in all files
   rg "service-name" --type md --type yaml
   # Also search for related terms (port, IP, hostname)
   rg "8080\|192\.168\.1\.50"
   ```

2. **List ALL affected files** before making any edits

3. **Edit ALL files together** - never commit partial changes

4. **Re-search after editing** to verify nothing was missed

### File Dependency Map

Changes to these files usually require checking the others:

| If you change... | Also check... |
|------------------|---------------|
| `docker/compose*.yml` (service) | `Makefile`, `scripts/setup-folders.sh`, `docs/network/rack-homelab-config.md` |
| `docs/network/rack-homelab-config.md` (IPs/ports) | `docs/network/firewall-config.md`, `docs/setup/*.md` |
| `docs/network/firewall-config.md` (rules) | `docs/network/rack-homelab-config.md` (IP groups referenced) |
| Any service port or IP | ALL docs in `docs/network/` and `docs/setup/` |
| Service hostname/container name | `docker/compose*.yml`, any *arr app config references |

### Common Failures

- Updating `compose.yml` but not `compose.media.yml`
- Changing an IP in one doc but not others
- Adding a service without updating Makefile AND setup scripts AND docs
- Editing one table without checking related tables in sibling files

---

## Project Overview

Infrastructure-as-code for a homelab: QNAP NAS (Docker media stack) + Lenovo Mini PC (Proxmox/Plex). Follows Trash Guides best practices.

### Repository Structure

```
homelab/
├── Makefile                 # Stack management (run `make help`)
├── docker/
│   ├── compose.yml          # Infrastructure: Pi-hole, Home Assistant, Portainer, Traefik
│   ├── compose.media.yml    # Media stack: *arr apps, download clients, monitoring
│   ├── .env.example         # Non-sensitive config template
│   └── .env.secrets.example # Credentials template (gitignored)
├── scripts/                 # Operational scripts (setup, backup, certs)
└── docs/
    ├── setup/               # Initial setup guides
    ├── network/             # Hardware layout, IP plan, firewall rules
    └── operations/          # Runbooks
```

---

## Key Technical Concepts

### Hardlinking (Critical)
All paths under `/share/data` must be on the same filesystem. Services mount `/share/data:/data` to enable hardlinks between downloads and media library.

### VPN Profiles
```bash
COMPOSE_PROFILES=vpn    # qBittorrent/NZBGet via Gluetun (recommended)
COMPOSE_PROFILES=novpn  # Direct connection
```
When using VPN, configure *arr apps with hostname `gluetun` (not `qbittorrent`/`nzbget`).

### Docker Socket Security
- **Socket Proxy**: Traefik and Watchtower use a proxy with limited API access
- **Portainer**: Direct socket access (requires full API for exec/volumes)

### Secrets
- `docker/.env` → Non-sensitive config (PUID, PGID, TZ)
- `docker/.env.secrets` → Passwords and API keys (gitignored)

---

## When Modifying...

### Compose Files
1. Use existing YAML anchors: `&common-env`, `&common-logging`, `&common-healthcheck`
2. Every service needs: `healthcheck`, `logging`, `deploy.resources`, `labels` (watchtower)
3. Maintain `depends_on` relationships
4. For hardlinks: mount `/share/data:/data` (not subdirectories)

### Adding New Services
1. Add to appropriate compose file (infrastructure vs media)
2. Update `scripts/setup-folders.sh` for config directories
3. Add health check to `Makefile` `health` target
4. Add WebUI URL to `Makefile` `show-urls` target
5. Update service table in `docs/network/rack-homelab-config.md`
6. Add firewall rules if inter-VLAN access needed → `docs/network/firewall-config.md`

### Firewall Rules
1. Rule order matters - processed sequentially
2. "Allow Established/Related" must be first
3. Use IP/Port groups for maintainability
4. Block rules come after specific allow rules
5. End with catch-all "Block All Inter-VLAN"

### Documentation
1. Check sibling files in same directory for similar structure
2. If data appears in multiple tables, update ALL of them
3. Verify internal links still work
4. Cross-reference with actual config values in compose files

---

## Trade-offs

When facing trade-offs, **ask the user**:
- Simplicity vs completeness
- Security vs convenience
- Standards vs customization

---

## Documentation Index

| Topic | File |
|-------|------|
| Hardware & IP plan | `docs/network/rack-homelab-config.md` |
| Firewall & VLAN config | `docs/network/firewall-config.md` |
| Proxmox setup | `docs/setup/proxmox-setup.md` |
| NAS setup | `docs/setup/nas-setup.md` |
| Network setup | `docs/setup/network-setup.md` |
| VPN setup (Gluetun) | `docs/setup/vpn-setup.md` |
| Reverse proxy (Traefik) | `docs/setup/reverse-proxy-setup.md` |
| Authelia SSO | `docs/setup/authelia-setup.md` |
| Notifications | `docs/setup/notifications-setup.md` |
| Backup procedures | `docs/operations/runbook-backup-restore.md` |
| Energy saving | `docs/operations/energy-saving-strategies.md` |

## Quick Commands

```bash
make help          # Show all commands
make up            # Start containers
make health        # Check services
make urls          # Show WebUI URLs
```
