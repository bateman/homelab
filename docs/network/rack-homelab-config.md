# Rack 19" 8U — Home Lab Configuration v3

> Configurazione ottimizzata per ventilazione passiva (rack aperto lateralmente e superiormente)

## Schema Rack

```
┏━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ U8  │ 🖥️  Lenovo Mini PC (Proxmox)                                            ┃
┃     │   • Fonte di calore principale -> dissipa verso l'alto (top aperto)     ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U7  │ 🌀 Pannello ventilato #1                                                ┃
┃     │   • Isola termicamente il Mini PC dal resto del rack                    ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U6  │ 🔀 Switch PoE 2.5G                                                      ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U5  │ 🌐 UDM-SE                                                               ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U4  │ 🔌 Patch Panel                                                          ┃
┃     │   • Passivo, nessun calore — fa da buffer naturale                      ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U3  │ 🔌 Multipresa Rack                                                      ┃
┃     │   • Alimentazione dispositivi con spina standard (es. Mini PC)          ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U2  │ 💾 NAS QNAP                                                             ┃
┃     │   • HDD nella zona piu' fresca del rack                                 ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃     │ ████ ISOLANTE: Neoprene 5mm ███████████████████████████████████████████ ┃
┣━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ U1  │ ⚡ UPS                                                                  ┃
┃     │   • Peso in basso, minima generazione di calore                         ┃
┗━━━━━┷━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        ↑↑↑ ARIA CALDA ESCE DAL TOP APERTO ↑↑↑
        
   <-  aria fresca entra dai lati  ->
```

---

## Dettaglio Componenti

### U8 — Lenovo ThinkCentre neo 50q Gen 4

| Spec | Valore |
|------|--------|
| CPU | Intel Core i5-13420H (Quick Sync) |
| RAM | 16GB DDR5 |
| Storage | 1TB M.2 NVMe PCIe Gen4 (Opal 2.0) |
| Network | 1x 1GbE RJ45 (integrata) + 1x 2.5GbE USB-C (adattatore) |
| Adattatore | StarTech US2GC30 (USB-C 3.0 to 2.5GbE) |
| OS | Proxmox VE |
| Services | Plex, Docker, Tailscale |
| IP | 192.168.3.20 |

### U7 — Pannello Ventilato #1

- Ubiquiti UACC-Rack-Panel-Vented-1U
- Isolamento termico tra Mini PC e networking

### U6 — UniFi USW-Enterprise-8-PoE

| Spec | Valore |
|------|--------|
| Porte RJ45 | 8x 2.5GbE (PoE+) |
| Porte SFP+ | 2x 10GbE |
| SFP+ Port 1 | Uplink a UDM-SE |
| SFP+ Port 2 | QNAP NAS |
| Budget PoE | 120W |
| IP | 192.168.2.10 |

### U5 — UniFi Dream Machine SE (UDM-SE-EU)

| Spec | Valore |
|------|--------|
| Funzione | Firewall / Router / Controller UniFi |
| WAN RJ45 | 1x 2.5GbE (ingresso fibra/ISP) |
| WAN SFP+ | 1x 10GbE (non usata - ISP non supporta 10G) |
| LAN RJ45 | 8x 1GbE |
| LAN SFP+ | 1x 10GbE (uplink a switch) |
| IP | 192.168.2.1 |

### U4 — Patch Panel deleyCON

| Spec | Valore |
|------|--------|
| Porte | 12x RJ45 Keystone |
| Categoria | CAT6A/CAT7 |
| Certificazione | 10 Gbit/s |

### U3 — Multipresa Rack 1U

| Spec | Valore |
|------|--------|
| Prese | 8x Schuko |
| Ingresso | IEC C14 (collegata a UPS) |
| Funzione | Alimentazione dispositivi con spina standard |
| Dispositivi collegati | Mini PC Lenovo |

### U2 — QNAP TS-435XeU

| Spec | Valore |
|------|--------|
| CPU | Marvell Octeon TX2 CN9131 quad-core 2.2GHz |
| Bay | 4x 3.5" HDD (RAID configurabile) |
| SFP+ | 2x 10GbE |
| SFP+ Port 1 | Uplink a Switch (trunk VLAN) |
| SFP+ Port 2 | Spare/backup |
| RJ45 | 2x 2.5GbE (gestione/backup) |
| Funzione | Media, Docker volumes, Backup |
| IP | 192.168.3.10 |

