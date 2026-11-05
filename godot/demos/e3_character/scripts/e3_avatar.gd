## E3 Digital Avatar — an OCP peer that lives in a Godot 3D scene.
##
## This CharacterBody3D is a first-class OCP peer. It publishes status,
## responds to OCP commands, and can be inhabited by a remote operator.
## Its virtual sensors (position, heading, collision) map to OCP schemas.
extends CharacterBody3D

@onready var ocp_peer: OCPPeer = $OCPPeer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var label_3d: Label3D = $Label3D

@export var move_speed: float = 3.0
@export var rotation_speed: float = 5.0

var _target_position: Vector3 = Vector3.ZERO
var _is_navigating: bool = false
var _sensor_publish_timer: float = 0.0
const SENSOR_PUBLISH_INTERVAL := 2.0  # Publish virtual sensors every 2s


func _ready() -> void:
	_target_position = global_position
	# Connect OCP command signal
	if ocp_peer:
		ocp_peer.command_received.connect(_on_ocp_command)
		ocp_peer.inhabit_requested.connect(_on_inhabit)
		ocp_peer.release_requested.connect(_on_release)
	# Update label
	if label_3d:
		label_3d.text = "E3 Avatar"


func _physics_process(delta: float) -> void:
	if _is_navigating and nav_agent:
		var next_pos := nav_agent.get_next_path_position()
		var direction := (next_pos - global_position).normalized()
		direction.y = 0  # Stay on ground plane

		if direction.length() > 0.01:
			# Rotate toward movement direction
			var target_angle := atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
			# Move
			velocity = direction * move_speed
			move_and_slide()

		# Check if arrived
		if nav_agent.is_navigation_finished():
			_is_navigating = false
			velocity = Vector3.ZERO
			_publish_arrival()

	# Publish virtual sensor data periodically
	_sensor_publish_timer += delta
	if _sensor_publish_timer >= SENSOR_PUBLISH_INTERVAL:
		_publish_virtual_sensors()
		_sensor_publish_timer = 0.0


# --- OCP Command Handling ---

func _on_ocp_command(action: String, parameters: Dictionary) -> void:
	match action:
		"navigate":
			var target: String = str(parameters.get("target", ""))
			var pos := _resolve_named_position(target)
			if pos != Vector3.ZERO:
				_navigate_to(pos)
		"stop":
			_is_navigating = false
			velocity = Vector3.ZERO
		"set_position":
			var x: float = parameters.get("x", global_position.x)
			var z: float = parameters.get("z", global_position.z)
			global_position = Vector3(x, global_position.y, z)
		"move_forward":
			var dir := -transform.basis.z.normalized()
			_move_step(dir, parameters.get("distance", 1.0))
		"move_back":
			var dir := transform.basis.z.normalized()
			_move_step(dir, parameters.get("distance", 1.0))
		"move_left":
			var dir := -transform.basis.x.normalized()
			_move_step(dir, parameters.get("distance", 1.0))
		"move_right":
			var dir := transform.basis.x.normalized()
			_move_step(dir, parameters.get("distance", 1.0))
		"turn_left":
			var tween := create_tween()
			tween.tween_property(self, "rotation:y", rotation.y + deg_to_rad(45), 0.3)
		"turn_right":
			var tween := create_tween()
			tween.tween_property(self, "rotation:y", rotation.y - deg_to_rad(45), 0.3)
		"jump":
			_play_jump()
		_:
			push_warning("E3Avatar: Unknown OCP command '%s'" % action)


func _move_step(direction: Vector3, distance: float) -> void:
	direction.y = 0
	var target := global_position + direction * distance
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _play_jump() -> void:
	var original_y := global_position.y
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", original_y + 0.3, 0.2)
	tween.tween_property(self, "global_position:y", original_y, 0.2)
	tween.tween_property(self, "global_position:y", original_y + 0.2, 0.15)
	tween.tween_property(self, "global_position:y", original_y, 0.15)


func _on_inhabit(operator_session: String, mode: String) -> void:
	if label_3d:
		label_3d.text = "E3 Avatar\n[%s]" % operator_session.left(8)
	print("[E3Avatar] Inhabited by session: %s (mode: %s)" % [operator_session, mode])


func _on_release() -> void:
	if label_3d:
		label_3d.text = "E3 Avatar"
	print("[E3Avatar] Released")


# --- Navigation ---

func _navigate_to(target: Vector3) -> void:
	if nav_agent:
		nav_agent.target_position = target
		_is_navigating = true


## Resolve a named location (e.g., "kitchen", "living_room") to a Vector3.
## Override or extend this for your scene's specific room layout.
func _resolve_named_position(name: String) -> Vector3:
	# Default room positions — adjust per scene geometry
	match name.to_lower():
		"kitchen": return Vector3(-3.0, 0.0, -2.0)
		"living_room", "livingroom": return Vector3(3.0, 0.0, 2.0)
		"door": return Vector3(0.0, 0.0, 0.0)
		"table": return Vector3(-2.0, 0.0, -1.0)
		"center": return Vector3(0.0, 0.0, 0.0)
		_:
			push_warning("E3Avatar: Unknown location '%s'" % name)
			return Vector3.ZERO


# --- Virtual Sensor Publishing ---

func _publish_virtual_sensors() -> void:
	if ocp_peer == null or ocp_peer._mqtt == null:
		return
	# Position as GPS-equivalent
	var pos_msg := {
		"device": ocp_peer.peer_id,
		"msg_type": "sensor",
		"sensor_type": "position",
		"x": global_position.x,
		"y": global_position.y,
		"z": global_position.z,
		"heading": rad_to_deg(rotation.y),
		"is_navigating": _is_navigating,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	ocp_peer._mqtt.publish(
		"oasis/%s/sensors/position" % ocp_peer.component_name,
		JSON.stringify(pos_msg)
	)


func _publish_arrival() -> void:
	if ocp_peer == null or ocp_peer._mqtt == null:
		return
	var event := {
		"device": ocp_peer.peer_id,
		"msg_type": "event",
		"event": "navigation_complete",
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	ocp_peer._mqtt.publish(
		"oasis/%s" % ocp_peer.peer_id,
		JSON.stringify(event)
	)
