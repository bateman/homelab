# Setup Notifiche - Uptime Kuma via Home Assistant

Questa guida spiega come configurare le notifiche push su iOS per gli alert di Uptime Kuma, utilizzando Home Assistant come ponte.

## Architettura

```
┌──────────────┐     webhook      ┌──────────────────┐     push      ┌─────────┐
│ Uptime Kuma  │ ───────────────► │  Home Assistant  │ ────────────► │  iPhone │
│  (monitor)   │   HTTP POST      │   (automazione)  │   APNs        │  (app)  │
└──────────────┘                  └──────────────────┘               └─────────┘
   :3001                              :8123                         HA Companion
```

## Prerequisiti

- Uptime Kuma attivo (`http://192.168.3.10:3001`)
- Home Assistant attivo (`http://192.168.3.10:8123`)
- iPhone con iOS 14+

## Passo 1: Installare l'App iOS

1. Scarica **Home Assistant** dall'App Store (gratuita)
2. Apri l'app e connettiti al server:
   - URL: `http://192.168.3.10:8123`
   - Effettua il login con le tue credenziali HA
3. Quando richiesto, **consenti le notifiche**
4. Completa la configurazione iniziale dell'app

### Trovare il Nome del Dispositivo

Dopo la configurazione, HA crea automaticamente un servizio di notifica per il tuo dispositivo.

1. Vai in HA → **Impostazioni** → **Dispositivi e servizi**
2. Cerca **Mobile App** o il nome del tuo iPhone
3. Clicca sul dispositivo
4. Nota il nome del servizio, sarà qualcosa come:
   - `notify.mobile_app_iphone_di_mario`
   - `notify.mobile_app_iphone`

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
   - Dati servizio (YAML mode):
     ```yaml
     title: "{{ trigger.json.monitor.name | default('Uptime Kuma') }}"
     message: "{{ trigger.json.heartbeat.msg | default('Status changed') }}"
     data:
       push:
         sound: default
       url: "http://192.168.3.10:3001"
     ```
5. Dai un nome: "Uptime Kuma Alerts"
6. **Salva**

### Opzione B: Via YAML

1. Copia il file di esempio nel container HA:
   ```bash
   # Dal NAS
   cp /share/container/homeassistant/config/automations/uptime-kuma.yaml.example \
      /share/container/homeassistant/config/automations/uptime-kuma.yaml
   ```

2. Modifica il file e sostituisci `<your_iphone_name>` con il nome reale del tuo dispositivo

3. Assicurati che `configuration.yaml` includa le automazioni:
   ```yaml
   # Se usi file separati per le automazioni
   automation: !include_dir_merge_list automations/

   # Oppure se usi un singolo file
   automation: !include automations.yaml
   ```

4. Riavvia Home Assistant:
   - Impostazioni → Sistema → Riavvia

Il file di esempio si trova in:
```
docker/config/homeassistant/automations/uptime-kuma.yaml.example
```

## Passo 3: Configurare Uptime Kuma

1. Apri Uptime Kuma: `http://192.168.3.10:3001`
2. Vai in **Settings** (icona ingranaggio) → **Notifications**
3. Clicca **Setup Notification**
4. Configura:
   - **Notification Type**: `Home Assistant`
   - **Friendly Name**: `Home Assistant iOS`
   - **Home Assistant URL**: `http://localhost:8123`
     > Nota: usa `localhost` perché HA gira in `network_mode: host` sullo stesso NAS
   - **Webhook URL path**: `/api/webhook/uptime-kuma-alert`
5. Clicca **Test** per verificare
6. Se il test funziona, clicca **Save**

### Associare la Notifica ai Monitor

1. Vai su un monitor esistente o creane uno nuovo
2. Nella sezione **Notifications**, abilita "Home Assistant iOS"
3. Salva

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

Dovresti ricevere una notifica push sull'iPhone.

## Notifiche Critiche (Opzionale)

Per ricevere notifiche anche quando l'iPhone è in modalità silenzioso o Non Disturbare:

1. Modifica l'automazione in HA
2. Aggiungi questi parametri all'azione:
   ```yaml
   data:
     push:
       sound: default
       critical: 1
       volume: 1.0
   ```
3. L'app iOS chiederà il permesso per le notifiche critiche

> **Attenzione**: Le notifiche critiche bypassano TUTTE le impostazioni di silenzio. Usale solo per alert veramente importanti.

## Troubleshooting

### La notifica non arriva

1. **Verifica il servizio notify**: In HA → Strumenti per sviluppatori → Servizi, cerca `notify.mobile_app_*`
2. **Controlla i log HA**: Impostazioni → Sistema → Log
3. **Verifica l'automazione**: Impostazioni → Automazioni → clicca sui tre puntini → Traccia
4. **Testa il webhook**: Usa il comando curl sopra

### Errore "Service not found"

- Il nome del dispositivo è case-sensitive
- Verifica il nome esatto in Dispositivi e servizi → Mobile App
- Potrebbe essere necessario reinstallare l'app Companion

### Webhook non raggiungibile

- Verifica che HA sia raggiungibile: `curl http://192.168.3.10:8123/api/`
- Controlla che `local_only: true` sia configurato (se usi webhook da rete locale)

### Notifiche in ritardo

- Le notifiche push dipendono da Apple Push Notification service (APNs)
- In rari casi possono esserci ritardi di alcuni secondi
- Per test immediati, usa il pulsante "Test" in Uptime Kuma

## Riferimenti

- [Home Assistant Companion App](https://companion.home-assistant.io/)
- [HA Automation Triggers - Webhook](https://www.home-assistant.io/docs/automation/trigger/#webhook-trigger)
- [Uptime Kuma Notifications](https://github.com/louislam/uptime-kuma/wiki/Notification-Methods)
- File esempio: `docker/config/homeassistant/automations/uptime-kuma.yaml.example`
