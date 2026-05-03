## Component-grouped Provider control panel (ADR-0001).
##
## Three-level toggle hierarchy:
##   Global "Toggle All" → Component toggle → Data source toggle
##
## Every mocked data source is independently toggleable between
## SIMULATED and LIVE, organized by the O.A.S.I.S. component that
## owns the data. All toggles publish OCP messages to the stream.
##
## Components:
##   M.I.R.A.G.E. — Camera, Audio (with waveform visualization)
##   A.U.R.A.     — Motion (IMU), GPS, Environmental
##   S.T.A.T.     — System metrics, Battery
##   D.A.W.N.     — LLM responder
extends PanelContainer

const PT = preload("res://resources/presentation_theme.gd")

signal stream_toggled(paused: bool)
signal source_toggled(source_name: String, live: bool)

# --- Source definitions ---
# Each source: component, simulated OCP label, live OCP label
const SOURCE_DEFS := {
	"camera":  {"component": "mirage", "sim": "test-pattern", "live": "usb"},
	"audio":   {"component": "mirage", "sim": "sine-wave",    "live": "microphone"},
	"motion":  {"component": "aura",   "sim": "simulated",    "live": "imu"},
	"gps":     {"component": "aura",   "sim": "simulated",    "live": "receiver"},
	"environ": {"component": "aura",   "sim": "simulated",    "live": "sensors"},
	"system":  {"component": "stat",   "sim": "simulated",    "live": "os-metrics"},
	"battery": {"component": "stat",   "sim": "simulated",    "live": "monitor"},
	"llm":     {"component": "dawn",   "sim": "mock-responder", "live": "dawn-server"},
}

var COMPONENTS := {
	"mirage": {"label": "M.I.R.A.G.E.", "color": PT.COMP_MIRAGE,
			   "header": "MirageHeader", "section": "MirageSection"},
	"aura":   {"label": "A.U.R.A.",     "color": PT.COMP_AURA,
			   "header": "AuraHeader",   "section": "AuraSection"},
	"stat":   {"label": "S.T.A.T.",     "color": PT.COMP_STAT,
			   "header": "StatHeader",   "section": "StatSection"},
	"dawn":   {"label": "D.A.W.N.",     "color": PT.COMP_DAWN,
			   "header": "DawnHeader",   "section": "DawnSection"},
}

# Row node name mapping (source_name -> {status: node_name, btn: node_name, label: node_name})
const ROW_NODES := {
	"camera":  {"row": "CameraRow",  "status": "CameraStatus",  "btn": "CameraBtn",  "label": "CameraLabel"},
	"audio":   {"row": "AudioRow",   "status": "AudioStatus",   "btn": "AudioBtn",   "label": "AudioLabel"},
	"motion":  {"row": "MotionRow",  "status": "MotionStatus",  "btn": "MotionBtn",  "label": "MotionLabel"},
	"gps":     {"row": "GPSRow",     "status": "GPSStatus",     "btn": "GPSBtn",     "label": "GPSLabel"},
	"environ": {"row": "EnvironRow", "status": "EnvironStatus", "btn": "EnvironBtn", "label": "EnvironLabel"},
	"system":  {"row": "SystemRow",  "status": "SystemStatus",  "btn": "SystemBtn",  "label": "SystemLabel"},
	"battery": {"row": "BatteryRow", "status": "BatteryStatus", "btn": "BatteryBtn", "label": "BatteryLabel"},
	"llm":     {"row": "LLMRow",     "status": "LLMStatus",     "btn": "LLMBtn",     "label": "LLMLabel"},
}

# --- Runtime state ---
var _source_live: Dictionary = {}  # source_name -> bool
var _stream_live: bool = true
var _mqtt: MQTTBridge = null

# Audio-specific state
var _mic_player: AudioStreamPlayer = null
var _audio_effect: AudioEffectCapture = null
var _sim_phase: float = 0.0
var _volume_db: float = -40.0
var _waveform: PackedFloat32Array = []

# Node references (populated in _ready)
var _status_labels: Dictionary = {}  # source_name -> Label
var _toggle_btns: Dictionary = {}    # source_name -> Button

