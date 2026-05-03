## M.I.R.A.G.E. HUD scene — camera feed background with data overlay.
##
## Provider-toggled data sources:
##   Camera — SIMULATED: SMPTE test pattern, LIVE: USB webcam (CameraServer)
##   S.T.A.T. — SIMULATED: sine-wave oscillation, LIVE: MQTT stat topic
##
## HUD elements drawn using MirageHUD design tokens extracted from the
## real M.I.R.A.G.E. C codebase (config.json, element_renderer.c).
extends Control

const MH = preload("res://resources/mirage_design_tokens.gd")

# Multi-level simulation model (followup deck slide_02):
#   L0_LOCAL      — Test pattern, fully in-process
#   L2_HOST       — Real USB camera on host (DirectShow / V4L2)
#   L3_CONTAINER  — Captured frames from a running M.I.R.A.G.E. container
enum CameraMode { L0_LOCAL, L2_HOST, L3_CONTAINER }

var _camera_mode: CameraMode = CameraMode.L0_LOCAL
var _camera_live: bool = false  # Convenience: true when mode != L0_LOCAL
var _stat_live: bool = false

## ffmpeg input args for L3 — captures the M.I.R.A.G.E. container's surface.
## Default targets a host window titled "MIRAGE" via gdigrab on Windows.
## Override per platform: x11grab `:0.0` on Linux, avfoundation index on macOS,
## or RTMP `rtmp://localhost:1935/live/mirage` once the upstream RTMP-URL
## patch lands (see followup deck slide_04_l3_options).
@export var l3_ffmpeg_input_args: PackedStringArray = PackedStringArray([
	"-f", "gdigrab",
	"-framerate", "10",
	"-i", "title=MIRAGE"
])

# Simulated metric state
var _sim_phase: float = 0.0
var _cpu: float = 35.0
var _mem: float = 62.0
var _temp: float = 48.0
var _battery_pct: float = 85.0
var _battery_voltage: float = 12.4
var _fan: float = 45.0

# Live metric state (from MQTT)
var _live_cpu: float = 0.0
var _live_mem: float = 0.0
var _live_temp: float = 0.0
var _live_battery_pct: float = 0.0
var _live_battery_voltage: float = 0.0
var _live_fan: float = 0.0

# Environmental data (from aura/Enviro)
var _env_humidity: float = -1.0
var _env_aqi: float = -1.0
var _env_eco2: float = -1.0
# GPS data (from aura/GPS)
var _gps_lat: float = NAN
var _gps_lon: float = NAN
var _gps_lat_hemi: String = ""
var _gps_lon_hemi: String = ""

var _camera_texture: ImageTexture = null
var _test_pattern: ImageTexture = null
var _camera_feed: CameraFeed = null
var _noise_frames: Array[ImageTexture] = []
var _noise_frame_idx: int = 0
var _noise_timer: float = 0.0

# ffmpeg-based camera capture (fallback when CameraServer unavailable)
var _ffmpeg_pid: int = -1
var _ffmpeg_path: String = ""
var _ffmpeg_output_path: String = ""
var _ffmpeg_read_timer: float = 0.0
var _ffmpeg_last_size: int = 0  # Detect when frame changes
var _ffmpeg_stale_timer: float = 0.0  # Watchdog for frozen feed
const FFMPEG_FPS := 10
const FFMPEG_READ_INTERVAL := 0.15  # Read frame every 150ms
const FFMPEG_STALE_TIMEOUT := 3.0   # Restart ffmpeg if no new frame for 3 seconds

