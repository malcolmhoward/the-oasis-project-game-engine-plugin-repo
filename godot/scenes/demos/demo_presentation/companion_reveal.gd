## Persistent companion face overlay for the presentation engine.
##
## Lives at the presentation level (not inside any slide or demo scene).
## Hidden initially. Becomes visible when the demo loads (positioned
## where the demo's HUD face appears). Optionally persists across slides
## when persist_after_demo is true.
##
## When the presentation ends, the companion can transition to a floating
## tray mode: text fades, face reacts, body grows, then the window
## shrinks to a borderless transparent overlay near the taskbar.
extends Control

enum Phase { HIDDEN, DEMO_ACTIVE, POST_DEMO, REVEAL, TRAY }

## If true, companion stays visible after the demo ends and persists
## across slides. If false, companion hides when the demo exits.
@export var persist_after_demo: bool = false

var _phase: Phase = Phase.HIDDEN
var _blink_timer: float = 0.0
var _blink_interval: float = 3.0
var _is_blinking: bool = false
var _reveal_timer: float = 0.0
var _reveal_phase: int = 0  # 0=confused, 1=looking, 2=settled, 3=floating
var _face_expression: int = 0  # 0=neutral, 1=confused, 2=looking, 3=smile
var _speaking_timer: float = 0.0
var _speaking_duration: float = 0.0
var _is_speaking: bool = false
var _expression: int = 0  # 0=neutral, 1=happy, 2=curious, 3=speaking
var _expression_timer: float = 0.0
var _original_window_size: Vector2i = Vector2i.ZERO
var _original_window_pos: Vector2i = Vector2i.ZERO

@onready var face_canvas: Control = $FaceCanvas
@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel


func _ready():
	visible = false
	_blink_interval = randf_range(2.0, 4.0)

	# Subscribe to MQTT for reactions
	var oasis_mqtt = get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_mqtt)

	face_canvas.draw.connect(_draw_face.bind(face_canvas))

	# Style health bar
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color("1a1e24")
	bar_bg.set_corner_radius_all(2)
	health_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color("2dd4bf")
	bar_fill.set_corner_radius_all(2)
	health_bar.add_theme_stylebox_override("fill", bar_fill)
	health_label.add_theme_font_size_override("font_size", 10)
	health_label.add_theme_color_override("font_color", Color("666666"))


func show_for_demo():
	"""Called by PresentationController when demo mode starts."""
	_phase = Phase.DEMO_ACTIVE
	visible = true
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func enter_post_demo():
	"""Called when exiting demo mode."""
	if persist_after_demo:
		_phase = Phase.POST_DEMO
	else:
		_phase = Phase.HIDDEN
		visible = false


func trigger_reveal():
	"""Called on the final slide — the big moment."""
	_phase = Phase.REVEAL
	_reveal_timer = 0.0
	_reveal_phase = 0
	_face_expression = 0
	_original_window_size = DisplayServer.window_get_size()
	_original_window_pos = DisplayServer.window_get_position()

	# Fade out health bar
	var tween = create_tween()
	tween.tween_property(health_bar, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(health_label, "modulate:a", 0.0, 1.0)


func restore_window():
	"""Restore the window to its original state (for recovery)."""
	if _original_window_size != Vector2i.ZERO:
		# Restore opacity and window flags
		get_viewport().transparent_bg = false
		RenderingServer.set_default_clear_color(Color("121417"))
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, false)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
		DisplayServer.window_set_size(_original_window_size)
		DisplayServer.window_set_position(_original_window_pos)
		# Reset companion to its normal size and position
		position = Vector2(1560, 680)  # Original position in presentation
		scale = Vector2.ONE
		face_canvas.position = Vector2(10, 0)
		face_canvas.size = Vector2(100, 80)
		health_bar.visible = true
		health_bar.modulate.a = 1.0
		health_label.visible = true
		health_label.modulate.a = 1.0
		# Restore sibling visibility
		var presentation = get_parent()
		if presentation:
			for child in presentation.get_children():
				child.visible = true
	_phase = Phase.POST_DEMO


