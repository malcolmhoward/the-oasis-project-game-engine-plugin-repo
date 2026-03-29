extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"


func _ready():
	total_steps = 4
	$HardwareIcons.visible = false
	$RedOverlay.visible = false
	$SoftwareIcon.visible = false
	$Tagline.visible = false


func _animate_step(step: int) -> void:
	match step:
		1: _fade_in($HardwareIcons)
		2: _fade_in($RedOverlay)
		3: _fade_in($SoftwareIcon)
		4: _slide_up($Tagline)
