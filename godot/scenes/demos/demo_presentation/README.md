# Presentation Engine

A reusable slide-based presentation system for Godot 4.x. Supports step animations, keyboard navigation, speaking cues, morph transitions to live demo scenes, and a configurable companion overlay.

## Scene Composition Pattern

Presentation content is separated into two categories:

- **Technical content** — Slides about architecture, code patterns, and implementation details. These live in the `content/` subdirectory and are designed for reuse across presentations.
- **Stakeholder content** — Slides for specific audiences or contexts. These live in `scratch/presentations/` (gitignored) and are private by default.

Both types extend the same `SlideTemplate` base class and work identically within the presentation controller.

## Directory Structure

```
demo_presentation/
  SlideTemplate.gd          # Base class for all slides
  PresentationController.gd # Loads manifest, handles navigation
  MorphTransition.gd        # Morph panels into live demo scenes
  ProgressIndicator.gd      # Dot-based slide progress
  companion_reveal.gd       # Persistent companion face overlay
  demo_presentation.tscn    # Main scene (instantiate this)
  content/                   # Reusable technical slides (committed)
    provider_diagram.tscn
    provider_diagram.gd
  examples/                  # Example presentation (gravity sim)
    slides/
    gravity_sim.gd
  scratch/                   # Private content (gitignored)
    presentations/
      <name>/
        presentation.json    # Manifest
        slide_01_*.tscn      # Slide scenes
        slide_01_*.gd        # Slide scripts
```

## How to Create a Presentation

### Step 1: Create a Presentation Folder

```
scratch/presentations/my_presentation/
```

This directory is gitignored, so content stays private by default.

### Step 2: Create Slide Scenes

Each slide is a `.tscn` + `.gd` pair extending `SlideTemplate`:

```gdscript
extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

func _ready():
    total_steps = 3

func _animate_step(step: int) -> void:
    match step:
        1: _fade_in($Title)
        2: _slide_up($Content)
        3: _fade_in($Footer)
```

Available animation helpers from `SlideTemplate`:
- `_fade_in(node, duration, delay)` — Fade opacity from 0 to 1
- `_slide_up(node, duration, distance, delay)` — Slide up while fading in
- `_slide_in_left(node, duration, distance, delay)` — Slide in from left while fading in

For `_draw()`-based slides (diagrams, spectrums), add a child `Control` as a canvas and connect its `draw` signal.

### Step 3: Create a Manifest

Create `presentation.json` in your presentation folder:

```json
{
  "title": "My Presentation",
  "theme": "res://resources/themes/arc_reactor_dark.tres",
  "slides": [
    {"scene": "slide_01_title.tscn", "cue": "Introduction"},
    {"scene": "slide_02_content.tscn", "cue": "Main point"},
    {"scene": "res://scenes/demos/demo_presentation/content/provider_diagram.tscn", "cue": "Provider pattern"}
  ],
  "transitions": {},
  "appendix": []
}
```

Scene paths are relative to the manifest directory unless they start with `res://`.

### Step 4: Set the Manifest Path

In the `demo_presentation.tscn` scene, set the `manifest_path` export on `PresentationController`. Default search locations:

1. `user://presentations/default/presentation.json`
2. `res://scratch/presentations/default/presentation.json`

### Step 5: Run

Launch `demo_presentation.tscn`. The controller loads the manifest, instantiates slides on demand, and auto-plays step 1 of each slide on entry.

## Keyboard Controls

| Key | Action |
|-----|--------|
| Right / Space | Advance to next step or next slide |
| Left | Go back one step or one slide |
| Escape | Show slide list (overview) |
| Ctrl+D | Toggle between slides and live demo |
| F | Toggle fullscreen |
| Tab | Toggle annotation overlays |
| D | Toggle debug panel |
| Shift+Escape | Restore window from tray mode (companion overlay) |

## Manifest Format

```json
{
  "title": "Presentation Title",
  "theme": "res://resources/themes/arc_reactor_dark.tres",
  "theme_override": null,
  "slides": [
    {
      "scene": "path/to/slide.tscn",
      "cue": "Speaker cue text shown in bottom-left corner"
    }
  ],
  "transitions": {
    "slide_04_to_slide_07": {
      "type": "morph_to_demo",
      "duration": 0.8,
      "demo_scene": "res://scenes/demos/demo_ocp_monitor.tscn"
    }
  },
  "appendix": [
    {
      "scene": "path/to/appendix_slide.tscn",
      "cue": "Appendix cue"
    }
  ]
}
```

### Fields

- **title** — Display name for the presentation (used in UI and logs).
- **theme** — Default Godot theme resource. Applied globally on load.
- **theme_override** — Optional override theme (takes precedence over `theme`).
- **slides** — Ordered array of slide entries. Each has a `scene` path and optional `cue` text.
- **transitions** — Named transitions between slides. Key format: `slide_NN_to_slide_MM`. The `morph_to_demo` type tweens morph-panel-grouped nodes from slide positions to demo scene positions.
- **appendix** — Additional slides accessible outside the main sequence.

## Morph Transitions

To morph slide elements into a live demo scene, add panels to the `morph_panel` group and set target metadata:

```gdscript
panel.add_to_group("morph_panel")
panel.set_meta("morph_target", "TargetNodeName")
```

The morph engine tweens panels from their slide positions to matching node positions in the target demo scene. After the morph completes, the presentation enters demo mode (slide navigation is suspended; input passes through to the demo).

## Companion Overlay

The companion face is a persistent overlay that appears during live demos and optionally persists across slides afterward.

### Configuration

- **persist_after_demo** (export, default `false`) — When `true`, the companion remains visible after exiting demo mode and stays across subsequent slides.
- The companion reacts to MQTT messages on the `dawn` topic (expression changes for intents, speaking animation for speech).
- After the final slide, the companion can enter a standalone tray mode (borderless transparent window). Use `Shift+Escape` to restore the full window.

## Running a Presentation

### Prerequisites

- Docker (for Mosquitto MQTT broker)
- Python 3.10+ with `paho-mqtt` (`pip install paho-mqtt`)
- Godot 4.5.2+ (download from https://godotengine.org)

### Launch Steps

```bash
# 1. Start the MQTT broker (if not already running)
docker start oasis-mqtt-test
# Or first time: docker run -d --name oasis-mqtt-test -p 1883:1883 -p 9001:9001 eclipse-mosquitto:2

# 2. Start the mock OCP traffic publisher
python tools/mock_ocp_traffic.py --broker localhost --port 1883

# 3. Launch the presentation (in a separate terminal)
/path/to/Godot_v4.5.2-stable_win64.exe --path godot
```

The presentation controller auto-discovers the manifest at
`res://scratch/presentations/default/presentation.json`. If no
manifest is found, set `manifest_path` in the inspector or pass
a different default search path.

### Verifying Connectivity

After launch, the Godot console should show:
```
[MQTTBridge] Connecting to ws://localhost:9001...
[MQTTBridge] WebSocket open, sending MQTT CONNECT...
[OasisMQTT] Connected to localhost:9001
[Presentation] Loaded N slides, 0 appendix from ...
```

If MQTT does not connect, verify Mosquitto is running with
WebSocket support on port 9001.

## Privacy Model

The `scratch/` directory is gitignored. Presentation manifests, slide scenes, speaker notes, and any audience-specific content stored there remain private. The engine code (`SlideTemplate.gd`, `PresentationController.gd`, etc.) and reusable technical slides (`content/`) are committed and open-source.

This separation allows the same engine to serve both public examples and private presentations without risk of accidentally committing sensitive content.
