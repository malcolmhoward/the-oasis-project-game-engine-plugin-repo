## M.I.R.A.G.E. pitch ladder — drawn horizon line with degree marks.
##
## Centered on the reticle. The horizon line shifts vertically with the
## current pitch (positive pitch = nose up = horizon below center).
## Degree marks every 10° span the visible vertical range with short
## tick lines and rolled labels.
extends Control

const MH = preload("res://resources/mirage_design_tokens.gd")

@export var pitch_deg: float = 0.0:
	set(value):
		pitch_deg = clamp(value, -90.0, 90.0)
		queue_redraw()

@export var pixels_per_degree: float = 6.0
@export var tick_step_deg: float = 10.0
@export var horizon_width: float = 240.0
@export var tick_width: float = 80.0

var _font: Font = null
var _font_size: int = 12


func _ready() -> void:
	# Pick up the parent HUD's devgothic font when available.
	var hud := get_parent()
	while hud != null and not hud.has_method("_load_overlay_textures"):
		hud = hud.get_parent()
	if hud and hud.get("_devgothic"):
		_font = hud._devgothic
	if _font == null:
		_font = ThemeDB.fallback_font


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var center_x: float = w * 0.5
	var center_y: float = h * 0.5
	var color: Color = MH.PRIMARY_CYAN

	# The 0° horizon is offset by pitch_deg * pixels_per_degree from center.
	# Positive pitch tilts horizon downward in the view.
	var horizon_offset_y: float = pitch_deg * pixels_per_degree

	# Degree range that fits within the widget's height.
	var deg_radius: float = (h * 0.5) / pixels_per_degree
	var min_deg: float = floor((pitch_deg - deg_radius) / tick_step_deg) * tick_step_deg
	var max_deg: float = ceil((pitch_deg + deg_radius) / tick_step_deg) * tick_step_deg

	var deg: float = min_deg
	while deg <= max_deg:
		# Y coordinate for this degree mark within the widget's local space.
		var y: float = center_y - (deg - pitch_deg) * pixels_per_degree
		if y < 0 or y > h:
			deg += tick_step_deg
			continue

		var is_horizon: bool = absf(deg) < 0.01
		var line_color: Color = color
		var line_w: float = horizon_width if is_horizon else tick_width
		if is_horizon:
			# Horizon: full bright, slightly thicker, gap at center.
			var gap: float = 24.0
			draw_line(Vector2(center_x - line_w * 0.5, y), Vector2(center_x - gap, y), line_color, 2.0)
			draw_line(Vector2(center_x + gap, y), Vector2(center_x + line_w * 0.5, y), line_color, 2.0)
		else:
			# Pitch tick: shorter, dimmed for negative (nose-down).
			line_color.a = 0.85 if deg > 0 else 0.55
			draw_line(Vector2(center_x - line_w * 0.5, y), Vector2(center_x + line_w * 0.5, y), line_color, 1.0)
			# Numeric label on each side.
			if _font:
				var label_text: String = "%d" % int(absf(deg))
				var text_size: Vector2 = _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, _font_size)
				var label_color: Color = line_color
				draw_string(_font,
					Vector2(center_x - line_w * 0.5 - text_size.x - 4, y + text_size.y * 0.3),
					label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, _font_size, label_color)
				draw_string(_font,
					Vector2(center_x + line_w * 0.5 + 4, y + text_size.y * 0.3),
					label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, _font_size, label_color)
		deg += tick_step_deg
