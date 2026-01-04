# Reverse Proxy Setup - Traefik con Pi-hole DNS

> Guida per configurare Traefik come reverse proxy e Pi-hole come DNS per Tailscale

---

## Panoramica

Un reverse proxy permette di accedere ai servizi usando nomi leggibili (es. `sonarr.home.local`) invece di IP:porta. Questa guida documenta:

- **Traefik** come soluzione principale (auto-discovery Docker)
- **Nginx Proxy Manager** come alternativa (configurazione via WebUI)
- **Pi-hole + Tailscale** per risolvere gli stessi URL da locale e remoto

---

## Confronto Soluzioni

| Aspetto | Traefik | Nginx Proxy Manager |
|---------|---------|---------------------|
| **Configurazione** | Labels Docker + YAML | WebUI point-and-click |
| **Curva apprendimento** | Media | Bassa |
| **Auto-discovery Docker** | Nativo | No (manuale) |
| **Certificati SSL** | Let's Encrypt automatico | Let's Encrypt via UI |
| **Dashboard** | Avanzata | Semplice |
| **Risorse** | ~30MB RAM | ~50MB RAM |
| **Aggiunta nuovo servizio** | Aggiungi labels al container | Click in WebUI |
| **Ideale per** | Stack Docker esistente | Servizi misti/non-Docker |

**Raccomandazione**: Con lo stack Docker gia' configurato su NAS, **Traefik** si integra meglio grazie all'auto-discovery.

---

## Prerequisiti

- [ ] Stack Docker funzionante su NAS (192.168.3.10)
- [ ] Pi-hole configurato e attivo
- [ ] Tailscale installato su Proxmox (vedi [PROXMOX_SETUP.md](PROXMOX_SETUP.md))

---

## Fase 1: Configurazione Pi-hole come DNS Tailscale

> Questa configurazione permette di usare gli stessi URL (es. `sonarr.home.local`) sia dalla rete locale che da remoto via Tailscale.

### 1.1 Schema di Funzionamento

```
                    +-------------+
                    |   Pi-hole   |
                    |192.168.3.10 |
                    +------+------+
                           |
         +-----------------+------------------+
         |                 |                  |
    +----v----+      +-----v-----+     +------v------+
    |   LAN   |      | Tailscale |     |  Tailscale  |
    | Client  |      |  (casa)   |     |  (remoto)   |
    +---------+      +-----------+     +-------------+
         |                 |                  |
         |    DNS query: sonarr.home.local    |
         |                 |                  |
         +-----------------+------------------+
                           v
                   Tutti ricevono:
                    192.168.3.10
```

### 1.2 Configurare Tailscale per usare Pi-hole

1. Accedere a https://login.tailscale.com/admin/dns
2. In **Nameservers** → Add nameserver → Custom
3. Inserire: `192.168.3.10` (IP del NAS con Pi-hole)
4. Abilitare **Override local DNS**

> **Nota**: Assicurarsi che le subnet routes siano approvate (vedi Fase 6 in PROXMOX_SETUP.md)

### 1.3 Aggiungere Record DNS in Pi-hole

Accedere a Pi-hole: `http://192.168.3.10:8081`

**Local DNS → DNS Records**, aggiungere:

| Domain | IP |
|--------|-----|
| `traefik.home.local` | 192.168.3.10 |
| `sonarr.home.local` | 192.168.3.10 |
| `radarr.home.local` | 192.168.3.10 |
| `lidarr.home.local` | 192.168.3.10 |
| `prowlarr.home.local` | 192.168.3.10 |
| `bazarr.home.local` | 192.168.3.10 |
| `qbit.home.local` | 192.168.3.10 |
| `nzbget.home.local` | 192.168.3.10 |
| `pihole.home.local` | 192.168.3.10 |
| `ha.home.local` | 192.168.3.10 |
| `portainer.home.local` | 192.168.3.10 |
| `duplicati.home.local` | 192.168.3.10 |
| `plex.home.local` | 192.168.3.20 |

### 1.4 Verifica

