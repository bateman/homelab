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
- **Supporta 30+ provider VPN**: NordVPN, Mullvad, Surfshark, PIA, ProtonVPN, etc.
- **Port forwarding automatico**: per alcuni provider (ProtonVPN, PIA, AirVPN)
- **Health checks**: riavvio automatico se la connessione fallisce
- **Leggero**: ~15MB RAM

---

## Pre-requisiti

### Account VPN

Serve un account con un provider VPN supportato da Gluetun. Provider consigliati:

| Provider | Port Forwarding | Prezzo | Note |
|----------|-----------------|--------|------|
| [NordVPN](https://nordvpn.com/) | No | €3-5/mese | Popolare, molti server, veloce |
| [ProtonVPN](https://protonvpn.com/) | Sì (Plus) | €5-10/mese | Svizzero, open source |
| [AirVPN](https://airvpn.org/) | Sì | €7/mese | Ottimo per P2P, port forwarding incluso |
| [Private Internet Access](https://www.privateinternetaccess.com/) | Sì | €2-3/mese | Economico, buon supporto P2P |
| [Mullvad](https://mullvad.net/) | No (rimosso 2023) | €5/mese | Privacy-first, no email richiesta |

> **Port forwarding** è importante per velocità torrent ottimali. Permette connessioni in ingresso dai peer. Se il tuo provider non lo supporta (es. Mullvad), i torrent funzioneranno comunque ma potrebbero essere più lenti.

### Credenziali VPN

Recupera le credenziali dal tuo provider. Vedi la sezione [Configurazioni per Provider Specifici](#configurazioni-per-provider-specifici) per istruzioni dettagliate per ogni provider.

---

## Quick Start

La VPN è **già configurata** nei file compose tramite Docker Compose profiles. Devi solo:

1. **Configurare le credenziali VPN** in `docker/.env.secrets`
2. **Abilitare il profile VPN** in `docker/.env`
3. **Avviare lo stack** con `make up`

---

## Configurazione

### Step 1: Abilita il Profile VPN

In `docker/.env`, imposta:

```bash
COMPOSE_PROFILES=vpn
```

> **Alternativa senza VPN**: usa `COMPOSE_PROFILES=novpn` per avviare i download clients senza protezione VPN.

### Step 2: Configura Credenziali VPN

Aggiungi le credenziali del tuo provider a `docker/.env.secrets`:

```bash
# -----------------------------------------------------------------------------
# VPN (Gluetun) - REQUIRED when using COMPOSE_PROFILES=vpn
# -----------------------------------------------------------------------------
# Docs: https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers

# Provider VPN (required)
VPN_SERVICE_PROVIDER=nordvpn

# Connection type: openvpn or wireguard
VPN_TYPE=openvpn

# Server location
SERVER_COUNTRIES=Switzerland

# --- OpenVPN (NordVPN, PIA, Surfshark) ---
OPENVPN_USER=your_service_username
OPENVPN_PASSWORD=your_service_password

# --- WireGuard (Mullvad, ProtonVPN) - leave empty for OpenVPN ---
# WIREGUARD_PRIVATE_KEY=your_private_key_here
# WIREGUARD_ADDRESSES=10.x.x.x/32

# --- Port Forwarding (ProtonVPN, PIA, AirVPN only) ---
# VPN_PORT_FORWARDING=on
```

### Step 3: Avvia lo Stack

```bash
# Create folders (first time only)
make setup

# Start all services
make up

# Verify VPN is working
docker exec gluetun curl -s https://ipinfo.io/ip
# Should show VPN IP, NOT your real IP
```

### Step 4: Configura Hostname nelle *arr Apps (IMPORTANTE!)

Con il profile `vpn`, qBittorrent e NZBGet sono raggiungibili tramite l'hostname `gluetun`:

**In Sonarr/Radarr/Lidarr → Settings → Download Clients:**

| Download Client | Host | Port |
|-----------------|------|------|
| qBittorrent | `gluetun` | `8080` |
| NZBGet | `gluetun` | `6789` |

> **Perché?** I container con `network_mode: "service:gluetun"` condividono lo stack di rete con Gluetun. Quindi qBittorrent e NZBGet sono raggiungibili all'indirizzo di Gluetun.

---

## Profiles Disponibili

| Profile | Comando | Download Clients Host |
|---------|---------|----------------------|
| `vpn` | `COMPOSE_PROFILES=vpn make up` | `gluetun:8080` / `gluetun:6789` |
| `novpn` | `COMPOSE_PROFILES=novpn make up` | `qbittorrent:8080` / `nzbget:6789` |

**Quando cambi profile**, ricorda di aggiornare gli hostname nelle *arr apps!

---

## Configurazioni per Provider Specifici

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

### Mullvad (WireGuard)

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

> **Nota**: Mullvad non supporta più il port forwarding dal 2023.

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
# Simula disconnessione VPN (ferma il tunnel)
docker exec gluetun killall -STOP openvpn 2>/dev/null || docker exec gluetun killall -STOP wireguard-go 2>/dev/null

# Prova a raggiungere internet
docker exec gluetun curl -s --max-time 5 https://ipinfo.io/ip
# Output: (timeout o errore) ← Kill switch funziona!

# Riavvia per ripristinare
docker restart gluetun
```

> **Nota**: Il kill switch è gestito da iptables in Gluetun. Se la connessione VPN cade, tutto il traffico viene bloccato automaticamente.

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
