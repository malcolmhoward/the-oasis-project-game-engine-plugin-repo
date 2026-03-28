extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

const ARC_CORE := Color("2dd4bf")
const DEVICE_COLOR := Color("f0a050")   # orange
const NETWORK_COLOR := Color("5090e0")  # blue
const PLATFORM_COLOR := Color("008888") # teal
const PANEL_BG := Color("1a1e24")
const CHECK_COLOR := Color("2dd4bf")    # teal checkmarks

# Consistent bullet format with controlled spacing
const DEVICE_TEXT := """[color=#2dd4bf]✓[/color]  GPIO pins, I2C bus,
    SPI, camera

[color=#2dd4bf]✓[/color]  Sensors (IMU, temp,
    distance)

[color=#2dd4bf]✓[/color]  Actuators (servos,
    LEDs, displays)

[color=#2dd4bf]✓[/color]  Hot-swap: mock ↔ real
    at runtime"""

const NETWORK_TEXT := """[color=#2dd4bf]✓[/color]  MQTT broker
    (local Mosquitto)

[color=#2dd4bf]✓[/color]  OCP message routing

[color=#2dd4bf]✓[/color]  Peer discovery
    and heartbeat

[color=#2dd4bf]✓[/color]  All three OCP topics
    (status/discovery/command)"""

const PLATFORM_TEXT := """[color=#2dd4bf]✓[/color]  Godot visualization

[color=#2dd4bf]✓[/color]  E3 digital peers
    (game characters)

[color=#2dd4bf]✓[/color]  D.A.W.N. conversation
    interface

[color=#2dd4bf]✓[/color]  OCP traffic monitoring"""

var _headers: Array[Control] = []
var _panels: Array[Control] = []


func _ready():
	total_steps = 2

	# Style title
	$Title.add_theme_font_size_override("font_size", 56)
	$Title.add_theme_color_override("font_color", ARC_CORE)

	# Style headers
	_headers = [$DeviceHeader, $NetworkHeader, $PlatformHeader]
	var header_colors = [DEVICE_COLOR, NETWORK_COLOR, PLATFORM_COLOR]
	for i in _headers.size():
		_headers[i].add_theme_font_size_override("font_size", 32)
		_headers[i].add_theme_color_override("font_color", header_colors[i])

	# Style panels with dark backgrounds
	_panels = [$DevicePanel, $NetworkPanel, $PlatformPanel]
	for panel in _panels:
		var style := StyleBoxFlat.new()
		style.bg_color = PANEL_BG
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 24.0
		style.content_margin_right = 24.0
		style.content_margin_top = 24.0
		style.content_margin_bottom = 24.0
		panel.add_theme_stylebox_override("panel", style)

	# Set content with consistent formatting
	var contents = [
		$DevicePanel/DeviceContent,
		$NetworkPanel/NetworkContent,
		$PlatformPanel/PlatformContent,
	]
	var texts = [DEVICE_TEXT, NETWORK_TEXT, PLATFORM_TEXT]
	for i in contents.size():
		contents[i].add_theme_font_size_override("normal_font_size", 22)
		contents[i].text = texts[i]

	# Hide animated elements
	for h in _headers:
		h.visible = false
	for p in _panels:
		p.visible = false


func _animate_step(step: int) -> void:
	match step:
		1:
			# Headers slide in with stagger
			for i in _headers.size():
				_slide_in_left(_headers[i], 0.35, 40.0, i * 0.12)
		2:
			# Panels slide up with stagger
			for i in _panels.size():
				_slide_up(_panels[i], 0.4, 30.0, i * 0.12)


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			for h in _headers:
				h.visible = true
				h.modulate.a = 1.0
		2:
			for p in _panels:
				p.visible = true
				p.modulate.a = 1.0


func _reset_animations() -> void:
	for h in _headers:
		h.visible = false
		h.modulate.a = 0.0
	for p in _panels:
		p.visible = false
		p.modulate.a = 0.0
