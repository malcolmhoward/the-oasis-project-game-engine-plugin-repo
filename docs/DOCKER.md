# Docker Guide

## Overview

The game engine plugin is primarily used inside the Godot editor, not in a container. Docker is used for:

- Running the MQTT broker (Mosquitto) for development
- Running E.C.H.O. mock services alongside the Godot editor
- Future: headless Godot CI testing of the MQTT bridge and OCP peer logic

## MQTT Broker for Development

```bash
# Start Mosquitto with WebSocket support
docker run -d --name oasis-mqtt -p 1883:1883 -p 9001:9001 \
  eclipse-mosquitto:2 sh -c \
  'echo "listener 1883\nlistener 9001\nprotocol websockets\nallow_anonymous true" > /mosquitto/config/mosquitto.conf && mosquitto -c /mosquitto/config/mosquitto.conf'
```

The Godot plugin connects to `ws://localhost:9001` by default.

## Running with E.C.H.O. Simulation

For full ecosystem simulation (mock sensors + mock services), use the ecosystem demo from S.C.O.P.E.:

```bash
# From the meta-repo
docker compose -f demos/ecosystem-mock/docker-compose.demo.yaml up -d

# Then open the Godot project — it connects to the same broker on port 9001
```

See the [ecosystem demo README](https://github.com/malcolmhoward/the-oasis-project-meta-repo/tree/feat/scope/40-ecosystem-demo/demos/ecosystem-mock) for details.
