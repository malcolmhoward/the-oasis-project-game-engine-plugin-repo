## D.A.W.N. settings panel (Phase 4).
##
## Two tabs:
##   - Audio: TTS voice, mic enabled, sample rate
##   - LLM:   provider, max context tokens, streaming on/off
##
## Each control change publishes a v1.4 OCP command on dawn/cmd:
##   { action: "set_setting", parameters: { <field>: <value> } }
## Server-driven changes arrive as dawn/events `setting_update` and
## are routed through apply_event() to update controls without echoing
## back.
##
## Inherits the floating-panel chrome (CanvasLayer + draggable +
## collapsible drag bar + close) from FloatingPanel; only the body
## (the two tabs of form controls) and the publish/apply plumbing
## live here.
extends "res://demos/dawn_ui/scripts/floating_panel.gd"

const TTS_VOICES := ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]
const LLM_PROVIDERS := ["claude", "openai", "gemini", "local"]

signal setting_changed(field: String, value: Variant)

# Audio tab controls
var _voice_button: OptionButton = null
var _mic_check: CheckBox = null
var _sample_rate_button: OptionButton = null

# LLM tab controls
var _provider_button: OptionButton = null
var _context_slider: HSlider = null
var _context_label: Label = null
var _streaming_check: CheckBox = null

# Suppress publish path while applying remote update
var _muted: bool = false

var _mqtt: MQTTBridge = null


func _init() -> void:
	dialog_title = "Settings"
	dialog_size = Vector2(440, 380)
	default_position = DefaultPosition.TOP_RIGHT


func _ready() -> void:
	super._ready()
	var oasis_mqtt := get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		_mqtt = oasis_mqtt.get_mqtt()


# ─── Body construction (override) ─────────────────────────────────────────

func _build_body(parent: MarginContainer) -> void:
	var tab_container := TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_theme_font_size_override("font_size", ArcReactor.FONT_BODY)
	tab_container.add_theme_color_override("font_selected_color", ArcReactor.TEXT_PRIMARY)
	tab_container.add_theme_color_override("font_unselected_color", ArcReactor.TEXT_SECONDARY)
	tab_container.add_theme_color_override("font_hovered_color", ArcReactor.ARC_CORE)
	if _font_sans:
		tab_container.add_theme_font_override("font", _font_sans)
	parent.add_child(tab_container)

	tab_container.add_child(_build_audio_tab())
	tab_container.add_child(_build_llm_tab())


func _make_form_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	lbl.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		lbl.add_theme_font_override("font", _font_sans)
	return lbl


func _make_tab_page(name: String) -> MarginContainer:
	var page := MarginContainer.new()
	page.name = name
	page.add_theme_constant_override("margin_left", ArcReactor.SPACE_SM)
	page.add_theme_constant_override("margin_right", ArcReactor.SPACE_SM)
	page.add_theme_constant_override("margin_top", ArcReactor.SPACE_MD)
	page.add_theme_constant_override("margin_bottom", ArcReactor.SPACE_SM)
	return page


func _build_audio_tab() -> Control:
	var page := _make_tab_page("Audio")

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", ArcReactor.SPACE_MD)
	grid.add_theme_constant_override("v_separation", ArcReactor.SPACE_MD)
	page.add_child(grid)

	grid.add_child(_make_form_label("TTS voice"))
	_voice_button = OptionButton.new()
	_voice_button.fit_to_longest_item = true
	_voice_button.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		_voice_button.add_theme_font_override("font", _font_sans)
	for v in TTS_VOICES:
		_voice_button.add_item(v)
	_voice_button.selected = TTS_VOICES.find("alloy")
	_voice_button.item_selected.connect(_on_voice_selected)
	_voice_button.get_popup().max_size = Vector2i(0, 130)
	grid.add_child(_voice_button)

	grid.add_child(_make_form_label("Microphone"))
	_mic_check = CheckBox.new()
	_mic_check.text = "Enabled"
	_mic_check.button_pressed = true
	_mic_check.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		_mic_check.add_theme_font_override("font", _font_sans)
	_mic_check.toggled.connect(_on_mic_toggled)
	grid.add_child(_mic_check)

	grid.add_child(_make_form_label("Sample rate"))
	_sample_rate_button = OptionButton.new()
	_sample_rate_button.fit_to_longest_item = true
	_sample_rate_button.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		_sample_rate_button.add_theme_font_override("font", _font_sans)
	for hz in ["16000 Hz", "24000 Hz", "44100 Hz", "48000 Hz"]:
		_sample_rate_button.add_item(hz)
	_sample_rate_button.selected = 1  # 24kHz default — matches DAWN web UI
	_sample_rate_button.item_selected.connect(_on_sample_rate_selected)
	_sample_rate_button.get_popup().max_size = Vector2i(0, 130)
	grid.add_child(_sample_rate_button)

	return page


