## D.A.W.N. plan orchestrator block (Phase 3).
##
## Renders a multi-step plan inline in the transcript. Each step has a
## status indicator (PENDING gray, RUNNING amber, DONE green, ERROR red)
## that updates as plan_step_update events arrive. Default-expanded
## during streaming so the user can watch progress; collapses on
## plan_end with the final outcome summary in the header.
##
## Subscribes implicitly via dawn_ui.gd's event router:
##   plan_start        → spawn block, populate step list
##   plan_step_update  → flip status (and optional note) on indexed step
##   plan_end          → finalise, show summary, default to collapsed
class_name PlanOrchestratorBlock
extends PanelContainer

const ArcReactor = preload("res://resources/design_tokens.gd")

const STATUS_PENDING := "pending"
const STATUS_RUNNING := "running"
const STATUS_SUCCESS := "success"
const STATUS_ERROR := "error"

var _expanded: bool = true
var _orchestrator_id: String = ""
var _start_ms: int = 0

var _header_button: Button = null
var _summary_label: Label = null
var _body_scroll: ScrollContainer = null
var _step_list: VBoxContainer = null
# Step rows keyed by index so plan_step_update can reach them in O(1).
var _step_rows: Array = []


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ArcReactor.ACCENT_PURPLE.r, ArcReactor.ACCENT_PURPLE.g,
		ArcReactor.ACCENT_PURPLE.b, 0.10)
	style.border_width_left = 3
	style.border_color = ArcReactor.ACCENT_PURPLE
	style.set_corner_radius_all(ArcReactor.RADIUS_MD)
	style.content_margin_left = ArcReactor.SPACE_MD
	style.content_margin_right = ArcReactor.SPACE_MD
	style.content_margin_top = ArcReactor.SPACE_SM
	style.content_margin_bottom = ArcReactor.SPACE_SM
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", ArcReactor.SPACE_XS)
	add_child(vbox)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	vbox.add_child(header)

	_header_button = Button.new()
	_header_button.flat = true
	_header_button.text = "▾ PLAN"
	_header_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_button.add_theme_color_override("font_color", ArcReactor.ACCENT_PURPLE)
	_header_button.add_theme_color_override("font_hover_color", ArcReactor.TEXT_PRIMARY)
	_header_button.add_theme_color_override("font_pressed_color", ArcReactor.ACCENT_PURPLE)
	_header_button.add_theme_color_override("font_focus_color", ArcReactor.ACCENT_PURPLE)
	_header_button.add_theme_font_size_override("font_size", ArcReactor.FONT_BODY)
	_header_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_header_button.pressed.connect(_toggle_expanded)
	header.add_child(_header_button)

	_summary_label = Label.new()
	_summary_label.name = "Summary"
	_summary_label.text = ""
	_summary_label.add_theme_color_override("font_color", ArcReactor.TEXT_TERTIARY)
	_summary_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	header.add_child(_summary_label)

	_body_scroll = ScrollContainer.new()
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Step list grows naturally; cap at the same 140 px ceiling as siblings
	# so a long plan scrolls inside the block.
	_body_scroll.custom_minimum_size = Vector2(0, 0)
	vbox.add_child(_body_scroll)

	# Wrap the step list in a MarginContainer so the rows have left/right
	# breathing room from the panel's left accent border and right edge,
	# plus a little top/bottom space inside the scroll viewport.
	var step_list_margin := MarginContainer.new()
	step_list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_list_margin.add_theme_constant_override("margin_left", ArcReactor.SPACE_MD)
	step_list_margin.add_theme_constant_override("margin_right", ArcReactor.SPACE_MD)
	step_list_margin.add_theme_constant_override("margin_top", ArcReactor.SPACE_XS)
	step_list_margin.add_theme_constant_override("margin_bottom", ArcReactor.SPACE_XS)
	_body_scroll.add_child(step_list_margin)

	_step_list = VBoxContainer.new()
	_step_list.name = "StepList"
	_step_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_list.add_theme_constant_override("separation", ArcReactor.SPACE_XS)
	step_list_margin.add_child(_step_list)


