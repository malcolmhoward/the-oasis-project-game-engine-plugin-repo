extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

## Fallback title card — the actual demo loads via MorphTransition from slide 6.
## This slide appears only if the morph transition fails.


func _ready():
	total_steps = 1
	$Subtitle.visible = false
	$Tech.visible = false

	# Font size overrides
	$Subtitle.add_theme_font_size_override("font_size", 40)
	$Tech.add_theme_font_size_override("font_size", 32)


func _animate_step(step: int) -> void:
	match step:
		1:
			_fade_in($Subtitle, 0.3)
			_fade_in($Tech, 0.3, 0.15)


func _reset_animations() -> void:
	$Subtitle.visible = false
	$Tech.visible = false