### Isolante — Neoprene 5mm

- Posizionato tra NAS (U2) e UPS (U1)
- Assorbe vibrazioni HDD
- Protegge UPS da calore residuo

### U1 — UPS Eaton 5P 650i Rack G2

| Spec | Valore |
|------|--------|
| Potenza | 650VA / 420W |
| Tecnologia | Line-interactive |
| Autonomia | ~10-15 min (carico medio) |
| Management | USB -> Proxmox (NUT) |

---

## Logica Termica

| Zona | Unita' | Strategia |
|------|--------|-----------|
| Top (U8) | Mini PC | Massima dissipazione verso l'esterno |
| U7 | Ventilato | Taglia la risalita di calore dal networking |
| Centro (U4-U6) | Networking + Patch | Calore moderato, buona ventilazione laterale |
| U3 | Multipresa | Passiva, nessun calore generato |
| Bottom (U1-U2) | NAS + UPS | Zona piu' fresca, ideale per HDD (< 40C) |

---

## Distribuzione Elettrica

```
                    ┌─────────────────────────────────────────┐
                    │           UPS Eaton 5P 650i             │
                    │              (4x C13)                   │
                    └─────┬─────┬─────┬─────┬─────────────────┘
                          │     │     │     │
                    C13 #1│     │     │     │C13 #4
                          │     │     │     │
                          ▼     │     │     ▼
                      ┌───────┐ │     │ ┌────────────────┐
                      │  NAS  │ │     │ │ Multipresa 1U  │
                      │ QNAP  │ │     │ │   (U3)         │
                      └───────┘ │     │ └───────┬────────┘
                                │     │         │
                          C13 #2│     │C13 #3   │ Schuko
                                │     │         │
                                ▼     ▼         ▼
                          ┌───────┐ ┌───────┐ ┌─────────┐
                          │UDM-SE │ │Switch │ │ Mini PC │
                          │       │ │  PoE  │ │ Lenovo  │
                          └───────┘ └───────┘ └─────────┘
```

| Presa UPS | Dispositivo | Connettore |
|-----------|-------------|------------|
| C13 #1 | NAS QNAP | IEC C14 |
| C13 #2 | UDM-SE | IEC C14 |
| C13 #3 | Switch PoE | IEC C14 |
| C13 #4 | Multipresa Rack (U3) | IEC C14 |

| Presa Multipresa | Dispositivo | Note |
|------------------|-------------|------|
| Schuko #1 | Mini PC Lenovo | Alimentatore esterno |
| Schuko #2-8 | Disponibili | Espansioni future |

> **Nota**: Tutti i dispositivi sono protetti da batteria UPS. I dispositivi con connettore IEC vanno direttamente all'UPS, quelli con spina standard passano dalla multipresa.

---

## Backbone di Rete (SFP+ 10GbE)

```
UDM-SE (SFP+) <--10G--> Switch (SFP+ Port 1)
                              │
                              │ 10G
                              ↓
                        NAS (SFP+ Port 1)
```

---

## Servizi in Esecuzione

### NAS QNAP (192.168.3.10)

| Servizio | Porta | Descrizione |
|----------|-------|-------------|
| Sonarr | 8989 | Gestione serie TV |
| Radarr | 7878 | Gestione film |
| Lidarr | 8686 | Gestione musica |
| Prowlarr | 9696 | Gestione indexer |
| Bazarr | 6767 | Sottotitoli automatici |
| qBittorrent | 8080 | Client torrent |
| NZBGet | 6789 | Client Usenet |
| Recyclarr | - | Sync profili Trash Guides |
| Huntarr | 9705 | Monitoring *arr |
| Cleanuparr | 11011 | Pulizia automatica |
| FlareSolverr | 8191 | Bypass Cloudflare |
| Pi-hole | 8081 | DNS ad-blocking |
| Home Assistant | 8123 | Automazione domotica |
| Portainer | 9443 | Gestione Docker |
| Duplicati | 8200 | Backup incrementale |
| Watchtower | 8383 | Auto-update container |
| Traefik | 80/443 | Reverse proxy (dashboard via traefik.home.local) |

### Mini PC Proxmox (192.168.3.20)

