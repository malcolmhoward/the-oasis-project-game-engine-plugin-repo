# O.A.S.I.S. Godot Plugin — Dependency Map

## Runtime Dependencies

| Dependency | Required | Purpose |
|-----------|----------|---------|
| Mosquitto MQTT Broker | Yes | OCP message transport |
| WebSocket listener (port 9001) | Yes | Godot ↔ MQTT bridge |

## Development Dependencies

| Dependency | Required | Purpose |
|-----------|----------|---------|
| Godot 4.5+ | Yes | Engine |
| ECHO Simulation Framework | Recommended | Provides mock OCP peers for testing |
| D.A.W.N. | Optional | Real AI assistant integration |

## Ecosystem Dependencies

| Component | Relationship |
|-----------|-------------|
| ECHO (simulation-repo) | Provides mock peers; plugin observes their MQTT traffic |
| D.A.W.N. | Plugin can embed or link to DAWN's web UI |
| S.C.O.P.E. (meta-repo) | Coordination, ADRs, getting-started guides |
| OCP Spec (in DAWN repo) | Defines message schemas the plugin implements |

## Dependency Direction

```
This Plugin ──reads──► OCP Spec (DAWN repo)
This Plugin ──observes──► ECHO mock peers (MQTT)
This Plugin ──observes──► Real hardware peers (MQTT)
This Plugin ──links to──► DAWN Web UI (HTTP, optional)
S.C.O.P.E. ──coordinates──► This Plugin (docs, ADRs)
```

The plugin has NO compile-time dependency on any O.A.S.I.S. component.
All integration happens at runtime via MQTT.
