## D.A.W.N. settings panel (Phase 4).
##
## Toggleable, draggable, collapsible CanvasLayer panel mirroring the
## web UI's settings overlay at a demo level. Two tabs:
##   - Audio: TTS voice, mic enabled, sample rate
##   - LLM:   provider, max context tokens, streaming on/off
##
## Each control change publishes a v1.4 OCP command on dawn/cmd:
##   { action: "set_setting", parameters: { <field>: <value> } }
## Server-driven changes arrive as dawn/events `setting_update` and
## are routed through apply_event() to update controls without echoing
## back.
##
## Same scaffolding pattern as memory_inspector.gd and
## conversation_history_sidebar.gd: CanvasLayer root, drag bar with
## collapse/close, body holds the tab container.
extends CanvasLayer

const ArcReactor = preload("res://resources/design_tokens.gd")

const _DEFAULT_DIALOG_SIZE := Vector2(440, 380)

const TTS_VOICES := ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]
const LLM_PROVIDERS := ["claude", "openai", "gemini", "local"]

signal setting_changed(field: String, value: Variant)

# UI nodes
var _root_control: Control = null
var _dialog_panel: PanelContainer = null
var _drag_handle: Label = null
var _collapse_button: Button = null
var _body_container: Control = null

# Audio tab controls
var _voice_button: OptionButton = null
var _mic_check: CheckBox = null
var _sample_rate_button: OptionButton = null

# LLM tab controls
var _provider_button: OptionButton = null
var _context_slider: HSlider = null
var _context_label: Label = null
var _streaming_check: CheckBox = null

# Drag/collapse state
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _collapsed: bool = false

# Suppress publish path while applying remote update
var _muted: bool = false

# Fonts
var _font_sans: Font = null
var _font_sans_bold: Font = null

var _mqtt: MQTTBridge = null


func _ready() -> void:
	visible = false
	layer = 64
	_load_project_fonts()
	_build_ui()
	var oasis_mqtt := get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		_mqtt = oasis_mqtt.get_mqtt()
	# Place the dialog in the viewport's right-side empty area so it
	# doesn't cover the DawnUI input column on the left.
	_set_default_position.call_deferred()


func _set_default_position() -> void:
	if _dialog_panel == null:
		return
	var viewport_size: Vector2 = get_tree().root.get_visible_rect().size
	var x: float = max(20.0, viewport_size.x - _DEFAULT_DIALOG_SIZE.x - 30.0)
	# Offset slightly below the memory inspector's default y so if both
	# happen to be open at once, the user can see they're distinct.
	var y: float = 120.0
	_dialog_panel.position = Vector2(x, y)


func _load_project_fonts() -> void:
	if ResourceLoader.exists(ArcReactor.FONT_SANS_PATH):
		_font_sans = load(ArcReactor.FONT_SANS_PATH)
	if ResourceLoader.exists(ArcReactor.FONT_SANS_BOLD):
		_font_sans_bold = load(ArcReactor.FONT_SANS_BOLD)


# ─── UI construction ──────────────────────────────────────────────────────

