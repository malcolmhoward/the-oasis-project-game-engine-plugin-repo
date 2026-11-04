## Editor plugin: docks the D.A.W.N. chat UI (demos/dawn_ui) in the Godot editor, wired to a local
## llama-server through llama_server_backend.gd.
##
## Settings live in Editor Settings (per user, never committed to the project):
##   dawn_chat/server_url     default http://127.0.0.1:8080
##   dawn_chat/api_key        sent as a Bearer token when llama-server runs with --api-key
##   dawn_chat/system_prompt
@tool
extends EditorPlugin

const DawnUIScene = preload("res://demos/dawn_ui/scenes/dawn_ui.tscn")
const Backend = preload("res://addons/dawn_chat/llama_server_backend.gd")

const SETTINGS := {
	"dawn_chat/server_url": "http://127.0.0.1:8080",
	"dawn_chat/api_key": "",
	"dawn_chat/system_prompt": "You are D.A.W.N., an assistant inside the Godot 4.7 editor. Help with GDScript, scenes, nodes, shaders and game design. Answer concisely; prefer Godot 4 APIs and typed GDScript.",
}

var _dock: EditorDock = null
var _ui: Control = null
var _backend: Node = null


func _enter_tree() -> void:
	_register_settings()

	_backend = Backend.new()
	_backend.name = "LlamaServerBackend"
	_apply_settings()

	_ui = DawnUIScene.instantiate()
	_ui.editor_mode = true
	_ui.backend = _backend
	_ui.add_child(_backend)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dock = EditorDock.new()
	_dock.title = "D.A.W.N."
	_dock.layout_key = "dawn_chat"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	_dock.custom_minimum_size = Vector2(280, 320)
	_dock.add_child(_ui)
	add_dock(_dock)

	EditorInterface.get_editor_settings().settings_changed.connect(_apply_settings)


func _exit_tree() -> void:
	var es := EditorInterface.get_editor_settings()
	if es.settings_changed.is_connected(_apply_settings):
		es.settings_changed.disconnect(_apply_settings)
	if _dock:
		remove_dock(_dock)
		_dock.queue_free()
	_dock = null
	_ui = null
	_backend = null


func _register_settings() -> void:
	var es := EditorInterface.get_editor_settings()
	for key in SETTINGS:
		if not es.has_setting(key):
			es.set_setting(key, SETTINGS[key])
		es.set_initial_value(key, SETTINGS[key], false)
	es.add_property_info({"name": "dawn_chat/system_prompt", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_MULTILINE_TEXT})
	es.add_property_info({"name": "dawn_chat/api_key", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_PASSWORD})


func _apply_settings() -> void:
	if _backend == null:
		return
	var es := EditorInterface.get_editor_settings()
	_backend.configure(str(es.get_setting("dawn_chat/server_url")),
		str(es.get_setting("dawn_chat/api_key")),
		str(es.get_setting("dawn_chat/system_prompt")))
