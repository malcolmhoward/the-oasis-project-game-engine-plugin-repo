## M.I.R.A.G.E. compass strip — horizontal heading ribbon.
##
## Draws a centered ruler with degree ticks every 5°, labeled cardinals at
## 0/90/180/270 and ordinals at 45/135/225/315. The current heading is
## anchored at the strip's horizontal center; a downward chevron marks it.
extends Control

const MH = preload("res://resources/mirage_design_tokens.gd")

@export var heading_deg: float = 0.0:
	set(value):
		heading_deg = fposmod(value, 360.0)
		queue_redraw()

@export var pixels_per_degree: float = 5.0
@export var minor_tick_step: float = 5.0
@export var major_tick_step: float = 30.0
@export var label_step: float = 30.0

var _font: Font = null
var _font_size: int = 14


func _ready() -> void:
	# Try to use the M.I.R.A.G.E. devgothic font if loaded, else IBM Plex.
	var hud := get_parent()
	while hud != null and not hud.has_method("_load_overlay_textures"):
		hud = hud.get_parent()
	if hud and hud.get("_devgothic"):
		_font = hud._devgothic
	if _font == null:
		_font = ThemeDB.fallback_font


func _draw() -> void:
	var w := size.x
	var h := size.y
	var center_x := w * 0.5
	var baseline_y := h * 0.55

	# Underline along the strip
	var line_color := MH.PRIMARY_CYAN
	line_color.a = 0.35
	draw_line(Vector2(0, baseline_y), Vector2(w, baseline_y), line_color, 1.0)

	# Determine the visible degree range based on width.
	var deg_radius := (w * 0.5) / pixels_per_degree

	# Iterate from heading - radius to heading + radius in 1° steps and snap to
	# minor_tick_step. This is the simplest robust approach and width-bounded.
	var start_deg := heading_deg - deg_radius
	var end_deg := heading_deg + deg_radius
	# Snap start_deg up to the nearest minor_tick_step
	var first_tick := ceil(start_deg / minor_tick_step) * minor_tick_step

	var deg := first_tick
	while deg <= end_deg:
		var screen_x := center_x + (deg - heading_deg) * pixels_per_degree
		var normalized := fposmod(deg, 360.0)
		var is_major := fmod(normalized, major_tick_step) < 0.01
		var is_label := fmod(normalized, label_step) < 0.01

		var tick_color := MH.PRIMARY_CYAN
		var tick_h := 6.0
		if is_major:
			tick_h = 14.0
		else:
			tick_color.a = 0.55

		draw_line(
			Vector2(screen_x, baseline_y),
			Vector2(screen_x, baseline_y - tick_h),
			tick_color, 1.0
		)

		if is_label and _font:
			var label := _heading_label(normalized)
			var label_color := MH.PRIMARY_CYAN
			# Cardinals slightly brighter than numeric labels.
			if label.length() <= 2:
				label_color = MH.SECONDARY_CYAN if label.length() == 2 else MH.PRIMARY_CYAN
			var text_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, _font_size)
			draw_string(
				_font,
				Vector2(screen_x - text_size.x * 0.5, baseline_y - tick_h - 4),
				label,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				_font_size,
				label_color
			)
		deg += minor_tick_step

	# Center marker — downward chevron pointing at current heading.
	var marker_color := MH.PRIMARY_CYAN
	var marker_pts := PackedVector2Array([
		Vector2(center_x, baseline_y + 8),
		Vector2(center_x - 6, baseline_y + 18),
		Vector2(center_x + 6, baseline_y + 18),
	])
	draw_colored_polygon(marker_pts, marker_color)


func _heading_label(deg: float) -> String:
	# Cardinal/ordinal substitutions at the 8 standard points; 3-digit otherwise.
	var rounded := round(deg) as int
	rounded = rounded % 360
	match rounded:
		0:   return "N"
		45:  return "NE"
		90:  return "E"
		135: return "SE"
		180: return "S"
		225: return "SW"
		270: return "W"
		315: return "NW"
	return "%03d" % rounded
