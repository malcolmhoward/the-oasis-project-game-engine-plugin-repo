extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

const ARC_CORE := Color("2dd4bf")
const PANEL_BG := Color("1a1e24")


func _ready():
	total_steps = 4
	for child in get_children():
		if child is Control:
			child.visible = false

	# Font size overrides
	$Title.add_theme_font_size_override("font_size", 56)
	$Title.add_theme_color_override("font_color", ARC_CORE)
	$Context.add_theme_font_size_override("font_size", 28)
	$LocationList.add_theme_font_size_override("font_size", 24)

	# Monospace for the location list
	var mono_font = load("res://resources/fonts/IBMPlexMono-Regular.ttf")
	if mono_font:
		$LocationList.add_theme_font_override("font", mono_font)

	# Style option panels
	for panel in [$OptionA, $OptionB, $OptionC]:
		var style := StyleBoxFlat.new()
		style.bg_color = PANEL_BG
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 16.0
		style.content_margin_right = 16.0
		style.content_margin_top = 12.0
		style.content_margin_bottom = 12.0
		panel.add_theme_stylebox_override("panel", style)

	$OptionA/LabelA.add_theme_font_size_override("font_size", 28)
	$OptionB/LabelB.add_theme_font_size_override("font_size", 28)
	$OptionC/LabelC.add_theme_font_size_override("font_size", 28)
	$Footer.add_theme_font_size_override("font_size", 24)
	$FooterSub.add_theme_font_size_override("font_size", 24)


func _animate_step(step: int) -> void:
	match step:
		1:
			_fade_in($Title, 0.4)
			_fade_in($Context, 0.3, 0.2)
		2:
			_slide_up($LocationList, 0.4, 25.0)
		3:
			_slide_in_left($OptionA, 0.3, 40.0)
			_slide_in_left($OptionB, 0.3, 40.0, 0.1)
			_slide_in_left($OptionC, 0.3, 40.0, 0.2)
		4:
			_fade_in($Footer, 0.3)
			_fade_in($FooterSub, 0.3, 0.15)


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			$Title.visible = true
			$Title.modulate.a = 1.0
			$Context.visible = true
			$Context.modulate.a = 1.0
		2:
			$LocationList.visible = true
			$LocationList.modulate.a = 1.0
		3:
			$OptionA.visible = true
			$OptionA.modulate.a = 1.0
			$OptionB.visible = true
			$OptionB.modulate.a = 1.0
			$OptionC.visible = true
			$OptionC.modulate.a = 1.0
		4:
			$Footer.visible = true
			$Footer.modulate.a = 1.0
			$FooterSub.visible = true
			$FooterSub.modulate.a = 1.0


func _reset_animations() -> void:
	for child in get_children():
		if child is Control:
			child.visible = false
			child.modulate.a = 0.0
