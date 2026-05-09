## D.A.W.N. memory inspector (Phase 4).
##
## Toggleable Control overlay that mirrors the web UI's memory popover.
## Five tabs — facts, preferences, summaries, entities, contacts —
## each with a search box and a scrollable item list. Built entirely
## in code (no .tscn) so the inspector ships as a single file.
##
## Implementation note: a CanvasLayer root so the dialog escapes the
## DawnUI panel's clip region while still rendering directly into the
## host viewport (no SubViewport blur). The dialog itself is a non-
## modal floating panel — drag the title bar to move, collapse to a
## title-only strip, close button to dismiss. Same pattern as
## control_panel.gd, adapted for a CanvasLayer host.
##
## Subscribes implicitly via dawn_ui's event router for the demo:
##   dawn/events with event=memory_update overwrites the named
##   category. Schema:
##     { event: "memory_update",
##       category: "facts"|"preferences"|"summaries"|"entities"|"contacts",
##       items: [{id, title, body, timestamp}, ...] }
##
## If no memory_update arrives, each tab displays the static seed data
## defined in MOCK_SEEDS so the inspector reads as populated during
## stakeholder demos.
extends CanvasLayer

const ArcReactor = preload("res://resources/design_tokens.gd")

const CATEGORIES := ["facts", "preferences", "summaries", "entities", "contacts"]

# Static seed so the inspector reads populated even before any
# dawn/events memory_update arrives. Replaces in place when an update
# for a category lands.
const MOCK_SEEDS := {
	"facts": [
		{"title": "User's name is Tony",
		 "body": "Confirmed via voice interaction on 2026-04-15."},
		{"title": "Workshop is in Malibu",
		 "body": "Primary lab/workshop location; address redacted."},
		{"title": "Coffee preference: black, no sugar",
		 "body": "Mentioned consistently across morning sessions."},
		{"title": "Mark II suit operational",
		 "body": "Last full-systems check passed on 2026-05-01."},
	],
	"preferences": [
		{"title": "Notification verbosity",
		 "body": "concise"},
		{"title": "Voice tone",
		 "body": "professional with light wit"},
		{"title": "Tool-call confirmation",
		 "body": "auto for read-only, prompt for actions"},
		{"title": "Default stat units",
		 "body": "metric (°C, kg)"},
	],
	"summaries": [
		{"title": "Morning briefing 2026-05-07",
		 "body": "Reviewed M.I.R.A.G.E. parity audit, queued the WSL2 + USB/IP container plan, and shipped Phase 3 of the Godot D.A.W.N. recreation."},
		{"title": "Conversation with Pepper 2026-05-06",
		 "body": "Reminder to prep for the board review on Thursday; agenda placed in the calendar."},
	],
	"entities": [
		{"title": "Pepper Potts", "body": "CEO, primary contact"},
		{"title": "James Rhodes", "body": "USAF liaison, Mark VI pilot"},
		{"title": "JARVIS", "body": "deprecated assistant; do not invoke"},
		{"title": "Friday", "body": "successor assistant; not currently online"},
	],
	"contacts": [
		{"title": "Pepper Potts", "body": "+1-555-0142 · pepper@stark-industries.example"},
		{"title": "Rhodey", "body": "+1-555-0177 · rhodes@af.example"},
		{"title": "Happy", "body": "+1-555-0192 · happy@stark-industries.example"},
	],
}

# Per-category state: search query + ItemList reference + items array.
var _state: Dictionary = {}
var _root_vbox: VBoxContainer = null
var _tab_container: TabContainer = null
var _dialog_panel: PanelContainer = null
var _root_control: Control = null  # full-viewport Control inside the CanvasLayer
var _body_container: Control = null  # collapsible content under the title bar
var _drag_handle: Label = null
var _collapse_button: Button = null
# Drag/collapse state — same pattern as control_panel.gd.
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _collapsed: bool = false
var _has_been_dragged: bool = false  # switch from CENTER anchors to manual on first drag
# Project fonts loaded once and reused.
var _font_sans: Font = null
var _font_sans_bold: Font = null
var _font_mono: Font = null


