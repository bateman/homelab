# UniFi Dream Machine SE — Firewall Configuration

> Configurazione firewall con segmentazione VLAN per homelab

---

## Topologia di Rete

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                      Iliad Box                              │
│                   192.168.1.254                             │
│                                                             │
│   Rete legacy 192.168.1.0/24 (Vimar, videocitofono, etc.)   │
│                                                             │
│   ┌─────────────────┐                                       │
│   │ Switch PoE Vimar│──► Dispositivi Vimar (IP statici)     │
│   └─────────────────┘                                       │
│                                                             │
│   DMZ -> 192.168.1.1 (UDM-SE WAN)                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                        UDM-SE                               │
│                  WAN: 192.168.1.1                           │
│                                                             │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────┐  │
│  │ VLAN 2  │ │ VLAN 3  │ │ VLAN 4  │ │ VLAN 5  │ │VLAN 6 │  │
│  │  Mgmt   │ │ Servers │ │  Media  │ │  Guest  │ │  IoT  │  │
│  │ .2.0/24 │ │ .3.0/24 │ │ .4.0/24 │ │ .5.0/24 │ │.6.0/24│  │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └───────┘  │
└─────────────────────────────────────────────────────────────┘
         │
         │ SFP+ 10G
         ▼
┌─────────────────┐
│ USW-Pro-Max     │
│   -16-PoE       │
└─────────────────┘
```

---

## Definizione VLAN

| VLAN ID | Nome | Subnet | Gateway | DHCP Range | Scopo |
|---------|------|--------|---------|------------|-------|
| 2 | Management | 192.168.2.0/24 | 192.168.2.1 | .100-.200 | UDM-SE, Switch, Access Point |
| 3 | Servers | 192.168.3.0/24 | 192.168.3.1 | Disabilitato* | NAS, Proxmox, stampante, PC desktop (IP statici) |
| 4 | Media | 192.168.4.0/24 | 192.168.4.1 | .100-.200 | Smart TV, telefoni, tablet |
| 5 | Guest | 192.168.5.0/24 | 192.168.5.1 | .100-.200 | WiFi ospiti |
| 6 | IoT | 192.168.6.0/24 | 192.168.6.1 | .100-.200 | Alexa, videocamera nuova, dispositivi smart WiFi |

> **Nota**: La subnet 192.168.1.0/24 NON e' gestita dal UDM-SE. Resta per Iliad Box e dispositivi Vimar legacy collegati allo switch PoE nel quadro elettrico.

> ***DHCP Disabilitato su VLAN 3**: I dispositivi server usano IP statici configurati direttamente su di essi. Se devi collegare temporaneamente un nuovo dispositivo per configurarlo, puoi:
> 1. Collegarlo prima a un'altra VLAN con DHCP (es. Management), configurare l'IP statico, poi spostarlo
> 2. Configurare l'IP statico manualmente prima di collegarlo alla rete

---

## Piano IP Statico

### Rete Legacy — Iliad/Vimar (192.168.1.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Iliad Box | 192.168.1.254 | Router/modem, telefonia |
| UDM-SE (WAN) | 192.168.1.1 | Riceve IP via DMZ |
| Dispositivi Vimar | 192.168.1.x | Videocitofono, allarme, attuatori (statici) |

> Questa rete e' gestita dall'Iliad Box, non dal UDM-SE.

### VLAN 2 — Management (192.168.2.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Gateway (UDM-SE) | 192.168.2.1 | Controller UniFi integrato |
| USW-Pro-Max-16-PoE | 192.168.2.10 | Switch managed |
| U6-Pro Access Point | 192.168.2.20 | WiFi |

### VLAN 3 — Servers (192.168.3.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Gateway (UDM-SE) | 192.168.3.1 | — |
| NAS QNAP | 192.168.3.10 | Media stack, Pi-hole |
| Mini PC Proxmox | 192.168.3.20 | Plex, Tailscale, Nginx Proxy Manager |
| Stampante | 192.168.3.30 | Stampa da PC e dispositivi Media |
| PC Desktop | 192.168.3.40 | Workstation principale |

### VLAN 4 — Media (192.168.4.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Gateway (UDM-SE) | 192.168.4.1 | — |
| Smart TV camera da letto | DHCP reservation | Cablata |
| Smart TV salotto | DHCP reservation | WiFi |
| Telefoni/Tablet | DHCP | Client Plex, gestione *arr |

### VLAN 5 — Guest (192.168.5.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Gateway (UDM-SE) | 192.168.5.1 | — |
| Client ospiti | DHCP | Solo accesso Internet |

### VLAN 6 — IoT (192.168.6.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Gateway (UDM-SE) | 192.168.6.1 | — |
| Alexa | DHCP reservation | Cloud-dependent |
| Videocamera nuova | DHCP reservation | Cloud-dependent (Vimar View) |
| Altri dispositivi IoT | DHCP | Sensori WiFi, luci smart, etc. |

---

## Configurazione Iliad Box

| Parametro | Valore |
|-----------|--------|
| Modalita' | Router (NO bridge/ONT) |
| IP LAN | 192.168.1.254 (invariato) |
| DHCP | Disabilitato (o range limitato .200-.250 per Vimar) |
| DMZ | Abilitata verso 192.168.1.1 |
| Telefonia VoIP | Funzionante |

> **Nota**: L'IP dell'Iliad Box NON deve essere cambiato. La subnet 192.168.1.0/24 resta per i dispositivi Vimar legacy.

---

## Reti WiFi (SSID)

| SSID | VLAN | Sicurezza | Note |
|------|------|-----------|------|
| Casa-Media | 4 | WPA3/WPA2 | TV, telefoni, tablet |
| Casa-Guest | 5 | WPA3/WPA2 | Ospiti, isolamento completo |
| Casa-IoT | 6 | WPA3/WPA2 | Alexa, dispositivi smart WiFi |

> **Nota**: Non serve SSID per Management (accesso solo cablato) ne' per Servers (dispositivi cablati con IP statici).

---

## Regole Firewall

### Filosofia

Il firewall segue il principio "deny all, allow specific": tutto il traffico inter-VLAN e' bloccato di default, poi vengono create eccezioni esplicite per i flussi necessari.

Le regole sono organizzate in gruppi logici per facilitare la manutenzione.

### Gruppi di IP

Prima di creare le regole, definire questi gruppi in Settings -> Profiles -> IP Groups:

| Nome Gruppo | Tipo | Contenuto |
|-------------|------|-----------|
| NAS | IP Address | 192.168.3.10 |
| MiniPC | IP Address | 192.168.3.20 |
| Stampante | IP Address | 192.168.3.30 |
| Servers-All | IP Address | 192.168.3.10, 192.168.3.20, 192.168.3.30 |
| VLAN-Management | Subnet | 192.168.2.0/24 |
| VLAN-Servers | Subnet | 192.168.3.0/24 |
| VLAN-Media | Subnet | 192.168.4.0/24 |
| VLAN-Guest | Subnet | 192.168.5.0/24 |
| VLAN-IoT | Subnet | 192.168.6.0/24 |
| RFC1918 | Subnet | 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12 |

### Gruppi di Porte

Definire in Settings -> Profiles -> Port Groups:

| Nome Gruppo | Porte |
|-------------|-------|
| DNS | 53 |
| Plex | 32400 |
| Plex-Discovery | 32410-32414 |
| Arr-Stack | 8989, 7878, 8686, 9696, 6767, 8080, 6789, 9705, 11011, 8081, 8191 |
| HomeAssistant | 8123 |
| Portainer | 9443 |
| Stampa | 631, 9100 |
| mDNS | 5353 |

> **Nota**: Arr-Stack include: Sonarr (8989), Radarr (7878), Lidarr (8686), Prowlarr (9696), Bazarr (6767), qBittorrent (8080), NZBGet (6789), Huntarr (9705), Cleanuparr (11011), Pi-hole (8081), FlareSolverr (8191).

---

## Regole LAN In (Inter-VLAN)

Percorso: Settings -> Firewall & Security -> Firewall Rules -> LAN In

Le regole sono processate in ordine, dalla prima all'ultima. L'ordine e' importante.

### Regola 1 — Allow Established/Related

| Campo | Valore |
|-------|--------|
| Name | Allow Established/Related |
| Action | Accept |
| Protocol | All |
| Source | Any |
| Destination | Any |
| States | Established, Related |

> Permette il traffico di ritorno per connessioni gia' stabilite. Fondamentale per il funzionamento corretto.

### Regola 2 — Allow All -> Pi-hole DNS

| Campo | Valore |
|-------|--------|
| Name | Allow DNS to Pi-hole |
| Action | Accept |
| Protocol | TCP/UDP |
| Source | Any |
| Destination | NAS (192.168.3.10) |
| Port | DNS (53) |

> DNS centralizzato accessibile da tutte le VLAN.

### Regola 3 — Allow Media -> Plex

| Campo | Valore |
|-------|--------|
| Name | Allow Media to Plex |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | MiniPC (192.168.3.20) |
| Port | Plex (32400) |

### Regola 4 — Allow Media -> Plex Discovery

| Campo | Valore |
|-------|--------|
| Name | Allow Media to Plex Discovery |
| Action | Accept |
| Protocol | UDP |
| Source | VLAN-Media |
| Destination | MiniPC (192.168.3.20) |
| Port | Plex-Discovery (32410-32414) |

### Regola 5 — Allow Media -> Arr Stack

| Campo | Valore |
|-------|--------|
| Name | Allow Media to Arr Stack |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | NAS (192.168.3.10) |
| Port | Arr-Stack |

### Regola 6 — Allow Media -> Portainer

| Campo | Valore |
|-------|--------|
| Name | Allow Media to Portainer |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | NAS (192.168.3.10) |
| Port | Portainer (9443) |

### Regola 7 — Allow Media -> Stampante

| Campo | Valore |
|-------|--------|
| Name | Allow Media to Printer |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | Stampante (192.168.3.30) |
| Port | Stampa (631, 9100) |

### Regola 8 — Allow Media -> Home Assistant

| Campo | Valore |
|-------|--------|
| Name | Allow Media to Home Assistant |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-Media |
| Destination | NAS (192.168.3.10) |
| Port | HomeAssistant (8123) |

> Permette ai dispositivi Media (telefoni, tablet) di accedere all'interfaccia Home Assistant.

### Regola 9 — Allow IoT -> Home Assistant

| Campo | Valore |
|-------|--------|
| Name | Allow IoT to Home Assistant |
| Action | Accept |
| Protocol | TCP |
| Source | VLAN-IoT |
| Destination | NAS (192.168.3.10) |
| Port | HomeAssistant (8123) |

> Permette ai dispositivi IoT di comunicare con Home Assistant per automazioni.

### Regola 10 — Block IoT -> All Private

| Campo | Valore |
|-------|--------|
| Name | Block IoT to Private Networks |
| Action | Drop |
| Protocol | All |
| Source | VLAN-IoT |
| Destination | RFC1918 |

> Blocca qualsiasi tentativo dei dispositivi IoT di raggiungere altre reti private. Possono solo accedere a Internet (necessario per Alexa e cloud services) e Home Assistant (regola 9).

### Regola 11 — Block Guest -> All Private

| Campo | Valore |
|-------|--------|
| Name | Block Guest to Private Networks |
| Action | Drop |
| Protocol | All |
| Source | VLAN-Guest |
| Destination | RFC1918 |

> Isolamento completo della rete Guest. Solo accesso Internet.

### Regola 12 — Allow Management from Servers

| Campo | Valore |
|-------|--------|
| Name | Allow Servers to Management |
| Action | Accept |
| Protocol | All |
| Source | VLAN-Servers |
| Destination | VLAN-Management |

> Permette al PC desktop (VLAN 3) di accedere alle interfacce di gestione di switch e AP.

### Regola 13 — Block All Inter-VLAN (Catch-All)

| Campo | Valore |
|-------|--------|
| Name | Block All Inter-VLAN |
| Action | Drop |
| Protocol | All |
| Source | RFC1918 |
| Destination | RFC1918 |

> Catch-all finale: blocca tutto il traffico inter-VLAN non esplicitamente permesso.

---

## mDNS Reflection

Percorso: Settings -> Networks -> (seleziona VLAN) -> Advanced -> Multicast DNS

Abilitare mDNS reflection per permettere il discovery automatico tra VLAN:
- **Stampante**: discovery da dispositivi Media
- **Home Assistant**: discovery dispositivi IoT (Alexa, smart devices)
- **Chromecast/AirPlay**: streaming da telefoni a TV

| VLAN | mDNS Enabled | Motivo |
|------|--------------|--------|
| 2 (Management) | No | Solo gestione, no discovery necessario |
| 3 (Servers) | Si | HA discovery, stampante |
| 4 (Media) | Si | Chromecast, AirPlay, stampante |
| 5 (Guest) | No | Isolamento completo |
| 6 (IoT) | Si | HA discovery dispositivi smart |

> **Nota sicurezza**: mDNS reflection espone solo i nomi dei servizi (es. "Stampante._ipp._tcp.local"), non fornisce accesso. Il firewall continua a bloccare il traffico non autorizzato tra VLAN.

---

## Threat Management (IDS/IPS)

Percorso: Settings -> Firewall & Security -> Threat Management

| Parametro | Valore |
|-----------|--------|
| Stato | Enabled |
| Mode | IPS (Intrusion Prevention) |
| Sensitivity | Medium |
| Restrict IoT | Enabled (VLAN 6) |
| Restrict Guest | Enabled (VLAN 5) |

> L'IPS su IoT e Guest aggiunge un livello di protezione contro comportamenti anomali dei dispositivi compromessi.

---

## Traffic Rules (QoS)

Percorso: Settings -> Traffic Management -> Traffic Rules

### Priorita' Plex

| Campo | Valore |
|-------|--------|
| Name | Prioritize Plex |
| Action | Set DSCP |
| DSCP Value | 46 (EF - Expedited Forwarding) |
| Source | MiniPC (192.168.3.20) |
| Port | 32400 |

### Limitazione Bandwidth Guest

| Campo | Valore |
|-------|--------|
| Name | Limit Guest Bandwidth |
| Action | Rate Limit |
| Download | 50 Mbps |
| Upload | 10 Mbps |
| Source | VLAN-Guest |

---

## Configurazione DNS (DHCP)

### Architettura DNS

Pi-hole (192.168.3.10) e' il DNS primario per tutte le VLAN, fornendo ad-blocking e risoluzione nomi locali (`*.home.local`). Per evitare Single Point of Failure, configurare un DNS di fallback.

### Configurazione per VLAN

Percorso: Settings -> Networks -> (seleziona VLAN) -> DHCP -> DHCP DNS Server

| VLAN | DNS Primario | DNS Secondario | Note |
|------|--------------|----------------|------|
| 2 (Management) | 192.168.3.10 | 1.1.1.1 | Pi-hole + fallback Cloudflare |
| 3 (Servers) | N/A | N/A | IP statici, DNS configurato su ogni host |
| 4 (Media) | 192.168.3.10 | 1.1.1.1 | Pi-hole + fallback Cloudflare |
| 5 (Guest) | 1.1.1.1 | 1.0.0.1 | Solo Cloudflare (no Pi-hole) |
| 6 (IoT) | 192.168.3.10 | 1.1.1.1 | Pi-hole + fallback Cloudflare |

> **Nota VLAN 5 (Guest)**: Gli ospiti usano direttamente Cloudflare per evitare che vedano i record DNS locali (`*.home.local`).

### Comportamento Fallback

- **Normale**: Client usano Pi-hole (192.168.3.10) per tutte le query
- **Pi-hole down**: Client fallback su Cloudflare (1.1.1.1) automaticamente
- **Durante fallback**: Ad-blocking disattivato, nomi `*.home.local` non risolvono

### Verifica Configurazione

```bash
# Da un client DHCP (es. telefono su VLAN Media)
# Verificare che riceva entrambi i DNS
# Android: Impostazioni -> WiFi -> Dettagli rete
# iOS: Impostazioni -> WiFi -> (i) -> DNS

