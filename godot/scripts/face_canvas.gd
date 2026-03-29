## Canvas that delegates _draw() to the parent HUD face controller.
extends Control


func _draw():
	var parent = get_parent()
	if parent and parent.has_method("_draw_face"):
		parent._draw_face(self)