func _ready() -> void:
	visible = false  # CanvasLayer-level visibility hides everything.
	# Sit above normal scene Controls; matches typical modal layer.
	layer = 64
	_load_project_fonts()
	_build_ui()
	# Seed each tab with mock data so the inspector reads populated
	# from the moment it's first opened.
	for category in CATEGORIES:
		_apply_items(category, MOCK_SEEDS.get(category, []))
	# Position the dialog in the right-side empty area away from the
	# DawnUI input column. Deferred so the viewport size is available.
	_set_default_position.call_deferred()


## Place the dialog near the top-right of the viewport so it doesn't
## cover the DawnUI input column on the left. Only runs when the user
## hasn't dragged the dialog manually.
func _set_default_position() -> void:
	if _dialog_panel == null:
		return
	var viewport_size: Vector2 = get_tree().root.get_visible_rect().size
	var x: float = max(20.0, viewport_size.x - _DEFAULT_DIALOG_SIZE.x - 30.0)
	var y: float = 80.0
	_dialog_panel.position = Vector2(x, y)


func _load_project_fonts() -> void:
	if ResourceLoader.exists(ArcReactor.FONT_SANS_PATH):
		_font_sans = load(ArcReactor.FONT_SANS_PATH)
	# Bold variant — RichTextLabel needs it explicitly when BBCode
	# uses [b], otherwise bold falls back to a default font that
	# renders blurry against the rest of the dialog.
	if ResourceLoader.exists(ArcReactor.FONT_SANS_BOLD):
		_font_sans_bold = load(ArcReactor.FONT_SANS_BOLD)
	if ResourceLoader.exists(ArcReactor.FONT_MONO_PATH):
		_font_mono = load(ArcReactor.FONT_MONO_PATH)


# ─── UI construction ──────────────────────────────────────────────────────

