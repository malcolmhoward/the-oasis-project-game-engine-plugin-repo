## D.A.W.N. memory inspector (Phase 4).
##
## Five tabs — facts, preferences, summaries, entities, contacts —
## each with a search box, scrollable item list, and detail pane.
##
## Inherits the floating-panel chrome (CanvasLayer + draggable +
## collapsible drag bar + close) from FloatingPanel; only the body
## construction (the tabs) and the memory-specific state live here.
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
extends "res://demos/dawn_ui/scripts/floating_panel.gd"

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
var _tab_container: TabContainer = null


func _init() -> void:
	dialog_title = "D.A.W.N. Memory"
	dialog_size = Vector2(480, 400)
	default_position = DefaultPosition.TOP_RIGHT


func _ready() -> void:
	super._ready()
	# Seed each tab with mock data so the inspector reads populated
	# from the moment it's first opened.
	for category in CATEGORIES:
		_apply_items(category, MOCK_SEEDS.get(category, []))


# ─── Body construction (override) ─────────────────────────────────────────

func _build_body(parent: MarginContainer) -> void:
	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_theme_font_size_override("font_size", ArcReactor.FONT_BODY)
	_tab_container.add_theme_color_override("font_selected_color", ArcReactor.TEXT_PRIMARY)
	_tab_container.add_theme_color_override("font_unselected_color", ArcReactor.TEXT_SECONDARY)
	_tab_container.add_theme_color_override("font_hovered_color", ArcReactor.ARC_CORE)
	if _font_sans:
		_tab_container.add_theme_font_override("font", _font_sans)
	parent.add_child(_tab_container)

	for category in CATEGORIES:
		_state[category] = {
			"items": [],
			"filtered": [],
			"query": "",
			"search": null,
			"list": null,
			"detail": null,
		}
		_tab_container.add_child(_build_category_tab(category))


func _build_category_tab(category: String) -> Control:
	var page := MarginContainer.new()
	page.name = category.capitalize()
	page.add_theme_constant_override("margin_left", ArcReactor.SPACE_SM)
	page.add_theme_constant_override("margin_right", ArcReactor.SPACE_SM)
	page.add_theme_constant_override("margin_top", ArcReactor.SPACE_MD)
	page.add_theme_constant_override("margin_bottom", ArcReactor.SPACE_SM)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	page.add_child(content)

	var search := LineEdit.new()
	search.placeholder_text = "Search %s…" % category
	search.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		search.add_theme_font_override("font", _font_sans)
	search.text_changed.connect(func(t: String): _on_search_changed(category, t))
	content.add_child(search)
	_state[category]["search"] = search

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
	if _font_sans_bold:
		detail.add_theme_font_override("bold_font", _font_sans_bold)
	content.add_child(detail)
	_state[category]["detail"] = detail

	return page


# ─── Public API ───────────────────────────────────────────────────────────

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
	detail.text = "[b]%s[/b]\n\n%s" % [title, body]
