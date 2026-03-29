## Orbital mechanics simulation — live Godot physics demo.
##
## Central mass with 2-4 orbiting bodies. Bodies leave trail lines.
## Used as the morph target for the gravity presentation's Slide 5→6
## transition. Also independently runnable as a demo.
extends Node2D

const G := 500.0  # Gravitational constant (scaled for visual clarity)
const TRAIL_LENGTH := 200

var _bodies: Array[Dictionary] = []  # {node, mass, velocity, trail}
var _central_mass := 1000.0
var _central_pos := Vector2.ZERO


func _ready():
	_central_pos = get_viewport_rect().size / 2.0

	# Add orbiting bodies with different orbital parameters
	_add_body(Vector2(200, 0), Vector2(0, -180), 5.0, Color("2dd4bf"))
	_add_body(Vector2(-140, 100), Vector2(-120, -100), 3.0, Color("f97316"))
	_add_body(Vector2(0, -250), Vector2(150, 0), 4.0, Color("22c55e"))


func _process(delta: float):
	for body in _bodies:
		var node: Node2D = body["node"]
		var pos = node.position
		var vel: Vector2 = body["velocity"]

		# Gravitational force toward center
		var diff = _central_pos - pos
		var dist = diff.length()
		if dist < 20:
			dist = 20  # Prevent singularity
		var force = G * _central_mass * body["mass"] / (dist * dist)
		var accel = diff.normalized() * force / body["mass"]

		# Update velocity and position (Euler integration)
		vel += accel * delta
		node.position += vel * delta
		body["velocity"] = vel

		# Update trail
		var trail: Line2D = body["trail"]
		trail.add_point(node.position)
		while trail.get_point_count() > TRAIL_LENGTH:
			trail.remove_point(0)

	queue_redraw()


func _draw():
	# Draw central mass
	draw_circle(_central_pos, 20, Color("f0b429"))
	draw_arc(_central_pos, 22, 0, TAU, 32, Color("f0b429", 0.3), 2.0)

	# Draw body positions
	for body in _bodies:
		var pos = body["node"].position
		draw_circle(pos, body["mass"] * 1.5, body["color"])


func _add_body(offset: Vector2, velocity: Vector2, mass: float, color: Color):
	var node = Node2D.new()
	node.position = _central_pos + offset
	add_child(node)

	var trail = Line2D.new()
	trail.width = 1.5
	trail.default_color = Color(color, 0.4)
	add_child(trail)

	_bodies.append({
		"node": node,
		"mass": mass,
		"velocity": velocity,
		"trail": trail,
		"color": color,
	})