func _build_llm_tab() -> Control:
	var page := _make_tab_page("LLM")

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", ArcReactor.SPACE_MD)
	grid.add_theme_constant_override("v_separation", ArcReactor.SPACE_MD)
	page.add_child(grid)

	grid.add_child(_make_form_label("Provider"))
	_provider_button = OptionButton.new()
	_provider_button.fit_to_longest_item = true
	_provider_button.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		_provider_button.add_theme_font_override("font", _font_sans)
	for p in LLM_PROVIDERS:
		_provider_button.add_item(p)
	_provider_button.item_selected.connect(_on_provider_selected)
	_provider_button.get_popup().max_size = Vector2i(0, 130)
	grid.add_child(_provider_button)

	grid.add_child(_make_form_label("Max context"))
	var ctx_row := HBoxContainer.new()
	ctx_row.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	_context_slider = HSlider.new()
	_context_slider.min_value = 4000
	_context_slider.max_value = 200000
	_context_slider.step = 1000
	_context_slider.value = 64000
	_context_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_context_slider.custom_minimum_size = Vector2(120, 0)
	_context_slider.value_changed.connect(_on_context_changed)
	ctx_row.add_child(_context_slider)
	_context_label = Label.new()
	_context_label.text = "64k"
	_context_label.add_theme_color_override("font_color", ArcReactor.TEXT_PRIMARY)
	_context_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	_context_label.custom_minimum_size = Vector2(48, 0)
	if _font_sans:
		_context_label.add_theme_font_override("font", _font_sans)
	ctx_row.add_child(_context_label)
	grid.add_child(ctx_row)

	grid.add_child(_make_form_label("Streaming"))
	_streaming_check = CheckBox.new()
	_streaming_check.text = "Enabled"
	_streaming_check.button_pressed = true
	_streaming_check.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		_streaming_check.add_theme_font_override("font", _font_sans)
	_streaming_check.toggled.connect(_on_streaming_toggled)
	grid.add_child(_streaming_check)

	return page


# ─── Event handlers ───────────────────────────────────────────────────────

func _on_voice_selected(idx: int) -> void:
	if _muted or idx < 0:
		return
	var voice: String = TTS_VOICES[idx]
	_publish_set_setting({"tts_voice": voice})
	setting_changed.emit("tts_voice", voice)


func _on_mic_toggled(pressed: bool) -> void:
	if _muted:
		return
	_publish_set_setting({"mic_enabled": pressed})
	setting_changed.emit("mic_enabled", pressed)


func _on_sample_rate_selected(idx: int) -> void:
	if _muted or idx < 0:
		return
	var rate_label: String = _sample_rate_button.get_item_text(idx)
	var rate: int = int(rate_label.split(" ")[0])
	_publish_set_setting({"sample_rate_hz": rate})
	setting_changed.emit("sample_rate_hz", rate)


func _on_provider_selected(idx: int) -> void:
	if _muted or idx < 0:
		return
	var provider: String = LLM_PROVIDERS[idx]
	_publish_set_setting({"llm_provider": provider})
	setting_changed.emit("llm_provider", provider)


func _on_context_changed(value: float) -> void:
	var int_value: int = int(value)
	_context_label.text = _format_tokens(int_value)
	if _muted:
		return
	_publish_set_setting({"max_context_tokens": int_value})
	setting_changed.emit("max_context_tokens", int_value)


func _on_streaming_toggled(pressed: bool) -> void:
	if _muted:
		return
	_publish_set_setting({"streaming": pressed})
	setting_changed.emit("streaming", pressed)


func _format_tokens(n: int) -> String:
	if n >= 1000:
		return "%dk" % (n / 1000)
	return "%d" % n


func _publish_set_setting(parameters: Dictionary) -> void:
	if _mqtt == null:
		return
	_mqtt.publish(OCPMessage.cmd_topic("dawn"), JSON.stringify({
		"device": "godot-dawn-ui",
		"msg_type": "command",
		"action": "set_setting",
		"parameters": parameters,
		"timestamp": OCPMessage.now_ms(),
	}))


# ─── Public API ───────────────────────────────────────────────────────────

func apply_event(payload: Dictionary) -> void:
	_muted = true
	if payload.has("tts_voice"):
		var idx := TTS_VOICES.find(str(payload["tts_voice"]))
		if idx >= 0:
			_voice_button.select(idx)
	if payload.has("mic_enabled"):
		_mic_check.button_pressed = bool(payload["mic_enabled"])
	if payload.has("sample_rate_hz"):
		var hz: int = int(payload["sample_rate_hz"])
		for i in range(_sample_rate_button.item_count):
			if _sample_rate_button.get_item_text(i).begins_with(str(hz)):
				_sample_rate_button.select(i)
				break
	if payload.has("llm_provider"):
		var idx2 := LLM_PROVIDERS.find(str(payload["llm_provider"]))
		if idx2 >= 0:
			_provider_button.select(idx2)
	if payload.has("max_context_tokens"):
		_context_slider.value = float(payload["max_context_tokens"])
	if payload.has("streaming"):
		_streaming_check.button_pressed = bool(payload["streaming"])
	_muted = false