# Test fallback (dal PC desktop)
# 1. Fermare Pi-hole
docker stop pihole

# 2. Verificare che DNS funzioni ancora (usa fallback)
nslookup google.com
# Deve funzionare via 1.1.1.1

# 3. Verificare che *.home.local NON funziona (normale durante fallback)
nslookup sonarr.home.local
# Fallisce - usare IP diretto o riavviare Pi-hole

# 4. Riavviare Pi-hole
docker start pihole
```

### Limitazioni del Fallback DNS

- **Nomi locali**: `*.home.local` non risolvono durante outage Pi-hole
- **Ad-blocking**: Disattivato durante fallback
- **Workaround**: Accedere ai servizi via IP diretto (es. `https://192.168.3.10:8989`)

> **Per ridondanza completa con ad-blocking**: Installare secondo Pi-hole su Proxmox con Gravity Sync. Vedere documentazione Gravity Sync: https://github.com/vmstan/gravity-sync

---

## Port Forwarding

Per l'accesso remoto tramite Tailscale, non e' necessario port forwarding: Tailscale usa NAT traversal.

Se in futuro servisse aprire porte specifiche (es. per Plex remoto senza Tailscale):

| Nome | Porta Esterna | Porta Interna | Destinazione | Protocollo |
|------|---------------|---------------|--------------|------------|
| Plex Remote | 32400 | 32400 | 192.168.3.20 | TCP |

