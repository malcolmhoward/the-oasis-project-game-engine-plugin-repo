extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

const ARC_CORE := Color("2dd4bf")
const TEXT_TERTIARY := Color("666666")
const BADGE_GREEN := Color(0.2, 0.8, 0.4, 1)

var _rows: Array[Control] = []


func _ready():
	total_steps = 2

	# Style title
	$Title.add_theme_color_override("font_color", ARC_CORE)

	# Style header row — muted uppercase
	for hdr in [$HeaderRow/HdrType, $HeaderRow/HdrName, $HeaderRow/HdrDesc, $HeaderRow/HdrStatus]:
		hdr.add_theme_color_override("font_color", TEXT_TERTIARY)

	# Divider line
	$Divider.color = TEXT_TERTIARY

	_rows = [$RowE1, $RowE2, $RowE3, $RowE4, $RowE5]

	# Hide rows initially (header row stays visible)
	for row in _rows:
		row.visible = false

	# All embodiment types are implemented across ecosystem branches
	for row in _rows:
		var badge = row.get_node("Badge")
		badge.text = "Implemented"
		badge.add_theme_color_override("font_color", BADGE_GREEN)
		badge.visible = false


func _animate_step(step: int) -> void:
	match step:
		1:
			# All 5 rows slide in with staggered delays
			for i in _rows.size():
				_slide_in_left(_rows[i], 0.35, 40.0, i * 0.12)
		2:
			# All badges fade in with stagger
			for i in _rows.size():
				_fade_in(_rows[i].get_node("Badge"), 0.3, i * 0.08)


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			for row in _rows:
				row.visible = true
				row.modulate.a = 1.0
		2:
			for row in _rows:
				var badge = row.get_node("Badge")
				badge.visible = true
				badge.modulate.a = 1.0


func _reset_animations() -> void:
	for row in _rows:
		row.visible = false
		row.modulate.a = 0.0
		row.get_node("Badge").visible = false
		row.get_node("Badge").modulate.a = 0.0
