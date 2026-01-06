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

### 2.1 Configurazione gia' inclusa

Traefik e' gia' configurato in `docker/compose.yml` con:
- **HTTPS attivo** con certificato self-signed per `*.home.local`
- Redirect automatico HTTP → HTTPS
- Dashboard accessibile via reverse proxy su `traefik.home.local`
- Auto-discovery Docker sulla rete `homelab_proxy`
- Provider file per servizi non-Docker (Home Assistant)
- Labels Traefik gia' aggiunte a tutti i servizi

**Accesso Dashboard**: https://traefik.home.local (richiede DNS Pi-hole configurato)

### 2.2 Servizi gia' configurati

Le labels Traefik sono gia' aggiunte a tutti i servizi nei file compose:

| Servizio | URL Traefik (HTTPS) | Porta diretta (HTTP) |
|----------|---------------------|----------------------|
| Sonarr | https://sonarr.home.local | :8989 |
| Radarr | https://radarr.home.local | :7878 |
| Lidarr | https://lidarr.home.local | :8686 |
| Prowlarr | https://prowlarr.home.local | :9696 |
| Bazarr | https://bazarr.home.local | :6767 |
| qBittorrent | https://qbit.home.local | :8080 |
| NZBGet | https://nzbget.home.local | :6789 |
| Huntarr | https://huntarr.home.local | :9705 |
| Cleanuparr | https://cleanuparr.home.local | :11011 |
| Pi-hole | https://pihole.home.local | :8081 |
| Portainer | https://portainer.home.local | :9443 (HTTPS) |
| Duplicati | https://duplicati.home.local | :8200 |
| Home Assistant | https://ha.home.local | :8123 |
| Traefik Dashboard | https://traefik.home.local | (via reverse proxy) |

### 2.3 Configurazione Home Assistant

Home Assistant usa `network_mode: host`, quindi non puo' usare le labels Docker.
La configurazione e' gia' presente in `docker/config/traefik/homeassistant.yml`.

### 2.4 Generazione Certificati HTTPS

Prima di avviare lo stack, generare i certificati self-signed:

```bash
# Generare certificato wildcard per *.home.local
./scripts/generate-certs.sh

# I certificati vengono creati in:
# - docker/config/traefik/certs/home.local.crt
# - docker/config/traefik/certs/home.local.key
```

Il certificato e' valido 10 anni e copre:
- `*.home.local` (tutti i sottodomini)
- `home.local` (dominio base)

### 2.5 Avvio e Verifica

```bash
# Creare struttura cartelle (include traefik)
make setup

# Generare certificati HTTPS
./scripts/generate-certs.sh

# Avviare stack
make up

# Verificare Traefik
docker logs traefik

# Accedere alla dashboard (richiede DNS Pi-hole configurato)
# https://traefik.home.local
```

### 2.6 Test Accesso via Nome

```bash
# Da browser o curl (-k ignora certificato self-signed)
curl -k https://sonarr.home.local
curl -k https://radarr.home.local
curl -k https://pihole.home.local
```

> **Nota**: Il browser mostrera' un warning al primo accesso perche' il certificato e' self-signed. E' normale e sicuro per uso interno. Accetta il certificato una volta e il warning non apparira' piu'.

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

## Fase 3: Accettare il Certificato Self-Signed

HTTPS e' abilitato di default con certificati self-signed. Il traffico e' cifrato, ma i browser mostreranno un warning perche' il certificato non e' emesso da una CA pubblica.

### 3.1 Accettare nel Browser (Metodo Semplice)

Al primo accesso a ogni servizio:

1. Il browser mostra "La connessione non e' privata" (o simile)
2. Click su **Avanzate** → **Procedi comunque**
3. Il certificato viene memorizzato e il warning non appare piu'

### 3.2 Importare il Certificato (Metodo Permanente)

Per eliminare il warning su tutti i servizi, importare il certificato come attendibile.

**Esportare il certificato dal NAS:**
```bash
# Il certificato e' in:
# docker/config/traefik/certs/home.local.crt
```

**Windows:**
1. Copiare `home.local.crt` sul PC
2. Doppio click → **Installa certificato**
3. Selezionare **Computer locale** → **Avanti**
4. **Colloca tutti i certificati nel seguente archivio** → **Sfoglia**
5. Selezionare **Autorita' di certificazione radice attendibili**
6. **Fine** → Riavviare browser

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain home.local.crt
```

**Linux (Chrome/Chromium):**
```bash
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "Homelab" -i home.local.crt
```

**Firefox (tutti i sistemi):**
1. Impostazioni → Privacy e sicurezza → Certificati → Mostra certificati
2. Tab **Autorita'** → **Importa**
3. Selezionare `home.local.crt`
4. Selezionare **Considera attendibile per identificare siti web**

### 3.3 Rigenerare i Certificati

Se i certificati scadono o vuoi rigenerarli:

```bash
./scripts/generate-certs.sh
# Rispondere 'y' per sovrascrivere
make restart
```

---

## Riepilogo Accessi

### Con Traefik configurato (HTTPS)

| Servizio | URL (HTTPS) | Porta diretta (HTTP, backup) |
|----------|-------------|------------------------------|
| Dashboard Traefik | https://traefik.home.local | (via reverse proxy) |
| Sonarr | https://sonarr.home.local | :8989 |
| Radarr | https://radarr.home.local | :7878 |
| Lidarr | https://lidarr.home.local | :8686 |
| Prowlarr | https://prowlarr.home.local | :9696 |
| Bazarr | https://bazarr.home.local | :6767 |
| qBittorrent | https://qbit.home.local | :8080 |
| NZBGet | https://nzbget.home.local | :6789 |
| Huntarr | https://huntarr.home.local | :9705 |
| Cleanuparr | https://cleanuparr.home.local | :11011 |
| Pi-hole | https://pihole.home.local | :8081 |
| Home Assistant | https://ha.home.local | :8123 |
| Portainer | https://portainer.home.local | :9443 (HTTPS) |
| Duplicati | https://duplicati.home.local | :8200 |
| Plex | https://plex.home.local | :32400 (su 192.168.3.20) |

> **Nota**: Gli URL funzionano sia dalla rete locale che da remoto via Tailscale (grazie a Pi-hole come DNS).
> HTTP (porta 80) viene automaticamente reindirizzato a HTTPS (porta 443).

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