@onready var camera_bg: TextureRect = $CameraBackground
@onready var top_bar_label: Label = $HUDOverlay/TopBar/MirageLabel
@onready var time_label: Label = $HUDOverlay/TopBar/TimeLabel
@onready var date_label: Label = $HUDOverlay/DateLabel
@onready var status_dot: Label = $HUDOverlay/TopBar/StatusDot
@onready var compass_label: Label = $HUDOverlay/CompassBar
@onready var compass_strip = $HUDOverlay/CompassStrip
@onready var pitch_ladder = $HUDOverlay/PitchLadder
@onready var gps_label: Label = $HUDOverlay/GPSLabel
@onready var stat_panel_bg: PanelContainer = $HUDOverlay/StatPanelBG
@onready var stat_panel: Control = $HUDOverlay/StatPanelBG/StatPanel
@onready var cpu_value: Label = $HUDOverlay/StatPanelBG/StatPanel/CPURow/Value
@onready var mem_value: Label = $HUDOverlay/StatPanelBG/StatPanel/MEMRow/Value
@onready var temp_value: Label = $HUDOverlay/StatPanelBG/StatPanel/TEMPRow/Value
@onready var fan_value: Label = $HUDOverlay/StatPanelBG/StatPanel/FANRow/Value
@onready var hum_value: Label = $HUDOverlay/StatPanelBG/StatPanel/HUMRow/Value
@onready var aqi_value: Label = $HUDOverlay/StatPanelBG/StatPanel/AQIRow/Value
@onready var co2_value: Label = $HUDOverlay/StatPanelBG/StatPanel/CO2Row/Value
@onready var bat_value: Label = $HUDOverlay/StatPanelBG/StatPanel/BATRow/Value
@onready var bat_volt: Label = $HUDOverlay/StatPanelBG/StatPanel/BATRow/Voltage
@onready var fps_label: Label = $HUDOverlay/FPSCounter
@onready var alert_label: Label = $HUDOverlay/AlertArea

@onready var cam_mode_label: Label = $HUDOverlay/CamModeLabel
@onready var ai_icon: TextureRect = $HUDOverlay/AIIcon
@onready var ai_name_label: Label = $HUDOverlay/AIName
@onready var pitch_value: Label = $HUDOverlay/PitchValue
@onready var center_reticle: TextureRect = $HUDOverlay/CenterReticle
@onready var armor_display: TextureRect = $HUDOverlay/ArmorDisplay
@onready var cpumem_panel: TextureRect = $HUDOverlay/CPUMEMPanel
@onready var clock_box: TextureRect = $HUDOverlay/ClockBox
@onready var pitch_box: TextureRect = $HUDOverlay/PitchBox

# AI state icon textures (loaded from scratch assets)
var _ai_icons: Dictionary = {}
var _devgothic: Font = null
var _aldrich: Font = null

const ASSET_BASE := "res://scratch/mirage_assets/"


func _ready():
	_generate_test_pattern()
	camera_bg.texture = _test_pattern

	# Load real M.I.R.A.G.E. assets (manual loading — bypasses import system)
	_load_overlay_textures()
	_load_fonts()
	_load_ai_icons()

	# Subscribe to MQTT for live S.T.A.T. data
	var oasis_mqtt = get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_mqtt_message)

	# Enable camera monitoring (required on some platforms)
	CameraServer.set_monitoring_feeds(true)

	# Style HUD elements
	_style_hud()


func _load_png(path: String) -> ImageTexture:
	var abs_path = ProjectSettings.globalize_path(path)
	var img = Image.new()
	var err = img.load(abs_path)
	if err == OK and not img.is_empty():
		return ImageTexture.create_from_image(img)
	print("[MirageHUD] Failed to load: %s" % path)
	return null


func _load_overlay_textures():
	var tex: ImageTexture
	tex = _load_png(ASSET_BASE + "mk2/IronMan-UI-CenterRect.png")
	if tex and center_reticle:
		center_reticle.texture = tex
	tex = _load_png(ASSET_BASE + "mk2/IronMan-UI-CPUMEM-V4.png")
	if not tex:
		tex = _load_png(ASSET_BASE + "mk2/IronMan-UI-CPUMEM-V3.png")
	if tex and cpumem_panel:
		cpumem_panel.texture = tex
	tex = _load_png(ASSET_BASE + "mk2/IronMan-UI-ClockBox.png")
	if tex and clock_box:
		clock_box.texture = tex
	tex = _load_png(ASSET_BASE + "mk2/IronMan-UI-PitchBox.png")
	if tex and pitch_box:
		pitch_box.texture = tex
	tex = _load_png(ASSET_BASE + "mk2/FullBody-Blue-Composite.png")
	if tex and armor_display:
		armor_display.texture = tex


func _load_fonts():
	for font_info in [["devgothic.ttf", "_devgothic"], ["Aldrich-Regular.ttf", "_aldrich"]]:
		var abs_path = ProjectSettings.globalize_path(ASSET_BASE + "fonts/" + font_info[0])
		var font = FontFile.new()
		var err = font.load_dynamic_font(abs_path)
		if err == OK:
			set(font_info[1], font)
		else:
			print("[MirageHUD] Failed to load font: %s" % font_info[0])


