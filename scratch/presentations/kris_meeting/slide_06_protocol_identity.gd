extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"


func _ready():
	total_steps = 4
	$LeftMessage.visible = false
	$RightMessage.visible = false
	$Highlight.visible = false
	$Tagline.visible = false


func _animate_step(step: int) -> void:
	match step:
		1: _fade_in($LeftMessage)
		2: _fade_in($RightMessage)
		3: _fade_in($Highlight, 0.5)
		4: _slide_up($Tagline)
