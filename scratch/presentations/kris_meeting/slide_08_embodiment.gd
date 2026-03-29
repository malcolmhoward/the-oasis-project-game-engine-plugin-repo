extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"


func _ready():
	total_steps = 7
	$Spectrum.visible = false
	for i in range(5):
		get_node("Types/Type%d" % (i + 1)).visible = false
	$Badges.visible = false


func _animate_step(step: int) -> void:
	match step:
		1: _fade_in($Spectrum, 0.5)
		2: _slide_in_left(get_node("Types/Type1"))
		3: _slide_in_left(get_node("Types/Type2"))
		4: _slide_in_left(get_node("Types/Type3"))
		5: _slide_in_left(get_node("Types/Type4"))
		6: _slide_in_left(get_node("Types/Type5"))
		7: _fade_in($Badges)
