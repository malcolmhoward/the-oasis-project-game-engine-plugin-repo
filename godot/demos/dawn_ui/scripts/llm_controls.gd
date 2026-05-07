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
# to overwrite this. Each entry is [display_name, model_id] so the
# OptionButton stays compact while the published command uses the full
# canonical model id.
const DEFAULT_MODELS := [
	["Opus 4.7",   "claude-opus-4-7"],
	["Sonnet 4.6", "claude-sonnet-4-6"],
	["Haiku 4.5",  "claude-haiku-4-5"],
	["GPT-4.1",    "gpt-4.1"],
	["GPT-4o m",   "gpt-4o-mini"],
	["Gemini 2.5", "gemini-2.5-pro"],
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
	# Two-row stack so the bar fits at the DawnUI panel's typical width
	# (~480 px in the demo). Row 1: model + temperature. Row 2: tools.
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", ArcReactor.SPACE_XS)
	add_child(vbox)

	# ─── Row 1: Model select + Temperature slider ────────────────────
	var row1 := HBoxContainer.new()
	row1.name = "Row1"
	row1.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	vbox.add_child(row1)

	var model_label := Label.new()
	model_label.text = "Model"
	model_label.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	model_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	row1.add_child(model_label)

	_model_button = OptionButton.new()
	_model_button.flat = false
	_model_button.fit_to_longest_item = true
	_model_button.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	for entry in DEFAULT_MODELS:
		_model_button.add_item(entry[0])  # display name only
	_model_button.item_selected.connect(_on_model_selected)
	row1.add_child(_model_button)

	# Cap the popup height so a tall list of models scrolls inside the
	# popup instead of extending below the DawnUI panel and getting
	# clipped by the bottom edge. 120 px ≈ exactly 4 items visible with
	# items 5+ accessible via the popup's internal scrollbar; previous
	# 130 left the 6th item half-clipped at the bottom edge.
	_model_button.get_popup().max_size = Vector2i(0, 120)

	var temp_text := Label.new()
	temp_text.text = "Temp"
	temp_text.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	temp_text.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	row1.add_child(temp_text)

	_temp_slider = HSlider.new()
	_temp_slider.min_value = 0.0
	_temp_slider.max_value = 1.5
	_temp_slider.step = 0.05
	_temp_slider.value = 0.7
	_temp_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_temp_slider.custom_minimum_size = Vector2(60, 0)
	_temp_slider.value_changed.connect(_on_temp_changed)
	row1.add_child(_temp_slider)

	_temp_label = Label.new()
	_temp_label.text = "0.70"
	_temp_label.add_theme_color_override("font_color", ArcReactor.TEXT_PRIMARY)
	_temp_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	_temp_label.custom_minimum_size = Vector2(36, 0)
	row1.add_child(_temp_label)

	# ─── Row 2: Tool-mode radio ──────────────────────────────────────
	var row2 := HBoxContainer.new()
	row2.name = "Row2"
	row2.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	vbox.add_child(row2)

	var tool_text := Label.new()
	tool_text.text = "Tools"
	tool_text.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	tool_text.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	row2.add_child(tool_text)

	var tool_group := ButtonGroup.new()
	for mode in TOOL_MODES:
		var btn := Button.new()
		btn.text = mode
		btn.toggle_mode = true
		btn.button_group = tool_group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
		btn.button_pressed = (mode == "auto")
		btn.pressed.connect(_on_tool_mode_selected.bind(mode))
		row2.add_child(btn)
		_tool_mode_buttons[mode] = btn


# ─── Event handlers ───────────────────────────────────────────────────────

func _on_model_selected(index: int) -> void:
	if _muted:
		return
	if index < 0 or index >= DEFAULT_MODELS.size():
		return
	var model_id: String = DEFAULT_MODELS[index][1]  # canonical id
	_publish_set_config({"model": model_id})
	config_changed.emit("model", model_id)


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
		var model_id: String = str(payload["model"])
		# Match against canonical id in the registry; the OptionButton
		# only carries the display name so we can't compare against it.
		for i in range(DEFAULT_MODELS.size()):
			if DEFAULT_MODELS[i][1] == model_id:
				_model_button.select(i)
				break
	if payload.has("temperature"):
		_temp_slider.value = float(payload["temperature"])
	if payload.has("tool_mode"):
		var mode: String = str(payload["tool_mode"])
		if _tool_mode_buttons.has(mode):
			_tool_mode_buttons[mode].button_pressed = true
	_muted = false
