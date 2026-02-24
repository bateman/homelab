# Runbook — NAS Reset Button Recovery

> How to regain access to the QNAP TS-435XeU after a physical reset button press

---

## Reset Button Behavior

The QNAP TS-435XeU has a recessed reset button on the back panel. Its behavior depends on how long you hold it:

| Press Duration | Beeps | What It Resets |
|----------------|-------|----------------|
| **3 seconds** | 1 beep | Network settings only (IP reverts to DHCP) |
| **10 seconds** | 2 beeps | Network settings + admin password |

### What Is NOT Affected

Regardless of reset type, the following are **preserved**:

- Storage pools, volumes, and all data
- Shared folders and their contents
- Installed applications (Container Station, etc.)
- Docker containers, images, and configs
- Non-admin user accounts (e.g., `dockeruser`)
- Scheduled tasks and system settings (except network/admin password)

> [!IMPORTANT]
> The reset button does **not** factory-wipe the NAS. It only resets network configuration and (on long press) the admin password.

---

## Do I Need the Cloud Key / Cloud Installation Again?

**You do NOT need to repeat the cloud installation** (install.qnap.com). That process is only for initial QTS setup on a brand-new or fully reinitialized NAS. A reset button press does not require reinstallation.

**However, the Cloud Key IS your login password on QTS 5.2+.** Starting with QTS/QuTS hero 5.2.0, the default admin password after reset is the device's Cloud Key (not the MAC address). You can find it on a sticker on the NAS, via Qfinder Pro, or on myQNAPcloud. See [Step 3](#step-3--log-in) for details.

---

## Recovery Steps

### Step 1 — Identify the NAS IP

