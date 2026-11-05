## Main controller for the O.A.S.I.S. Monitor demo.
##
## Manages the top-level layout (HSplitContainer), view mode switching
## (full demo vs presentation mode), and global status bar updates.
extends Control

@onready var split_container: HSplitContainer = $HSplitContainer
@onready var left_column: VBoxContainer = $HSplitContainer/LeftColumn
@onready var status_bar: HBoxContainer = $GlobalStatusBar
@onready var mqtt_status_label: Label = $GlobalStatusBar/MQTTStatus
@onready var peer_count_label: Label = $GlobalStatusBar/PeerCount
@onready var msg_rate_label: Label = $GlobalStatusBar/MsgRate
@onready var uptime_label: Label = $GlobalStatusBar/Uptime

var _start_time: float = 0.0
var _msg_count: int = 0
var _msg_count_prev: int = 0
var _rate_timer: float = 0.0
var _presentation_mode: bool = false


func _ready() -> void:
	_start_time = Time.get_unix_time_from_system()
	# Connect to autoload signals
	var oasis_mqtt := get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_global_message)
		oasis_mqtt.mqtt.connected.connect(func(): _update_mqtt_status(true))
		oasis_mqtt.mqtt.disconnected.connect(func(): _update_mqtt_status(false))


func _process(delta: float) -> void:
	# Update message rate every second
	_rate_timer += delta
	if _rate_timer >= 1.0:
		var rate := _msg_count - _msg_count_prev
		msg_rate_label.text = "Msgs/s: %d" % rate
		_msg_count_prev = _msg_count
		_rate_timer = 0.0
	# Update uptime
	var elapsed := int(Time.get_unix_time_from_system() - _start_time)
	var mins := elapsed / 60
	var secs := elapsed % 60
	uptime_label.text = "Uptime: %dm %ds" % [mins, secs]
	# Update peer count
	var oasis_mqtt := get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		var peers: Dictionary = oasis_mqtt.get_peers()
		var online := 0
		for peer_id in peers:
			if peers[peer_id].get("status", "") == "online":
				online += 1
		peer_count_label.text = "Peers: %d/%d online" % [online, peers.size()]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_presentation_mode"):
		_toggle_presentation_mode()


func _toggle_presentation_mode() -> void:
	_presentation_mode = not _presentation_mode
	left_column.visible = not _presentation_mode
	if _presentation_mode:
		split_container.split_offset = 0
	else:
		# Restore 35% left column
		split_container.split_offset = int(size.x * 0.35)


func _on_global_message(_topic: String, _payload: String) -> void:
	_msg_count += 1


func _update_mqtt_status(connected: bool) -> void:
	var oasis_mqtt := get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt and connected:
		mqtt_status_label.text = "MQTT: ws://%s:%d ● Connected" % [
			oasis_mqtt.broker_host, oasis_mqtt.broker_port
		]
		mqtt_status_label.add_theme_color_override("font_color", Color("#00CC66"))
	else:
		mqtt_status_label.text = "MQTT: ○ Disconnected"
		mqtt_status_label.add_theme_color_override("font_color", Color("#CC3333"))
