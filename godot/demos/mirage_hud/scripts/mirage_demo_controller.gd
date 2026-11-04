## M.I.R.A.G.E. HUD demo with OCP message stream.
##
## Same layout as unified_demo: D.A.W.N. panel (left), OCP stream (top-right),
## M.I.R.A.G.E. HUD (bottom-right) with control panel overlay.
##
## Wires ControlPanel provider toggles to the MIRAGE HUD's setter methods.
extends Control

@onready var dawn_panel = find_child("DawnPanel", true, false)
@onready var stream_log = find_child("RichTextLabel", true, false)
@onready var msg_count_label = find_child("MsgCount", true, false)

var _msg_count = 0
var _stream_paused = false
var _control_panel = null
var _mirage_hud = null


func _ready():
	var oasis_mqtt = get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_global_message)

	# Find control panel and wire signals
	_control_panel = find_child("ControlPanel", true, false)
	if _control_panel:
		_control_panel.stream_toggled.connect(func(paused): _stream_paused = paused)
		_control_panel.source_toggled.connect(_on_source_toggled)
		_control_panel.source_mode_changed.connect(_on_source_mode_changed)

	# Find MIRAGE HUD
	_mirage_hud = find_child("MirageHUD", true, false)


func _on_source_toggled(source_name: String, live: bool):
	if _mirage_hud == null:
		return
	match source_name:
		"system", "battery":
			# Both system and battery control S.T.A.T. display
			_mirage_hud.set_stat_live(live)
		# Camera handled via source_mode_changed (multi-mode source)


func _on_source_mode_changed(source_name: String, mode: String):
	if _mirage_hud == null or source_name != "camera":
		return
	match mode:
		"L0": _mirage_hud.set_camera_mode(_mirage_hud.CameraMode.L0_LOCAL)
		"L2": _mirage_hud.set_camera_mode(_mirage_hud.CameraMode.L2_HOST)
		"L3": _mirage_hud.set_camera_mode(_mirage_hud.CameraMode.L3_CONTAINER)


func _on_global_message(topic: String, payload: String):
	_msg_count += 1
	if msg_count_label:
		msg_count_label.text = "%d messages" % _msg_count

	# When paused, filter out sensor flood but keep commands, status, events, and dawn
	if _stream_paused:
		var dominated_keep = topic == "dawn" or topic.ends_with("/command") or topic.ends_with("/status") or topic.ends_with("/events")
		if not dominated_keep:
			return

	if stream_log:
		var time_dict = Time.get_time_dict_from_system()
		var timestamp = "%02d:%02d:%02d" % [time_dict["hour"], time_dict["minute"], time_dict["second"]]
		var short_topic = topic.get_file() if topic.contains("/") else topic
		stream_log.append_text("[color=#888888]%s[/color] [color=#00BFFF]%s[/color] %s\n" % [
			timestamp, short_topic, payload.left(120)
		])
		if stream_log.get_line_count() > 200:
			stream_log.clear()
			stream_log.append_text("[color=#888888]--- log cleared ---[/color]\n")