## Initialise from a plan_start event. `steps` is an array of either
## strings (step names) or dictionaries with {name, description}.
func start(orchestrator_id: String, steps: Array) -> void:
	_orchestrator_id = orchestrator_id
	_start_ms = OCPMessage.now_ms()
	_step_rows.clear()
	for child in _step_list.get_children():
		child.queue_free()

	for i in range(steps.size()):
		var raw = steps[i]
		var name := ""
		var description := ""
		if raw is Dictionary:
			name = str(raw.get("name", "Step %d" % (i + 1)))
			description = str(raw.get("description", ""))
		else:
			name = str(raw)
		_step_rows.append(_make_step_row(i, name, description))

	_header_button.text = "▾ PLAN — %d step%s" % [
		steps.size(), "" if steps.size() == 1 else "s"]
	_summary_label.text = "running…"
	_set_expanded(true)
	_resize_body()


## Update a single step's status and optional note. status ∈
## {pending, running, success, error}.
func update_step(step_index: int, status: String, note: String = "") -> void:
	if step_index < 0 or step_index >= _step_rows.size():
		return
	var row: Dictionary = _step_rows[step_index]
	var dot: Label = row["dot"]
	var label: Label = row["label"]
	var note_label: Label = row["note"]

	var color: Color = _status_color(status)
	dot.text = _status_glyph(status)
	dot.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_color",
		ArcReactor.TEXT_PRIMARY if status != STATUS_PENDING else ArcReactor.TEXT_SECONDARY)

	if not note.is_empty():
		note_label.text = note
		note_label.visible = true
	_resize_body()


## Finalise the block. `summary` is optional free text; if absent we
## report a step tally ("3/4 done · 1 error").
func finish(summary: String = "", duration_ms: int = 0) -> void:
	if duration_ms <= 0 and _start_ms > 0:
		duration_ms = OCPMessage.now_ms() - _start_ms
	if summary.is_empty():
		var done: int = 0
		var errored: int = 0
		for row in _step_rows:
			var s: String = row.get("status", STATUS_PENDING)
			if s == STATUS_SUCCESS:
				done += 1
			elif s == STATUS_ERROR:
				errored += 1
		summary = "%d/%d done" % [done, _step_rows.size()]
		if errored > 0:
			summary += " · %d error" % errored
	_summary_label.text = "%s · %.1fs" % [summary, duration_ms / 1000.0]
	_set_expanded(false)


# ─── internal helpers ─────────────────────────────────────────────────────

func _make_step_row(_index: int, name: String, description: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ArcReactor.SPACE_SM)

	var dot := Label.new()
	dot.text = _status_glyph(STATUS_PENDING)
	dot.custom_minimum_size = Vector2(16, 0)
	dot.add_theme_color_override("font_color", _status_color(STATUS_PENDING))
	dot.add_theme_font_size_override("font_size", ArcReactor.FONT_BODY)
	row.add_child(dot)

	var name_label := Label.new()
	name_label.text = name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
	name_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	row.add_child(name_label)

	var note_label := Label.new()
	note_label.text = description
	note_label.visible = not description.is_empty()
	note_label.add_theme_color_override("font_color", ArcReactor.TEXT_TERTIARY)
	note_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	row.add_child(note_label)

	_step_list.add_child(row)

	return {
		"row": row,
		"dot": dot,
		"label": name_label,
		"note": note_label,
		"status": STATUS_PENDING,
	}


func _status_color(status: String) -> Color:
	match status:
		STATUS_RUNNING: return ArcReactor.STATUS_WARNING
		STATUS_SUCCESS: return ArcReactor.STATUS_SUCCESS
		STATUS_ERROR:   return ArcReactor.STATUS_ERROR
		_:              return ArcReactor.TEXT_TERTIARY


func _status_glyph(status: String) -> String:
	match status:
		STATUS_RUNNING: return "◐"
		STATUS_SUCCESS: return "●"
		STATUS_ERROR:   return "✕"
		_:              return "○"


func _resize_body() -> void:
	# Cap the step list height at 140 px scrollable so a long plan
	# doesn't push the rest of the transcript off-screen.
	var natural_h: int = int(_step_list.size.y) if _step_list.size.y > 0 else 0
	if natural_h <= 0:
		# First-frame fallback before layout settles.
		natural_h = _step_rows.size() * 28
	var clamped_h: int = min(natural_h, 140)
	_body_scroll.custom_minimum_size = Vector2(0, clamped_h)


func _toggle_expanded() -> void:
	_set_expanded(not _expanded)


func _set_expanded(expanded: bool) -> void:
	_expanded = expanded
	_body_scroll.visible = expanded
	var arrow := "▾" if expanded else "▸"
	if _header_button.text.length() >= 1:
		_header_button.text = arrow + _header_button.text.substr(1)
