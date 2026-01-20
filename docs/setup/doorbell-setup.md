# Smart Doorbell Setup - Vimar View Door 7 Integration

> Guida per integrare una telecamera alla porta d'ingresso e visualizzare l'anteprima sul videocitofono Vimar View Door 7

---

## Overview

Questa guida spiega come aggiungere una telecamera alla porta d'ingresso e visualizzare l'anteprima sul videocitofono Vimar esistente quando qualcuno suona al campanello.

### Obiettivi

1. **Visualizzazione automatica** sul View Door 7 quando suonano
2. **Notifica su smartphone** con snapshot (opzionale, via Home Assistant)
3. **Registrazione video** degli eventi (opzionale)

---

## Opzione 1: Telecamera Elvox (Raccomandata)

La soluzione più semplice è usare una telecamera Elvox, compatibile nativamente con il sistema Due Fili Plus del View Door 7.

### Architettura

```
┌──────────────────┐                    ┌──────────────────┐
│  Telecamera      │   Due Fili Plus    │  Vimar View Door │
│  Elvox PoE       │ ◄────────────────► │  7 (40517)       │
│  192.168.1.x     │   integrazione     │  192.168.1.x     │
└──────────────────┘   nativa           └──────────────────┘
                                                 │
                                                 │ quando suonano
                                                 ▼
                                        ┌──────────────────┐
                                        │  Mostra video    │
                                        │  automaticamente │
                                        └──────────────────┘
```

### Hardware Elvox Consigliato

| Modello | Tipo | Risoluzione | Prezzo |
|---------|------|-------------|--------|
| **Elvox 46237** | Bullet PoE | 2MP | ~€150-200 |
| **Elvox 46239** | Dome PoE | 2MP | ~€150-200 |
| **Elvox 46249** | Bullet PoE | 4MP | ~€200-250 |
| **Elvox 46247** | Compact PoE | 2MP | ~€120-150 |

### Vantaggi Elvox

- **Integrazione nativa** con View Door 7 - zero configurazione
- **Stesso ecosistema** - gestione unificata in Elvox Device Manager
- **Evento automatico** - il video appare sul videocitofono quando suonano
- **Supporto Vimar** - assistenza diretta del produttore

### Installazione Elvox

1. **Posiziona** la telecamera accanto alla porta d'ingresso
2. **Collega** al PoE switch nel quadro elettrico (rete legacy 192.168.1.x)
3. **Apri Elvox Device Manager** sul PC
4. **Aggiungi telecamera** - verrà rilevata automaticamente
5. **Associa al campanello** - configura l'evento "mostra video quando suonano"
6. **Test** - premi il campanello e verifica che il View Door 7 mostri il feed

### Configurazione Evento in Elvox Device Manager

1. Vai su **Impianto** → **Eventi**
2. Crea nuova regola:
   - **Trigger**: Chiamata campanello / Posto esterno
   - **Azione**: Visualizza telecamera su View Door 7
3. Salva e sincronizza

---

## Opzione 2: Telecamera Terze Parti (Alternativa)

Se preferisci campanelli smart con funzionalità aggiuntive (rilevamento persone, audio bidirezionale, app dedicata), puoi usare modelli di terze parti con integrazione via Home Assistant.

### Architettura

```
┌──────────────────┐     RTSP/ONVIF     ┌──────────────────┐
│  Doorbell Camera │ ─────────────────► │  Home Assistant  │
│  (Reolink PoE)   │   192.168.6.x      │   192.168.3.10   │
└──────────────────┘                    └────────┬─────────┘
        │                                        │
        │ ONVIF (se supportato)                  │ Push + Snapshot
        ▼                                        ▼
┌──────────────────┐                    ┌──────────────────┐
│  Vimar View Door │                    │     iPhone       │
│  192.168.1.x     │                    │  HA Companion    │
└──────────────────┘                    └──────────────────┘
```

### Hardware Terze Parti

| Modello | Pro | Contro | Prezzo |
|---------|-----|--------|--------|
| **Reolink Video Doorbell PoE** | RTSP nativo, ONVIF, no cloud, 5MP | Integrazione Vimar da verificare | ~€100 |
| **Amcrest AD410** | RTSP, ONVIF, 2K, locale | App mediocre | ~€90 |
| **UniFi G4 Doorbell Pro PoE** | Integrazione UniFi nativa | Costoso, no ONVIF | ~€500 |

### Quando scegliere terze parti

- Vuoi **rilevamento AI** (persone, pacchi, veicoli)
- Preferisci **app dedicata** oltre a Vimar
- Hai bisogno di **audio bidirezionale** avanzato
- Vuoi **integrare con Home Assistant** per automazioni complesse

---

## Prerequisiti

- [ ] Cavo Ethernet dalla porta d'ingresso al rack/switch PoE
- [ ] Home Assistant attivo (`docker compose -f compose.yml -f compose.homeassistant.yml up -d`)
- [ ] iPhone con app Home Assistant Companion
- [ ] Accesso al software Elvox Device Manager (per integrazione Vimar)

