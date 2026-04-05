## Presentation controller — loads slides from a JSON manifest,
## manages keyboard navigation, transitions, and speaking cues.
##
## Reads a presentation.json file that declares slides, cues,
## transitions, and optional theme overrides. Slide scenes are
## loaded at runtime and must inherit from SlideTemplate.
##
## Presentations are private by default — manifest and slide content
## live in user:// or scratch/ (gitignored). The engine itself is
## committed and reusable.
extends Control

const TRANSITION_DURATION := 0.3
const MORPH_DURATION := 0.8

var _slides: Array[Dictionary] = []  # [{scene, cue, instance}]
var _appendix: Array[Dictionary] = []
var _transitions: Dictionary = {}
var _current_index: int = 0
var _current_slide: Control = null
var _is_in_appendix: bool = false
var _demo_mode: bool = false  # True when live demo is active — disables slide navigation

@onready var slide_container: Control = $SlideContainer
@onready var progress_indicator: Control = $ProgressIndicator
@onready var speaking_cue: Label = $SpeakingCue
@onready var debug_panel: Control = $DebugPanel

@export var manifest_path: String = ""


func _ready():
	if manifest_path.is_empty():
		# Try default locations
		for path in [
			"user://presentations/default/presentation.json",
			"res://scratch/presentations/default/presentation.json",
		]:
			if FileAccess.file_exists(path):
				manifest_path = path
				break

	if not manifest_path.is_empty():
		_load_manifest(manifest_path)

	if _slides.size() > 0:
		_show_slide(0, false)

	# Hide debug panel by default
	if debug_panel:
		debug_panel.visible = false


func _input(event: InputEvent):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# In demo mode, only Escape exits back to presentation
	if _demo_mode:
		if event.keycode == KEY_ESCAPE:
			_exit_demo_mode()
		# All other keys pass through to the demo (DAWN panel, etc.)
		return

	match event.keycode:
		KEY_RIGHT, KEY_SPACE:
			_advance()
		KEY_LEFT:
			_retreat()
		KEY_TAB:
			_toggle_annotations()
		KEY_F:
			_toggle_fullscreen()
		KEY_ESCAPE:
			_show_slide_list()
		KEY_D:
			_toggle_debug()


func _advance():
	if _current_slide and _current_slide.advance_step():
		return  # More steps in current slide
	# Check for morph transition
	var morph_key = "slide_%02d_to_slide_%02d" % [_current_index + 1, _current_index + 2]
	if _transitions.has(morph_key):
		_execute_morph(_transitions[morph_key])
		return
	# If in demo mode (current_slide is null), clean up demo content first
	if _current_slide == null:
		for child in slide_container.get_children():
			child.queue_free()
	# Advance to next slide
	if _current_index < _slides.size() - 1:
		_show_slide(_current_index + 1, true)


func _retreat():
	if _current_slide and _current_slide.current_step > 0:
		_current_slide.retreat_step()
		return
	if _current_index > 0:
		# If in demo mode, clean up demo first
		if _current_slide == null:
			for child in slide_container.get_children():
				child.queue_free()
		_show_slide(_current_index - 1, true)


func _show_slide(index: int, animate: bool):
	if index < 0 or index >= _slides.size():
		return

	var slide_data = _slides[index]
	var scene = load(slide_data["scene_path"])
	if scene == null:
		push_warning("Failed to load slide: %s" % slide_data["scene_path"])
		return

	var new_slide = scene.instantiate()

	if animate and _current_slide:
		var old = _current_slide
		slide_container.add_child(new_slide)
		new_slide.modulate.a = 0.0

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(old, "modulate:a", 0.0, TRANSITION_DURATION)
		tween.tween_property(new_slide, "modulate:a", 1.0, TRANSITION_DURATION)
		tween.chain().tween_callback(func(): old.queue_free())
	else:
		if _current_slide:
			_current_slide.queue_free()
		slide_container.add_child(new_slide)

	_current_slide = new_slide
	_current_index = index

	# Auto-play step 1 so the slide isn't blank on load
	if _current_slide and _current_slide.has_method("advance_step"):
		_current_slide.advance_step()

	# Update speaking cue
	if speaking_cue:
		speaking_cue.text = slide_data.get("cue", "")

	# Update progress dots
	_update_progress()


