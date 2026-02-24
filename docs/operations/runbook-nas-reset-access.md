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

## Do I Need the Cloud Key Again?

**No.** The myQNAPcloud cloud key is only used for initial remote discovery when you don't know the NAS IP address. After a reset button press, you can access the NAS directly on the local network — no cloud setup is needed.

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

#### After a short press (3 seconds — network reset only)

Your admin password is unchanged. Log in with your existing credentials.

#### After a long press (10 seconds — password reset)

The admin password has been reset to the default. On QTS 5.x and later, the default password is the **first MAC address** of the NAS in lowercase, without separators.

**Find the MAC address:**

```bash
# Option A: Check UDM-SE client list for the NAS
# Option B: Look at the sticker on the back/bottom of the NAS
# Option C: Use Qfinder Pro (displays MAC in device details)
```

**Format the password:**

```
# MAC on sticker:    00:08:9B:XX:YY:ZZ
# Password to type:  00089bxxyyzz
```

> [!TIP]
> On older QTS versions (< 5.0), the default admin password after reset may be the MAC address with uppercase letters, or simply `admin`. Try both formats if the first doesn't work.

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
┌─────────────────────────────────────────────────────────────┐
│                  NAS RESET BUTTON RECOVERY                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Browse to http://192.168.3.10:8080                      │
│  2. Log in:                                                 │
│     • Short press → existing password                       │
│     • Long press  → MAC address (lowercase, no separators)  │
│  3. Change password immediately                             │
│  4. Verify storage + containers: make status && make health │
│                                                             │
│  Cloud key: NOT needed                                      │
│  Data: NOT affected                                         │
│  Containers: NOT affected                                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| NAS not reachable at 192.168.3.10 | DHCP reservation not applied yet | Wait 1-2 minutes, check UDM-SE client list, use Qfinder Pro |
| Cannot find NAS on network at all | NAS not fully booted, or on wrong VLAN | Check physical cable to SFP+ port 2 on switch (Servers VLAN 3), check NAS power/LCD |
| Admin password doesn't work | Wrong MAC format | Try lowercase without separators, uppercase without separators, or `admin` |
| Container Station missing | Reset doesn't remove apps — likely not installed | Reinstall from App Center |
| Containers not running | Docker daemon restarted during reset | `cd /share/container/mediastack && make up` |
| Services unhealthy after restart | Configs intact but services need initialization time | Wait 2-3 minutes, then `make health` again |

---

## References

- QNAP Knowledge Base — [How to reset my QNAP NAS](https://www.qnap.com/en/how-to/knowledge-base/article/how-to-reset-my-qnap-nas)
- Qfinder Pro download — [qnap.com/utilities](https://www.qnap.com/en/utilities/essentials)
- NAS setup checklist — [`nas-setup.md`](../setup/nas-setup.md)
- Network DHCP reservations — [`network-setup.md` Phase 4](../setup/network-setup.md#phase-4-dhcp-reservations)
