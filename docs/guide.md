# O.A.S.I.S. Game Engine Plugin — Godot 4.5

> **Naming note**: This repository uses a temporary name pending the project lead's selection.

## Overview

The Godot OCP plugin enables any Godot 4.5 project to participate on the O.A.S.I.S. MQTT (Message Queuing Telemetry Transport) network. Game scenes can subscribe to real-time sensor data, publish OCP (OASIS Communications Protocol) status messages, and host virtual avatars that are first-class peers on the same network as physical O.A.S.I.S. hardware.

The plugin registers game engine entities as E3 (digital/virtual) peers per the OCP embodiment spectrum (ADR-0003 Amendment 5). A Godot character publishing to `oasis/<peer_id>/status` is indistinguishable from M.I.R.A.G.E. on a Jetson to any MQTT subscriber.

## Software Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| Godot Engine | 4.5+ | Game engine runtime |
| Mosquitto | 2.x | MQTT broker (WebSocket listener on port 9001) |

No external GDScript libraries required — the MQTT client (`mqtt_bridge.gd`) implements MQTT v3.1.1 packet encoding over WebSocket natively.

Optional:
| Package | Purpose |
|---------|---------|
| [E.C.H.O.](https://github.com/malcolmhoward/the-oasis-project-simulation-repo) | Provides mock sensor data for testing without hardware |
| Docker | Runs Mosquitto broker and E.C.H.O. mock services |

## Installation

### As a Godot Addon

1. Copy `godot/addons/oasis_ocp/` into your Godot project's `addons/` directory
2. Open Project → Project Settings → Plugins
3. Enable "O.A.S.I.S. OCP" plugin
4. The `OasisMQTTAutoload` singleton is added automatically

### From This Repository

```bash
git clone https://github.com/malcolmhoward/the-oasis-project-game-engine-plugin-repo.git
cd the-oasis-project-game-engine-plugin-repo/godot
# Open in Godot 4.5 editor
```

## Configuration

### MQTT Broker

The plugin connects via WebSocket. Configure Mosquitto with:

```
# mosquitto.conf
listener 1883
listener 9001
protocol websockets
allow_anonymous true
```

Start the broker:
```bash
docker run -d -p 1883:1883 -p 9001:9001 \
  -v ./mosquitto.conf:/mosquitto/config/mosquitto.conf:ro \
  eclipse-mosquitto:2
```

### Plugin Settings

The `OasisMQTTAutoload` singleton reads connection settings from the autoload script. Default: `ws://localhost:9001`.

## Usage

### Minimal OCP Peer

```gdscript
extends Node3D

var peer: OCPPeer

func _ready():
    peer = OCPPeer.new()
    peer.peer_id = "my-godot-character"
    peer.component_name = "game"
    peer.embodiment_type = "E3"
    add_child(peer)

    peer.message_received.connect(_on_message)
    peer.subscribe("oasis/+/status")

func _on_message(topic: String, data: Dictionary):
    print("Received: ", topic, " → ", data)
```

### Subscribing to E.C.H.O. Sensor Data

```gdscript
# Subscribe to simulated AURA sensor data
peer.subscribe("aura")

func _on_message(topic: String, data: Dictionary):
    if data.get("device") == "Motion":
        var heading = data.get("heading", 0.0)
        var pitch = data.get("pitch", 0.0)
        # Update 3D character rotation from simulated IMU
        rotation_degrees = Vector3(pitch, heading, 0)
```

## Demo Scenes

### oasis_monitor — Architecture Visualization

Displays the three-layer E.C.H.O. architecture (Device/Network/Platform) with live MQTT traffic:

- **Device zone**: Sensor gauges updating from `aura` and `stat` topics
- **Network zone**: Animated MQTT packet flow showing OCP messages
- **Platform zone**: D.A.W.N. mock reasoning pipeline status

### e3_character — 3D Digital Peer

A 3D avatar that is a live OCP E3 peer:

- Publishes `oasis/e3-avatar/status` with standard OCP schema
- Responds to commands on its subscription topics
- Visible in the `oasis_monitor` peer status panel

## Communication

### MQTT Topics (OCP)

| Topic Pattern | Direction | Purpose |
|---------------|-----------|---------|
| `oasis/<peer_id>/status` | Publish | E3 peer status and heartbeat |
| `<component>/discovery/<capability>` | Publish | Peer capability discovery |
| `echo/discovery/simulates` | Publish | Identifies this peer as digital/virtual |
| `aura` | Subscribe | A.U.R.A. sensor telemetry (or E.C.H.O. mock) |
| `stat` | Subscribe | S.T.A.T. system metrics (or E.C.H.O. mock) |
| `hud/status` | Subscribe | M.I.R.A.G.E. HUD status |
| `dawn` | Subscribe | D.A.W.N. AI state and commands |

## Troubleshooting

### MQTT Connection Failed

**WebSocket connection refused on port 9001**
Ensure Mosquitto is running with WebSocket listener enabled. Check `mosquitto.conf` includes `listener 9001` and `protocol websockets`.

### No Messages Received

**Subscribed but no data appearing**
- Verify E.C.H.O. or another publisher is running on the same broker
- Check topic patterns match (case-sensitive)
- Use `mosquitto_sub -t '#' -v` to verify traffic exists on the broker

### Godot Editor Errors on Open

**GDScript parse errors or missing nodes**
The scaffold was generated without running in the Godot editor. Expect initial fixes needed for syntax and node references. See issue #4 for tracking.

## Related Components

| Component | Relationship |
|-----------|-------------|
| [E.C.H.O.](https://github.com/malcolmhoward/the-oasis-project-simulation-repo) | Provides mock sensor data for all three layers |
| [M.I.R.A.G.E.](https://github.com/The-OASIS-Project/mirage) | HUD display — game scene can mirror HUD state |
| [D.A.W.N.](https://github.com/The-OASIS-Project/dawn) | AI assistant — drives E3 avatar via OCP commands |
| [S.C.O.P.E.](https://github.com/malcolmhoward/the-oasis-project-meta-repo) | Ecosystem coordination, ADRs, standards |
