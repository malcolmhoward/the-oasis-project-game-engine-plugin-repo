## M.I.R.A.G.E. notification toast.
##
## Listens for OCP `mirage/events` messages with `event=notification` and
## displays a fade-in/out card with the caller name and call status.
## Demo-quality recreation of upstream M.I.R.A.G.E.'s phone-notification
## subsystem — single concurrent toast, no photo decode, no per-event
## TTL config; fixed visible duration.
extends PanelContainer

const MH = preload("res://resources/mirage_design_tokens.gd")

@export var visible_seconds: float = 5.0
@export var fade_seconds: float = 0.4

var _title_label: Label = null
var _body_label: Label = null
var _status_label: Label = null
var _hide_timer: SceneTreeTimer = null


func _ready() -> void:
	# Build child controls programmatically so the scene file stays simple.
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = MH.HUD_PANEL_BG
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 8.0
	panel_style.border_width_left = 3
	panel_style.border_color = MH.PRIMARY_CYAN
	add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "INCOMING CALL"
	_title_label.add_theme_color_override("font_color", MH.PRIMARY_CYAN)
	_title_label.add_theme_font_size_override("font_size", MH.FONT_METRIC)
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.text = ""
	_body_label.add_theme_color_override("font_color", MH.DATA_WHITE)
	_body_label.add_theme_font_size_override("font_size", MH.FONT_AI_NAME)
	vbox.add_child(_body_label)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", MH.SECONDARY_CYAN)
	_status_label.add_theme_font_size_override("font_size", MH.FONT_LOG)
	vbox.add_child(_status_label)

	modulate.a = 0.0
	visible = false

	var oasis_mqtt := get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_message)


func _on_message(topic: String, payload: String) -> void:
	if topic != "mirage/events":
		return
	var msg = OCPMessage.parse(payload)
	if msg == null or typeof(msg) != TYPE_DICTIONARY:
		return
	if msg.get("event", "") != "notification":
		return
	show_notification(
		msg.get("category", "incoming_call"),
		msg.get("caller_name", msg.get("title", "")),
		msg.get("status", msg.get("body", ""))
	)


## Display a notification card. Restarts the visible timer if a new
## notification arrives while one is showing.
func show_notification(category: String, title: String, status: String) -> void:
	match category:
		"incoming_call": _title_label.text = "INCOMING CALL"
		"call_active":   _title_label.text = "CALL ACTIVE"
		"call_ended":    _title_label.text = "CALL ENDED"
		"sms_received":  _title_label.text = "MESSAGE"
		"image":         _title_label.text = "IMAGE"
		_:               _title_label.text = category.to_upper()
	_body_label.text = title
	_status_label.text = status

	visible = true
	# Cancel a pending hide if one is queued.
	if _hide_timer and _hide_timer.time_left > 0:
		_hide_timer = null
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_seconds)
	tween.tween_interval(visible_seconds)
	tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
	tween.tween_callback(func(): visible = false)
