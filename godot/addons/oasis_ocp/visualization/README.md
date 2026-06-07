# OCP Topology Visualizer

Reusable Godot scene that renders a live OCP message-flow topology from
a JSON config. Subscribes to MQTT through the `OasisMQTT` autoload and
animates message particles along configured edges as traffic arrives.

The addon owns **only the topology rendering** (nodes, edges, particles,
pulse decay, `$SYS`-driven node health). Demo widgets — info panels,
control toggles, command injectors — layer on top as siblings of the
overlay and consume the signals it emits.

## Files

```
ocp_topology_overlay.tscn   # Reusable Control scene — drop into any layout
ocp_topology_overlay.gd     # Subscribes to MQTT, drives edge + node state
topology_node.gd            # Single labeled node with status + pulse
topology_edge.gd            # Directed edge with envelope particles
configs/
├── mirage_demo.json        # 3-node mock → broker → Godot (mirrors the original architecture_live)
├── dawn_demo.json          # Chat-focused: Godot ↔ broker ↔ DAWN backend
├── full_ecosystem.json     # All O.A.S.I.S. components on one broker
└── debug_all.json          # Single wildcard edge — "did any message arrive at all?"
```

## Embedding

Add `ocp_topology_overlay.tscn` as a child of any `Control`. Set its
`config_path` to one of the JSON configs (or your own):

```tscn
[ext_resource type="PackedScene" path="res://addons/oasis_ocp/visualization/ocp_topology_overlay.tscn" id="1"]

[node name="Topology" parent="." instance=ExtResource("1")]
```

```gdscript
@onready var topology = $Topology

func _ready():
    topology.config_path = "res://addons/oasis_ocp/visualization/configs/mirage_demo.json"
    topology.load_config(topology.config_path)
```

`load_config()` may be called at runtime to swap topologies.

## Config schema

```json
{
  "title": "<topology name>",
  "description": "<optional human-readable explanation>",
  "palette": {
    "MY_COLOR": "#abcdef"
  },
  "nodes": [
    {
      "id": "node-id",
      "label": "Display Name",
      "subtitle": "(extra context, optional)",
      "position": [x_pct, y_pct],
      "size": [w_pct, h_pct],
      "role": "mock | broker | consumer | real_source",
      "color": "ACCENT",
      "online_indicator": "always | mqtt_connected | topic_seen:<pattern>"
    }
  ],
  "edges": [
    {
      "from": "node-id",
      "to": "other-node-id",
      "label": "Display Label",
      "topics": ["<topic-pattern>", "..."]
    }
  ],
  "topic_colors": [
    {"pattern": "<topic-pattern>", "color": "ACCENT"}
  ]
}
```

### Positions and sizes

All positions and sizes are percentages of the parent overlay rect
(0.0–1.0), so the same config works at any viewport size. The overlay
listens for `resized` and re-lays out children automatically.

### Topic patterns

MQTT-style:

- `exact` — exact match (`aura`, `dawn/cmd`)
- `+` — single-level wildcard (`dawn/+` matches `dawn/cmd`, `dawn/events`)
- `#` — multi-level wildcard (`dawn/#` matches `dawn`, `dawn/cmd/xyz`)
- `*/<suffix>` — suffix wildcard (`*/status` matches `aura/status`, `stat/status`)

A message is routed to every edge whose `topics` array contains a
matching pattern.

### Colors

Color names are resolved via the built-in palette plus any overrides
supplied in the config's `palette` block. You may also use hex codes
inline (e.g. `"color": "#2dd4bf"`). The built-in palette includes:

```
MOCK, BROKER, GODOT, CONSUMER, LIVE, REAL, ACCENT, DIM, CMD,
COMP_MIRAGE, COMP_AURA, COMP_STAT, COMP_DAWN
```

### Node `online_indicator`

- `always` — node is always green-bordered
- `mqtt_connected` — green when the broker connection is open
- `topic_seen:<pattern>` — green once any matching message has arrived

## Signals

The overlay emits these signals for sibling widgets:

```gdscript
signal message_received(topic: String, payload: String, payload_bytes: int)
signal topic_seen(topic: String)
signal metrics_updated(clients: int, msg_count: int, subscriptions: int)
```

`metrics_updated` reflects values from `$SYS/broker/{clients/connected,
messages/received, subscriptions/count}`. The overlay subscribes to
these automatically.

## Public state (read-only)

```gdscript
overlay.mqtt_connected   # bool
overlay.msg_count        # int  — non-muted messages observed
overlay.msg_rate         # float — moving average (1s window)
overlay.active_topics    # Dict topic→last-seen-unix (10s stale prune)
overlay.broker_clients   # int  — latest $SYS value
overlay.broker_subscriptions
overlay.broker_msgs_received
```

## Muting traffic

```gdscript
overlay.mute_topics(["aura", "stat"])   # drop these from count + particles
overlay.mute_topics([])                  # un-mute everything
```

Useful for demo "hide mock traffic" toggles.

## Self-publish round-trip

The overlay subscribes to every topic declared by its config's edges at
load time, so the visualization can see traffic the autoload may not
already track. This includes the Godot client's **own publishes** — when
you publish to `e3-avatar/cmd` and the active config declares an edge
with `"topics": ["*/cmd"]` or `"e3-avatar/cmd"`, the broker routes the
message back to you and the visualizer renders it (counter increments,
edge pulses, particle animates).

This is the desired behavior for visualization: a viewer expects "I sent
a command → I see it travel the bus." But it has a consequence for
**any other handler** that subscribes to a topic it might publish to —
without a self-filter, two subscribed clients can ping-pong into a loop.

### The convention

Any handler that subscribes to a topic it might publish to MUST filter
its own publishes out by comparing the OCP `device` field:

```gdscript
const OWN_DEVICE := "my-component"

func _on_message(topic: String, payload: String) -> void:
    var msg = JSON.parse_string(payload)
    if msg is Dictionary and msg.get("device") == OWN_DEVICE:
        return  # Skip our own publishes
    # ... handle ...
```

OCP v1.4 messages always carry `"device": "<peer-id>"`. The mock
script (`tools/mock_ocp_traffic.py`) follows this pattern when listening
to its own `dawn` topic.

The topology overlay itself does **not** need this filter — its
`_on_message` is purely passive (counters, signals, visual effects, no
publishes). The convention applies to any future scene or addon that
subscribes-and-publishes on the same topic pattern.

See ADR-0003 for the full rationale on subscription ownership and
loop prevention.

## Hotkey toggle pattern

If you want the overlay to fade in/out on a hotkey (e.g. during a slide
demo), wrap it in a `CanvasLayer` and tween `modulate.a`:

```gdscript
func _input(event):
    if event is InputEventKey and event.pressed and event.keycode == KEY_T:
        var tween = create_tween()
        var target_a = 0.0 if overlay.visible and overlay.modulate.a > 0.5 else 0.85
        tween.tween_property(overlay, "modulate:a", target_a, 0.3)
```

## See also

- `scenes/demos/demo_presentation/content/architecture_live.tscn` — the
  reference embedding: M.I.R.A.G.E. demo config with InfoPanel,
  MockToggle, and D-pad sibling widgets.
- `docs/adr/ADR-NNNN-ocp-topology-addon-extraction.md` — design rationale.
