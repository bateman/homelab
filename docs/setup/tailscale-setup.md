# Tailscale Setup — Mesh VPN Remote Access

> Guide to configure Tailscale as a Docker container on the NAS for secure remote access without port forwarding.

---

## Overview

Tailscale runs as a **subnet router** on the QNAP NAS (`192.168.3.10`), advertising the homelab subnets to the Tailscale mesh network. This allows remote devices to access all homelab services (Sonarr, Radarr, Plex, etc.) as if they were on the local network — without opening any ports on the router.

### Why on the NAS?

The NAS is always-on, so remote access remains available even when the Mini PC (Proxmox) is powered off. This also enables Wake-on-LAN of the Mini PC from remote via SSH through Tailscale.

### Architecture

```
                   Internet
                      |
              +-------+-------+
              |   Tailscale   |
              | Coordination  |
              +-------+-------+
                      |
         NAT traversal (no port forwarding)
                      |
    +-----------------+------------------+
    |                                    |
+---v-----------+              +---------v-------+
| NAS (Docker)  |              | Remote Device   |
| nas-tailscale |              | (phone/laptop)  |
| Subnet Router |              | Tailscale client|
| 192.168.3.0/24|              |                 |
| 192.168.4.0/24|              |                 |
+---------------+              +-----------------+
```

---

## Prerequisites