# Drag state
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _collapsed: bool = false

@onready var body: VBoxContainer = $VBox/Body
@onready var drag_handle: Label = $VBox/DragBar/DragHandle
@onready var collapse_btn: Button = $VBox/DragBar/CollapseBtn
@onready var toggle_all_btn: Button = $VBox/Body/ToggleAllRow/ToggleAllBtn
@onready var toggle_all_status: Label = $VBox/Body/ToggleAllRow/ToggleAllStatus
@onready var stream_status: Label = $VBox/Body/StreamRow/StreamStatus
@onready var stream_btn: Button = $VBox/Body/StreamRow/StreamBtn
@onready var volume_bar: ProgressBar = $VBox/Body/MirageSection/VolumeBar
@onready var waveform_canvas: Control = $VBox/Body/MirageSection/WaveformCanvas


func _ready():
	# Initialize all sources to simulated
	for source_name in SOURCE_DEFS:
		_source_live[source_name] = false

	_style_panel()
	_setup_drag_bar()
	_setup_toggle_all()
	_setup_stream_row()
	_setup_component_sections()
	_setup_source_rows()
	_setup_audio_visualization()
	_setup_dpad()
	_set_focus_none_recursive(self)
	_setup_capture_bus()

	# Cache MQTT reference
	var oasis_mqtt = get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		_mqtt = oasis_mqtt.get_mqtt()

	_update_all_ui()


# --- Setup helpers ---

func _style_panel():
	var style := StyleBoxFlat.new()
	style.bg_color = PT.PANEL_BG
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	for side in ["bottom", "top", "left", "right"]:
		style.set("border_width_%s" % side, 1)
	style.border_color = PT.PANEL_BORDER
	add_theme_stylebox_override("panel", style)


func _setup_drag_bar():
	# Style drag handle
	drag_handle.add_theme_font_size_override("font_size", PT.CP_LABEL)
	drag_handle.add_theme_color_override("font_color", PT.COLOR_ACCENT)
	drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_handle.gui_input.connect(_on_drag_input)
	# Collapse button
	collapse_btn.add_theme_font_size_override("font_size", PT.CP_LABEL)
	var btn_style = _make_btn_style(Color("1a1e2400"))
	collapse_btn.add_theme_stylebox_override("normal", btn_style)
	collapse_btn.add_theme_color_override("font_color", PT.COLOR_DIM)
	collapse_btn.pressed.connect(_on_collapse)


func _on_drag_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_offset = get_global_mouse_position() - global_position
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		# Switch to manual positioning on first drag
		if anchors_preset != 0:
			_switch_to_manual_position()
		global_position = get_global_mouse_position() - _drag_offset


func _switch_to_manual_position():
	# Capture current position, then disable anchors
	var current_global = global_position
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	global_position = current_global
	# Let the panel auto-size to content
	size = Vector2.ZERO


func _on_collapse():
	_collapsed = not _collapsed
	body.visible = not _collapsed
	collapse_btn.text = "▶" if _collapsed else "▼"
	drag_handle.text = "≡ Providers" if not _collapsed else "≡"
	# Force size recalculation
	size = Vector2.ZERO
	reset_size()


func _make_btn_style(bg: Color = PT.BTN_BG) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(4)
	s.content_margin_left = 6.0
	s.content_margin_right = 6.0
	s.content_margin_top = 2.0
	s.content_margin_bottom = 2.0
	return s


func _setup_toggle_all():
	var all_style = _make_btn_style(PT.BTN_ACCENT_BG)
	all_style.border_width_bottom = 1
	all_style.border_color = PT.PANEL_BORDER
	toggle_all_btn.add_theme_stylebox_override("normal", all_style)
	toggle_all_btn.add_theme_font_size_override("font_size", PT.CP_LABEL)
	toggle_all_btn.add_theme_color_override("font_color", PT.COLOR_ACCENT)
	toggle_all_btn.pressed.connect(_on_toggle_all)
	toggle_all_status.add_theme_font_size_override("font_size", PT.CP_LABEL)


