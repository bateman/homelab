# CLAUDE.md - Homelab Repository Guide

## Project Overview

Infrastructure-as-code for a homelab: QNAP NAS (Docker media stack) + Lenovo Mini PC (Proxmox/Plex). Follows Trash Guides best practices with hardlinking support.

## Repository Structure

```
homelab/
├── Makefile                 # Stack management (run `make help` for commands)
├── docker/
│   ├── compose.yml          # Infrastructure: Pi-hole, Home Assistant, Portainer, Traefik
│   ├── compose.media.yml    # Media stack: *arr apps, download clients, monitoring
│   ├── .env.example         # Non-sensitive config template
│   └── .env.secrets.example # Credentials template (gitignored after copy)
├── scripts/                 # Operational scripts (setup, backup, certs)
└── docs/
    ├── setup/               # Initial setup guides (VPN, reverse proxy, notifications)
    ├── network/             # Hardware layout, IP plan, firewall rules
    └── operations/          # Backup/restore runbooks
```

**Reference docs instead of duplicating**: Hardware specs, IP addresses, service ports, and detailed procedures are in `docs/`. Don't repeat them here.

## Key Concepts

### Hardlinking (Critical)
All paths under `/share/data` must be on the same filesystem. Services mount `/share/data:/data` to enable hardlinks between downloads and media library.

### VPN Profiles
Download clients use Docker Compose profiles:
- `COMPOSE_PROFILES=vpn` → qBittorrent/NZBGet via Gluetun (recommended)
- `COMPOSE_PROFILES=novpn` → Direct connection

When using VPN, configure *arr apps with hostname `gluetun` (not `qbittorrent`/`nzbget`).

### Docker Socket Security
- **Socket Proxy**: Traefik and Watchtower use a proxy with limited API access
- **Portainer**: Direct socket access (requires full API for exec/volumes)

## Development Guidelines

### Mandatory: Cross-File Consistency (READ THIS FIRST)

**STOP. Before making ANY change, complete this checklist:**

1. **Search for ALL occurrences** of what you're modifying:
   - Use grep/ripgrep to find references across the entire repo
   - Check both code files AND documentation (`docs/`)
   - Look for the exact term AND related terms (e.g., changing a service name? Search for its port, hostname, container name too)

2. **Identify the full scope** before editing anything:
   - List ALL files that reference the thing you're changing
   - If modifying one doc page, check sibling pages in the same directory for similar patterns
   - Tables, lists, and configurations often span multiple files

3. **Make ALL related changes together**:
   - Never submit a change to one file without updating all related files
   - If you find 5 files that need updates, update all 5
   - Document what you changed and where

4. **Verify after changes**:
   - Re-run the search to confirm nothing was missed
   - Check that cross-references still work (links, paths, hostnames)

**Common consistency failures to avoid:**
- Updating a service in compose.yml but not compose.media.yml
- Changing an IP/port in one doc but not the network config docs
- Adding a service without updating Makefile, setup scripts, AND docs
- Modifying firewall rules without updating the rules table AND the IP groups
- Renaming something without grep-ing for all references first

### When Modifying Compose Files
1. Use existing YAML anchors: `&common-env`, `&common-logging`, `&common-healthcheck`
2. Every service must have: `healthcheck`, `logging`, `deploy.resources`, `labels` (watchtower)
3. Maintain `depends_on` relationships
4. For hardlink support: mount `/share/data:/data` (not subdirectories)

### When Adding New Services
1. Add to appropriate compose file (infrastructure vs media)
2. Update `scripts/setup-folders.sh` for new config directories
3. Add health check endpoint to `Makefile` `health` target
4. Add WebUI URL to `Makefile` `show-urls` target
5. Update service table in `docs/network/rack-homelab-config.md`
6. Add firewall rules if inter-VLAN access needed (document in `docs/network/firewall-config.md`)

### When Modifying Firewall Rules
1. Rule order matters - rules are processed sequentially
2. "Allow Established/Related" must be first
3. Use IP/Port groups for maintainability
4. Block rules come after specific allow rules
5. End with catch-all "Block All Inter-VLAN"

## Best Practices

### Makefile
- Use `.PHONY` for all non-file targets
- Provide `help` target with descriptions
- Use variables for repeated values
- Check prerequisites before operations (`check-docker`, `check-compose`)
- Use color output for status messages

### Docker Compose
- Set resource limits (`deploy.resources.limits`)
- Configure logging limits to prevent disk fill
- Use named networks for service isolation
- Prefer `depends_on` with `condition: service_healthy`

### Shell Scripts
- Start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Quote all variables: `"${VAR}"` not `$VAR`
- Use `[[ ]]` for conditionals (bash-specific but safer)
- Provide `--dry-run` and `--verbose` flags where appropriate
- Exit with meaningful codes (0=success, 1=error, 2=usage error)

### When Modifying Documentation

1. **Check sibling files** in the same directory for similar structure/content
2. **Update all related tables** - if data appears in multiple tables, update ALL of them
3. **Verify internal links** still work after renaming/moving sections
4. **Cross-reference with code** - docs should match actual config values
5. **Check the Documentation Index** in this file - add new docs there

**Documentation files are interconnected.** A change to `firewall-config.md` likely requires checking `rack-homelab-config.md`. Network changes affect setup guides. Always trace the dependencies.

## Trade-offs

When facing trade-offs (simplicity vs completeness, security vs convenience, standards vs customization), **ask the user** rather than making assumptions.

## Secrets Management

- `docker/.env` → Non-sensitive config (PUID, PGID, TZ)
- `docker/.env.secrets` → Passwords and API keys (gitignored)

API keys for *arr apps are stored in each service's config (Settings → General → API Key).

## Quick Reference

```bash
make help          # Show all available commands
make up            # Start all containers
make health        # Check all services
make urls          # Show WebUI URLs
make logs-SERVICE  # Logs for specific service
```

## Documentation Index

| Topic | File |
|-------|------|
| Hardware & IP plan | `docs/network/rack-homelab-config.md` |
| Firewall & VLAN config | `docs/network/firewall-config.md` |
| VPN setup (Gluetun) | `docs/setup/vpn-setup.md` |
| Reverse proxy (Traefik) | `docs/setup/reverse-proxy-setup.md` |
| Backup procedures | `docs/operations/runbook-backup-restore.md` |
| Energy saving strategies | `docs/operations/energy-saving-strategies.md` |
