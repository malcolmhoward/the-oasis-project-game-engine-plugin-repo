## D.A.W.N. LLM controls bar (Phase 4).
##
## Sits above the input row in the DawnUI panel. Three controls plus a
## label header — model select (OptionButton), temperature slider, and
## tool-mode radio (auto / always / never).
##
## Each change publishes a v1.4 OCP command to dawn/cmd with
## action=set_config, parameters carrying just the field that changed.
## Live updates from the server arrive on dawn/events with
## event=config_update and apply_config_update() reflects them in the
## controls without re-emitting commands (loop break via _muted flag).
extends PanelContainer

const ArcReactor = preload("res://resources/design_tokens.gd")

const TOOL_MODES := ["auto", "always", "never"]

# Default model list. Real D.A.W.N. would emit a config_update on connect
# to overwrite this. Models cover the three providers DAWN supports.
const DEFAULT_MODELS := [
	"claude-opus-4-7",
	"claude-sonnet-4-6",
	"claude-haiku-4-5",
	"gpt-4.1",
	"gpt-4o-mini",
	"gemini-2.5-pro",
]

signal config_changed(field: String, value: Variant)

var _mqtt: MQTTBridge = null
var _muted: bool = false  # Suppress signal emit while applying remote update

var _model_button: OptionButton = null
var _temp_slider: HSlider = null
var _temp_label: Label = null
var _tool_mode_buttons: Dictionary = {}


func _ready() -> void:
	_style_panel()
	_build_controls()
	# Cache MQTT for publishing set_config commands.
	var oasis_mqtt := get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		_mqtt = oasis_mqtt.get_mqtt()


func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = ArcReactor.BG_DARK
	style.set_corner_radius_all(ArcReactor.RADIUS_MD)
	style.content_margin_left = ArcReactor.SPACE_MD
	style.content_margin_right = ArcReactor.SPACE_MD
	style.content_margin_top = ArcReactor.SPACE_SM
	style.content_margin_bottom = ArcReactor.SPACE_SM
	add_theme_stylebox_override("panel", style)


func _build_controls() -> void:
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", ArcReactor.SPACE_MD)
	add_child(hbox)

	# ─── Model select ────────────────────────────────────────────────
	var model_label := Label.new()
	model_label.text = "Model"
	model_label.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	model_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	hbox.add_child(model_label)

	_model_button = OptionButton.new()
	_model_button.flat = false
	_model_button.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	for model_name in DEFAULT_MODELS:
		_model_button.add_item(model_name)
	_model_button.item_selected.connect(_on_model_selected)
	hbox.add_child(_model_button)

	# ─── Temperature slider ──────────────────────────────────────────
	var temp_text := Label.new()
	temp_text.text = "Temp"
	temp_text.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	temp_text.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	hbox.add_child(temp_text)

	_temp_slider = HSlider.new()
	_temp_slider.min_value = 0.0
	_temp_slider.max_value = 1.5
	_temp_slider.step = 0.05
	_temp_slider.value = 0.7
	_temp_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_temp_slider.custom_minimum_size = Vector2(120, 0)
	_temp_slider.value_changed.connect(_on_temp_changed)
	hbox.add_child(_temp_slider)

	_temp_label = Label.new()
	_temp_label.text = "0.70"
	_temp_label.add_theme_color_override("font_color", ArcReactor.TEXT_PRIMARY)
	_temp_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	_temp_label.custom_minimum_size = Vector2(36, 0)
	hbox.add_child(_temp_label)

	# ─── Tool-mode radio ─────────────────────────────────────────────
	var tool_text := Label.new()
	tool_text.text = "Tools"
	tool_text.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	tool_text.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	hbox.add_child(tool_text)

	var tool_group := ButtonGroup.new()
	for mode in TOOL_MODES:
		var btn := Button.new()
		btn.text = mode
		btn.toggle_mode = true
		btn.button_group = tool_group
		btn.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
		btn.button_pressed = (mode == "auto")
		btn.pressed.connect(_on_tool_mode_selected.bind(mode))
		hbox.add_child(btn)
		_tool_mode_buttons[mode] = btn


# ─── Event handlers ───────────────────────────────────────────────────────

func _on_model_selected(index: int) -> void:
	if _muted:
		return
	var name: String = _model_button.get_item_text(index)
	_publish_set_config({"model": name})
	config_changed.emit("model", name)


func _on_temp_changed(value: float) -> void:
	_temp_label.text = "%.2f" % value
	if _muted:
		return
	_publish_set_config({"temperature": value})
	config_changed.emit("temperature", value)


func _on_tool_mode_selected(mode: String) -> void:
	if _muted:
		return
	_publish_set_config({"tool_mode": mode})
	config_changed.emit("tool_mode", mode)


func _publish_set_config(parameters: Dictionary) -> void:
	if _mqtt == null:
		return
	_mqtt.publish(OCPMessage.cmd_topic("dawn"), JSON.stringify({
		"device": "godot-dawn-ui",
		"msg_type": "command",
		"action": "set_config",
		"parameters": parameters,
		"timestamp": OCPMessage.now_ms(),
	}))


# ─── Remote-driven update entry point ─────────────────────────────────────

## Call when a dawn/events config_update arrives. Mutes the signal/publish
## path while applying so we don't echo the change back to the server.
func apply_config_update(payload: Dictionary) -> void:
	_muted = true
	if payload.has("model"):
		var model: String = str(payload["model"])
		for i in range(_model_button.item_count):
			if _model_button.get_item_text(i) == model:
				_model_button.select(i)
				break
	if payload.has("temperature"):
		_temp_slider.value = float(payload["temperature"])
	if payload.has("tool_mode"):
		var mode: String = str(payload["tool_mode"])
		if _tool_mode_buttons.has(mode):
			_tool_mode_buttons[mode].button_pressed = true
	_muted = false