- [ ] QNAP NAS con Docker funzionante
- [ ] Account Tailscale creato su [tailscale.com](https://tailscale.com)
- [ ] File `docker/.env` e `docker/.env.secrets` configurati (vedi `docker/.env.example`)
- [ ] Stack Docker avviato almeno una volta (`make up`)

---

## Phase 1: Generate Auth Key

1. Accedere a [Tailscale Admin Console — Keys](https://login.tailscale.com/admin/settings/keys)
2. Click **Generate auth key**
3. Configurare la chiave:

| Impostazione | Valore | Motivo |
|-------------|--------|--------|
| **Reusable** | Yes | Il container può riavviarsi senza dover ri-autenticare |
| **Ephemeral** | No | Il dispositivo resta visibile nella Admin Console anche dopo un riavvio |
| **Tags** | `tag:server` (opzionale) | Per applicare ACL policy specifiche |
| **Expiration** | 90 days (default) | Dopo la prima autenticazione lo stato viene persistito e la chiave non serve più |

4. Copiare la chiave generata (formato: `tskey-auth-xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`)

> [!IMPORTANT]
> La chiave è visibile solo al momento della creazione. Salvarla subito.

---

## Phase 2: Configure Environment Variables

### 2.1 Secrets (`.env.secrets`)

Aggiungere la auth key in `docker/.env.secrets`:

```bash
# Tailscale - Remote Access (Mesh VPN)
TS_AUTHKEY=tskey-auth-xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

> Dopo la prima autenticazione riuscita, lo stato viene persistito nella directory `docker/config/tailscale/` e `TS_AUTHKEY` non è più necessario. Può essere rimosso da `.env.secrets` o lasciato (verrà ignorato).

### 2.2 Configuration (`.env`)

I valori di default in `docker/.env` sono:

```bash
# Subnet routes to advertise (comma-separated CIDR ranges)
TS_ROUTES=192.168.3.0/24,192.168.4.0/24

# Extra Tailscale arguments (optional)
# TS_EXTRA_ARGS=--accept-routes
```

| Variabile | Default | Descrizione |
|-----------|---------|-------------|
| `TS_ROUTES` | `192.168.3.0/24,192.168.4.0/24` | Subnet da rendere raggiungibili via Tailscale. `192.168.3.0/24` = VLAN Server, `192.168.4.0/24` = VLAN IoT |
| `TS_EXTRA_ARGS` | `--accept-routes` | Argomenti extra per `tailscale up` |

> [!TIP]
> Se hai solo la VLAN Server (192.168.3.0/24), puoi rimuovere la subnet IoT da `TS_ROUTES`.

---

## Phase 3: Start and Verify

### 3.1 Start the Stack

```bash
make up
```

Tailscale si avvia, si autentica con la chiave, e registra il dispositivo come `nas-tailscale` nella rete Tailscale.

### 3.2 Approve Subnet Routes

La prima volta, le subnet routes devono essere approvate manualmente:

1. Accedere a [Tailscale Admin Console — Machines](https://login.tailscale.com/admin/machines)
2. Trovare la macchina **nas-tailscale**
3. Click sui tre puntini (**...**) → **Edit route settings**
4. Abilitare le subnet advertised:
   - `192.168.3.0/24` (VLAN Server)
   - `192.168.4.0/24` (VLAN IoT)
5. Click **Save**

> [!IMPORTANT]
> Senza questo passaggio, i dispositivi remoti non potranno raggiungere le subnet locali.

### 3.3 Verify Connection

```bash
# Verificare che Tailscale sia connesso
docker exec tailscale tailscale status

# Mostra l'IP Tailscale assegnato al NAS
docker exec tailscale tailscale ip -4

# Verificare le subnet routes advertised
docker exec tailscale tailscale status --json | grep -A5 "AllowedIPs"
```

Output atteso di `tailscale status`:

```
100.x.x.x   nas-tailscale        user@     linux   -
```

### 3.4 Test from Remote Device

Sul dispositivo remoto (con Tailscale installato e connesso):

```bash
# Ping del NAS via IP locale (passa attraverso il tunnel)
tailscale ping 192.168.3.10

# Verificare accesso ai servizi
curl -s http://192.168.3.10:8989/ping   # Sonarr
curl -s http://192.168.3.10:3001        # Uptime Kuma
```

---

## Phase 4: Pi-hole as Tailscale DNS (Optional but Recommended)

Configurando Pi-hole come DNS per Tailscale, puoi usare gli stessi URL `*.home.local` sia da LAN che da remoto.

Per le istruzioni complete, vedi: [Reverse Proxy Setup — Phase 1: Pi-hole Configuration as Tailscale DNS](reverse-proxy-setup.md#phase-1-pi-hole-configuration-as-tailscale-dns)

In breve:

1. [Tailscale Admin Console — DNS](https://login.tailscale.com/admin/dns)
2. **Nameservers** → Add nameserver → Custom → `192.168.3.10`
3. Enable **Override local DNS**

Risultato: `sonarr.home.local`, `radarr.home.local`, ecc. funzionano anche da remoto.

---

## Docker Compose Reference

Il servizio Tailscale in `docker/compose.yml`:

```yaml
tailscale:
  image: tailscale/tailscale:latest
  container_name: tailscale
  hostname: nas-tailscale
  environment:
    TS_AUTHKEY: ${TS_AUTHKEY:-}
    TS_STATE_DIR: /var/lib/tailscale
    TS_ROUTES: ${TS_ROUTES:-192.168.3.0/24,192.168.4.0/24}
    TS_EXTRA_ARGS: ${TS_EXTRA_ARGS:---accept-routes}
    TS_USERSPACE: "false"
  volumes:
    - ./config/tailscale:/var/lib/tailscale
  cap_add:
    - NET_ADMIN
    - NET_RAW
  devices:
    - /dev/net/tun:/dev/net/tun
  network_mode: host
  restart: unless-stopped
```

Note importanti:

| Configurazione | Valore | Motivo |
|---------------|--------|--------|
| `network_mode: host` | Obbligatorio | Il subnet router deve accedere direttamente alla rete dell'host |
| `cap_add: NET_ADMIN, NET_RAW` | Obbligatorio | Necessari per creare l'interfaccia tunnel e gestire il routing |
| `/dev/net/tun` | Obbligatorio | Device TUN per il tunnel VPN |
| `TS_USERSPACE: "false"` | Consigliato | Usa il kernel networking (più performante) anziché lo userspace |
| `TS_STATE_DIR` + volume | Persistenza | Lo stato di autenticazione sopravvive ai riavvii del container |

---

## Troubleshooting

| Problema | Causa | Soluzione |
|----------|-------|----------|
| `tailscale status` mostra "Logged out" | Auth key scaduta o invalida | Generare una nuova chiave e riavviare: `docker restart tailscale` |
| Subnet routes non raggiungibili | Routes non approvate nella Admin Console | Approvare in [Machines](https://login.tailscale.com/admin/machines) → nas-tailscale → Edit route settings |
| `tailscale ping` fallisce da remoto | Tailscale non installato/connesso sul dispositivo remoto | Installare Tailscale e fare login |
| DNS `*.home.local` non funziona da remoto | Pi-hole non configurato come DNS Tailscale | Vedi [Phase 4](#phase-4-pi-hole-as-tailscale-dns-optional-but-recommended) |
| Container non si avvia: "permission denied" | Mancano capabilities o device TUN | Verificare `cap_add` e `devices` in `compose.yml` |
| IP Tailscale cambia dopo riavvio | Chiave ephemeral o stato non persistito | Usare chiave non-ephemeral; verificare il volume `./config/tailscale` |

---

## Useful Commands

```bash
# Status della connessione
docker exec tailscale tailscale status

# IP Tailscale del NAS
docker exec tailscale tailscale ip -4

# Ping di un altro nodo Tailscale
docker exec tailscale tailscale ping <hostname-or-ip>

# Log del container
docker logs tailscale --tail 50

# Forzare ri-autenticazione (se necessario)
docker exec tailscale tailscale logout
# Poi aggiornare TS_AUTHKEY in .env.secrets e riavviare
docker restart tailscale
```

---

## Related Documentation

| Topic | File |
|-------|------|
| Pi-hole DNS per Tailscale | [reverse-proxy-setup.md — Phase 1](reverse-proxy-setup.md#phase-1-pi-hole-configuration-as-tailscale-dns) |
| Firewall e subnet routing | [firewall-config.md](../network/firewall-config.md) |
| WOL remoto via Tailscale | [proxmox-setup.md — WOL via Tailscale](proxmox-setup.md#827-wol-via-tailscale-remote) |
| Monitoring (Uptime Kuma) | [uptime-kuma-monitors.md](../operations/uptime-kuma-monitors.md) |
| Compose service definition | [docker/compose.yml](../../docker/compose.yml) |
