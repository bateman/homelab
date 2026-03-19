# Alexa & Fire TV Integration — Home Assistant Setup

> Configure Amazon Fire TV and Alexa devices in Home Assistant for media control and home automation

---

## Overview

This guide covers two integrations:

| Integration | Purpose | Method |
|-------------|---------|--------|
| **Android TV / Fire TV** | Monitor Fire TV state, control playback | Built-in HA integration (ADB) |
| **Alexa Media Player** | Control Echo devices, TTS, routines | HACS custom component |

**Why both?** Fire TV integration detects when someone starts watching (triggers Mini PC wake via [plex-minipc-power.yaml](../../docker/config/homeassistant/plex-minipc-power.yaml)). Alexa integration enables voice control of HA entities and TTS announcements.

---

## 1. Fire TV (Android TV Integration)

The Android TV integration uses ADB (Android Debug Bridge) to monitor and control Fire TV devices.

### 1.1 Prerequisites

- Fire TV on the same network as Home Assistant (VLAN 1 — Default/LAN, or reachable via firewall rule)
- Fire TV IP address (find it in: Fire TV Settings → My Fire TV → About → Network)
- ADB debugging enabled on Fire TV

### 1.2 Enable ADB on Fire TV

1. **Fire TV Settings** → **My Fire TV** → **About**
2. Click **Fire TV Stick** (or device name) **7 times** to enable Developer Options
3. Go back to **My Fire TV** → **Developer Options**
4. Enable **ADB Debugging** → confirm "Allow"

> [!WARNING]
> ADB debugging allows remote control of the device. Only enable on trusted networks. The Fire TV will prompt to authorize each new ADB connection.

### 1.3 Reserve Fire TV IP (DHCP Reservation)

To ensure the Fire TV always gets the same IP (required for reliable automations):

1. Open UniFi Network: `https://192.168.2.1`
2. **Clients** → find Fire TV → click on it
3. **Settings** (gear icon) → **Fixed IP Address** → assign a static IP
4. Note the IP for the next step

> [!TIP]
> If Fire TV is on the IoT VLAN (192.168.4.x), you'll need a firewall rule to allow Home Assistant (192.168.3.10) to reach it on port 5555 (ADB). See [firewall-config.md](../network/firewall-config.md).

### 1.4 Add Integration in Home Assistant

1. Open Home Assistant: `http://192.168.3.10:8123`
2. **Settings** → **Devices & Services** → **Add Integration**
3. Search for **"Android TV Remote"**
4. Enter the Fire TV IP address
5. On the Fire TV screen, a pairing prompt will appear — **confirm the code**
6. The device appears as `media_player.fire_tv` (or similar — note the exact entity ID)

> [!NOTE]
> Home Assistant offers two Android TV integrations:
> - **Android TV Remote** (recommended) — uses the Android TV Remote protocol, more reliable
> - **Android Debug Bridge** — legacy, uses ADB directly
>
> Try **Android TV Remote** first. If it doesn't detect your Fire TV state changes correctly, use the ADB-based integration instead.

### 1.5 Verify the Entity

1. **Developer Tools** → **States**
2. Search for `media_player.fire_tv`
3. Verify state changes:
   - Turn on Fire TV → state should change to `idle`, `playing`, or `on`
   - Turn off Fire TV → state should change to `standby` or `off`

### 1.6 Update Automation Entity ID

The existing `plex-minipc-power.yaml` automation references `media_player.fire_tv`. If your entity has a different ID:

```bash
# Check the actual entity ID in HA Developer Tools → States
# Then update the automation file:
vi docker/config/homeassistant/plex-minipc-power.yaml

# Replace media_player.fire_tv with your actual entity ID
```

