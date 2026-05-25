## Live architecture diagram — demo wrapper around the reusable OCP topology
## addon. The addon (OcpTopologyOverlay at $Topology) owns all topology
## rendering. This script owns the demo-specific widgets layered over it:
## InfoPanel (MQTT status + message counters), MockToggle, and the DPad
## for injecting OCP commands.
##
## All values surfaced in InfoPanel are read from the addon's public state
## each frame; the addon is the source of truth for MQTT/topology data.
extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

const PT = preload("res://resources/presentation_theme.gd")

const FONT_INFO := 14
const FONT_MOCK_BTN := 12
const STATUS_ERROR := Color("ef4444")

const MOCK_PATTERNS := ["aura", "stat"]

@onready var topology = $Topology
@onready var mqtt_status: Label = $InfoPanel/VBox/MQTTStatus
@onready var msg_counter: Label = $InfoPanel/VBox/MsgCounter
@onready var msg_rate_label: Label = $InfoPanel/VBox/MsgRate
@onready var topics_label: Label = $InfoPanel/VBox/TopicsLabel
@onready var mock_toggle: Button = $MockToggle

var _show_mock: bool = true
var _mqtt = null
var _mono_font: Font = null


func _ready() -> void:
	total_steps = 1  # Single step — diagram is always fully visible
	_mono_font = load("res://resources/fonts/IBMPlexMono-Regular.ttf")

	# Point topology at the M.I.R.A.G.E. demo config
	topology.config_path = "res://addons/oasis_ocp/visualization/configs/mirage_demo.json"
	topology.load_config(topology.config_path)

	var oasis_mqtt := get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		_mqtt = oasis_mqtt.get_mqtt()

	_style_info_panel()
	_style_mock_toggle()
	_setup_dpad()
	_set_focus_none_recursive(self)


func _style_info_panel() -> void:
	for label in [mqtt_status, msg_counter, msg_rate_label, topics_label]:
		if label:
			label.add_theme_font_size_override("font_size", FONT_INFO)
			label.add_theme_color_override("font_color", PT.COLOR_ACCENT)
			if _mono_font:
				label.add_theme_font_override("font", _mono_font)


func _style_mock_toggle() -> void:
	if not mock_toggle:
		return
	mock_toggle.text = "Mock Traffic: ON"
	mock_toggle.add_theme_font_size_override("font_size", FONT_MOCK_BTN)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = PT.BTN_BG
	btn_style.set_corner_radius_all(4)
	btn_style.content_margin_left = 8.0
	btn_style.content_margin_right = 8.0
	btn_style.content_margin_top = 4.0
	btn_style.content_margin_bottom = 4.0
	mock_toggle.add_theme_stylebox_override("normal", btn_style)
	mock_toggle.add_theme_color_override("font_color", PT.COLOR_SIM)
	mock_toggle.pressed.connect(_on_mock_toggle)


func _setup_dpad() -> void:
	var dpad_style := StyleBoxFlat.new()
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


func _set_focus_none_recursive(node: Node) -> void:
	if node is Control:
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_set_focus_none_recursive(child)


func _on_mock_toggle() -> void:
	_show_mock = not _show_mock
	if mock_toggle:
		mock_toggle.text = "Mock Traffic: ON" if _show_mock else "Mock Traffic: OFF"
		mock_toggle.add_theme_color_override("font_color",
			PT.COLOR_SIM if _show_mock else PT.COLOR_MIXED)
	topology.mute_topics([] if _show_mock else MOCK_PATTERNS)


func _process(_delta: float) -> void:
	if mqtt_status:
		var connected: bool = topology.mqtt_connected
		mqtt_status.text = "MQTT: CONNECTED" if connected else "MQTT: DISCONNECTED"
		mqtt_status.add_theme_color_override("font_color",
			PT.COLOR_LIVE if connected else STATUS_ERROR)
	if msg_counter:
		msg_counter.text = "Messages: %d" % topology.msg_count
	if msg_rate_label:
		msg_rate_label.text = "Rate: %.0f msg/s" % topology.msg_rate
	if topics_label:
		var topic_list: Array = topology.active_topics.keys()
		topic_list.sort()
		topics_label.text = "Topics: %s" % ", ".join(topic_list) if topic_list.size() > 0 else "Topics: (none)"


func _on_dpad(btn_name: String) -> void:
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
		_mqtt.publish(OCPMessage.cmd_topic("e3-avatar"), JSON.stringify({
			"device": "e3-avatar", "msg_type": "command",
			"action": action, "parameters": params,
			"timestamp": OCPMessage.now_ms(),
		}))