> **Nota**: Aprire porte espone servizi a Internet. Preferire Tailscale quando possibile.

---

## Checklist Configurazione

1. [ ] Verificare IP Iliad Box (192.168.1.254) e DMZ verso 192.168.1.1
2. [ ] Creare VLAN 2, 3, 4, 5, 6 in Settings -> Networks
3. [ ] Creare IP Groups in Settings -> Profiles
4. [ ] Creare Port Groups in Settings -> Profiles
5. [ ] Configurare regole firewall in ordine
6. [ ] Abilitare mDNS reflection su VLAN 3, 4 e 6
7. [ ] Configurare Threat Management
8. [ ] Creare SSID WiFi (Casa-Media, Casa-Guest, Casa-IoT)
9. [ ] Assegnare IP statici ai dispositivi Servers
10. [ ] Testare comunicazione inter-VLAN

---

## Troubleshooting

### Verificare connettivita' inter-VLAN

Dal PC desktop (192.168.3.40):

```bash
# Test DNS
nslookup google.com 192.168.3.10

# Test Plex
curl -I http://192.168.3.20:32400/web

# Test raggiungibilita' Iliad Box (dalla VLAN Servers)
ping 192.168.1.254
```

### Log firewall

Percorso: Settings -> Firewall & Security -> Firewall Rules -> (regola) -> Enable Logging

