# O.A.S.I.S. Game Engine Plugin Repository

> Temporary name — pending official O.A.S.I.S. acronym from the project lead

## Description

OCP (O.A.S.I.S. Communication Protocol) integration plugins for real-time game and rendering engines. Each engine has its own subdirectory with a self-contained plugin and demos.

| Engine | Status | Path |
|---|---|---|
| **Godot 4.5** | Scaffold complete (23 files, 1,827 lines) | [`godot/`](godot/) |
| Unreal | Planned | `unreal/` |
| Unity | Planned | `unity/` |

## Why This Project?

O.A.S.I.S. components communicate over MQTT using OCP. Game engines can participate on this same network as E3 (digital/virtual) peers — subscribing to sensor data, publishing status, and hosting virtual avatars that are indistinguishable from physical peers on the wire. This enables:

- **Visualization**: Real-time architecture monitoring of the O.A.S.I.S. network
- **Digital peers**: Game characters that participate in OCP as E3 entities
- **Accessibility**: Contributors can interact with the ecosystem visually without hardware
- **Demonstration**: Live demos for presentations and events

## Architecture

Each engine plugin implements the same OCP interface:

- **MQTT Bridge**: Connects to the O.A.S.I.S. MQTT broker via WebSocket
- **OCP Message**: Builds and parses OCP-formatted messages with E1-E5 embodiment
- **OCP Peer**: Attaches to any engine entity, making it a first-class OCP peer
- **Autoload/Singleton**: Global MQTT connection and peer registry

The protocol is identical across engines. An OCP peer in Godot and an OCP peer in Unreal are indistinguishable on the MQTT network.

## Demos and Tools

The Godot plugin ships with several runnable demos:

- **Architecture Monitor** (`godot/demos/oasis_monitor/`) — Three-layer visualization of live Device/Network/Platform OCP traffic
- **E3 Character** (`godot/demos/e3_character/`) — 3D avatar that is a first-class OCP peer on the MQTT network
- **D.A.W.N. UI** (`godot/demos/dawn_ui/`) — Interactive UI for the D.A.W.N. assistant
- **Presentation Engine** (`godot/scenes/demos/demo_presentation/`) — Reusable, manifest-driven presentation system with morph transitions and reusable visualizations (embodiment spectrum, provider diagram)
- **Audio Monitor** (`godot/scenes/audio_monitor.tscn`) — Audio input monitor demonstrating Provider pattern hot-swap

Development tools:

- **Mock OCP Traffic** (`tools/mock_ocp_traffic.py`) — Generates simulated OCP messages for Docker-free development and testing

## Quick Start

See [`godot/README.md`](godot/README.md) for Godot-specific setup and demo instructions.

## Related O.A.S.I.S. Components

| Component | Relationship |
|---|---|
| [E.C.H.O.](https://github.com/malcolmhoward/the-oasis-project-simulation-repo) | Generates mock sensor data consumed by engine plugins |
| [S.C.O.P.E.](https://github.com/malcolmhoward/the-oasis-project-meta-repo) | ADRs, coordination, dependency tracking |
| [D.A.W.N.](https://github.com/The-OASIS-Project/dawn) | AI assistant — LLM reasoning engine that drives OCP peers |
| [M.I.R.A.G.E.](https://github.com/The-OASIS-Project/mirage) | HUD overlay — helmet display system |

## Contributing

Please see [godot/CONTRIBUTING.md](godot/CONTRIBUTING.md) for Godot plugin guidelines. For ecosystem-wide coordination, see [S.C.O.P.E.](https://github.com/malcolmhoward/the-oasis-project-meta-repo).

## License

GPL-3.0 — see [LICENSE](LICENSE).

## Security

For security concerns, please open a private issue or contact the maintainers via the [O.A.S.I.S. meta-repository](https://github.com/malcolmhoward/the-oasis-project-meta-repo).

---

*Part of the [O.A.S.I.S. Project](https://github.com/The-OASIS-Project). Generated with [Project Foundation Template](https://github.com/malcolmhoward/project-foundation-template).*