func _load_ai_icons():
	for state in ["grey", "green", "purple", "red", "blue"]:
		var tex = _load_png(ASSET_BASE + "mk2/AI-%s.png" % state)
		if tex:
			_ai_icons[state] = tex
	if _ai_icons.has("grey") and ai_icon:
		ai_icon.texture = _ai_icons["grey"]


func _process(delta: float):
	# Update system time + date
	var t = Time.get_time_dict_from_system()
	time_label.text = MH.FMT_TIME % [t["hour"], t["minute"], t["second"]]
	if date_label:
		var d = Time.get_date_dict_from_system()
		date_label.text = "%04d.%02d.%02d" % [d["year"], d["month"], d["day"]]

	# Update FPS
	fps_label.text = MH.FMT_FPS % Engine.get_frames_per_second()

	# Camera feed update
	if _camera_live:
		if _ffmpeg_pid > 0:
			# Read ffmpeg output frame
			_ffmpeg_read_timer += delta
			_ffmpeg_stale_timer += delta
			if _ffmpeg_read_timer >= FFMPEG_READ_INTERVAL:
				_ffmpeg_read_timer = 0.0
				_read_ffmpeg_frame()
			# Watchdog: restart ffmpeg if no new frames
			if _ffmpeg_stale_timer > FFMPEG_STALE_TIMEOUT:
				print("[MirageHUD] Camera feed stale — restarting ffmpeg")
				_stop_ffmpeg()
				_start_ffmpeg()
		elif _camera_feed:
			# CameraServer feed (if available)
			var img = _camera_feed.get_image(CameraServer.FEED_RGBA_IMAGE)
			if img and not img.is_empty():
				if _camera_texture == null:
					_camera_texture = ImageTexture.create_from_image(img)
					camera_bg.texture = _camera_texture
				else:
					_camera_texture.update(img)
		elif _noise_frames.size() > 0:
			# Fallback — cycle noise frames
			_noise_timer += delta
			if _noise_timer > 0.1:
				_noise_timer = 0.0
				_noise_frame_idx = (_noise_frame_idx + 1) % _noise_frames.size()
				camera_bg.texture = _noise_frames[_noise_frame_idx]

	# Update metrics
	if _stat_live:
		_display_metrics(_live_cpu, _live_mem, _live_temp, _live_fan, _live_battery_pct, _live_battery_voltage)
	else:
		_process_simulated_metrics(delta)
		_display_metrics(_cpu, _mem, _temp, _fan, _battery_pct, _battery_voltage)

	# Simulated compass and pitch drift
	var heading = fmod(Time.get_unix_time_from_system() * 2.0, 360.0)
	compass_label.text = "%s %03d°" % [_heading_to_cardinal(heading), int(round(heading))]
	if compass_strip:
		compass_strip.heading_deg = heading
	var pitch_now: float = 5.0 * sin(Time.get_unix_time_from_system() * 0.5)
	pitch_value.text = "%d" % int(pitch_now)
	if pitch_ladder:
		pitch_ladder.pitch_deg = pitch_now

	_update_gps_label()


func _process_simulated_metrics(delta: float):
	_sim_phase += delta
	_cpu = 35.0 + 10.0 * sin(_sim_phase * 0.7) + 5.0 * sin(_sim_phase * 1.9)
	_mem = 62.0 + 3.0 * sin(_sim_phase * 0.3)
	_temp = 48.0 + 4.0 * sin(_sim_phase * 0.5)
	_fan = 45.0 + 15.0 * sin(_sim_phase * 0.6)
	_battery_pct = max(0.0, 85.0 - _sim_phase * 0.02)  # Slow drain
	_battery_voltage = 12.4 - (85.0 - _battery_pct) * 0.01


func _display_metrics(cpu: float, mem: float, temp: float, fan: float, bat: float, volts: float):
	cpu_value.text = MH.FMT_CPU % cpu
	mem_value.text = MH.FMT_MEM % mem
	temp_value.text = MH.FMT_TEMP_C % temp
	fan_value.text = MH.FMT_CPU % fan  # Same 3-digit % format
	bat_value.text = MH.FMT_BATTERY_PCT % bat
	bat_volt.text = MH.FMT_VOLTAGE % volts

	# Color thresholds
	temp_value.add_theme_color_override("font_color",
		MH.WARNING_ORANGE if temp > MH.WARN_TEMP_C else MH.DATA_WHITE)
	bat_value.add_theme_color_override("font_color",
		MH.ALERT_RED if bat < 15.0 else MH.WARNING_ORANGE if bat < 30.0 else MH.DATA_WHITE)


