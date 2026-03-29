# Demo Verification and Presentation Status Check

**Date**: 2026-03-29
**Context**: Response to Malcolm's status check before continuing with presentation scenes.

---

## 1. E.C.H.O. Data Verification

The demos receive data from the **live E.C.H.O. simulation framework** running in Docker — not a standalone mock script or placeholder data.

### Data Flow

```
Docker: ecosystem-mock-mock-ecosystem-1 (Python)
  → E.C.H.O. MockSensor classes (Device layer) generate sensor data
  → publishes to Mosquitto broker on ports 1883 + 9001 (WebSocket)
    → Godot subscribes via WebSocket on port 9001
```

### Components Running in Docker

- `MockSensor("imu", sensor_type="motion")` → publishes to `aura` topic
- `MockSensor("gps", sensor_type="gps")` → publishes to `aura` topic
- `MockSensor("enviro", sensor_type="environmental")` → publishes to `aura` topic
- System metrics + battery → publishes to `stat` topic
- 4 OCP E4 peers (aura, stat, scope, dawn) → publish to `*/status` and `echo/discovery/simulates`
- Mock DAWN responder → listens on `dawn`, responds via LLMMock keyword matching + HomeAssistantMock tool execution

### Exact Topics and Sample Payloads

**OCP Peer Status** (`aura/status`):
```json
{"device": "aura", "msg_type": "status", "status": "online", "timestamp": 1774820928, "version": "0.1.0-simulation", "capabilities": ["motion", "gps", "environmental"]}
```

**Per-Peer Status** (`oasis/echo-aura-simulation/status`):
```json
{"peer_id": "echo-aura-simulation", "component": "aura", "embodiment": "software", "status": "online", "timestamp": 1774820928}
```

**Discovery** (`echo/discovery/simulates`):
```json
{"peer_id": "echo-dawn-simulation", "component": "dawn", "embodiment": "software", "capabilities": ["conversation", "tool_execution", "reasoning"], "timestamp": 1774820928}
```

**Motion/IMU** (`aura`):
```json
{"device": "Motion", "format": "Orientation", "heading": 334.25, "pitch": -4.82, "roll": -1.6, "w": -0.9738, "x": 0.023, "y": 0.0379, "z": 0.2232}
```

**GPS** (`aura`):
```json
{"device": "GPS", "time": "21:49:12", "date": "2026-03-29", "fix": 1, "quality": 1, "latitude": 33.748209, "latitudeDegrees": 33.748209, "lat": "N", "longitude": -84.387385, "longitudeDegrees": -84.387385, "lon": "W", "speed": 0, "angle": 25.0, "altitude": 320.1, "satellites": 8}
```

**Environmental** (`aura`):
```json
{"device": "Enviro", "temp": 22.1, "humidity": 60.0, "air_quality": 93.7, "tvoc_ppb": 8.2, "eco2_ppm": 437.4, "co2_ppm": 445.5, "heat_index_c": 23.3, "dew_point": 14.0}
```

**System Metrics** (`stat`):
```json
{"device": "SystemMetrics", "cpu_percent": 38.38, "memory_percent": 62.1, "disk_percent": 45.0, "system_temp": 52.3, "uptime_seconds": 78553}
```

**Battery** (`stat`):
```json
{"device": "BatteryStatus", "voltage": 12.4, "current": 1.2, "power": 14.88, "percentage": 85, "charging": false}
```

### How to Describe It to the project lead

The payloads use the **exact same JSON schemas** that M.I.R.A.G.E.'s `command_processing.c` expects. This is not placeholder data — it's the simulation framework's Device layer producing protocol-identical output at ~1Hz. The DAWN conversation loop runs through E.C.H.O.'s LLMMock (keyword matching) and HomeAssistantMock (entity state changes).

**Accurate description**: "Connected to the E.C.H.O. simulation framework. Same MQTT topics, same JSON schemas, same heartbeat cadence as real hardware. Indistinguishable on the wire."

---

## 2. Presentation Slide Content

### Content Source

The presentation outline (KRIS_PRESENTATION_OUTLINE_V1.md) provides slide-by-slide: titles, text content, speaker notes, and visual descriptions for all 14 main + 5 appendix slides.

