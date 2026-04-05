## Embodiment Spectrum slide — draws an interactive spectrum showing
## D.A.W.N.'s range of embodiment options from virtual to physical.
##
## 8 animation steps:
##   1: Gradient bar draws
##   2-6: Each anchor point appears (left to right)
##   7: D.A.W.N. label + connection lines
##   8: All visible + pulse animation
extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

const BAR_Y := 400.0
const BAR_LEFT := 200.0
const BAR_RIGHT := 1720.0
const BAR_HEIGHT := 12.0
const POINT_Y := BAR_Y
const LABEL_Y := BAR_Y + 50.0
const ICON_Y := BAR_Y - 70.0
const DAWN_Y := 650.0

const COLOR_COOL := Color("#4488cc")
const COLOR_WARM := Color("#cc8844")
const COLOR_ACCENT := Color("#2dd4bf")
const COLOR_LABEL := Color("#cccccc")
const COLOR_DAWN := Color("#2dd4bf")
const COLOR_OCP := Color("#88aacc")
const COLOR_DIM := Color("#333333")

var _bar_progress := 0.0  # 0.0 to 1.0 for animated bar draw
var _visible_points: Array[bool] = [false, false, false, false, false]
var _dawn_visible := false
var _pulse_active := false
var _pulse_timer := 0.0
var _canvas: Control = null

var _point_names: Array[String] = [
	"Virtual\nPresence",
	"E.C.H.O.\nSimulation",
	"Game Engine\nAvatar",
	"Wearable /\nCosplay",
	"Autonomous\nBody",
]


func _ready():
	total_steps = 8

	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_on_canvas_draw)


func _process(delta: float):
	if _pulse_active:
		_pulse_timer += delta
		_canvas.queue_redraw()


func _animate_step(step: int) -> void:
	match step:
		1:
			# Bar draws in
			var tween = create_tween()
			tween.tween_method(_set_bar_progress, 0.0, 1.0, 0.6)
		2:
			_visible_points[0] = true
			_canvas.queue_redraw()
		3:
			_visible_points[1] = true
			_canvas.queue_redraw()
		4:
			_visible_points[2] = true
			_canvas.queue_redraw()
		5:
			_visible_points[3] = true
			_canvas.queue_redraw()
		6:
			_visible_points[4] = true
			_canvas.queue_redraw()
		7:
			_dawn_visible = true
			_canvas.queue_redraw()
		8:
			_pulse_active = true
			# Ensure everything is visible
			for i in range(5):
				_visible_points[i] = true
			_dawn_visible = true
			_canvas.queue_redraw()


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			_bar_progress = 1.0
		2: _visible_points[0] = true
		3: _visible_points[1] = true
		4: _visible_points[2] = true
		5: _visible_points[3] = true
		6: _visible_points[4] = true
		7: _dawn_visible = true
		8:
			_pulse_active = true
			for i in range(5):
				_visible_points[i] = true
			_dawn_visible = true
	_canvas.queue_redraw()


func _reset_animations() -> void:
	_bar_progress = 0.0
	_visible_points = [false, false, false, false, false]
	_dawn_visible = false
	_pulse_active = false
	_pulse_timer = 0.0
	_canvas.queue_redraw()


func _set_bar_progress(value: float) -> void:
	_bar_progress = value
	_canvas.queue_redraw()