func _heading_to_cardinal(degrees: float) -> String:
	var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var idx = int(round(degrees / 45.0)) % 8
	return dirs[idx]


# --- Camera Provider ---

## Back-compat shim — maps boolean toggle to L0_LOCAL / L2_HOST.
## New code should call set_camera_mode() directly.
func set_camera_live(live: bool):
	set_camera_mode(CameraMode.L2_HOST if live else CameraMode.L0_LOCAL)


## Set camera mode explicitly. L0 disables capture, L2 uses host USB,
## L3 captures the M.I.R.A.G.E. container's surface via ffmpeg.
func set_camera_mode(mode: CameraMode):
	if mode == _camera_mode and _camera_live == (mode != CameraMode.L0_LOCAL):
		return
	_camera_mode = mode
	if mode == CameraMode.L0_LOCAL:
		_stop_camera()
	else:
		_activate_camera()


func _stop_camera():
	_camera_live = false
	_camera_texture = null
	_noise_frame_idx = 0
	camera_bg.texture = _test_pattern
	cam_mode_label.text = "CAM: L0 — Fully Local (test pattern)"
	cam_mode_label.add_theme_color_override("font_color", MH.WARNING_ORANGE)
	if _camera_feed:
		_camera_feed.set_active(false)
		_camera_feed = null
	_stop_ffmpeg()


func _activate_camera():
	# L3 always uses ffmpeg with the container-capture command — never CameraServer.
	if _camera_mode == CameraMode.L3_CONTAINER:
		_ffmpeg_path = _find_ffmpeg()
		if _ffmpeg_path.is_empty():
			_camera_live = true
			cam_mode_label.text = "CAM: L3 — ffmpeg not found"
			cam_mode_label.add_theme_color_override("font_color", MH.ALERT_RED)
			return
		_start_ffmpeg()
		return

	# L2 — try CameraServer first, then fall back to ffmpeg with USB device input.
	var feed_count = CameraServer.get_feed_count()
	print("[MirageHUD] CameraServer feeds: %d" % feed_count)
	if feed_count > 0:
		_camera_feed = CameraServer.get_feed(0)
		_camera_feed.set_active(true)
		print("[MirageHUD] CameraServer feed: %s" % _camera_feed.get_name())
		_camera_live = true
		cam_mode_label.text = "CAM: L2 — Real Source (host USB)"
		cam_mode_label.add_theme_color_override("font_color", MH.PRIMARY_CYAN)
		return

	_ffmpeg_path = _find_ffmpeg()
	if not _ffmpeg_path.is_empty():
		_start_ffmpeg()
		return

	# Last resort — simulated noise
	print("[MirageHUD] No camera backend available — using noise")
	_camera_live = true
	if _noise_frames.is_empty():
		_generate_noise_frames()
	camera_bg.texture = _noise_frames[0]
	cam_mode_label.text = "CAM: L0 — Fully Local (noise fallback)"
	cam_mode_label.add_theme_color_override("font_color", MH.PRIMARY_CYAN)


func _find_ffmpeg() -> String:
	# Check common ffmpeg locations on Windows
	var paths = [
		"ffmpeg",  # In PATH
	]
	# Search Downloads for ffmpeg directories
	var downloads = OS.get_environment("USERPROFILE") + "\\Downloads"
	var dir = DirAccess.open(downloads)
	if dir:
		dir.list_dir_begin()
		var entry = dir.get_next()
		while entry != "":
			if entry.begins_with("ffmpeg") and dir.current_is_dir():
				var candidate = downloads + "\\" + entry + "\\bin\\ffmpeg.exe"
				if FileAccess.file_exists(candidate):
					print("[MirageHUD] Found ffmpeg: %s" % candidate)
					return candidate
			entry = dir.get_next()
	# Try system PATH
	var output = []
	var ret = OS.execute("where", ["ffmpeg"], output, true)
	if ret == 0 and output.size() > 0 and output[0].strip_edges() != "":
		var found = output[0].strip_edges().split("\n")[0].strip_edges()
		print("[MirageHUD] Found ffmpeg in PATH: %s" % found)
		return found
	return ""


