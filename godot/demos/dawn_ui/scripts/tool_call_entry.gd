## D.A.W.N. tool-execution entry (Phase 3).
##
## Rendered inline in the transcript when D.A.W.N. invokes a tool. Shows
## the tool name in the header, the call arguments + result in a body that
## scrolls internally if it gets long, and a status badge that flips from
## "RUNNING" (after tool_call) to "DONE" / "ERROR" (after tool_result).
##
## Subscribes implicitly via dawn_ui.gd's event router:
##   tool_call    → spawn entry, render arguments, status=RUNNING
##   tool_result  → fill result body, status=DONE or ERROR
class_name ToolCallEntry
extends PanelContainer

const ArcReactor = preload("res://resources/design_tokens.gd")

const BODY_MAX_HEIGHT: int = 140

var _expanded: bool = false
var _call_id: String = ""
var _start_ms: int = 0

var _header_button: Button = null
var _status_label: Label = null
var _duration_label: Label = null
var _body_label: RichTextLabel = null
var _body_scroll: ScrollContainer = null
var _tool_name: String = ""


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
	_header_button.text = "▸ TOOL"
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

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.text = "RUNNING"
	_status_label.add_theme_color_override("font_color", ArcReactor.STATUS_WARNING)
	_status_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	header.add_child(_status_label)

	_duration_label = Label.new()
	_duration_label.name = "Duration"
	_duration_label.text = ""
	_duration_label.add_theme_color_override("font_color", ArcReactor.TEXT_TERTIARY)
	_duration_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	header.add_child(_duration_label)

	_body_scroll = ScrollContainer.new()
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.custom_minimum_size = Vector2(0, 0)
	_body_scroll.visible = false  # Default collapsed
	vbox.add_child(_body_scroll)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.text = ""
	_body_label.add_theme_color_override("default_color", ArcReactor.TEXT_SECONDARY)
	_body_label.add_theme_font_size_override("normal_font_size", ArcReactor.FONT_SMALL)
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.selection_enabled = true
	_body_scroll.add_child(_body_label)


## Initialise from a tool_call event. Renders the call arguments in the
## body and primes the status to RUNNING.
func start(call_id: String, tool_name: String, arguments: Dictionary) -> void:
	_call_id = call_id
	_tool_name = tool_name
	_start_ms = OCPMessage.now_ms()
	_header_button.text = "▸ TOOL — %s" % tool_name.to_upper()
	_status_label.text = "RUNNING"
	_status_label.add_theme_color_override("font_color", ArcReactor.STATUS_WARNING)
	_duration_label.text = "…"

	var pretty_args := JSON.stringify(arguments, "  ")
	var bbcode := "[color=#%s]arguments:[/color]\n[code]%s[/code]" % [
		ArcReactor.TEXT_TERTIARY.to_html(false), pretty_args]
	_body_label.text = bbcode
	_resize_body()


## Fill the result from a tool_result event. Status flips to DONE
## (or ERROR if the result has an "error" field).
func finish(result: Variant, duration_ms: int = 0) -> void:
	if duration_ms <= 0 and _start_ms > 0:
		duration_ms = OCPMessage.now_ms() - _start_ms
	_duration_label.text = "%.2fs" % (duration_ms / 1000.0)

	var is_error := result is Dictionary and result.has("error")
	if is_error:
		_status_label.text = "ERROR"
		_status_label.add_theme_color_override("font_color", ArcReactor.STATUS_ERROR)
	else:
		_status_label.text = "DONE"
		_status_label.add_theme_color_override("font_color", ArcReactor.STATUS_SUCCESS)

	var pretty_result := JSON.stringify(result, "  ") if result is Dictionary or result is Array else str(result)
	var label_color := ArcReactor.STATUS_ERROR if is_error else ArcReactor.TEXT_TERTIARY
	var existing := _body_label.text
	_body_label.text = "%s\n\n[color=#%s]result:[/color]\n[code]%s[/code]" % [
		existing, label_color.to_html(false), pretty_result]
	_resize_body()


func _resize_body() -> void:
	var natural_h: int = int(_body_label.get_content_height())
	var clamped_h: int = min(natural_h, BODY_MAX_HEIGHT)
	_body_scroll.custom_minimum_size = Vector2(0, clamped_h)
	_scroll_body_to_bottom.call_deferred()


func _scroll_body_to_bottom() -> void:
	var bar := _body_scroll.get_v_scroll_bar()
	if bar:
		bar.value = bar.max_value


func _toggle_expanded() -> void:
	_set_expanded(not _expanded)


func _set_expanded(expanded: bool) -> void:
	_expanded = expanded
	_body_scroll.visible = expanded
	var arrow := "▾" if expanded else "▸"
	if _header_button.text.length() >= 1:
		_header_button.text = arrow + _header_button.text.substr(1)