| Servizio | Porta | Descrizione |
|----------|-------|-------------|
| Plex | 32400 | Media server |
| Tailscale | — | VPN mesh |

---

## Codifica Colore Cavi di Rete

| Colore | Uso | Esempio |
|--------|-----|---------|
| 🟡 Giallo | Rack interno | NAS, Mini PC |
| 🔵 Blu | Dispositivi stanze | Camera, Studio, Soggiorno |
| 🟠 Arancione | PoE | Access Point, telecamere future |
| ⚪ Bianco | Management / Uplink | UDM-SE, Switch |
| 🔘 Grigio | Spare | Non assegnati |

> **Etichettatura**: Ogni cavo deve avere etichetta su entrambe le estremita' con: colore + numero + destinazione (es. "BLU-01 Studio/PC")

---

## Note

- **Rack**: Aperto lateralmente e superiormente (ventilazione passiva ottimale)
- **Pannello ventilato**: In U7 per isolare termicamente il Mini PC dal networking
- **Multipresa rack**: In U3, collegata all'UPS per dispositivi con spina standard
- **UPS**: Valutare upgrade a 1000-1500VA se si utilizza intensivamente il PoE

---

## Piano IP

### Topologia di rete

```
Internet <-> Iliad Box (router) <-> UDM-SE <-> Homelab (VLAN segmentate)
              192.168.1.254       192.168.1.1    192.168.x.0/24
                    ↑               (WAN)
              Rete legacy              ↓
              Vimar/IoT          Gateway VLAN
```

### Configurazione Iliad Box

| Parametro | Valore |
|-----------|--------|
| Modalita' | Router (NO bridge/ONT) |
| IP | 192.168.1.254 |
| DHCP | **Disabilitato** (lo gestisce UDM-SE) |
| DMZ | Abilitata verso 192.168.1.1 |
| Telefonia VoIP | Funzionante |

### Indirizzi IP

> Vedi `firewall-config.md` per la configurazione VLAN completa.

#### Rete Legacy — Iliad/Vimar (192.168.1.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Iliad Box | 192.168.1.254 | Router/modem, telefonia |
| UDM-SE (WAN) | 192.168.1.1 | Riceve IP via DMZ |
| Dispositivi Vimar | 192.168.1.x | Videocitofono, allarme, attuatori (statici) |

> Questa rete NON e' gestita dal UDM-SE. Resta per i dispositivi Vimar legacy collegati allo switch PoE nel quadro elettrico.

#### VLAN 2 — Management (192.168.2.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Gateway (UDM-SE) | 192.168.2.1 | Controller UniFi |
| Switch UniFi | 192.168.2.10 | USW-Enterprise-8-PoE |
| Access Point | 192.168.2.20 | U6-Pro |

#### VLAN 3 — Servers (192.168.3.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Gateway (UDM-SE) | 192.168.3.1 | — |
| NAS QNAP | 192.168.3.10 | Media stack, Pi-hole |
| Mini PC Proxmox | 192.168.3.20 | Plex, Tailscale |
| Stampante | 192.168.3.30 | Stampa |
| PC Desktop | 192.168.3.40 | Workstation |

#### VLAN 4 — Media (192.168.4.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Gateway (UDM-SE) | 192.168.4.1 | — |
| Smart TV, telefoni | DHCP (.100-.200) | Client Plex, gestione *arr |

#### VLAN 5 — Guest (192.168.5.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Gateway (UDM-SE) | 192.168.5.1 | — |
| Client ospiti | DHCP (.100-.200) | Solo accesso Internet |

#### VLAN 6 — IoT (192.168.6.0/24)

| Dispositivo | IP | Note |
|-------------|-----|------|
| Gateway (UDM-SE) | 192.168.6.1 | — |
| Alexa, videocamera nuova | DHCP (.100-.200) | Dispositivi smart WiFi |

### Note

- **Rete Legacy**: La subnet 192.168.1.0/24 resta per Iliad Box e dispositivi Vimar. Non e' gestita dal UDM-SE.
- **Double NAT**: Tecnicamente presente, ma irrilevante per homelab
- **Accesso Iliad**: Disponibile su 192.168.1.254 dalla rete (routing attraverso WAN)
- **Telefonia**: Funziona perche' Iliad resta in modalita' router
- **Documentazione VLAN**: Vedi `firewall-config.md`
