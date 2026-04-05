## Provider Pattern slide — shows the runtime hot-swap architecture
## using a three-column diagram with animated transitions.
##
## 6 animation steps:
##   1: Component Code box appears (left)
##   2: Provider box appears (center, accent border)
##   3: MockCamera box + arrow from provider (right, amber)
##   4: RealCamera slides in, MockCamera slides down (swap animation)
##   5: RealCamera fades, MockCamera slides back up (fallback)
##   6: Explanation text appears below
extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

const COLOR_ACCENT := Color("#2dd4bf")
const COLOR_BG := Color("#1a1e24")
const COLOR_MOCK := Color("#ccaa44")
const COLOR_REAL := Color("#44dd88")
const COLOR_TEXT := Color("#cccccc")
const COLOR_ARROW := Color("#888888")
const COLOR_DIM := Color("#444444")

# Layout constants
const COL_LEFT_X := 200.0
const COL_CENTER_X := 760.0
const COL_RIGHT_X := 1320.0
const BOX_WIDTH := 320.0
const BOX_HEIGHT := 160.0
const ROW_Y := 340.0
const MOCK_Y := 300.0
const REAL_Y := 500.0

var _component_box: PanelContainer = null
var _provider_box: PanelContainer = null
var _mock_box: PanelContainer = null
var _real_box: PanelContainer = null
var _arrow_left: Control = null
var _arrow_right: Control = null
var _explanation: Label = null
var _title_label: Label = null


func _ready():
	total_steps = 6

	# Title
	_title_label = Label.new()
	_title_label.text = "Provider Pattern \u2014 Runtime Hot-Swap"
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, 60)
	_title_label.size = Vector2(1920, 80)
	add_child(_title_label)

	# Component Code box (left column)
	_component_box = _create_box("Component Code", COL_LEFT_X, ROW_Y, COLOR_DIM, [
		"get_camera().capture()",
		"get_camera().stream()",
		"",
		"# Doesn't know which",
		"# implementation runs",
	])
	_component_box.visible = false
	add_child(_component_box)

	# Provider box (center column — accent border)
	_provider_box = _create_box("Provider", COL_CENTER_X, ROW_Y, COLOR_ACCENT, [
		"CameraProvider",
		"",
		"get_camera() ->",
		"  return _active",
		"",
		"swap(impl) ->",
		"  _active = impl",
	])
	_provider_box.visible = false
	add_child(_provider_box)

	# MockCamera box (right column, top — amber)
	_mock_box = _create_box("MockCamera", COL_RIGHT_X, MOCK_Y, COLOR_MOCK, [
		"capture() -> test_image",
		"stream() -> test_feed",
	])
	_mock_box.visible = false
	add_child(_mock_box)

	# RealCamera box (right column, bottom — green)
	_real_box = _create_box("RealCamera", COL_RIGHT_X, REAL_Y, COLOR_REAL, [
		"capture() -> hw_image",
		"stream() -> hw_feed",
	])
	_real_box.visible = false
	add_child(_real_box)

	# Arrow canvases
	_arrow_left = _create_arrow_canvas(
		Vector2(COL_LEFT_X + BOX_WIDTH, ROW_Y + BOX_HEIGHT / 2.0),
		Vector2(COL_CENTER_X, ROW_Y + BOX_HEIGHT / 2.0),
		COLOR_ARROW)
	_arrow_left.visible = false
	add_child(_arrow_left)

	_arrow_right = _create_arrow_canvas(
		Vector2(COL_CENTER_X + BOX_WIDTH, ROW_Y + BOX_HEIGHT / 2.0),
		Vector2(COL_RIGHT_X, MOCK_Y + BOX_HEIGHT / 2.0),
		COLOR_ACCENT)
	_arrow_right.visible = false
	add_child(_arrow_right)

	# Explanation text
	_explanation = Label.new()
	_explanation.text = "The Provider owns the active implementation reference.\nComponents call the interface — they never import a concrete class.\nSwapping at runtime requires zero code changes in consuming components."
	_explanation.add_theme_font_size_override("font_size", 22)
	_explanation.add_theme_color_override("font_color", COLOR_TEXT)
	_explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_explanation.position = Vector2(200, 740)
	_explanation.size = Vector2(1520, 120)
	_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explanation.visible = false
	add_child(_explanation)


