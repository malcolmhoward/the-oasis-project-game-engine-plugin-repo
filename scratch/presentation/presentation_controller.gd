## Presentation controller — manages slides, transitions, and live demo embedding.
##
## Keyboard controls:
##   Right / Space  — next step or slide
##   Left           — previous step
##   Tab            — toggle annotation overlays
##   F              — fullscreen toggle
##   Escape         — slide list (emergency nav)
##   D              — debug panel (MQTT traffic)
##
## Slide 7 transitions to the live demo scenes inline (no window switching).
## The companion face persists across all slides via the autoload singleton.
extends Control

const TRANSITION_DURATION := 0.3   # Cross-dissolve between slides
const MORPH_DURATION := 0.8        # Demo morph (slide 4 → live demo)

var _slides: Array[PackedScene] = []
var _current_slide_index: int = 0
var _current_slide_node: Control = null
var _is_demo_active: bool = false
var _annotations_visible: bool = false

@onready var slide_container: Control = $SlideContainer
@onready var slide_number_label: Label = $SlideNumber
@onready var debug_panel: Control = $DebugPanel


func _ready():
	# Load slide scenes in order
	_slides = _discover_slides()
	if _slides.size() > 0:
		_show_slide(0, false)
	_update_slide_number()


func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT, KEY_SPACE:
				_next()
			KEY_LEFT:
				_previous()
			KEY_TAB:
				_toggle_annotations()
			KEY_F:
				_toggle_fullscreen()
			KEY_ESCAPE:
				_show_slide_list()
			KEY_D:
				_toggle_debug()


func _next():
	if _current_slide_index < _slides.size() - 1:
		_show_slide(_current_slide_index + 1, true)


func _previous():
	if _current_slide_index > 0:
		_show_slide(_current_slide_index - 1, true)


func _show_slide(index: int, animate: bool):
	if index < 0 or index >= _slides.size():
		return

	var new_scene = _slides[index].instantiate()

	if animate and _current_slide_node:
		# Cross-dissolve transition
		var old = _current_slide_node
		slide_container.add_child(new_scene)
		new_scene.modulate.a = 0.0

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(old, "modulate:a", 0.0, TRANSITION_DURATION)
		tween.tween_property(new_scene, "modulate:a", 1.0, TRANSITION_DURATION)
		tween.chain().tween_callback(func(): old.queue_free())
	else:
		if _current_slide_node:
			_current_slide_node.queue_free()
		slide_container.add_child(new_scene)

	_current_slide_node = new_scene
	_current_slide_index = index
	_update_slide_number()


func _toggle_annotations():
	_annotations_visible = not _annotations_visible
	# Toggle annotation layers in current slide if they exist
	if _current_slide_node and _current_slide_node.has_node("Annotations"):
		_current_slide_node.get_node("Annotations").visible = _annotations_visible


func _toggle_fullscreen():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _toggle_debug():
	if debug_panel:
		debug_panel.visible = not debug_panel.visible


func _show_slide_list():
	# Emergency navigation — show numbered list of all slides
	pass  # TODO: overlay with clickable slide titles


func _update_slide_number():
	if slide_number_label:
		slide_number_label.text = "%d / %d" % [_current_slide_index + 1, _slides.size()]


func _discover_slides() -> Array[PackedScene]:
	var slides: Array[PackedScene] = []
	var dir = DirAccess.open("res://scratch/presentation/slides/")
	if dir == null:
		# Fallback: try committed location
		dir = DirAccess.open("res://scenes/presentation/")
	if dir == null:
		push_warning("No slide directory found")
		return slides

	dir.list_dir_begin()
	var files: Array[String] = []
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn") and file_name.begins_with("slide_"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	files.sort()  # Alphabetical = numerical order (slide_01, slide_02, ...)
	for f in files:
		var scene = load(dir.get_current_dir() + "/" + f)
		if scene:
			slides.append(scene)

	return slides
