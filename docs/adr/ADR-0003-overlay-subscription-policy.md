# ADR-0003: Visualization-Driven MQTT Subscriptions Live with the Consumer

**Status:** Accepted
**Date:** 2026-06-07
**Context:** O.A.S.I.S. game engine plugin — subscription ownership boundary between the autoload and the consumer (specifically the topology overlay), plus a project-wide loop-prevention convention

## Decision

The MQTT subscriptions a Godot scene needs **purely for visualization** live with that scene, not in the `OasisMQTT` autoload. The autoload's subscription list is reserved for topics the application needs to **process**. When any handler subscribes to a topic it might also publish to, it MUST filter its own publishes out by comparing the OCP `device` field against its own device identifier.

## Context

ADR-0002 extracted the live architecture diagram into a reusable topology addon. That decision focused on rendering responsibility — what gets drawn, where, by which component — but did not address subscription responsibility. The autoload (`oasis_mqtt_autoload.gd:51-57`) continued to own all MQTT subscriptions with a hardcoded list:

```
+/status, +/events, echo/#, aura, stat, hud/#, dawn
```

Two problems surfaced after the extraction:

1. **D-pad commands invisible to visualization.** The `architecture_live` demo's D-pad publishes to `e3-avatar/cmd`, but the autoload subscribes to no `*/cmd` pattern. The Godot client's own publishes never round-trip back, so the InfoPanel counter doesn't increment, edges don't pulse, and the topic cloud doesn't update when the user injects a command. The visualization looks broken to a viewer who expects "I sent a message → I should see it."

2. **Config-specific gaps will multiply.** Each topology config declares the topics it cares about via its `edges[]`. As we add more configs (`dawn_demo.json`, `full_ecosystem.json`, `debug_all.json`), each will potentially need topics the autoload doesn't subscribe to. Adding every visualization-relevant pattern to the autoload turns it into a dumping ground for unrelated concerns and couples the app's subscription policy to whichever visualization is currently active.

The cleanest path is to push visualization subscriptions down to the visualization, not up to the autoload.

## Decision Drivers

1. **Separation of concerns** — the autoload subscribes for the app; the overlay subscribes for the picture. Mixing the two means changes to one drag in changes to the other.

2. **Config-driven discovery** — each topology config already declares its edges with topic patterns. Walking that list at config load is the natural source of truth.

3. **Subscribe-twice is safe** — `mqtt_bridge.gd:79` dedupes subscriptions via `_subscriptions`. Overlapping with the autoload's list creates no protocol overhead beyond the initial SUBSCRIBE round-trip.

4. **Pure-consumer code paths can't loop** — the overlay's `_on_message` only increments counters, emits signals, and triggers visual effects. It never publishes. So no matter what topics it subscribes to, the overlay alone cannot create a feedback loop.

5. **Loops are still possible elsewhere** — any future handler that subscribes to a topic it might publish to (e.g. a DAWN handler that listens for `dawn/cmd` and might also emit one) could loop without defense. A project-wide convention prevents this category of bug before it ships.

## Subscription Ownership Boundary

| What lives in the autoload | What lives in the overlay |
|----------------------------|---------------------------|
| Topics the app *processes* (peer discovery, status awareness, sensor input for HUD widgets, DAWN chat backplane) | Topics the visualization *displays* (every topic declared by edges in the active config) |
| Hardcoded baseline subscriptions for the plugin's standard behavior | Config-driven, swapped at runtime when `load_config()` is called with a different config |
| `+/status`, `+/events`, `aura`, `stat`, `hud/#`, `dawn`, `echo/#` | All `edges[].topics` from the loaded config, plus the `$SYS` topics already subscribed by the overlay |

## Implementation

In `ocp_topology_overlay.gd::_build_edges()`, immediately after each `OcpTopologyEdge` is configured, subscribe to every topic pattern it declares:

```gdscript
func _build_edges() -> void:
	for spec in _config.get("edges", []):
		var from = _nodes_by_id.get(spec.get("from", ""))
		var to = _nodes_by_id.get(spec.get("to", ""))
		if from == null or to == null:
			continue
		var edge = EDGE_SCRIPT.new()
		# (setup omitted)
		edge.configure(spec, _palette, from, to)
		_edges.append(edge)
		# NEW: subscribe to every topic the edge declares so the
		# visualization sees traffic the autoload may not track.
		if _mqtt:
			for topic_pattern in edge.topic_patterns:
				_mqtt.subscribe(topic_pattern, 0)
```

`load_config()` already clears child nodes and edges before rebuilding; the overlay doesn't currently unsubscribe on swap. This is intentional for now — the autoload's MQTT bridge doesn't support UNSUBSCRIBE and adding it is out of scope. The trade-off: switching configs at runtime accumulates subscriptions but never leaks them (the broker silently drops unhandled messages, and Godot's signal connection is the only routing path).

## Loop-Prevention Convention

Any handler that **subscribes to a topic it might publish to** MUST self-filter by the OCP `device` field. The OCP v1.4 message envelope already carries `"device": "<peer-id>"`; consumers compare and skip:

```gdscript
const OWN_DEVICE := "my-component"

func _on_message(topic: String, payload: String) -> void:
	var msg = JSON.parse_string(payload)
	if msg is Dictionary and msg.get("device") == OWN_DEVICE:
		return  # Skip our own publishes
	# ... handle ...
```

Reference: `tools/mock_ocp_traffic.py:300` already uses this pattern (`if p.get("device") == "echo-dawn-mock": return`). The convention exists in the codebase informally; this ADR makes it explicit and project-wide.

The topology overlay does **not** need this filter because its `_on_message` is purely passive — no publishes, no actions. The convention applies to any future handler that subscribes-and-publishes on the same topic pattern.

## Consequences

### Positive

- D-pad and any future Godot-side OCP publishes become observable in the visualization without further code changes
- Each config self-describes what it wants to see; adding a new config doesn't touch the autoload
- The autoload stays focused on app-needed subscriptions, easier to reason about
- Loop-prevention convention is documented before the project has to recover from one
- Cross-config behavior: `debug_all.json`'s `topics: ["#"]` now subscribes to everything when active — a genuine debugging firehose

### Negative

- The overlay subscribes redundantly with the autoload for topics that overlap (`aura`, `stat`, etc.). Cheap (one extra SUBSCRIBE per topic at connect time) but worth noting.
- No UNSUBSCRIBE support means runtime config swaps accumulate subscriptions. Acceptable for the current single-config demo flow; revisit if runtime config switching becomes common.

### Neutral

- The mock script (`mock_ocp_traffic.py`) already follows the loop-prevention convention; no change needed there.

## Out of Scope (Tracked Separately)

- UNSUBSCRIBE support in `mqtt_bridge.gd` (would clean up after runtime config swaps; not a blocker for current use cases)
- A linter or CI check that enforces the `device`-field self-filter convention
- Subscription introspection API on the bridge (helpful for debugging "what am I subscribed to?")

## References

- ADR-0002 — Extract OCP topology addon. Establishes the addon boundary that this ADR extends to subscription ownership.
- Issue #16 — the request that drove this decision
- `godot/addons/oasis_ocp/oasis_mqtt_autoload.gd:51-57` — autoload's app-needed subscriptions
- `godot/addons/oasis_ocp/visualization/ocp_topology_overlay.gd::_build_edges()` — config-driven subscription site
- `godot/addons/oasis_ocp/mqtt_bridge.gd:78-82` — subscribe deduping
- `tools/mock_ocp_traffic.py:300` — existing loop-prevention example in the codebase
