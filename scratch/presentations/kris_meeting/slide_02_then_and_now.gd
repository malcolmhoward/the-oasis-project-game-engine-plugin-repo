extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

@onready var left_items = [$Content/Left/Item1, $Content/Left/Item2, $Content/Left/Item3, $Content/Left/Item4]
@onready var right_items = [$Content/Right/Item1, $Content/Right/Item2, $Content/Right/Item3, $Content/Right/Item4]
@onready var lines = [$Content/Lines/Line1, $Content/Lines/Line2, $Content/Lines/Line3, $Content/Lines/Line4]


func _ready():
	total_steps = 8
	for item in left_items + right_items + lines:
		if item:
			item.visible = false


func _animate_step(step: int) -> void:
	match step:
		1: _slide_in_left(left_items[0])
		2: _slide_in_left(left_items[1])
		3: _slide_in_left(left_items[2])
		4: _slide_in_left(left_items[3])
		5:
			_fade_in(right_items[0])
			if lines[0]: _fade_in(lines[0])
		6:
			_fade_in(right_items[1])
			if lines[1]: _fade_in(lines[1])
		7:
			_fade_in(right_items[2])
			if lines[2]: _fade_in(lines[2])
		8:
			_fade_in(right_items[3])
			if lines[3]: _fade_in(lines[3])
