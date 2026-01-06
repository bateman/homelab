# Setup Notifiche - Uptime Kuma via Home Assistant

> Guida per configurare notifiche push iOS dagli alert di Uptime Kuma tramite Home Assistant

---

## Panoramica

Questa guida spiega come ricevere notifiche push su iPhone quando Uptime Kuma rileva un servizio down, utilizzando Home Assistant come ponte.

### Architettura

```
┌──────────────┐     webhook      ┌──────────────────┐     push      ┌─────────┐
│ Uptime Kuma  │ ───────────────► │  Home Assistant  │ ────────────► │  iPhone │
│  (monitor)   │   HTTP POST      │   (automazione)  │   APNs        │  (app)  │
└──────────────┘                  └──────────────────┘               └─────────┘
   :3001                              :8123                         HA Companion
```

### Perche' questa soluzione

- **Gratuita**: nessun costo, nessun abbonamento
- **Gia' nello stack**: Home Assistant e' gia' configurato
- **Notifiche native iOS**: push istantanee, supporto notifiche critiche
- **Nessuna dipendenza esterna**: funziona anche senza internet (in LAN)

---

## Prerequisiti

- [ ] Uptime Kuma attivo (`https://uptime.home.local` o `http://192.168.3.10:3001`)
- [ ] Home Assistant attivo (`https://ha.home.local` o `http://192.168.3.10:8123`)
- [ ] iPhone con iOS 14+

---

## Passo 1: Installare l'App iOS

1. Scarica **Home Assistant** dall'App Store (gratuita)
2. Apri l'app e connettiti al server:
   - URL interno: `http://192.168.3.10:8123`
   - Oppure via Tailscale: `https://ha.home.local`
3. Effettua il login con le tue credenziali HA
4. Quando richiesto, **consenti le notifiche**
5. Completa la configurazione iniziale dell'app

### Trovare il Nome del Dispositivo

Dopo la configurazione, HA crea automaticamente un servizio di notifica per il tuo dispositivo.

1. Vai in HA → **Impostazioni** → **Dispositivi e servizi**
2. Cerca **Mobile App** o il nome del tuo iPhone
3. Clicca sul dispositivo
4. Nota il nome del servizio, sara' qualcosa come:
   - `notify.mobile_app_iphone_di_mario`
   - `notify.mobile_app_iphone`

> **Importante**: Annota questo nome esatto, servira' per configurare l'automazione.

---

## Passo 2: Configurare l'Automazione in Home Assistant

Hai due opzioni: via UI (consigliata) o via YAML.

### Opzione A: Via UI (Consigliata)

1. Vai in HA → **Impostazioni** → **Automazioni e scene**
2. Clicca **+ Crea automazione** → **Crea nuova automazione**
3. Configura il **Trigger**:
   - Tipo trigger: **Webhook**
   - Webhook ID: `uptime-kuma-alert`
   - Metodi consentiti: `POST`
   - Solo locale: `Si`
4. Configura l'**Azione**:
   - Tipo azione: **Chiama servizio**
   - Servizio: `notify.mobile_app_<nome_tuo_iphone>`
   - Clicca sui tre puntini → **Modifica in YAML**
   - Inserisci:
     ```yaml
     service: notify.mobile_app_<nome_tuo_iphone>
     data:
       title: "{{ trigger.json.monitor.name | default('Uptime Kuma') }}"
       message: "{{ trigger.json.heartbeat.msg | default('Status changed') }}"
       data:
         push:
           sound: default
         url: "https://uptime.home.local"
     ```
5. Dai un nome: `Uptime Kuma Alerts`
6. **Salva**

### Opzione B: Via YAML

Aggiungi questa automazione al file `automations.yaml` di Home Assistant:

```yaml
- id: uptime_kuma_notifications
  alias: "Uptime Kuma Alerts"
  description: "Forward Uptime Kuma alerts to iOS via push notification"
  trigger:
    - platform: webhook
      webhook_id: uptime-kuma-alert
      allowed_methods:
        - POST
      local_only: true
  condition: []
  action:
    - service: notify.mobile_app_<nome_tuo_iphone>
      data:
        title: "{{ trigger.json.monitor.name | default('Uptime Kuma') }}"
        message: "{{ trigger.json.heartbeat.msg | default('Status changed') }}"
        data:
          push:
            sound: default
            # Decommentare per notifiche critiche (bypass silenzioso)
            # critical: 1
            # volume: 1.0
          url: "https://uptime.home.local"
  mode: parallel
  max: 10
```

