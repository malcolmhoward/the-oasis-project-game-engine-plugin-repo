extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

# Design tokens
const BG_DEEPEST := Color("121417")
const ARC_CORE := Color("2dd4bf")
const TEXT_PRIMARY := Color("e6e6e6")
const TEXT_SECONDARY := Color("a0a0a0")
const TEXT_TERTIARY := Color("666666")


func _ready() -> void:
	total_steps = 5

	# Title — bold accent
	var title := $Title as Label
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", ARC_CORE)

	# Problem text — primary, emphasis
	var problem1 := $ProblemLine1 as Label
	problem1.add_theme_font_size_override("font_size", 32)
	problem1.add_theme_color_override("font_color", TEXT_PRIMARY)

	var problem2 := $ProblemLine2 as Label
	problem2.add_theme_font_size_override("font_size", 32)
	problem2.add_theme_color_override("font_color", TEXT_SECONDARY)

	# Solution — accent, stands out
	var sol_header := $SolutionHeader as Label
	sol_header.add_theme_font_size_override("font_size", 36)
	sol_header.add_theme_color_override("font_color", TEXT_PRIMARY)

	var sol_detail := $SolutionDetail as Label
	sol_detail.add_theme_font_size_override("font_size", 36)
	sol_detail.add_theme_color_override("font_color", ARC_CORE)

	# Accessibility callout
	var access := $AccessibilityLine as Label
	access.add_theme_font_size_override("font_size", 30)
	access.add_theme_color_override("font_color", TEXT_PRIMARY)


func _animate_step(step: int) -> void:
	match step:
		1: _fade_in($Title, 0.4)
		2:
			_fade_in($ProblemLine1, 0.3)
			_fade_in($ProblemLine2, 0.3, 0.2)
		3: _slide_up($SolutionHeader, 0.4, 20.0)
		4: _fade_in($SolutionDetail, 0.3, 0.1)
		5: _slide_up($AccessibilityLine, 0.5, 25.0)


func _reset_animations() -> void:
	for node_name in ["Title", "ProblemLine1", "ProblemLine2",
			"SolutionHeader", "SolutionDetail", "AccessibilityLine"]:
		var node := get_node(node_name) as Control
		node.visible = false
		node.modulate.a = 0.0