Since the NAS is configured with a **DHCP reservation** on the UDM-SE (see [`network-setup.md` Phase 4](../setup/network-setup.md#phase-4-dhcp-reservations)), the reset to DHCP actually works in your favor — the NAS will request an IP via DHCP and receive its reserved address:

| Setting | Value |
|---------|-------|
| Expected IP | `192.168.3.10` |
| DHCP reservation | Configured on UDM-SE for the NAS MAC address |

**Verify the IP was assigned:**

```bash
# From any machine on the Servers VLAN (192.168.3.0/24)
ping 192.168.3.10
```

**If ping fails**, the NAS may not have received the reservation yet:

1. **Check UDM-SE** → Settings → Networks → Servers → DHCP → Client list — look for the NAS MAC address
2. **Use Qfinder Pro** (download from [qnap.com/utilities](https://www.qnap.com/en/utilities/essentials)) — it discovers QNAP devices on the local network via broadcast
3. **Check the NAS front LCD panel** (if available) — it displays the current IP

### Step 2 — Access QTS Web Interface

Open a browser and go to:

```
http://192.168.3.10:8080
```

### Step 3 — Log In

- **Username:** `admin`
- **Password:** depends on your QTS version (see below)

#### After a short press (3 seconds — network reset only)

Your admin password is unchanged. Log in with your existing credentials.

#### After a long press (10 seconds — password reset)

The admin password resets to a **version-dependent default**:

| QTS Version | Default Password | Format |
|-------------|-----------------|--------|
| **QTS/QuTS hero 5.2.0+** | **Cloud Key** | Uppercase, no dashes (e.g., `Q12345678`) |
| QTS 4.4.2 – 5.1.x | First MAC address (MAC1) | Uppercase, no separators (e.g., `00089BF61575`) |
| QTS < 4.4.2 | `admin` | Literal string |

> [!IMPORTANT]
> **QTS 5.2+ changed the default password from MAC address to Cloud Key.** If you updated firmware to 5.2 or later, the MAC address will NOT work — you need the Cloud Key.

#### Finding the Cloud Key (QTS 5.2+)

The Cloud Key is printed on a **separate sticker** on the NAS (not the MAC address sticker). It looks like `Q1234-5678`.

```
# Cloud Key on sticker:  Q1234-5678
# Password to type:      Q12345678  (uppercase, no dashes)
```

**If you can't find the sticker:**

1. **Qfinder Pro** (without drives) — power off NAS, remove all drives, power on, run Qfinder Pro → select device → Details → Cloud Key is displayed
2. **myQNAPcloud** — log in at myqnapcloud.com → Device Management → your device → Device Detail

#### Finding the MAC Address (QTS 4.4.2 – 5.1.x)

Use the MAC address labeled **MAC1** on the NAS rear sticker — this is the first built-in RJ45 NIC, **not** the SFP+ ports.

```
# MAC1 on sticker:  00:08:9B:XX:YY:ZZ
# Password to type: 00089BXXYYZZ  (UPPERCASE, no colons/dashes)
```

**If MAC1 doesn't work:**

- The TS-435XeU has multiple stickers — check for a second sticker with additional MAC addresses and try those
- Verify you're using **UPPERCASE** letters (not lowercase)
- Try other MACs listed on the sticker (MAC2, MAC3, etc.)
- Use Qfinder Pro → select device → the MAC shown in the device list is the one QTS uses

> [!TIP]
> **Still not working?** The reset button may have been disabled in QTS settings (Control Panel → System → Hardware → "Enable configuration reset switch"). In that case, skip to the [Advanced Recovery](#advanced-recovery--password-still-not-working) section below.

### Step 3b — Advanced Recovery (Password Still Not Working)

If none of the default passwords work (Cloud Key, MAC, or `admin`), the reset button may have been disabled, or the admin account was in an unusual state. Use the **diskless boot + SSH** method:

1. **Power off** the NAS
2. **Remove all drives** from the bays (note the exact order — bay 1, 2, 3, 4)
3. **Power on** the NAS without drives
4. Wait for a short beep, then a long beep (~2-3 minutes)
5. **Run Qfinder Pro** on your PC — it will discover the NAS
6. **Do NOT click "Initialize"** if prompted
7. **Re-insert the drives** in their original order (hot-plug — do NOT power off)
8. **SSH into the NAS:**
   ```bash
   ssh admin@<ip-shown-in-qfinder>
   # Password: admin (diskless boot always uses admin/admin)
   ```
9. **Reset the password:**
   ```bash
   # Check if this is a HAL or Legacy model
   /sbin/hal_app
   # If "No such file" → Legacy model, if silent → HAL model

   # Then reset password with:
   passwd admin
   # Enter new password twice

   # Reboot
   reboot
   ```

> [!WARNING]
> **Do NOT run the Smart Installation wizard** if it appears — clicking through it could reinitialize the system. Just close the browser tab and proceed with SSH.

> [!TIP]
> Download Qfinder Pro from [qnap.com/utilities](https://www.qnap.com/en/utilities/essentials) — it's available for Windows, macOS, and Linux.

---

### Step 4 — Post-Login Checklist

After regaining access, verify and reconfigure:

- [ ] **Change admin password** to a secure password immediately
- [ ] **Verify network settings** — DHCP should already be correct since we use DHCP reservation
  - Control Panel → Network & Virtual Switch → Interfaces
  - Confirm adapter is set to DHCP (not static)
  - Confirm hostname is `qnap-nas`
- [ ] **Verify storage** — pools and volumes should be intact
  - Storage & Snapshots → Overview
- [ ] **Verify shared folders** — `/share/data`, `/share/container`, `/share/backup`
  - Control Panel → Shared Folders
- [ ] **Verify Container Station** — open Container Station and check containers are running
  - Or via SSH: `docker ps`
- [ ] **Verify Docker stack** (via SSH):
  ```bash
  ssh admin@192.168.3.10
  cd /share/container/mediastack
  make status
  make health
  ```
- [ ] **Verify 2FA** — re-enable if it was disabled by the reset
  - Control Panel → Security → 2-Step Verification

### Step 5 — Restart Docker Stack (If Needed)

If containers are stopped after the reset:

```bash
ssh admin@192.168.3.10
cd /share/container/mediastack
make up
make status
```

Verify services are responding:

```bash
make health
make urls    # Shows all WebUI URLs
```

---

## Quick Reference

```
┌──────────────────────────────────────────────────────────────────┐
│                    NAS RESET BUTTON RECOVERY                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Browse to http://192.168.3.10:8080                           │
│  2. Username: admin                                              │
│  3. Password (try in order):                                     │
│     a) Cloud Key — UPPERCASE, no dashes (QTS 5.2+)              │
│     b) MAC1 — UPPERCASE, no colons (QTS 4.4.2–5.1)              │
│     c) admin (QTS < 4.4.2)                                      │
│  4. If none work → diskless boot + SSH reset (see guide)         │
│  5. Change password immediately after login                      │
│  6. Verify: make status && make health                           │
│                                                                  │
│  Cloud installation: NOT needed again                            │
│  Data: NOT affected                                              │
│  Containers: NOT affected                                        │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| NAS not reachable at 192.168.3.10 | DHCP reservation not applied yet | Wait 1-2 minutes, check UDM-SE client list, use Qfinder Pro |
| Cannot find NAS on network at all | NAS not fully booted, or on wrong VLAN | Check physical cable to SFP+ port 2 on switch (Servers VLAN 3), check NAS power/LCD |
| MAC address password doesn't work | QTS 5.2+ uses Cloud Key, not MAC | Try the Cloud Key from the NAS sticker (uppercase, no dashes) |
| Cloud Key password doesn't work | Wrong format or reset switch disabled | Try uppercase without dashes; if still failing, use [diskless boot + SSH method](#step-3b--advanced-recovery-password-still-not-working) |
| No beep when pressing reset button | Reset switch disabled in QTS settings | Use [diskless boot + SSH method](#step-3b--advanced-recovery-password-still-not-working) |
| Smart Installation wizard appears | NAS booted without drives | Do NOT initialize — close browser, re-insert drives, use SSH |
| Container Station missing | Reset doesn't remove apps — likely not installed | Reinstall from App Center |
| Containers not running | Docker daemon restarted during reset | `cd /share/container/mediastack && make up` |
| Services unhealthy after restart | Configs intact but services need initialization time | Wait 2-3 minutes, then `make health` again |

---

## References

- QNAP — [What is the default system administrator password for my NAS?](https://www.qnap.com/en/how-to/faq/article/what-is-the-default-system-administrator-password-for-my-nas)
- QNAP — [Default password changed to Cloud Key (QTS 5.2+)](https://www.qnap.com/en/how-to/faq/article/nas-default-administrator-password-changed-to-cloud-key-starting-from-qtsquts-hero-520)
- QNAP — [How do I reset the administrator password?](https://www.qnap.com/en/how-to/faq/article/how-do-i-reset-the-administrator-password-of-my-nas)
- QNAP — [How do I log in after resetting my NAS?](https://www.qnap.com/en/how-to/faq/article/how-do-i-log-in-after-resetting-my-nas)
- QNAP — [How do I find my NAS device's Cloud Key?](https://www.qnap.com/en-us/how-to/faq/article/how-do-i-find-my-nas-device-cloud-key)
- QNAP — [Password reset doesn't work — what can I do?](https://www.qnap.com/en/how-to/faq/article/im-unable-to-log-in-to-qts-and-the-password-reset-does-not-work-what-can-i-do)
- Qfinder Pro download — [qnap.com/utilities](https://www.qnap.com/en/utilities/essentials)
- NAS setup checklist — [`nas-setup.md`](../setup/nas-setup.md)
- Network DHCP reservations — [`network-setup.md` Phase 4](../setup/network-setup.md#phase-4-dhcp-reservations)
