# Notifications Setup

> Guides for configuring notifications across homelab services

---

## Table of Contents

1. [Uptime Kuma via Home Assistant](#overview)
2. [Watchtower via Discord](#watchtower--discord-notifications)

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

> [!IMPORTANT]
> Note this exact name, you'll need it to configure the automation.

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

> [!NOTE]
> Replace `<your_iphone_name>` with the actual device name found in Step 1.

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

> [!NOTE]
> We use IP `192.168.3.10` (not `localhost`) because Uptime Kuma runs in Docker network while Home Assistant is in `network_mode: host`. The host IP is required for communication.

### Associate Notification with Monitors

For each monitor you want to track:

1. Go to existing monitor or create a new one
2. In **Notifications** section, enable `Home Assistant iOS`
3. Save

---

## Step 4: Create Monitors

Below are the recommended monitor types for each service in the homelab. Use container hostnames (e.g., `http://sonarr:8989`) when possible — Uptime Kuma is on the same Docker network, so this is more reliable than host IPs.

> [!TIP]
> For the full operational guide on managing monitors (adding new services, status pages, maintenance windows, troubleshooting), see [Uptime Kuma Monitors Runbook](../operations/uptime-kuma-monitors.md).

### Infrastructure (compose.yml)

| Service | Monitor Type | URL / Target | Notes |
|---------|-------------|--------------|-------|
| Traefik | HTTP(s) | `http://traefik:80/ping` | Ping is on the `web` entrypoint (port 80), not 8080; `https://traefik.home.local` is blocked by Authelia |
| Authelia | HTTP(s) | `http://authelia:9091/api/health` | Dedicated health endpoint |
| Pi-hole | DNS | Query `pi.hole` @ `192.168.3.10` | Tests DNS resolution, not just the web UI |
| Portainer | HTTP(s) | `https://192.168.3.10:9443/` | Primary health monitor (no Docker healthcheck — scratch image has no wget/curl); enable "Ignore TLS/SSL errors"; accept status codes 200-399 since root may return a 303 redirect |
| Duplicati | HTTP(s) | `http://duplicati:8200` | Simple web UI check |
| Tailscale | Docker Container | Container: `tailscale` | Uses `network_mode: host`, not reachable via Docker network; built-in healthcheck runs `tailscale status --json` |
| Socket Proxy | Docker Container | Container: `socket-proxy` | Internal only, no exposed HTTP endpoint |
| Watchtower | Docker Container | Container: `watchtower` | Metrics endpoint requires auth token; Docker monitor is simpler |
| Cert Page | HTTP(s) | `http://cert-page:80/` | CA certificate download page; no auth required |
| Home Assistant | HTTP(s) | `http://192.168.3.10:8123/manifest.json` | Must use host IP — HA runs in `network_mode: host`; do not use `/api/` (requires auth, causes login errors in HA log) |

> [!NOTE]
> Do not create a monitor for Uptime Kuma itself — it cannot reliably monitor its own availability.

### Media Stack (compose.media.yml)

| Service | Monitor Type | URL / Target | Notes |
|---------|-------------|--------------|-------|
| Sonarr | HTTP(s) | `http://sonarr:8989/ping` | `/ping` returns 200 without auth |
| Radarr | HTTP(s) | `http://radarr:7878/ping` | Same as above |
| Lidarr | HTTP(s) | `http://lidarr:8686/ping` | Same as above |
| Prowlarr | HTTP(s) | `http://prowlarr:9696/ping` | Same as above |
| Bazarr | HTTP(s) | `http://bazarr:6767/ping` | Same as above |
| qBittorrent | HTTP(s) | `http://gluetun:8080` | Route through Gluetun (VPN profile); use `http://qbittorrent:8080` for novpn |
| NZBGet | HTTP(s) | `http://gluetun:6789` | Same — goes through Gluetun's network |
| Gluetun | Docker Container | Container: `gluetun` | Built-in health check validates the VPN tunnel |
| FlareSolverr | HTTP(s) | `http://flaresolverr:8191/health` | Dedicated `/health` endpoint |
| Recyclarr | Docker Container | Container: `recyclarr` | Runs on a schedule, no web UI |
| Cleanuparr | HTTP(s) | `http://cleanuparr:11011/health` | Dedicated `/health` endpoint |
| Plex Music | HTTP(s) | `http://plex-music:32400/identity` | Music server (always-on Docker container on NAS) |

### Proxmox Host (192.168.3.20)

| Service | Monitor Type | URL / Target | Notes |
|---------|-------------|--------------|-------|
| Proxmox | HTTP(s) | `https://192.168.3.20:8006` | Enable "Ignore TLS/SSL errors" (self-signed cert) |
| Plex (Movies/TV) | HTTP(s) | `http://192.168.3.21:32400/web` | Movies/TV server in LXC on Proxmox (on-demand) |

### General Settings

- **Check interval**: 60s for most services; 30s for critical ones (Traefik, Pi-hole, Gluetun)
- **Retries**: 3 retries before alerting (avoids false positives during container restarts)
- **HTTPS monitors with self-signed certs**: enable "Ignore TLS/SSL errors" in monitor settings

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

> [!WARNING]
> Critical notifications bypass ALL silence settings. Use only for truly important alerts (critical services down).

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
curl http://192.168.3.10:8123/manifest.json

# If error, verify HA is running
docker ps | grep homeassistant
docker logs homeassistant --tail 20
```

### Delayed notifications

- Push notifications depend on Apple Push Notification service (APNs)
- In rare cases there may be delays of a few seconds
- For immediate tests, use the **Test** button in Uptime Kuma

---

## Watchtower — Discord Notifications

Watchtower monitors running containers and automatically updates them when new images are available. This section configures Discord notifications so you are informed of every update and failure.

### Prerequisites

- Discord server where you have permission to create webhooks
- Watchtower running (part of `compose.yml` infrastructure stack)

### Step 1: Create Discord Webhook

1. Open Discord and go to the channel where you want notifications
2. Click **Edit Channel** (gear icon) > **Integrations** > **Webhooks**
3. Click **New Webhook**
4. Name it `Watchtower` (or any name you prefer)
5. Copy the **Webhook URL** — it will look like:
   ```
   https://discord.com/api/webhooks/123456789012345678/AbCdEfGhIjKlMnOpQrStUvWxYz...
   ```

### Step 2: Convert to Shoutrrr Format

Watchtower uses the [Shoutrrr](https://containrrr.dev/shoutrrr/v0.8/services/discord/) library. Convert the Discord URL:

```
Discord:  https://discord.com/api/webhooks/<webhook_id>/<token>
Shoutrrr: discord://<token>@<webhook_id>
```

**Example:**

```
Discord:  https://discord.com/api/webhooks/123456789/AbCdEfGhIjKlMnOp
Shoutrrr: discord://AbCdEfGhIjKlMnOp@123456789
```

### Step 3: Configure `.env.secrets`

Add the Shoutrrr URL to `docker/.env.secrets`:

```bash
WATCHTOWER_NOTIFICATION_URL=discord://AbCdEfGhIjKlMnOp@123456789
```

### Step 4: Restart Watchtower

```bash
make restart s=watchtower
```

### Step 5: Verify

Trigger a manual update check:

```bash
docker exec watchtower /watchtower --run-once
```

If containers were updated or errors occurred, you should see a Discord message. If nothing needed updating, no notification is sent (this is the expected behavior).

### How Notification Filtering Works

Watchtower runs in **report mode** (`WATCHTOWER_NOTIFICATION_REPORT=true`), which sends a single summary per update cycle instead of per-container messages. The notification template only renders content when containers were updated or failed — when neither condition is true (i.e., no updates found), the template renders empty and Watchtower skips sending the notification entirely.

**You will only receive Discord messages when:**
- One or more containers were successfully updated
- One or more containers failed to update

To customize the template, edit `WATCHTOWER_NOTIFICATION_TEMPLATE` in `docker/compose.yml`. Report mode templates receive a `.Report` object with `.Updated`, `.Failed`, `.Skipped`, and `.Fresh` container lists (e.g., `{{.Report.Updated}}`). See [Watchtower notifications docs](https://containrrr.dev/watchtower/notifications/) for Go template syntax.

### Troubleshooting

| Issue | Check |
|-------|-------|
| No notifications | Verify URL is set: `docker exec watchtower env \| grep NOTIFICATION` |
| Invalid URL format | Ensure format is `discord://token@webhookid` (not the raw Discord URL) |
| Network error | Watchtower needs outbound HTTPS (port 443) to `discord.com` |
| Template error | Check logs: `docker logs watchtower --tail 50` |

---

## References

- [Home Assistant Companion App](https://companion.home-assistant.io/)
- [HA Automation Triggers - Webhook](https://www.home-assistant.io/docs/automation/trigger/#webhook-trigger)
- [Uptime Kuma Notifications](https://github.com/louislam/uptime-kuma/wiki/Notification-Methods)
- [iOS Critical Alerts](https://companion.home-assistant.io/docs/notifications/critical-notifications/)
- [Watchtower Notifications](https://containrrr.dev/watchtower/notifications/)
- [Shoutrrr Discord Service](https://containrrr.dev/shoutrrr/v0.8/services/discord/)
