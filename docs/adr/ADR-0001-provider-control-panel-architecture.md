# ADR-0001: Provider Control Panel Architecture

**Status:** Accepted
**Date:** 2026-04-08
**Context:** O.A.S.I.S. game engine plugin — Provider pattern for data source hot-swapping

## Decision

The game engine plugin's ControlPanel implements a **component-grouped,
collapsible Provider toggle system** where every mocked data source is
independently togglable between SIMULATED and LIVE, organized by the
O.A.S.I.S. component that owns that data source.

## Context

The O.A.S.I.S. game engine plugin runs on real MQTT infrastructure
(Mosquitto broker in Docker, WebSocket connections) but can use
simulated data sources when real hardware is unavailable. The
distinction between "real infrastructure" and "simulated data" is
not immediately obvious and needs to be made explicit and controllable.

The demo currently mocks data from four O.A.S.I.S. components:

| Component | Data Sources | Current State |
|-----------|-------------|---------------|
| M.I.R.A.G.E. | Camera feed, Audio input | Audio toggleable; Camera planned |
| A.U.R.A. | Motion (IMU), GPS, Environmental (temp/humidity/CO2) | All simulated, not toggleable |
| S.T.A.T. | System metrics (CPU/mem/temp), Battery status | All simulated, not toggleable |
| D.A.W.N. | LLM responder | Mock keyword matcher, not toggleable |

A flat list of 8 toggles would be unwieldy. The toggles need logical
grouping that maps to the real O.A.S.I.S. architecture.

## Decision Drivers

1. **Provider pattern consistency** — Every data source uses the same
   interface regardless of whether it's simulated or live. The toggle
   swaps the implementation, not the interface.

2. **Component-peer architecture** — O.A.S.I.S. components are peers
   (ADR-0002 in meta-repo). The control panel should reflect this: each
   component is a collapsible section with its own data sources.

3. **Granularity** — Individual data sources are toggleable (e.g., enable
   real GPS but keep motion simulated). Component-level toggles provide
   convenience ("plug in A.U.R.A. hardware, toggle all its sensors live").
   A global Toggle All provides the full-system switch.

4. **Observable state changes** — Every toggle publishes an OCP message
   to the MQTT stream, making provider swaps visible as protocol events.

5. **Scene composition** — The ControlPanel is a reusable Godot scene
   that can be instanced in any demo layout. New components are added
   by extending the scene, not by creating separate control UIs.

## Architecture

### Three-level toggle hierarchy

```
Toggle All (global)
├── M.I.R.A.G.E. (component toggle)
│   ├── Camera    (data source toggle)
│   └── Audio     (data source toggle)
├── A.U.R.A. (component toggle)
│   ├── Motion    (data source toggle)
│   ├── GPS       (data source toggle)
│   └── Environ   (data source toggle)
├── S.T.A.T. (component toggle)
│   ├── System    (data source toggle)
│   └── Battery   (data source toggle)
└── D.A.W.N. (component toggle)
    └── LLM       (data source toggle)
```

### Toggle semantics

| Level | Action | Effect |
|-------|--------|--------|
| Global "Toggle All" | All SIMULATED → all LIVE (or vice versa) | Every data source swaps simultaneously |
| Component toggle | All sources in that component swap | Maps to "plugging in real hardware for this component" |
| Data source toggle | Single source swaps | Fine-grained control for debugging or demo |

### State indicators

