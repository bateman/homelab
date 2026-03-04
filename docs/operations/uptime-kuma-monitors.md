# Runbook — Uptime Kuma Monitors

> Procedure operative per aggiungere e gestire i monitor in Uptime Kuma

---

## Accesso

| Metodo | URL |
|--------|-----|
| Diretto | `http://192.168.3.10:3001` |
| Traefik (con Authelia SSO) | `https://uptime.home.local` |

---

## Tipi di Monitor

Uptime Kuma supporta diversi tipi di monitor. In questo homelab se ne usano quattro:

| Tipo | Quando usarlo | Esempio |
|------|---------------|---------|
| **HTTP(s)** | Il servizio espone un endpoint HTTP verificabile | Sonarr `/ping`, Authelia `/api/health` |
| **DNS** | Verificare che la risoluzione DNS funzioni | Pi-hole: query `pi.hole` |
| **Ping** | Il servizio non ha endpoint HTTP ma risponde a ICMP | Tailscale IP (`100.x.x.x`) |
| **Docker Container** | Il container non espone endpoint utili o richiedono autenticazione | Socket Proxy, Watchtower, Gluetun |

> [!NOTE]
> I monitor di tipo **Docker Container** funzionano perché Uptime Kuma ha accesso al Docker socket (montato read-only in `compose.yml`).

---

## Aggiungere un Monitor

1. Aprire Uptime Kuma → click **Add New Monitor** (pulsante in alto)
2. Selezionare il **Monitor Type** appropriato (vedi tabella sopra)
3. Compilare i campi:

| Campo | Valore consigliato |
|-------|-------------------|
| **Friendly Name** | Nome del servizio (es. `Sonarr`) |
| **URL / Hostname** | Vedi [Tabella Monitor](#tabella-monitor-per-servizio) |
| **Heartbeat Interval** | `60` secondi (standard) o `30` secondi (servizi critici) |
| **Retries** | `3` (evita falsi positivi durante i restart) |
| **Ignore TLS/SSL Errors** | Abilitare per endpoint HTTPS con certificati self-signed |

4. Nella sezione **Notifications**, abilitare `Home Assistant iOS` (vedi [notifications-setup.md](../setup/notifications-setup.md))
5. Click **Save**
6. Verificare che il monitor diventi verde entro 1-2 minuti

> [!TIP]
> Usa gli hostname dei container (es. `http://sonarr:8989`) anziché gli IP dell'host quando possibile. Uptime Kuma è sulla stessa rete Docker (`media_net`), quindi la risoluzione DNS interna è più affidabile.

---

## Tabella Monitor per Servizio

### Infrastructure (compose.yml)

| Servizio | Tipo | URL / Target | Note |
|----------|------|--------------|------|
| Traefik | HTTP(s) | `http://traefik:8080/ping` | Endpoint interno di ping; non usare `traefik.home.local` (bloccato da Authelia) |
| Authelia | HTTP(s) | `http://authelia:9091/api/health` | Endpoint health dedicato |
| Pi-hole | DNS | Query `pi.hole` @ `192.168.3.10` | Testa la risoluzione DNS, non solo la web UI |
| Portainer | HTTP(s) | `https://192.168.3.10:9443/api/system/status` | Abilitare "Ignore TLS/SSL errors" (cert self-signed) |
| Duplicati | HTTP(s) | `http://duplicati:8200` | Verifica semplice della web UI |
| Tailscale | Ping | IP Tailscale (`100.x.x.x`) | Verifica che il tunnel mesh sia raggiungibile |
| Socket Proxy | Docker Container | Container: `socket-proxy` | Interno, nessun endpoint HTTP esposto |
| Watchtower | Docker Container | Container: `watchtower` | L'endpoint metriche richiede auth; il monitor Docker è più semplice |
| Home Assistant | HTTP(s) | `http://192.168.3.10:8123/api/` | Usare l'IP dell'host — HA usa `network_mode: host` |

> [!NOTE]
> Non creare un monitor per Uptime Kuma stesso — non può monitorare in modo affidabile la propria disponibilità.

### Media Stack (compose.media.yml)

| Servizio | Tipo | URL / Target | Note |
|----------|------|--------------|------|
| Sonarr | HTTP(s) | `http://sonarr:8989/ping` | `/ping` ritorna 200 senza autenticazione |
| Radarr | HTTP(s) | `http://radarr:7878/ping` | Come sopra |
| Lidarr | HTTP(s) | `http://lidarr:8686/ping` | Come sopra |
| Prowlarr | HTTP(s) | `http://prowlarr:9696/ping` | Come sopra |
| Bazarr | HTTP(s) | `http://bazarr:6767/ping` | Come sopra |
| qBittorrent | HTTP(s) | `http://gluetun:8080` | Passa attraverso Gluetun (profilo VPN); usare `http://qbittorrent:8080` per novpn |
| NZBGet | HTTP(s) | `http://gluetun:6789` | Come sopra — passa attraverso la rete di Gluetun |
| Gluetun | Docker Container | Container: `gluetun` | L'health check integrato valida il tunnel VPN |
| FlareSolverr | HTTP(s) | `http://flaresolverr:8191/health` | Endpoint `/health` dedicato |
| Recyclarr | Docker Container | Container: `recyclarr` | Eseguito su schedule, nessuna web UI |
| Cleanuparr | HTTP(s) | `http://cleanuparr:11011/health` | Endpoint `/health` dedicato |

### Proxmox (192.168.3.20)

| Servizio | Tipo | URL / Target | Note |
|----------|------|--------------|------|
| Proxmox | HTTP(s) | `https://192.168.3.20:8006` | Abilitare "Ignore TLS/SSL errors" (cert self-signed) |
| Plex | HTTP(s) | `http://192.168.3.21:32400/web` | Plex gira in LXC su Proxmox |

---

## Checklist: Nuovo Servizio

Quando aggiungi un nuovo servizio Docker al homelab, segui questa checklist per il monitoraggio:

- [ ] Identificare il tipo di monitor appropriato (HTTP, DNS, Ping, Docker Container)
- [ ] Trovare l'endpoint di health check (controllare l'`healthcheck` nel compose file)
- [ ] Creare il monitor in Uptime Kuma con le impostazioni consigliate
- [ ] Abilitare la notifica `Home Assistant iOS`
- [ ] Verificare che il monitor risulti verde
- [ ] Aggiungere il servizio alla tabella in questo documento
- [ ] Aggiornare la tabella in [notifications-setup.md](../setup/notifications-setup.md) se necessario

