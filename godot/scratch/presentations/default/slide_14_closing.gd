extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

## Closing slide. The companion reveal is handled by
## PresentationController + CompanionOverlay when the user
## advances past this slide (the last one).


func _ready():
	total_steps = 2
	for child in get_children():
		if child is Control:
			child.visible = false

	$Title.add_theme_font_size_override("font_size", 72)
	$Body.add_theme_font_size_override("font_size", 32)
	$Repos.add_theme_font_size_override("font_size", 22)


func _animate_step(step: int) -> void:
	match step:
		1:
			_fade_in($Title, 0.5)
			_fade_in($Body, 0.4, 0.3)
		2:
			$Repos.modulate.a = 0.0
			$Repos.visible = true
			var tween = create_tween()
			tween.tween_property($Repos, "modulate:a", 0.5, 0.4)


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			$Title.visible = true
			$Title.modulate.a = 1.0
			$Body.visible = true
			$Body.modulate.a = 1.0
		2:
			$Repos.visible = true
			$Repos.modulate.a = 0.5


func _reset_animations() -> void:
	for child in get_children():
		if child is Control:
			child.visible = false
			child.modulate.a = 0.0
