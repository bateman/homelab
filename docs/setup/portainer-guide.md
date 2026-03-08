# Portainer — Guida agli Scenari d'Uso

> Quando e perché usare Portainer nel tuo homelab, e quando usare CLI/Makefile

---

## Overview

Portainer è una GUI web per gestire Docker. Nel contesto di questo homelab, dove deployment e configurazione sono già codificati in compose file e Makefile, Portainer serve principalmente come **strumento operativo** per monitoraggio, troubleshooting e operazioni rapide senza dover aprire una sessione SSH.

---

## Accesso

| Metodo | URL | Autenticazione |
|--------|-----|----------------|
| Traefik + Authelia (raccomandato) | `https://portainer.home.local` | SSO con 2FA |
| Diretto | `https://192.168.3.10:9443` | Solo auth interna Portainer |

> [!IMPORTANT]
> Usare sempre l'accesso via Traefik. L'accesso diretto sulla porta 9443 bypassa Authelia e si affida solo all'autenticazione built-in di Portainer.

---

## Scenari d'Uso Concreti

### Troubleshooting

| Scenario | Cosa fare in Portainer |
|----------|----------------------|
| Un servizio *arr non risponde | **Containers** → click sul container → **Logs** per vedere errori in tempo reale |
| Sonarr/Radarr si riavvia in loop | **Containers** → verificare **Status** e **Restart Count** per capire se è un crash loop |
| Gluetun perde la connessione VPN | **Containers** → `gluetun` → **Logs** → cercare errori di handshake o timeout |
| Un container usa troppa RAM | **Containers** → colonna **Memory** per confrontare il consumo di tutti i container a colpo d'occhio |
| qBittorrent non scarica | **Containers** → `gluetun` → **Logs** per verificare lo stato del tunnel VPN |

### Operazioni Rapide

| Scenario | Cosa fare in Portainer |
|----------|----------------------|
| Riavviare un singolo container | **Containers** → selezionare → **Restart** (senza toccare gli altri servizi) |
| Fermare temporaneamente un servizio | **Containers** → selezionare → **Stop** |
| Aprire una shell dentro un container | **Containers** → click → **Console** → selezionare `/bin/sh` o `/bin/bash` |
| Ricreare un container con la stessa config | **Containers** → click → **Recreate** |

### Ispezione e Debug

| Cosa ispezionare | Dove trovarlo |
|-----------------|---------------|
| Variabili d'ambiente di un container | **Containers** → click → **Inspect** → sezione Environment |
| Volumi montati e relativi path | **Containers** → click → **Inspect** → sezione Mounts |
| Network e IP interni dei container | **Containers** → click → **Inspect** → sezione Network |
| Porte esposte e mapping | **Containers** → click → **Inspect** → sezione Ports |
| Immagine in uso e tag | **Containers** → colonna **Image** |

### Manutenzione e Pulizia

#### Immagini

| Scenario | Cosa fare in Portainer |
|----------|----------------------|
| Trovare immagini non più utilizzate | **Images** → click **Filter** → spuntare **Unused** (etichetta arancione) |
| Eliminare immagini obsolete | **Images** → filtrare per Unused → selezionare con checkbox → **Remove** |
| Verificare quale immagine usa un container | **Containers** → colonna **Image** (nome e tag) |

> [!NOTE]
> Watchtower (`WATCHTOWER_CLEANUP=true`) rimuove automaticamente le vecchie immagini dopo aver aggiornato un container. Le immagini "Unused" in Portainer sono tipicamente residui di aggiornamenti manuali o container rimossi.

#### Volumi

| Scenario | Cosa fare in Portainer |
|----------|----------------------|
| Vedere i volumi e il loro stato | **Volumes** → lista con nome, driver, mount point e stato (Unused/In use) |
| Eliminare volumi orfani | **Volumes** → selezionare i volumi non in uso → **Remove** |

> [!IMPORTANT]
> Portainer CE **non mostra le dimensioni** dei volumi Docker. Per verificare lo spazio occupato usare da CLI: `docker system df -v`.