func _start_ffmpeg():
	_ffmpeg_output_path = OS.get_user_data_dir() + "/mirage_cam_frame.jpg"
	# Build input args based on current mode. -update 1 overwrites the same JPEG.
	var input_args: Array
	var mode_label: String
	var mode_color: Color
	if _camera_mode == CameraMode.L3_CONTAINER:
		input_args = Array(l3_ffmpeg_input_args)
		mode_label = "CAM: L3 — M.I.R.A.G.E. Container"
		mode_color = MH.ARMOR_ONLINE
	else:
		input_args = ["-f", "dshow", "-i", "video=HD Pro Webcam C920", "-r", str(FFMPEG_FPS)]
		mode_label = "CAM: L2 — Real Source (host USB)"
		mode_color = MH.PRIMARY_CYAN
	var args := input_args + [
		"-s", "640x480",
		"-q:v", "5",
		"-update", "1",
		"-y", _ffmpeg_output_path,
	]
	print("[MirageHUD] Starting ffmpeg: %s %s" % [_ffmpeg_path, " ".join(args)])
	_ffmpeg_pid = OS.create_process(_ffmpeg_path, args)
	_ffmpeg_stale_timer = 0.0
	_ffmpeg_last_size = 0
	if _ffmpeg_pid > 0:
		_camera_live = true
		cam_mode_label.text = mode_label
		cam_mode_label.add_theme_color_override("font_color", mode_color)
		print("[MirageHUD] ffmpeg started, pid=%d" % _ffmpeg_pid)
	else:
		print("[MirageHUD] ffmpeg failed to start")
		_camera_live = true
		if _camera_mode == CameraMode.L3_CONTAINER:
			# L3 with no source — show a clear disconnected state instead of fallback.
			camera_bg.texture = _test_pattern
			cam_mode_label.text = "CAM: L3 — M.I.R.A.G.E. source disconnected"
			cam_mode_label.add_theme_color_override("font_color", MH.ALERT_RED)
		else:
			if _noise_frames.is_empty():
				_generate_noise_frames()
			camera_bg.texture = _noise_frames[0]
			cam_mode_label.text = "CAM: L0 — Fully Local (noise fallback)"
			cam_mode_label.add_theme_color_override("font_color", MH.PRIMARY_CYAN)


func _stop_ffmpeg():
	if _ffmpeg_pid > 0:
		OS.kill(_ffmpeg_pid)
		_ffmpeg_pid = -1
		print("[MirageHUD] ffmpeg stopped")


func _read_ffmpeg_frame():
	if not FileAccess.file_exists(_ffmpeg_output_path):
		return
	# Check if file size changed (new frame written)
	var file = FileAccess.open(_ffmpeg_output_path, FileAccess.READ)
	if file == null:
		return  # File locked by ffmpeg — skip this frame
	var size = file.get_length()
	var bytes = file.get_buffer(size)
	file.close()
	if size < 100 or size == _ffmpeg_last_size:
		return  # Incomplete write or same frame
	_ffmpeg_last_size = size
	_ffmpeg_stale_timer = 0.0  # Reset watchdog — got a new frame
	var img = Image.new()
	var err = img.load_jpg_from_buffer(bytes)
	if err != OK or img.is_empty():
		return
	if _camera_texture == null:
		_camera_texture = ImageTexture.create_from_image(img)
		camera_bg.texture = _camera_texture
	else:
		_camera_texture.update(img)


func _exit_tree():
	_stop_ffmpeg()


func _generate_test_pattern():
	# SMPTE color bar test pattern
	var w := 640
	var h := 480
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var colors := [
		Color.WHITE, Color.YELLOW, Color.CYAN, Color.GREEN,
		Color.MAGENTA, Color.RED, Color.BLUE,
	]
	var bar_w := w / colors.size()
	for i in range(colors.size()):
		var x_start := i * bar_w
		var x_end := (i + 1) * bar_w if i < colors.size() - 1 else w
		for x in range(x_start, x_end):
			for y in range(h):
				img.set_pixel(x, y, colors[i])
	# Dark bottom strip
	for x in range(w):
		for y in range(int(h * 0.75), h):
			img.set_pixel(x, y, Color(0.05, 0.05, 0.05))
	_test_pattern = ImageTexture.create_from_image(img)


# --- S.T.A.T. Provider ---

func set_stat_live(live: bool):
	_stat_live = live
	if not live:
		_sim_phase = 0.0  # Reset simulated oscillation


