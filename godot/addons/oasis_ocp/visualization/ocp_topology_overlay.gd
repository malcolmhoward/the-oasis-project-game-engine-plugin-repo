## Reusable OCP topology overlay.
##
## Loads a JSON topology config (nodes + edges + topic-color rules) and renders
## a live graph driven by MQTT messages from the OasisMQTT autoload.
##
## Demo wrapper scenes layer additional widgets (info panels, mock toggles,
## d-pads) as siblings over this overlay; this addon owns only the topology
## rendering itself.
##
## Embedding:
##   Add this scene as a child of any Control. Set config_path to a JSON config.
##   For runtime config switching, call load_config(path).
##
## Signals:
##   message_received(topic, payload, payload_bytes)
##   topic_seen(topic)
##   metrics_updated(clients, msg_count, subscriptions)
##
## Exposed properties (read-only, useful for external metrics consumers):
##   mqtt_connected, msg_count, msg_rate, active_topics (Dict topic→last-seen-unix)
extends Control
## Loaded via path: const OVERLAY_SCRIPT := preload("res://addons/oasis_ocp/visualization/ocp_topology_overlay.gd")


signal message_received(topic: String, payload: String, payload_bytes: int)
signal topic_seen(topic: String)
signal metrics_updated(clients: int, msg_count: int, subscriptions: int)


const NODE_SCRIPT := preload("res://addons/oasis_ocp/visualization/topology_node.gd")
const EDGE_SCRIPT := preload("res://addons/oasis_ocp/visualization/topology_edge.gd")

const TOPIC_STALE_SEC := 10.0
const RATE_INTERVAL := 1.0
const BG_COLOR := Color("121417")

# Default named palette — config color names resolve here.
const DEFAULT_PALETTE := {
	"MOCK":     Color("f0b429"),  # amber
	"BROKER":   Color("2dd4bf"),  # teal
	"GODOT":    Color("3b82f6"),  # blue
	"CONSUMER": Color("3b82f6"),  # blue
	"LIVE":     Color("44dd88"),  # green — real source
	"REAL":     Color("44dd88"),
	"ACCENT":   Color("2dd4bf"),  # teal
	"COMP_MIRAGE": Color("00F5FC"),
	"COMP_AURA":   Color("44dd88"),
	"COMP_STAT":   Color("3b82f6"),
	"COMP_DAWN":   Color("2dd4bf"),
	"CMD":     Color("f97316"),  # orange — command topics
	"DIM":     Color("888888"),
}


@export var config_path: String = ""
@export var background_color: Color = BG_COLOR
@export var draw_background: bool = true
@export var font_path: String = "res://resources/fonts/IBMPlexMono-Regular.ttf"


var mqtt_connected: bool = false
var msg_count: int = 0
var msg_rate: float = 0.0
var active_topics: Dictionary = {}     # topic -> last-seen-unix
var muted_topic_patterns: Array = []   # patterns suppressed from msg_count + particles
var broker_clients: int = 0
var broker_subscriptions: int = 0
var broker_msgs_received: int = 0

var _config: Dictionary = {}
var _palette: Dictionary = DEFAULT_PALETTE.duplicate()
var _topic_color_rules: Array = []     # ordered list of {pattern, color}
var _nodes_by_id: Dictionary = {}      # id -> OcpTopologyNode
var _edges: Array = []                 # OcpTopologyEdge
var _msg_count_last: int = 0
var _rate_timer: float = 0.0
var _font: Font = null
var _mqtt = null
var _config_loaded: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_relayout_children)
	if ResourceLoader.exists(font_path):
		_font = load(font_path)

	var oasis_mqtt := get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_message)
		_mqtt = oasis_mqtt.get_mqtt()
		if _mqtt:
			mqtt_connected = _mqtt.get_connection_state() == 3
			_mqtt.connected.connect(func(): _set_mqtt_connected(true))
			_mqtt.disconnected.connect(func(): _set_mqtt_connected(false))
			# Subscribe to $SYS topics for metrics
			for sys_topic in [
				"$SYS/broker/clients/connected",
				"$SYS/broker/messages/received",
				"$SYS/broker/subscriptions/count",
			]:
				_mqtt.subscribe(sys_topic, 0)

	if config_path:
		load_config(config_path)


## Suppress messages matching these patterns from msg_count, particles, and the
## active-topics map. Useful for demo "hide mock traffic" toggles. Pass `[]` to
## un-mute all.
func mute_topics(patterns: Array) -> void:
	muted_topic_patterns = patterns.duplicate()