func _process(delta: float):
	if not visible:
		return

	# Blink
	_blink_timer += delta
	if _is_blinking:
		if _blink_timer >= 0.15:
			_is_blinking = false
			_blink_timer = 0.0
			_blink_interval = randf_range(2.0, 4.0)
	else:
		if _blink_timer >= _blink_interval:
			_is_blinking = true
			_blink_timer = 0.0

	# Speaking timer
	if _is_speaking:
		_speaking_timer += delta
		if _speaking_timer >= _speaking_duration:
			_is_speaking = false
			_expression = 1  # happy
			_expression_timer = 0.0

	# Expression timeout (non-speaking)
	if not _is_speaking and _expression != 0:
		_expression_timer += delta
		if _expression_timer >= 2.0:
			_expression = 0

	# Reveal phases
	if _phase == Phase.REVEAL:
		_reveal_timer += delta
		_process_reveal(delta)

	face_canvas.queue_redraw()


func _process_reveal(_delta: float):
	match _reveal_phase:
		0:  # Wait a beat, then confused
			if _reveal_timer > 0.8:
				_face_expression = 1  # confused
				_reveal_phase = 1
		1:  # Looking around
			if _reveal_timer > 2.5:
				_face_expression = 2  # looking around
				_reveal_phase = 2
		2:  # Settle, then float
			if _reveal_timer > 4.0:
				_face_expression = 3  # gentle smile
				_reveal_phase = 3
				_start_float_to_tray()
		3:  # Floating (tween handles it)
			pass


func _start_float_to_tray():
	# Get screen info
	var screen_size = DisplayServer.screen_get_size()
	var window_size = DisplayServer.window_get_size()
	var window_pos = DisplayServer.window_get_position()

	# Target: bottom-right of screen, near taskbar
	# First, animate the face to the bottom-right of the current window
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", Vector2(window_size.x - 120, window_size.y - 140), 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# After floating, shrink window to just the face
	tween.chain().tween_callback(_transform_to_tray)


func _transform_to_tray():
	_phase = Phase.TRAY
	var screen_size = DisplayServer.screen_get_size()

	# Enable transparent background — only the face is visible
	get_viewport().transparent_bg = true
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)

	# Make window borderless, small, always-on-top
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)

	# Shrink to face size
	var face_size = Vector2i(140, 140)
	DisplayServer.window_set_size(face_size)

	# Position near bottom-right of screen (above taskbar)
	var tray_pos = Vector2i(screen_size.x - face_size.x - 10, screen_size.y - face_size.y - 50)
	DisplayServer.window_set_position(tray_pos)

	# The viewport is still 1920x1080 (canvas_items stretch mode) even
	# though the window is now tiny. Position the face at viewport center
	# and scale it up so it fills the small window.
	var viewport_size = get_viewport_rect().size  # 1920x1080
	position = Vector2(viewport_size.x / 2 - 250, viewport_size.y / 2 - 250)
	scale = Vector2(5.0, 5.0)  # Scale up to fill the viewport
	face_canvas.position = Vector2(0, 0)
	face_canvas.size = Vector2(100, 100)
	health_bar.visible = false
	health_label.visible = false

	# Hide everything else in the scene tree except us
	var presentation = get_parent()
	if presentation:
		for child in presentation.get_children():
			if child != self:
				child.visible = false


func _on_mqtt(topic: String, payload: String):
	if _phase == Phase.HIDDEN:
		return
	var msg = JSON.parse_string(payload)
	if msg is Dictionary and topic == "dawn":
		if msg.get("action") == "process_intent":
			_expression = 2  # curious
			_expression_timer = 0.0
		elif msg.get("action") == "speak":
			var text = str(msg.get("value", ""))
			_speaking_duration = text.length() / 50.0
			_speaking_timer = 0.0
			if msg.get("confused", false):
				# Show confusion first, then speak after a beat
				_expression = 2  # curious/confused (wide eyes, small O)
				_expression_timer = 0.0
				# Delay the speaking start
				get_tree().create_timer(0.8).timeout.connect(func():
					_is_speaking = true
					_expression = 3  # speaking
				, CONNECT_ONE_SHOT)
			else:
				_is_speaking = true
				_expression = 3  # speaking


func _input(event: InputEvent):
	# In tray mode, Shift+Escape restores the full window
	if _phase == Phase.TRAY and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and event.shift_pressed:
			restore_window()


