extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"


func _ready():
	total_steps = 15
	for section in [$Device, $Network, $Platform]:
		if section:
			section.visible = false
			for child in section.get_children():
				child.visible = false


func _animate_step(step: int) -> void:
	match step:
		1: _fade_in($Device); $Device.get_child(0).visible = true
		2: _fade_in($Network); $Network.get_child(0).visible = true
		3: _fade_in($Platform); $Platform.get_child(0).visible = true
		4, 5, 6, 7:
			var idx = step - 3
			if idx < $Device.get_child_count():
				_fade_in($Device.get_child(idx), 0.2)
		8, 9, 10, 11:
			var idx = step - 7
			if idx < $Network.get_child_count():
				_fade_in($Network.get_child(idx), 0.2)
		12, 13, 14, 15:
			var idx = step - 11
			if idx < $Platform.get_child_count():
				_fade_in($Platform.get_child(idx), 0.2)
