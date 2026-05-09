## D.A.W.N. conversation history sidebar (Phase 4).
##
## Toggleable, draggable, collapsible CanvasLayer panel listing past
## chat sessions. Each session is a list of {role, text, timestamp}
## entries; sessions persist across launches via a single JSON file
## under user://. The active session is the one new messages append
## to. Clicking a past session in the list switches the active
## session and replays its messages into the DawnUI transcript via
## the conversation_switched signal.
##
## Same shape as memory_inspector.gd:
##   - CanvasLayer root → escapes parent clip region, no SubViewport blur
##   - Drag bar at top with collapse/close
##   - Body holds a scrollable session list + "+ New conversation" button
##   - Public toggle() / append_user_message() / append_assistant_message()
extends CanvasLayer

const ArcReactor = preload("res://resources/design_tokens.gd")

const SAVE_PATH: String = "user://dawn_conversations.json"
const _DEFAULT_DIALOG_SIZE := Vector2(360, 480)

signal conversation_switched(messages: Array)

# ─── Persistent state ─────────────────────────────────────────────────────
var _conversations: Array = []  # [{id, title, started_at, messages: [{role, text, timestamp}]}, ...]
var _active_id: String = ""

# ─── UI nodes ─────────────────────────────────────────────────────────────
var _root_control: Control = null
var _dialog_panel: PanelContainer = null
var _drag_handle: Label = null
var _collapse_button: Button = null
var _body_container: Control = null
var _session_list: VBoxContainer = null
var _new_button: Button = null

# ─── Drag/collapse state ──────────────────────────────────────────────────
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _collapsed: bool = false
var _has_been_dragged: bool = false

# ─── Fonts ────────────────────────────────────────────────────────────────
var _font_sans: Font = null
var _font_sans_bold: Font = null


func _ready() -> void:
	visible = false
	layer = 64
	_load_project_fonts()
	_build_ui()
	_load_state()
	if _conversations.is_empty() or _active_id.is_empty():
		_create_new_conversation()
	_render_session_list()


func _load_project_fonts() -> void:
	if ResourceLoader.exists(ArcReactor.FONT_SANS_PATH):
		_font_sans = load(ArcReactor.FONT_SANS_PATH)
	if ResourceLoader.exists(ArcReactor.FONT_SANS_BOLD):
		_font_sans_bold = load(ArcReactor.FONT_SANS_BOLD)


# ─── UI construction ──────────────────────────────────────────────────────

func _build_ui() -> void:
	# Dialog sits directly under the CanvasLayer — no full-rect parent
	# Control intercepting clicks. Mouse events outside the dialog's
	# bounds miss this CanvasLayer entirely and propagate down to the
	# main scene's controls (so the DawnUI input field can receive
	# focus while this sidebar is open).
	_dialog_panel = PanelContainer.new()
	# Anchor to top-left so the sidebar sits where a real sidebar would;
	# user can drag it anywhere from there.
	_dialog_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_dialog_panel.position = Vector2(20, 20)
	_dialog_panel.custom_minimum_size = _DEFAULT_DIALOG_SIZE
	_dialog_panel.size = _DEFAULT_DIALOG_SIZE
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = ArcReactor.BG_DEEPEST
	style.border_color = ArcReactor.ARC_BORDER
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(ArcReactor.RADIUS_MD)
	_dialog_panel.add_theme_stylebox_override("panel", style)
	add_child(_dialog_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	_dialog_panel.add_child(root_vbox)

	# ─── Drag bar ────────────────────────────────────────────────────
	var drag_bar := PanelContainer.new()
	var drag_style := StyleBoxFlat.new()
	drag_style.bg_color = ArcReactor.BG_DARK
	drag_style.corner_radius_top_left = ArcReactor.RADIUS_MD
	drag_style.corner_radius_top_right = ArcReactor.RADIUS_MD
	drag_style.content_margin_left = ArcReactor.SPACE_MD
	drag_style.content_margin_right = ArcReactor.SPACE_MD
	drag_style.content_margin_top = ArcReactor.SPACE_XS
	drag_style.content_margin_bottom = ArcReactor.SPACE_XS
	drag_bar.add_theme_stylebox_override("panel", drag_style)
	root_vbox.add_child(drag_bar)

	var drag_row := HBoxContainer.new()
	drag_row.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	drag_bar.add_child(drag_row)

	_drag_handle = Label.new()
	_drag_handle.text = "≡ Conversations"
	_drag_handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drag_handle.add_theme_color_override("font_color", ArcReactor.ARC_CORE)
	_drag_handle.add_theme_font_size_override("font_size", ArcReactor.FONT_SUBHEAD)
	_drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_handle.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_drag_handle.gui_input.connect(_on_drag_input)
	if _font_sans:
		_drag_handle.add_theme_font_override("font", _font_sans)
	drag_row.add_child(_drag_handle)

	_collapse_button = Button.new()
	_collapse_button.text = "▼"
	_collapse_button.flat = true
	_collapse_button.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	_collapse_button.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	_collapse_button.add_theme_color_override("font_hover_color", ArcReactor.TEXT_PRIMARY)
	_collapse_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_collapse_button.pressed.connect(_on_collapse)
	drag_row.add_child(_collapse_button)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.flat = true
	close_button.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	close_button.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	close_button.add_theme_color_override("font_hover_color", ArcReactor.STATUS_ERROR)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(_on_close)
	drag_row.add_child(close_button)

	# ─── Body container (collapsible) ────────────────────────────────
	_body_container = MarginContainer.new()
	_body_container.add_theme_constant_override("margin_left", ArcReactor.SPACE_MD)
	_body_container.add_theme_constant_override("margin_right", ArcReactor.SPACE_MD)
	_body_container.add_theme_constant_override("margin_top", ArcReactor.SPACE_SM)
	_body_container.add_theme_constant_override("margin_bottom", ArcReactor.SPACE_SM)
	_body_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_body_container)

	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	_body_container.add_child(body_vbox)

	# "+ New conversation" button
	_new_button = Button.new()
	_new_button.text = "+ New conversation"
	_new_button.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		_new_button.add_theme_font_override("font", _font_sans)
	_new_button.pressed.connect(_on_new_pressed)
	body_vbox.add_child(_new_button)

	# Scrollable session list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_vbox.add_child(scroll)

	_session_list = VBoxContainer.new()
	_session_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_session_list.add_theme_constant_override("separation", ArcReactor.SPACE_XS)
	scroll.add_child(_session_list)


# ─── Public API ───────────────────────────────────────────────────────────

func toggle() -> void:
	visible = not visible


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


func _on_close() -> void:
	visible = false


func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = _dialog_panel.get_global_mouse_position() - _dialog_panel.global_position
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_dialog_panel.global_position = _dialog_panel.get_global_mouse_position() - _drag_offset


func _on_collapse() -> void:
	_collapsed = not _collapsed
	if _body_container:
		_body_container.visible = not _collapsed
	if _collapse_button:
		_collapse_button.text = "▶" if _collapsed else "▼"
	if _collapsed:
		_dialog_panel.custom_minimum_size = Vector2.ZERO
	else:
		_dialog_panel.custom_minimum_size = _DEFAULT_DIALOG_SIZE
	_dialog_panel.size = Vector2.ZERO
	_dialog_panel.reset_size()
