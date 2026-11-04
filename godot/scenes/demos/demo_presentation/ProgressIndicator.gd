## Progress indicator — dots at bottom center showing current slide position.
##
## Current slide dot is ARC_BRIGHT. Others are TEXT_MUTED at 30% opacity.
## Auto-resizes based on slide count.
extends HBoxContainer

var _dots: Array[Control] = []
var _current: int = 0
const DOT_SIZE := 8
const DOT_SPACING := 6


func set_progress(current: int, total: int) -> void:
	_current = current
	# Rebuild dots if count changed
	if _dots.size() != total:
		_rebuild(total)
	# Update colors
	for i in range(_dots.size()):
		var dot = _dots[i]
		if i == current:
			dot.modulate = ArcReactorDark.ARC_CORE
		else:
			dot.modulate = Color(ArcReactorDark.TEXT_TERTIARY, 0.3)


func _rebuild(total: int) -> void:
	for dot in _dots:
		dot.queue_free()
	_dots.clear()

	for i in range(total):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.color = Color.WHITE
		# Round corners via shader or just use a small square (close enough at 8px)
		add_child(dot)
		_dots.append(dot)

	# Center the container
	add_theme_constant_override("separation", DOT_SPACING)
