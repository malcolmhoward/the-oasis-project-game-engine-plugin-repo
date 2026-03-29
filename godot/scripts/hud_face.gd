## HUD companion face — a small animated character in the corner of the game scene.
##
## An OCP peer that subscribes to status and sensor topics, updating its
## expression based on system state. Styled as standard game UI (health bar
## + face icon) so it blends into the scene naturally.
##
## Expressions:
##   neutral  — default idle, occasional blinks
##   happy    — command succeeded, peer came online
##   worried  — high CPU/temp, peer went offline
##   curious  — new peer discovered, new topic activity
##   sleeping — long idle period (30s+ no messages)
extends Control

enum FaceExpression { NEUTRAL, HAPPY, WORRIED, CURIOUS, SLEEPING }

var _current_expression: FaceExpression = FaceExpression.NEUTRAL
var _blink_timer: float = 0.0
var _blink_interval: float = 3.0
var _is_blinking: bool = false
var _blink_duration: float = 0.15
var _idle_timer: float = 0.0
var _expression_timer: float = 0.0
var _expression_duration: float = 2.0
var _health: float = 1.0
var _mqtt = null
var _msg_count: int = 0

@onready var face_canvas: Control = $FaceCanvas
@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
@onready var health_label: Label = $VBoxContainer/HealthLabel


func _ready():
	var oasis_mqtt = get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		_mqtt = oasis_mqtt.get_mqtt()
		oasis_mqtt.global_message.connect(_on_mqtt_message)
		oasis_mqtt.peer_discovered.connect(_on_peer_discovered)
		oasis_mqtt.peer_lost.connect(_on_peer_lost)

	# Randomize blink interval
	_blink_interval = randf_range(2.0, 5.0)


func _process(delta: float):
	# Blink timer
	_blink_timer += delta
	if _is_blinking:
		if _blink_timer >= _blink_duration:
			_is_blinking = false
			_blink_timer = 0.0
			_blink_interval = randf_range(2.0, 5.0)
	else:
		if _blink_timer >= _blink_interval:
			_is_blinking = true
			_blink_timer = 0.0

	# Idle timer — go to sleep after 30s of no messages
	_idle_timer += delta
	if _idle_timer > 30.0 and _current_expression == FaceExpression.NEUTRAL:
		_set_expression(FaceExpression.SLEEPING)

	# Expression timeout — return to neutral
	if _current_expression != FaceExpression.NEUTRAL and _current_expression != FaceExpression.SLEEPING:
		_expression_timer += delta
		if _expression_timer >= _expression_duration:
			_set_expression(FaceExpression.NEUTRAL)

	# Update health bar
	if health_bar:
		health_bar.value = _health

	# Redraw face
	if face_canvas:
		face_canvas.queue_redraw()


func _on_mqtt_message(_topic: String, _payload: String):
	_msg_count += 1
	_idle_timer = 0.0

	# Wake up if sleeping
	if _current_expression == FaceExpression.SLEEPING:
		_set_expression(FaceExpression.NEUTRAL)

	# Parse for system state
	var msg = JSON.parse_string(_payload)
	if msg is Dictionary:
		# High temperature → worried
		if msg.has("temp") and float(msg.get("temp", 22)) > 35:
			_set_expression(FaceExpression.WORRIED)
			_health = clampf(_health - 0.05, 0.0, 1.0)
		# CPU > 85% → worried
		if msg.has("cpu_percent") and float(msg.get("cpu_percent", 30)) > 85:
			_set_expression(FaceExpression.WORRIED)
		# Battery low
		if msg.has("percentage") and int(msg.get("percentage", 100)) < 20:
			_set_expression(FaceExpression.WORRIED)
			_health = clampf(float(msg.get("percentage", 100)) / 100.0, 0.0, 1.0)
		# Status online → happy briefly
		if msg.get("status") == "online" and _current_expression == FaceExpression.NEUTRAL:
			_set_expression(FaceExpression.HAPPY)

	# Update health label
	if health_label:
		health_label.text = "OCP Health"


func _on_peer_discovered(_peer_id: String, _data: Dictionary):
	_set_expression(FaceExpression.CURIOUS)
	_health = minf(_health + 0.1, 1.0)


func _on_peer_lost(_peer_id: String):
	_set_expression(FaceExpression.WORRIED)
	_health = clampf(_health - 0.15, 0.0, 1.0)


func _set_expression(expr: FaceExpression):
	_current_expression = expr
	_expression_timer = 0.0


func _draw_face(canvas: Control):
	# Called from FaceCanvas._draw() — see scene setup
	var center = canvas.size / 2.0
	var radius = min(center.x, center.y) * 0.8

	# Face circle
	canvas.draw_circle(center, radius, ArcReactorDark.BG_CARD)
	canvas.draw_arc(center, radius, 0, TAU, 32, ArcReactorDark.ARC_CORE, 2.0)

	# Eyes
	var eye_y = center.y - radius * 0.2
	var eye_spread = radius * 0.35
	var eye_size = radius * 0.12

	if _is_blinking or _current_expression == FaceExpression.SLEEPING:
		# Closed eyes — horizontal lines
		canvas.draw_line(
			Vector2(center.x - eye_spread - eye_size, eye_y),
			Vector2(center.x - eye_spread + eye_size, eye_y),
			ArcReactorDark.ARC_CORE, 2.0
		)
		canvas.draw_line(
			Vector2(center.x + eye_spread - eye_size, eye_y),
			Vector2(center.x + eye_spread + eye_size, eye_y),
			ArcReactorDark.ARC_CORE, 2.0
		)
	else:
		# Open eyes
		var eye_color = ArcReactorDark.ARC_CORE
		if _current_expression == FaceExpression.WORRIED:
			eye_color = ArcReactorDark.STATUS_WARNING
		elif _current_expression == FaceExpression.CURIOUS:
			eye_size *= 1.3  # Wider eyes for curious
		canvas.draw_circle(Vector2(center.x - eye_spread, eye_y), eye_size, eye_color)
		canvas.draw_circle(Vector2(center.x + eye_spread, eye_y), eye_size, eye_color)

	# Mouth
	var mouth_y = center.y + radius * 0.25
	var mouth_width = radius * 0.4
	match _current_expression:
		FaceExpression.HAPPY:
			# Smile arc
			canvas.draw_arc(
				Vector2(center.x, mouth_y - radius * 0.1),
				mouth_width, 0.2, PI - 0.2, 16,
				ArcReactorDark.STATUS_SUCCESS, 2.0
			)
		FaceExpression.WORRIED:
			# Frown arc
			canvas.draw_arc(
				Vector2(center.x, mouth_y + radius * 0.15),
				mouth_width, PI + 0.3, TAU - 0.3, 16,
				ArcReactorDark.STATUS_WARNING, 2.0
			)
		FaceExpression.CURIOUS:
			# Small O
			canvas.draw_arc(
				Vector2(center.x, mouth_y),
				mouth_width * 0.4, 0, TAU, 16,
				ArcReactorDark.ARC_CORE, 2.0
			)
		FaceExpression.SLEEPING:
			# Flat line with Zs
			canvas.draw_line(
				Vector2(center.x - mouth_width * 0.5, mouth_y),
				Vector2(center.x + mouth_width * 0.5, mouth_y),
				ArcReactorDark.TEXT_TERTIARY, 2.0
			)
		_:  # NEUTRAL
			# Slight smile
			canvas.draw_arc(
				Vector2(center.x, mouth_y - radius * 0.05),
				mouth_width * 0.7, 0.3, PI - 0.3, 12,
				ArcReactorDark.ARC_CORE, 2.0
			)