func _animate_step(step: int) -> void:
	match step:
		1:
			_fade_in(_component_box)
			_fade_in(_arrow_left, 0.3, 0.2)
		2:
			_fade_in(_provider_box)
		3:
			_fade_in(_mock_box)
			_fade_in(_arrow_right, 0.3, 0.2)
		4:
			# Swap: RealCamera slides in from below, MockCamera dims
			_real_box.visible = true
			_real_box.modulate.a = 0.0
			_real_box.position.y = REAL_Y + 60
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(_real_box, "modulate:a", 1.0, 0.4)
			tween.tween_property(_real_box, "position:y", REAL_Y, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(_mock_box, "modulate:a", 0.3, 0.4)
			# Update arrow to point at RealCamera
			tween.chain().tween_callback(func():
				_arrow_right.queue_free()
				_arrow_right = _create_arrow_canvas(
					Vector2(COL_CENTER_X + BOX_WIDTH, ROW_Y + BOX_HEIGHT / 2.0),
					Vector2(COL_RIGHT_X, REAL_Y + BOX_HEIGHT / 2.0),
					COLOR_ACCENT)
				add_child(_arrow_right)
			)
		5:
			# Fallback: RealCamera fades, MockCamera restores
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(_real_box, "modulate:a", 0.3, 0.4)
			tween.tween_property(_mock_box, "modulate:a", 1.0, 0.4)
			# Restore arrow to MockCamera
			tween.chain().tween_callback(func():
				_arrow_right.queue_free()
				_arrow_right = _create_arrow_canvas(
					Vector2(COL_CENTER_X + BOX_WIDTH, ROW_Y + BOX_HEIGHT / 2.0),
					Vector2(COL_RIGHT_X, MOCK_Y + BOX_HEIGHT / 2.0),
					COLOR_ACCENT)
				add_child(_arrow_right)
			)
		6:
			_fade_in(_explanation)


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			_component_box.visible = true
			_component_box.modulate.a = 1.0
			_arrow_left.visible = true
			_arrow_left.modulate.a = 1.0
		2:
			_provider_box.visible = true
			_provider_box.modulate.a = 1.0
		3:
			_mock_box.visible = true
			_mock_box.modulate.a = 1.0
			_arrow_right.visible = true
			_arrow_right.modulate.a = 1.0
		4:
			_real_box.visible = true
			_real_box.modulate.a = 1.0
			_real_box.position.y = REAL_Y
			_mock_box.modulate.a = 0.3
		5:
			_real_box.modulate.a = 0.3
			_mock_box.modulate.a = 1.0
		6:
			_explanation.visible = true
			_explanation.modulate.a = 1.0


func _reset_animations() -> void:
	_component_box.visible = false
	_provider_box.visible = false
	_mock_box.visible = false
	_real_box.visible = false
	_arrow_left.visible = false
	_arrow_right.visible = false
	_explanation.visible = false
	_component_box.modulate.a = 1.0
	_provider_box.modulate.a = 1.0
	_mock_box.modulate.a = 1.0
	_real_box.modulate.a = 1.0
	_real_box.position.y = REAL_Y


func _create_box(title: String, x: float, y: float, border_color: Color, lines: Array) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.position = Vector2(x, y)
	panel.size = Vector2(BOX_WIDTH, BOX_HEIGHT)

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", border_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	vbox.add_child(sep)

	for line in lines:
		var lbl = Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", COLOR_TEXT)
		vbox.add_child(lbl)

	panel.add_child(vbox)
	return panel


func _create_arrow_canvas(from: Vector2, to: Vector2, color: Color) -> Control:
	var canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Store arrow endpoints in metadata for the draw callback
	canvas.set_meta("arrow_from", from)
	canvas.set_meta("arrow_to", to)
	canvas.set_meta("arrow_color", color)
	canvas.draw.connect(_draw_arrow.bind(canvas))
	return canvas


func _draw_arrow(canvas: Control) -> void:
	var from: Vector2 = canvas.get_meta("arrow_from")
	var to: Vector2 = canvas.get_meta("arrow_to")
	var color: Color = canvas.get_meta("arrow_color")

	# Line
	canvas.draw_line(from, to, color, 2.0)

	# Arrowhead
	var dir = (to - from).normalized()
	var perp = Vector2(-dir.y, dir.x)
	var head_size = 10.0
	var tip = to
	var left = tip - dir * head_size + perp * head_size * 0.5
	var right = tip - dir * head_size - perp * head_size * 0.5
	canvas.draw_polygon(PackedVector2Array([tip, left, right]), PackedColorArray([color, color, color]))