Abilitare logging sulle regole Drop per diagnosticare traffico bloccato.

### Comandi utili da SSH su UDM-SE

```bash
# Visualizza regole iptables
iptables -L -n -v

# Monitor traffico in tempo reale
tcpdump -i br0 -n

# Verifica VLAN tagging
cat /sys/class/net/br0/bridge/vlan_filtering
```

---

## Considerazioni Sicurezza Rete Legacy (192.168.1.0/24)

La rete 192.168.1.0/24 non e' gestita dal UDM-SE e rappresenta un potenziale vettore di attacco.

### Architettura

```
Internet
    │
    ▼
┌─────────────────────────────────────┐
│         Iliad Box                   │
│       192.168.1.254                 │
│                                     │
│   ┌─────────────┐  ┌─────────────┐  │
│   │ Switch PoE  │  │  UDM-SE WAN │  │
│   │   Vimar     │  │ 192.168.1.1 │  │
│   └──────┬──────┘  └──────┬──────┘  │
│          │                │         │
│    Dispositivi       DMZ (tutto)    │
│    Vimar .1.x                       │
└─────────────────────────────────────┘
```

### Rischi Teorici

| Rischio | Probabilita' | Impatto | Mitigazione |
|---------|--------------|---------|-------------|
| Dispositivo Vimar compromesso attacca UDM-SE WAN | Bassa | Media | UDM-SE protetto di default |
| Lateral movement da 192.168.1.x a VLAN interne | Molto bassa | Alta | No route, UDM-SE blocca |
| Attacco a Iliad Box | Bassa | Media | Dispositivo gestito da ISP |

