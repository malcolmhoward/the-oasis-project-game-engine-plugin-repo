extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

## CRITICAL: These panels morph into the live demo at Slide 7.
## They are in the "morph_panel" group with morph_target metadata.


func _ready():
	total_steps = 4
	$DevicePanel.visible = false
	$NetworkPanel.visible = false
	$PlatformPanel.visible = false
	$Labels.visible = false

	# Register panels for morph transition
	$DevicePanel.add_to_group("morph_panel")
	$DevicePanel.set_meta("morph_target", "DeviceLayer")
	$NetworkPanel.add_to_group("morph_panel")
	$NetworkPanel.set_meta("morph_target", "NetworkLayer")
	$PlatformPanel.add_to_group("morph_panel")
	$PlatformPanel.set_meta("morph_target", "PlatformLayer")


func _animate_step(step: int) -> void:
	match step:
		1: _slide_up($DevicePanel, 0.4, 40.0)
		2: _slide_up($NetworkPanel, 0.4, 40.0)
		3: _slide_up($PlatformPanel, 0.4, 40.0)
		4: _fade_in($Labels, 0.3)