---

## Step 1: Installazione Hardware

### 1.1 Posizionamento

1. Installa il campanello accanto alla porta d'ingresso
2. Collega il cavo Ethernet al PoE switch nel rack
3. Verifica che il LED del campanello si accenda

### 1.2 Configurazione di Rete

Il campanello va nella **VLAN 6 (IoT)** con IP riservato.

**IP consigliato**: `192.168.6.50` (fuori dal range DHCP .100-.200)

#### Configurazione su UDM-SE

1. Apri UniFi Network → **Settings** → **Networks** → **VLAN 6 (IoT)**
2. Vai su **DHCP** → **DHCP Reservations**
3. Aggiungi reservation:
   - **MAC Address**: (trova nelle impostazioni del campanello)
   - **IP Address**: `192.168.6.50`
   - **Name**: `Doorbell-Camera`

---

## Step 2: Configurazione Campanello

### Reolink Video Doorbell PoE

1. Scarica l'app **Reolink** su smartphone
2. Aggiungi il dispositivo tramite scansione QR o ricerca LAN
3. Configura:
   - **Nome**: `Doorbell Ingresso`
   - **WiFi**: Non necessario (usa PoE)
   - **Notifiche**: Abilita nell'app
4. Nelle impostazioni avanzate:
   - **RTSP**: Abilitato (porta 554)
   - **ONVIF**: Abilitato (porta 8000)
   - **Username/Password**: Imposta credenziali sicure

### URL RTSP

```
rtsp://username:password@192.168.6.50:554/h264Preview_01_main
rtsp://username:password@192.168.6.50:554/h264Preview_01_sub  (bassa qualità)
```

---

## Step 3: Integrazione Home Assistant

### 3.1 Aggiungi Integrazione Reolink

1. Apri Home Assistant → **Settings** → **Devices & Services**
2. Click **+ Add Integration**
3. Cerca **Reolink**
4. Inserisci:
   - **Host**: `192.168.6.50`
   - **Username**: (quello configurato)
   - **Password**: (quella configurata)
5. Click **Submit**

Home Assistant creerà automaticamente:
- Entity camera: `camera.doorbell_ingresso`
- Entity binary_sensor: `binary_sensor.doorbell_ingresso_visitor` (quando suonano)
- Entity button: per parlare/rispondere

### 3.2 Automazione Notifica Campanello

Crea un'automazione per ricevere notifica con snapshot quando qualcuno suona.

#### Via UI

1. **Settings** → **Automations & Scenes** → **+ Create Automation**
2. **Trigger**:
   - Type: **State**
   - Entity: `binary_sensor.doorbell_ingresso_visitor`
   - From: `off`
   - To: `on`
3. **Action**:
   - Type: **Call service**
   - Service: `notify.mobile_app_<your_iphone>`
   - Edit in YAML:

```yaml
service: notify.mobile_app_<your_iphone>
data:
  title: "Campanello"
  message: "Qualcuno alla porta!"
  data:
    push:
      sound: default
      critical: 1
      volume: 0.8
    attachment:
      url: /api/camera_proxy/camera.doorbell_ingresso
      content-type: jpeg
    actions:
      - action: "OPEN_GATE"
        title: "Apri Cancello"
      - action: "IGNORE"
        title: "Ignora"
```

4. Nome: `Doorbell Notification`
5. **Save**

#### Via YAML

Aggiungi a `automations.yaml`:

```yaml
- id: doorbell_notification
  alias: "Doorbell - Notify on Ring"
  description: "Send push notification with camera snapshot when doorbell rings"
  trigger:
    - platform: state
      entity_id: binary_sensor.doorbell_ingresso_visitor
      from: "off"
      to: "on"
  condition: []
  action:
    - service: notify.mobile_app_<your_iphone>
      data:
        title: "Campanello"
        message: "Qualcuno alla porta!"
        data:
          push:
            sound: default
            critical: 1
            volume: 0.8
          attachment:
            url: /api/camera_proxy/camera.doorbell_ingresso
            content-type: jpeg
          actions:
            - action: "OPEN_GATE"
              title: "Apri Cancello"
            - action: "IGNORE"
              title: "Ignora"
  mode: single
```

---

## Step 4: Integrazione Vimar View Door 7

Il View Door 7 (40517) è un videocitofono IP del sistema Due Fili Plus. Supporta l'aggiunta di telecamere IP esterne tramite il software **Elvox Device Manager**.

### 4.1 Verifica Compatibilità ONVIF

1. Apri **Elvox Device Manager** sul PC
2. Connettiti al sistema Due Fili Plus
3. Cerca la sezione **Telecamere IP** o **CCTV Integration**
4. Verifica se supporta profilo ONVIF S (streaming)

### 4.2 Aggiungi Telecamera al Vimar

Se il View Door 7 supporta telecamere ONVIF:

