## Add Homepage dashboard for service overview

### Summary
Add [Homepage](https://gethomepage.dev/) as a centralized dashboard for quick service access and real-time status monitoring.

### Motivation
Currently there's no single view of all services. Users must remember individual ports or use `make urls`. Homepage provides:
- Single-pane view of all services with live status
- Native API widgets showing real-time stats (queue sizes, disk usage, etc.)
- Low resource footprint (~50MB RAM vs Organizr ~150MB or Dashy ~120MB)

### Implementation

#### 1. Docker Compose Addition

Add to `docker/compose.yml` in the Infrastructure section:

```yaml
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    environment:
      TZ: ${TZ:-Europe/Rome}
      PUID: ${PUID:-1000}
      PGID: ${PGID:-100}
    volumes:
      - ./config/homepage:/app/config
      - /var/run/docker.sock:ro
    ports:
      - "3000:3000"
    networks:
      - infra_net
    restart: unless-stopped
    logging: *common-logging
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 32M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      - "traefik.enable=true"
      - "traefik.http.routers.homepage.rule=Host(`home.home.local`)"
      - "traefik.http.routers.homepage.entrypoints=websecure"
      - "traefik.http.routers.homepage.tls=true"
      - "traefik.http.routers.homepage.middlewares=authelia@docker"
      - "traefik.http.services.homepage.loadbalancer.server.port=3000"
```

#### 2. Configuration Files

Create `docker/config/homepage/services.yaml` with service groups for Media, Downloads, Infrastructure, and Monitoring. Each service needs:
- `href`: Traefik URL (e.g., `https://sonarr.home.local`)
- `icon`: Service icon (e.g., `sonarr.png`)
- `widget`: API integration with type, url, and key

#### 3. Required Updates

| File | Change |
|------|--------|
| `scripts/setup-folders.sh` | Add `make_dir "${CONFIG_ROOT}/homepage"` |
| `docs/setup/reverse-proxy-setup.md` | Add `home.home.local` DNS record |
| `Makefile` show-urls | Add Homepage URL |
| `Makefile` health | Add Homepage health check |

### Tasks

- [ ] Add Homepage service to `docker/compose.yml`
- [ ] Create `docker/config/homepage/` with services.yaml, settings.yaml, widgets.yaml
- [ ] Update `scripts/setup-folders.sh`
- [ ] Add DNS record to reverse-proxy-setup.md
- [ ] Add to Makefile health check and show-urls
- [ ] Document API key retrieval in setup guide

### Notes

- API keys retrieved from each service's Settings → General → API Key
- Docker socket access is read-only for container status only
