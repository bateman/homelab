# Guida VPN per Download Clients

> Setup Gluetun come container VPN per proteggere qBittorrent (e opzionalmente NZBGet)

---

## Panoramica

Questa guida spiega come configurare **Gluetun** come container VPN per instradare il traffico torrent attraverso una connessione VPN sicura.

### Perché Serve una VPN per Torrent?

| Rischio senza VPN | Protezione con VPN |
|-------------------|---------------------|
| ISP vede tutto il traffico P2P | Traffico criptato, invisibile all'ISP |
| IP reale esposto ai peer | IP del server VPN visibile ai peer |
| Possibili lettere DMCA | IP non riconducibile a te |
| Throttling P2P dall'ISP | ISP non può identificare traffico P2P |

### Perché Gluetun?

[Gluetun](https://github.com/qdm12/gluetun) è il container VPN più usato per questo scopo:

- **Kill switch integrato**: se la VPN cade, il traffico si ferma automaticamente
- **Supporta 30+ provider VPN**: Mullvad, NordVPN, Surfshark, PIA, ProtonVPN, etc.
- **Port forwarding automatico**: per alcuni provider (Mullvad, PIA, ProtonVPN)
- **Health checks**: riavvio automatico se la connessione fallisce
- **Leggero**: ~15MB RAM

### VPN per Usenet (NZBGet)?

Per **Usenet la VPN è generalmente non necessaria**:

- Usenet usa connessioni SSL dirette ai provider (porta 563)
- Non c'è esposizione peer-to-peer dell'IP
- I provider Usenet non condividono informazioni con terzi
- Il traffico è già criptato end-to-end

Tuttavia, puoi instradare NZBGet attraverso la VPN se vuoi nascondere anche il traffico Usenet dal tuo ISP.

---

## Pre-requisiti

### Account VPN

Serve un account con un provider VPN supportato da Gluetun. Provider consigliati:

| Provider | Port Forwarding | Prezzo | Note |
|----------|-----------------|--------|------|
| [Mullvad](https://mullvad.net/) | Sì | €5/mese | Privacy-first, no email richiesta |
| [ProtonVPN](https://protonvpn.com/) | Sì (Plus) | €5-10/mese | Svizzero, open source |
| [AirVPN](https://airvpn.org/) | Sì | €7/mese | Ottimo per P2P |
| [Private Internet Access](https://www.privateinternetaccess.com/) | Sì | €2-3/mese | Economico |

> **Port forwarding** è importante per velocità torrent ottimali. Permette connessioni in ingresso dai peer.

### Credenziali VPN

Recupera le credenziali dal tuo provider. Esempio per Mullvad:

1. Accedi a https://mullvad.net/account
2. Genera un device token WireGuard (Settings → WireGuard keys)
3. Annota: Account number e Private key

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
VPN_SERVICE_PROVIDER=mullvad

# Per Mullvad (WireGuard):
WIREGUARD_PRIVATE_KEY=your_private_key_here
WIREGUARD_ADDRESSES=10.x.x.x/32
VPN_ENDPOINT_PORT=51820
SERVER_COUNTRIES=Switzerland

# Per altri provider con OpenVPN:
# OPENVPN_USER=your_username
# OPENVPN_PASSWORD=your_password
# SERVER_COUNTRIES=Netherlands
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
      - VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER:-mullvad}
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY}
      - WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES}
      - VPN_ENDPOINT_PORT=${VPN_ENDPOINT_PORT:-51820}
      - SERVER_COUNTRIES=${SERVER_COUNTRIES:-Switzerland}
      - TZ=${TZ:-Europe/Rome}
      # Port forwarding (se supportato dal provider)
      - VPN_PORT_FORWARDING=on
      - VPN_PORT_FORWARDING_PROVIDER=protonvpn
      # Health check endpoint
      - HEALTH_TARGET_ADDRESS=1.1.1.1:443
      - HEALTH_VPN_DURATION_INITIAL=30s
    volumes:
      - ./config/gluetun:/gluetun
    ports:
      # Porte esposte per qBittorrent (attraverso VPN)
      - "8080:8080"           # qBittorrent WebUI
      - "${QBIT_PORT:-50413}:${QBIT_PORT:-50413}"      # qBittorrent torrent port
      - "${QBIT_PORT:-50413}:${QBIT_PORT:-50413}/udp"  # qBittorrent torrent port UDP
      # Porta esposta per NZBGet se instradato via VPN (opzionale)
      # - "6789:6789"
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

### 4. Sposta Label Traefik su Gluetun

Poiché qBittorrent usa la rete di Gluetun, le label Traefik vanno sul container Gluetun:

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
```

### 5. Crea Cartella Config Gluetun

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

### ProtonVPN (WireGuard)

```bash
# .env.secrets
VPN_SERVICE_PROVIDER=protonvpn
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=<tua_chiave_privata>
WIREGUARD_ADDRESSES=10.x.x.x/32
SERVER_COUNTRIES=Switzerland
VPN_PORT_FORWARDING=on
VPN_PORT_FORWARDING_PROVIDER=protonvpn
```

Per ottenere le credenziali:
1. Vai su https://account.protonvpn.com/downloads
2. Genera configurazione WireGuard
3. Copia `PrivateKey` e `Address`

### NordVPN (OpenVPN)

```bash
# .env.secrets
VPN_SERVICE_PROVIDER=nordvpn
VPN_TYPE=openvpn
OPENVPN_USER=<tuo_username>
OPENVPN_PASSWORD=<tua_password>
SERVER_COUNTRIES=Netherlands
```

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

# IP di qBittorrent (attraverso VPN)
docker exec gluetun curl -s https://ipinfo.io/ip
# Output: <IP_del_server_VPN>  ← Deve essere DIVERSO!
```

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

## Configurazione Opzionale: NZBGet via VPN

Se vuoi instradare anche NZBGet attraverso la VPN:

### 1. Aggiungi Porta a Gluetun

```yaml
  gluetun:
    ports:
      # ... porte esistenti ...
      - "6789:6789"  # NZBGet WebUI
```

### 2. Modifica NZBGet

```yaml
  nzbget:
    image: lscr.io/linuxserver/nzbget:latest
    container_name: nzbget
    network_mode: "service:gluetun"
    environment:
      <<: *common-env
    volumes:
      - ./config/nzbget:/config
      - /share/data:/data
    # Rimuovi ports e networks
    restart: unless-stopped
    logging: *common-logging
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6789"]
      <<: *common-healthcheck
    depends_on:
      gluetun:
        condition: service_healthy
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

---

## Troubleshooting

| Problema | Causa Probabile | Soluzione |
|----------|-----------------|-----------|
| Gluetun non si connette | Credenziali errate | Verifica `.env.secrets`, rigenera credenziali |
| `AUTH_FAILED` | Username/password errati | Per Mullvad: usa private key, non account number |
| qBittorrent non raggiungibile | Porte non esposte su gluetun | Verifica sezione `ports` di gluetun |
| Velocità basse | Server VPN lontano | Cambia `SERVER_COUNTRIES` |
| Torrenti "stalled" | No port forwarding | Verifica supporto provider o cambia provider |
| Container in restart loop | `/dev/net/tun` non disponibile | Verifica che il modulo tun sia caricato sul NAS |

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
- [LinuxServer qBittorrent](https://docs.linuxserver.io/images/docker-qbittorrent)
