# CLAUDE.md - LLM Integration Guide

## Project Overview

This repository contains OCP (OASIS Communications Protocol) plugins for game engines, starting with Godot 4.5. The plugins enable game engine scenes to participate on the O.A.S.I.S. MQTT (Message Queuing Telemetry Transport) network as E3 (digital/virtual) peers — subscribing to sensor data, publishing status, and hosting virtual avatars that are indistinguishable from physical peers on the wire.

The repository is structured for multiple engines:

```
godot/          Godot 4.5 OCP plugin + demos (current)
unreal/         Future: Unreal OCP plugin
unity/          Future: Unity OCP integration
coordination/   Cross-engine design decisions
```

> **Naming note**: This repository uses a temporary name pending the project lead's selection of an official O.A.S.I.S. acronym. See ADR-0007 in S.C.O.P.E. for the naming convention.

## Godot Plugin Architecture

### Key Files

| File | Purpose |
|------|---------|
| `godot/addons/oasis_ocp/mqtt_bridge.gd` | MQTT v3.1.1 WebSocket client (connects to broker on port 9001) |
| `godot/addons/oasis_ocp/ocp_peer.gd` | OCP peer node — status, discovery, heartbeat, embodiment |
| `godot/addons/oasis_ocp/ocp_message.gd` | Message data class with topic builders and JSON serialization |
| `godot/addons/oasis_ocp/oasis_mqtt_autoload.gd` | Singleton autoload — auto-connects to broker on project start |
| `godot/addons/oasis_ocp/plugin.cfg` | Godot addon metadata |
| `godot/project.godot` | Project configuration (gl_compatibility renderer) |

### Demo Scenes

| Scene | Purpose |
|-------|---------|
| `godot/demos/oasis_monitor/` | Architecture visualization — three-layer view of Device/Network/Platform traffic |
| `godot/demos/e3_character/` | 3D game scene with avatar that is an E3 OCP peer |

## OCP Integration

The plugin implements the same OCP protocol as physical O.A.S.I.S. components:

- Same MQTT topics (`oasis/<peer_id>/status`, `<component>/discovery/<capability>`)
- Same JSON schemas (status, discovery, command/response)
- Same heartbeat cadence (30-second interval, 90-second timeout)
- Same LWT (Last Will and Testament) for offline detection

Game engine peers register as E3 (digital/virtual) embodiment type per ADR-0003 Amendment 5.

## Working with This Codebase

### MQTT Broker Requirement

The plugin connects via WebSocket (port 9001 by default). Mosquitto must be configured with:

```
listener 9001
protocol websockets
```

### GDScript Conventions

- All OCP classes extend `Node` or `RefCounted`
- Signals are used for async MQTT message delivery
- The `OasisMQTTAutoload` singleton manages the single broker connection
- Individual `OCPPeer` nodes subscribe to their own topics via the singleton

### Adding a New Engine Plugin

1. Create a directory at the repo root (e.g., `bevy/`)
2. Implement the OCP peer protocol for that engine's networking model
3. Add cross-engine design decisions to `coordination/`
4. Update the root `README.md` with the new engine

## O.A.S.I.S. Component Interaction

| Component | Interaction | Direction |
|-----------|------------|-----------|
| M.I.R.A.G.E. | Receives HUD status; game scene can mirror HUD state | Subscribe |
| D.A.W.N. | Receives AI state updates; E3 avatar responds to commands | Subscribe + Publish |
| A.U.R.A. | Receives sensor telemetry; visualized as gauges in monitor | Subscribe |
| S.P.A.R.K. | Receives armor status; visualized in monitor | Subscribe |
| S.T.A.T. | Receives system metrics; visualized in monitor | Subscribe |
| E.C.H.O. | Receives mock sensor data; same topics as real components | Subscribe |
| S.C.O.P.E. | Receives coordination messages; OCP peer discovery | Subscribe + Publish |

## Branch Naming Convention

```
feat/plugin/<issue#>-<description>
```

Always verify the issue number with `gh issue list` before creating a branch.

---

*For contribution guidelines, see [godot/CONTRIBUTING.md](godot/CONTRIBUTING.md).*
*For ecosystem coordination, see [S.C.O.P.E.](https://github.com/malcolmhoward/the-oasis-project-meta-repo).*
