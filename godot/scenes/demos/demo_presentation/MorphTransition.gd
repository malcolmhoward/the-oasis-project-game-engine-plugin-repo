## Generic panel-to-scene morph transition engine.
##
## Tweens an array of Control panels from their current positions to
## target positions defined by a destination scene. The destination
## scene is instanced and the panels are repositioned to match its layout.
##
## Usage:
##   var morph = MorphTransition.new()
##   add_child(morph)
##   morph.morph(source_panels, target_scene, 0.8, container)
##
## Source panels should be in the "morph_panel" group with metadata:
##   panel.set_meta("morph_target", "target_node_name")
class_name MorphTransition
extends Node

signal morph_completed()


func morph(from_panels: Array[Control], to_scene: PackedScene,
		   duration: float, container: Control) -> void:
	if from_panels.is_empty() or to_scene == null:
		morph_completed.emit()
		queue_free()
		return

	# Instance the target scene (hidden initially)
	var target = to_scene.instantiate()
	target.modulate.a = 0.0
	container.add_child(target)

	# Record source positions
	var source_rects: Array[Rect2] = []
	for panel in from_panels:
		source_rects.append(Rect2(panel.global_position, panel.size))

	# Calculate target positions from the target scene's layout
	var target_rects: Array[Rect2] = []
	for panel in from_panels:
		var target_name = panel.get_meta("morph_target", "")
		var target_node = target.find_child(target_name, true, false) if not target_name.is_empty() else null
		if target_node and target_node is Control:
			# Wait for layout to resolve
			await get_tree().process_frame
			target_rects.append(Rect2(target_node.global_position, target_node.size))
		else:
			# No target — tween to center
			target_rects.append(Rect2(container.global_position, container.size))

	# Tween panels from source to target positions
	var tween = create_tween()
	tween.set_parallel(true)

	for i in range(from_panels.size()):
		if i < target_rects.size():
			var panel = from_panels[i]
			var target_rect = target_rects[i]
			tween.tween_property(panel, "global_position", target_rect.position, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(panel, "size", target_rect.size, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	# Fade in the target scene as panels arrive
	tween.chain().tween_property(target, "modulate:a", 1.0, duration * 0.3)

	# Clean up source panels after morph
	tween.chain().tween_callback(func():
		for panel in from_panels:
			panel.queue_free()
		morph_completed.emit()
		queue_free()
	)
