# ADR-0002: Extract OCP Topology Visualizer into Reusable Addon

**Status:** Accepted
**Date:** 2026-05-25
**Context:** O.A.S.I.S. game engine plugin — separating reusable infrastructure from demo-specific composition

## Decision

The live topology rendering — node boxes, animated edges, message
particles, `$SYS`-driven node health, topic routing — is extracted
from `scenes/demos/demo_presentation/content/architecture_live.gd`
into a reusable addon at `addons/oasis_ocp/visualization/`. Layout is
driven by a JSON config rather than hardcoded constants. The original
`architecture_live` scene is preserved as a thin wrapper that
instantiates the addon with the `mirage_demo.json` config and layers
demo-specific widgets (InfoPanel, MockToggle, D-pad) on top.

## Context

`architecture_live.gd` evolved into a 408-line script that combined
two distinct concerns:

1. **Generic OCP topology visualization** — subscribe to MQTT, render
   labeled boxes for nodes, animate message particles along
   connections, prune stale topics, expose live message metrics.
2. **Demo-specific UI and interactions** — the InfoPanel showing MQTT
   status text, the "Mock Traffic: ON/OFF" toggle, the D-pad that
   injects `e3-avatar/cmd` commands, the slide-template integration
   (`extends SlideTemplate.gd`).

The first concern is generally useful — for debugging ("is my message
reaching the subscriber?"), onboarding (new contributors see message
flow live), observability dashboards, and presentations beyond this
one. The second concern is specific to the M.I.R.A.G.E. demo's design.

Mixing the two meant any reuse of the topology view required either
(a) instantiating the whole `architecture_live` scene and disabling
the parts that weren't wanted, or (b) forking the rendering code into
a separate copy. Neither scales as more topology use cases emerge.

## Decision Drivers

1. **Reusability beyond the demo** — debugging, observability, public
   events, future Observability Tool widget. The topology view should
   work standalone, without dragging the slide engine along with it.

2. **Config-driven layouts** — different use cases want different
   topologies (chat-focused, full ecosystem, debug-all, mock demo).
   Hardcoding three node positions and three connection lines was the
   right call for a single-purpose scene; for reuse, the layout must
   be data.

3. **Decouple from `SlideTemplate`** — the addon shouldn't know it's
   running inside a presentation. `SlideTemplate.gd` provides
   step-based animation helpers; the topology view has no steps.

4. **No visual regression in the existing demo** — the current
   `architecture_live` rendering is a stakeholder-visible asset.
   Extraction must preserve its on-screen appearance exactly.

5. **Composability** — info panels, toggle widgets, and command
   injectors are demo-specific Controls layered over the topology.
   The addon exposes signals and read-only state for these siblings
   to consume; it does not embed them.

## What Stays in the Demo

The following remain in `architecture_live.tscn` / `architecture_live.gd`:

- **InfoPanel** (MQTT status text, message counter, message rate,
  active-topics label) — text widgets pulled from `topology.msg_count`,
  `topology.msg_rate`, `topology.active_topics` each frame
- **MockToggle button** — calls `topology.mute_topics(["aura", "stat"])`
  to suppress mock traffic
- **D-pad panel** — publishes OCP `e3-avatar/cmd` messages, unrelated
  to topology rendering
- **`extends SlideTemplate.gd`** — slide-template integration for the
  presentation deck

## What Moves to the Addon

- **Topology nodes** — labeled boxes with status indicator, pulse
  highlight, role-based accent color
- **Topology edges** — directed connection lines with arrowheads,
  configurable color, label, and animated envelope particles
- **Particle system** — `MAX_PARTICLES`, `PARTICLE_SPEED`,
  `PARTICLE_FADE`, pulse decay
- **MQTT subscription** — via `OasisMQTT` autoload's `global_message`
  signal
- **Topic routing** — pattern matching (exact / `+` / `#` / `*/<suffix>`)
  to route messages to matching edges
- **Stale-topic pruning** — `TOPIC_STALE_SEC` countdown
- **Rate calculation** — moving average via `RATE_INTERVAL`
- **`$SYS` metrics** — auto-subscribed and exposed via signal

## Schema Design

Layouts are JSON configs at `addons/oasis_ocp/visualization/configs/`.
A node is `{id, label, subtitle, position, size, role, color,
online_indicator}`. An edge is `{from, to, label, topics}`. Topic-color
rules map patterns to palette names. Positions and sizes are percentages
(0.0–1.0) of the parent rect so configs are viewport-independent.

Topic patterns follow MQTT conventions (`+`, `#`) plus a `*/<suffix>`
shorthand for "any prefix + slash + suffix" since it's the most common
non-MQTT pattern in OCP usage. See `README.md` in the addon directory.

## Consequences

### Positive

- Topology view is now embeddable as overlay, panel, or full scene
- Four example configs land at once (M.I.R.A.G.E. demo, D.A.W.N. demo,
  full ecosystem, debug-all)
- `architecture_live.gd` drops from 408 lines to ~130, with the smaller
  script doing only what it should — bridging the demo widgets to the
  reusable view
- Future protocol-aware edges (MQTT control / MQTT binary / RTMP / HTTP)
  can be added inside the addon without touching the demo
- Public state (`topology.mqtt_connected`, `msg_count`, `msg_rate`,
  `active_topics`) and signals (`message_received`, `topic_seen`,
  `metrics_updated`) form a small, intentional API surface

### Negative

- Two-file indirection: when someone modifies the M.I.R.A.G.E. demo's
  topology, they edit `mirage_demo.json` rather than the GDScript that
  draws it. The README mitigates this with a config-schema reference.
- `class_name` is intentionally NOT used on the addon's scripts. The
  recurring "Class name not resolving on first load" issue (see project
  CLAUDE.md / memory) makes path-based `preload()` the safer pattern.
  Type annotations on the addon's internal references are therefore
  weaker than they would otherwise be.

### Neutral

- Provider list and topic cloud sub-panels — drawn inline by the old
  `architecture_live._draw_diagram` — are not present in the migrated
  scene. The InfoPanel's `topics_label` already shows the active topic
  list textually, and per-provider state is visible in the
  ControlPanel. These two specific sub-panels were redundant with
  state available elsewhere; their removal is not a regression.

## Out of Scope (Tracked Separately)

The following enhancements are intentionally NOT part of this ADR
and will be filed as separate issues:

- Multi-protocol edges (MQTT control / MQTT binary / RTMP / HTTP)
  with protocol-specific visual styles
- L3 progression integrations — Option 1 (RTMP relay) as a new edge
  type; Option 2 (MQTT JPEG frames) via payload-size-aware particles
- `$SYS`-driven node health (LWT-aware coloring, rate-based pulsing)
- Edge thickness / particle size proportional to message rate
- Latency-driven particle travel speed
- Side-by-side topology comparison (L1 mock vs L3 real)
- Recording / GIF export
- Failure injection extensions
- Hierarchical / collapsible node groupings

## References

- Original implementation: `scenes/demos/demo_presentation/content/architecture_live.gd` (pre-extraction)
- Addon: `addons/oasis_ocp/visualization/`
- Issue #14 — the request that drove this extraction
- ADR-0001 — Provider Control Panel Architecture (the other
  abstraction the demo depends on)
