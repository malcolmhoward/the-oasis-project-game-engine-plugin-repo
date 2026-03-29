extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

func _ready():
	total_steps = 0
	for child in get_children():
		if child is Control and child.name != "Heading":
			child.visible = false

func _animate_step(step: int) -> void:
	var items = []
	for child in get_children():
		if child is Control and child.name != "Heading":
			items.append(child)
	if step > 0 and step <= items.size():
		_fade_in(items[step - 1], 0.3)