func _draw_face(canvas: Control):
	var center = canvas.size / 2.0
	var radius = min(center.x, center.y) * 0.85

	# Face circle
	canvas.draw_circle(center, radius, Color("1b1f24"))
	canvas.draw_arc(center, radius, 0, TAU, 32, Color("2dd4bf"), 2.0)

	# Eyes
	var eye_y = center.y - radius * 0.15
	var eye_spread = radius * 0.35
	var eye_size = radius * 0.12

	# Reveal-specific eye behavior
	var use_reveal_eyes = (_phase == Phase.REVEAL and _face_expression > 0)

	if _is_blinking and not use_reveal_eyes:
		# Closed eyes
		canvas.draw_line(Vector2(center.x - eye_spread - eye_size, eye_y), Vector2(center.x - eye_spread + eye_size, eye_y), Color("2dd4bf"), 2.0)
		canvas.draw_line(Vector2(center.x + eye_spread - eye_size, eye_y), Vector2(center.x + eye_spread + eye_size, eye_y), Color("2dd4bf"), 2.0)
	else:
		var l_off = 0.0
		var r_off = 0.0
		var sz = eye_size

		if use_reveal_eyes:
			if _face_expression == 1:  # confused — wide eyes
				sz *= 1.5
			elif _face_expression == 2:  # looking around
				var shift = sin(_reveal_timer * 3.0) * eye_size * 0.8
				l_off = shift
				r_off = shift
		elif _expression == 2:  # curious
			sz *= 1.3

		canvas.draw_circle(Vector2(center.x - eye_spread + l_off, eye_y), sz, Color("2dd4bf"))
		canvas.draw_circle(Vector2(center.x + eye_spread + r_off, eye_y), sz, Color("2dd4bf"))

	# Mouth
	var mouth_y = center.y + radius * 0.3
	var mouth_width = radius * 0.35

	if use_reveal_eyes:
		# Reveal mouth expressions
		match _face_expression:
			1:  # confused — small O
				canvas.draw_arc(Vector2(center.x, mouth_y), mouth_width * 0.3, 0, TAU, 16, Color("2dd4bf"), 2.0)
			2:  # looking around — wobbly
				var w = sin(_reveal_timer * 4.0) * 3.0
				canvas.draw_line(Vector2(center.x - mouth_width * 0.4, mouth_y + w), Vector2(center.x + mouth_width * 0.4, mouth_y - w), Color("2dd4bf"), 2.0)
			3:  # gentle smile
				canvas.draw_arc(Vector2(center.x, mouth_y - radius * 0.1), mouth_width, 0.3, PI - 0.3, 12, Color("44ddaa"), 2.0)
	elif _is_speaking:
		# Speaking jaw
		var open = abs(sin(_speaking_timer * 8.0))
		var jaw = radius * 0.15 * open
		canvas.draw_line(Vector2(center.x - mouth_width * 0.4, mouth_y), Vector2(center.x + mouth_width * 0.4, mouth_y), Color("2dd4bf"), 2.0)
		canvas.draw_line(Vector2(center.x - mouth_width * 0.3, mouth_y + jaw + radius * 0.06), Vector2(center.x + mouth_width * 0.3, mouth_y + jaw + radius * 0.06), Color("2dd4bf"), 2.0)
		if jaw > radius * 0.03:
			canvas.draw_line(Vector2(center.x - mouth_width * 0.4, mouth_y), Vector2(center.x - mouth_width * 0.3, mouth_y + jaw + radius * 0.06), Color("2dd4bf"), 1.5)
			canvas.draw_line(Vector2(center.x + mouth_width * 0.4, mouth_y), Vector2(center.x + mouth_width * 0.3, mouth_y + jaw + radius * 0.06), Color("2dd4bf"), 1.5)
	elif _expression == 1:  # happy
		canvas.draw_arc(Vector2(center.x, mouth_y - radius * 0.1), mouth_width, 0.2, PI - 0.2, 16, Color("2dd4bf"), 2.0)
	elif _expression == 2:  # curious
		canvas.draw_arc(Vector2(center.x, mouth_y), mouth_width * 0.3, 0, TAU, 16, Color("2dd4bf"), 2.0)
	else:  # neutral
		canvas.draw_arc(Vector2(center.x, mouth_y - radius * 0.05), mouth_width * 0.6, 0.3, PI - 0.3, 12, Color("2dd4bf"), 2.0)
