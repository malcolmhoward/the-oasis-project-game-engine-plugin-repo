# Presentation Engine

A reusable presentation system for Godot. Create slide-based presentations with step animations, keyboard navigation, speaking cues, and morph transitions to live demo scenes.

## Creating a Presentation

1. Create a folder for your presentation content:
   ```
   scratch/presentations/my_presentation/
   ```

2. Create a `presentation.json` manifest:
   ```json
   {
     "title": "My Presentation",
     "theme": "res://resources/themes/arc_reactor_dark.tres",
     "slides": [
       {"scene": "slide_01_title.tscn", "cue": "Title slide"},
       {"scene": "slide_02_content.tscn", "cue": "Main point"}
     ]
   }
   ```

3. Create slide scenes inheriting from `SlideTemplate.gd`:
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

4. Set the manifest path in `PresentationController` and run.

## Keyboard Controls

| Key | Action |
|-----|--------|
| Right / Space | Next step or slide |
| Left | Previous step |
| Tab | Toggle annotations |
| F | Fullscreen |
| Escape | Slide list |
| D | Debug panel |

## Manifest Format

```json
{
  "title": "Presentation Title",
  "theme": "res://resources/themes/arc_reactor_dark.tres",
  "theme_override": null,
  "slides": [
    {"scene": "path/to/slide.tscn", "cue": "Speaker cue text"}
  ],
  "transitions": {
    "slide_04_to_slide_07": {
      "type": "morph_to_demo",
      "duration": 0.8,
      "demo_scene": "res://scenes/demos/demo_ocp_monitor.tscn"
    }
  },
  "appendix": [
    {"scene": "path/to/appendix.tscn", "cue": "Appendix cue"}
  ]
}
```

## Morph Transitions

To morph slide elements into a live demo scene, add panels to the `morph_panel` group and set metadata:

```gdscript
panel.add_to_group("morph_panel")
panel.set_meta("morph_target", "TargetNodeName")
```

The morph engine tweens panels from their slide positions to matching node positions in the target demo scene.

## Privacy

The `scratch/` directory is gitignored. Presentation content (slide scenes, manifests, speaker notes) stored there is private by default. The engine itself is committed and open-source.
