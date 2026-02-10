# Homelab Simulation Tools for Students

A free, 3-tool approach for students to simulate building and configuring a homelab — from networking fundamentals through infrastructure-as-code — without any physical hardware.

---

## Recommended 3-Tool Stack (All Free)

| Tool | Cost | Role in the Stack | Best For |
|---|---|---|---|
| **Cisco Packet Tracer** | Free (NetAcad account) | Networking fundamentals | Learning L2/L3 concepts, VLANs, routing basics |
| **GNS3** | Free & open source | Full network + service emulation | Multi-vendor labs, connecting VMs, firewall configs |
| **Containerlab** | Free & open source | Infrastructure-as-code networking | Automation, DevOps workflows, large topologies |

---

## Phase 1: Foundations with Cisco Packet Tracer

**Goal:** Learn networking concepts before touching real infrastructure.

### What to Practice

- VLANs and trunking (maps to a homelab's VLAN design)
- Inter-VLAN routing (the basis for homelab firewall rules)
- DNS, DHCP, NAT (fundamentals behind every homelab)
- Basic firewall ACLs

### Why Packet Tracer for This Phase

It's purpose-built for learning. The GUI is drag-and-drop, simulated devices behave predictably, and there are hundreds of free labs on [Cisco Networking Academy](https://www.netacad.com/learning-collections/cisco-packet-tracer). No image licensing headaches, no resource tuning — just concepts.

### Limitations

Packet Tracer is a *simulator* (simplified models), not an *emulator* (real OS). You'll outgrow it for anything beyond CCNA-level work.

### How to Get It

Create a free account at [netacad.com](https://www.netacad.com) and download Packet Tracer.

---

## Phase 2: Realistic Multi-Vendor Labs with GNS3

**Goal:** Emulate the actual network infrastructure that a homelab sits on.

### What to Practice

- Build a virtual version of a homelab's network topology (router, switches, VLANs)
- Practice firewall rule chains with real router/firewall images
- Connect GNS3 to Docker containers and VMs running on the same host
- Test inter-VLAN traffic flows end-to-end

### Why GNS3 for This Phase

It runs *real* network OS images (not simulations), has a GUI for visual topology building, and can bridge to your host network — meaning you can connect GNS3's virtual network to Docker containers running on the same machine. The `.gns3project` format makes it easy to share and distribute lab files to students.

### Free Router/Firewall Images

| Image | Type | Use Case |
|---|---|---|
| **[FRRouting (FRR)](https://frrouting.org/)** | Docker container | OSPF, BGP, routing |
| **[VyOS](https://vyos.io/)** (rolling/nightly builds) | VM or container | Full router + firewall + VPN |
| **Open vSwitch** | Docker container | SDN / VLAN switching |

### Limitations

GNS3 uses VMs under the hood, so it gets heavy past ~20-30 nodes. Setup can be finicky on some systems.

### How to Get It

Download from [gns3.com](https://www.gns3.com/). GNS3 is 100% free and open source.

---

## Phase 3: Infrastructure-as-Code with Containerlab

**Goal:** Simulate the *operational* side of a homelab — defining, versioning, and automating infrastructure.

### What to Practice

- Define network topologies in YAML (mirrors how a real homelab uses Docker Compose)
- Spin up 50+ routers in seconds with FRR containers (~50MB each)
- Practice automation with Ansible against the virtual topology
- Version-control your lab definitions in Git

### Why Containerlab for This Phase

It's the only tool in this stack that teaches the *DevOps/IaC mindset* — topologies are code, labs are reproducible, and it integrates natively with Git, CI/CD, and Ansible. A student who learns Containerlab is practicing the same workflow as managing a real homelab repository.

### Example Topology File

```yaml
name: homelab-sim
topology:
  nodes:
    router:
      kind: linux
      image: frrouting/frr:latest    # Free, no license needed
    nas-switch:
      kind: linux
      image: frrouting/frr:latest
    iot-switch:
      kind: linux
      image: frrouting/frr:latest
  links:
    - endpoints: ["router:eth1", "nas-switch:eth1"]
    - endpoints: ["router:eth2", "iot-switch:eth1"]
```

### Free Container Images

| Image | Source | Notes |
|---|---|---|
| **[FRRouting](https://hub.docker.com/r/frrouting/frr)** | Docker Hub (auto-download) | Easiest to get started |
| **[Nokia SR Linux](https://containerlab.dev/)** | Free community images | Feature-rich |
| **Cumulus VX** | NVIDIA container registry | Data center networking |

### Limitations

CLI only (no GUI for topology visualization). L2/switching simulation is weaker than GNS3.

### How to Get It

Install from [containerlab.dev](https://containerlab.dev/). See also [free Containerlab labs with FRR](https://github.com/ciscoittech/containerlab-free-labs) for ready-made exercises.

---

## How the Three Tools Connect

```
Student Journey:

  Packet Tracer          GNS3              Containerlab
  ─────────────    ───────────────    ──────────────────
  "What is a       "How does a        "How do I manage
   VLAN?"           real firewall       infrastructure
                    process rules?"     as code?"

  Concepts    ──>  Realism       ──>  Automation
  (simulate)       (emulate)          (orchestrate)
```

Each phase builds on the previous:

1. **Packet Tracer** teaches *what* VLANs, routing, and firewalls are
2. **GNS3** teaches *how* real network devices implement them
3. **Containerlab** teaches *how to manage and automate* them at scale

---

## Quick Reference: Free Tier Comparison

| Tool | Free Version | Node/Resource Limits | Interface |
|---|---|---|---|
| **Cisco Packet Tracer** | Full (free NetAcad account) | Unlimited (simulated) | GUI |
| **GNS3** | Full (open source) | Hardware-bound (~20-30 practical) | GUI |
| **Containerlab** | Full (open source) | Hardware-bound (very lightweight) | CLI |
| **EVE-NG Community** | Limited | 63 nodes, 1 user, no hot-linking | Web GUI |

> **Note on EVE-NG:** The Community edition's 63-node cap and single-user restriction make it the weakest free option. The three-tool combo above covers the full learning spectrum without those artificial limits.

---

## Suggested Hardware Requirements

All three tools run on a standard laptop:

| Setup | RAM | Storage | Notes |
|---|---|---|---|
| Packet Tracer only | 4 GB | 1 GB | Runs on almost anything |
| GNS3 (small labs) | 8 GB | 20 GB | Needs VirtualBox or VMware |
| Containerlab + FRR | 8 GB | 5 GB | Docker only, very lightweight |
| All three combined | 16 GB | 30 GB | Recommended for the full stack |

---

## Additional Resources

- [Cisco Networking Academy - Free Packet Tracer Labs](https://www.netacad.com/learning-collections/cisco-packet-tracer)
- [GNS3 Documentation & Community](https://docs.gns3.com/)
- [Containerlab Documentation](https://containerlab.dev/)
- [Free Containerlab Labs (FRR-based)](https://github.com/ciscoittech/containerlab-free-labs)
- [FRRouting Project](https://frrouting.org/)
- [VyOS Open Source Router](https://vyos.io/)
- [Containerlab with Open-Source Routers (Brian Linkletter)](https://brianlinkletter.com/2021/05/use-containerlab-to-emulate-open-source-routers/)
