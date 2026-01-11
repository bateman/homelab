## Replace Recyclarr with Profilarr for quality profile management

### Summary
Migrate from Recyclarr (CLI/YAML-based) to Profilarr (Web UI) for managing Sonarr/Radarr custom formats and quality profiles.

### Current State

| Aspect | Recyclarr (Current) |
|--------|---------------------|
| Config | YAML file (`docker/recyclarr.yml`) |
| Profiles | WEB-1080p (Sonarr), HD Bluray + WEB (Radarr) |
| RAM | 256M limit |
| Data Source | Trash Guides (built-in) |
| Operation | Scheduled sync via cron |

### Profilarr Advantages

| Feature | Recyclarr | Profilarr |
|---------|-----------|-----------|
| Configuration | YAML files | Web UI |
| Version control | Manual | Built-in Git |
| Conflict resolution | Manual | Automatic |
| Multi-instance | Separate configs | Single dashboard |
| Learning curve | Moderate | Low |

### ⚠️ Critical: Trash Guides Compatibility

**Profilarr does NOT include Trash Guides by default.** It uses Dictionarry's database instead.

| Data Source | Pros | Cons |
|-------------|------|------|
| **Dictionarry** (default) | Official, stable | Different scoring than Trash Guides |
| **profilarr-trash-guides** | Trash Guides compatible | Unofficial, third-party maintained |
| **Dumpstarr** | Hybrid approach | Complex setup |

**Risk Assessment:**
- `profilarr-trash-guides` is maintained by community, not Profilarr team
- If repo stops syncing, profiles become stale
- Current Recyclarr setup uses official Trash Guides directly

**Recommendation:** Only proceed if Web UI benefit outweighs third-party dependency risk. Consider waiting for official Trash Guides support in Profilarr.

### Implementation

#### 1. Add Profilarr to `docker/compose.media.yml`

```yaml
  profilarr:
    image: ghcr.io/profilarr/profilarr:latest
    container_name: profilarr
    environment:
      <<: *common-env
    volumes:
      - ./config/profilarr:/app/data
    ports:
      - "6868:6868"
    networks:
      - media_net
    restart: unless-stopped
    logging: *common-logging
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6868/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 64M
    depends_on:
      - sonarr
      - radarr
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      - "traefik.enable=true"
      - "traefik.http.routers.profilarr.rule=Host(`profilarr.home.local`)"
      - "traefik.http.routers.profilarr.entrypoints=websecure"
      - "traefik.http.routers.profilarr.tls=true"
      - "traefik.http.routers.profilarr.middlewares=authelia@docker"
      - "traefik.http.services.profilarr.loadbalancer.server.port=6868"
```

#### 2. Migration Steps

1. **Document current state:**
   ```bash
   # Export current Sonarr/Radarr custom formats
   # Settings → Custom Formats → Export (note scores)
   ```

2. **Configure Profilarr:**
   - Add Sonarr/Radarr connections (Settings → Connections)
   - Add profilarr-trash-guides repository (Settings → Repositories)
   - Import profiles matching current setup

3. **Verify migration:**
   - Compare custom format scores
   - Test with a single show/movie
   - Monitor for 1 week before removing Recyclarr

4. **Remove Recyclarr:**
   ```bash
   # Only after successful verification
   docker stop recyclarr
   docker rm recyclarr
   # Remove from compose.media.yml
   # Remove docker/recyclarr.yml
   # Update Makefile (remove recyclarr-sync, recyclarr-config targets)
   ```

#### 3. Update Documentation

| File | Change |
|------|--------|
| `scripts/setup-folders.sh` | Add `make_dir "${CONFIG_ROOT}/profilarr"` |
| `docs/setup/reverse-proxy-setup.md` | Add `profilarr.home.local` DNS record |
| `docs/setup/nas-setup.md` | Update Recyclarr section to Profilarr |
| `Makefile` | Remove recyclarr targets, add profilarr health check |
| `README.md` | Update service list |

### Tasks

- [ ] Evaluate if Web UI benefit outweighs third-party dependency risk
- [ ] Add Profilarr service to `docker/compose.media.yml`
- [ ] Update `scripts/setup-folders.sh`
- [ ] Configure profilarr-trash-guides repository
- [ ] Connect Sonarr and Radarr instances
- [ ] Migrate WEB-1080p profile (Sonarr)
- [ ] Migrate HD Bluray + WEB profile (Radarr)
- [ ] Verify custom format scores match
- [ ] Run parallel with Recyclarr for 1 week
- [ ] Remove Recyclarr after verification
- [ ] Update Makefile targets
- [ ] Add DNS record to documentation
- [ ] Update nas-setup.md guide

### Alternative: Keep Recyclarr

If third-party dependency is unacceptable, consider keeping Recyclarr and:
- Document the YAML config better
- Add `make recyclarr-edit` target for easier access
- Current setup is stable and uses official Trash Guides

### Resource Impact

No change in RAM (both use ~256M limit).