## Replace the loaded topology with a new one from JSON.
func load_config(path: String) -> void:
	for child in get_children():
		child.queue_free()
	_nodes_by_id.clear()
	_edges.clear()

	if not FileAccess.file_exists(path):
		push_warning("[OcpTopologyOverlay] config not found: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_warning("[OcpTopologyOverlay] config not a Dictionary: %s" % path)
		return

	_config = parsed
	_palette = DEFAULT_PALETTE.duplicate()
	for k in _config.get("palette", {}):
		_palette[k] = Color(_config["palette"][k])
	_topic_color_rules = _config.get("topic_colors", [])

	_build_nodes()
	_build_edges()
	_config_loaded = true
	_relayout_children()


func _build_nodes() -> void:
	for spec in _config.get("nodes", []):
		var node = NODE_SCRIPT.new()
		add_child(node)
		node.configure(spec, _palette)
		node.set_font(_font)
		_nodes_by_id[node.node_id] = node
		# Initial online state per indicator
		var indicator: String = spec.get("online_indicator", "always")
		match indicator:
			"always":         node.set_online(true)
			"mqtt_connected": node.set_online(mqtt_connected)
			_:                node.set_online(false)


func _build_edges() -> void:
	for spec in _config.get("edges", []):
		var from = _nodes_by_id.get(spec.get("from", ""))
		var to = _nodes_by_id.get(spec.get("to", ""))
		if from == null or to == null:
			push_warning("[OcpTopologyOverlay] edge endpoints not found: %s" % spec)
			continue
		var edge = EDGE_SCRIPT.new()
		# Edge spans the full overlay so it can draw between any two nodes
		edge.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(edge)
		# Move edges behind nodes so the line goes under the boxes
		move_child(edge, 0)
		edge.configure(spec, _palette, from, to)
		edge.set_font(_font)
		_edges.append(edge)
		# Subscribe to the topics this edge declares so the visualization
		# sees traffic the autoload may not already track (e.g. */cmd).
		# See ADR-0003 for the subscription-ownership rationale.
		# Subscribe-twice is safe — mqtt_bridge.gd dedupes via _subscriptions.
		if _mqtt:
			for topic_pattern in edge.topic_patterns:
				_mqtt.subscribe(topic_pattern, 0)


func _relayout_children() -> void:
	if not _config_loaded:
		return
	# Position each node based on its (x_pct, y_pct) and (w_pct, h_pct)
	for spec in _config.get("nodes", []):
		var node = _nodes_by_id.get(spec.get("id", ""))
		if node == null:
			continue
		var pos_pct: Array = spec.get("position", [0.0, 0.0])
		var size_pct: Array = spec.get("size", [0.2, 0.22])
		node.position = Vector2(float(pos_pct[0]) * size.x, float(pos_pct[1]) * size.y)
		node.size = Vector2(float(size_pct[0]) * size.x, float(size_pct[1]) * size.y)
	for edge in _edges:
		edge.queue_redraw()


func _process(delta: float) -> void:
	_rate_timer += delta
	if _rate_timer >= RATE_INTERVAL:
		msg_rate = float(msg_count - _msg_count_last) / _rate_timer
		_msg_count_last = msg_count
		_rate_timer = 0.0

	# Prune stale topics
	var now := Time.get_unix_time_from_system()
	var stale := []
	for t in active_topics:
		if now - active_topics[t] > TOPIC_STALE_SEC:
			stale.append(t)
	for t in stale:
		active_topics.erase(t)


func _draw() -> void:
	if draw_background:
		draw_rect(Rect2(Vector2.ZERO, size), background_color)


func _set_mqtt_connected(connected: bool) -> void:
	mqtt_connected = connected
	# Update any node whose online_indicator is mqtt_connected
	for spec in _config.get("nodes", []):
		if spec.get("online_indicator", "") == "mqtt_connected":
			var node = _nodes_by_id.get(spec.get("id", ""))
			if node:
				node.set_online(connected)


func _on_message(topic: String, payload: String) -> void:
	# $SYS metrics — these don't drive edges, just metrics state
	if topic.begins_with("$SYS/"):
		_handle_sys_topic(topic, payload)
		return

	# Muted topics are dropped entirely (no count, no particle, no cloud entry)
	for pattern in muted_topic_patterns:
		if EDGE_SCRIPT._topic_matches(topic, pattern):
			return

	msg_count += 1
	active_topics[topic] = Time.get_unix_time_from_system()
	emit_signal("topic_seen", topic)
	emit_signal("message_received", topic, payload, payload.length())

	var color := _resolve_topic_color(topic)
	for edge in _edges:
		if edge.matches_topic(topic):
			edge.trigger_pulse(1.0)
			edge.spawn_particle(color)


func _handle_sys_topic(topic: String, payload: String) -> void:
	match topic:
		"$SYS/broker/clients/connected":     broker_clients = int(payload)
		"$SYS/broker/messages/received":     broker_msgs_received = int(payload)
		"$SYS/broker/subscriptions/count":   broker_subscriptions = int(payload)
	emit_signal("metrics_updated", broker_clients, broker_msgs_received, broker_subscriptions)


func _resolve_topic_color(topic: String) -> Color:
	for rule in _topic_color_rules:
		var pattern: String = rule.get("pattern", "")
		if EDGE_SCRIPT._topic_matches(topic, pattern):
			var color_name: String = rule.get("color", "")
			if _palette.has(color_name):
				return _palette[color_name]
			if color_name.begins_with("#"):
				return Color(color_name)
	return _palette.get("DIM", Color("888888"))