func _on_mqtt_message(topic: String, payload: String):
	# aura/enviro/gps drive HUD readouts even in L0 stat mode (they're
	# independent A.U.R.A. data sources, not part of the stat provider).
	if topic == "aura":
		var amsg = JSON.parse_string(payload)
		if amsg is Dictionary:
			_consume_aura(amsg)
		return

	if not _stat_live:
		return
	if topic != "stat":
		return
	var msg = JSON.parse_string(payload)
	if not msg is Dictionary:
		return
	var device = msg.get("device", "")
	if device == "SystemMetrics":
		_live_cpu = msg.get("cpu_percent", _live_cpu)
		_live_mem = msg.get("memory_percent", _live_mem)
		_live_temp = msg.get("system_temp", _live_temp)
		_live_fan = msg.get("fan_load", _live_fan)
	elif device == "BatteryStatus":
		_live_battery_pct = msg.get("percentage", _live_battery_pct)
		_live_battery_voltage = msg.get("voltage", _live_battery_voltage)


func _consume_aura(msg: Dictionary) -> void:
	var device: String = msg.get("device", "")
	match device:
		"GPS":
			_gps_lat = float(msg.get("latitudeDegrees", msg.get("latitude", NAN)))
			_gps_lon = float(msg.get("longitudeDegrees", msg.get("longitude", NAN)))
			_gps_lat_hemi = str(msg.get("lat", ""))
			_gps_lon_hemi = str(msg.get("lon", ""))
		"Enviro":
			_env_humidity = float(msg.get("humidity", _env_humidity))
			_env_aqi = float(msg.get("air_quality", _env_aqi))
			_env_eco2 = float(msg.get("eco2_ppm", _env_eco2))
			_update_environmental_rows()


func _update_environmental_rows() -> void:
	if hum_value and _env_humidity >= 0:
		hum_value.text = "%02d%%" % int(round(_env_humidity))
	if aqi_value and _env_aqi >= 0:
		aqi_value.text = "%03d" % int(round(_env_aqi))
		var aqi_color: Color = MH.DATA_WHITE
		if _env_aqi < 50:
			aqi_color = MH.ARMOR_ONLINE
		elif _env_aqi < 100:
			aqi_color = MH.WARNING_ORANGE
		else:
			aqi_color = MH.ALERT_RED
		aqi_value.add_theme_color_override("font_color", aqi_color)
	if co2_value and _env_eco2 >= 0:
		co2_value.text = "%4d" % int(round(_env_eco2))


func _update_gps_label() -> void:
	if gps_label == null:
		return
	if is_nan(_gps_lat) or is_nan(_gps_lon):
		gps_label.text = "GPS: ---"
		return
	gps_label.text = "GPS: %.4f%s, %.4f%s" % [
		absf(_gps_lat), _gps_lat_hemi if _gps_lat_hemi != "" else ("N" if _gps_lat >= 0 else "S"),
		absf(_gps_lon), _gps_lon_hemi if _gps_lon_hemi != "" else ("E" if _gps_lon >= 0 else "W"),
	]


func _generate_noise_frames():
	# Pre-generate 8 noise frames at low res (64x48) — TextureRect stretches them
	var w := 64
	var h := 48
	for f in range(8):
		var img = Image.create(w, h, false, Image.FORMAT_RGB8)
		var scan_y = (f * 6) % h  # Moving scan line per frame
		for y in range(h):
			for x in range(w):
				var n = randf() * 0.15
				var scan_boost = 0.1 if abs(y - scan_y) < 2 else 0.0
				img.set_pixel(x, y, Color(n * 0.7, n + scan_boost, n * 0.7))
		_noise_frames.append(ImageTexture.create_from_image(img))


# --- Styling ---

