## D.A.W.N. conversation demo with OCP message stream.
##
## Left panel: reusable dawn_panel.tscn instance (conversation UI).
## Right panel: OCP message stream showing raw MQTT traffic.
## Stream pause/resume is controlled by the ControlPanel (if present)
## or by a local toggle added to the stream header (standalone mode).
##
## Useful for testing D.A.W.N. communication without the 3D game scene.
## Works with E.C.H.O. mock LLM or real D.A.W.N. instance.
extends Control

@onready var dawn_panel = find_child("DawnPanel", true, false)
@onready var stream_log = find_child("RichTextLabel", true, false)
@onready var msg_count_label = find_child("MsgCount", true, false)

var _msg_count = 0
var _stream_paused = false
var _control_panel = null  # ControlPanel node if present (unified demo)


func _ready():
	var oasis_mqtt = get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_global_message)

	# Look for a ControlPanel in the scene (unified demo mode)
	_control_panel = find_child("ControlPanel", true, false)
	if _control_panel:
		_control_panel.stream_toggled.connect(func(paused): _stream_paused = paused)
	else:
		# Standalone mode — add stream toggle directly to the stream header
		_add_standalone_stream_toggle()


func _add_standalone_stream_toggle():
	var header = find_child("HBoxContainer", true, false)
	if header:
		var status_lbl = Label.new()
		status_lbl.name = "StreamStatus"
		status_lbl.text = "● LIVE"
		status_lbl.add_theme_font_size_override("font_size", 11)
		status_lbl.add_theme_color_override("font_color", Color("44dd88"))
		header.add_child(status_lbl)

		var toggle_btn = Button.new()
		toggle_btn.text = "Pause"
		toggle_btn.add_theme_font_size_override("font_size", 11)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color("2a3040")
		btn_style.set_corner_radius_all(4)
		btn_style.content_margin_left = 6.0
		btn_style.content_margin_right = 6.0
		toggle_btn.add_theme_stylebox_override("normal", btn_style)
		toggle_btn.pressed.connect(func():
			_stream_paused = not _stream_paused
			if _stream_paused:
				toggle_btn.text = "Resume"
				status_lbl.text = "● PAUSED"
				status_lbl.add_theme_color_override("font_color", Color("ccaa44"))
			else:
				toggle_btn.text = "Pause"
				status_lbl.text = "● LIVE"
				status_lbl.add_theme_color_override("font_color", Color("44dd88"))
		)
		header.add_child(toggle_btn)


func _on_global_message(topic: String, payload: String):
	_msg_count += 1
	if msg_count_label:
		msg_count_label.text = "%d messages" % _msg_count

	# When paused, filter out sensor flood but keep commands, status, events, and dawn
	if _stream_paused:
		var dominated_keep = topic == "dawn" or topic.ends_with("/cmd") or topic.ends_with("/status") or topic.ends_with("/events")
		if not dominated_keep:
			return

	if stream_log:
		var time_dict = Time.get_time_dict_from_system()
		var timestamp = "%02d:%02d:%02d" % [time_dict["hour"], time_dict["minute"], time_dict["second"]]
		var short_topic = topic.get_file() if topic.contains("/") else topic
		stream_log.append_text("[color=#888888]%s[/color] [color=#00BFFF]%s[/color] %s\n" % [
			timestamp, short_topic, payload.left(120)
		])
		# Keep log size manageable
		if stream_log.get_line_count() > 200:
			stream_log.clear()
			stream_log.append_text("[color=#888888]--- log cleared ---[/color]\n")
