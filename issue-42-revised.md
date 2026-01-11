## Add centralized monitoring stack (Prometheus + Grafana + Loki)

### Summary
Implement unified metrics collection, visualization, and log aggregation to complement existing Uptime Kuma alerting.

### Architecture

| Service | Purpose | RAM |
|---------|---------|-----|
| Prometheus | Metrics collection/storage | ~200 MB |
| Grafana | Visualization dashboards | ~150 MB |
| Loki | Log aggregation | ~200 MB |
| Promtail | Log collector (sidecar) | ~50 MB |
| cAdvisor | Container metrics exporter | ~80 MB |
| Node Exporter | Host system metrics | ~40 MB |
| **Total** | | **~720 MB** |

### Relationship with Uptime Kuma

| Concern | Uptime Kuma | Prometheus/Grafana |
|---------|-------------|-------------------|
| Availability monitoring | ✅ Primary | Backup |
| Notifications | ✅ Telegram, email | AlertManager (optional) |
| Public status page | ✅ Built-in | Requires extra setup |
| Historical metrics | ❌ Limited | ✅ Long-term storage |
| Resource usage | ❌ No | ✅ CPU, RAM, disk, network |
| Log search | ❌ No | ✅ Loki |
| Dashboards | ❌ Basic | ✅ Full Grafana |

**Recommendation:** Keep Uptime Kuma for simple alerting/status page. Use Prometheus stack for deep metrics and troubleshooting.

### Implementation

#### 1. Create `docker/compose.monitoring.yml`

```yaml
version: "3.8"

networks:
  monitoring_net:
    driver: bridge

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    user: "${PUID:-1000}:${PGID:-100}"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    volumes:
      - ./config/prometheus:/etc/prometheus
      - ./data/prometheus:/prometheus
    ports:
      - "9090:9090"
    networks:
      - monitoring_net
      - infra_net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 128M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.home.local`)"
      - "traefik.http.routers.prometheus.entrypoints=websecure"
      - "traefik.http.routers.prometheus.tls=true"
      - "traefik.http.routers.prometheus.middlewares=authelia@docker"
      - "traefik.http.services.prometheus.loadbalancer.server.port=9090"

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    user: "${PUID:-1000}:${PGID:-100}"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin}
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_SERVER_ROOT_URL: https://grafana.home.local
    volumes:
      - ./config/grafana:/etc/grafana
      - ./data/grafana:/var/lib/grafana
    ports:
      - "3030:3000"
    networks:
      - monitoring_net
      - infra_net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 64M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.home.local`)"
      - "traefik.http.routers.grafana.entrypoints=websecure"
      - "traefik.http.routers.grafana.tls=true"
      - "traefik.http.routers.grafana.middlewares=authelia@docker"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"

  loki:
    image: grafana/loki:latest
    container_name: loki
    user: "${PUID:-1000}:${PGID:-100}"
    command: -config.file=/etc/loki/loki-config.yml
    volumes:
      - ./config/loki:/etc/loki
      - ./data/loki:/loki
    ports:
      - "3100:3100"
    networks:
      - monitoring_net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3100/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 128M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    command: -config.file=/etc/promtail/promtail-config.yml
    volumes:
      - ./config/promtail:/etc/promtail
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    networks:
      - monitoring_net
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 32M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    privileged: true
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    ports:
      - "8085:8080"
    networks:
      - monitoring_net
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 64M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    command:
      - '--path.rootfs=/host'
    volumes:
      - /:/host:ro
    ports:
      - "9100:9100"
    networks:
      - monitoring_net
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 64M
        reservations:
          memory: 16M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

#### 2. Prometheus Scrape Config

Create `docker/config/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'traefik'
    static_configs:
      - targets: ['traefik:8080']

  # *arr services (if metrics enabled)
  - job_name: 'sonarr'
    static_configs:
      - targets: ['sonarr:8989']
    metrics_path: /metrics

  - job_name: 'radarr'
    static_configs:
      - targets: ['radarr:7878']
    metrics_path: /metrics
```

#### 3. Recommended Grafana Dashboards

| Dashboard | ID | Purpose |
|-----------|-----|---------|
| Node Exporter Full | 1860 | Host system metrics |
| Docker Container | 893 | Container resource usage |
| Traefik 2 | 12250 | Reverse proxy metrics |
| Loki Logs | 13639 | Log exploration |

#### 4. Update Makefile

Add to `COMPOSE_FILES` (optional service):
```makefile
# To enable monitoring:
# COMPOSE_FILES := -f docker/compose.yml -f docker/compose.media.yml -f docker/compose.monitoring.yml
```

#### 5. DNS Records

Add to `docs/setup/reverse-proxy-setup.md`:

| Domain | IP |
|--------|-----|
| `prometheus.home.local` | 192.168.3.10 |
| `grafana.home.local` | 192.168.3.10 |

### Tasks

- [ ] Create `docker/compose.monitoring.yml`
- [ ] Create `docker/config/prometheus/prometheus.yml`
- [ ] Create `docker/config/loki/loki-config.yml`
- [ ] Create `docker/config/promtail/promtail-config.yml`
- [ ] Update `scripts/setup-folders.sh` with monitoring directories
- [ ] Add DNS records to documentation
- [ ] Document enabling monitoring stack in START_HERE.md
- [ ] Import recommended Grafana dashboards
- [ ] Configure Loki as Grafana data source

### Resource Impact

Total additional RAM: ~720 MB (as optional service, not loaded by default)

### Why Loki over ELK?

| Aspect | Loki | ELK Stack |
|--------|------|-----------|
| RAM | ~200 MB | 2-4 GB |
| Full-text search | Labels only | ✅ Full |
| Grafana native | ✅ Yes | Plugin required |
| Complexity | Low | High |

For homelab scale, Loki's simplicity and low resource usage outweighs ELK's search capabilities.