func _execute_morph(transition_data: Dictionary):
	# Delegate to MorphTransition engine
	var morph = MorphTransition.new()
	add_child(morph)

	var duration = transition_data.get("duration", MORPH_DURATION)
	var demo_scene_path = transition_data.get("demo_scene", "")

	if demo_scene_path.is_empty() or not ResourceLoader.exists(demo_scene_path):
		push_warning("Morph target scene not found: %s" % demo_scene_path)
		# Fall through to next slide instead of recursing
		if _current_index < _slides.size() - 1:
			_show_slide(_current_index + 1, true)
		return

	var demo_scene = load(demo_scene_path)
	# Find morphable panels in current slide
	var panels: Array[Control] = []
	if _current_slide:
		for child in _current_slide.get_children():
			if child.is_in_group("morph_panel"):
				panels.append(child)

	# Clean up the current slide before morphing — prevents it showing behind demo
	if _current_slide:
		_current_slide.queue_free()
		_current_slide = null

	morph.morph(panels, demo_scene, duration, slide_container)
	_demo_mode = true  # Disable slide navigation, let demo handle input
	_current_index += 1
	_update_progress()

	if speaking_cue:
		speaking_cue.text = "LIVE DEMO — press Escape to return to slides"

	# Hide progress dots and speaking cue during demo
	if progress_indicator:
		progress_indicator.visible = false


func _exit_demo_mode():
	_demo_mode = false
	# Clean up demo scene from slide container
	for child in slide_container.get_children():
		child.queue_free()
	# Restore UI
	if progress_indicator:
		progress_indicator.visible = true
	# Advance to next slide after the demo
	if _current_index < _slides.size() - 1:
		# Small delay to let queue_free process
		await get_tree().process_frame
		_show_slide(_current_index + 1, false)
	elif _current_index > 0:
		await get_tree().process_frame
		_show_slide(_current_index, false)


func _toggle_annotations():
	if _current_slide and _current_slide.has_node("Annotations"):
		var ann = _current_slide.get_node("Annotations")
		ann.visible = not ann.visible


func _toggle_fullscreen():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _toggle_debug():
	if debug_panel:
		debug_panel.visible = not debug_panel.visible


func _show_slide_list():
	pass  # TODO: overlay with clickable slide titles


func _update_progress():
	if progress_indicator and progress_indicator.has_method("set_progress"):
		progress_indicator.set_progress(_current_index, _slides.size())


func _load_manifest(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Cannot open manifest: %s" % path)
		return

	var config = JSON.parse_string(file.get_as_text())
	file.close()

	if config == null or not config is Dictionary:
		push_warning("Invalid manifest JSON: %s" % path)
		return

	var base_dir = path.get_base_dir()

	# Load slides
	for slide_entry in config.get("slides", []):
		var scene_path = slide_entry.get("scene", "")
		if not scene_path.begins_with("res://"):
			scene_path = base_dir + "/" + scene_path
		_slides.append({
			"scene_path": scene_path,
			"cue": slide_entry.get("cue", ""),
		})

	# Load appendix
	for app_entry in config.get("appendix", []):
		var scene_path = app_entry.get("scene", "")
		if not scene_path.begins_with("res://"):
			scene_path = base_dir + "/" + scene_path
		_appendix.append({
			"scene_path": scene_path,
			"cue": app_entry.get("cue", ""),
		})

	# Load transitions
	_transitions = config.get("transitions", {})

	# Apply theme override if specified
	var theme_override = config.get("theme_override", null)
	if theme_override and ResourceLoader.exists(theme_override):
		var custom_theme = load(theme_override)
		if custom_theme:
			get_tree().root.theme = custom_theme

	print("[Presentation] Loaded %d slides, %d appendix from %s" % [
		_slides.size(), _appendix.size(), path
	])
