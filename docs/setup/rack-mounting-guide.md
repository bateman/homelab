# 19" 8U Rack — Mounting & Installation Guide

> Step-by-step order of operations for populating a wall-mounted 8U rack that is **open on top and bottom only** (sides closed).

---

## Prerequisites

- [ ] Empty rack already wall-mounted (studs/anchors rated for total load)
- [ ] Rack is level (use a spirit level on the front rails)
- [ ] All equipment unpacked and inventoried (see [rack-homelab-config.md](../network/rack-homelab-config.md) for full component list)
- [ ] All cables purchased per the [Cable Inventory](#cable-inventory) and labeled on both ends (see [Pre-Label Everything](#12-pre-label-everything))
- [ ] Cage nuts / clip nuts installed in correct rail positions for all 8U
- [ ] Basic toolkit: cage nut tool, Phillips screwdriver, cable ties, velcro straps

---

## Understanding Cable Access

With sides closed, you only have **two openings** for cable entry and exit:

```
        ┌──── TOP OPENING ────┐
        │                      │
        │   Cable entry from:  │
        │   • In-wall runs     │
        │   • WAN (ISP)        │
        │   • AP PoE cable     │
        │                      │
   ┌────┴──────────────────────┴────┐
   │  ┌──────────────────────────┐  │
   │  │ U8  Mini PC              │  │◄── FRONT
   │  │ U7  Vented Panel         │  │    (only equipment
   │  │ U6  Switch               │  │     access point)
   │  │ U5  UDM-SE               │  │
   │  │ U4  Patch Panel          │  │
   │  │ U3  Power Strip          │  │
   │  │ U2  NAS                  │  │
   │  │ U1  UPS                  │  │
   │  └──────────────────────────┘  │
   └────┬──────────────────────┬────┘
        │                      │
        │  BOTTOM OPENING      │
        │   Cable exit for:    │
        │   • UPS mains power  │
        │                      │
        └──────────────────────┘
              ▼ to wall outlet
```

> [!IMPORTANT]
> The **top opening** is your primary cable entry point. Once upper equipment (U5–U8) is installed, routing new cables down to the middle and lower units becomes significantly harder. Plan all cable routes **before** filling the upper half of the rack.

---

## Cable Inventory

> Every cable in the build, its label, color, route, and when it gets handled. Use this table as a checklist — each cable has exactly two events: **routed** (physically placed) and **connected** (plugged in).

### Ethernet Cables

Labeled using the [color coding system](../network/rack-homelab-config.md#network-cable-color-coding): 🟢 Green = room devices, ⚪ White = management/uplink, ⚫ Black = rack internal.

| Label | Color | Cable Type | From | To | Entry Point | Routed | Connected |
|-------|-------|-----------|------|-----|-------------|--------|-----------|
| GRN-01 Studio | 🟢 Green | Cat6A in-wall run | Studio wall plate | PP-03 rear keystone (U4) | Top | Phase 2.1 | Phase 3.5 |
| GRN-02 Living | 🟢 Green | Cat6A in-wall run | Living room wall plate | PP-04 rear keystone (U4) | Top | Phase 2.1 | Phase 3.5 |
| GRN-03 Bedroom | 🟢 Green | Cat6A in-wall run | Bedroom wall plate | PP-05 rear keystone (U4) | Top | Phase 2.1 | Phase 3.5 |
| WHT-WAN | ⚪ White | Cat6 ethernet | ISP router (Iliad Box) | UDM-SE WAN RJ45 port (U5) | Top | Phase 2.1 | Phase 3.7 |
| WHT-01 AP | ⚪ White | Cat6 PoE | U6-Pro AP (ceiling) | Switch Port 2 (U6) | Top | Phase 2.1 | Phase 4.4 |
| BLK-01 Proxmox | ⚫ Black | Cat6 ethernet | Mini PC (U8) | Switch port or UDM-SE LAN | Internal | — | Phase 4.4 |

### Front Patch Cables (Patch Panel → Switch)

Pre-made short cables. Use **green** to match the room drops they extend — same label, same color.

| Label | Color | Length | From | To | Connected |
|-------|-------|--------|------|----|-----------|
| GRN-01 Studio | 🟢 Green | ~30 cm | PP-03 front (U4) | Switch Port 3 (U6) | Phase 4.3 |
| GRN-02 Living | 🟢 Green | ~30 cm | PP-04 front (U4) | Switch Port 4 (U6) | Phase 4.3 |
| GRN-03 Bedroom | 🟢 Green | ~30 cm | PP-05 front (U4) | Switch Port 5 (U6) | Phase 4.3 |

### Power Cables

Standard IEC and Schuko cables — not color-coded, but label the UPS mains cable for easy identification.

| Label | Cable Type | From | To | Connected |
|-------|-----------|------|----|-----------|
| PWR-UPS | Schuko mains | Wall outlet | UPS rear input (U1) | Phase 3.1 |
| — | IEC C14→C13 | UPS C13 #4 (U1) | Power strip input (U3) | Phase 3.4 |
| — | IEC C14→C13 | UPS C13 #1 (U1) | NAS rear (U2) | Phase 4.1 |
| — | IEC C14→C13 | UPS C13 #2 (U1) | UDM-SE rear (U5) | Phase 4.1 |
| — | IEC C14→C13 | UPS C13 #3 (U1) | Switch rear (U6) | Phase 4.1 |
| — | Schuko + adapter | Power strip #1 (U3) | Mini PC (U8) | Phase 4.1 |

### SFP+ Cables (10GbE Backbone)

| Label | Cable Type | From | To | Connected |
|-------|-----------|------|----|-----------|
| — | SFP+ DAC 10GbE | UDM-SE LAN SFP+ (U5) | Switch SFP+ Port 1 (U6) | Phase 4.2 |
| — | SFP+ DAC 10GbE | Switch SFP+ Port 2 (U6) | NAS SFP+ Port 1 (U2) | Phase 4.2 |

---

## Phase 1: Pre-Rack Preparation (Workbench)

Do as much work as possible **outside** the rack — it is always easier on a flat surface.

### 1.1 Prepare the Patch Panel

Lay out patch panel materials on a workbench:

1. Unpack the keystone patch panel frame and verify all 12 keystone slots are intact
2. Lay out one keystone jack (Cat6A/Cat7) per in-wall cable run
3. Have ready: punch-down tool (or toolless keystones), cable stripper, cable tester
4. Label each keystone slot on the panel frame (PP-03 Studio, PP-04 Living, PP-05 Bedroom — see [patch panel port assignments](../network/rack-homelab-config.md#u4--deleycon-patch-panel))

> [!NOTE]
> Actual cable termination happens after cables are routed into the rack (Phase 2). The panel will be terminated on the workbench in Phase 3.5 before it is mounted.

### 1.2 Pre-Label Everything

Label **both ends** of every cable before it enters the rack. Use the color coding from the [Cable Inventory](#cable-inventory): 🟢 Green = room devices, ⚪ White = management/uplink, ⚫ Black = rack internal.

**In-wall and external cables** (routed through rack openings):

| Label | Color | Cable | Route |
|-------|-------|-------|-------|
| GRN-01 Studio | 🟢 Green | Studio room drop | Top opening → PP-03 rear (U4) |
| GRN-02 Living | 🟢 Green | Living room drop | Top opening → PP-04 rear (U4) |
| GRN-03 Bedroom | 🟢 Green | Bedroom room drop | Top opening → PP-05 rear (U4) |
| WHT-WAN | ⚪ White | WAN uplink (ISP) | Top opening → UDM-SE WAN port (U5) |
| WHT-01 AP | ⚪ White | AP PoE feed | Top opening → Switch Port 2 (U6) |
| PWR-UPS | — | UPS mains power | Bottom opening → wall outlet |

**Internal rack cables** (never leave the rack):

| Label | Color | Cable | Route |
|-------|-------|-------|-------|
| BLK-01 Proxmox | ⚫ Black | Mini PC ethernet | Mini PC (U8) → Switch or UDM-SE LAN |
| GRN-01 Studio | 🟢 Green | Front patch cable ~30 cm | PP-03 front (U4) → Switch Port 3 (U6) |
| GRN-02 Living | 🟢 Green | Front patch cable ~30 cm | PP-04 front (U4) → Switch Port 4 (U6) |
| GRN-03 Bedroom | 🟢 Green | Front patch cable ~30 cm | PP-05 front (U4) → Switch Port 5 (U6) |

> [!TIP]
> The front patch cables carry the **same label and color** as the in-wall run they extend. This means you can trace a room connection end-to-end: green cable in the wall → green keystone at patch panel rear → green patch cable on front → switch port.

### 1.3 Dry-Fit Equipment

Confirm every device fits its intended U position with the correct mounting hardware:

- Rack ears / rail adapters attached
- Screws and cage nuts match (M6 is most common for 19" racks)
- Depth clearance is sufficient (measure from front rail to wall)

> [!WARNING]
> The NAS and UPS are the deepest devices. Verify they clear the wall behind the rack **before** installation — you do not want to discover a fit problem with 15kg already on the rails.

---

## Phase 2: Cable Rough-In (Empty Rack)

**Do this while the rack is still empty.** This is your only chance to route cables freely through the full depth and height of the rack interior.

### 2.1 Route Ethernet Cables Through the Top

Feed all five external ethernet cables down through the **top opening**, one group at a time:

**Step 1 — Room drops (🟢 Green):** Route the three green in-wall cables together as a bundle.

| Cable | Label | Destination | Pull down to |
|-------|-------|-------------|-------------|
| Studio run | GRN-01 Studio | PP-03 rear keystone (U4) | U4 level |
| Living room run | GRN-02 Living | PP-04 rear keystone (U4) | U4 level |
| Bedroom run | GRN-03 Bedroom | PP-05 rear keystone (U4) | U4 level |

**Step 2 — Management/uplink (⚪ White):** Route the two white cables alongside the green bundle.

| Cable | Label | Destination | Pull down to |
|-------|-------|-------------|-------------|
| WAN uplink | WHT-WAN | UDM-SE WAN RJ45 port (U5) | U5 level |
| AP PoE feed | WHT-01 AP | Switch Port 2 (U6) | U6 level |

**Step 3 — Secure the bundle:**

1. Route all five cables down the **left or right rear edge** of the rack interior (pick one side and stay consistent)
2. Leave a **30–40 cm service loop** on each cable at its destination level
3. Temporarily secure the bundle to the rear rail or rack frame with velcro straps (not zip ties — you may need to adjust later)

```
     TOP OPENING
         │
    ┌────┴────┐
    │ ⚪⚪🟢 │
    │ 🟢🟢   │      Keep cables tight against
    │ along   │◄──── one rear edge (left or right)
    │ rear    │
    │ edge    │
    │  ⚪─────│──── WHT-01 AP service loop at U6
    │  ⚪─────│──── WHT-WAN service loop at U5
    │  🟢🟢🟢│──── GRN-01/02/03 service loops at U4
    │         │
    └────┬────┘
     BOTTOM
```

### 2.2 Route the UPS Mains Cable

Feed the UPS power cable **up** through the **bottom opening** and leave it coiled at the U1 position. Do not plug it into the wall yet.

### 2.3 Verify Before Proceeding

- [ ] Three green cables (GRN-01/02/03) reach U4 level with service loop to spare
- [ ] WAN cable (WHT-WAN) reaches U5 level with service loop
- [ ] AP cable (WHT-01 AP) reaches U6 level with service loop
- [ ] All five cables secured along one rear edge, not blocking the middle of the rack
- [ ] UPS mains cable (PWR-UPS) accessible at U1
- [ ] Top and bottom openings still have clearance for equipment to slide in

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
> Have a second person help lift the UPS into position. Lifting 15 kg at an awkward angle into a wall-mounted rack is a common cause of dropped equipment and stripped cage nuts.

### 3.2 Insulation — Neoprene 5mm

Place the neoprene pad on top of the UPS in U1, before the NAS goes in. It absorbs vibrations from HDD spindles and provides thermal separation.

### 3.3 U2 — QNAP NAS (TS-435XeU)

1. Slide the NAS into U2
2. Secure with front screws
3. **Do not connect any cables yet** — power and network come in Phase 4

### 3.4 U3 — Rack Power Strip

1. Mount the power strip in U3
2. Route its IEC C14 input cable **downward** to UPS C13 outlet #4
3. Connect the input cable to the UPS — this is a short internal cable so it can be done now

### 3.5 U4 — Patch Panel (Critical Step)

This is the most timing-sensitive installation in the entire build. The upper half of the rack is still empty — use this window to terminate and mount the panel.

**Step A — Terminate on the workbench (not in the rack):**

Only the three 🟢 green room-drop cables get terminated onto the patch panel. The ⚪ white cables (WHT-WAN, WHT-01 AP) stay in the rack — they connect directly to devices later.

1. Pull the three green cables (GRN-01, GRN-02, GRN-03) from their service loops at U4 level out through the top opening with enough slack to reach your workbench
2. For each green cable: strip the jacket → punch down onto a keystone jack (or use toolless keystones) → snap the keystone into the correct panel slot:
   - GRN-01 Studio → slot PP-03
   - GRN-02 Living → slot PP-04
   - GRN-03 Bedroom → slot PP-05
3. Test every terminated port with a cable tester before the panel goes into the rack

> [!TIP]
> Terminating keystones on a flat, well-lit surface is significantly easier than working inside a closed-side rack. This is the single biggest time-saver in the entire build.

**Step B — Mount the panel:**

4. Carefully feed the terminated cables back through the top opening
5. Slide the patch panel into U4 and secure with front screws
6. Dress the rear cables neatly — tuck excess into service loops held with velcro

> [!IMPORTANT]
> **Why now?** The patch panel sits at U4. Above it will be the UDM-SE (U5) and Switch (U6). Once those are installed, the space above U4 is occupied and reaching the patch panel's rear through the top opening becomes very difficult. This is your last comfortable chance to work behind the patch panel.

### 3.6 Checkpoint — Lower Half Complete

Before proceeding to the upper half, verify:

- [ ] UPS seated and secured at U1, mains cable connected (not plugged in)
- [ ] Neoprene insulation in place
- [ ] NAS seated and secured at U2
- [ ] Power strip mounted at U3, connected to UPS
- [ ] Patch panel mounted at U4 with all keystones terminated, tested, and cables dressed
- [ ] Cable bundle is tidy along rear edge, no loose loops hanging

> [!TIP]
> Take a photo of the rear cable routing now. If you ever need to re-terminate a cable, this photo is your reference for how everything was dressed.

### 3.7 U5 — UDM-SE

1. Slide the UDM-SE into U5
2. Secure with front screws
3. Take the ⚪ white WAN cable (**WHT-WAN**, hanging from Phase 2.1 at U5 level) and connect it to the WAN RJ45 port on the UDM-SE rear

### 3.8 U6 — PoE Switch (USW-Pro-Max-16-PoE)

1. Slide the switch into U6
2. Secure with front screws

### 3.9 U7 — Vented Panel

1. Snap/screw the vented panel into U7
2. No cabling required — this is a passive thermal barrier

### 3.10 U8 — Lenovo Mini PC (Proxmox)

1. Place the Mini PC on its shelf/tray at U8
2. Secure if applicable (shelf strap, bracket, or just positioned)

> [!NOTE]
> The Mini PC sits at the top where heat rises and dissipates through the open top. This is intentional — see [Thermal Logic](../network/rack-homelab-config.md#thermal-logic).

---

## Phase 4: Internal Cabling (Front-Access)

All equipment is now installed. The remaining connections are made from the **front** of the rack using short patch cables and power cords.

### 4.1 Power Connections

Connect power cables from the UPS and power strip to each device:

| UPS Outlet | Device | Cable Route |
|-----------|--------|-------------|
| C13 #1 | QNAP NAS (U2) | Short IEC cable, route along side rail upward |
| C13 #2 | UDM-SE (U5) | IEC cable, route along side rail upward |
| C13 #3 | PoE Switch (U6) | IEC cable, route along side rail upward |
| C13 #4 | Power Strip (U3) | Already connected in Phase 3.4 |

| Power Strip Outlet | Device | Notes |
|-------------------|--------|-------|
| Schuko #1 | Lenovo Mini PC (U8) | External power supply brick |

> [!TIP]
> Route power cables along one side rail and network cables along the other. This reduces electromagnetic interference and makes troubleshooting easier.

### 4.2 Network Backbone (SFP+ 10GbE)

Connect the high-speed backbone using DAC (Direct Attach Copper) or SFP+ transceivers + fiber:

| Connection | From | To |
|-----------|------|-----|
| 10GbE Link 1 | UDM-SE LAN SFP+ (U5) | Switch SFP+ Port 1 (U6) |
| 10GbE Link 2 | Switch SFP+ Port 2 (U6) | QNAP NAS SFP+ Port 1 (U2) |

> [!NOTE]
> The NAS SFP+ cable runs from U6 down to U2 — this is the longest internal cable. Use a 1m DAC cable and route it along the side rail to keep it tidy.

### 4.3 Front Patch Cables (Patch Panel → Switch)

These are **separate pre-made 🟢 green cables** (~30 cm) — not the in-wall runs. They bridge the **front** of the patch panel (U4) **up** to the switch (U6), completing the room-to-switch path.

| Patch Cable Label | From | To | VLAN |
|-------------------|------|----|------|
| GRN-01 Studio | PP-03 front (U4) | Switch Port 3 (U6) | Media (4) |
| GRN-02 Living | PP-04 front (U4) | Switch Port 4 (U6) | Media (4) |
| GRN-03 Bedroom | PP-05 front (U4) | Switch Port 5 (U6) | Media (4) |

Use **~30 cm** patch cables. The patch panel (U4) and switch (U6) are 2U apart with the UDM-SE between them — keep cables short to avoid clutter.

> [!NOTE]
> The full signal path for each room is now: **room wall plate → 🟢 green in-wall cable → patch panel rear keystone → patch panel front port → 🟢 green patch cable → switch port**.

### 4.4 Remaining Ethernet Connections

| Label | Color | From | To | Notes |
|-------|-------|------|-----|-------|
| WHT-01 AP | ⚪ White | Switch Port 2 (U6) | Top opening → ceiling AP | Routed in Phase 2.1, now plug the rack-end into the switch |
| BLK-01 Proxmox | ⚫ Black | Mini PC (U8) | Switch port or UDM-SE LAN | Short internal cable, does not leave the rack |

### 4.5 Cable Management Final Pass

1. Bundle front-facing patch cables with velcro straps
2. Ensure no cables obstruct the vented panel (U7) airflow
3. Verify no cables are pinched, kinked, or under tension
4. Confirm all labels are visible from the front

---

## Phase 5: Power On & Verification

### 5.1 Power-On Sequence

Power on devices in this order, waiting for each to fully boot before starting the next:

| Step | Action | Wait For |
|------|--------|----------|
| 1 | Plug UPS mains cable into wall outlet | UPS LCD shows "Online", battery charging indicator |
| 2 | Power on UDM-SE | White status LED steady (boot takes ~3–5 min) |
| 3 | Power on PoE Switch | Status LED steady, PoE ports energize |
| 4 | Power on QNAP NAS | System ready beep, LCD shows IP |
| 5 | Power on Mini PC | Proxmox boot to login prompt |

> [!IMPORTANT]
> Power on the UDM-SE and switch **before** the NAS. The NAS needs a working network to obtain its IP and become reachable. The Mini PC (Plex) depends on the NAS media shares being available.

### 5.2 Verification Checklist

- [ ] UPS shows all outlets active, battery status healthy
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
│ ✦ Dry-fit equipment     │      │   through BOTTOM opening│
└─────────────────────────┘      └─────────────────────────┘
            │                                │
            ▼                                ▼
PHASE 3 — INSTALL BOTTOM → UP   PHASE 4 — CABLE FROM FRONT
┌─────────────────────────┐      ┌─────────────────────────┐
│ U1  UPS ............. ① │      │ ✦ Power cables (UPS →   │
│ ░░  Neoprene ........ ② │      │   devices)              │
│ U2  NAS ............. ③ │      │ ✦ SFP+ backbone         │
│ U3  Power Strip ..... ④ │      │ ✦ Patch cables (PP →    │
│ U4  Patch Panel ..... ⑤ │      │   switch, short ~30cm)  │
│  ► TERMINATE + MOUNT ◄  │      │ ✦ AP & Mini PC ethernet │
│ U5  UDM-SE .......... ⑥ │      │ ✦ Cable dress & labels  │
│ U6  Switch .......... ⑦ │      └─────────────────────────┘
│ U7  Vented Panel .... ⑧ │                  │
│ U8  Mini PC ......... ⑨ │                  ▼
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
| Cable won't reach patch panel rear | Insufficient service loop | Pull more slack through top opening; may need to remove upper equipment temporarily |
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
