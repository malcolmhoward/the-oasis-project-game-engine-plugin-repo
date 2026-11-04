## Single topology node — labeled box with status indicator and pulse-on-message.
##
## Positioned in relative coordinates (0.0-1.0) of its parent container so the
## same config works at any viewport size. The parent overlay calls update_layout()
## on resize.
##
## State:
##   online   — drives accent color (online: accent, offline: dim)
##   pulse    — brief glow when a message arrives at this node (decays per frame)
##
## Public API:
##   set_online(bool)         — update online state, triggers redraw
##   trigger_pulse(strength)  — briefly highlight (0.0–1.0, decays via PULSE_DECAY)
extends Control
## Loaded via path: const NODE_SCRIPT := preload("res://addons/oasis_ocp/visualization/topology_node.gd")


const PULSE_DECAY := 3.0
const DOT_RADIUS := 5.0
const DOT_OFFSET := Vector2(15, 18)
const TITLE_OFFSET := Vector2(28, 22)
const SUBTITLE_OFFSET := Vector2(28, 42)
const STATUS_MARGIN := 12.0

const FONT_TITLE := 14
const FONT_SUBTITLE := 11
const FONT_STATUS := 11

# --- Default palette (overridable via set_palette) ---
const DEFAULT_BOX_BG := Color("1a1e24")
const DEFAULT_OFFLINE := Color("444444")
const DEFAULT_LIVE := Color("44dd88")
const DEFAULT_OFFLINE_DOT := Color("ef4444")
const DEFAULT_DIM := Color("888888")


var node_id: String = ""
var label_text: String = ""
var subtitle_text: String = ""
var role: String = "consumer"
var accent_color: Color = Color("2dd4bf")
var online_indicator: String = "always"  # "always" | "mqtt_connected" | "topic_seen:<pattern>"

var _online: bool = true
var _pulse: float = 0.0
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func configure(spec: Dictionary, palette: Dictionary = {}) -> void:
	node_id = spec.get("id", "")
	label_text = spec.get("label", node_id)
	subtitle_text = spec.get("subtitle", "")
	role = spec.get("role", "consumer")
	online_indicator = spec.get("online_indicator", "always")
	var color_name: String = spec.get("color", "")
	if color_name and palette.has(color_name):
		accent_color = palette[color_name]
	elif color_name.begins_with("#"):
		accent_color = Color(color_name)
	queue_redraw()


func set_font(font: Font) -> void:
	_font = font
	queue_redraw()


func set_online(online: bool) -> void:
	if _online != online:
		_online = online
		queue_redraw()


func trigger_pulse(strength: float = 1.0) -> void:
	_pulse = max(_pulse, strength)


func get_anchor_point(side: String) -> Vector2:
	# Returns a center-edge point on this node's rect, in parent coordinates.
	var center_y = size.y / 2.0
	match side:
		"left":   return position + Vector2(0, center_y)
		"right":  return position + Vector2(size.x, center_y)
		"top":    return position + Vector2(size.x / 2.0, 0)
		"bottom": return position + Vector2(size.x / 2.0, size.y)
		_:        return position + size / 2.0


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = max(0.0, _pulse - delta * PULSE_DECAY)
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var border_color := accent_color if _online else DEFAULT_OFFLINE
	# Glow tint while pulsing
	if _pulse > 0.0:
		border_color = border_color.lerp(Color(1, 1, 1), _pulse * 0.4)

	draw_rect(rect, DEFAULT_BOX_BG)
	draw_rect(rect, border_color, false, 2.0)

	var dot_color := DEFAULT_LIVE if _online else DEFAULT_OFFLINE_DOT
	draw_circle(DOT_OFFSET, DOT_RADIUS, dot_color)

	var font := _font if _font else ThemeDB.fallback_font
	draw_string(font, TITLE_OFFSET, label_text,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, FONT_TITLE, accent_color)
	if subtitle_text:
		draw_string(font, SUBTITLE_OFFSET, subtitle_text,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, FONT_SUBTITLE, DEFAULT_DIM)

	var status := "● RUNNING" if _online else "● OFFLINE"
	draw_string(font, Vector2(15, size.y - STATUS_MARGIN), status,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, FONT_STATUS, dot_color)
