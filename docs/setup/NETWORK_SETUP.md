# Network Setup - UniFi UDM-SE e VLAN

> Guida completa per configurare la rete UniFi con segmentazione VLAN

---

## Prerequisiti

- [ ] UDM-SE montato in rack e alimentato
- [ ] USW-Enterprise-8-PoE montato e alimentato
- [ ] Cavo ethernet da UDM-SE porta WAN a Iliad Box LAN
- [ ] Cavo ethernet da UDM-SE porta 1 a Switch porta 1
- [ ] PC collegato a una porta LAN del UDM-SE

---

## Fase 1: Setup Iniziale UDM-SE

### 1.1 Primo Accesso

1. Collegare PC direttamente a una porta LAN del UDM-SE
2. Il PC riceverà IP via DHCP (192.168.1.x)
3. Aprire browser: `https://192.168.1.1`
4. Accettare certificato self-signed

### 1.2 Wizard Iniziale

1. [ ] Selezionare "Set up a new UniFi Console"
2. [ ] Creare account UniFi o accedere con esistente
3. [ ] Nome console: `Homelab`
4. [ ] Configurazione WAN:
   - Tipo: DHCP (Iliad Box assegnerà IP)
   - Verificare connessione Internet
5. [ ] Configurazione LAN default:
   - Lasciare temporaneamente 192.168.1.0/24
   - Modificheremo dopo

### 1.3 Aggiornamento Firmware

1. [ ] Settings → System → Firmware
2. [ ] Verificare aggiornamenti disponibili
3. [ ] Installare ultima versione stabile
4. [ ] Attendere riavvio (~5 minuti)

---

## Fase 2: Creazione VLAN

### 2.1 Eliminare Rete Default (opzionale)

> Nota: Potresti voler mantenere la rete default per la transizione

Settings → Networks → Default → Delete (dopo aver creato VLAN 3 per Servers)

### 2.2 Creare VLAN Management (VLAN 2)

Settings → Networks → Create New Network

| Campo | Valore |
|-------|--------|
| Name | Management |
| Router | UDM-SE |
| Gateway IP/Subnet | 192.168.2.1/24 |
| VLAN ID | 2 |
| DHCP Mode | DHCP Server |
| DHCP Range | 192.168.2.100 - 192.168.2.200 |
| Domain Name | management.local |

**Opzioni Avanzate:**
- [ ] IGMP Snooping: Enabled
- [ ] Multicast DNS: Enabled

Cliccare "Add Network"

### 2.3 Creare VLAN Servers (VLAN 3)

| Campo | Valore |
|-------|--------|
| Name | Servers |
| Gateway IP/Subnet | 192.168.3.1/24 |
| VLAN ID | 3 |
| DHCP Mode | None (IP statici) |
| Domain Name | servers.local |

> **Nota**: VLAN Servers usa IP statici. Assegnare manualmente: NAS=.10, Proxmox=.20, Stampante=.30, PC=.40

### 2.4 Creare VLAN Media (VLAN 4)

| Campo | Valore |
|-------|--------|
| Name | Media |
| Gateway IP/Subnet | 192.168.4.1/24 |
| VLAN ID | 4 |
| DHCP Range | 192.168.4.100 - 192.168.4.200 |
| Domain Name | media.local |

### 2.5 Creare VLAN Guest (VLAN 5)

| Campo | Valore |
|-------|--------|
| Name | Guest |
| Gateway IP/Subnet | 192.168.5.1/24 |
| VLAN ID | 5 |
| DHCP Range | 192.168.5.100 - 192.168.5.200 |
| Network Type | Guest Network |

**Opzioni Guest:**
- [ ] Guest Network Isolation: Enabled
- [ ] Apply Guest Policies: Enabled

### 2.6 Creare VLAN IoT (VLAN 6)

| Campo | Valore |
|-------|--------|
| Name | IoT |
| Gateway IP/Subnet | 192.168.6.1/24 |
| VLAN ID | 6 |
| DHCP Range | 192.168.6.100 - 192.168.6.200 |
| Domain Name | iot.local |

### Verifica VLAN Create

Settings → Networks dovrebbe mostrare:

```
Management  192.168.2.0/24  VLAN 2
Servers     192.168.3.0/24  VLAN 3
Media       192.168.4.0/24  VLAN 4
Guest       192.168.5.0/24  VLAN 5
IoT         192.168.6.0/24  VLAN 6
```

---

## Fase 3: Configurazione Switch

### 3.1 Adozione Switch

1. [ ] Collegare switch a UDM-SE porta 1
2. [ ] UniFi Devices → dovrebbe apparire "USW-Enterprise-8-PoE"
3. [ ] Cliccare "Adopt"
4. [ ] Attendere provisioning (~2 minuti)
5. [ ] Aggiornare firmware se disponibile

### 3.2 Configurazione Porte Switch

Settings → Devices → USW-Enterprise-8-PoE → Ports

