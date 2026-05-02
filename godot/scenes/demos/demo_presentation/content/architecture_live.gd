## Live architecture diagram — real-time visualization of demo infrastructure.
##
## Shows Docker containers, MQTT connections, message flow, and provider
## toggle states. All data is live from OasisMQTT. Usable as:
##   - Slide (manifest references it directly)
##   - Overlay (PresentationController shows on hotkey)
##   - Panel (instanced in any demo layout)
##
## Includes d-pad for manually injecting OCP commands to visualize message flow.
## Answers "how much of O.A.S.I.S. is real?" in a single glance.
extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

const PT = preload("res://resources/presentation_theme.gd")

# --- Layout proportions (relative to canvas size) ---
const NODE_Y          := 0.25   # Vertical position of node boxes
const MOCK_X          := 0.06   # Mock Traffic box left edge
const BROKER_X        := 0.40   # Mosquitto box left edge
const GODOT_X         := 0.74   # Godot App box left edge
const BOX_W           := 0.20   # Node box width
const BOX_H           := 0.22   # Node box height
const SECTION_GAP     := 0.05   # Gap below boxes to provider/topic lists
const LIST_LINE_H     := 13.0   # Pixels per line in provider/topic lists
const MAX_TOPICS      := 8      # Max topics shown in cloud

# --- Drawing sizes (pixels) ---
const DOT_RADIUS      := 5.0
const DOT_OFFSET      := Vector2(15, 18)
const TITLE_OFFSET    := Vector2(28, 22)
const SUBTITLE_OFFSET := Vector2(28, 42)
const STATUS_MARGIN   := 12.0   # Pixels from box bottom
const ARROW_SIZE      := 8.0
const CONN_LABEL_Y    := -12.0  # Connection label offset above line
const ENV_W           := 10.0   # Envelope particle width
const ENV_H           := 7.0    # Envelope particle height
const CONN_INSET      := 10.0   # Arrow endpoint inset from box edge

# --- Font sizes ---
const FONT_TITLE      := 14
const FONT_SUBTITLE   := 11
const FONT_STATUS     := 11
const FONT_CONN_LABEL := 10
const FONT_LIST_HEAD  := 11
const FONT_LIST_ITEM  := 10
const FONT_INFO       := 14
const FONT_MOCK_BTN   := 12

# --- Animation ---
const PULSE_DECAY     := 3.0    # Pulse fade speed (per second)
const PARTICLE_SPEED  := 1.8    # Particle travel speed (0→1 per second)
const PARTICLE_FADE   := 0.5    # Particle alpha fade factor at end
const MAX_PARTICLES   := 6      # Max particles per connection
const TOPIC_STALE_SEC := 10.0   # Seconds before topic pruned from cloud
const RATE_INTERVAL   := 1.0    # Seconds between rate calculations

# --- Colors ---
const BG_COLOR        := Color("121417")
const BOX_BG          := Color("1a1e24")
const BOX_OFFLINE     := Color("444444")
const STATUS_ERROR    := Color("ef4444")
const CONN_BASE       := Color("333333")
const LABEL_DIM       := Color("666666")
const LIST_DIM        := Color("888888")
const CMD_COLOR       := Color("f97316")  # Orange — OCP commands
const MOCK_COLOR      := Color("f0b429")  # Gold — mock traffic node
const GODOT_COLOR     := Color("3b82f6")  # Blue — Godot app node

# Provider source names (for display list)
const PROVIDER_SOURCES := ["camera", "audio", "motion", "gps", "environ", "system", "battery", "llm"]

# --- Runtime state ---
var _mqtt: MQTTBridge = null
var _mqtt_connected: bool = false
var _msg_count: int = 0
var _msg_rate: float = 0.0
var _msg_count_last: int = 0
var _rate_timer: float = 0.0
var _active_topics: Dictionary = {}
var _pulse_timers: Dictionary = {}
var _provider_states: Dictionary = {}
var _show_mock: bool = true
var _particles: Array = []
var _mono_font: Font = null

@onready var canvas: Control = $Canvas
@onready var mqtt_status: Label = $InfoPanel/VBox/MQTTStatus
@onready var msg_counter: Label = $InfoPanel/VBox/MsgCounter
@onready var msg_rate_label: Label = $InfoPanel/VBox/MsgRate
@onready var topics_label: Label = $InfoPanel/VBox/TopicsLabel
@onready var mock_toggle: Button = $MockToggle