func _style_hud():
	# Use real M.I.R.A.G.E. fonts with IBM Plex Mono as fallback
	var hud_font = _devgothic if _devgothic else load(MH.FONT_MONO_PATH)
	var label_font = _aldrich if _aldrich else hud_font

	# Top bar — devgothic (primary HUD font)
	top_bar_label.add_theme_font_size_override("font_size", MH.FONT_AI_NAME)
	top_bar_label.add_theme_color_override("font_color", MH.PRIMARY_CYAN)
	if hud_font:
		top_bar_label.add_theme_font_override("font", hud_font)

	time_label.add_theme_font_size_override("font_size", MH.FONT_TIME)
	time_label.add_theme_color_override("font_color", MH.PRIMARY_CYAN)
	if hud_font:
		time_label.add_theme_font_override("font", hud_font)

	status_dot.add_theme_font_size_override("font_size", MH.FONT_METRIC)
	status_dot.add_theme_color_override("font_color", MH.ARMOR_ONLINE)

	# Compass — devgothic, larger
	compass_label.add_theme_font_size_override("font_size", MH.FONT_COMPASS)
	compass_label.add_theme_color_override("font_color", MH.PRIMARY_CYAN)
	if hud_font:
		compass_label.add_theme_font_override("font", hud_font)

	# Date label — Aldrich subdued
	if date_label:
		date_label.add_theme_font_size_override("font_size", MH.FONT_METRIC)
		date_label.add_theme_color_override("font_color", MH.SECONDARY_CYAN)
		if label_font:
			date_label.add_theme_font_override("font", label_font)

	# GPS label — Aldrich, secondary cyan
	if gps_label:
		gps_label.add_theme_font_size_override("font_size", MH.FONT_METRIC)
		gps_label.add_theme_color_override("font_color", MH.SECONDARY_CYAN)
		if label_font:
			gps_label.add_theme_font_override("font", label_font)

	# AI name — devgothic, secondary cyan
	ai_name_label.add_theme_font_size_override("font_size", MH.FONT_AI_NAME)
	ai_name_label.add_theme_color_override("font_color", MH.SECONDARY_CYAN)
	if hud_font:
		ai_name_label.add_theme_font_override("font", hud_font)

	# Pitch value — devgothic, primary cyan
	pitch_value.add_theme_font_size_override("font_size", MH.FONT_PITCH)
	pitch_value.add_theme_color_override("font_color", MH.PRIMARY_CYAN)
	if hud_font:
		pitch_value.add_theme_font_override("font", hud_font)

	# Stat panel — Aldrich font (metric labels)
	var stat_bg = StyleBoxFlat.new()
	stat_bg.bg_color = MH.HUD_PANEL_BG
	stat_bg.set_corner_radius_all(4)
	stat_bg.content_margin_left = 8.0
	stat_bg.content_margin_right = 8.0
	stat_bg.content_margin_top = 4.0
	stat_bg.content_margin_bottom = 4.0
	stat_bg.border_width_left = 2
	stat_bg.border_color = MH.HUD_BORDER
	if stat_panel_bg:
		stat_panel_bg.add_theme_stylebox_override("panel", stat_bg)

	for row_name in ["CPURow", "MEMRow", "TEMPRow", "FANRow", "HUMRow", "AQIRow", "CO2Row", "BATRow"]:
		var row = stat_panel.get_node_or_null(row_name)
		if row:
			var label_node = row.get_node_or_null("Label")
			var value_node = row.get_node_or_null("Value")
			if label_node:
				label_node.add_theme_font_size_override("font_size", MH.FONT_METRIC)
				label_node.add_theme_color_override("font_color", MH.SECONDARY_CYAN)
				if label_font:
					label_node.add_theme_font_override("font", label_font)
			if value_node:
				value_node.add_theme_font_size_override("font_size", MH.FONT_METRIC)
				value_node.add_theme_color_override("font_color", MH.DATA_WHITE)
				if label_font:
					value_node.add_theme_font_override("font", label_font)
	# Battery voltage sub-label
	if bat_volt:
		bat_volt.add_theme_font_size_override("font_size", MH.FONT_LOG)
		bat_volt.add_theme_color_override("font_color", MH.SUBDUED_GRAY)
		if label_font:
			bat_volt.add_theme_font_override("font", label_font)

	# FPS — devgothic, primary cyan
	fps_label.add_theme_font_size_override("font_size", MH.FONT_METRIC)
	fps_label.add_theme_color_override("font_color", MH.PRIMARY_CYAN)
	if hud_font:
		fps_label.add_theme_font_override("font", hud_font)

	# Alert — devgothic, red
	alert_label.add_theme_font_size_override("font_size", MH.FONT_ALERT)
	alert_label.add_theme_color_override("font_color", MH.ALERT_RED)
	if hud_font:
		alert_label.add_theme_font_override("font", hud_font)

	# Camera mode — devgothic
	cam_mode_label.add_theme_font_size_override("font_size", MH.FONT_METRIC)
	cam_mode_label.add_theme_color_override("font_color", MH.WARNING_ORANGE)
	if hud_font:
		cam_mode_label.add_theme_font_override("font", hud_font)


