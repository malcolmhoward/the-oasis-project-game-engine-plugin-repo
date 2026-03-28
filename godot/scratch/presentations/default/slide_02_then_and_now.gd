extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

# Design tokens
const BG_DEEPEST := Color("121417")
const ARC_CORE := Color("2dd4bf")
const TEXT_PRIMARY := Color("e6e6e6")
const TEXT_SECONDARY := Color("a0a0a0")
const TEXT_TERTIARY := Color("666666")

# Paired items: left index -> right index
var _left_items: Array[Label] = []
var _right_items: Array[Label] = []


func _ready() -> void:
	total_steps = 3

	# Style headers
	var left_header := $LeftHeader as Label
	left_header.add_theme_font_size_override("font_size", 40)
	left_header.add_theme_color_override("font_color", TEXT_TERTIARY)

	var right_header := $RightHeader as Label
	right_header.add_theme_font_size_override("font_size", 40)
	right_header.add_theme_color_override("font_color", ARC_CORE)

	# Divider line
	$Divider.color = TEXT_TERTIARY

	# Collect items
	_left_items = [
		$LeftItem1, $LeftItem2, $LeftItem3, $LeftItem4
	]
	_right_items = [
		$RightItem1, $RightItem2, $RightItem3, $RightItem4
	]

	# Style all items
	for item in _left_items:
		item.add_theme_font_size_override("font_size", 32)
		item.add_theme_color_override("font_color", TEXT_SECONDARY)

	for item in _right_items:
		item.add_theme_font_size_override("font_size", 32)
		item.add_theme_color_override("font_color", TEXT_PRIMARY)

	# Hide all animated elements
	left_header.visible = false
	right_header.visible = false
	for item in _left_items:
		item.visible = false
	for item in _right_items:
		item.visible = false


func _animate_step(step: int) -> void:
	match step:
		1:
			# Both headers fade in together
			_fade_in($LeftHeader, 0.3)
			_fade_in($RightHeader, 0.3)
		2:
			# All left items slide in with staggered delays
			for i in _left_items.size():
				_slide_in_left(_left_items[i], 0.3, 40.0, i * 0.1)
		3:
			# All right items slide in with staggered delays (matching left)
			for i in _right_items.size():
				_slide_in_left(_right_items[i], 0.35, 40.0, i * 0.1)


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			$LeftHeader.visible = true
			$LeftHeader.modulate.a = 1.0
			$RightHeader.visible = true
			$RightHeader.modulate.a = 1.0
		2:
			for item in _left_items:
				item.visible = true
				item.modulate.a = 1.0
		3:
			for item in _right_items:
				item.visible = true
				item.modulate.a = 1.0


func _reset_animations() -> void:
	$LeftHeader.visible = false
	$LeftHeader.modulate.a = 0.0
	$RightHeader.visible = false
	$RightHeader.modulate.a = 0.0
	$Divider.visible = true
	for item in _left_items:
		item.visible = false
		item.modulate.a = 0.0
	for item in _right_items:
		item.visible = false
		item.modulate.a = 0.0
