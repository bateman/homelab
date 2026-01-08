# Guida VPN per Download Clients

> Setup Gluetun come container VPN per proteggere qBittorrent e NZBGet

---

## Panoramica

Questa guida spiega come configurare **Gluetun** come container VPN per instradare il traffico dei download clients attraverso una connessione VPN sicura.

### Perché Serve una VPN per i Download Clients?

| Rischio senza VPN | Protezione con VPN |
|-------------------|---------------------|
| ISP vede tutto il traffico | Traffico criptato, invisibile all'ISP |
| IP reale esposto (torrent: ai peer) | IP del server VPN visibile |
| Possibili lettere DMCA | IP non riconducibile a te |
| Throttling dall'ISP | ISP non può identificare il tipo di traffico |

### Perché Gluetun?

[Gluetun](https://github.com/qdm12/gluetun) è il container VPN più usato per questo scopo:

- **Kill switch integrato**: se la VPN cade, il traffico si ferma automaticamente
- **Supporta 30+ provider VPN**: Mullvad, NordVPN, Surfshark, PIA, ProtonVPN, etc.
- **Port forwarding automatico**: per alcuni provider (Mullvad, PIA, ProtonVPN)
- **Health checks**: riavvio automatico se la connessione fallisce
- **Leggero**: ~15MB RAM

---

## Pre-requisiti

### Account VPN

Serve un account con un provider VPN supportato da Gluetun. Provider consigliati:

| Provider | Port Forwarding | Prezzo | Note |
|----------|-----------------|--------|------|
| [Mullvad](https://mullvad.net/) | No (rimosso 2023) | €5/mese | Privacy-first, no email richiesta |
| [ProtonVPN](https://protonvpn.com/) | Sì (Plus) | €5-10/mese | Svizzero, open source |
| [AirVPN](https://airvpn.org/) | Sì | €7/mese | Ottimo per P2P, port forwarding incluso |
| [Private Internet Access](https://www.privateinternetaccess.com/) | Sì | €2-3/mese | Economico, buon supporto P2P |

> **Port forwarding** è importante per velocità torrent ottimali. Permette connessioni in ingresso dai peer. Se il tuo provider non lo supporta (es. Mullvad), i torrent funzioneranno comunque ma potrebbero essere più lenti.

### Credenziali VPN

Recupera le credenziali dal tuo provider. Vedi la sezione [Configurazioni per Provider Specifici](#configurazioni-per-provider-specifici) per istruzioni dettagliate per ogni provider.

---

## Configurazione

### 1. Variabili d'Ambiente

Aggiungi le seguenti variabili a `docker/.env.secrets`:

```bash
# -----------------------------------------------------------------------------
# VPN (Gluetun)
# -----------------------------------------------------------------------------
# Configura secondo il tuo provider VPN
# Documentazione: https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers

# Provider VPN (es: mullvad, nordvpn, protonvpn, private internet access, etc.)
VPN_SERVICE_PROVIDER=nordvpn

# Tipo VPN: wireguard oppure openvpn
# - WireGuard: Mullvad, ProtonVPN
# - OpenVPN: NordVPN, PIA, Surfshark
VPN_TYPE=openvpn

# Server location
SERVER_COUNTRIES=Switzerland

# --- Per OpenVPN (NordVPN, PIA, Surfshark) ---
OPENVPN_USER=your_service_username
OPENVPN_PASSWORD=your_service_password

# --- Per WireGuard (Mullvad, ProtonVPN) ---
# WIREGUARD_PRIVATE_KEY=your_private_key_here
# WIREGUARD_ADDRESSES=10.x.x.x/32

# --- Port Forwarding (solo provider che lo supportano: ProtonVPN, PIA, AirVPN) ---
# VPN_PORT_FORWARDING=on
```

### 2. Aggiungi Gluetun al Compose

Aggiungi questo servizio a `docker/compose.media.yml` **prima** di qBittorrent:

```yaml
  # ===========================================================================
  # VPN CONTAINER
  # ===========================================================================

  gluetun:
    image: qmcgaw/gluetun:latest
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    environment:
      # Provider e tipo connessione
      - VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER}
      - VPN_TYPE=${VPN_TYPE:-openvpn}
      - SERVER_COUNTRIES=${SERVER_COUNTRIES:-Switzerland}
      - TZ=${TZ:-Europe/Rome}
      # OpenVPN (NordVPN, PIA, Surfshark)
      - OPENVPN_USER=${OPENVPN_USER:-}
      - OPENVPN_PASSWORD=${OPENVPN_PASSWORD:-}
      # WireGuard (Mullvad, ProtonVPN) - lasciare vuoto se si usa OpenVPN
      - WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY:-}
      - WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES:-}
      # Port forwarding (opzionale, solo ProtonVPN/PIA/AirVPN)
      - VPN_PORT_FORWARDING=${VPN_PORT_FORWARDING:-off}
      # Health check
      - HEALTH_TARGET_ADDRESS=1.1.1.1:443
      - HEALTH_VPN_DURATION_INITIAL=30s
    volumes:
      - ./config/gluetun:/gluetun
    ports:
      # Porte esposte per qBittorrent (attraverso VPN)
      - "8080:8080"           # qBittorrent WebUI
      - "${QBIT_PORT:-50413}:${QBIT_PORT:-50413}"      # qBittorrent torrent port
      - "${QBIT_PORT:-50413}:${QBIT_PORT:-50413}/udp"  # qBittorrent torrent port UDP
      # Porta esposta per NZBGet (attraverso VPN)
      - "6789:6789"           # NZBGet WebUI
    networks:
      - media_net
      - proxy
    restart: unless-stopped
    logging: *common-logging
    healthcheck:
      test: ["CMD", "/gluetun-entrypoint", "healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 64M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

### 3. Modifica qBittorrent per Usare la VPN

Modifica il servizio `qbittorrent` in `docker/compose.media.yml`:

```yaml
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    # USA LA RETE DI GLUETUN invece della rete diretta
    network_mode: "service:gluetun"
    environment:
      <<: *common-env
      WEBUI_PORT: 8080
    volumes:
      - ./config/qbittorrent:/config
      - /share/data:/data
    # RIMUOVI la sezione ports - sono gestite da gluetun
    # ports:
    #   - "${QBIT_PORT:-50413}:${QBIT_PORT:-50413}"
    #   - "${QBIT_PORT:-50413}:${QBIT_PORT:-50413}/udp"
    #   - "8080:8080"
    # RIMUOVI networks - usa la rete di gluetun
    # networks:
    #   - media_net
    #   - proxy
    restart: unless-stopped
    logging: *common-logging
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      <<: *common-healthcheck
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 256M
    depends_on:
      gluetun:
        condition: service_healthy
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      # Traefik labels devono stare su gluetun, non qbittorrent
      # - "traefik.enable=true"
      # ...
```

### 4. Modifica NZBGet per Usare la VPN

Modifica il servizio `nzbget` in `docker/compose.media.yml`:

```yaml
  nzbget:
    image: lscr.io/linuxserver/nzbget:latest
    container_name: nzbget
    # USA LA RETE DI GLUETUN invece della rete diretta
    network_mode: "service:gluetun"
    environment:
      <<: *common-env
    volumes:
      - ./config/nzbget:/config
      - /share/data:/data
    # RIMUOVI la sezione ports - sono gestite da gluetun
    # ports:
    #   - "6789:6789"
    # RIMUOVI networks - usa la rete di gluetun
    # networks:
    #   - media_net
    #   - proxy
    restart: unless-stopped
    logging: *common-logging
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6789"]
      <<: *common-healthcheck
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 128M
    depends_on:
      gluetun:
        condition: service_healthy
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      # Traefik labels devono stare su gluetun, non nzbget
      # - "traefik.enable=true"
      # ...
```

### 5. Sposta Label Traefik su Gluetun

Poiché qBittorrent e NZBGet usano la rete di Gluetun, le label Traefik per entrambi vanno sul container Gluetun:

```yaml
  gluetun:
    # ... configurazione esistente ...
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      # Traefik per qBittorrent
      - "traefik.enable=true"
      - "traefik.http.routers.qbit.rule=Host(`qbit.home.local`)"
      - "traefik.http.routers.qbit.entrypoints=websecure"
      - "traefik.http.routers.qbit.tls=true"
      - "traefik.http.services.qbit.loadbalancer.server.port=8080"
      # Traefik per NZBGet
      - "traefik.http.routers.nzbget.rule=Host(`nzbget.home.local`)"
      - "traefik.http.routers.nzbget.entrypoints=websecure"
      - "traefik.http.routers.nzbget.tls=true"
      - "traefik.http.services.nzbget.loadbalancer.server.port=6789"
```

### 6. Crea Cartella Config Gluetun

Aggiungi a `scripts/setup-folders.sh`:

```bash
mkdir -p "${CONFIG_BASE}/gluetun"
```

Oppure crea manualmente:

```bash
mkdir -p /share/container/mediastack/config/gluetun
```

---

## Configurazioni per Provider Specifici

### Mullvad (WireGuard) - Consigliato

```bash
# .env.secrets
VPN_SERVICE_PROVIDER=mullvad
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=<tua_chiave_privata>
WIREGUARD_ADDRESSES=10.x.x.x/32
SERVER_COUNTRIES=Switzerland
```

Per ottenere le credenziali:
1. Vai su https://mullvad.net/account
2. Scarica una configurazione WireGuard
3. Apri il file `.conf` e copia `PrivateKey` e `Address`

### ProtonVPN (WireGuard con Port Forwarding)

```bash
# .env.secrets
VPN_SERVICE_PROVIDER=protonvpn
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=<tua_chiave_privata>
WIREGUARD_ADDRESSES=10.x.x.x/32
SERVER_COUNTRIES=Switzerland
VPN_PORT_FORWARDING=on
```

Per ottenere le credenziali:
1. Vai su https://account.protonvpn.com/downloads
2. Genera configurazione WireGuard (richiede piano Plus o superiore)
3. Copia `PrivateKey` e `Address`

> **Nota**: Il port forwarding ProtonVPN richiede un piano Plus o superiore.

### NordVPN (OpenVPN)

```bash
# .env.secrets
VPN_SERVICE_PROVIDER=nordvpn
VPN_TYPE=openvpn
OPENVPN_USER=<tuo_service_username>
OPENVPN_PASSWORD=<tua_service_password>
SERVER_COUNTRIES=Switzerland
```

Per ottenere le credenziali:
1. Accedi a https://my.nordaccount.com/
2. Vai su **NordVPN** → **Configurazione manuale**
3. Verifica la tua identità (email)
4. Copia **Service username** e **Service password** (NON sono le credenziali di login!)

> **Importante**: NordVPN richiede le credenziali "Service credentials", non username/password dell'account. Le trovi nel pannello sotto "Manual setup".

### Private Internet Access (OpenVPN con Port Forwarding)

```bash
# .env.secrets
VPN_SERVICE_PROVIDER=private internet access
VPN_TYPE=openvpn
OPENVPN_USER=<tuo_username>
OPENVPN_PASSWORD=<tua_password>
SERVER_REGIONS=Switzerland
VPN_PORT_FORWARDING=on
```

> **Nota**: PIA usa `SERVER_REGIONS` invece di `SERVER_COUNTRIES`.

---

## Verifica Funzionamento

### 1. Avvio e Verifica Connessione VPN

```bash
# Avvia lo stack
make up

# Verifica logs Gluetun
docker logs gluetun | grep -i "connected\|healthy"

# Output atteso:
# INFO [vpn] connected to server...
# INFO [healthcheck] healthy!
```

### 2. Verifica IP Pubblico

```bash
# IP dell'host (senza VPN)
curl -s https://ipinfo.io/ip
# Output: <tuo_IP_reale>

# IP dei download clients (attraverso VPN)
docker exec gluetun curl -s https://ipinfo.io/ip
# Output: <IP_del_server_VPN>  ← Deve essere DIVERSO dal tuo IP reale!
```

Sia qBittorrent che NZBGet usano questo stesso IP VPN per tutte le connessioni.

### 3. Verifica Kill Switch

```bash
# Simula disconnessione VPN
docker exec gluetun pkill -f wireguard

# Prova a raggiungere internet da qBittorrent
docker exec gluetun curl -s --max-time 5 https://ipinfo.io/ip
# Output: (timeout o errore) ← Kill switch funziona!

# Riavvia per ripristinare
docker restart gluetun
```

### 4. Verifica Porta qBittorrent

Se il provider supporta port forwarding:

```bash
# Verifica porta assegnata
docker exec gluetun cat /gluetun/forwarded_port
# Output: 12345 (esempio)
```

Configura questa porta in qBittorrent:
1. Options → Connection → Listening Port
2. Inserisci la porta mostrata sopra
3. Salva

Verifica con un port checker online o:
```bash
# Da fuori la rete locale
nc -zv <IP_VPN> <porta_forwarded>
```

---

## Troubleshooting

| Problema | Causa Probabile | Soluzione |
|----------|-----------------|-----------|
| Gluetun non si connette | Credenziali errate | Verifica `.env.secrets`, rigenera credenziali |
| `AUTH_FAILED` | Username/password errati | Per Mullvad: usa private key, non account number |
| qBittorrent/NZBGet non raggiungibile | Porte non esposte su gluetun | Verifica sezione `ports` di gluetun |
| Velocità basse | Server VPN lontano | Cambia `SERVER_COUNTRIES` |
| Torrenti "stalled" | No port forwarding | Verifica supporto provider o cambia provider |
| Container in restart loop | `/dev/net/tun` non disponibile | Verifica che il modulo tun sia caricato sul NAS |
| *arr non raggiunge download clients | network_mode errato | Verifica che qbit/nzbget usino `network_mode: "service:gluetun"` |

### Verificare Modulo TUN

```bash
# Sul NAS via SSH
lsmod | grep tun

# Se non presente, caricarlo
insmod /lib/modules/$(uname -r)/tun.ko
# Oppure
modprobe tun
```

Su QNAP, potrebbe essere necessario abilitare il modulo permanentemente. Verifica la documentazione Container Station.

### Logs Utili

```bash
# Logs completi Gluetun
docker logs -f gluetun

# Solo errori
docker logs gluetun 2>&1 | grep -i error

# Stato connessione
docker exec gluetun wget -qO- https://ipinfo.io
```

---

## Riferimenti

- [Gluetun Wiki](https://github.com/qdm12/gluetun-wiki)
- [Lista Provider Supportati](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)
- [Trash Guides - VPN Setup](https://trash-guides.info/Downloaders/qBittorrent/VPN/)
- [LinuxServer qBittorrent](https://docs.linuxserver.io/images/docker-qbittorrent/)
- [LinuxServer NZBGet](https://docs.linuxserver.io/images/docker-nzbget/)
