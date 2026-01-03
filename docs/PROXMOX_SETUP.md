# Proxmox Setup - Mini PC Lenovo IdeaCentre

> Guida per installare Proxmox VE sul Mini PC e configurare Plex con accesso remoto via Tailscale

---

## Prerequisiti

- [ ] Mini PC Lenovo IdeaCentre montato in rack
- [ ] Collegato a switch porta VLAN 3 (Servers)
- [ ] Monitor e tastiera per installazione iniziale
- [ ] Chiavetta USB (8GB+) per ISO Proxmox
- [ ] VLAN 3 configurata (vedi [NETWORK_SETUP.md](NETWORK_SETUP.md))

---

## Fase 1: Preparazione USB Avviabile

### 1.1 Download ISO Proxmox

1. Scaricare da: https://www.proxmox.com/en/downloads
2. Selezionare: Proxmox VE ISO Installer (ultima versione stabile)
3. Verificare checksum SHA256

### 1.2 Creare USB Avviabile

**Linux/macOS:**
```bash
# Identificare device USB
lsblk

# Scrivere ISO (sostituire /dev/sdX con device corretto)
sudo dd bs=4M if=proxmox-ve_*.iso of=/dev/sdX conv=fsync status=progress
```

**Windows:**
- Usare Rufus o balenaEtcher
- Selezionare ISO Proxmox
- Mode: DD Image

---

## Fase 2: Installazione Proxmox

### 2.1 Boot da USB

1. [ ] Inserire USB nel Mini PC
2. [ ] Accendere e premere F12 (o tasto boot menu Lenovo)
3. [ ] Selezionare USB come boot device
4. [ ] Selezionare "Install Proxmox VE"

### 2.2 Wizard Installazione

1. [ ] Accettare EULA
2. [ ] Selezionare disco per installazione
   - Se SSD NVMe disponibile, selezionarlo
   - Filesystem: ext4 (default) o ZFS (se RAM sufficiente)
3. [ ] Impostazioni locali:
   - Country: Italy
   - Timezone: Europe/Rome
   - Keyboard: Italian

### 2.3 Configurazione Rete

| Campo | Valore |
|-------|--------|
| Management Interface | eth0 (o interfaccia principale) |
| Hostname (FQDN) | proxmox.servers.local |
| IP Address | 192.168.3.20 |
| Netmask | 255.255.255.0 (/24) |
| Gateway | 192.168.3.1 |
| DNS Server | 192.168.3.1 (o 1.1.1.1) |

### 2.4 Credenziali

- [ ] Impostare password root sicura
- [ ] Email: tua@email.com (per notifiche)

### 2.5 Completare Installazione

1. [ ] Verificare riepilogo configurazione
2. [ ] Cliccare "Install"
3. [ ] Attendere completamento (~5-10 minuti)
4. [ ] Rimuovere USB al riavvio
5. [ ] Sistema avvia in Proxmox

### Verifica Installazione

```bash
# Da un PC sulla stessa VLAN
ping 192.168.3.20
```

Aprire browser: `https://192.168.3.20:8006`
- Accettare certificato self-signed
- Login: root / password impostata

---

## Fase 3: Configurazione Post-Installazione

### 3.1 Disabilitare Repository Enterprise

```bash
# SSH nel Proxmox
ssh root@192.168.3.20

# Commentare repo enterprise
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Aggiungere repo no-subscription
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
```

### 3.2 Aggiornare Sistema

```bash
apt update && apt full-upgrade -y
reboot
```

### 3.3 Rimuovere Popup Subscription

```bash
# Opzionale - rimuove popup licenza nella WebUI
sed -Ezi.bak "s/(Ext.Msg.show\(\{[^}]*license[^}]*\}\);)/void(0);/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy
```

### 3.4 Configurare Storage NFS dal NAS

Datacenter → Storage → Add → NFS

| Campo | Valore |
|-------|--------|
| ID | nas-media |
| Server | 192.168.3.10 |
| Export | /share/data/media |
| Content | Disk image, Container |

Aggiungere anche storage per backup:

