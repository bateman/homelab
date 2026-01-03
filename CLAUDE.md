# CLAUDE.md - Guida Repository Homelab

## Panoramica Progetto

Questo repository contiene la configurazione infrastructure-as-code completa per un homelab basato su NAS QNAP TS-435XeU e Mini PC Lenovo con Proxmox. Il setup segue le best practice di Trash Guides per la gestione media con supporto hardlinking.

## Architettura

### Hardware
- **NAS**: QNAP TS-435XeU (192.168.3.10) - Esegue lo stack Docker media
- **Mini PC**: Lenovo IdeaCentre (192.168.3.20) - Esegue Proxmox con Plex
- **Rete**: UniFi UDM-SE + USW-Enterprise-8-PoE con segmentazione VLAN
- **Rack**: 8U con ottimizzazione raffreddamento passivo

### Topologia di Rete
- **VLAN 2** (192.168.2.0/24): Management - UDM-SE, Switch, AP
- **VLAN 3** (192.168.3.0/24): Servers - NAS, Proxmox, PC Desktop, Stampante
- **VLAN 4** (192.168.4.0/24): Media - Smart TV, telefoni, tablet
- **VLAN 5** (192.168.5.0/24): Guest - Accesso internet isolato
- **VLAN 6** (192.168.6.0/24): IoT - Alexa, dispositivi smart
- **Legacy** (192.168.1.0/24): Iliad Box + dispositivi Vimar (non gestita da UDM-SE)

## Struttura Repository

```
homelab/
├── docker-compose.yml      # Definizione stack Docker principale
├── Makefile                # Comandi gestione stack
├── setup-folders.sh        # Creazione struttura cartelle iniziale
├── recyclarr.yml           # Sync profili qualita' Trash Guides
├── recyclarr-snippet.yml   # Snippet configurazione Recyclarr
├── rack-homelab-config.md  # Layout rack hardware e piano IP
├── firewall-config.md      # Regole firewall UDM-SE e config VLAN
├── runbook-backup-restore.md       # Procedure backup/restore
└── checklist-qnap-deployment.md    # Checklist deployment iniziale
```

## Servizi Docker (su NAS 192.168.3.10)

| Servizio | Porta | Descrizione |
|----------|-------|-------------|
| Sonarr | 8989 | Gestione serie TV |
| Radarr | 7878 | Gestione film |
| Lidarr | 8686 | Gestione musica |
| Prowlarr | 9696 | Gestione indexer |
| Bazarr | 6767 | Gestione sottotitoli |
| qBittorrent | 8080 | Client torrent |
| SABnzbd | 8085 | Client Usenet |
| Huntarr | 7500 | Monitoring *arr |
| Cleanuparr | 11011 | Pulizia automatica |
| Pi-hole | 8081 | DNS ad-blocking |
| Home Assistant | 8123 | Automazione domotica |
| Portainer | 9443 | Gestione Docker |
| FlareSolverr | 8191 | Bypass Cloudflare |

## Comandi Comuni

```bash
# Gestione stack (via Makefile)
make setup      # Crea struttura cartelle (eseguire una volta)
make up         # Avvia tutti i container
make down       # Ferma tutti i container
make restart    # Restart completo
make pull       # Aggiorna immagini Docker
make logs       # Segui tutti i logs
make status     # Stato container e utilizzo risorse
make health     # Health check tutti i servizi
make backup     # Backup configurazioni
make urls       # Mostra tutti gli URL WebUI

# Specifici per servizio
make logs-sonarr    # Logs per servizio specifico
make shell-radarr   # Shell nel container
```

## Configurazioni Chiave

### Variabili Ambiente
- `PUID=1000` / `PGID=100` - ID utente/gruppo container
- `TZ=Europe/Rome` - Fuso orario
- `UMASK=002` - Permessi file

### Struttura Cartelle (conforme Trash Guides)
```
/share/data/
├── torrents/
│   ├── movies/
│   ├── tv/
│   └── music/
├── usenet/
│   ├── incomplete/
│   └── complete/{movies,tv,music}/
└── media/
    ├── movies/
    ├── tv/
    └── music/
```

**Critico**: Tutti i path sotto `/share/data` devono essere sullo stesso filesystem perche' l'hardlinking funzioni.

### Verifica Hardlinking
```bash
ls -li /share/data/torrents/movies/file.mkv /share/data/media/movies/Film/file.mkv
# Stesso numero inode = hardlink funzionante
```

## Linee Guida Sviluppo

### Quando modifichi docker-compose.yml
1. Tutti i servizi *arr montano `/share/data:/data` per supporto hardlink
2. Usa anchor YAML (`&common-env`) per variabili ambiente condivise
3. Mantieni relazioni `depends_on` tra servizi
4. Conserva label Watchtower per auto-update

### Quando modifichi regole firewall
1. Le regole sono processate in ordine - la posizione conta
2. Includi sempre "Allow Established/Related" come prima regola
3. Usa gruppi IP/Porte per manutenibilita'
4. Le regole di blocco devono venire dopo le regole allow specifiche
5. Termina con catch-all "Block All Inter-VLAN"

### Quando aggiungi nuovi servizi
1. Aggiungi a `docker-compose.yml` con environment/volumes appropriati
2. Aggiorna `setup-folders.sh` se servono nuove directory config
3. Aggiungi endpoint health check al target health del `Makefile`
4. Aggiorna target urls del `Makefile` con nuova WebUI
5. Documenta nella tabella servizi di `rack-homelab-config.md`
6. Aggiungi regole firewall se serve accesso inter-VLAN

## Posizione API Key

Le API key sono salvate nella config di ogni servizio e vanno recuperate da:
- Sonarr/Radarr/Lidarr/Prowlarr: Settings -> General -> API Key
- qBittorrent: Settings -> WebUI -> Authentication
- SABnzbd: Config -> General -> API Key
- Password Pi-hole: file `.env` (`PIHOLE_PASSWORD`)

## Strategia Backup

- **Config Docker**: Backup giornaliero via `make backup` -> `/share/backup/`
- **Config QTS**: Settimanale via Control Panel -> Backup/Restore
- **VM Proxmox**: Settimanale su NAS via mount NFS
- **Offsite**: Rclone verso Backblaze B2 o rsync via Tailscale

Vedi `runbook-backup-restore.md` per procedure dettagliate.

## Troubleshooting

### Container non parte
```bash
docker compose logs <service>
# Verifica permessi
chown -R 1000:100 ./config/<service>
```

### Hardlink non funzionano
- Verifica che sorgente e destinazione siano sullo stesso filesystem
- Controlla `Use Hardlinks instead of Copy: Yes` nelle impostazioni *arr
- Testa manualmente con comando `ln`

### Problemi connettivita' rete
- Verifica assegnazione VLAN sulla porta switch
- Controlla regole firewall in UDM-SE
- Testa con `ping` dalla VLAN rilevante

### Servizio non accessibile da altra VLAN
- Controlla regole firewall in `firewall-config.md`
- Verifica che mDNS reflection sia abilitato se necessario
- Verifica che il gruppo porte includa la porta del servizio

## Note Importanti

- Home Assistant usa `network_mode: host` per discovery dispositivi
- Iliad Box (192.168.1.254) resta come router upstream (double NAT)
- Tailscale su Mini PC fornisce accesso remoto senza port forwarding
- Container Station 3 richiesto su QNAP per Docker Compose v2