| State | Color | Meaning |
|-------|-------|---------|
| ● LIVE | Green (#44dd88) | Real hardware / real data source active |
| ● SIM | Amber (#ccaa44) | Simulated / mock data source active |
| ● MIXED | Gray (#888888) | Some sources live, some simulated (component/global level only) |

### Collapsible sections

Each component header is clickable to collapse/expand its data source rows.
Default state: all expanded. This keeps the panel manageable when many
components are present while allowing the full view when needed.

### OCP message format

Every toggle publishes to `oasis/godot-control/status`:

```json
{
  "device": "godot-control",
  "msg_type": "status",
  "provider": "aura-motion",
  "source": "imu",
  "component": "aura",
  "timestamp": 1234567890
}
```

The `component` field groups related swaps in the OCP stream.

## Layout

```
┌──────────────────────────┐
│ [● SIMULATED] [→ Live]   │  Global toggle
│ ─────────────────────────│
│ ▼ M.I.R.A.G.E.    [All] │  Component header + toggle
│   Camera   ● SIM [Toggle]│  Data source rows
│   Audio    ● SIM [Toggle]│
│   [volume bar]           │
│   [waveform canvas]      │
│ ▼ A.U.R.A.        [All] │
│   Motion   ● SIM [Toggle]│
│   GPS      ● SIM [Toggle]│
│   Environ  ● SIM [Toggle]│
│ ▼ S.T.A.T.        [All] │
│   System   ● SIM [Toggle]│
│   Battery  ● SIM [Toggle]│
│ ▼ D.A.W.N.        [All] │
│   LLM      ● SIM [Toggle]│
│ ─────────────────────────│
│        [↑]               │  D-pad (direct OCP commands)
│    [←] [Jump] [→]        │
│        [↓]               │
└──────────────────────────┘
```

## Data source details

### M.I.R.A.G.E.

| Source | SIMULATED | LIVE | Topic |
|--------|-----------|------|-------|
| Camera | SMPTE test pattern (ImageTexture) | USB webcam (CameraTexture via CameraServer) | `oasis/godot-control/status` |
| Audio | Sine wave generator | Microphone (AudioStreamMicrophone) | `oasis/godot-control/status` |

### A.U.R.A.

| Source | SIMULATED | LIVE | Topic |
|--------|-----------|------|-------|
| Motion | Sine-wave orientation from mock_ocp_traffic.py | Real IMU sensor on `aura` MQTT topic | `aura` |
| GPS | Drifting Atlanta coordinates from mock script | Real GPS on `aura` MQTT topic | `aura` |
| Environ | Oscillating temp/humidity/CO2 from mock script | Real environmental sensor on `aura` MQTT topic | `aura` |

Note: A.U.R.A. LIVE mode means consuming real sensor data from MQTT.
SIMULATED mode means the mock_ocp_traffic.py script provides the data.
Both flow through real MQTT — the difference is the data *origin*, not
the transport.

### S.T.A.T.

| Source | SIMULATED | LIVE | Topic |
|--------|-----------|------|-------|
| System | Oscillating CPU/mem/temp from mock script or local generation | Real system metrics via OS APIs or MQTT | `stat` |
| Battery | Fixed mock values from mock script | Real battery monitor on `stat` MQTT topic | `stat` |

### D.A.W.N.

| Source | SIMULATED | LIVE | Topic |
|--------|-----------|------|-------|
| LLM | Keyword-matching mock responder (mock_ocp_traffic.py) | Real D.A.W.N. instance with LLM backend | `dawn` |

Note: D.A.W.N. LIVE requires a running D.A.W.N. server with LLM. When
toggled to LIVE, the mock responder stops processing `dawn` messages and
the real D.A.W.N. handles them. In practice, this toggle is a "disconnect
mock, let real D.A.W.N. take over" switch.

## Consequences

### Positive

- **Answers "how much is real?"** — The panel's state IS the answer.
  Green = real, amber = simulated. At a glance.
- **Incremental hardware integration** — As real hardware becomes
  available, flip individual toggles. No code changes needed.
- **Demo flexibility** — Show fully simulated, fully live, or any mix.
  Toggle individual sources to demonstrate graceful degradation.
- **Architectural education** — The component grouping teaches the
  audience how O.A.S.I.S. is structured while they interact with it.
- **Reusable scene** — Same ControlPanel works in any demo layout.

### Negative

- **Panel complexity** — 8 data source rows + 4 component headers +
  global toggle + d-pad is a lot of UI. Mitigated by collapsible sections.
- **Mock script coordination** — Toggling A.U.R.A./S.T.A.T./D.A.W.N.
  between simulated and live requires the mock script to stop publishing
  for those topics when live mode is active, or the HUD must ignore mock
  data when live. Implementation choice: HUD ignores mock data in live mode
  (simpler, no mock script changes needed).

### Neutral

- The OCP stream will show more provider_swap messages. This is actually
  desirable — it proves every state change is observable.

## Multi-Level Simulation Model

The binary SIMULATED/LIVE toggle is an abstraction over a deeper
multi-level simulation model. Each data source actually operates
across a spectrum of simulation levels:

### Simulation Levels

| Level | Name | Description | What's Real |
|-------|------|-------------|-------------|
| 0 | Fully Local | Data generated in-process (no network) | UI rendering only |
| 1 | Real Transport | Mock data via real MQTT broker | MQTT infrastructure |
| 2 | Real Source | Real data source, no component container | Data + transport |
| 3 | Real Component | Actual O.A.S.I.S. container providing data | Everything |

### Per-Source Level Examples

| Source | Level 0 | Level 1 | Level 2 | Level 3 |
|--------|---------|---------|---------|---------|
| Camera | SMPTE test pattern | Test pattern via MQTT | Host USB webcam (ffmpeg) | M.I.R.A.G.E. container streaming |
| Audio | Sine wave | — | Host microphone | A.U.R.A. audio sensor |
| S.T.A.T. System | Local sine oscillation | mock_ocp_traffic.py → MQTT | Host OS metrics via API | S.T.A.T. container publishing |
| D.A.W.N. LLM | — | Mock keyword matcher → MQTT | — | D.A.W.N. server with real LLM |
| A.U.R.A. GPS | — | Mock coordinates → MQTT | Host GPS (if available) | A.U.R.A. hardware GPS |

The current toggle maps to these levels as follows:
- **SIMULATED** = Level 0 or 1 (local generation or mock script)
- **LIVE** = Level 2 or 3 (real source or real component)

The toggle does not yet distinguish between Level 2 and Level 3.
A future enhancement could add a three-state toggle (SIM / LOCAL / REMOTE)
or auto-detect which level is available.

### Failure Mode Interpretation

Toggling a data source from LIVE to SIMULATED is equivalent to
**simulating that component's failure**. This reframes the control
panel as a **graceful degradation testing tool**:

- Toggle M.I.R.A.G.E. Camera to SIM → "What happens when the helmet
  camera fails? The HUD falls back to a test pattern."
- Toggle S.T.A.T. to SIM → "What happens when the system monitor goes
  offline? The HUD shows last-known or simulated values."
- Toggle D.A.W.N. to SIM → "What happens when the AI backend is
  unavailable? A local keyword matcher provides basic responses."

This is not an artificial demo feature — it IS the Provider pattern's
core value proposition. The same hot-swap mechanism that enables
simulation enables fault tolerance in production.

### Relationship to Three-Layer Architecture

The simulation levels map to the O.A.S.I.S. simulation framework's
three layers (ADR-0003 in meta-repo):

| Simulation Layer | Levels | What It Simulates |
|-----------------|--------|-------------------|
| Device Layer | 0, 2 | Hardware sensors, cameras, actuators |
| Network Layer | 1 | MQTT transport, message routing |
| Platform Layer | 3 | Full component containers |

Level 0 simulates the Device Layer (no real hardware).
Level 1 proves the Network Layer is real (mock data, real transport).
Level 2 uses real Device Layer but no Platform Layer (host hardware, no container).
Level 3 requires all three layers to be real.

### Infrastructure vs Data Distinction

A critical insight from the first presentation: the MQTT infrastructure
(Mosquitto broker, WebSocket connections, OCP message routing) is **always
real**, regardless of simulation level. Only the data sources change.
The architecture diagram makes this visible — connection lines pulse with
real messages even when all data sources are simulated.

This means the demo is never "fully fake." Even at Level 0, the protocol
layer is exercised. The question "how much is real?" has a nuanced answer:
the pipes are always real; the toggles control what flows through them.

## Alternatives Considered

### Flat toggle list (rejected)

8 toggles in a flat list with no grouping. Rejected because:
- Doesn't communicate component ownership
- No component-level toggle convenience
- Harder to scan visually

### Tab-based UI (deferred)

Separate tabs for "Providers" and "Controls" (d-pad). Could be added later
if the single-panel approach becomes too tall, but collapsible sections
should handle it.

### Automatic detection (deferred)

Auto-detect available hardware and toggle to LIVE automatically. Good UX
but removes the educational value of the manual toggle. Could be a future
"auto" mode alongside manual control.
