extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"


func _ready():
	total_steps = 3


func _animate_step(step: int) -> void:
	match step:
		1: _fade_in($Title, 0.5)
		2: _slide_up($Subtitle, 0.3, 20.0)
		3: _fade_in($Author, 0.3, 0.1)
