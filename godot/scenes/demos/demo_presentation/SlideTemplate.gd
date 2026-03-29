## Base class for all presentation slides.
##
## Each slide scene extends this and overrides _animate_step() to define
## its step-based animation sequence. The presentation controller calls
## advance_step() on Right Arrow / Space press.
##
## Usage:
##   extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"
##
##   func _ready():
##       total_steps = 4
##
##   func _animate_step(step: int) -> void:
##       match step:
##           1: _fade_in($Title)
##           2: _slide_up($Subtitle)
##           3: _fade_in($Content)
##           4: _fade_in($Footer)
extends Control

var current_step: int = 0
var total_steps: int = 1

## Title text — set by the slide scene or by the controller from manifest
@export var slide_title: String = ""

## Speaking cue — shown in bottom-left corner for the presenter
@export var speaking_cue: String = ""


## Called by the presentation controller. Returns true if more steps remain.
func advance_step() -> bool:
	current_step += 1
	if current_step <= total_steps:
		_animate_step(current_step)
	return current_step < total_steps


## Called by the presentation controller to go back one step.
func retreat_step() -> void:
	if current_step > 0:
		current_step -= 1
		# Reset and replay up to current step
		_reset_animations()
		for i in range(1, current_step + 1):
			_animate_step_instant(i)


## Override in each slide to define step animations.
func _animate_step(step: int) -> void:
	pass


## Override to instantly show a step (no animation) for retreat/replay.
func _animate_step_instant(step: int) -> void:
	_animate_step(step)


## Override to reset all animations to initial state.
func _reset_animations() -> void:
	pass


# --- Utility animation helpers ---

func _fade_in(node: Control, duration: float = 0.3, delay: float = 0.0) -> Tween:
	node.modulate.a = 0.0
	node.visible = true
	var tween = create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", 1.0, duration)
	return tween


func _slide_up(node: Control, duration: float = 0.3, distance: float = 30.0, delay: float = 0.0) -> Tween:
	node.modulate.a = 0.0
	node.position.y += distance
	node.visible = true
	var tween = create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, duration)
	tween.tween_property(node, "position:y", node.position.y - distance, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tween


func _slide_in_left(node: Control, duration: float = 0.3, distance: float = 50.0, delay: float = 0.0) -> Tween:
	node.modulate.a = 0.0
	node.position.x -= distance
	node.visible = true
	var tween = create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, duration)
	tween.tween_property(node, "position:x", node.position.x + distance, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tween


func _draw_line_animated(canvas: Control, from: Vector2, to: Vector2, color: Color, duration: float = 0.3) -> void:
	# For animated connecting lines — override _draw in the canvas
	pass
