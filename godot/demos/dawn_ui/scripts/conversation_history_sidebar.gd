## D.A.W.N. conversation history sidebar (Phase 4).
##
## Lists past chat sessions with file-backed JSON persistence
## (user://dawn_conversations.json). The active session is the one
## new messages append to. Clicking a past session in the list
## switches active and replays its messages into the DawnUI
## transcript via the conversation_switched signal.
##
## Inherits the floating-panel chrome (CanvasLayer + draggable +
## collapsible drag bar + close) from FloatingPanel; only the body
## (session list + new-conversation button) and the persistence
## logic live here.
extends "res://demos/dawn_ui/scripts/floating_panel.gd"

const SAVE_PATH: String = "user://dawn_conversations.json"

signal conversation_switched(messages: Array)

# ─── Persistent state ─────────────────────────────────────────────────────
var _conversations: Array = []  # [{id, title, started_at, messages: [...]}, ...]
var _active_id: String = ""

# ─── Body UI nodes ────────────────────────────────────────────────────────
var _session_list: VBoxContainer = null
var _new_button: Button = null


func _init() -> void:
	dialog_title = "Conversations"
	dialog_size = Vector2(360, 480)
	default_position = DefaultPosition.TOP_LEFT


func _ready() -> void:
	super._ready()
	_load_state()
	if _conversations.is_empty() or _active_id.is_empty():
		_create_new_conversation()
	_render_session_list()


# ─── Body construction (override) ─────────────────────────────────────────

func _build_body(parent: MarginContainer) -> void:
	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	parent.add_child(body_vbox)

	_new_button = Button.new()
	_new_button.text = "+ New conversation"
	_new_button.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		_new_button.add_theme_font_override("font", _font_sans)
	_new_button.pressed.connect(_on_new_pressed)
	body_vbox.add_child(_new_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_vbox.add_child(scroll)

	_session_list = VBoxContainer.new()
	_session_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_session_list.add_theme_constant_override("separation", ArcReactor.SPACE_XS)
	scroll.add_child(_session_list)


# ─── Public API ───────────────────────────────────────────────────────────

func append_user_message(text: String) -> void:
	_append_message("user", text)


func append_assistant_message(text: String) -> void:
	_append_message("assistant", text)


# ─── Persistence ──────────────────────────────────────────────────────────

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary):
		return
	_conversations = data.get("conversations", [])
	_active_id = str(data.get("active_id", ""))


func _save_state() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"conversations": _conversations,
		"active_id": _active_id,
	}, "  "))
	f.close()


# ─── Conversation operations ──────────────────────────────────────────────

func _create_new_conversation() -> void:
	var ts: int = OCPMessage.now_ms()
	var conv := {
		"id": "conv-%d" % ts,
		"title": "New conversation",
		"started_at": ts,
		"messages": [],
	}
	_conversations.push_front(conv)
	_active_id = conv["id"]
	_save_state()


func _append_message(role: String, text: String) -> void:
	var conv = _find_active()
	if conv == null:
		_create_new_conversation()
		conv = _find_active()
	conv["messages"].append({
		"role": role,
		"text": text,
		"timestamp": OCPMessage.now_ms(),
	})
	# First user message becomes the conversation title (truncated).
	if role == "user" and conv["title"] == "New conversation":
		conv["title"] = text.left(48)
	_save_state()
	_render_session_list()


func _find_active() -> Variant:
	for conv in _conversations:
		if conv["id"] == _active_id:
			return conv
	return null


# ─── Session list rendering ───────────────────────────────────────────────

func _render_session_list() -> void:
	if _session_list == null:
		return
	for child in _session_list.get_children():
		child.queue_free()
	for conv in _conversations:
		_session_list.add_child(_make_session_row(conv))


func _make_session_row(conv: Dictionary) -> Control:
	var btn := Button.new()
	btn.text = "%s\n%s" % [
		conv.get("title", "Untitled"),
		_format_timestamp(int(conv.get("started_at", 0))),
	]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.toggle_mode = true
	btn.button_pressed = (conv["id"] == _active_id)
	btn.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		btn.add_theme_font_override("font", _font_sans)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_on_session_pressed.bind(conv["id"]))
	return btn


func _format_timestamp(ms: int) -> String:
	if ms <= 0:
		return ""
	var t := Time.get_datetime_dict_from_unix_time(ms / 1000)
	return "%04d-%02d-%02d %02d:%02d" % [
		t["year"], t["month"], t["day"], t["hour"], t["minute"]]


# ─── Event handlers ───────────────────────────────────────────────────────

func _on_new_pressed() -> void:
	_create_new_conversation()
	_render_session_list()
	conversation_switched.emit([])


func _on_session_pressed(id: String) -> void:
	_active_id = id
	_save_state()
	_render_session_list()
	var conv = _find_active()
	if conv:
		conversation_switched.emit(conv["messages"])