func _setup_stream_row():
	var lbl = $VBox/Body/StreamRow/StreamLabel
	lbl.add_theme_font_size_override("font_size", PT.CP_LABEL)
	lbl.add_theme_color_override("font_color", PT.COLOR_DIM)
	stream_status.add_theme_font_size_override("font_size", PT.CP_LABEL)
	stream_btn.add_theme_font_size_override("font_size", PT.CP_LABEL)
	stream_btn.add_theme_stylebox_override("normal", _make_btn_style())
	stream_btn.pressed.connect(_on_stream_toggle)

	# Separator styling
	for sep_name in ["Sep1", "Sep2"]:
		var sep = body.get_node_or_null(sep_name)
		if sep:
			sep.add_theme_constant_override("separation", 2)
			sep.add_theme_stylebox_override("separator", StyleBoxLine.new())


func _setup_component_sections():
	var header_style = _make_btn_style(Color("1a1e2400"))  # Transparent bg
	for comp_id in COMPONENTS:
		var comp = COMPONENTS[comp_id]
		var header: Button = body.get_node(comp["header"])
		var section: VBoxContainer = body.get_node(comp["section"])
		header.add_theme_stylebox_override("normal", header_style.duplicate())
		header.add_theme_font_size_override("font_size", PT.CP_HEADER)
		header.add_theme_color_override("font_color", comp["color"])
		# Toggle collapse on click
		header.pressed.connect(_on_component_header.bind(comp_id))


func _setup_source_rows():
	var btn_style = _make_btn_style()
	for source_name in ROW_NODES:
		var nodes = ROW_NODES[source_name]
		var comp_id = SOURCE_DEFS[source_name]["component"]
		var section = body.get_node(COMPONENTS[comp_id]["section"])
		var status_lbl: Label = section.find_child(nodes["status"], true, false)
		var btn: Button = section.find_child(nodes["btn"], true, false)
		var label: Label = section.find_child(nodes["label"], true, false)

		if label:
			label.add_theme_font_size_override("font_size", PT.CP_LABEL)
			label.add_theme_color_override("font_color", PT.COLOR_DIM)
		if status_lbl:
			status_lbl.add_theme_font_size_override("font_size", PT.CP_LABEL)
			_status_labels[source_name] = status_lbl
		if btn:
			btn.add_theme_font_size_override("font_size", PT.CP_LABEL)
			btn.add_theme_stylebox_override("normal", btn_style.duplicate())
			btn.pressed.connect(_on_source_toggle.bind(source_name))
			_toggle_btns[source_name] = btn


func _setup_audio_visualization():
	# Volume bar
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color("121417")
	bar_bg.set_corner_radius_all(2)
	volume_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = PT.COLOR_ACCENT
	bar_fill.set_corner_radius_all(2)
	volume_bar.add_theme_stylebox_override("fill", bar_fill)
	# Waveform
	_waveform.resize(64)
	_waveform.fill(0.0)
	waveform_canvas.draw.connect(_draw_waveform.bind(waveform_canvas))


func _setup_dpad():
	var dpad_style = _make_btn_style()
	dpad_style.content_margin_left = 4.0
	dpad_style.content_margin_right = 4.0
	for btn_name in ["BtnUp", "BtnDown", "BtnLeft", "BtnRight", "BtnJump"]:
		var btn: Button = find_child(btn_name, true, false)
		if btn:
			btn.add_theme_stylebox_override("normal", dpad_style.duplicate())
			btn.add_theme_font_size_override("font_size", PT.CP_DPAD)
			btn.pressed.connect(_on_dpad.bind(btn_name))


func _setup_capture_bus():
	var idx = AudioServer.get_bus_index("MicCapture")
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "MicCapture")
	AudioServer.set_bus_mute(idx, true)
	if AudioServer.get_bus_effect_count(idx) == 0:
		var effect = AudioEffectCapture.new()
		effect.buffer_length = 0.1
		AudioServer.add_bus_effect(idx, effect)
	_audio_effect = AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture


