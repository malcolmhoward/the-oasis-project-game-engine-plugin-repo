## D.A.W.N. extended-thinking block (Phase 3).
##
## Collapsible BBCode region rendered inside the transcript whenever
## D.A.W.N. emits Claude/OpenAI-style "thinking" content alongside the
## final response. Subscribes implicitly via dawn_ui's event router:
##   thinking_start  → reveal placeholder + start streaming
##   thinking_delta  → append text
##   thinking_end    → finalise; show duration; default to collapsed
##
## Visual: dim accent border on the left, "THINKING" header with a
## chevron toggle and duration badge, the body itself in a slightly
## smaller font with the secondary text colour.
class_name ThinkingBlock
extends PanelContainer

const ArcReactor = preload("res://resources/design_tokens.gd")

## Maximum height the body grows to before scrolling internally. Keeps a
## long thinking trace from pushing the rest of the transcript out of view.
const BODY_MAX_HEIGHT: int = 140

var _expanded: bool = true
var _orchestrator_id: String = ""
var _start_ms: int = 0

var _header_button: Button = null
var _duration_label: Label = null
var _body_label: RichTextLabel = null
var _body_scroll: ScrollContainer = null


func _init() -> void:
	# Build the panel skeleton in code so the scene file stays simple.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ArcReactor.ACCENT_PURPLE.r, ArcReactor.ACCENT_PURPLE.g,
		ArcReactor.ACCENT_PURPLE.b, 0.10)
	style.border_width_left = 3
	style.border_color = ArcReactor.ACCENT_PURPLE
	style.set_corner_radius_all(ArcReactor.RADIUS_MD)
	style.content_margin_left = ArcReactor.SPACE_MD
	style.content_margin_right = ArcReactor.SPACE_MD
	style.content_margin_top = ArcReactor.SPACE_SM
	style.content_margin_bottom = ArcReactor.SPACE_XS
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
	_header_button.text = "▾ THINKING"
	_header_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_button.add_theme_color_override("font_color", ArcReactor.ACCENT_PURPLE)
	# Bumped from FONT_ROLE (10) to FONT_BODY (16) so the chevron + label
	# read as obviously interactive. Hover lifts to TEXT_PRIMARY (near-
	# white) — high contrast against any background, no risk of blending
	# into the panel tint the way ARC_CORE did. Pressed/focus pinned to
	# ACCENT_PURPLE so the resting state is stable.
	_header_button.add_theme_font_size_override("font_size", ArcReactor.FONT_BODY)
	_header_button.add_theme_color_override("font_hover_color", ArcReactor.TEXT_PRIMARY)
	_header_button.add_theme_color_override("font_pressed_color", ArcReactor.ACCENT_PURPLE)
	_header_button.add_theme_color_override("font_focus_color", ArcReactor.ACCENT_PURPLE)
	_header_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_header_button.pressed.connect(_toggle_expanded)
	header.add_child(_header_button)

	_duration_label = Label.new()
	_duration_label.name = "Duration"
	_duration_label.text = ""
	_duration_label.add_theme_color_override("font_color", ArcReactor.TEXT_TERTIARY)
	_duration_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	header.add_child(_duration_label)

	_body_scroll = ScrollContainer.new()
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# SHRINK_BEGIN so the scroll wraps content tightly instead of inheriting
	# extra height from the parent VBox / PanelContainer fill behaviour —
	# without this, short thinking traces leave dead space at the bottom.
	_body_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.custom_minimum_size = Vector2(0, 0)
	vbox.add_child(_body_scroll)

	# Wrap the body label in a MarginContainer so the text has horizontal
	# padding from the panel's accent border on the left and the panel
	# edge on the right — mirrors the plan block's step-list padding.
	# Top/bottom margins are intentionally 0; the panel's own
	# content_margin_top/bottom already contributes padding, and the
	# body content was reading "loose" with a doubled bottom margin.
	var body_margin := MarginContainer.new()
	body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", ArcReactor.SPACE_MD)
	body_margin.add_theme_constant_override("margin_right", ArcReactor.SPACE_MD)
	body_margin.add_theme_constant_override("margin_top", 0)
	body_margin.add_theme_constant_override("margin_bottom", 0)
	_body_scroll.add_child(body_margin)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.text = ""
	_body_label.add_theme_color_override("default_color", ArcReactor.TEXT_SECONDARY)
	_body_label.add_theme_font_size_override("normal_font_size", ArcReactor.FONT_SMALL)
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.selection_enabled = true
	body_margin.add_child(_body_label)


func start(orchestrator_id: String, provider: String) -> void:
	_orchestrator_id = orchestrator_id
	_start_ms = OCPMessage.now_ms()
	var label_text := "▾ THINKING"
	if provider != "":
		label_text = "▾ THINKING — %s" % provider.to_upper()
	_header_button.text = label_text
	_duration_label.text = "…"
	_body_label.text = ""
	_set_expanded(true)


func append_delta(delta: String) -> void:
	_body_label.append_text(delta)
	# Cap the visible body at BODY_MAX_HEIGHT — content beyond that scrolls
	# internally rather than pushing the rest of the transcript out of view.
	var natural_h: int = int(_body_label.get_content_height())
	var clamped_h: int = min(natural_h, BODY_MAX_HEIGHT)
	_body_scroll.custom_minimum_size = Vector2(0, clamped_h)
	# Auto-scroll the inner body to its bottom so the latest delta is visible.
	# Defer one frame so the layout settles before we read max_value.
	_scroll_body_to_bottom.call_deferred()


func _scroll_body_to_bottom() -> void:
	var bar := _body_scroll.get_v_scroll_bar()
	if bar:
		bar.value = bar.max_value


func finish(duration_ms: int) -> void:
	if duration_ms <= 0 and _start_ms > 0:
		duration_ms = OCPMessage.now_ms() - _start_ms
	var seconds := duration_ms / 1000.0
	_duration_label.text = "%.1fs" % seconds
	# Default to collapsed once finished — keeps the transcript dense.
	_set_expanded(false)


func _toggle_expanded() -> void:
	_set_expanded(not _expanded)


func _set_expanded(expanded: bool) -> void:
	_expanded = expanded
	_body_scroll.visible = expanded
	var arrow := "▾" if expanded else "▸"
	# Replace just the leading arrow character without losing the rest.
	if _header_button.text.length() >= 1:
		_header_button.text = arrow + _header_button.text.substr(1)