```bash
# Da client in LAN
nslookup sonarr.home.local
# Deve restituire 192.168.3.10

# Da dispositivo remoto via Tailscale
tailscale ping 192.168.3.10
nslookup sonarr.home.local
# Deve restituire 192.168.3.10 (DNS via tunnel)
```

### Vantaggi di questa configurazione

- **Zero costi**: nessun dominio da acquistare
- **Stesso URL ovunque**: `sonarr.home.local` funziona in LAN e via Tailscale
- **Ad-blocking anche da remoto**: Pi-hole filtra anche il traffico Tailscale
- **Nessun port forwarding**: Tailscale gestisce l'accesso remoto

---

## Fase 2: Installazione Traefik (Soluzione Principale)

### 2.1 Aggiungere Traefik a compose.yml

Aggiungere il seguente servizio in `docker/compose.yml`:

```yaml
  # ============================================
  # TRAEFIK - Reverse Proxy
  # ============================================
  traefik:
    image: traefik:v3.2
    container_name: traefik
    restart: unless-stopped
    command:
      # API e Dashboard
      - --api.dashboard=true
      - --api.insecure=true
      # Provider Docker
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.network=proxy
      # Entrypoints
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      # Redirect HTTP -> HTTPS (opzionale per rete locale)
      # - --entrypoints.web.http.redirections.entryPoint.to=websecure
      # Logs
      - --log.level=INFO
      - --accesslog=true
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /share/container/traefik/config:/etc/traefik
      - /share/container/traefik/certs:/certs
    networks:
      - proxy
      - default
    environment:
      <<: *common-env
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      # Dashboard su traefik.home.local
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.home.local`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.entrypoints=web"
    healthcheck:
      test: ["CMD", "traefik", "healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      <<: *common-logging
    deploy:
      resources:
        limits:
          memory: 256M

networks:
  proxy:
    name: proxy
    driver: bridge
```

### 2.2 Aggiungere Labels ai Servizi Esistenti

Per ogni servizio che vuoi esporre via Traefik, aggiungi le labels. Esempio per Sonarr in `compose.media.yml`:

```yaml
  sonarr:
    # ... configurazione esistente ...
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      # Traefik
      - "traefik.enable=true"
      - "traefik.http.routers.sonarr.rule=Host(`sonarr.home.local`)"
      - "traefik.http.routers.sonarr.entrypoints=web"
      - "traefik.http.services.sonarr.loadbalancer.server.port=8989"
    networks:
      - proxy
      - default
```

### 2.3 Labels per tutti i servizi

Ecco le labels da aggiungere a ciascun servizio:

**Stack Media (compose.media.yml):**

```yaml
# Sonarr
- "traefik.enable=true"
- "traefik.http.routers.sonarr.rule=Host(`sonarr.home.local`)"
- "traefik.http.routers.sonarr.entrypoints=web"
- "traefik.http.services.sonarr.loadbalancer.server.port=8989"

# Radarr
- "traefik.enable=true"
- "traefik.http.routers.radarr.rule=Host(`radarr.home.local`)"
- "traefik.http.routers.radarr.entrypoints=web"
- "traefik.http.services.radarr.loadbalancer.server.port=7878"

# Lidarr
- "traefik.enable=true"
- "traefik.http.routers.lidarr.rule=Host(`lidarr.home.local`)"
- "traefik.http.routers.lidarr.entrypoints=web"
- "traefik.http.services.lidarr.loadbalancer.server.port=8686"

# Prowlarr
- "traefik.enable=true"
- "traefik.http.routers.prowlarr.rule=Host(`prowlarr.home.local`)"
- "traefik.http.routers.prowlarr.entrypoints=web"
- "traefik.http.services.prowlarr.loadbalancer.server.port=9696"

# Bazarr
- "traefik.enable=true"
- "traefik.http.routers.bazarr.rule=Host(`bazarr.home.local`)"
- "traefik.http.routers.bazarr.entrypoints=web"
- "traefik.http.services.bazarr.loadbalancer.server.port=6767"

# qBittorrent
- "traefik.enable=true"
- "traefik.http.routers.qbit.rule=Host(`qbit.home.local`)"
- "traefik.http.routers.qbit.entrypoints=web"
- "traefik.http.services.qbit.loadbalancer.server.port=8080"

# NZBGet
- "traefik.enable=true"
- "traefik.http.routers.nzbget.rule=Host(`nzbget.home.local`)"
- "traefik.http.routers.nzbget.entrypoints=web"
- "traefik.http.services.nzbget.loadbalancer.server.port=6789"
```

**Stack Infrastruttura (compose.yml):**

```yaml
# Pi-hole (WebUI)
- "traefik.enable=true"
- "traefik.http.routers.pihole.rule=Host(`pihole.home.local`)"
- "traefik.http.routers.pihole.entrypoints=web"
- "traefik.http.services.pihole.loadbalancer.server.port=80"

# Portainer
- "traefik.enable=true"
- "traefik.http.routers.portainer.rule=Host(`portainer.home.local`)"
- "traefik.http.routers.portainer.entrypoints=web"
- "traefik.http.services.portainer.loadbalancer.server.port=9000"

# Duplicati
- "traefik.enable=true"
- "traefik.http.routers.duplicati.rule=Host(`duplicati.home.local`)"
- "traefik.http.routers.duplicati.entrypoints=web"
- "traefik.http.services.duplicati.loadbalancer.server.port=8200"

# Home Assistant (nota: usa network_mode: host, richiede config manuale)
# Vedi sezione 2.5 per configurazione file
```

### 2.4 Creare Directory Config

```bash
mkdir -p /share/container/traefik/{config,certs}
```

### 2.5 Configurazione Home Assistant (network_mode: host)

Home Assistant usa `network_mode: host`, quindi non puo' usare le labels Docker. Creare un file di configurazione:

```bash
cat > /share/container/traefik/config/home-assistant.yml << 'EOF'
http:
  routers:
    homeassistant:
      rule: "Host(`ha.home.local`)"
      service: homeassistant
      entryPoints:
        - web

  services:
    homeassistant:
      loadBalancer:
        servers:
          - url: "http://192.168.3.10:8123"
EOF
```

Aggiungere a Traefik in compose.yml:

```yaml
command:
  # ... altre opzioni ...
  - --providers.file.directory=/etc/traefik
  - --providers.file.watch=true
```

### 2.6 Avvio e Verifica

```bash
# Creare network proxy
docker network create proxy

# Riavviare stack
make restart

# Verificare Traefik
docker logs traefik

# Accedere alla dashboard
# http://traefik.home.local:8080 oppure http://192.168.3.10:8080
```

### 2.7 Test Accesso via Nome

```bash
# Da browser o curl
curl http://sonarr.home.local
curl http://radarr.home.local
curl http://pihole.home.local
```

---

## Alternativa: Nginx Proxy Manager

> Usa NPM se preferisci configurare via interfaccia grafica o hai servizi non-Docker.

### Installazione su Proxmox (LXC Container)

```bash
# Creare LXC container (ID 101)
# Installare Docker
apt update && apt install docker.io docker-compose -y

# Creare directory
mkdir -p /opt/npm && cd /opt/npm

# docker-compose.yml per NPM
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF

docker-compose up -d
```

### Accesso e Configurazione

1. Accedere: `http://192.168.3.22:81`
2. Login default: `admin@example.com` / `changeme`
3. Cambiare password al primo accesso

### Aggiungere Proxy Host

Per ogni servizio:

1. **Hosts → Proxy Hosts → Add Proxy Host**
2. **Domain Names**: `sonarr.home.local`
3. **Scheme**: `http`
4. **Forward Hostname/IP**: `192.168.3.10`
5. **Forward Port**: `8989`
6. **Block Common Exploits**: abilitato
7. **Websockets Support**: abilitato (per Home Assistant)

### Quando preferire NPM

- Configurazione visuale senza modificare file YAML
- Servizi non-Docker (es. Proxmox WebUI, dispositivi di rete)
- SSL con Let's Encrypt via interfaccia guidata
- Utenti meno esperti con Docker

---

## Fase 3: HTTPS con Certificati Locali (Opzionale)

Per HTTPS in rete locale senza dominio pubblico, usare certificati self-signed o mkcert.

### 3.1 Generare Certificati con mkcert

```bash
# Installare mkcert
apt install libnss3-tools
wget -O mkcert https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
chmod +x mkcert && mv mkcert /usr/local/bin/

# Creare CA locale
mkcert -install

# Generare certificato wildcard
mkcert -cert-file /share/container/traefik/certs/local.crt \
       -key-file /share/container/traefik/certs/local.key \
       "*.home.local" "home.local"
```

### 3.2 Configurare Traefik per HTTPS

Aggiungere a `command` in compose.yml:

```yaml
command:
  # ... altre opzioni ...
  # Certificato locale
  - --entrypoints.websecure.http.tls=true
  - --providers.file.filename=/etc/traefik/tls.yml
```

Creare `/share/container/traefik/config/tls.yml`:

```yaml
tls:
  certificates:
    - certFile: /certs/local.crt
      keyFile: /certs/local.key
  stores:
    default:
      defaultCertificate:
        certFile: /certs/local.crt
        keyFile: /certs/local.key
```

### 3.3 Installare CA sui Client

Copiare il file CA (`~/.local/share/mkcert/rootCA.pem`) sui dispositivi client e installarlo come certificato attendibile.

---

## Riepilogo Accessi

### Con Traefik configurato

| Servizio | URL | Porta diretta (backup) |
|----------|-----|------------------------|
| Dashboard Traefik | http://traefik.home.local | :8080 |
| Sonarr | http://sonarr.home.local | :8989 |
| Radarr | http://radarr.home.local | :7878 |
| Lidarr | http://lidarr.home.local | :8686 |
| Prowlarr | http://prowlarr.home.local | :9696 |
| Bazarr | http://bazarr.home.local | :6767 |
| qBittorrent | http://qbit.home.local | :8080 |
| NZBGet | http://nzbget.home.local | :6789 |
| Pi-hole | http://pihole.home.local | :8081 |
| Home Assistant | http://ha.home.local | :8123 |
| Portainer | http://portainer.home.local | :9443 |
| Duplicati | http://duplicati.home.local | :8200 |
| Plex | http://plex.home.local | :32400 |

> **Nota**: Gli URL funzionano sia dalla rete locale che da remoto via Tailscale (grazie a Pi-hole come DNS).

---

## Troubleshooting

### DNS non risolve

```bash
# Verificare che Pi-hole sia raggiungibile
ping 192.168.3.10

# Verificare record DNS in Pi-hole
# WebUI → Local DNS → DNS Records

# Forzare uso Pi-hole come DNS
# Linux: /etc/resolv.conf → nameserver 192.168.3.10
# Windows: Impostazioni rete → DNS: 192.168.3.10
```

### Traefik non trova i container

```bash
# Verificare network proxy
docker network ls | grep proxy

# Verificare che i container siano sulla rete proxy
docker network inspect proxy

# Verificare labels
docker inspect sonarr | grep -A 20 Labels
```

### 502 Bad Gateway

```bash
# Verificare che il servizio backend sia attivo
docker ps | grep sonarr
curl http://192.168.3.10:8989

# Verificare logs Traefik
docker logs traefik --tail 50
```

### Accesso remoto non funziona

```bash
# Verificare Tailscale
tailscale status

# Verificare DNS Tailscale
# https://login.tailscale.com/admin/dns
# Deve mostrare 192.168.3.10 come nameserver

# Verificare subnet routes approvate
# https://login.tailscale.com/admin/machines
```

---

## Note

- **Porte dirette**: Restano accessibili come backup se Traefik ha problemi
- **Home Assistant**: Richiede configurazione file separata (network_mode: host)
- **Plex**: Se su Proxmox, aggiungere record DNS che punta a 192.168.3.20
- **Aggiornamenti**: Watchtower aggiorna automaticamente Traefik