func _set_focus_none_recursive(node: Node):
	if node is Control:
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_set_focus_none_recursive(child)


# --- Public API ---

## Returns whether the OCP message stream is paused (simulated mode).
func is_stream_paused() -> bool:
	return not _stream_live


## Returns whether a specific source is live.
func is_source_live(source_name: String) -> bool:
	return _source_live.get(source_name, false)


# --- Toggle All (global) ---

func _on_toggle_all():
	var all_live = _are_all_live()
	var target = not all_live
	_set_stream(target)
	for source_name in SOURCE_DEFS:
		_set_source(source_name, target)
	_update_all_ui()


func _are_all_live() -> bool:
	if not _stream_live:
		return false
	for source_name in _source_live:
		if not _source_live[source_name]:
			return false
	return true


func _are_all_sim() -> bool:
	if _stream_live:
		return false
	for source_name in _source_live:
		if _source_live[source_name]:
			return false
	return true


func _update_toggle_all_ui():
	if _are_all_live():
		toggle_all_status.text = "● LIVE"
		toggle_all_status.add_theme_color_override("font_color", PT.COLOR_LIVE)
		toggle_all_btn.text = "→ Simulated"
	elif _are_all_sim():
		toggle_all_status.text = "● SIMULATED"
		toggle_all_status.add_theme_color_override("font_color", PT.COLOR_SIM)
		toggle_all_btn.text = "→ Live"
	else:
		toggle_all_status.text = "● MIXED"
		toggle_all_status.add_theme_color_override("font_color", PT.COLOR_MIXED)
		toggle_all_btn.text = "→ Live"


# --- Component toggle (collapse + toggle all sources) ---

func _on_component_header(comp_id: String):
	var section = body.get_node(COMPONENTS[comp_id]["section"])
	section.visible = not section.visible
	var header: Button = body.get_node(COMPONENTS[comp_id]["header"])
	var arrow = "▶" if not section.visible else "▼"
	header.text = "%s %s" % [arrow, COMPONENTS[comp_id]["label"]]


# --- Stream toggle (standalone — display filter, not a Provider) ---

func _on_stream_toggle():
	_set_stream(not _stream_live)
	_update_all_ui()


func _set_stream(live: bool):
	_stream_live = live
	_update_stream_ui()
	stream_toggled.emit(not _stream_live)
	_publish_swap("ocp-stream", "live" if _stream_live else "filtered", "display")


func _update_stream_ui():
	if _stream_live:
		stream_status.text = "● LIVE"
		stream_status.add_theme_color_override("font_color", PT.COLOR_LIVE)
		stream_btn.text = "Pause"
	else:
		stream_status.text = "● SIM"
		stream_status.add_theme_color_override("font_color", PT.COLOR_SIM)
		stream_btn.text = "Resume"


# --- Generic source toggle ---

func _on_source_toggle(source_name: String):
	_set_source(source_name, not _source_live[source_name])
	_update_all_ui()


func _set_source(source_name: String, live: bool):
	_source_live[source_name] = live

	# Audio has special hardware handling
	if source_name == "audio":
		if live:
			_connect_mic()
		else:
			_disconnect_mic()

	_update_source_ui(source_name)
	var def = SOURCE_DEFS[source_name]
	_publish_swap(source_name, def["live"] if live else def["sim"], def["component"])
	source_toggled.emit(source_name, live)


func _update_source_ui(source_name: String):
	var live = _source_live[source_name]
	var status_lbl = _status_labels.get(source_name)
	var btn = _toggle_btns.get(source_name)
	if status_lbl:
		if live:
			status_lbl.text = "● LIVE"
			status_lbl.add_theme_color_override("font_color", PT.COLOR_LIVE)
		else:
			status_lbl.text = "● SIM"
			status_lbl.add_theme_color_override("font_color", PT.COLOR_SIM)
	if btn:
		btn.text = "Disconnect" if live else "Connect"


func _update_all_ui():
	_update_stream_ui()
	for source_name in SOURCE_DEFS:
		_update_source_ui(source_name)
	_update_toggle_all_ui()


# --- Audio hardware ---