| Porta | Profilo | VLAN | Dispositivo |
|-------|---------|------|-------------|
| 1 | All | Trunk | UDM-SE Uplink |
| 2 | Servers | 3 | Mini PC Proxmox |
| 3 | Management | 2 | (riservata) |
| 4 | Servers | 3 | (espansione) |
| 5 | Media | 4 | (espansione) |
| 6 | IoT | 6 | (espansione) |
| SFP+ 1 | Servers | 3 | NAS QNAP 10GbE |
| SFP+ 2 | - | - | (non usata) |

### 3.3 Creare Port Profiles

Settings → Profiles → Switch Ports → Create New Profile

**Profile "Servers":**
- Native Network: Servers (VLAN 3)
- Tagged Networks: None
- PoE: Off (per porte dati)

**Profile "Management":**
- Native Network: Management (VLAN 2)
- Tagged Networks: None

**Profile "Media":**
- Native Network: Media (VLAN 4)
- Tagged Networks: None

**Profile "IoT":**
- Native Network: IoT (VLAN 6)
- Tagged Networks: None

### 3.4 Applicare Profili alle Porte

Per ogni porta, cliccare → Port Profile → selezionare profilo appropriato

---

## Fase 4: Configurazione IP Statici

> **Nota importante**: Gli IP statici per NAS e Proxmox vengono configurati **direttamente sui dispositivi** durante il loro setup iniziale (vedi [NAS_SETUP.md](NAS_SETUP.md) e [PROXMOX_SETUP.md](PROXMOX_SETUP.md)).
>
> Le "Fixed IP" in UniFi sono **opzionali** e servono solo se preferisci usare DHCP con reservation invece di IP statici configurati sui device.

### 4.1 Opzione A: IP Statici sui Dispositivi (Raccomandato)

Configurare IP statici direttamente su:
- **NAS QNAP**: Control Panel → Network → IP statico `192.168.3.10`
- **Mini PC Proxmox**: Durante installazione, IP `192.168.3.20`

### 4.2 Opzione B: DHCP Reservation in UniFi (Alternativa)

Se preferisci gestire gli IP centralmente da UniFi:

1. Collegare temporaneamente i dispositivi per farli apparire in Client Devices
2. Settings → Client Devices → (cercare per MAC address)
3. Settings → Fixed IP Address: assegnare IP desiderato

### 4.3 Fixed IP per Switch

Lo switch dovrebbe già avere IP in VLAN Management dopo l'adozione.
Verificare: Settings → Devices → Switch → IP: dovrebbe essere 192.168.2.x

---

## Fase 5: Gruppi IP e Porte

> Necessari per le regole firewall. Vedi [`firewall-config.md`](../network/firewall-config.md) per la lista completa.

### 5.1 Creare Gruppi IP

Settings → Profiles → IP Groups → Create New Group

**Gruppo: RFC1918 (Reti Private)**
- Type: IPv4 Address/Subnet
- Addresses:
  - `10.0.0.0/8`
  - `172.16.0.0/12`
  - `192.168.0.0/16`

**Gruppo: NAS Server**
- Type: IPv4 Address/Subnet
- Addresses:
  - `192.168.3.10/32`

**Gruppo: Media Clients**
- Type: IPv4 Address/Subnet
- Addresses:
  - `192.168.4.0/24`

**Gruppo: Plex Server**
- Type: IPv4 Address/Subnet
- Addresses:
  - `192.168.3.20/32`

### 5.2 Creare Gruppi Porte

Settings → Profiles → Port Groups → Create New Group

**Gruppo: Media Services Ports**
- Ports:
  - `8989` (Sonarr)
  - `7878` (Radarr)
  - `8686` (Lidarr)
  - `6767` (Bazarr)

> **Nota**: Plex (32400) non è incluso perché gira sul Mini PC, non sul NAS. qBittorrent (8080) e NZBGet (6789) non sono inclusi - i client media non devono accedere direttamente ai download client.

**Gruppo: Infrastructure Ports**
- Ports:
  - `53` (DNS)
  - `8081` (Pi-hole)
  - `8123` (Home Assistant)

---

## Fase 6: Regole Firewall

**Riferimento completo:** [`firewall-config.md`](../network/firewall-config.md)

> **Importante**: Questa sezione contiene solo le regole essenziali per iniziare.
> Per la configurazione completa (13 regole), consulta [`firewall-config.md`](../network/firewall-config.md).
>
> Le regole sotto sono un **subset minimo** per far funzionare lo stack media.
> Aggiungi le regole mancanti da firewall-config.md per una sicurezza completa.

### 6.1 Ordine Regole (CRITICO)

Le regole sono processate in ordine. Inserire esattamente in questa sequenza:

Settings → Firewall & Security → Firewall Rules → LAN → Create New Rule

### Regola 1: Allow Established/Related

| Campo | Valore |
|-------|--------|
| Type | LAN In |
| Description | Allow Established and Related |
| Action | Allow |
| States | Established, Related |
| Source | Any |
| Destination | Any |

### Regola 2: Allow Media to NAS Media Services

