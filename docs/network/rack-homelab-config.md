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
┃ U3  │ 🌀 Pannello ventilato #2                                                ┃
┃     │   • Protegge gli HDD del NAS dal calore proveniente dall'alto           ┃
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

### U8 — Lenovo IdeaCentre Mini Gen 10

| Spec | Valore |
|------|--------|
| CPU | Intel Core i5-1240H (Quick Sync) |
| RAM | 16GB DDR5 |
| Storage | 1TB M.2 NVMe PCIe Gen4 |
| Network | 1x 2.5GbE RJ45 |
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

### U3 — Pannello Ventilato #2

- Ubiquiti UACC-Rack-Panel-Vented-1U
- Protezione termica per HDD del NAS

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

### U1 — UPS Riello Vision Rack VSR 800

| Spec | Valore |
|------|--------|
| Potenza | 800VA / 640W |
| Tecnologia | Line-interactive |
| Autonomia | ~15-20 min (carico medio) |
| Management | USB -> Proxmox (NUT) |

---

## Logica Termica

| Zona | Unita' | Strategia |
|------|--------|-----------|
| Top (U8) | Mini PC | Massima dissipazione verso l'esterno |
| U7 | Ventilato #1 | Taglia la risalita di calore dal networking |
| Centro (U4-U6) | Networking + Patch | Calore moderato, buona ventilazione laterale |
| U3 | Ventilato #2 | Scudo termico per proteggere gli HDD |
| Bottom (U1-U2) | NAS + UPS | Zona piu' fresca, ideale per HDD (< 40C) |

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
| Huntarr | 9705 | Monitoring *arr |
| Cleanuparr | 11011 | Pulizia automatica |
| Pi-hole | 8081 | DNS ad-blocking |
| Home Assistant | 8123 | Automazione domotica |
| Portainer | 9443 | Gestione Docker |
| Traefik | 80/443/8082 | Reverse proxy |

### Mini PC Proxmox (192.168.3.20)

| Servizio | Porta | Descrizione |
|----------|-------|-------------|
| Plex | 32400 | Media server |
| Tailscale | — | VPN mesh |

---

## Note

- **Rack**: Aperto lateralmente e superiormente (ventilazione passiva ottimale)
- **Secondo pannello ventilato**: Puo' essere rimosso per guadagnare 1U di espansione
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
