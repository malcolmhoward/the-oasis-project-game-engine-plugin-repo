@warning_ignore("inferred_declaration")
## OCP Message Log panel.
##
## Compact timestamped log of recent OCP messages. Color-coded by type.
## Supports auto-scroll toggle and topic filtering.
extends PanelContainer

@onready var log_text: RichTextLabel = $VBoxContainer/LogScroll/LogText
@onready var auto_scroll_toggle: CheckButton = $VBoxContainer/Header/AutoScroll
@onready var filter_button: OptionButton = $VBoxContainer/Header/Filter

var _max_lines: int = 200
var _line_count: int = 0
var _auto_scroll: bool = true
var _filter_topic: String = ""  # Empty = show all

const TYPE_COLORS = {
	"status": "#4488CC",
	"command": "#CC8844",
	"response": "#44CC88",
	"discovery": "#44CC44",
	"event": "#CC44CC",
	"sensor": "#8888CC",
}


func _ready() -> void:
	if log_text:
		log_text.bbcode_enabled = true
		log_text.scroll_following = true
		log_text.text = ""

	if auto_scroll_toggle:
		auto_scroll_toggle.button_pressed = true
		auto_scroll_toggle.toggled.connect(func(pressed): _auto_scroll = pressed)

	if filter_button:
		filter_button.add_item("All Topics", 0)
		filter_button.add_item("oasis/dawn/*", 1)
		filter_button.add_item("oasis/mirage/*", 2)
		filter_button.add_item("oasis/*/status", 3)
		filter_button.add_item("oasis/*/command", 4)
		filter_button.item_selected.connect(_on_filter_changed)

	var oasis_mqtt = get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_message)


func _on_message(topic: String, payload: String) -> void:
	# Apply filter
	if not _filter_topic.is_empty() and not _matches_filter(topic):
		return

	var msg = OCPMessage.parse(payload)
	var msg_type = "unknown"
	var device = "?"
	if msg != null:
		msg_type = OCPMessage.get_msg_type(msg)
		device = OCPMessage.get_device(msg)

	# Format: HH:MM:SS  type  device
	var time_dict = Time.get_time_dict_from_system()
	var timestamp = "%02d:%02d:%02d" % [time_dict["hour"], time_dict["minute"], time_dict["second"]]
	var color: String = str(TYPE_COLORS.get(msg_type, "#888888"))
	var short_device = device.left(8)
	var short_type = msg_type.left(6)

	var line = "[color=#888888]%s[/color] [color=%s]%-6s[/color] [color=#E0E0E0]%s[/color]" % [
		timestamp, color, short_type, short_device
	]

	if log_text:
		log_text.append_text(line + "\n")
		_line_count += 1
		# Trim old lines to prevent unbounded growth
		if _line_count > _max_lines:
			# RichTextLabel doesn't support line removal easily;
			# clear and rebuild would be expensive. Accept the growth
			# up to ~2x max_lines then clear.
			if _line_count > _max_lines * 2:
				log_text.clear()
				_line_count = 0
		# Auto-scroll
		if _auto_scroll:
			log_text.scroll_to_line(log_text.get_line_count() - 1)


func _on_filter_changed(index: int) -> void:
	match index:
		0: _filter_topic = ""
		1: _filter_topic = "oasis/dawn/"
		2: _filter_topic = "oasis/mirage/"
		3: _filter_topic = "/status"
		4: _filter_topic = "/command"


func _matches_filter(topic: String) -> bool:
	if _filter_topic.begins_with("/"):
		# Suffix match (e.g., "/status")
		return topic.ends_with(_filter_topic)
	else:
		# Prefix match (e.g., "oasis/dawn/")
		return topic.begins_with(_filter_topic)