| Campo | Valore |
|-------|--------|
| Type | LAN In |
| Description | Media VLAN to NAS Media Services |
| Action | Allow |
| Source | Network: Media |
| Destination | IP Group: NAS Server |
| Port Group | Media Services Ports |

### Regola 3: Allow Media to Plex

| Campo | Valore |
|-------|--------|
| Type | LAN In |
| Description | Media VLAN to Plex |
| Action | Allow |
| Source | Network: Media |
| Destination | IP Group: Plex Server |
| Port | 32400 |

### Regola 4: Allow IoT to Home Assistant

| Campo | Valore |
|-------|--------|
| Type | LAN In |
| Description | IoT to Home Assistant |
| Action | Allow |
| Source | Network: IoT |
| Destination | IP Group: NAS Server |
| Port | 8123 |

### Regola 5: Block All Inter-VLAN (ULTIMA)

| Campo | Valore |
|-------|--------|
| Type | LAN In |
| Description | Block All Inter-VLAN Traffic |
| Action | Drop |
| Source | IP Group: RFC1918 |
| Destination | IP Group: RFC1918 |

> ⚠️ Questa regola DEVE essere l'ultima. Blocca tutto il traffico inter-VLAN non esplicitamente permesso.

---

## Fase 7: Configurazione Iliad Box

### 7.1 Accesso a Iliad Box

1. Collegare PC direttamente a Iliad Box (temporaneamente)
2. Accedere a `http://192.168.1.254`
3. Login con credenziali Iliad

### 7.2 Configurazione DMZ (Opzionale)

> La DMZ inoltra tutto il traffico in ingresso al UDM-SE. Utile per port forwarding gestito da UniFi.

1. Impostazioni → NAT/Firewall → DMZ
2. Abilitare DMZ
3. IP Host DMZ: IP WAN del UDM-SE (verificare in Iliad Box → Dispositivi connessi)

### 7.3 Disabilitare Wi-Fi Iliad (Consigliato)

1. Impostazioni → Wi-Fi
2. Disabilitare tutte le reti Wi-Fi
3. Il Wi-Fi sarà gestito da UniFi AP

---

## Fase 8: Verifica Configurazione

### Test Connettività di Base

```bash
# Da un PC su VLAN Servers (192.168.3.x)

# Test gateway
ping 192.168.3.1

# Test inter-VLAN (dovrebbe funzionare - established)
ping 192.168.2.1

# Test Internet
ping 8.8.8.8
ping google.com
```

### Test Regole Firewall

```bash
# Da VLAN Media (192.168.4.x)

# Dovrebbe funzionare (regola allow)
curl http://192.168.3.10:8989  # Sonarr

# Dovrebbe essere bloccato (no regola)
ping 192.168.3.10  # ICMP bloccato da catch-all

# Da VLAN Guest (192.168.5.x)
# Tutto verso altre VLAN dovrebbe essere bloccato
ping 192.168.3.10  # Bloccato
curl http://192.168.3.10:8989  # Bloccato
```

### Test DNS

```bash
# Dopo configurazione Pi-hole
nslookup google.com 192.168.3.10
```

---

## Troubleshooting

| Problema | Causa | Soluzione |
|----------|-------|-----------|
| Switch non adottato | Rete diversa | Collegare temporaneamente alla stessa subnet |
| VLAN non raggiungibile | Porta non taggata | Verificare profilo porta switch |
| Inter-VLAN bloccato | Regola firewall | Verificare ordine regole |
| No Internet da VLAN | Gateway errato | Verificare DHCP options |
| Dispositivo IP errato | DHCP lease vecchio | Rinnovare lease o impostare fixed IP |

---

## Diagramma Rete Finale

```
                    ┌─────────────┐
                    │  Internet   │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │  Iliad Box  │
                    │ 192.168.1.254│
                    └──────┬──────┘
                           │ WAN
                    ┌──────┴──────┐
                    │   UDM-SE    │
                    │ 192.168.2.1 │ ← Management
                    │ 192.168.3.1 │ ← Servers
                    │ 192.168.4.1 │ ← Media
                    │ 192.168.5.1 │ ← Guest
                    │ 192.168.6.1 │ ← IoT
                    └──────┬──────┘
                           │ Trunk (All VLANs)
                    ┌──────┴──────┐
                    │   Switch    │
                    │USW-Ent-8-PoE│
                    └┬─────┬─────┬┘
                     │     │     │
            ┌────────┘     │     └────────┐
            │              │              │
     ┌──────┴──────┐ ┌─────┴─────┐ ┌──────┴──────┐
     │    QNAP     │ │  Proxmox  │ │  Altri      │
     │192.168.3.10 │ │192.168.3.20│ │  Devices    │
     │  VLAN 3     │ │  VLAN 3   │ │             │
     └─────────────┘ └───────────┘ └─────────────┘
```

---

## Prossimi Passi

Dopo aver completato il setup di rete:

1. → Procedere con [Setup NAS QNAP](NAS_SETUP.md)
2. → Tornare a [START_HERE.md](../../START_HERE.md) Fase 3