| Campo | Valore |
|-------|--------|
| ID | nas-backup |
| Server | 192.168.3.10 |
| Export | /share/backup |
| Content | VZDump backup file |

---

## Fase 4: Creazione LXC Container per Plex

> LXC è più leggero di una VM completa e sufficiente per Plex

### 4.1 Download Template

Datacenter → proxmox → local → CT Templates → Templates

Scaricare: `ubuntu-22.04-standard` (o Debian 12)

### 4.2 Creare Container

Datacenter → proxmox → Create CT

**Tab General:**
| Campo | Valore |
|-------|--------|
| CT ID | 100 |
| Hostname | plex |
| Password | (password sicura) |
| SSH Public Key | (opzionale) |

**Tab Template:**
- Template: ubuntu-22.04-standard (o quello scaricato)

**Tab Disks:**
| Campo | Valore |
|-------|--------|
| Storage | local-lvm |
| Disk size | 16 GB |

**Tab CPU:**
- Cores: 4 (o quanti disponibili)

**Tab Memory:**
| Campo | Valore |
|-------|--------|
| Memory | 4096 MB |
| Swap | 512 MB |

**Tab Network:**
| Campo | Valore |
|-------|--------|
| Bridge | vmbr0 |
| IPv4 | Static |
| IPv4/CIDR | 192.168.3.21/24 |
| Gateway | 192.168.3.1 |

**Tab DNS:**
- Usa impostazioni host (default)

### 4.3 Configurare Mount Point NFS

Prima di avviare, aggiungere mount point per media:

```bash
# Sul host Proxmox
pct set 100 -mp0 /mnt/nas-media,mp=/media
```

Oppure via WebUI:
Container 100 → Resources → Add → Mount Point
- Storage: nas-media
- Mount Point: /media

### 4.4 Avviare Container e Installare Plex

```bash
# Avviare container
pct start 100

# Entrare nel container
pct enter 100

# Aggiornare sistema
apt update && apt upgrade -y

# Aggiungere repository Plex
curl https://downloads.plex.tv/plex-keys/PlexSign.key | gpg --dearmor -o /usr/share/keyrings/plex-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/plex-archive-keyring.gpg] https://downloads.plex.tv/repo/deb public main" > /etc/apt/sources.list.d/plexmediaserver.list

# Installare Plex
apt update
apt install plexmediaserver -y

# Verificare stato
systemctl status plexmediaserver
```

### Verifica Plex

Aprire browser: `http://192.168.3.21:32400/web`

---

## Fase 5: Configurazione Plex

### 5.1 Setup Iniziale

1. [ ] Accedere a `http://192.168.3.21:32400/web`
2. [ ] Login con account Plex (o crearne uno)
3. [ ] Dare nome al server: "Homelab Plex"
4. [ ] Configurazione iniziale guidata

### 5.2 Aggiungere Librerie

Add Library → Movies:
- Name: Film
- Folders: /media/movies

Add Library → TV Shows:
- Name: Serie TV
- Folders: /media/tv

Add Library → Music:
- Name: Musica
- Folders: /media/music

### 5.3 Impostazioni Consigliate

Settings → Library:
- [ ] Scan my library automatically: Enabled
- [ ] Run a partial scan when changes are detected: Enabled

Settings → Transcoder:
- [ ] Transcoder temporary directory: /tmp (o SSD dedicato)
- [ ] Hardware acceleration: (se GPU supportata)

Settings → Network:
- [ ] Enable Relay: Disabled (useremo Tailscale)
- [ ] Secure connections: Preferred

---

## Fase 6: Installazione Tailscale

> Tailscale fornisce accesso remoto sicuro senza port forwarding

### 6.1 Installare su Host Proxmox

```bash
# SSH nel Proxmox
ssh root@192.168.3.20

# Installare Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Avviare e autenticare
tailscale up

# Seguire link per autenticazione nel browser
```

### 6.2 Configurare come Subnet Router

Per accedere a tutta la rete locale via Tailscale:

```bash
# Abilitare IP forwarding
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
sysctl -p

# Riavviare Tailscale come subnet router
tailscale up --advertise-routes=192.168.3.0/24,192.168.4.0/24
```

