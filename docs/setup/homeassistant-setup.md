# Home Assistant Setup

> Complete Home Assistant configuration guide: initial setup, reverse proxy, core integrations, Fire TV, Alexa, and power automations

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Initial Setup (First Boot)](#2-initial-setup-first-boot)
3. [Reverse Proxy (Traefik)](#3-reverse-proxy-traefik)
4. [Core Configuration](#4-core-configuration)
5. [Built-in Integrations](#5-built-in-integrations)
6. [Fire TV → Proxmox Power Management](#6-fire-tv--proxmox-power-management)
7. [Alexa (via HACS)](#7-alexa-via-hacs)
8. [Expose HA Entities to Alexa (Optional)](#8-expose-ha-entities-to-alexa-optional)
9. [Automations](#9-automations)
10. [Firewall Considerations](#10-firewall-considerations)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Architecture Overview

Home Assistant runs on the QNAP NAS as a Docker container with `network_mode: host` for device discovery (mDNS, Zigbee, Bluetooth).

```
┌──────────────────────────────────────────────────────────────────────┐
│  QNAP NAS (192.168.3.10)                                            │
│                                                                      │
│  ┌──────────────────┐   host network   ┌──────────────────────────┐ │
│  │  Home Assistant   │ ◄──────────────► │  Port 8123 (host)        │ │
│  │  (container)      │                  │  Accessible from LAN     │ │
│  └────────┬─────────┘                  └──────────────────────────┘ │
│           │                                                          │
│  ┌────────▼─────────┐                  ┌──────────────────────────┐ │
│  │  /config volume   │                  │  Traefik (Docker bridge) │ │
│  │  ./config/        │                  │  ha.home.local → :8123   │ │
│  │  homeassistant/   │                  └──────────────────────────┘ │
│  └──────────────────┘                                                │
└──────────────────────────────────────────────────────────────────────┘
         │                    │                         │
    Wake-on-LAN          Fire TV               Alexa / Echo
    ┌─────────┐        ┌─────────┐            ┌─────────┐
    │ Mini PC │        │ Fire TV │            │  Echo   │
    │ Proxmox │        │  Stick  │            │ Speaker │
    │ :8006   │        │         │            │         │
    └─────────┘        └─────────┘            └─────────┘
   192.168.3.20        DHCP/static            DHCP/static
```

**Key architectural decisions:**

| Decision | Reason |
|----------|--------|
| `network_mode: host` | Required for mDNS device discovery, Zigbee, Bluetooth |
| `/run/dbus:/run/dbus:ro` volume | Exposes host D-Bus to HA — needed for Bluetooth device access |
| No Authelia middleware | HA has its own auth; SSO breaks HA Companion app login |
| Traefik via file provider | Docker labels don't work with `network_mode: host` |
| Config volume tracked in git | Infrastructure-as-code; secrets excluded via `.gitignore` |

---

## 2. Initial Setup (First Boot)

### 2.1 Prerequisites

- Docker stack running on NAS (`make up`)
- Folder created by `scripts/setup-folders.sh` → `docker/config/homeassistant/`
- DNS record for `ha.home.local → 192.168.3.10` in Pi-hole (see [pihole-setup.md](pihole-setup.md))

### 2.2 Start the Container

```bash
# From the NAS (ssh admin@192.168.3.10)
cd /share/container/mediastack
make up
```

Home Assistant is defined in `docker/compose.yml` and starts automatically with the rest of the infrastructure stack.

### 2.3 Onboarding Wizard

1. Open `http://192.168.3.10:8123`
2. Wait for initial setup (may take a few minutes on first boot)
3. Create the **owner account** (admin user)
4. Set **Home name** (e.g., `Home` — matches `configuration.yaml`)
5. Set **Location** (used for sun-based automations, weather)
6. Set **Unit system** (e.g., Metric — matches `configuration.yaml`)
7. Set **Time zone** (e.g., Europe/Rome — matches `TZ` in `.env`)
8. Review auto-detected integrations → skip for now (we'll add them manually)
9. Click **Finish**

> [!IMPORTANT]
> The owner account is the only account that can manage other users and access the full admin panel. Use a strong password — this is the sole authentication layer (no Authelia in front of HA).

### 2.4 Install the HA Companion App (Optional)

For mobile notifications (used by [notifications-setup.md](notifications-setup.md)):

1. Install **Home Assistant** from App Store / Google Play
2. Open the app → enter `http://192.168.3.10:8123` (or `https://ha.home.local`)
3. Log in with the owner account
4. Grant notification permissions

The app registers as `notify.mobile_app_<device_name>` — used for push notifications.

> [!IMPORTANT]
> The `mobile_app:` component must be present in `configuration.yaml` (see [Section 4](#4-core-configuration)). Without it, the Companion App cannot register and HA returns `APIError code 6` ("mobile_app component not loaded").

---

## 3. Reverse Proxy (Traefik)

Home Assistant uses `network_mode: host`, so it **cannot use Docker labels** for Traefik. A file-based configuration is used instead.

**File:** `docker/config/traefik/homeassistant.yml`

```yaml
http:
  routers:
    homeassistant:
      rule: "Host(`ha.home.local`)"
      service: homeassistant
      entryPoints:
        - websecure
      tls: {}

  services:
    homeassistant:
      loadBalancer:
        servers:
          - url: "http://192.168.3.10:8123"
```

**Access:** `https://ha.home.local`

> [!NOTE]
> No Authelia middleware is configured. This is intentional — HA uses its own authentication, and adding Authelia breaks the Companion app and API integrations. This is documented as a known trade-off in the [firewall audit](../operations/firewall-audit.md).

For the reverse proxy to work, `configuration.yaml` trusts Docker bridge IPs:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.16.0.0/12   # Docker bridge networks
```

Without this, HA returns 400 Bad Request when accessed through Traefik. See [reverse-proxy-setup.md](reverse-proxy-setup.md) for the full Traefik configuration.

---

## 4. Core Configuration

**File:** `docker/config/homeassistant/configuration.yaml` (tracked in git)

```yaml
homeassistant:
  name: Home
  unit_system: metric

http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.16.0.0/12

mobile_app:

wake_on_lan:

automation: !include plex-minipc-power.yaml
```

> [!NOTE]
> The `wake_on_lan:` and `automation: !include plex-minipc-power.yaml` lines support the power management workflow. See [Section 6](#6-fire-tv--proxmox-power-management) for the full setup walkthrough including SSH key configuration.

### What's tracked in git vs what's not

| File | Tracked | Notes |
|------|---------|-------|
| `configuration.yaml` | Yes | Core config, managed as IaC |
| `plex-minipc-power.yaml` | Yes | Power automations, managed as IaC |
| `automations.yaml` | No | UI-created automations (gitignored, backed up by Duplicati) |
| `secrets.yaml` | No | Credentials (gitignored, backed up by Duplicati) |
| `scenes.yaml`, `scripts.yaml` | No | UI-created (gitignored) |
| `.storage/`, `blueprints/` | No | Runtime data (gitignored) |

> [!TIP]
> For YAML-based automations that you want version-controlled, add them as separate `.yaml` files and include them via `!include`. The gitignore is configured to track custom YAML files while excluding HA-generated ones.

### Restarting After Config Changes

After editing `configuration.yaml`:

- **From HA UI:** Settings → System → Restart
- **From CLI:**
  ```bash
  # From the NAS
  cd /share/container/mediastack
  docker compose -f docker/compose.yml restart homeassistant
  ```

---

## 5. Built-in Integrations

These integrations are configured via the HA UI (**Settings → Devices & Services → Add Integration**) and stored in `.storage/` (gitignored, backed up by Duplicati).

### 5.1 HA Companion App (Mobile)

Auto-discovered when you install the HA Companion app (see [Section 2.4](#24-install-the-ha-companion-app-optional)). Creates `notify.mobile_app_<device_name>` for push notifications.

### 5.2 Webhook (for Uptime Kuma)

Used to receive alerts from Uptime Kuma and forward them as iOS push notifications. No UI setup required — configured via automations.

See [notifications-setup.md](notifications-setup.md) for the full webhook integration.

---

## 6. Fire TV → Proxmox Power Management

This section walks through the complete power management setup end-to-end. When done, turning on the Fire TV automatically wakes the Mini PC (Plex), and turning it off for 5 minutes triggers a graceful shutdown.

**File:** `docker/config/homeassistant/plex-minipc-power.yaml` (tracked in git)

| Automation | Trigger | Action |
|------------|---------|--------|
| Wake Mini PC | Fire TV turns on (off/standby/unavailable → on/idle/playing/paused) | `wake_on_lan.send_magic_packet` to Mini PC |
| Shutdown Mini PC | Fire TV off for 5 minutes | `shell_command.shutdown_minipc` via SSH |

> [!NOTE]
> Choose **one** approach for Mini PC power management — cron ([energy-saving-strategies.md §1.1](../operations/energy-saving-strategies.md#11-scheduled-shutdown--wake-up-cron)), HA time-based, or HA Fire TV-based. See [energy-saving-strategies.md §6](../operations/energy-saving-strategies.md#6-home-assistant-power-automations) for all options.

### 6.1 Enable Wake-on-LAN

Already declared in `configuration.yaml` with `wake_on_lan:` (see [Section 4](#4-core-configuration)). No additional setup needed — this enables the `wake_on_lan.send_magic_packet` service call used by the wake automation.

### 6.2 Enable ADB on Fire TV

1. **Fire TV Settings** → **My Fire TV** → **About**
2. Click **Fire TV Stick** (or device name) **7 times** to enable Developer Options
3. Go back to **My Fire TV** → **Developer Options**
4. Enable **ADB Debugging** → confirm "Allow"

> [!WARNING]
> ADB debugging allows remote control of the device. Only enable on trusted networks. The Fire TV will prompt to authorize each new ADB connection.

### 6.3 Reserve Fire TV IP (DHCP Reservation)

To ensure the Fire TV always gets the same IP (required for reliable automations):

1. Open UniFi Network: `https://192.168.2.1`
2. **Clients** → find Fire TV → click on it
3. **Settings** (gear icon) → **Fixed IP Address** → assign a static IP
4. Note the IP for the next step

> [!TIP]
> If Fire TV is on the Media VLAN (192.168.4.x), you'll need a firewall rule allowing HA (192.168.3.10) to reach it on port 5555 (ADB). See [Section 10](#10-firewall-considerations) and [firewall-config.md Rule 14b](../network/firewall-config.md).

### 6.4 Add Android Debug Bridge Integration

1. Open Home Assistant: `http://192.168.3.10:8123`
2. **Settings** → **Devices & Services** → **Add Integration**
3. Search for **"Android Debug Bridge"**
4. Enter the Fire TV IP address
5. On the Fire TV screen, a pairing prompt will appear — **confirm the code**
6. The device appears as `media_player.fire_tv` (or similar — note the exact entity ID)

> [!NOTE]
> Home Assistant offers two Android TV integrations:
> - **Android Debug Bridge** (recommended for Fire TV) — uses ADB on port 5555, reliable state detection
> - **Android TV Remote** — uses port 6466, not supported on Fire TV Stick (port closed)
>
> Use **Android Debug Bridge** for Fire TV Stick devices. The Android TV Remote integration requires port 6466, which Fire TV Stick does not expose.

### 6.5 Verify the Fire TV Entity

1. **Developer Tools** → **States**
2. Search for `media_player.fire_tv`
3. Verify state changes:
   - Turn on Fire TV → state should change to `idle`, `playing`, or `on`
   - Turn off Fire TV → state should change to `standby` or `off`

### 6.6 Create Ping Sensor

The Ping sensor monitors whether the Mini PC (Proxmox) is online. The shutdown automation uses it to confirm the machine is up before sending the SSH command.

1. **Settings** → **Helpers** → **Add Helper** → **Ping**
2. Hostname: `192.168.3.20`
3. Name: `Proxmox`

Creates `binary_sensor.proxmox` — used by automations to check if the Mini PC is up.

### 6.7 Set Up SSH Key for Shutdown

The shutdown automation runs `shell_command.shutdown_minipc` (defined in `configuration.yaml`), which SSHes into the Mini PC. You need passwordless SSH from the HA container to Proxmox:

```bash
# From inside the HA container (docker exec -it homeassistant bash):
mkdir -p /config/.ssh
ssh-keygen -t ed25519 -f /config/.ssh/id_ed25519 -N ""
cat /config/.ssh/id_ed25519.pub

# On Proxmox (ssh root@192.168.3.20), add the public key:
nano ~/.ssh/authorized_keys   # paste the key
```

### 6.8 Fill in Placeholders

Replace the placeholder values in `plex-minipc-power.yaml` before enabling the automations:

```yaml
# In plex-minipc-power.yaml:
mac: "XX:XX:XX:XX:XX:XX"         # → Mini PC integrated NIC MAC address
entity_id: media_player.fire_tv  # → your actual Fire TV entity ID (from step 6.5)
```

### 6.9 Restart and Verify

1. Restart Home Assistant to pick up any config changes:
   - **From HA UI:** Settings → System → Restart
   - **From CLI:**
     ```bash
     cd /share/container/mediastack
     docker compose -f docker/compose.yml restart homeassistant
     ```

2. Verify the automations are loaded:
   - **Settings** → **Automations & Scenes** → confirm both power automations appear
   - Check they are **enabled** (toggle on)

3. Test the wake automation:
   - Turn off the Mini PC (or let it be off)
   - Turn on the Fire TV → Mini PC should wake via WoL within seconds

4. Test the shutdown automation:
   - Turn off the Fire TV
   - Wait 5 minutes → Mini PC should shut down gracefully via SSH

---

## 7. Alexa (via HACS)

The **Alexa Media Player** custom component allows Home Assistant to control Alexa/Echo devices and enables TTS announcements.

### 7.1 Install HACS

HACS (Home Assistant Community Store) is required to install Alexa Media Player.

1. Open a terminal in the Home Assistant container:
   ```bash
   docker exec -it homeassistant bash
   ```

2. Run the HACS install script:
   ```bash
   wget -O - https://get.hacs.xyz | bash -
   ```

3. **Restart Home Assistant**:
   ```bash
   # From the NAS
   cd /share/container/mediastack
   docker compose -f docker/compose.yml restart homeassistant
   ```

4. In Home Assistant: **Settings** → **Devices & Services** → **Add Integration** → search **"HACS"**
5. Follow the GitHub authorization flow (requires a GitHub account)

### 7.2 Install Alexa Media Player

1. In Home Assistant, go to **HACS** → **Integrations**
2. Click **"+ Explore & Download Repositories"**
3. Search for **"Alexa Media Player"**
4. Click **Download** → confirm the version → **Download**
5. **Restart Home Assistant** (required after installing HACS components)

### 7.3 Configure Alexa Media Player

> [!NOTE]
> In this homelab, Alexa/Echo devices are on VLAN 6 — IoT (192.168.6.0/24) per [rack-homelab-config.md](../network/rack-homelab-config.md). Home Assistant can discover them because it runs with `network_mode: host` and firewall Rule 14 allows IoT → HA traffic on port 8123.

1. **Settings** → **Devices & Services** → **Add Integration**
2. Search for **"Alexa Media Player"**
3. Enter your **Amazon account credentials** (the account linked to your Alexa devices)
4. Complete the **2FA/CAPTCHA** if prompted
5. Select your **Amazon region** (e.g., `amazon.it` for Italy)

> [!IMPORTANT]
> Alexa Media Player authenticates via your Amazon account. Amazon may require periodic re-authentication (typically every few weeks). When this happens, you'll see a persistent notification in Home Assistant — re-enter your credentials.

### 7.4 Available Entities

After setup, each Alexa device appears as a `media_player` entity:

| Entity | Description |
|--------|-------------|
| `media_player.echo_*` | Echo speakers — play/pause, volume, TTS |
| `media_player.fire_tv_*` | Fire TV via Alexa (duplicate of Android TV entity) |
| `sensor.last_called_*` | Which device was last used |

### 7.5 Example: TTS Announcement

Send a text-to-speech announcement to an Echo device:

```yaml
# In an automation action:
- service: notify.alexa_media
  data:
    message: "Plex server is ready."
    target:
      - media_player.echo_living_room  # Replace with your entity
    data:
      type: announce
```

> [!NOTE]
> Alexa Media Player supports two speech modes:
> - **`type: announce`** — plays an attention tone before speaking; ideal for Echo speakers (alerts, notifications)
> - **`type: tts`** — speaks immediately without a tone; better for Fire TV or background announcements
>
> Use `announce` for important alerts and `tts` for passive updates.

---

## 8. Expose HA Entities to Alexa (Optional)

To control Home Assistant devices with voice commands like "Alexa, turn on the lights", you need to bridge HA entities to the Alexa Smart Home ecosystem.

### Option A: Nabu Casa (Home Assistant Cloud)

The simplest approach — a paid subscription (~€7.50/month) that directly links HA to Alexa.

1. **Settings** → **Home Assistant Cloud** → sign up
2. **Alexa** tab → enable, link your Amazon account
3. Select which entities to expose

### Option B: Manual Alexa Smart Home Skill (Free)

Requires more setup but no subscription:

1. Create an **AWS Lambda** function
2. Create a custom **Alexa Smart Home Skill**
3. Configure HA with the skill credentials
4. Expose HA externally (via Nabu Casa or a reverse proxy with HTTPS)

> [!TIP]
> If you only need Alexa to trigger HA automations (not control individual devices), you can use **Alexa Routines** with the Alexa Media Player integration — no cloud setup needed. Create a routine in the Alexa app that triggers a webhook or virtual switch in HA.

---

## 9. Automations

### 9.1 Announce When Plex is Ready (Alexa TTS)

After Fire TV triggers Mini PC wake-up, announce on the nearest Echo when Plex is available. Create via HA UI or add to `automations.yaml`:

```yaml
- id: announce_plex_ready
  alias: "Announce when Plex is ready"
  description: >
    After Fire TV triggers Mini PC wake-up, wait for Plex to become available
    and announce it on the nearest Echo device.
  trigger:
    - platform: state
      entity_id: binary_sensor.proxmox  # Ping sensor for Mini PC
      from: "off"
      to: "on"
      for:
        seconds: 60  # Wait for Plex LXC to fully boot
  action:
    - service: notify.alexa_media
      data:
        message: "Plex server is ready to stream."
        target:
          - media_player.echo_living_room  # Replace with your Echo entity
        data:
          type: announce
```

> [!NOTE]
> Requires the Ping helper (`binary_sensor.proxmox`) from [Section 6.6](#66-create-ping-sensor) and Alexa Media Player from [Section 7](#7-alexa-via-hacs).

### 9.2 Uptime Kuma Notifications

HA acts as a webhook bridge between Uptime Kuma and iOS push notifications. See [notifications-setup.md](notifications-setup.md) for the full setup.

---

## 10. Firewall Considerations

Fire TV and Echo/Alexa devices live on different VLANs (see [rack-homelab-config.md](../network/rack-homelab-config.md)):

| Device | VLAN | Subnet |
|--------|------|--------|
| Fire TV | 4 — Media | 192.168.4.0/24 |
| Echo / Alexa | 6 — IoT | 192.168.6.0/24 |

If these devices need to reach Home Assistant on the Server VLAN (192.168.3.x), add firewall rules:

| Rule | Source | Destination | Port | Protocol | Action |
|------|--------|-------------|------|----------|--------|
| HA → Fire TV (ADB) | 192.168.3.10 | Fire TV IP (192.168.4.166) | 5555 | TCP | Allow |
| IoT → HA (mDNS) | IoT VLAN (192.168.6.0/24) | 192.168.3.10 | 5353 | UDP | Allow |
| Echo → HA (API) | Echo device IP (IoT VLAN) | 192.168.3.10 | 8123 | TCP | Allow |

> [!NOTE]
> Rules 7 and 14 already allow Media and IoT VLANs to reach HA on port 8123 (see below). The HA → Fire TV rule (Rule 14b in [firewall-config.md](../network/firewall-config.md)) allows traffic in the **reverse direction** — from Servers VLAN to Media VLAN. Fire TV Stick uses ADB on port **5555** (the Android TV Remote protocol on port 6466 is not supported on Fire TV Stick).

Existing firewall rules that already cover HA access:

| Rule | Description | File Reference |
|------|-------------|----------------|
| Rule 7 | Allow Media VLAN (192.168.4.0/24) → HA (port 8123) | [firewall-config.md](../network/firewall-config.md) |
| Rule 14 | Allow IoT VLAN (192.168.6.0/24) → HA (port 8123) | [firewall-config.md](../network/firewall-config.md) |

---

## 11. Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| HA returns 400 Bad Request via Traefik | Missing `trusted_proxies` | Add `172.16.0.0/12` to `http.trusted_proxies` in `configuration.yaml` |
| HA not reachable on port 8123 | Container not running | `docker ps \| grep homeassistant` → `make up` |
| Fire TV not discovered | ADB debugging off | Enable in Fire TV Developer Options ([Section 6.2](#62-enable-adb-on-fire-tv)) |
| Fire TV entity stays `unavailable` | IP changed | Set DHCP reservation in UniFi ([Section 6.3](#63-reserve-fire-tv-ip-dhcp-reservation)) |
| Fire TV pairing prompt doesn't appear | Firewall blocking | Allow TCP 5555 (ADB) from HA to Fire TV — see Rule 14b |
| Plex wake automation doesn't fire | Wrong entity ID | Check Developer Tools → States for exact `media_player` ID ([Section 6.5](#65-verify-the-fire-tv-entity)) |
| Alexa integration asks to re-authenticate | Amazon session expired | Re-enter credentials in HA notification |
| TTS not working | Wrong entity or type | Use `type: announce` for Echo, `type: tts` for Fire TV |
| HACS not showing in integrations | Restart needed | Restart HA after HACS install, clear browser cache |
| `configuration.yaml` changes not applied | Restart needed | Settings → System → Restart (or `docker compose restart homeassistant`) |

---

## References

- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [Android TV Remote Integration](https://www.home-assistant.io/integrations/androidtv_remote/)
- [Android Debug Bridge Integration](https://www.home-assistant.io/integrations/androidtv/)
- [Wake-on-LAN Integration](https://www.home-assistant.io/integrations/wake_on_lan/)
- [Alexa Media Player (HACS)](https://github.com/alandtse/alexa_media_player)
- [HACS Installation](https://hacs.xyz/docs/use/)
- [Home Assistant Cloud (Nabu Casa)](https://www.nabucasa.com/)

### Related Homelab Docs

- [Reverse Proxy Setup (Traefik)](reverse-proxy-setup.md) — HA file-based routing
- [Notifications Setup](notifications-setup.md) — Uptime Kuma → HA → iOS push
- [Energy Saving Strategies §6](../operations/energy-saving-strategies.md#6-home-assistant-power-automations) — Power automations (all options)
- [Firewall Config](../network/firewall-config.md) — VLAN access rules for HA
- [Proxmox Setup](proxmox-setup.md) — WoL and SSH-based shutdown for Mini PC control
