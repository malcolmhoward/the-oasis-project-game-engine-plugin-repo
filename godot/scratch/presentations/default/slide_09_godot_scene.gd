extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"


func _ready():
	total_steps = 5
	# Hide everything except the root Control
	for child in get_children():
		if child is Control:
			child.visible = false

	# Font size overrides
	$Title.add_theme_font_size_override("font_size", 56)
	$Item1Number.add_theme_font_size_override("font_size", 36)
	$Item1Desc.add_theme_font_size_override("font_size", 28)
	$Item2Number.add_theme_font_size_override("font_size", 36)
	$Item2Desc.add_theme_font_size_override("font_size", 28)
	$Connecting.add_theme_font_size_override("font_size", 28)
	$Tagline.add_theme_font_size_override("font_size", 36)


func _animate_step(step: int) -> void:
	match step:
		1:
			_fade_in($Title, 0.4)
		2:
			_slide_up($Item1Number, 0.3, 30.0)
			_fade_in($Item1Desc, 0.3, 0.2)
		3:
			_slide_up($Item2Number, 0.3, 30.0)
			_fade_in($Item2Desc, 0.3, 0.2)
		4:
			_fade_in($Connecting, 0.4)
		5:
			_fade_in($Tagline, 0.4)


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			$Title.visible = true
			$Title.modulate.a = 1.0
		2:
			$Item1Number.visible = true
			$Item1Number.modulate.a = 1.0
			$Item1Desc.visible = true
			$Item1Desc.modulate.a = 1.0
		3:
			$Item2Number.visible = true
			$Item2Number.modulate.a = 1.0
			$Item2Desc.visible = true
			$Item2Desc.modulate.a = 1.0
		4:
			$Connecting.visible = true
			$Connecting.modulate.a = 1.0
		5:
			$Tagline.visible = true
			$Tagline.modulate.a = 1.0


func _reset_animations() -> void:
	for child in get_children():
		if child is Control:
			child.visible = false
			child.modulate.a = 0.0
