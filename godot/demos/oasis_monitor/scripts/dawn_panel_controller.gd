@warning_ignore("inferred_declaration")
## D.A.W.N. panel placeholder.
##
## For the demo, DAWN's existing web UI runs at localhost:3000 in a browser.
## This panel provides a connection status indicator and a button to open/focus
## the DAWN web interface. It also displays a compact text-only interaction
## fallback for environments where the browser isn't available.
##
## Future: Replace with full Godot-native DAWN UI (see wireframe doc,
## "Future: Godot-Native DAWN UI" section).
extends PanelContainer

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var open_dawn_button: Button = $VBoxContainer/OpenDAWNButton
@onready var fallback_input: LineEdit = $VBoxContainer/FallbackInput/InputField
@onready var fallback_send: Button = $VBoxContainer/FallbackInput/SendButton
@onready var fallback_log: RichTextLabel = $VBoxContainer/FallbackLog

@export var dawn_url: String = "http://localhost:3000"

var _mqtt: MQTTBridge = null
var _dawn_online: bool = false


func _ready() -> void:
	if open_dawn_button:
		open_dawn_button.pressed.connect(_open_dawn_ui)
		open_dawn_button.text = "Open D.A.W.N. Web UI"

	if fallback_send:
		fallback_send.pressed.connect(_on_fallback_send)
	if fallback_input:
		fallback_input.text_submitted.connect(_on_fallback_text_submitted)

	if fallback_log:
		fallback_log.bbcode_enabled = true
		fallback_log.text = ""

	# Monitor DAWN's presence on OCP
	var oasis_mqtt = get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_message)
		_mqtt = oasis_mqtt.get_mqtt()

	_update_status()


func _open_dawn_ui() -> void:
	OS.shell_open(dawn_url)


func _on_fallback_send() -> void:
	if fallback_input:
		_on_fallback_text_submitted(fallback_input.text)


func _on_fallback_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	# Display in fallback log
	if fallback_log:
		fallback_log.append_text("[color=#AAAAAA]You:[/color] %s\n" % text)
	# Publish to DAWN's input topic
	if _mqtt:
		var msg = {
			"device": "godot-ui",
			"msg_type": "command",
			"action": "process_intent",
			"parameters": {"text": text},
			"timestamp": int(Time.get_unix_time_from_system()),
		}
		_mqtt.publish("oasis/dawn/input", JSON.stringify(msg))
	if fallback_input:
		fallback_input.clear()


func _on_message(topic: String, payload: String) -> void:
	# Track DAWN online status (OCP topic: dawn/status)
	if topic == "dawn/status" or topic == "oasis/dawn/status":
		var msg = OCPMessage.parse(payload)
		if msg and msg.get("status") == "online":
			_dawn_online = true
			_update_status()

	# Display DAWN responses in fallback log
	if topic == "dawn" or topic == "oasis/dawn/output":
		var msg = OCPMessage.parse(payload)
		if msg and fallback_log:
			var text: String = msg.get("text", msg.get("response", JSON.stringify(msg)))
			fallback_log.append_text("[color=#00BFFF]D.A.W.N.:[/color] %s\n" % text)
			if fallback_log.get_line_count() > 100:
				# Auto-scroll
				fallback_log.scroll_to_line(fallback_log.get_line_count() - 1)


func _update_status() -> void:
	if status_label:
		if _dawn_online:
			status_label.text = "D.A.W.N. ● Online — %s" % dawn_url
			status_label.add_theme_color_override("font_color", Color("#00CC66"))
		else:
			status_label.text = "D.A.W.N. ○ Waiting — %s" % dawn_url
			status_label.add_theme_color_override("font_color", Color("#CCAA00"))
