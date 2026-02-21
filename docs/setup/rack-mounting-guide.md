# 19" 8U Rack — Mounting & Installation Guide

> Step-by-step order of operations for filling a wall-mounted 8U rack that is **open on top and bottom only** (sides closed).

---

## Prerequisites

- [ ] Empty rack already wall-mounted (studs/anchors rated for total load)
- [ ] Rack is level (use a spirit level on the front rails)
- [ ] All equipment unpacked and inventoried (see [rack-homelab-config.md](../network/rack-homelab-config.md) for full component list)
- [ ] All cables purchased per the [Cable Inventory](#cable-inventory) and labeled on both ends (see [Pre-Label Everything](#12-pre-label-everything))
- [ ] Rack rails verified — StarTech WALLSHELF8U uses **10-32 threaded holes** (screw directly into rails, no cage nuts needed)
- [ ] Basic toolkit: Phillips screwdriver, 10-32 rack screws, cable ties, narrow velcro straps (8mm / 5/16" width — standard 12mm won't fit through rail holes, see [cable securing](#how-to-attach-cables-to-the-rack-posts))

---

## Understanding Cable Access

With sides closed, you only have **two openings** for cable entry and exit:

```
       ▲ wall outlets (power + network) above rack
        ┌──── TOP OPENING ─────┐
        │                      │
        │   Cable entry from:  │
        │   • In-wall cables   │
        │   • WAN (ISP)        │
        │   • AP PoE cable     │
        │   • UPS mains power  │
        │                      │
   ┌────┴──────────────────────┴────┐
   │  ┌──────────────────────────┐  │
   │  │ U8  Mini PC              │  │◄── FRONT
   │  │ U7  Vented Panel         │  │    (only equipment
   │  │ U6  UDM-SE               │  │     access point)
   │  │ U5  Switch               │  │
   │  │ U4  Patch Panel          │  │
   │  │ U3  Vented Panel         │  │
   │  │ U2  NAS                  │  │
   │  │ U1  UPS                  │  │
   │  └──────────────────────────┘  │
   └────┬──────────────────────┬────┘
        │                      │
        │  BOTTOM OPENING      │
        │   (unused — wall     │
        │   outlets are above) │
        │                      │
        └──────────────────────┘
```

> [!IMPORTANT]
> The **top opening** is your only cable entry point — wall outlets (power and network) are located above the rack. Once upper equipment (U5–U8) is installed, routing new cables down to the middle and lower units becomes significantly harder. Plan all cable routes — **including the UPS mains power cable** — **before** filling the upper half of the rack.

---

## Cable Inventory

> Master list of all cables. Use this to verify you have everything before starting. The **Routed** column = when the cable is physically placed in the rack. The **Connected** column = when it gets plugged in.

### Ethernet Cables

See the [cable labeling system](../network/rack-homelab-config.md#cable-labeling) for the label format (number + destination).

| Label | Cable Type | From | To | Entry Point | Routed | Connected |
|-------|-----------|------|-----|-------------|--------|-----------|
| 01 AP | Cat6 PoE | U6-Pro AP (ceiling) | PP-01 rear keystone (U4) | Top | Phase 2.1 | Phase 4.3 |
| 02 Living | Cat6A in-wall cable | Living room wall plate | PP-02 rear keystone (U4) | Top | Phase 2.1 | Phase 3.4 |
| 03 Bedroom | Cat6A in-wall cable | Bedroom wall plate | PP-03 rear keystone (U4) | Top | Phase 2.1 | Phase 3.4 |
| 04 Studio | Cat6A in-wall cable | Studio wall plate | PP-04 rear keystone (U4) | Top | Phase 2.1 | Phase 3.4 |
| 05 Mini PC | Cat6 ethernet | Mini PC integrated NIC (U8) | Switch Port 5 (U5) | Internal | — | Phase 4.4 |
| 06 Mini PC | Cat6 ethernet | Mini PC USB adapter (U8) | Switch Port 6 (U5) | Internal | — | Phase 4.4 |
| 09 Printer | Cat6A in-wall cable | Printer | PP-09 rear keystone (U4) | Top | Phase 2.1 | Phase 4.3 |
| 16 WAN | Cat6 ethernet | ISP router (Iliad Box) | PP-16 rear keystone (U4) | Top | Phase 2.1 | Phase 4.3 |

### Front Patch Cables (Patch Panel → Switch / UDM-SE)

Short pre-made cables that connect the front of the patch panel (U4) to the switch (U5) or UDM-SE (U6) above. Use the same labels as the cables they serve.

| Label | Length | From | To | Connected |
|-------|--------|------|----|-----------|
| 01 AP | ~15 cm | PP-01 front (U4) | Switch Port 1 (U5) | Phase 4.3 |
| 02 Living | ~15 cm | PP-02 front (U4) | Switch Port 2 (U5) | Phase 4.3 |
| 03 Bedroom | ~15 cm | PP-03 front (U4) | Switch Port 3 (U5) | Phase 4.3 |
| 04 Studio | ~15 cm | PP-04 front (U4) | Switch Port 4 (U5) | Phase 4.3 |
| 09 Printer | ~15 cm | PP-09 front (U4) | Switch Port 9 (U5) | Phase 4.3 |
| 16 WAN | ~30 cm | PP-16 front (U4) | UDM-SE WAN RJ45 port (U6) | Phase 4.3 |

### Power Cables

All devices connect directly to UPS C13 outlets. No power strip — the UPS has 4x C13 (2 always-on, 2 remotely manageable) which matches the 4 devices exactly.

| Label | Cable Type | Length | From | To | Connected |
|-------|-----------|--------|------|----|-----------|
| PWR-UPS | Schuko mains | — | Wall outlet | UPS rear input (U1) | Phase 3.1 |
| PWR-UDM | IEC C13→C14 + C14-to-Schuko adapter (Spina IEC C14 a Presa Schuko 16A) | 1.0 m | UPS C13 #1 always-on (U1) | UDM-SE rear (U6) | Phase 4.1 |
| PWR-SW | IEC C13→C14 + C14-to-Schuko adapter (Spina IEC C14 a Presa Schuko 16A) | 1.0 m | UPS C13 #2 always-on (U1) | Switch rear (U5) | Phase 4.1 |
| PWR-NAS | IEC C13→C14 | 0.5 m | UPS C13 #3 manageable (U1) | NAS rear (U2) | Phase 4.1 |
| PWR-PC | IEC C13→Schuko adapter + power brick | 1.5 m | UPS C13 #4 manageable (U1) | Mini PC (U8) | Phase 4.1 |

### SFP+ Cables (10GbE Links)

DAC = Direct Attach Copper — a short, thick cable with SFP+ connectors on both ends. No separate transceivers needed.

| Label | Cable Type | From | To | Connected |
|-------|-----------|------|----|-----------|
| — | SFP+ DAC 10GbE | UDM-SE LAN SFP+ (U6) | Switch SFP+ Port 1 (U5) | Phase 4.2 |
| — | SFP+ DAC 10GbE | Switch SFP+ Port 2 (U5) | NAS SFP+ Port 1 (U2) | Phase 4.2 |

---

## Phase 1: Pre-Rack Preparation (Workbench)

Do as much work as possible **outside** the rack — it is always easier on a flat surface.

### 1.1 Prepare the Patch Panel

Get the patch panel frame and keystone jacks ready on a workbench. **Do not punch down (terminate) cables yet** — that happens later in Phase 3.4.

1. Unpack the keystone patch panel frame and verify all 16 keystone slots are intact
2. Lay out one keystone jack (Cat6A/Cat7) per external cable — you need 6 (AP, Living, Bedroom, Studio, Printer, WAN)
3. Have ready: punch-down tool (or toolless keystones), cable stripper, cable tester
4. Label each keystone slot on the panel frame (PP-01 AP, PP-02 Living, PP-03 Bedroom, PP-04 Studio, PP-09 Printer, PP-16 WAN — see [patch panel port assignments](../network/rack-homelab-config.md#u4--logilink-nk4077-patch-panel))

### 1.2 Pre-Label Everything

Label **both ends** of every cable before it enters the rack. Use the label format from the [Cable Labeling system](../network/rack-homelab-config.md#cable-labeling): number + destination (e.g. "01 AP", "02 Living").

**In-wall and external cables** (routed through the top opening):

| Label | Cable | Route |
|-------|-------|-------|
| 01 AP | AP PoE cable | Top opening → PP-01 rear (U4) |
| 02 Living | Living room cable | Top opening → PP-02 rear (U4) |
| 03 Bedroom | Bedroom room cable | Top opening → PP-03 rear (U4) |
| 04 Studio | Studio room cable | Top opening → PP-04 rear (U4) |
| 09 Printer | Printer cable | Top opening → PP-09 rear (U4) |
| 16 WAN | WAN uplink (ISP) | Top opening → PP-16 rear (U4) |
| PWR-UPS | UPS mains power | Top opening → UPS rear input (U1) |

**Internal rack cables** (never leave the rack):

| Label | Cable | Route |
|-------|-------|-------|
| 05 Mini PC | Mini PC integrated ethernet | Mini PC integrated NIC (U8) → Switch Port 5 (U5) |
| 06 Mini PC | Mini PC USB adapter ethernet | Mini PC USB adapter (U8) → Switch Port 6 (U5) |
| PWR-UDM | IEC C13→C14 + C14-to-Schuko adapter, 1.0 m | UPS C13 #1 always-on (U1) → UDM-SE (U6) |
| PWR-SW | IEC C13→C14 + C14-to-Schuko adapter, 1.0 m | UPS C13 #2 always-on (U1) → Switch (U5) |
| PWR-NAS | IEC C13→C14, 0.5 m | UPS C13 #3 manageable (U1) → NAS (U2) |
| PWR-PC | IEC C13→Schuko adapter, 1.5 m | UPS C13 #4 manageable (U1) → Mini PC (U8) |
| 01 AP | Front patch cable ~15 cm | PP-01 front (U4) → Switch Port 1 (U5) |
| 02 Living | Front patch cable ~15 cm | PP-02 front (U4) → Switch Port 2 (U5) |
| 03 Bedroom | Front patch cable ~15 cm | PP-03 front (U4) → Switch Port 3 (U5) |
| 04 Studio | Front patch cable ~15 cm | PP-04 front (U4) → Switch Port 4 (U5) |
| 09 Printer | Front patch cable ~15 cm | PP-09 front (U4) → Switch Port 9 (U5) |
| 16 WAN | Front patch cable ~30 cm | PP-16 front (U4) → UDM-SE WAN RJ45 port (U6) |

> [!TIP]
> Front patch cables use the **same label** as the in-wall cable they connect to. This makes it easy to trace a connection from wall plate to switch port.

### 1.3 Test-Fit Equipment

Before installing anything, confirm every device physically fits its intended U position:

- Rack ears / rail adapters attached
- Screws match the rail thread (10-32 for this rack — no cage nuts needed)
- Depth clearance is sufficient (measure from front rail to wall)

> [!WARNING]
> The NAS and UPS are the deepest devices. Measure the distance from the front rail to the wall and confirm both fit **before** installation.

---

## Phase 2: Cable Routing (Empty Rack)

**Do this while the rack is still empty.** This is your only chance to route cables freely through the full depth and height of the rack interior.

### 2.1 Route Ethernet Cables Through the Top

Feed all external ethernet cables down through the **top opening**, as a single bundle:

| Cable | Label | Destination | Pull down to |
|-------|-------|-------------|-------------|
| AP PoE cable | 01 AP | PP-01 rear keystone (U4) | U4 level |
| Living room cable | 02 Living | PP-02 rear keystone (U4) | U4 level |
| Bedroom cable | 03 Bedroom | PP-03 rear keystone (U4) | U4 level |
| Studio cable | 04 Studio | PP-04 rear keystone (U4) | U4 level |
| Printer cable | 09 Printer | PP-09 rear keystone (U4) | U4 level |
| WAN uplink | 16 WAN | PP-16 rear keystone (U4) | U4 level |

**Secure the bundle:**

1. Route all cables down the **left or right rear edge** of the rack interior (pick one side and stay consistent)
2. Leave **30–40 cm of extra cable** (a service loop) coiled at each cable's destination level — this spare slack lets you pull cables out later for termination or rework
3. Secure the bundle to the rack post using velcro straps (not zip ties — you may need to adjust later). See [How to attach cables to the rack posts](#how-to-attach-cables-to-the-rack-posts) below for technique

```
     TOP OPENING
         │
    ┌────┴────┐
    │  ○○○○○○ │      Keep cables tight against
    │  along  │◄──── one rear edge (left or right)
    │  rear   │
    │  edge   │
    │  ○○○○○○─│──── All cables: extra slack at U4
    │         │
    └────┬────┘
     BOTTOM
```

#### How to Attach Cables to the Rack Posts

The StarTech WALLSHELF8U has **closed side panels** and **10-32 threaded rail holes**. Since the sides are closed, you cannot wrap a strap around the post. Instead, thread the velcro strap through **two adjacent unused 10-32 holes** on the rail to create an anchor loop.

**Technique — thread through two rail holes:**

1. Push the velcro strap in through one unused 10-32 hole from the front
2. Behind the rail, loop the strap around the cable bundle (cables sit between the rail and side panel)
3. Thread the strap back out through the adjacent hole above or below
4. Pull both ends snug from the front and fold the velcro back on itself to close

```
    RAIL (side view — looking              RAIL (front view — you only
    from the open top or bottom)           see strap ends at the holes)

    front │ rear                           ┌──────────┐
          │                                │  ○       │ ◄── equipment screw
     ━━━━►├──────────────┓ strap in        │          │
          │              ┃ through hole 1  │  ● ← strap disappears into hole
          │           ○○○┃ loops behind    │  ┆       │ (loops behind rail,
          │           ○○○┃ cable bundle    │  ┆       │  around cables,
          │              ┃                 │  ┆       │  comes back)
     ◄━━━━├──────────────┛ strap out       │  ● ← strap comes back out
          │                through hole 2  │          │
          │                                │  ○       │ ◄── equipment screw
          │                                └──────────┘
```

> [!NOTE]
> Standard 10-32 holes are ~5mm. Use **narrow velcro cable ties** (8mm / 5/16" width) which fit through the holes. Standard 12mm (1/2") velcro ties are too wide.

**Placement — one strap every 1–2U along the rail:**

```
    RAIL
    ┌──┐
    │  ┝━━○○○  U5 level — strap holds ethernet bundle
    │  │
    │  ┝━━○○○  U4 level — strap holds ethernet bundle
    │  │
    │  │
    │  │
    └──┘

    (Repeat on opposite rail for power cable)
```

> [!TIP]
> Use a neutral color velcro strap for the shared ethernet bundle.

> [!WARNING]
> **Do not use adhesive-backed cable mounts** (stick-on anchor pads). The rack generates enough heat from the UPS, NAS, switch, and UDM-SE to soften the adhesive over time, causing mounts to detach and cables to sag.

### 2.2 Route the UPS Mains Cable

Feed the UPS power cable **down** through the **top opening** (on the **opposite rear edge** from the ethernet bundle) and leave it coiled at the U1 position. Secure it to the opposite rail with a velcro strap using the same [thread-through-holes technique](#how-to-attach-cables-to-the-rack-posts). Do not plug it into the wall outlet yet.

> [!TIP]
> Keep the mains power cable on the **opposite side** of the rack from the ethernet bundle. Separating power and data cables reduces electromagnetic interference.

### 2.3 Verify Before Proceeding

- [ ] All six external cables (01 AP, 02 Living, 03 Bedroom, 04 Studio, 09 Printer, 16 WAN) reach U4 level with 30–40 cm of extra slack
- [ ] All cables secured along one rear edge, not blocking the middle of the rack
- [ ] UPS mains cable (PWR-UPS) routed from top opening down to U1, on opposite side from ethernet bundle
- [ ] Top opening still has clearance for equipment to slide in

---

## Phase 3: Equipment Installation (Bottom → Up)

Install equipment from the **bottom of the rack upward**. This sequence ensures:

- The heaviest items (UPS, NAS) go in first at the bottom for stability
- Each device you install does not block access to the one below it
- The top opening stays clear as long as possible for cable adjustments

### 3.1 U1 — UPS (Eaton 5P 650i Rack G2)

The UPS is the heaviest single item (~15 kg). Install it first.

1. Slide the UPS into U1 on its rails
2. Secure with front screws
3. Connect the mains power cable (already routed from Phase 2) to the UPS rear input
4. **Do NOT plug the mains cable into the wall outlet yet** — no power until Phase 5

> [!WARNING]
> Use two people. The UPS weighs ~15 kg and lifting it at an angle into a wall-mounted rack risks dropping it or stripping the threaded rail holes.

### 3.2 U2 — QNAP NAS (TS-435XeU)

1. Slide the NAS into U2
2. Secure with front screws
3. **Do not connect any cables yet** — power and network come in Phase 4

### 3.3 U3 — Vented Panel #2

1. Snap/screw the vented panel into U3
2. No cabling required — it provides airflow between the NAS and networking gear

### 3.4 U4 — Patch Panel

**Do this before installing the Switch (U5) and UDM-SE (U6).** Once those are in place above U4, you cannot reach the back of the patch panel through the top opening.

All external cables get terminated here — they connect to the patch panel rear keystones.

**Step A — Terminate on the workbench (not in the rack):**

1. Grab the external cables at U4 level where you left extra slack in Phase 2.1. Pull them up and out through the top opening — you need enough cable outside the rack to reach your workbench.
2. For each cable: strip the outer sheath, punch down onto a keystone jack (or use toolless keystones), and snap the keystone into the correct panel slot:
   - 01 AP → slot PP-01
   - 02 Living → slot PP-02
   - 03 Bedroom → slot PP-03
   - 04 Studio → slot PP-04
   - 09 Printer → slot PP-09
   - 16 WAN → slot PP-16
3. Test every terminated port with a cable tester before the panel goes into the rack

**Step B — Mount the panel:**

4. Feed the terminated cables back through the top opening
5. Slide the patch panel into U4 and secure with front screws
6. Tidy up the rear cables — coil any excess and secure the coils with velcro

### 3.5 Checkpoint — Lower Half Complete

Before proceeding to the upper half, verify:

- [ ] UPS seated and secured at U1, mains cable connected (not plugged in)
- [ ] NAS seated and secured at U2
- [ ] Vented panel mounted at U3
- [ ] Patch panel mounted at U4 with all keystones terminated, tested, and rear cables tidy
- [ ] Cable bundle is tidy along rear edge, no loose loops hanging

> [!TIP]
> Take a photo of the rear cable routing now for future reference.

### 3.6 U5 — PoE Switch (USW-Pro-Max-16-PoE)

1. Slide the switch into U5
2. Secure with front screws

### 3.7 U6 — UDM-SE

1. Slide the UDM-SE into U6
2. Secure with front screws

### 3.8 U7 — Vented Panel

1. Snap/screw the vented panel into U7
2. No cabling required — it allows airflow between the switch and Mini PC

### 3.9 U8 — Lenovo Mini PC (Proxmox)

1. Place the Mini PC on its shelf/tray at U8
2. Secure if applicable (shelf strap, bracket, or just positioned)

> [!NOTE]
> The Mini PC sits at the top where heat rises and dissipates through the open top. This is intentional — see [Thermal Logic](../network/rack-homelab-config.md#thermal-logic).

---

## Phase 4: Internal Cabling (Front-Access)

All equipment is now installed. The remaining connections are made from the **front** of the rack using short patch cables and power cords.

### 4.1 Power Connections

All devices connect directly to UPS C13 outlets (U1). Route power cables along one side rail (opposite from ethernet cables to reduce EMI).

| UPS Outlet | Type | Device | Cable | Length | Route |
|-----------|------|--------|-------|--------|-------|
| C13 #1 | Always-on | UDM-SE (U6) | IEC C13→C14 + C14-to-Schuko adapter | 1.0 m | U1→U6, 5U |
| C13 #2 | Always-on | PoE Switch (U5) | IEC C13→C14 + C14-to-Schuko adapter | 1.0 m | U1→U5, 4U |
| C13 #3 | Remotely manageable | QNAP NAS (U2) | IEC C13→C14 | 0.5 m | U1→U2, 1U |
| C13 #4 | Remotely manageable | Mini PC (U8) | IEC C13→Schuko adapter + power brick | 1.5 m | U1→U8, 7U |

> [!NOTE]
> Network infrastructure (UDM-SE, Switch) on **always-on** outlets. Storage and compute (NAS, Mini PC) on **remotely manageable** outlets — NUT can shut them down during extended outages to extend battery runtime for the network.

> [!TIP]
> Route power cables along one side rail and network cables along the other. This reduces electromagnetic interference and makes troubleshooting easier.

### 4.2 10GbE Links (SFP+)

Connect the 10GbE links using DAC (Direct Attach Copper) cables or SFP+ transceivers + fiber:

| Connection | From | To |
|-----------|------|-----|
| 10GbE Link 1 | UDM-SE LAN SFP+ (U6) | Switch SFP+ Port 1 (U5) |
| 10GbE Link 2 | Switch SFP+ Port 2 (U5) | QNAP NAS SFP+ Port 1 (U2) |

> [!NOTE]
> The NAS SFP+ cable runs from U5 down to U2 (3U). Use a 1m DAC cable and route it along the side rail to keep it tidy.

### 4.3 Front Patch Cables (Patch Panel → Switch)

These are **separate pre-made patch cables** — not the in-wall runs. They bridge the **front** of the patch panel (U4) **up** to the switch (U5) or UDM-SE (U6) above, completing the connection path.

| Patch Cable Label | From | To | VLAN |
|-------------------|------|----|------|
| 01 AP | PP-01 front (U4) | Switch Port 1 (U5) | Management (2) |
| 02 Living | PP-02 front (U4) | Switch Port 2 (U5) | Media (4) |
| 03 Bedroom | PP-03 front (U4) | Switch Port 3 (U5) | Media (4) |
| 04 Studio | PP-04 front (U4) | Switch Port 4 (U5) | Media (4) |
| 09 Printer | PP-09 front (U4) | Switch Port 9 (U5) | Servers (3) |
| 16 WAN | PP-16 front (U4) | UDM-SE WAN RJ45 port (U6) | — |

Use **~15 cm** patch cables for U4→U5 connections (1U distance). Use **~30 cm** for the WAN patch cable to U6 (2U distance).

> [!NOTE]
> The full connection path for each external cable is: **source device → labeled in-wall cable → patch panel rear keystone (U4) → patch panel front port → labeled patch cable → switch port (U5) or UDM-SE (U6)**.

### 4.4 Remaining Ethernet Connections

| Label | From | To | Notes |
|-------|------|-----|-------|
| 05 Mini PC | Mini PC integrated NIC (U8) | Switch Port 5 (U5) | 1GbE, short internal cable |
| 06 Mini PC | Mini PC USB adapter (U8) | Switch Port 6 (U5) | Management, short internal cable |

### 4.5 Cable Management Final Pass

1. Bundle front-facing patch cables with velcro straps
2. Ensure no cables obstruct the vented panels (U3 and U7) airflow
3. Verify no cables are pinched, kinked, or under tension
4. Confirm all labels are visible from the front

---

## Phase 5: Power On & Verification

### 5.1 Power-On Sequence

Power on devices in this order, waiting for each to fully boot before starting the next:

| Step | Action | Wait For |
|------|--------|----------|
| 1 | Plug UPS mains cable into wall outlet | UPS LCD shows "Online", battery charging indicator |
| 2 | Configure UPS LCD settings (first startup only) | See [5.2 UPS Initial Configuration](#52-ups-initial-configuration-first-startup-only) below |
| 3 | Power on UDM-SE | White status LED steady (boot takes ~3–5 min) |
| 4 | Power on PoE Switch | Status LED steady, PoE ports become active |
| 5 | Power on QNAP NAS | System ready beep, LCD shows IP |
| 6 | Power on Mini PC | Proxmox boot to login prompt |

> [!IMPORTANT]
> Power on the UDM-SE and switch **before** the NAS. The NAS needs a working network to obtain its IP and become reachable. The Mini PC (Plex) depends on the NAS media shares being available.

### 5.2 UPS Initial Configuration (First Startup Only)

On the very first power-on, the Eaton 5P Gen2 LCD prompts you to configure output voltage and date/time. Use the LCD front panel buttons to navigate:

- **⮠ (Enter)** — activate menu / confirm selection
- **⯅ ⯆ (Up/Down)** — scroll through options
- **ESC** — cancel / go back

Configure the following settings via **⮠ → Settings**:

| Setting | Menu Path | Recommended Value | Notes |
|---------|-----------|-------------------|-------|
| Output Voltage | Settings → Output Voltage | **230V** | Default. Options: 200 / 208 / 220 / 230 / 240V. Match your country's mains voltage |
| Date / Time | Settings → Date/Time | **Set current date and time** | Used for event log timestamps |
| Power Quality | Settings → Power Quality → Mode | **Good** | Default. Tightest voltage/frequency thresholds — transfers to battery at smallest deviation. Best for sensitive homelab equipment |
| Buzzer | Settings → Buzzer | **Enabled** | Default. Audible alarm on power events. Disable only if the rack is in a bedroom |

**Power Quality modes explained:**

| Mode | Behaviour | Use When |
|------|-----------|----------|
| **Good** (default) | Tightest thresholds — transfers to battery at smallest voltage/frequency deviation | Servers, NAS, networking gear (recommended) |
| Fair | Tolerates slight voltage and frequency variation before transferring | Equipment that handles minor fluctuations |
| Poor | Extended thresholds — tolerates significant deviation and distorted waveforms | Rugged or non-sensitive equipment |
| Custom | Independently set Voltage (Normal/Extended), Frequency (Normal/Extended), Sensitivity (High/Normal/Low) | Advanced tuning only |

> [!NOTE]
> **IP Address / Network card**: The 5P 650i connects via **USB to Proxmox** for monitoring (NUT). It has no built-in network interface. An optional Eaton Network-M2 or Network-M3 card can be installed in the communication bay for SNMP/web management, but this is unnecessary when using NUT over USB. See [energy-saving-strategies.md Section 5](../operations/energy-saving-strategies.md#5-ups-monitoring-with-nut) for NUT configuration.

> [!TIP]
> After configuration, verify settings with: **⮠ → Measurements** to check input/output voltage and load percentage. You can also verify later via NUT: `upsc eaton` once configured on Proxmox.

### 5.3 Verification Checklist

- [ ] UPS shows all 4 outlets active (2 always-on, 2 manageable), battery status healthy
- [ ] UDM-SE reachable at 192.168.2.1
- [ ] Switch adopted in UniFi Controller at 192.168.2.10
- [ ] NAS reachable at 192.168.3.10
- [ ] Proxmox reachable at 192.168.3.20:8006
- [ ] Each patch panel port provides link light on the corresponding switch port
- [ ] AP adopted and broadcasting SSIDs
- [ ] Run `make health` from NAS to verify all Docker services

---

## Quick Reference: Installation Order Summary

```
PHASE 1 — WORKBENCH              PHASE 2 — EMPTY RACK
┌─────────────────────────┐      ┌─────────────────────────┐
│ ✦ Prepare patch panel   │      │ ✦ Route ethernet cables │
│   and keystone jacks    │      │   through TOP opening   │
│ ✦ Label all cables      │      │ ✦ Route UPS mains cable │
│ ✦ Test-fit equipment    │      │   through TOP opening   │
└─────────────────────────┘      └─────────────────────────┘
            │                                │
            ▼                                ▼
PHASE 3 — INSTALL BOTTOM → UP   PHASE 4 — CABLE FROM FRONT
┌─────────────────────────┐      ┌─────────────────────────┐
│ U1  UPS ............. ① │      │ ✦ IEC power cables      │
│ U2  NAS ............. ② │      │   (UPS → devices direct)│
│ U3  Vented Panel .... ③ │      │ ✦ SFP+ 10GbE links      │
│ U4  Patch Panel ..... ④ │      │ ✦ Patch cables (PP →    │
│  ► TERMINATE + MOUNT ◄  │      │   switch, short ~15cm)  │
│ U5  Switch .......... ⑤ │      │ ✦ AP & Mini PC ethernet │
│ U6  UDM-SE .......... ⑥ │      │ ✦ Tidy cables & labels  │
│ U7  Vented Panel .... ⑦ │      └─────────────────────────┘
│ U8  Mini PC ......... ⑧ │                  ▼
└─────────────────────────┘      PHASE 5 — POWER ON
                                 ┌─────────────────────────┐
                                 │ UPS → UDM-SE → Switch → │
                                 │ NAS → Mini PC           │
                                 └─────────────────────────┘
```

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| Cable won't reach patch panel rear | Not enough extra slack | Pull more cable through top opening; may need to remove upper equipment temporarily |
| No link light after patching | Bad keystone termination | Re-test with cable tester; re-punch if needed |
| UPS overload alarm on power-on | Too many devices started simultaneously | Power on one device at a time, wait for each to stabilize |
| NAS not reachable after boot | Switch/UDM-SE not ready yet | Follow the power-on sequence — network gear first |
| Excessive heat at U8 | Top opening obstructed | Ensure nothing is placed on top of the rack blocking airflow |
| Equipment too deep for rack | Wall clearance insufficient | Measure depth before wall-mounting; some racks allow offset mounting |

---

## Related Documentation

| Topic | File |
|-------|------|
| Rack layout, components & IP plan | [rack-homelab-config.md](../network/rack-homelab-config.md) |
| NAS hardware setup | [nas-setup.md](nas-setup.md) |
| Proxmox installation | [proxmox-setup.md](proxmox-setup.md) |
| Network & VLAN configuration | [network-setup.md](network-setup.md) |
| Firewall rules | [firewall-config.md](../network/firewall-config.md) |
