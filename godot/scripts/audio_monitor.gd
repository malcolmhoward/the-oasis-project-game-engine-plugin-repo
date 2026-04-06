## Audio input monitor with Provider-style hot-swap demo.
##
## Shows a volume meter and waveform. Toggles between simulated
## audio (sine wave) and live microphone input via a button.
## Demonstrates the Provider pattern: same interface, different source.
##
## Requires project setting: audio/driver/enable_input = true
extends PanelContainer

var _is_live: bool = false
var _sim_phase: float = 0.0
var _volume_db: float = -40.0
var _waveform: PackedFloat32Array = []
var _audio_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null

@onready var toggle_button: Button = $VBox/Header/ToggleButton
@onready var status_label: Label = $VBox/Header/StatusLabel
@onready var volume_bar: ProgressBar = $VBox/VolumeBar
@onready var waveform_canvas: Control = $VBox/WaveformCanvas


func _ready():
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a1e24")
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)

	toggle_button.pressed.connect(_on_toggle)
	toggle_button.text = "Connect Mic"

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("2a3040")
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.content_margin_left = 6.0
	btn_style.content_margin_right = 6.0
	toggle_button.add_theme_stylebox_override("normal", btn_style)
	toggle_button.add_theme_font_size_override("font_size", 11)

	status_label.add_theme_font_size_override("font_size", 11)
	_update_status()

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color("121417")
	bar_bg.set_corner_radius_all(2)
	volume_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color("2dd4bf")
	bar_fill.set_corner_radius_all(2)
	volume_bar.add_theme_stylebox_override("fill", bar_fill)

	_waveform.resize(64)
	_waveform.fill(0.0)

	waveform_canvas.draw.connect(_draw_waveform.bind(waveform_canvas))
	_setup_capture_bus()


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


func _process(delta: float):
	if _is_live:
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


func _on_toggle():
	if _is_live:
		_disconnect_mic()
	else:
		_connect_mic()


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

	_is_live = true
	toggle_button.text = "Disconnect"
	_update_status()


func _disconnect_mic():
	if _mic_player:
		_mic_player.stop()

	_is_live = false
	_volume_db = -40.0
	_waveform.fill(0.0)
	toggle_button.text = "Connect Mic"
	_update_status()


func _update_status():
	if status_label:
		if _is_live:
			status_label.text = "● LIVE"
			status_label.add_theme_color_override("font_color", Color("44dd88"))
		else:
			status_label.text = "● SIMULATED"
			status_label.add_theme_color_override("font_color", Color("ccaa44"))


func _draw_waveform(canvas: Control):
	var w = canvas.size.x
	var h = canvas.size.y
	var mid_y = h * 0.5

	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("0d1014"))
	canvas.draw_line(Vector2(0, mid_y), Vector2(w, mid_y), Color("333333"), 1.0)

	var color = Color("44dd88") if _is_live else Color("2dd4bf")
	var points: PackedVector2Array = []
	for i in range(_waveform.size()):
		var x = float(i) / (_waveform.size() - 1) * w
		var y = mid_y - _waveform[i] * h * 0.8
		points.append(Vector2(x, y))

	if points.size() > 1:
		canvas.draw_polyline(points, color, 2.0, true)
