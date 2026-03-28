extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

# Design tokens
const BG_DEEPEST := Color("121417")
const ARC_CORE := Color("2dd4bf")
const TEXT_PRIMARY := Color("e6e6e6")
const TEXT_SECONDARY := Color("a0a0a0")
const TEXT_TERTIARY := Color("666666")


func _ready() -> void:
	total_steps = 3

	# Style the title — large, accent color
	var title := $Title as Label
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", ARC_CORE)

	# Subtitle — medium, secondary
	var subtitle := $Subtitle as Label
	subtitle.add_theme_font_size_override("font_size", 40)
	subtitle.add_theme_color_override("font_color", TEXT_SECONDARY)

	# Author — smaller, tertiary
	var author := $Author as Label
	author.add_theme_font_size_override("font_size", 28)
	author.add_theme_color_override("font_color", TEXT_TERTIARY)


func _animate_step(step: int) -> void:
	match step:
		1: _fade_in($Title, 0.5)
		2: _slide_up($Subtitle, 0.4, 20.0)
		3: _fade_in($Author, 0.3, 0.1)


func _reset_animations() -> void:
	$Title.visible = false
	$Title.modulate.a = 0.0
	$Subtitle.visible = false
	$Subtitle.modulate.a = 0.0
	$Author.visible = false
	$Author.modulate.a = 0.0