func _on_canvas_draw() -> void:
	# Title
	var title_font = ThemeDB.fallback_font
	var title_size = 56
	_canvas.draw_string(title_font, Vector2(960 - 250, 100), "Embodiment Spectrum",
		HORIZONTAL_ALIGNMENT_CENTER, -1, title_size, COLOR_ACCENT)

	# Gradient bar
	if _bar_progress > 0.0:
		var bar_width = (BAR_RIGHT - BAR_LEFT) * _bar_progress
		var segments = int(bar_width / 4.0)
		if segments < 1:
			segments = 1
		var seg_width = bar_width / segments
		for i in range(segments):
			var t = float(i) / max(segments - 1, 1)
			var color = COLOR_COOL.lerp(COLOR_WARM, t)
			var x = BAR_LEFT + i * seg_width
			_canvas.draw_rect(Rect2(x, BAR_Y - BAR_HEIGHT / 2.0, seg_width + 1, BAR_HEIGHT), color)

		# OCP label along the bar
		var ocp_font_size = 18
		_canvas.draw_string(title_font, Vector2(BAR_LEFT + bar_width / 2.0 - 15, BAR_Y - BAR_HEIGHT / 2.0 - 15),
			"OCP", HORIZONTAL_ALIGNMENT_CENTER, -1, ocp_font_size, COLOR_OCP)

	# Anchor points
	var bar_span = BAR_RIGHT - BAR_LEFT
	for i in range(5):
		if not _visible_points[i]:
			continue

		var x = BAR_LEFT + bar_span * (float(i) / 4.0)
		var pulse_offset = 0.0
		if _pulse_active:
			pulse_offset = sin(_pulse_timer * 2.0 + i * 0.8) * 3.0

		# Vertical tick on bar
		_canvas.draw_line(Vector2(x, BAR_Y - 15), Vector2(x, BAR_Y + 15), COLOR_LABEL, 2.0)

		# Icon above the point
		_draw_icon(i, Vector2(x, ICON_Y + pulse_offset))

		# Label below the point
		var label_font_size = 18
		var lines = _point_names[i].split("\n")
		for li in range(lines.size()):
			_canvas.draw_string(title_font,
				Vector2(x - 60, LABEL_Y + 25 + li * 22),
				lines[li], HORIZONTAL_ALIGNMENT_CENTER, 120, label_font_size, COLOR_LABEL)

	# D.A.W.N. label and connection lines
	if _dawn_visible:
		var dawn_font_size = 36
		var dawn_x = (BAR_LEFT + BAR_RIGHT) / 2.0
		_canvas.draw_string(title_font, Vector2(dawn_x - 60, DAWN_Y),
			"D.A.W.N.", HORIZONTAL_ALIGNMENT_CENTER, -1, dawn_font_size, COLOR_DAWN)

		# Connection lines from DAWN to each point
		for i in range(5):
			if _visible_points[i]:
				var px = BAR_LEFT + bar_span * (float(i) / 4.0)
				var line_color = COLOR_DAWN
				line_color.a = 0.4
				_canvas.draw_line(Vector2(dawn_x, DAWN_Y - 30), Vector2(px, BAR_Y + 20), line_color, 1.5)


func _draw_icon(index: int, center: Vector2) -> void:
	match index:
		0:
			# Virtual Presence — concentric circles
			_canvas.draw_arc(center, 20, 0, TAU, 24, COLOR_ACCENT, 2.0)
			_canvas.draw_arc(center, 12, 0, TAU, 16, COLOR_ACCENT, 1.5)
			_canvas.draw_circle(center, 4, COLOR_ACCENT)
		1:
			# E.C.H.O. Simulation — wireframe cube
			var s = 16.0
			var offset = Vector2(-s, -s * 0.6)
			var pts_front = [
				center + offset,
				center + offset + Vector2(s * 2, 0),
				center + offset + Vector2(s * 2, s * 1.2),
				center + offset + Vector2(0, s * 1.2),
			]
			for j in range(4):
				_canvas.draw_line(pts_front[j], pts_front[(j + 1) % 4], COLOR_ACCENT, 1.5)
			var depth = Vector2(8, -6)
			for j in range(4):
				var back = pts_front[j] + depth
				_canvas.draw_line(pts_front[j], back, COLOR_ACCENT, 1.0)
		2:
			# Game Engine Avatar — triangle (character silhouette)
			var pts = PackedVector2Array([
				center + Vector2(0, -22),
				center + Vector2(-18, 18),
				center + Vector2(18, 18),
			])
			_canvas.draw_polyline(pts, COLOR_ACCENT, 2.0)
			_canvas.draw_line(pts[2], pts[0], COLOR_ACCENT, 2.0)
		3:
			# Wearable / Cosplay — helmet arc
			_canvas.draw_arc(center + Vector2(0, 5), 18, PI + 0.3, TAU - 0.3, 16, COLOR_ACCENT, 2.0)
			_canvas.draw_line(center + Vector2(-14, 10), center + Vector2(14, 10), COLOR_ACCENT, 2.0)
			# Visor line
			_canvas.draw_arc(center + Vector2(0, 2), 12, PI + 0.5, TAU - 0.5, 12, COLOR_ACCENT, 1.5)
		4:
			# Autonomous Body — box with antenna
			var half = 14.0
			_canvas.draw_rect(Rect2(center.x - half, center.y - half + 4, half * 2, half * 2), Color.TRANSPARENT, false, 2.0)
			# Override with draw_line for rect border (draw_rect unfilled uses default white)
			var tl = center + Vector2(-half, -half + 4)
			var tr = center + Vector2(half, -half + 4)
			var br = center + Vector2(half, half + 4)
			var bl = center + Vector2(-half, half + 4)
			_canvas.draw_line(tl, tr, COLOR_ACCENT, 2.0)
			_canvas.draw_line(tr, br, COLOR_ACCENT, 2.0)
			_canvas.draw_line(br, bl, COLOR_ACCENT, 2.0)
			_canvas.draw_line(bl, tl, COLOR_ACCENT, 2.0)
			# Antenna
			_canvas.draw_line(center + Vector2(0, -half + 4), center + Vector2(0, -half - 12), COLOR_ACCENT, 2.0)
			_canvas.draw_circle(center + Vector2(0, -half - 14), 3, COLOR_ACCENT)