func _ready():
	total_steps = 1  # Single step — diagram is always fully visible
	_mono_font = load("res://resources/fonts/IBMPlexMono-Regular.ttf")

	var oasis_mqtt = get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_message)
		_mqtt = oasis_mqtt.get_mqtt()
		if _mqtt:
			_mqtt_connected = _mqtt.get_connection_state() == 3
			_mqtt.connected.connect(func(): _mqtt_connected = true)
			_mqtt.disconnected.connect(func(): _mqtt_connected = false)

	_pulse_timers = {"mock_to_broker": 0.0, "broker_to_godot": 0.0, "godot_to_broker": 0.0}
	canvas.draw.connect(_draw_diagram.bind(canvas))

	_style_info_panel()
	_style_mock_toggle()
	_setup_dpad()
	_set_focus_none_recursive(self)


func _style_info_panel():
	for label in [mqtt_status, msg_counter, msg_rate_label, topics_label]:
		if label:
			label.add_theme_font_size_override("font_size", FONT_INFO)
			label.add_theme_color_override("font_color", PT.COLOR_ACCENT)
			if _mono_font:
				label.add_theme_font_override("font", _mono_font)


func _style_mock_toggle():
	if not mock_toggle:
		return
	mock_toggle.text = "Mock Traffic: ON"
	mock_toggle.add_theme_font_size_override("font_size", FONT_MOCK_BTN)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = PT.BTN_BG
	btn_style.set_corner_radius_all(4)
	btn_style.content_margin_left = 8.0
	btn_style.content_margin_right = 8.0
	btn_style.content_margin_top = 4.0
	btn_style.content_margin_bottom = 4.0
	mock_toggle.add_theme_stylebox_override("normal", btn_style)
	mock_toggle.add_theme_color_override("font_color", PT.COLOR_SIM)
	mock_toggle.pressed.connect(_on_mock_toggle)


func _setup_dpad():
	var dpad_style = StyleBoxFlat.new()
	dpad_style.bg_color = PT.BTN_BG
	dpad_style.set_corner_radius_all(4)
	dpad_style.content_margin_left = 4.0
	dpad_style.content_margin_right = 4.0
	dpad_style.content_margin_top = 2.0
	dpad_style.content_margin_bottom = 2.0
	for btn_name in ["BtnUp", "BtnDown", "BtnLeft", "BtnRight", "BtnJump"]:
		var btn: Button = find_child(btn_name, true, false)
		if btn:
			btn.add_theme_stylebox_override("normal", dpad_style.duplicate())
			btn.add_theme_font_size_override("font_size", PT.CP_DPAD)
			btn.pressed.connect(_on_dpad.bind(btn_name))


func _set_focus_none_recursive(node: Node):
	if node is Control:
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_set_focus_none_recursive(child)


# --- Toggle ---

func _on_mock_toggle():
	_show_mock = not _show_mock
	if mock_toggle:
		mock_toggle.text = "Mock Traffic: ON" if _show_mock else "Mock Traffic: OFF"
		mock_toggle.add_theme_color_override("font_color",
			PT.COLOR_SIM if _show_mock else PT.COLOR_MIXED)


# --- Process ---

func _process(delta: float):
	# Decay pulse timers
	for key in _pulse_timers:
		if _pulse_timers[key] > 0:
			_pulse_timers[key] = max(0.0, _pulse_timers[key] - delta * PULSE_DECAY)

	# Animate particles
	var alive: Array = []
	for p in _particles:
		p["progress"] += delta * PARTICLE_SPEED
		if p["progress"] < 1.0:
			alive.append(p)
	_particles = alive

	# Rate calculation
	_rate_timer += delta
	if _rate_timer >= RATE_INTERVAL:
		_msg_rate = float(_msg_count - _msg_count_last) / _rate_timer
		_msg_count_last = _msg_count
		_rate_timer = 0.0

	# Prune stale topics
	var now = Time.get_unix_time_from_system()
	var stale: Array = []
	for t in _active_topics:
		if now - _active_topics[t] > TOPIC_STALE_SEC:
			stale.append(t)
	for t in stale:
		_active_topics.erase(t)

	_update_info_labels()
	canvas.queue_redraw()


func _update_info_labels():
	if mqtt_status:
		mqtt_status.text = "MQTT: CONNECTED" if _mqtt_connected else "MQTT: DISCONNECTED"
		mqtt_status.add_theme_color_override("font_color",
			PT.COLOR_LIVE if _mqtt_connected else STATUS_ERROR)
	if msg_counter:
		msg_counter.text = "Messages: %d" % _msg_count
	if msg_rate_label:
		msg_rate_label.text = "Rate: %.0f msg/s" % _msg_rate
	if topics_label:
		var topic_list = _active_topics.keys()
		topic_list.sort()
		topics_label.text = "Topics: %s" % ", ".join(topic_list) if topic_list.size() > 0 else "Topics: (none)"


# --- Message handling ---