func _build_ui() -> void:
	# ─── Root Control: fills the host viewport via the CanvasLayer ───
	# CanvasLayer renders in viewport coordinates regardless of where
	# this node sits in the scene tree, so the dialog isn't clipped to
	# the DawnUI panel's narrow column.
	_root_control = Control.new()
	_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# PASS instead of STOP — clicks outside the dialog go through to
	# whatever is below, since this is a non-modal floating panel.
	_root_control.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root_control)

	# ─── Dialog panel: anchored top-left, positioned in code so we
	# can place it in the viewport's right-side empty area away from
	# the DawnUI input column. _set_default_position runs deferred
	# from _ready once the viewport size is known.
	_dialog_panel = PanelContainer.new()
	_dialog_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
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
	# Drop content margins to 0 — the title bar styles its own padding,
	# and the body's TabContainer doesn't need outer padding.
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	_dialog_panel.add_theme_stylebox_override("panel", style)
	_root_control.add_child(_dialog_panel)

	_root_vbox = VBoxContainer.new()
	_root_vbox.add_theme_constant_override("separation", 0)
	_dialog_panel.add_child(_root_vbox)

	# ─── Drag bar with title (drag handle), collapse, close ──────────
	var drag_bar := PanelContainer.new()
	drag_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	var drag_style := StyleBoxFlat.new()
	drag_style.bg_color = ArcReactor.BG_DARK
	# Round only the top corners so the bar sits flush against the
	# body region below it.
	drag_style.corner_radius_top_left = ArcReactor.RADIUS_MD
	drag_style.corner_radius_top_right = ArcReactor.RADIUS_MD
	drag_style.corner_radius_bottom_left = 0
	drag_style.corner_radius_bottom_right = 0
	drag_style.content_margin_left = ArcReactor.SPACE_MD
	drag_style.content_margin_right = ArcReactor.SPACE_MD
	drag_style.content_margin_top = ArcReactor.SPACE_XS
	drag_style.content_margin_bottom = ArcReactor.SPACE_XS
	drag_bar.add_theme_stylebox_override("panel", drag_style)
	_root_vbox.add_child(drag_bar)

	var drag_row := HBoxContainer.new()
	drag_row.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	drag_bar.add_child(drag_row)

	_drag_handle = Label.new()
	_drag_handle.text = "≡ D.A.W.N. Memory"
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

	# ─── Body container (collapsible) holds the tabs ─────────────────
	_body_container = MarginContainer.new()
	_body_container.add_theme_constant_override("margin_left", ArcReactor.SPACE_MD)
	_body_container.add_theme_constant_override("margin_right", ArcReactor.SPACE_MD)
	_body_container.add_theme_constant_override("margin_top", ArcReactor.SPACE_SM)
	_body_container.add_theme_constant_override("margin_bottom", ArcReactor.SPACE_SM)
	_body_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(_body_container)

	var body_vbox := VBoxContainer.new()
	_body_container.add_child(body_vbox)
	# Re-target _root_vbox so the existing TabContainer-add code below
	# still drops the tabs into the body region rather than the drag bar.
	_root_vbox = body_vbox

	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Pin the tab text styling so the tab strip renders at a known
	# resolution rather than falling back to a default font that
	# rendered blurry inside the embedded sub-window.
	_tab_container.add_theme_font_size_override("font_size", ArcReactor.FONT_BODY)
	_tab_container.add_theme_color_override("font_selected_color", ArcReactor.TEXT_PRIMARY)
	_tab_container.add_theme_color_override("font_unselected_color", ArcReactor.TEXT_SECONDARY)
	_tab_container.add_theme_color_override("font_hovered_color", ArcReactor.ARC_CORE)
	if _font_sans:
		_tab_container.add_theme_font_override("font", _font_sans)
	_root_vbox.add_child(_tab_container)

	for category in CATEGORIES:
		_state[category] = {
			"items": [],
			"filtered": [],
			"query": "",
			"search": null,
			"list": null,
			"detail": null,
		}
		var tab := _build_category_tab(category)
		_tab_container.add_child(tab)


