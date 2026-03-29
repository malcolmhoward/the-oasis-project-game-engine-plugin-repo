extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"


func _ready():
	total_steps = 6
	for child in get_children():
		if child is Control and child != $Heading:
			child.visible = false


func _animate_step(step: int) -> void:
	var content_children = []
	for child in get_children():
		if child is Control and child != $Heading:
			content_children.append(child)
	if step > 0 and step <= content_children.size():
		_fade_in(content_children[step - 1], 0.3)