func _on_message(topic: String, _payload: String):
	_msg_count += 1
	_active_topics[topic] = Time.get_unix_time_from_system()

	var is_mock = topic in ["aura", "stat"]
	if is_mock and not _show_mock:
		return

	# Color by topic type
	var pcolor: Color
	match topic:
		"aura":  pcolor = PT.COMP_AURA
		"stat":  pcolor = PT.COMP_STAT
		"dawn":  pcolor = PT.COMP_DAWN
		_:
			if topic.ends_with("/command"):  pcolor = CMD_COLOR
			elif topic.ends_with("/status"): pcolor = PT.COLOR_ACCENT
			elif topic.ends_with("/events"): pcolor = PT.COLOR_ACCENT
			else: pcolor = LIST_DIM

	if is_mock:
		_pulse_timers["mock_to_broker"] = 1.0
		_pulse_timers["broker_to_godot"] = 1.0
		_spawn_particle("mock_to_broker", pcolor)
		_spawn_particle("broker_to_godot", pcolor)
	elif topic == "dawn":
		_pulse_timers["broker_to_godot"] = 1.0
		_pulse_timers["godot_to_broker"] = 1.0
		_spawn_particle("broker_to_godot", pcolor)
	elif topic.begins_with("oasis/"):
		_pulse_timers["broker_to_godot"] = 1.0
		_spawn_particle("broker_to_godot", pcolor)
		if topic.ends_with("/command") or topic.ends_with("/status") or topic.ends_with("/events"):
			_pulse_timers["godot_to_broker"] = 1.0
			_spawn_particle("godot_to_broker", pcolor)


func _spawn_particle(conn: String, color: Color):
	var count = 0
	for p in _particles:
		if p["conn"] == conn:
			count += 1
	if count < MAX_PARTICLES:
		_particles.append({"conn": conn, "progress": 0.0, "color": color})


## Called by ControlPanel or demo controller to update provider display
func set_provider_state(source_name: String, live: bool):
	_provider_states[source_name] = live


# --- D-pad ---

func _on_dpad(btn_name: String):
	var action := ""
	var params := {}
	match btn_name:
		"BtnUp":    action = "move_forward"; params = {"distance": 1.5}
		"BtnDown":  action = "move_back";    params = {"distance": 1.5}
		"BtnLeft":  action = "move_left";    params = {"distance": 1.5}
		"BtnRight": action = "move_right";   params = {"distance": 1.5}
		"BtnJump":  action = "jump"
	if action.is_empty():
		return
	if _mqtt:
		_mqtt.publish("oasis/e3-avatar/command", JSON.stringify({
			"device": "e3-avatar", "msg_type": "command",
			"action": action, "parameters": params,
			"timestamp": int(Time.get_unix_time_from_system()),
		}))


# --- Drawing ---

func _get_font() -> Font:
	return _mono_font if _mono_font else ThemeDB.fallback_font


func _get_conn_endpoints(conn: String, mock_pos: Vector2, broker_pos: Vector2,
		godot_pos: Vector2, box_w: float, box_h: float) -> Array:
	var center_y = box_h / 2.0
	match conn:
		"mock_to_broker":
			return [mock_pos + Vector2(box_w, center_y),
					broker_pos + Vector2(CONN_INSET, center_y)]
		"broker_to_godot":
			return [broker_pos + Vector2(box_w, center_y),
					godot_pos + Vector2(CONN_INSET, center_y)]
		"godot_to_broker":
			return [godot_pos + Vector2(CONN_INSET, center_y),
					broker_pos + Vector2(box_w, center_y)]
	return [Vector2.ZERO, Vector2.ZERO]


func _draw_diagram(c: Control):
	var w = c.size.x
	var h = c.size.y
	c.draw_rect(Rect2(Vector2.ZERO, c.size), BG_COLOR)

	var box_w = w * BOX_W
	var box_h = h * BOX_H
	var mock_pos = Vector2(w * MOCK_X, h * NODE_Y)
	var broker_pos = Vector2(w * BROKER_X, h * NODE_Y)
	var godot_pos = Vector2(w * GODOT_X, h * NODE_Y)

	# Connections (behind boxes)
	var mock_broker = _get_conn_endpoints("mock_to_broker", mock_pos, broker_pos, godot_pos, box_w, box_h)
	var broker_godot = _get_conn_endpoints("broker_to_godot", mock_pos, broker_pos, godot_pos, box_w, box_h)
	_draw_connection(c, mock_broker[0], mock_broker[1], "MQTT", _pulse_timers["mock_to_broker"])
	_draw_connection(c, broker_godot[0], broker_godot[1], "WebSocket", _pulse_timers["broker_to_godot"])

	# Boxes
	_draw_node_box(c, mock_pos, box_w, box_h, "Mock Traffic", "(Python)", true, MOCK_COLOR)
	_draw_node_box(c, broker_pos, box_w, box_h, "Mosquitto MQTT", "(Docker)", _mqtt_connected, PT.COLOR_ACCENT)
	_draw_node_box(c, godot_pos, box_w, box_h, "Godot App", "(This window)", _mqtt_connected, GODOT_COLOR)

	# Particles
	for p in _particles:
		var endpoints = _get_conn_endpoints(p["conn"], mock_pos, broker_pos, godot_pos, box_w, box_h)
		var pos = endpoints[0].lerp(endpoints[1], p["progress"])
		var pcolor = p["color"]
		pcolor.a = 1.0 - p["progress"] * PARTICLE_FADE
		# Envelope shape
		var half_w = ENV_W / 2.0
		var half_h = ENV_H / 2.0
		c.draw_rect(Rect2(pos - Vector2(half_w, half_h), Vector2(ENV_W, ENV_H)), pcolor)
		c.draw_line(pos + Vector2(-half_w, -half_h), pos, pcolor, 1.0)
		c.draw_line(pos + Vector2(half_w, -half_h), pos, pcolor, 1.0)

	# Provider list (below Godot box)
	_draw_provider_list(c, Vector2(godot_pos.x, godot_pos.y + box_h + h * SECTION_GAP), box_w)

	# Topic cloud (below broker)
	_draw_topic_cloud(c, Vector2(broker_pos.x, broker_pos.y + box_h + h * SECTION_GAP), box_w)


