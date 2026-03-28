extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"


func _ready():
	total_steps = 4
	for child in get_children():
		if child is Control:
			child.visible = false

	# Font size overrides
	$Title.add_theme_font_size_override("font_size", 56)
	$Equation.add_theme_font_size_override("font_size", 36)
	$Concept.add_theme_font_size_override("font_size", 32)
	$Physical.add_theme_font_size_override("font_size", 32)
	$Footer.add_theme_font_size_override("font_size", 24)


func _animate_step(step: int) -> void:
	match step:
		1:
			_fade_in($Title, 0.4)
			_slide_up($Equation, 0.3, 30.0, 0.2)
		2:
			_fade_in($Concept, 0.3)
		3:
			_fade_in($Physical, 0.3)
		4:
			_fade_in($Footer, 0.4)


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			$Title.visible = true
			$Title.modulate.a = 1.0
			$Equation.visible = true
			$Equation.modulate.a = 1.0
		2:
			$Concept.visible = true
			$Concept.modulate.a = 1.0
		3:
			$Physical.visible = true
			$Physical.modulate.a = 1.0
		4:
			$Footer.visible = true
			$Footer.modulate.a = 1.0


func _reset_animations() -> void:
	for child in get_children():
		if child is Control:
			child.visible = false
			child.modulate.a = 0.0