#### Reti

| Scenario | Cosa fare in Portainer |
|----------|----------------------|
| Vedere le reti Docker configurate | **Networks** → lista con nome, driver, scope e subnet |
| Verificare quali container sono collegati a una rete | **Networks** → click su una rete → sezione **Containers** |
| Rimuovere reti non utilizzate | **Networks** → selezionare → **Remove** (solo se nessun container è collegato) |

> [!NOTE]
> Portainer CE non offre una mappa visuale delle reti. La visualizzazione è una lista tabellare — per vedere i container collegati serve entrare nel dettaglio di ogni rete.

#### Pulizia massiva

Portainer CE **non ha un equivalente di `docker system prune`**. Per la pulizia massiva usare:

```bash
make clean    # docker system prune + docker volume prune (con conferma interattiva)
```

#### Riepilogo strumenti di pulizia

| Strumento | Cosa pulisce | Quando |
|-----------|-------------|--------|
| **Watchtower** | Vecchie immagini dopo aggiornamento | Automatico, daily 08:30 |
| **Portainer** | Immagini/volumi/reti selezionati manualmente | On-demand, da GUI |
| **`make clean`** | Tutto: container fermati, immagini dangling, volumi orfani, reti inutilizzate | On-demand, da CLI |
| **Cleanuparr** | Download bloccati/falliti nelle code *arr | Automatico, ogni 10-15 min |

### Visione d'Insieme

La dashboard di Portainer mostra in una sola schermata:

- Numero totale di container (running/stopped/unhealthy)
- Consumo aggregato di CPU e RAM
- Immagini in uso e spazio disco
- Volumi e reti configurati

Questo equivale a eseguire `docker ps -a`, `docker stats`, `docker images` e `docker volume ls` tutti insieme, ma con una visualizzazione grafica immediata.

---

## Portainer vs CLI/Makefile

| Operazione | Portainer | CLI / Makefile |
|-----------|-----------|----------------|
| Stato di tutti i container | Dashboard visuale immediata | `make health` o `docker ps` |
| Log di un container | Click → Logs (streaming, filtrabili) | `docker logs -f <nome>` |
| Riavvio singolo container | Click → Restart | `docker restart <nome>` |
| Shell in un container | Click → Console | `docker exec -it <nome> sh` |
| Deploy/aggiornamento stack | ❌ Usare `make up` | `make up` (compose + .env) |
| Modifica configurazione | ❌ Editare compose file | Editare YAML → `make up` |
| Ispezione variabili/volumi/network | Click → Inspect (tutto visuale) | `docker inspect <nome>` (JSON) |
| Confronto risorse tra container | Colonne sortabili | `docker stats` (testo, non ordinabile) |
| Eliminare immagini unused | Images → Filter Unused → Remove | `docker image prune` |
| Pulizia massiva (prune) | ❌ Non disponibile | `make clean` |
| Spazio disco volumi | ❌ Non disponibile | `docker system df -v` |

**Regola pratica:**
- **Portainer** → monitoraggio, troubleshooting, operazioni rapide su singoli container
- **CLI/Makefile** → deployment, configurazione, automazione, modifiche allo stack

---

## Sicurezza

Portainer ha **accesso diretto al Docker socket** (`/var/run/docker.sock`), il che gli dà controllo completo su tutti i container dell'host. Per questo motivo:

| Misura | Stato |
|--------|-------|
| Accesso via Traefik con Authelia 2FA | ✅ Configurato (`two_factor` policy) |
| HTTPS obbligatorio | ✅ Porta 9443 (solo HTTPS) |
| Monitoraggio via Uptime Kuma | ✅ Configurato |
| Backup automatico del database | ✅ `make backup-portainer` (daily 22:55) |
| Socket in read-only | ✅ Montato con `:ro` |

> [!NOTE]
> Nonostante il socket sia montato read-only nel compose file, Portainer può comunque eseguire operazioni di scrittura tramite l'API Docker. Il flag `:ro` impedisce al container di modificare il file del socket stesso, ma non limita le chiamate API attraverso di esso.
