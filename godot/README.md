# O.A.S.I.S. Godot Plugin

OCP (O.A.S.I.S. Communications Protocol) plugin for Godot 4.5. Enables any Godot
scene to participate as a first-class peer on the O.A.S.I.S. network.

> **Repository name is temporary** pending the project lead's naming decision.

## What This Is

A reusable Godot plugin (`addons/oasis_ocp/`) that provides:

- **MQTTBridge** — WebSocket-based MQTT v3.1.1 client (connects to Mosquitto's
  WebSocket listener, no external dependencies)
- **OCPMessage** — OCP message builder/parser with E1–E5 embodiment support
- **OCPPeer** — Attach to any Node to make it an OCP peer (status heartbeat,
  command subscription, discovery, inhabitation events)
- **OasisMQTT autoload** — Global MQTT connection manager and peer registry

Plus two runnable demos:

| Demo | What it shows |
|------|--------------|
| `demos/oasis_monitor/` | Three-layer architecture visualization (Device, Network, Platform) with animated OCP message traffic |
| `demos/e3_character/` | A game character that is a first-class OCP peer — navigates, publishes virtual sensors, can be inhabited |

## Quick Start

### Prerequisites

- [Godot 4.5](https://godotengine.org/download) (gl_compatibility renderer)
- [Mosquitto MQTT broker](https://mosquitto.org/) with WebSocket listener enabled

### Mosquitto Configuration

Add WebSocket support to your `mosquitto.conf`:

```
listener 1883
protocol mqtt

listener 9001
protocol websockets

allow_anonymous true
```

### Run the Demo

```bash
# Terminal 1: Start MQTT broker
mosquitto -c /path/to/mosquitto.conf

# Terminal 2: Start ECHO simulation stack (optional — provides mock peers)
cd /path/to/the-oasis-project-simulation-repo
pip install -e ".[all]"
python -m simulation.demo  # (when available)

# Terminal 3: Open in Godot
cd the-oasis-project-godot-plugin-repo
godot --path . --editor  # or just double-click project.godot
# Press F5 to run
```

Or use the launcher script:

```bash
./launch_demo.sh
```

### Use the Plugin in Your Own Project

Copy `addons/oasis_ocp/` into your Godot project's `addons/` directory, then
enable the plugin in Project → Project Settings → Plugins.

```gdscript
# Any scene — make a node an OCP peer
var peer = OCPPeer.new()
peer.peer_id = "my-custom-peer"
peer.component_name = "custom"
peer.embodiment_type = OCPMessage.EmbodimentType.E3_DIGITAL
peer.capabilities = PackedStringArray(["sensor_display", "navigation"])
add_child(peer)

# Listen for commands
peer.command_received.connect(func(action, params):
    print("Received command: %s %s" % [action, params])
)

# Send a command to another peer
peer.send_command("dawn", "process_intent", {"text": "turn on the lights"})
```

## Architecture

```
addons/oasis_ocp/           # ← The reusable plugin
├── plugin.cfg              # Godot plugin manifest
├── oasis_ocp_plugin.gd     # Editor plugin (registers OCPPeer custom type)
├── mqtt_bridge.gd          # MQTT v3.1.1 over WebSocket
├── ocp_message.gd          # OCP message builder/parser (E1-E5 embodiment)
├── ocp_peer.gd             # OCP peer component (attach to any Node)
└── oasis_mqtt_autoload.gd  # Global MQTT connection singleton

demos/
├── oasis_monitor/          # Three-layer architecture visualization
│   ├── scenes/             # .tscn scene files
│   ├── scripts/            # Panel controllers
│   └── resources/          # Theme, fonts, materials
└── e3_character/           # E3 digital peer (game character as OCP peer)
    ├── scenes/             # Character scene, game world
    └── scripts/            # Avatar controller with navigation
```

### How It Connects to O.A.S.I.S.

```
┌─────────────────────┐     ┌─────────────────────┐
│  This Godot Plugin  │     │  ECHO Simulation     │
│                     │     │  Framework           │
│  OCPPeer nodes      │     │  Device/Network/     │
│  E3 avatars         │     │  Platform layers     │
│  Visualization      │     │  Mock sensors        │
└────────┬────────────┘     └────────┬────────────┘
         │                           │
         │    WebSocket (port 9001)  │  MQTT (port 1883)
         │                           │
         └──────────┬────────────────┘
                    │
           ┌────────▼────────┐
           │  Mosquitto MQTT │
           │  Broker         │
           └────────┬────────┘
                    │
         ┌──────────┴──────────┐
         │                     │
    ┌────▼─────┐        ┌─────▼────┐
    │  D.A.W.N.│        │ Physical │
    │  (real   │        │ Hardware │
    │   or     │        │ (Jetson, │
    │   mock)  │        │  RPi)    │
    └──────────┘        └──────────┘
```

The plugin connects via WebSocket to the same MQTT broker that all O.A.S.I.S.
components use. It publishes and subscribes to the same OCP topics with the
same JSON schemas. From the broker's perspective, a Godot OCPPeer is
indistinguishable from a real hardware component.

## OCP Embodiment Types

| Type | Name | Plugin Support |
|------|------|---------------|
| E1 | Physical | Read-only (observe hardware peers) |
| E2 | Remote-Physical | Read-only (observe remote-controlled peers) |
| E3 | Digital/Virtual | **Full** — game characters, avatars, simulated peers |
| E4 | Software-Only | **Full** — service peers, infrastructure nodes |
| E5 | Hybrid | Partial (via Provider pattern, future work) |

## Cross-Platform Export

The plugin uses only Godot built-in APIs (WebSocketPeer, JSON, Node). No
external libraries or platform-specific code. It exports to every target
Godot 4.5 supports:

Windows · macOS · Linux · Android · iOS · HTML5/Web · Steam Deck ·
Nintendo Switch* · PlayStation* · Xbox*

*Console exports require W4 Games publishing partnership.

## Related Repositories

| Repository | Role |
|-----------|------|
| [the-oasis-project-simulation-repo](https://github.com/malcolmhoward/the-oasis-project-simulation-repo) | ECHO simulation framework (Device/Network/Platform layers) |
| [the-oasis-project-meta-repo](https://github.com/malcolmhoward/the-oasis-project-meta-repo) | S.C.O.P.E. coordination, ADRs, getting-started guides |
| [The-OASIS-Project/dawn](https://github.com/The-OASIS-Project/dawn) | D.A.W.N. — Digital Assistant for Workflow Neural-inference |
| [The-OASIS-Project/mirage](https://github.com/The-OASIS-Project/mirage) | M.I.R.A.G.E. — Heads-Up Display system |

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for the fork-first workflow,
branch naming conventions, and code review process.

## License

GPL-3.0. This project is part of the O.A.S.I.S. ecosystem; all O.A.S.I.S.
component repositories use the GNU General Public License v3.0.
See [LICENSE](LICENSE).
