extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"


func _ready():
	total_steps = 5
	# Title stays visible; hide all request items
	for child in get_children():
		if child is Control:
			child.visible = false
	# Show title immediately (it appears with step 1's slide-in)
	$Title.visible = true
	$Title.modulate.a = 1.0

	# Font size overrides
	$Title.add_theme_font_size_override("font_size", 56)
	$R1.add_theme_font_size_override("font_size", 32)
	$R2.add_theme_font_size_override("font_size", 32)
	$R3.add_theme_font_size_override("font_size", 32)
	$R4.add_theme_font_size_override("font_size", 32)
	$R5.add_theme_font_size_override("font_size", 32)


func _animate_step(step: int) -> void:
	match step:
		1:
			_slide_in_left($R1, 0.3, 50.0)
		2:
			_slide_in_left($R2, 0.3, 50.0)
		3:
			_slide_in_left($R3, 0.3, 50.0)
		4:
			_slide_in_left($R4, 0.3, 50.0)
		5:
			_slide_in_left($R5, 0.3, 50.0)


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			$R1.visible = true
			$R1.modulate.a = 1.0
		2:
			$R2.visible = true
			$R2.modulate.a = 1.0
		3:
			$R3.visible = true
			$R3.modulate.a = 1.0
		4:
			$R4.visible = true
			$R4.modulate.a = 1.0
		5:
			$R5.visible = true
			$R5.modulate.a = 1.0


func _reset_animations() -> void:
	for child in get_children():
		if child is Control:
			child.visible = false
			child.modulate.a = 0.0
	$Title.visible = true
	$Title.modulate.a = 1.0