func _draw_node_box(c: Control, pos: Vector2, bw: float, bh: float,
		title: String, subtitle: String, is_online: bool, accent: Color):
	var rect = Rect2(pos, Vector2(bw, bh))
	c.draw_rect(rect, BOX_BG)
	c.draw_rect(rect, accent if is_online else BOX_OFFLINE, false, 2.0)
	var dot_color = PT.COLOR_LIVE if is_online else STATUS_ERROR
	c.draw_circle(pos + DOT_OFFSET, DOT_RADIUS, dot_color)
	var font = _get_font()
	c.draw_string(font, pos + TITLE_OFFSET, title, HORIZONTAL_ALIGNMENT_LEFT, bw - 36, FONT_TITLE, accent)
	c.draw_string(font, pos + SUBTITLE_OFFSET, subtitle, HORIZONTAL_ALIGNMENT_LEFT, bw - 36, FONT_SUBTITLE, LABEL_DIM)
	var status_text = "● RUNNING" if is_online else "● OFFLINE"
	c.draw_string(font, pos + Vector2(15, bh - STATUS_MARGIN), status_text, HORIZONTAL_ALIGNMENT_LEFT, bw - 24, FONT_STATUS, dot_color)


func _draw_connection(c: Control, from: Vector2, to: Vector2, label: String, pulse: float):
	var color = CONN_BASE.lerp(PT.COLOR_ACCENT, pulse)
	var thickness = 1.5 + pulse * 2.0
	c.draw_line(from, to, color, thickness)
	var dir = (to - from).normalized()
	var perp = Vector2(-dir.y, dir.x)
	c.draw_line(to, to - dir * ARROW_SIZE + perp * ARROW_SIZE * 0.5, color, thickness)
	c.draw_line(to, to - dir * ARROW_SIZE - perp * ARROW_SIZE * 0.5, color, thickness)
	var mid = (from + to) / 2.0 + Vector2(0, CONN_LABEL_Y)
	c.draw_string(_get_font(), mid, label, HORIZONTAL_ALIGNMENT_CENTER, 120, FONT_CONN_LABEL, LABEL_DIM)


func _draw_provider_list(c: Control, pos: Vector2, bw: float):
	var font = _get_font()
	c.draw_string(font, pos, "Providers:", HORIZONTAL_ALIGNMENT_LEFT, bw, FONT_LIST_HEAD, LIST_DIM)
	var y_off = LIST_LINE_H + 3.0
	for source in PROVIDER_SOURCES:
		var live = _provider_states.get(source, false)
		var dot_color = PT.COLOR_LIVE if live else PT.COLOR_SIM
		c.draw_string(font, pos + Vector2(0, y_off), "● %s" % source, HORIZONTAL_ALIGNMENT_LEFT, bw, FONT_LIST_ITEM, dot_color)
		y_off += LIST_LINE_H


func _draw_topic_cloud(c: Control, pos: Vector2, bw: float):
	var font = _get_font()
	c.draw_string(font, pos, "Active Topics:", HORIZONTAL_ALIGNMENT_LEFT, bw, FONT_LIST_HEAD, LIST_DIM)
	var y_off = LIST_LINE_H + 3.0
	var topics = _active_topics.keys()
	topics.sort()
	for t in topics.slice(0, MAX_TOPICS):
		c.draw_string(font, pos + Vector2(0, y_off), t, HORIZONTAL_ALIGNMENT_LEFT, bw, FONT_LIST_ITEM, PT.COLOR_ACCENT)
		y_off += LIST_LINE_H