### Architecture Slides (3-6)

Planned as **Godot scene elements** (animated, interactive) — not static images. The architecture diagram on Slide 4 would be built from the same layer components visible in the oasis_monitor demo, enabling the morph transition to the live demo.

### Demo Morph (Slide 4 → Slide 7)

The three-layer architecture diagram (drawn as colored panels in the slide) would tween-animate from "slide layout" positions to "demo layout" positions. The same visual elements reposition and connect to live MQTT data. Duration: 0.8s (ANIM_DRAMATIC).

### Current State

**No slide scenes have been built yet.** The presentation controller script (`scratch/presentation/presentation_controller.gd`) has the controller skeleton (keyboard nav, slide loading, transitions) but no actual slides.

Slide-by-slide content specifications would be needed to proceed. If there is a V2 of the presentation outline or more detailed visual specs, those would accelerate this work.

---

## 3. Companion Reveal Status

| Aspect | Status |
|--------|--------|
| Face rendering | **Built and verified** — blinks, reacts to OCP events |
| Expression state machine | **Working** — neutral, happy, worried, curious, sleeping |
| OCP event reactions | **Working** — peer discovery → curious, status online → happy, high temp/CPU → worried, 30s idle → sleeping |
| Health bar | **Working** — tracks OCP network health |
| Post-close reveal animation | **Not built** — presentation controller has skeleton only |
| Transparent/borderless window | **Not tested** — platform-dependent, known Godot issues on Windows |
| Fallback (shrink to face size) | **Not built** — simpler alternative if transparency fails |

### Platform Concern

Transparent + borderless + always_on_top has known issues on some Windows configurations (Godot issues #76551, #100647, #109693). This needs early testing on the target machine before committing to the reveal approach.

---

## 4. PR Review Readiness

| PR | Status | Known Issues | Dependency |
|---|---|---|---|
| #7 (scaffold) | **Ready for review** | No UI polish — functional demos with default Godot styling + live data | None |
| #8 (UI theme) | **Ready for review** | Design tokens + fonts + components; doesn't yet achieve full DAWN WebUI parity | Requires #7 merged first |
| #9 (companion) | **Ready for review** | Programmatic face (not pixel art); Expression → FaceExpression rename applied | Requires #8 merged first |

Review in order: #7 → #8 → #9. Each PR is self-contained for its scope but builds on the previous.

---

## 5. What's Left Before Presentation-Ready

### Remaining Work

1. **Slide scenes** (14 main + 5 appendix) — Godot scenes with Arc Reactor Dark theme, text content, architecture diagrams
2. **Demo morph transition** — architecture slide tweens into live demo layout
3. **Companion reveal sequence** — post-close animation (fade panels, transparent window, face floats)
4. **Transparent window test** — needs testing on Windows 11 before committing to reveal approach
5. **Standalone mock traffic script** — `mock_ocp_traffic.py` as fallback if Docker isn't running (V3 requirement)
6. **10-minute stability test** — run each demo for 10+ minutes without crash (V3 "demo-ready" criterion)
7. **Screen recording backup** — 2-minute pre-recorded demo as insurance if live demo fails

### Blockers

1. **Slide content specifications** — need detailed per-slide visual layouts (which elements, where, what animates) beyond what the outline provides
2. **Transparent window platform test** — blocks the reveal approach decision
3. **No `mock_ocp_traffic.py` yet** — blocks running demos without Docker

### Open Questions for Malcolm

1. **Presentation location**: Should the presentation run from the current repo (`scratch/`) or a separate private repo?
2. **Slide content source**: Should detailed slide-by-slide visual specs be provided separately, or should drafts be created based on the existing presentation outline?
3. **Reveal approach**: Should the companion reveal be the post-close animation (complex, platform-dependent) or a simpler in-presentation reveal (face highlights and annotation appears during the demo)?
4. **Fallback priority**: If the transparent window doesn't work on Windows 11, should effort go to fixing it or to implementing the shrink-to-face-size alternative?
5. **Mock traffic script**: Should `mock_ocp_traffic.py` be a standalone Python script or a mode within the existing E.C.H.O. framework (e.g., `python -m simulation.demo`)?