See [energy-saving-strategies.md §6](../operations/energy-saving-strategies.md#6-home-assistant-power-automations) for the full automation context.

---

## 2. Alexa Integration (via HACS)

The **Alexa Media Player** custom component allows Home Assistant to control Alexa/Echo devices and expose HA entities to Alexa voice control.

### 2.1 Install HACS (if not already installed)

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

### 2.2 Install Alexa Media Player

1. In Home Assistant, go to **HACS** → **Integrations**
2. Click **"+ Explore & Download Repositories"**
3. Search for **"Alexa Media Player"**
4. Click **Download** → confirm the version → **Download**
5. **Restart Home Assistant** (required after installing HACS components)

### 2.3 Configure Alexa Media Player

1. **Settings** → **Devices & Services** → **Add Integration**
2. Search for **"Alexa Media Player"**
3. Enter your **Amazon account credentials** (the account linked to your Alexa devices)
4. Complete the **2FA/CAPTCHA** if prompted
5. Select your **Amazon region** (e.g., `amazon.it` for Italy)

> [!IMPORTANT]
> Alexa Media Player authenticates via your Amazon account. Amazon may require periodic re-authentication (typically every few weeks). When this happens, you'll see a persistent notification in Home Assistant — just re-enter your credentials.

> [!NOTE]
> This integration does **not** expose Home Assistant entities to Alexa voice control by default. For that, you need either:
> - **Nabu Casa** (Home Assistant Cloud) — paid subscription, easiest method
> - **Manual Alexa Smart Home Skill** — free, requires AWS Lambda setup (advanced)
>
> See [Section 3](#3-expose-ha-entities-to-alexa-optional) for details.

### 2.4 Available Entities

After setup, each Alexa device appears as a `media_player` entity:

| Entity | Description |
|--------|-------------|
| `media_player.echo_*` | Echo speakers — play/pause, volume, TTS |
| `media_player.fire_tv_*` | Fire TV via Alexa (duplicate of Android TV entity) |
| `sensor.last_called_*` | Which device was last used |

### 2.5 Example: TTS Announcement

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

### 2.6 Example: Announce When Plex is Ready

Add this automation to notify via Alexa when the Mini PC wakes up and Plex becomes available. Create or add to `docker/config/homeassistant/automations.yaml`:

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
> The `binary_sensor.proxmox` ping sensor must be created first: **Settings** → **Helpers** → **Add Helper** → **Ping** → enter `192.168.3.20` (Mini PC IP).

---

## 3. Expose HA Entities to Alexa (Optional)

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

## 4. Firewall Considerations

If Fire TV or Echo devices are on the IoT VLAN (192.168.4.x), add firewall rules to allow communication with Home Assistant on the Server VLAN (192.168.3.x).

| Rule | Source | Destination | Port | Protocol | Action |
|------|--------|-------------|------|----------|--------|
| HA → Fire TV (ADB) | 192.168.3.10 | Fire TV IP | 5555 | TCP | Allow |
| IoT → HA (mDNS) | IoT VLAN (192.168.4.0/24) | 192.168.3.10 | 5353 | UDP | Allow |
| Echo → HA (API) | Echo device IP | 192.168.3.10 | 8123 | TCP | Allow |

> [!NOTE]
> If all devices are on the same VLAN (Default/LAN — 192.168.1.0/24), no additional firewall rules are needed. Rules are only required for cross-VLAN communication.

See [firewall-config.md](../network/firewall-config.md) for the full rule set and how to add new rules.

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Fire TV not discovered | ADB debugging off | Enable in Fire TV Developer Options |
| Fire TV entity stays `unavailable` | IP changed | Set DHCP reservation in UniFi |
| Fire TV pairing prompt doesn't appear | Firewall blocking | Allow TCP 5555 from HA to Fire TV |
| Alexa integration asks to re-authenticate | Amazon session expired | Re-enter credentials in HA notification |
| TTS not working | Wrong entity or type | Use `type: announce` for Echo, `type: tts` for Fire TV |
| Plex wake automation doesn't fire | Wrong entity ID | Check Developer Tools → States for exact `media_player` ID |
| HACS not showing in integrations | Restart needed | Restart HA after HACS install, clear browser cache |

---

## References

- [Android TV Remote Integration](https://www.home-assistant.io/integrations/androidtv_remote/)
- [Android Debug Bridge Integration](https://www.home-assistant.io/integrations/androidtv/)
- [Alexa Media Player (HACS)](https://github.com/alandtse/alexa_media_player)
- [HACS Installation](https://hacs.xyz/docs/use/)
- [Home Assistant Cloud (Nabu Casa)](https://www.nabucasa.com/)
- [Plex Mini PC Power Automation](../operations/energy-saving-strategies.md#6-home-assistant-power-automations)
