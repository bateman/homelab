# Notifications Setup - Uptime Kuma via Home Assistant

> Guide to configure iOS push notifications from Uptime Kuma alerts via Home Assistant

---

## Overview

This guide explains how to receive push notifications on iPhone when Uptime Kuma detects a service down, using Home Assistant as a bridge.

### Architecture

```
┌──────────────┐     webhook      ┌──────────────────┐     push      ┌─────────┐
│ Uptime Kuma  │ ───────────────► │  Home Assistant  │ ────────────► │  iPhone │
│  (monitor)   │   HTTP POST      │   (automation)   │   APNs        │  (app)  │
└──────────────┘                  └──────────────────┘               └─────────┘
   :3001                              :8123                         HA Companion
```

### Why This Solution

- **Free**: no cost, no subscription
- **Already in stack**: Home Assistant is already configured
- **Native iOS notifications**: instant push, critical notification support
- **No external dependencies**: works without internet (on LAN)

---

## Prerequisites

- [ ] Uptime Kuma active (`https://uptime.home.local` or `http://192.168.3.10:3001`)
- [ ] Home Assistant active (`https://ha.home.local` or `http://192.168.3.10:8123`)
- [ ] iPhone with iOS 14+

---

## Step 1: Install iOS App

1. Download **Home Assistant** from the App Store (free)
2. Open the app and connect to server:
   - Internal URL: `http://192.168.3.10:8123`
   - Or via Tailscale: `https://ha.home.local`
3. Log in with your HA credentials
4. When prompted, **allow notifications**
5. Complete initial app setup

### Find Device Name

After setup, HA automatically creates a notification service for your device.

1. Go to HA → **Settings** → **Devices & services**
2. Search for **Mobile App** or your iPhone name
3. Click on the device
4. Note the service name, it will be something like:
   - `notify.mobile_app_marios_iphone`
   - `notify.mobile_app_iphone`

> **Important**: Note this exact name, you'll need it to configure the automation.

---

## Step 2: Configure Automation in Home Assistant

You have two options: via UI (recommended) or via YAML.

### Option A: Via UI (Recommended)

1. Go to HA → **Settings** → **Automations & scenes**
2. Click **+ Create automation** → **Create new automation**
3. Configure the **Trigger**:
   - Trigger type: **Webhook**
   - Webhook ID: `uptime-kuma-alert`
   - Allowed methods: `POST`
   - Local only: `Yes`
4. Configure the **Action**:
   - Action type: **Call service**
   - Service: `notify.mobile_app_<your_iphone_name>`
   - Click three dots → **Edit in YAML**
   - Enter:
     ```yaml
     service: notify.mobile_app_<your_iphone_name>
     data:
       title: "{{ trigger.json.monitor.name | default('Uptime Kuma') }}"
       message: "{{ trigger.json.heartbeat.msg | default('Status changed') }}"
       data:
         push:
           sound: default
         url: "https://uptime.home.local"
     ```
5. Name it: `Uptime Kuma Alerts`
6. **Save**

### Option B: Via YAML

Add this automation to Home Assistant's `automations.yaml`:

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
    - service: notify.mobile_app_<your_iphone_name>
      data:
        title: "{{ trigger.json.monitor.name | default('Uptime Kuma') }}"
        message: "{{ trigger.json.heartbeat.msg | default('Status changed') }}"
        data:
          push:
            sound: default
            # Uncomment for critical notifications (bypass silent mode)
            # critical: 1
            # volume: 1.0
          url: "https://uptime.home.local"
  mode: parallel
  max: 10
```

After modifying the file, restart Home Assistant:
- Settings → System → Restart

> **Note**: Replace `<your_iphone_name>` with the actual device name found in Step 1.

---

## Step 3: Configure Uptime Kuma

1. Open Uptime Kuma: `https://uptime.home.local` (or `http://192.168.3.10:3001`)
2. Go to **Settings** (gear icon) → **Notifications**
3. Click **Setup Notification**
4. Configure:
   - **Notification Type**: `Webhook`
   - **Friendly Name**: `Home Assistant iOS`
   - **Post URL**: `http://192.168.3.10:8123/api/webhook/uptime-kuma-alert`
   - **Request Body**: `application/json`
5. Click **Test** to verify
6. If test works, click **Save**

> **Note**: We use IP `192.168.3.10` (not `localhost`) because Uptime Kuma runs in Docker network while Home Assistant is in `network_mode: host`. The host IP is required for communication.

### Associate Notification with Monitors

For each monitor you want to track:

1. Go to existing monitor or create a new one
2. In **Notifications** section, enable `Home Assistant iOS`
3. Save

---

## Manual Test

You can test the webhook directly with curl:

```bash
curl -X POST http://192.168.3.10:8123/api/webhook/uptime-kuma-alert \
  -H "Content-Type: application/json" \
  -d '{
    "monitor": {"name": "Test Service"},
    "heartbeat": {"msg": "Service is DOWN - test notification"}
  }'
```

You should receive a push notification on iPhone within seconds.

---

## Critical Notifications (Optional)

To receive notifications even when iPhone is in silent mode or Do Not Disturb:

1. Edit the automation in HA
2. Add these parameters to the action:
   ```yaml
   data:
     push:
       sound: default
       critical: 1
       volume: 1.0
   ```
3. The iOS app will request permission for critical notifications

> **Warning**: Critical notifications bypass ALL silence settings. Use only for truly important alerts (critical services down).

---

## Troubleshooting

### Notification not arriving

| Check | How |
|-------|-----|
| Notify service exists | HA → Developer Tools → Services → search `notify.mobile_app_*` |
| Automation active | HA → Settings → Automations → check status |
| Automation log | Automations → three dots → Traces |
| HA Log | Settings → System → Logs |
| Webhook works | Use curl command above |

### Error "Service not found"

- Device name is **case-sensitive**
- Verify exact name in Devices & services → Mobile App
- Try restarting HA after installing Companion app

### Webhook not reachable

```bash
# Verify HA responds
curl http://192.168.3.10:8123/api/

# If error, verify HA is running
docker ps | grep homeassistant
docker logs homeassistant --tail 20
```

### Delayed notifications

- Push notifications depend on Apple Push Notification service (APNs)
- In rare cases there may be delays of a few seconds
- For immediate tests, use the **Test** button in Uptime Kuma

---

## References

- [Home Assistant Companion App](https://companion.home-assistant.io/)
- [HA Automation Triggers - Webhook](https://www.home-assistant.io/docs/automation/trigger/#webhook-trigger)
- [Uptime Kuma Notifications](https://github.com/louislam/uptime-kuma/wiki/Notification-Methods)
- [iOS Critical Alerts](https://companion.home-assistant.io/docs/notifications/critical-notifications/)