func _connect_mic():
	if _mic_player == null:
		_mic_player = AudioStreamPlayer.new()
		_mic_player.name = "MicPlayer"
		_mic_player.bus = &"MicCapture"
		_mic_player.stream = AudioStreamMicrophone.new()
		add_child(_mic_player)
	_mic_player.play()
	if _audio_effect:
		_audio_effect.clear_buffer()


func _disconnect_mic():
	if _mic_player:
		_mic_player.stop()


# --- OCP publish ---

func _publish_swap(provider: String, source: String, component: String):
	if _mqtt:
		_mqtt.publish(OCPMessage.status_topic("godot-control"), JSON.stringify({
			"device": "godot-control",
			"msg_type": "status",
			"provider": provider,
			"source": source,
			"component": component,
			"timestamp": OCPMessage.now_ms(),
		}))


# --- Audio visualization ---

func _process(delta: float):
	if _source_live.get("audio", false):
		_process_live_audio()
	else:
		_process_simulated_audio(delta)
	volume_bar.value = remap(clampf(_volume_db, -60.0, 0.0), -60.0, 0.0, 0.0, 100.0)
	waveform_canvas.queue_redraw()


func _process_simulated_audio(delta: float):
	_sim_phase += delta * 2.0
	_volume_db = -30.0 + 10.0 * sin(_sim_phase * 1.3) + 5.0 * sin(_sim_phase * 3.7)
	for i in range(_waveform.size() - 1):
		_waveform[i] = _waveform[i + 1]
	_waveform[_waveform.size() - 1] = 0.3 * sin(_sim_phase * 8.0) + 0.15 * sin(_sim_phase * 19.0)


func _process_live_audio():
	if _audio_effect == null:
		return
	var frames = _audio_effect.get_frames_available()
	if frames <= 0:
		return
	var buf = _audio_effect.get_buffer(min(frames, 256))
	if buf.size() == 0:
		return
	var sum_sq: float = 0.0
	for frame in buf:
		var sample = (frame.x + frame.y) * 0.5
		sum_sq += sample * sample
	var rms = sqrt(sum_sq / buf.size())
	if rms > 0.00001:
		_volume_db = 20.0 * log(rms) / log(10.0)
	else:
		_volume_db = -60.0
	var step_size = max(1, buf.size() / _waveform.size())
	for i in range(_waveform.size()):
		var idx = min(i * step_size, buf.size() - 1)
		_waveform[i] = (buf[idx].x + buf[idx].y) * 0.5


func _draw_waveform(canvas: Control):
	var w = canvas.size.x
	var h = canvas.size.y
	var mid_y = h * 0.5
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), PT.WAVEFORM_BG)
	canvas.draw_line(Vector2(0, mid_y), Vector2(w, mid_y), PT.WAVEFORM_MID, 1.0)
	var color = PT.COLOR_LIVE if _source_live.get("audio", false) else PT.COLOR_ACCENT
	var points: PackedVector2Array = []
	for i in range(_waveform.size()):
		var x = float(i) / (_waveform.size() - 1) * w
		var y = mid_y - _waveform[i] * h * 0.8
		points.append(Vector2(x, y))
	if points.size() > 1:
		canvas.draw_polyline(points, color, 2.0, true)


# --- D-pad ---

func _on_dpad(btn_name: String):
	var action := ""
	var params := {}
	match btn_name:
		"BtnUp":
			action = "move_forward"
			params = {"distance": 1.5}
		"BtnDown":
			action = "move_back"
			params = {"distance": 1.5}
		"BtnLeft":
			action = "move_left"
			params = {"distance": 1.5}
		"BtnRight":
			action = "move_right"
			params = {"distance": 1.5}
		"BtnJump":
			action = "jump"

	if action.is_empty():
		return

	if _mqtt:
		_mqtt.publish(OCPMessage.cmd_topic("e3-avatar"), JSON.stringify({
			"device": "e3-avatar",
			"msg_type": "command",
			"action": action,
			"parameters": params,
			"timestamp": OCPMessage.now_ms(),
		}))
