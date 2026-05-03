## D.A.W.N. telemetry rings — three circular progress indicators driven by
## dawn/events `metrics_update` payloads.
##
## Layout: TTFT | TOKEN RATE | CONTEXT %, equally spaced across the widget.
## Each ring shows a value, a unit, and a swept arc whose fill ratio reflects
## the current value relative to a per-metric range. Colour follows the
## ArcReactorDark accent unless the metric is in a "warning" zone (slow TTFT,
## low token rate, near-full context), in which case it shifts to amber.
##
## "No data" state: rings render dimmed with "—" placeholders. set_metrics()
## clears that state on first call.
extends Control

const ArcReactor = preload("res://resources/design_tokens.gd")

# Per-metric range and threshold values used for the swept arc fill ratio.
const TTFT_GOOD_MS: float = 200.0   # below this is "fast"
const TTFT_WARN_MS: float = 1500.0  # above this is "slow" — fill saturates here
const TOKENS_GOOD: float = 30.0     # above this is "fast" — fill saturates at 100
const TOKENS_WARN: float = 5.0      # below this is "slow"
const CONTEXT_WARN_PCT: float = 75.0  # above this turns amber

@export var ttft_ms: float = -1.0
@export var token_rate: float = -1.0
@export var context_percent: float = -1.0

var _font: Font = null
var _label_size: int = 10
var _value_size: int = 18


func _ready() -> void:
	_font = _resolve_mono_font()
	queue_redraw()


func _resolve_mono_font() -> Font:
	if ResourceLoader.exists(ArcReactor.FONT_MONO_PATH):
		return load(ArcReactor.FONT_MONO_PATH)
	return ThemeDB.fallback_font


## Update all three metrics in one call. Call from dawn_ui.gd's metrics
## event handler. Pass NAN or a negative number to leave a metric in
## the "no data" state without clearing the others.
func set_metrics(ttft: float, tokens: float, context: float) -> void:
	if ttft >= 0.0:
		ttft_ms = ttft
	if tokens >= 0.0:
		token_rate = tokens
	if context >= 0.0:
		context_percent = context
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0 or h <= 0:
		return
	var slot_width: float = w / 3.0
	var radius: float = min(slot_width * 0.36, h * 0.4)
	var center_y: float = h * 0.5

	for i in range(3):
		var center := Vector2(slot_width * (i + 0.5), center_y)
		match i:
			0: _draw_ring(center, radius, "TTFT", _ttft_label(), _ttft_fill(), _ttft_warn())
			1: _draw_ring(center, radius, "TOK/s", _tokens_label(), _tokens_fill(), _tokens_warn())
			2: _draw_ring(center, radius, "CTX %", _context_label(), _context_fill(), _context_warn())


func _draw_ring(center: Vector2, radius: float, label: String, value_text: String,
		fill: float, is_warning: bool) -> void:
	var inactive: Color = ArcReactor.BG_ELEVATED
	var active: Color = ArcReactor.STATUS_WARNING if is_warning else ArcReactor.ARC_CORE
	if fill < 0.0:
		# No-data state — dim everything.
		inactive = Color(ArcReactor.BG_ELEVATED.r, ArcReactor.BG_ELEVATED.g, ArcReactor.BG_ELEVATED.b, 0.5)
		active = inactive

	# Background ring (full circle).
	_draw_arc_ring(center, radius, 0.0, TAU, inactive, 3.0)

	# Active arc clamped to [0, 1] of the full circle.
	if fill > 0.0:
		var sweep: float = clamp(fill, 0.0, 1.0) * TAU
		# Start at the top (-PI/2) and sweep clockwise.
		_draw_arc_ring(center, radius, -PI * 0.5, -PI * 0.5 + sweep, active, 3.0)

	# Centered value text.
	if _font:
		var value_color: Color = ArcReactor.TEXT_PRIMARY if fill >= 0.0 else ArcReactor.TEXT_TERTIARY
		var value_metrics: Vector2 = _font.get_string_size(
			value_text, HORIZONTAL_ALIGNMENT_CENTER, -1, _value_size)
		draw_string(_font,
			Vector2(center.x - value_metrics.x * 0.5, center.y + value_metrics.y * 0.25),
			value_text, HORIZONTAL_ALIGNMENT_CENTER, -1, _value_size, value_color)

		var label_metrics: Vector2 = _font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, _label_size)
		draw_string(_font,
			Vector2(center.x - label_metrics.x * 0.5, center.y + radius + label_metrics.y + 2),
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, _label_size, ArcReactor.TEXT_SECONDARY)


func _draw_arc_ring(center: Vector2, radius: float, start_angle: float,
		end_angle: float, color: Color, thickness: float) -> void:
	# Godot's draw_arc handles the segments; pick a reasonable point count.
	var point_count: int = max(16, int(absf(end_angle - start_angle) / TAU * 64))
	draw_arc(center, radius, start_angle, end_angle, point_count, color, thickness, true)


# ─── Per-metric label / fill / warning helpers ────────────────────────────

func _ttft_label() -> String:
	if ttft_ms < 0.0:
		return "—"
	if ttft_ms < 1000.0:
		return "%d ms" % int(round(ttft_ms))
	return "%.1f s" % (ttft_ms / 1000.0)


func _ttft_fill() -> float:
	if ttft_ms < 0.0:
		return -1.0
	# Faster TTFT = more arc filled. Below TTFT_GOOD_MS -> 1.0; above
	# TTFT_WARN_MS -> 0.0; linear interpolation in between.
	if ttft_ms <= TTFT_GOOD_MS:
		return 1.0
	if ttft_ms >= TTFT_WARN_MS:
		return 0.05  # leave a sliver so the ring isn't empty
	return clamp(1.0 - (ttft_ms - TTFT_GOOD_MS) / (TTFT_WARN_MS - TTFT_GOOD_MS), 0.05, 1.0)


func _ttft_warn() -> bool:
	return ttft_ms > TTFT_WARN_MS * 0.66


func _tokens_label() -> String:
	if token_rate < 0.0:
		return "—"
	return "%d" % int(round(token_rate))


func _tokens_fill() -> float:
	if token_rate < 0.0:
		return -1.0
	# Faster token rate = more fill. Saturate at TOKENS_GOOD * 1.5 so
	# good-but-not-amazing rates still show meaningful fill.
	return clamp(token_rate / (TOKENS_GOOD * 1.5), 0.0, 1.0)


func _tokens_warn() -> bool:
	return token_rate >= 0.0 and token_rate < TOKENS_WARN


func _context_label() -> String:
	if context_percent < 0.0:
		return "—"
	return "%d%%" % int(round(context_percent))


func _context_fill() -> float:
	if context_percent < 0.0:
		return -1.0
	return clamp(context_percent / 100.0, 0.0, 1.0)


func _context_warn() -> bool:
	return context_percent > CONTEXT_WARN_PCT