func _build_category_tab(category: String) -> Control:
	# MarginContainer at the page root so the tab content has breathing
	# room from the TabContainer's tab strip on top and the panel
	# chrome on the sides — the tab text was reading flush against the
	# search box without it.
	var page := MarginContainer.new()
	page.name = category.capitalize()
	page.add_theme_constant_override("margin_left", ArcReactor.SPACE_SM)
	page.add_theme_constant_override("margin_right", ArcReactor.SPACE_SM)
	page.add_theme_constant_override("margin_top", ArcReactor.SPACE_MD)
	page.add_theme_constant_override("margin_bottom", ArcReactor.SPACE_SM)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	page.add_child(content)

	# Search box
	var search := LineEdit.new()
	search.placeholder_text = "Search %s…" % category
	search.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		search.add_theme_font_override("font", _font_sans)
	search.text_changed.connect(func(t: String): _on_search_changed(category, t))
	content.add_child(search)
	_state[category]["search"] = search

	# Item list (top half) + detail viewer (bottom half) split.
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio = 2.0
	list.add_theme_color_override("font_color", ArcReactor.TEXT_PRIMARY)
	list.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		list.add_theme_font_override("font", _font_sans)
	list.item_selected.connect(func(idx: int): _on_item_selected(category, idx))
	content.add_child(list)
	_state[category]["list"] = list

	var detail := RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.scroll_active = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio = 1.0
	detail.text = ""
	detail.selection_enabled = true
	detail.add_theme_color_override("default_color", ArcReactor.TEXT_SECONDARY)
	detail.add_theme_font_size_override("normal_font_size", ArcReactor.FONT_SMALL)
	detail.add_theme_font_size_override("bold_font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		detail.add_theme_font_override("normal_font", _font_sans)
	# Bold font for the [b]title[/b] in the detail body — without this
	# the bold text falls back to a system font that reads blurry
	# next to the regular Source Sans body.
	if _font_sans_bold:
		detail.add_theme_font_override("bold_font", _font_sans_bold)
	content.add_child(detail)
	_state[category]["detail"] = detail

	return page


# ─── Public API ───────────────────────────────────────────────────────────

## Toggle the inspector overlay's visibility. The dialog panel is
## anchored CENTER so re-centring on toggle is automatic.
func toggle() -> void:
	visible = not visible


## Apply a memory_update payload arriving on dawn/events.
func apply_event(payload: Dictionary) -> void:
	var category: String = str(payload.get("category", ""))
	if category.is_empty() or not _state.has(category):
		return
	var items: Array = payload.get("items", [])
	_apply_items(category, items)


# ─── Internals ────────────────────────────────────────────────────────────

func _apply_items(category: String, items: Array) -> void:
	_state[category]["items"] = items
	_apply_filter(category)


func _on_search_changed(category: String, query: String) -> void:
	_state[category]["query"] = query.to_lower()
	_apply_filter(category)


func _apply_filter(category: String) -> void:
	var s: Dictionary = _state[category]
	var query: String = s["query"]
	var items: Array = s["items"]
	var filtered: Array = []
	for item in items:
		if query.is_empty():
			filtered.append(item)
		else:
			var title := str(item.get("title", "")).to_lower()
			var body := str(item.get("body", "")).to_lower()
			if query in title or query in body:
				filtered.append(item)
	s["filtered"] = filtered

	var list: ItemList = s["list"]
	if list:
		list.clear()
		for item in filtered:
			list.add_item(str(item.get("title", "")))

	# Clear the detail pane when the list changes so a stale entry
	# doesn't linger after a search filters its source out.
	var detail: RichTextLabel = s["detail"]
	if detail:
		detail.text = ""


func _on_item_selected(category: String, index: int) -> void:
	var s: Dictionary = _state[category]
	var filtered: Array = s["filtered"]
	if index < 0 or index >= filtered.size():
		return
	var item: Dictionary = filtered[index]
	var detail: RichTextLabel = s["detail"]
	if detail == null:
		return
	var title: String = str(item.get("title", ""))
	var body: String = str(item.get("body", ""))
	var bb := "[b]%s[/b]\n\n%s" % [title, body]
	detail.text = bb


func _on_close() -> void:
	visible = false


# ─── Drag + collapse (same pattern as control_panel.gd) ──────────────────

func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = _dialog_panel.get_global_mouse_position() - _dialog_panel.global_position
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		# Switch the dialog from CENTER anchors to manual positioning
		# the first time the user drags it.
		if not _has_been_dragged:
			_switch_to_manual_position()
		_dialog_panel.global_position = _dialog_panel.get_global_mouse_position() - _drag_offset


func _switch_to_manual_position() -> void:
	_has_been_dragged = true
	var current_pos := _dialog_panel.global_position
	var current_size := _dialog_panel.size
	_dialog_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_dialog_panel.global_position = current_pos
	_dialog_panel.size = current_size


const _DEFAULT_DIALOG_SIZE := Vector2(480, 400)


func _on_collapse() -> void:
	_collapsed = not _collapsed
	if _body_container:
		_body_container.visible = not _collapsed
	if _collapse_button:
		_collapse_button.text = "▶" if _collapsed else "▼"
	# custom_minimum_size pins the panel at 480×400 even when the body
	# is hidden — clear it so the panel can shrink to the drag bar's
	# natural height when collapsed, restore it when expanding.
	if _collapsed:
		_dialog_panel.custom_minimum_size = Vector2.ZERO
	else:
		_dialog_panel.custom_minimum_size = _DEFAULT_DIALOG_SIZE
	_dialog_panel.size = Vector2.ZERO
	_dialog_panel.reset_size()