---

## Status Page

Le Status Page raggruppano i monitor in una vista pubblica o interna.

1. Navigare a **Status Pages** (menu laterale)
2. Click **New Status Page**
3. Inserire un nome (es. `Homelab`) e uno slug (es. `homelab`)
4. Aggiungere gruppi tematici:
   - **Infrastructure**: Traefik, Authelia, Pi-hole, Portainer
   - **Media**: Sonarr, Radarr, Lidarr, Prowlarr, Bazarr
   - **Download**: qBittorrent, NZBGet, Gluetun
   - **Proxmox**: Proxmox, Plex
5. Trascinare i monitor nei gruppi corrispondenti
6. Click **Save**

La status page è accessibile a `http://192.168.3.10:3001/status/homelab`.

---

## Manutenzione Programmata

Per evitare notifiche durante aggiornamenti pianificati o riavvii:

1. Navigare al monitor interessato (o selezionare più monitor)
2. Click **Maintenance** (icona chiave inglese nel menu laterale)
3. Click **Schedule Maintenance**
4. Configurare:
   - **Title**: es. `Aggiornamento QNAP QTS`
   - **Date/Time**: data e ora di inizio e fine
   - **Affected Monitors**: selezionare i monitor coinvolti
5. Click **Save**

> [!IMPORTANT]
> Durante la finestra di manutenzione, i monitor selezionati non invieranno notifiche di downtime. Il monitoraggio continua normalmente ma gli alert sono silenziati.

---

## Troubleshooting

| Problema | Causa | Soluzione |
|----------|-------|-----------|
| Monitor sempre rosso su un servizio funzionante | URL errato o rete Docker sbagliata | Verificare che Uptime Kuma sia sulla stessa rete del container target (`media_net`) |
| "Connection refused" su container VPN | qBittorrent/NZBGet passano per Gluetun | Usare `http://gluetun:<porta>` anziché l'hostname del container |
| Falsi positivi frequenti | Intervallo troppo basso o retries insufficienti | Aumentare l'intervallo a 60s e i retries a 3 |
| Monitor Docker Container non funziona | Docker socket non montato | Verificare il volume `/var/run/docker.sock:/var/run/docker.sock:ro` in `compose.yml` |
| Errore TLS su Portainer/Proxmox | Certificato self-signed | Abilitare "Ignore TLS/SSL errors" nelle impostazioni del monitor |
