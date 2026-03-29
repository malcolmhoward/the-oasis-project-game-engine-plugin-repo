extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

## This slide IS the live demo. The morph transition from Slide 4
## handles the visual transition. This script just reports that
## there are no steps — advance moves to the next slide.


func _ready():
	total_steps = 0  # No steps — demo runs until presenter advances
