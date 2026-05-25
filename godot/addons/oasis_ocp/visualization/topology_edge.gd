## Topology edge — directed connection between two nodes with animated message
## particles. The edge knows its endpoint nodes (by reference); it queries them
## for anchor points on each draw, so node movement is automatic.
##
## State:
##   pulse     — connection-line glow when a message arrives (decays)
##   particles — array of envelope-shaped dots traveling 0→1 along the line
##
## Public API:
##   configure(spec, palette, from_node, to_node)
##   spawn_particle(color)     — adds one particle to the edge
##   trigger_pulse(strength)   — momentary edge highlight
extends Control
## Loaded via path: const EDGE_SCRIPT := preload("res://addons/oasis_ocp/visualization/topology_edge.gd")


const PULSE_DECAY := 3.0
const PARTICLE_SPEED := 1.8       # 0→1 traversal per second
const PARTICLE_FADE := 0.5        # alpha fade by end of traversal
const MAX_PARTICLES := 6
const ARROW_SIZE := 8.0
const CONN_INSET := 10.0          # arrow endpoint inset from node edge
const ENV_W := 10.0
const ENV_H := 7.0
const CONN_LABEL_Y := -12.0

const FONT_CONN_LABEL := 10
const DEFAULT_BASE := Color("333333")
const DEFAULT_HIGHLIGHT := Color("2dd4bf")
const DEFAULT_LABEL_DIM := Color("666666")


var edge_id: String = ""
var label_text: String = ""
var from_node = null
var to_node = null
var topic_patterns: Array = []
var highlight_color: Color = DEFAULT_HIGHLIGHT

var _pulse: float = 0.0
var _particles: Array = []
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func configure(spec: Dictionary, palette: Dictionary,
		from: Control, to: Control) -> void:
	edge_id = "%s_to_%s" % [spec.get("from", ""), spec.get("to", "")]
	label_text = spec.get("label", "")
	from_node = from
	to_node = to
	topic_patterns = spec.get("topics", [])
	var color_name: String = spec.get("color", "")
	if color_name and palette.has(color_name):
		highlight_color = palette[color_name]
	elif color_name.begins_with("#"):
		highlight_color = Color(color_name)
	queue_redraw()


func set_font(font: Font) -> void:
	_font = font
	queue_redraw()


func matches_topic(topic: String) -> bool:
	for pattern in topic_patterns:
		if _topic_matches(topic, pattern):
			return true
	return false


## MQTT-style topic matcher.
## Supports: exact, `+` (single level), `#` (multi level), and `*/<suffix>`.
static func _topic_matches(topic: String, pattern: String) -> bool:
	if pattern == topic:
		return true
	if pattern == "#":
		return true
	# Suffix wildcard: `*/<suffix>` matches any-prefix + slash + literal suffix
	if pattern.begins_with("*/"):
		return topic.ends_with(pattern.substr(1))
	# Split-by-level matching for + and #
	var pp := pattern.split("/")
	var tp := topic.split("/")
	var i := 0
	while i < pp.size():
		if pp[i] == "#":
			return true
		if i >= tp.size():
			return false
		if pp[i] == "+":
			pass  # any one level OK
		elif pp[i] != tp[i]:
			return false
		i += 1
	return i == tp.size()


func trigger_pulse(strength: float = 1.0) -> void:
	_pulse = max(_pulse, strength)


func spawn_particle(color: Color) -> void:
	if _particles.size() >= MAX_PARTICLES:
		return
	_particles.append({"progress": 0.0, "color": color})


func _process(delta: float) -> void:
	var dirty := false
	if _pulse > 0.0:
		_pulse = max(0.0, _pulse - delta * PULSE_DECAY)
		dirty = true
	if _particles.size() > 0:
		var alive := []
		for p in _particles:
			p["progress"] += delta * PARTICLE_SPEED
			if p["progress"] < 1.0:
				alive.append(p)
		_particles = alive
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	if from_node == null or to_node == null:
		return

	var from_pt: Vector2 = from_node.get_anchor_point("right")
	var to_pt: Vector2 = to_node.get_anchor_point("left")
	# Inset so the arrow lands inside the to-node visually
	var dir: Vector2 = (to_pt - from_pt).normalized()
	to_pt -= dir * CONN_INSET

	var color: Color = DEFAULT_BASE.lerp(highlight_color, _pulse)
	var thickness: float = 1.5 + _pulse * 2.0
	draw_line(from_pt, to_pt, color, thickness)

	# Arrow head
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	draw_line(to_pt, to_pt - dir * ARROW_SIZE + perp * ARROW_SIZE * 0.5, color, thickness)
	draw_line(to_pt, to_pt - dir * ARROW_SIZE - perp * ARROW_SIZE * 0.5, color, thickness)

	# Label centered above mid-line
	if label_text:
		var mid: Vector2 = (from_pt + to_pt) / 2.0 + Vector2(0, CONN_LABEL_Y)
		var font := _font if _font else ThemeDB.fallback_font
		draw_string(font, mid, label_text,
			HORIZONTAL_ALIGNMENT_CENTER, 120, FONT_CONN_LABEL, DEFAULT_LABEL_DIM)

	# Particles
	var half_w := ENV_W / 2.0
	var half_h := ENV_H / 2.0
	for p in _particles:
		var pos: Vector2 = from_pt.lerp(to_pt, p["progress"])
		var pcolor: Color = p["color"]
		pcolor.a = 1.0 - p["progress"] * PARTICLE_FADE
		draw_rect(Rect2(pos - Vector2(half_w, half_h), Vector2(ENV_W, ENV_H)), pcolor)
		draw_line(pos + Vector2(-half_w, -half_h), pos, pcolor, 1.0)
		draw_line(pos + Vector2(half_w, -half_h), pos, pcolor, 1.0)