Dopo aver modificato il file, riavvia Home Assistant:
- Impostazioni → Sistema → Riavvia

> **Nota**: Sostituisci `<nome_tuo_iphone>` con il nome reale del dispositivo trovato al Passo 1.

---

## Passo 3: Configurare Uptime Kuma

1. Apri Uptime Kuma: `https://uptime.home.local` (o `http://192.168.3.10:3001`)
2. Vai in **Settings** (icona ingranaggio) → **Notifications**
3. Clicca **Setup Notification**
4. Configura:
   - **Notification Type**: `Home Assistant`
   - **Friendly Name**: `Home Assistant iOS`
   - **Home Assistant URL**: `http://localhost:8123`
   - **Webhook URL path**: `/api/webhook/uptime-kuma-alert`
5. Clicca **Test** per verificare
6. Se il test funziona, clicca **Save**

> **Nota**: Si usa `localhost` perche' Home Assistant gira in `network_mode: host` sullo stesso NAS di Uptime Kuma.

### Associare la Notifica ai Monitor

Per ogni monitor che vuoi monitorare:

1. Vai sul monitor esistente o creane uno nuovo
2. Nella sezione **Notifications**, abilita `Home Assistant iOS`
3. Salva

---

## Test Manuale

Puoi testare il webhook direttamente con curl:

```bash
curl -X POST http://192.168.3.10:8123/api/webhook/uptime-kuma-alert \
  -H "Content-Type: application/json" \
  -d '{
    "monitor": {"name": "Test Service"},
    "heartbeat": {"msg": "Service is DOWN - test notification"}
  }'
```

Dovresti ricevere una notifica push sull'iPhone entro pochi secondi.

---

## Notifiche Critiche (Opzionale)

Per ricevere notifiche anche quando l'iPhone e' in modalita' silenzioso o Non Disturbare:

1. Modifica l'automazione in HA
2. Aggiungi questi parametri all'azione:
   ```yaml
   data:
     push:
       sound: default
       critical: 1
       volume: 1.0
   ```
3. L'app iOS chiedera' il permesso per le notifiche critiche

> **Attenzione**: Le notifiche critiche bypassano TUTTE le impostazioni di silenzio. Usale solo per alert veramente importanti (servizi critici down).

---

## Troubleshooting

### La notifica non arriva

| Verifica | Come |
|----------|------|
| Servizio notify esiste | HA → Strumenti sviluppatori → Servizi → cerca `notify.mobile_app_*` |
| Automazione attiva | HA → Impostazioni → Automazioni → verifica stato |
| Log automazione | Automazioni → tre puntini → Traccia |
| Log HA | Impostazioni → Sistema → Log |
| Webhook funziona | Usa il comando curl sopra |

### Errore "Service not found"

- Il nome del dispositivo e' **case-sensitive**
- Verifica il nome esatto in Dispositivi e servizi → Mobile App
- Prova a riavviare HA dopo aver installato l'app Companion

### Webhook non raggiungibile

```bash
# Verificare che HA risponda
curl http://192.168.3.10:8123/api/

# Se errore, verificare che HA sia attivo
docker ps | grep homeassistant
docker logs homeassistant --tail 20
```

### Notifiche in ritardo

- Le notifiche push dipendono da Apple Push Notification service (APNs)
- In rari casi possono esserci ritardi di alcuni secondi
- Per test immediati, usa il pulsante **Test** in Uptime Kuma

---

## Riferimenti

- [Home Assistant Companion App](https://companion.home-assistant.io/)
- [HA Automation Triggers - Webhook](https://www.home-assistant.io/docs/automation/trigger/#webhook-trigger)
- [Uptime Kuma Notifications](https://github.com/louislam/uptime-kuma/wiki/Notification-Methods)
- [iOS Critical Alerts](https://companion.home-assistant.io/docs/notifications/critical-notifications/)