func _build_ui() -> void:
	# Dialog sits directly under the CanvasLayer — no full-rect parent
	# Control intercepting clicks. Mouse events outside the dialog's
	# bounds miss this CanvasLayer entirely and propagate down to the
	# main scene's controls (so the DawnUI input field can receive
	# focus while this settings panel is open).
	_dialog_panel = PanelContainer.new()
	_dialog_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_dialog_panel.custom_minimum_size = _DEFAULT_DIALOG_SIZE
	_dialog_panel.size = _DEFAULT_DIALOG_SIZE
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = ArcReactor.BG_DEEPEST
	style.border_color = ArcReactor.ARC_BORDER
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(ArcReactor.RADIUS_MD)
	_dialog_panel.add_theme_stylebox_override("panel", style)
	add_child(_dialog_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	_dialog_panel.add_child(root_vbox)

	_build_drag_bar(root_vbox)
	_build_body(root_vbox)


func _build_drag_bar(parent: VBoxContainer) -> void:
	var drag_bar := PanelContainer.new()
	var drag_style := StyleBoxFlat.new()
	drag_style.bg_color = ArcReactor.BG_DARK
	drag_style.corner_radius_top_left = ArcReactor.RADIUS_MD
	drag_style.corner_radius_top_right = ArcReactor.RADIUS_MD
	drag_style.content_margin_left = ArcReactor.SPACE_MD
	drag_style.content_margin_right = ArcReactor.SPACE_MD
	drag_style.content_margin_top = ArcReactor.SPACE_XS
	drag_style.content_margin_bottom = ArcReactor.SPACE_XS
	drag_bar.add_theme_stylebox_override("panel", drag_style)
	parent.add_child(drag_bar)

	var drag_row := HBoxContainer.new()
	drag_row.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	drag_bar.add_child(drag_row)

	_drag_handle = Label.new()
	_drag_handle.text = "≡ Settings"
	_drag_handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drag_handle.add_theme_color_override("font_color", ArcReactor.ARC_CORE)
	_drag_handle.add_theme_font_size_override("font_size", ArcReactor.FONT_SUBHEAD)
	_drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_handle.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_drag_handle.gui_input.connect(_on_drag_input)
	if _font_sans:
		_drag_handle.add_theme_font_override("font", _font_sans)
	drag_row.add_child(_drag_handle)

	_collapse_button = Button.new()
	_collapse_button.text = "▼"
	_collapse_button.flat = true
	_collapse_button.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	_collapse_button.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	_collapse_button.add_theme_color_override("font_hover_color", ArcReactor.TEXT_PRIMARY)
	_collapse_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_collapse_button.pressed.connect(_on_collapse)
	drag_row.add_child(_collapse_button)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.flat = true
	close_button.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	close_button.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	close_button.add_theme_color_override("font_hover_color", ArcReactor.STATUS_ERROR)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(_on_close)
	drag_row.add_child(close_button)


func _build_body(parent: VBoxContainer) -> void:
	_body_container = MarginContainer.new()
	_body_container.add_theme_constant_override("margin_left", ArcReactor.SPACE_MD)
	_body_container.add_theme_constant_override("margin_right", ArcReactor.SPACE_MD)
	_body_container.add_theme_constant_override("margin_top", ArcReactor.SPACE_SM)
	_body_container.add_theme_constant_override("margin_bottom", ArcReactor.SPACE_SM)
	_body_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_body_container)

	var tab_container := TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_theme_font_size_override("font_size", ArcReactor.FONT_BODY)
	tab_container.add_theme_color_override("font_selected_color", ArcReactor.TEXT_PRIMARY)
	tab_container.add_theme_color_override("font_unselected_color", ArcReactor.TEXT_SECONDARY)
	tab_container.add_theme_color_override("font_hovered_color", ArcReactor.ARC_CORE)
	if _font_sans:
		tab_container.add_theme_font_override("font", _font_sans)
	_body_container.add_child(tab_container)

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


func _build_audio_tab() -> Control:
	var page := MarginContainer.new()
	page.name = "Audio"
	page.add_theme_constant_override("margin_left", ArcReactor.SPACE_SM)
	page.add_theme_constant_override("margin_right", ArcReactor.SPACE_SM)
	page.add_theme_constant_override("margin_top", ArcReactor.SPACE_MD)
	page.add_theme_constant_override("margin_bottom", ArcReactor.SPACE_SM)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", ArcReactor.SPACE_MD)
	grid.add_theme_constant_override("v_separation", ArcReactor.SPACE_MD)
	page.add_child(grid)

	# TTS voice
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

	# Mic enabled
	grid.add_child(_make_form_label("Microphone"))
	_mic_check = CheckBox.new()
	_mic_check.text = "Enabled"
	_mic_check.button_pressed = true
	_mic_check.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		_mic_check.add_theme_font_override("font", _font_sans)
	_mic_check.toggled.connect(_on_mic_toggled)
	grid.add_child(_mic_check)

	# Sample rate
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
	var page := MarginContainer.new()
	page.name = "LLM"
	page.add_theme_constant_override("margin_left", ArcReactor.SPACE_SM)
	page.add_theme_constant_override("margin_right", ArcReactor.SPACE_SM)
	page.add_theme_constant_override("margin_top", ArcReactor.SPACE_MD)
	page.add_theme_constant_override("margin_bottom", ArcReactor.SPACE_SM)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", ArcReactor.SPACE_MD)
	grid.add_theme_constant_override("v_separation", ArcReactor.SPACE_MD)
	page.add_child(grid)

	# Provider
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

	# Max context (tokens)
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

	# Streaming
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
	# "24000 Hz" → 24000
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

func toggle() -> void:
	visible = not visible


## Apply a remote setting_update event without echoing back.
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


# ─── Drag + collapse ──────────────────────────────────────────────────────

func _on_close() -> void:
	visible = false


func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = _dialog_panel.get_global_mouse_position() - _dialog_panel.global_position
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_dialog_panel.global_position = _dialog_panel.get_global_mouse_position() - _drag_offset


func _on_collapse() -> void:
	_collapsed = not _collapsed
	if _body_container:
		_body_container.visible = not _collapsed
	if _collapse_button:
		_collapse_button.text = "▶" if _collapsed else "▼"
	if _collapsed:
		_dialog_panel.custom_minimum_size = Vector2.ZERO
	else:
		_dialog_panel.custom_minimum_size = _DEFAULT_DIALOG_SIZE
	_dialog_panel.size = Vector2.ZERO
	_dialog_panel.reset_size()