### 6.3 Approvare Route in Tailscale Admin

1. Accedere a https://login.tailscale.com/admin/machines
2. Trovare "proxmox"
3. Cliccare "..." → Edit route settings
4. Approvare le subnet routes advertised

### 6.4 Installare Tailscale nel Container Plex (Alternativa)

Se preferisci accesso diretto solo a Plex:

```bash
# Entrare nel container
pct enter 100

# Installare Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

### Verifica Tailscale

```bash
# Sul Proxmox
tailscale status

# Da dispositivo remoto con Tailscale
ping 192.168.3.20  # Dovrebbe funzionare via Tailscale
```

---

## Fase 7: Configurazione Backup Proxmox

### 7.1 Aggiungere Storage Backup

Se non già fatto:
Datacenter → Storage → Add → NFS
- ID: nas-backup
- Server: 192.168.3.10
- Export: /share/backup
- Content: VZDump backup file

> **Nota**: I backup Proxmox verranno salvati in una sottocartella automatica (`dump/`).

### 7.2 Creare Backup Job Schedulato

Datacenter → Backup → Add

| Campo | Valore |
|-------|--------|
| Storage | nas-backup |
| Schedule | Weekly (Sun 02:00) |
| Selection mode | All |
| Mode | Snapshot |
| Compression | ZSTD |
| Retention | Keep Last: 4 |

### 7.3 Backup Manuale

Per backup immediato:
Container/VM → Backup → Backup now

---

## Fase 8: Configurazione Opzionale

### 8.1 Nginx Proxy Manager (Opzionale)

Per reverse proxy con SSL automatico:

```bash
# Creare altro LXC container (ID 101)
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

Accedere: `http://192.168.3.22:81`
Default login: admin@example.com / changeme

### 8.2 GPU Passthrough per Transcoding (Avanzato)

Se il Mini PC ha GPU Intel integrata:

```bash
# Sul host Proxmox
# Aggiungere moduli kernel
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules

# Per LXC, usare bind mount del device
# Modificare /etc/pve/lxc/100.conf
echo "lxc.cgroup2.devices.allow: c 226:* rwm" >> /etc/pve/lxc/100.conf
echo "lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir" >> /etc/pve/lxc/100.conf
```

Riavviare container e abilitare hardware transcoding in Plex.

---

## Verifica Finale

### Checklist Proxmox

- [ ] WebUI accessibile: `https://192.168.3.20:8006`
- [ ] Nessun errore in System → Syslog
- [ ] Storage NFS montato e accessibile
- [ ] Backup job configurato

### Checklist Plex

- [ ] WebUI accessibile: `http://192.168.3.21:32400/web`
- [ ] Librerie sincronizzate
- [ ] Playback locale funzionante
- [ ] Accesso remoto via Tailscale funzionante

### Checklist Tailscale

- [ ] `tailscale status` mostra connected
- [ ] Subnet routes approvate (se configurate)
- [ ] Accesso remoto a Plex funzionante

---

## Troubleshooting

| Problema | Causa | Soluzione |
|----------|-------|-----------|
| Container non parte | Risorse insufficienti | Aumentare RAM/CPU |
| NFS mount fallisce | Permessi o rete | Verificare export NFS su NAS |
| Plex non vede media | Mount point errato | Verificare /media nel container |
| Tailscale non connette | Firewall | Verificare regole UDM-SE |
| Transcoding lento | No GPU | Abilitare hardware acceleration |
| Backup fallisce | Spazio insufficiente | Verificare retention policy |

---

## Comandi Utili

```bash
# Stato container
pct list

# Entrare in container
pct enter 100

# Log container
pct console 100

# Restart container
pct restart 100

# Stato Tailscale
tailscale status

# Aggiornare Plex (nel container)
apt update && apt upgrade plexmediaserver -y

# Verificare mount NFS
df -h | grep nfs
```

---

## Prossimi Passi

Dopo aver completato il setup Proxmox:

1. → Procedere con [Configurazione Backup](../runbook-backup-restore.md)
2. → Tornare a [START_HERE.md](../START_HERE.md) Fase 7
