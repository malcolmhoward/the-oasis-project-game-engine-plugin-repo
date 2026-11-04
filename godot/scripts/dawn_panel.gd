## Reusable D.A.W.N. conversation panel.
##
## Can be instanced as a standalone demo or embedded in any scene.
## Publishes user messages to the D.A.W.N. input topic and displays
## responses from the D.A.W.N. output topic.
##
## When running with E.C.H.O.'s mock LLM, keyword-matched responses
## appear automatically. When running with real D.A.W.N., the full
## intent-processing pipeline handles the conversation.
extends Control

signal user_message_sent(text: String)

@onready var conversation = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var input_field = $VBoxContainer/HBoxContainer/LineEdit
@onready var send_button = $VBoxContainer/HBoxContainer/Button
@onready var status_label = $VBoxContainer/StatusBar

var _mqtt = null
var _dawn_online = false


func _ready():
	send_button.pressed.connect(_on_send)
	input_field.text_submitted.connect(_on_send_text)

	# Prevent scroll container from stealing focus from input field
	var scroll = $VBoxContainer/ScrollContainer
	if scroll:
		scroll.focus_mode = Control.FOCUS_NONE
	if conversation:
		conversation.focus_mode = Control.FOCUS_NONE

	var oasis_mqtt = get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		_mqtt = oasis_mqtt.get_mqtt()
		oasis_mqtt.global_message.connect(_on_mqtt_message)
		oasis_mqtt.peer_discovered.connect(_on_peer_discovered)

	_update_status()

	# Keep editing mode after Enter — Godot 4.4+ exits editing by default
	# (LineEdit keeps focus but stops accepting typed characters)
	if input_field:
		input_field.keep_editing_on_text_submit = true
		input_field.grab_focus.call_deferred()


func _on_send():
	_on_send_text(input_field.text)


func _on_send_text(text: String):
	if text.strip_edges().is_empty():
		return
	_add_message("You", text, Color.WHITE)
	# Publish to D.A.W.N.'s input topic
	if _mqtt:
		_mqtt.publish("dawn", JSON.stringify({
			"device": "godot-dawn-panel",
			"action": "process_intent",
			"value": text,
			"timestamp": OCPMessage.now_ms(),
		}))
	user_message_sent.emit(text)
	input_field.clear()
	input_field.grab_focus()


func _on_mqtt_message(topic: String, payload: String):
	# Track D.A.W.N. online status (v1.4: dawn/status)
	if topic == "dawn/status":
		var msg = JSON.parse_string(payload)
		if msg is Dictionary and msg.get("status") == "online":
			_dawn_online = true
			_update_status()

	# Display D.A.W.N. responses (v1.4: dawn topic)
	if topic == "dawn":
		var msg = JSON.parse_string(payload)
		if msg is Dictionary:
			var text = ""
			if msg.has("text"):
				text = str(msg["text"])
			elif msg.has("response"):
				text = str(msg["response"])
			elif msg.has("value") and msg.get("action") == "speak":
				text = str(msg["value"])
			if not text.is_empty():
				_add_message("D.A.W.N.", text, Color("#00BFFF"))


func _on_peer_discovered(peer_id: String, data: Dictionary):
	if "dawn" in peer_id.to_lower():
		_dawn_online = true
		_update_status()


const MAX_MESSAGES := 100


func _add_message(sender: String, text: String, color: Color):
	var role = MessageBubble.Role.USER if sender == "You" else MessageBubble.Role.ASSISTANT
	var bubble = MessageBubble.create(role, sender, text)
	conversation.add_child(bubble)
	# Typewriter effect for assistant responses
	if role == MessageBubble.Role.ASSISTANT:
		bubble.typewrite(50.0)  # 50 chars/sec
	# Remove oldest messages to prevent memory growth
	while conversation.get_child_count() > MAX_MESSAGES:
		var oldest = conversation.get_child(0)
		conversation.remove_child(oldest)
		oldest.queue_free()
	# Auto-scroll to bottom
	await get_tree().process_frame
	var scroll = $VBoxContainer/ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	# Re-grab focus after UI settles (wait 2 frames for layout + scroll)
	await get_tree().process_frame
	await get_tree().process_frame
	if input_field and is_inside_tree():
		input_field.grab_focus()


func _update_status():
	if status_label:
		if _dawn_online:
			status_label.text = "● D.A.W.N.: Online"
			status_label.add_theme_color_override("font_color", ArcReactorDark.STATUS_SUCCESS)
		elif _mqtt:
			status_label.text = "● D.A.W.N.: Waiting..."
			status_label.add_theme_color_override("font_color", ArcReactorDark.STATUS_WARNING)
		else:
			status_label.text = "MQTT: Not connected"
			status_label.add_theme_color_override("font_color", ArcReactorDark.STATUS_ERROR)
