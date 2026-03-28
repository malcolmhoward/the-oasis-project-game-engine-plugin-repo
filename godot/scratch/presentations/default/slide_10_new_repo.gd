extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"


func _ready():
	total_steps = 5
	for child in get_children():
		if child is Control:
			child.visible = false

	# Font size overrides
	$Title.add_theme_font_size_override("font_size", 56)
	$Metadata.add_theme_font_size_override("font_size", 28)
	$TreeRoot.add_theme_font_size_override("font_size", 24)
	$TreeLines.add_theme_font_size_override("font_size", 24)
	$FutureNote.add_theme_font_size_override("font_size", 24)
	$Footer.add_theme_font_size_override("font_size", 24)

	# Monospace font for tree structure
	var mono_font = load("res://resources/fonts/IBMPlexMono-Regular.ttf")
	if mono_font:
		$TreeRoot.add_theme_font_override("font", mono_font)
		$TreeLines.add_theme_font_override("font", mono_font)
		$FutureNote.add_theme_font_override("font", mono_font)


func _animate_step(step: int) -> void:
	match step:
		1:
			_fade_in($Title, 0.4)
		2:
			_fade_in($Metadata, 0.3)
		3:
			# Tree builds as a group
			_fade_in($TreeRoot, 0.2)
			_slide_up($TreeLines, 0.3, 20.0, 0.15)
		4:
			_fade_in($FutureNote, 0.3)
		5:
			_fade_in($Footer, 0.4)


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			$Title.visible = true
			$Title.modulate.a = 1.0
		2:
			$Metadata.visible = true
			$Metadata.modulate.a = 1.0
		3:
			$TreeRoot.visible = true
			$TreeRoot.modulate.a = 1.0
			$TreeLines.visible = true
			$TreeLines.modulate.a = 1.0
		4:
			$FutureNote.visible = true
			$FutureNote.modulate.a = 1.0
		5:
			$Footer.visible = true
			$Footer.modulate.a = 1.0


func _reset_animations() -> void:
	for child in get_children():
		if child is Control:
			child.visible = false
			child.modulate.a = 0.0