### Mitigazioni Esistenti

1. **UDM-SE WAN protection**: Traffico WAN→LAN bloccato di default
2. **No routing**: Dispositivi 192.168.1.x non hanno route verso 192.168.2-6.x
3. **Threat Management**: IDS/IPS attivo su UDM-SE rileva anomalie
4. **Dispositivi trusted**: Vimar installati professionalmente, non IoT consumer

### Accettazione del Rischio

Per questo homelab, il rischio e' accettato perche':
- Vimar sono dispositivi professionali con firmware controllato
- Richiedono compromissione fisica o vulnerabilita' 0-day specifica
- L'alternativa (ricablaggio completo) ha costo sproporzionato al beneficio
- UDM-SE offre protezione adeguata sull'interfaccia WAN

> **Miglioramento futuro (opzionale)**: Aggiungere regola WAN Local su UDM-SE per bloccare accesso alla gestione (porta 443) dalla subnet 192.168.1.0/24 eccetto 192.168.1.254 (Iliad Box).

---

## Note

- **Rete Legacy**: La subnet 192.168.1.0/24 resta per Iliad Box e dispositivi Vimar. Non e' gestita dal UDM-SE.
- **Double NAT**: Presente con Iliad Box in modalita' router. Non impatta le prestazioni per uso homelab.
- **Tailscale**: Installato su Mini PC Proxmox, fornisce accesso VPN mesh senza port forwarding.
- **Home Assistant**: Accessibile da VLAN Media (telefoni/tablet) e VLAN IoT (dispositivi smart).
- **Backup config**: Esportare regolarmente da Settings -> System -> Backup.