1. In Elvox Device Manager → **Impianto** → **Telecamere**
2. Click **Aggiungi telecamera IP**
3. Configura:
   - **Nome**: `Ingresso`
   - **Tipo**: ONVIF
   - **IP**: `192.168.6.50`
   - **Porta ONVIF**: `8000`
   - **Username/Password**: credenziali del campanello
4. **Associa** la telecamera al posto esterno o al videocitofono

### 4.3 Configurazione Evento

Per mostrare automaticamente la telecamera quando suonano:

1. In Elvox Device Manager → **Eventi**
2. Crea regola:
   - **Trigger**: Chiamata da posto esterno / Campanello
   - **Azione**: Mostra telecamera `Ingresso` su View Door 7
3. Salva e sincronizza con l'impianto

### 4.4 Note sulla Rete Legacy

Il sistema Vimar è sulla rete legacy `192.168.1.x`, separata dalla VLAN IoT `192.168.6.x`.

**Opzioni di connettività**:

| Opzione | Pro | Contro |
|---------|-----|--------|
| **Route tra reti** | Comunicazione diretta | Richiede regole firewall, riduce isolamento |
| **Porta campanello su legacy** | Semplice, rete unica | Meno sicuro, no segmentazione |
| **Proxy RTSP via HA** | Mantiene isolamento | Latenza aggiuntiva |

**Raccomandazione**: Se il View Door 7 deve accedere direttamente al campanello, considera di mettere il campanello sulla rete legacy `192.168.1.x` con IP statico (es. `192.168.1.50`).

---

## Step 5: Alternativa - Display Dedicato

Se l'integrazione diretta con Vimar non è possibile, usa un display dedicato.

### Echo Show / Fire TV

1. Installa skill **Home Assistant** su Alexa
2. Abilita la camera `camera.doorbell_ingresso`
3. Dì "Alexa, mostra la porta d'ingresso"

### Tablet Android/iPad

1. Installa app **Home Assistant**
2. Crea dashboard con card camera
3. Abilita notifiche per automazione `doorbell_notification`
4. Monta il tablet vicino alla porta

### Home Assistant Dashboard Card

```yaml
type: picture-entity
entity: camera.doorbell_ingresso
camera_view: live
show_state: false
show_name: false
tap_action:
  action: more-info
```

---

## Firewall Rules

Se mantieni il campanello in VLAN 6 e vuoi che il Vimar (rete legacy) possa accedervi:

### Regola su UDM-SE (se gestisci routing)

```
Nome: Allow Legacy → Doorbell Camera
Azione: Accept
Protocollo: TCP
Sorgente: 192.168.1.0/24 (Legacy)
Destinazione: 192.168.6.50 (Doorbell)
Porta: 554, 8000 (RTSP, ONVIF)
```

### Regola esistente già sufficiente

La regola **#9 (Allow IoT → Home Assistant)** permette al campanello di comunicare con HA per le automazioni.

---

## Test e Verifica

### Test RTSP Stream

```bash
# Da qualsiasi PC sulla rete
ffplay rtsp://username:password@192.168.6.50:554/h264Preview_01_main

# Oppure con VLC
vlc rtsp://username:password@192.168.6.50:554/h264Preview_01_main
```

### Test Notifica Campanello

1. Premi il pulsante del campanello
2. Verifica che arrivi notifica su iPhone con snapshot
3. Verifica che l'azione "Apri Cancello" funzioni (se configurata)

### Test Integrazione Vimar

1. Premi il pulsante del campanello o del posto esterno
2. Verifica che il View Door 7 mostri il feed della telecamera
3. Verifica la qualità video e la latenza

---

## Troubleshooting

### Campanello non raggiungibile

```bash
# Verifica connettività
ping 192.168.6.50

# Verifica porta RTSP
nc -zv 192.168.6.50 554

# Verifica porta ONVIF
nc -zv 192.168.6.50 8000
```

### Home Assistant non trova il campanello

- Verifica che VLAN 6 possa raggiungere VLAN 3 (regola firewall #9)
- Verifica credenziali nel setup integrazione
- Controlla log HA: **Settings** → **System** → **Logs**

### Vimar non mostra la telecamera

- Verifica compatibilità ONVIF del View Door 7 (contatta supporto Vimar)
- Verifica che le reti possano comunicare
- Prova con URL RTSP diretto invece di ONVIF

### Notifiche non arrivano

Segui la guida [Notifications Setup](notifications-setup.md) per verificare:
- App HA Companion installata e configurata
- Permessi notifiche abilitati
- Automazione attiva e senza errori

---

## Riferimenti

- [Home Assistant Reolink Integration](https://www.home-assistant.io/integrations/reolink/)
- [Reolink RTSP Stream](https://support.reolink.com/hc/en-us/articles/360007010473)
- [Vimar View Door 7 Manuale](https://www.vimar.com/it/it/catalog/product/index/code/40517)
- [Elvox Device Manager](https://www.vimar.com/it/it/elvox-device-manager)
- [ONVIF Profile S](https://www.onvif.org/profiles/profile-s/)
