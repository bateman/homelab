## Add ebook and comics/manga stack (LazyLibrarian + Kapowarr + Calibre + Kavita)

### Summary
Expand media infrastructure with digital book and graphic novel management: automated discovery, library organization, and reading capabilities.

### Proposed Stack

| Service | Function | Port | RAM |
|---------|----------|------|-----|
| LazyLibrarian | Ebook automation (*arr-style) | 5299 | ~150 MB |
| Kapowarr | Comics/manga automation | 5656 | ~200 MB |
| Calibre | Library management + conversion | 8083 | ~500 MB |
| Kavita | Universal reader (epub/cbz/pdf) | 5000 | ~200 MB |
| **Total** | | | **~1.05 GB** |

> **Note:** Calibre-Web removed - Kavita provides superior reading experience with OPDS support, progress sync, and handles all formats. Calibre retained for library management and format conversion only.

### Folder Structure

Update `scripts/setup-folders.sh` to add:

```bash
# Books/Comics media directories (under DATA_ROOT)
make_dir "${DATA_ROOT}/media/books"
make_dir "${DATA_ROOT}/media/comics"
make_dir "${DATA_ROOT}/media/manga"

# Download directories (for hardlinking)
make_dir "${DATA_ROOT}/torrents/books"
make_dir "${DATA_ROOT}/torrents/comics"
make_dir "${DATA_ROOT}/usenet/books"
make_dir "${DATA_ROOT}/usenet/comics"

# Config directories
make_dir "${CONFIG_ROOT}/lazylibrarian"
make_dir "${CONFIG_ROOT}/kapowarr"
make_dir "${CONFIG_ROOT}/calibre"
make_dir "${CONFIG_ROOT}/kavita"
```

### Docker Compose

Add to `docker/compose.media.yml`:

```yaml
  # ===========================================================================
  # BOOKS / COMICS
  # ===========================================================================

  lazylibrarian:
    image: lscr.io/linuxserver/lazylibrarian:latest
    container_name: lazylibrarian
    environment:
      <<: *common-env
    volumes:
      - ./config/lazylibrarian:/config
      - /share/data:/data
    ports:
      - "5299:5299"
    networks:
      - media_net
    restart: unless-stopped
    logging: *common-logging
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5299"]
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
      - "traefik.http.routers.lazylibrarian.rule=Host(`books.home.local`)"
      - "traefik.http.routers.lazylibrarian.entrypoints=websecure"
      - "traefik.http.routers.lazylibrarian.tls=true"
      - "traefik.http.routers.lazylibrarian.middlewares=authelia@docker"
      - "traefik.http.services.lazylibrarian.loadbalancer.server.port=5299"

  kapowarr:
    image: mrcas/kapowarr:latest
    container_name: kapowarr
    environment:
      <<: *common-env
    volumes:
      - ./config/kapowarr:/app/db
      - /share/data:/data
    ports:
      - "5656:5656"
    networks:
      - media_net
    restart: unless-stopped
    logging: *common-logging
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5656"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 300M
        reservations:
          memory: 100M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      - "traefik.enable=true"
      - "traefik.http.routers.kapowarr.rule=Host(`comics.home.local`)"
      - "traefik.http.routers.kapowarr.entrypoints=websecure"
      - "traefik.http.routers.kapowarr.tls=true"
      - "traefik.http.routers.kapowarr.middlewares=authelia@docker"
      - "traefik.http.services.kapowarr.loadbalancer.server.port=5656"

  calibre:
    image: lscr.io/linuxserver/calibre:latest
    container_name: calibre
    environment:
      <<: *common-env
    volumes:
      - ./config/calibre:/config
      - /share/data/media/books:/books
    ports:
      - "8083:8080"
      - "8181:8181"  # Calibre content server
    networks:
      - media_net
    restart: unless-stopped
    logging: *common-logging
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 256M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      - "traefik.enable=true"
      - "traefik.http.routers.calibre.rule=Host(`calibre.home.local`)"
      - "traefik.http.routers.calibre.entrypoints=websecure"
      - "traefik.http.routers.calibre.tls=true"
      - "traefik.http.routers.calibre.middlewares=authelia@docker"
      - "traefik.http.services.calibre.loadbalancer.server.port=8080"

  kavita:
    image: jvmilazz0/kavita:latest
    container_name: kavita
    environment:
      TZ: ${TZ:-Europe/Rome}
    volumes:
      - ./config/kavita:/kavita/config
      - /share/data/media/books:/books:ro
      - /share/data/media/comics:/comics:ro
      - /share/data/media/manga:/manga:ro
    ports:
      - "5000:5000"
    networks:
      - media_net
    restart: unless-stopped
    logging: *common-logging
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000"]
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
      - "traefik.http.routers.kavita.rule=Host(`read.home.local`)"
      - "traefik.http.routers.kavita.entrypoints=websecure"
      - "traefik.http.routers.kavita.tls=true"
      - "traefik.http.routers.kavita.middlewares=authelia@docker"
      - "traefik.http.services.kavita.loadbalancer.server.port=5000"
```

### Prowlarr Indexer Setup

LazyLibrarian and Kapowarr require specific indexer types in Prowlarr:

| Content | Indexer Examples | Category |
|---------|------------------|----------|
| Ebooks | MAM, LibGen, AudioBookBay | Books |
| Comics | 32Pages, ComicBT | Comics |
| Manga | Nyaa, AnimeTosho | Manga/Anime |

> **Note:** Book/comic indexers are less common than TV/movie indexers. MAM (MyAnonamouse) requires invite.

### DNS Records

Add to `docs/setup/reverse-proxy-setup.md`:

| Domain | IP |
|--------|-----|
| `books.home.local` | 192.168.3.10 |
| `comics.home.local` | 192.168.3.10 |
| `calibre.home.local` | 192.168.3.10 |
| `read.home.local` | 192.168.3.10 |

### Configuration Flow

```
Prowlarr (indexers)
    ├── LazyLibrarian → qBittorrent/NZBGet → /data/torrents/books → Calibre → /data/media/books
    └── Kapowarr → qBittorrent/NZBGet → /data/torrents/comics → /data/media/comics
                                                                           ↓
                                                                       Kavita (reader)
                                                                           ↑
                                                               /data/media/manga (manual)
```

### Tasks

- [ ] Update `scripts/setup-folders.sh` with book/comic directories
- [ ] Add services to `docker/compose.media.yml`
- [ ] Add DNS records to `docs/setup/reverse-proxy-setup.md`
- [ ] Update Makefile `show-urls` and `health` targets
- [ ] Configure Prowlarr with book/comic indexers
- [ ] Connect LazyLibrarian to Prowlarr + download clients
- [ ] Connect Kapowarr to download clients
- [ ] Set up Calibre library at `/data/media/books`
- [ ] Configure Kavita library paths
- [ ] Document setup in `docs/setup/`

### Resource Impact

Total additional RAM: ~1.05 GB (reduced from 1.2 GB by removing Calibre-Web redundancy)
