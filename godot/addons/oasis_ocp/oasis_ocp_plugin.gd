@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type(
		"OCPPeer",
		"Node",
		preload("ocp_peer.gd"),
		null  # Icon loaded by editor when available; headless mode has no image importer
	)


func _exit_tree() -> void:
	remove_custom_type("OCPPeer")
