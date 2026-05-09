## Reusable floating panel base for DAWN's draggable / collapsible
## overlay tools (memory inspector, conversation history sidebar,
## settings panel, future ones).
##
## Subclass and override `_build_body(parent)` to populate the panel's
## body region. Subclass may also set `dialog_title`, `dialog_size`,
## and `default_position` via _init() or @export overrides before
## _ready runs.
##
## Behaviour the base provides for all subclasses:
##   - CanvasLayer root at layer 64 (sits above the main scene Controls)
##   - Dialog placed directly under the CanvasLayer (no full-rect
##     wrapper) so mouse events outside the dialog miss this layer
##     entirely and propagate to the underlying scene — the host
##     UI's input fields keep keyboard focus while the panel is open.
##   - PanelContainer dialog with the standard ArcReactor stylebox
##     (BG_DEEPEST + ARC_BORDER, RADIUS_MD, no inner content padding)
##   - Drag bar at top: ≡ title (drag handle) + ▼/▶ collapse + ✕ close
##   - Drag handler that flips the dialog from anchored to manual
##     positioning on first drag so subsequent toggles preserve the
##     moved position
##   - Collapse handler that hides the body container and clears the
##     panel's custom_minimum_size so the dialog shrinks to the
##     drag bar's natural height
##   - _set_default_position helper that places the dialog according
##     to the configured `default_position` enum
##
## All scaffolding fonts pull from ArcReactor's project fonts loaded
## in _load_project_fonts; subclasses can use the protected
## _font_sans / _font_sans_bold for their own controls.
class_name FloatingPanel
extends CanvasLayer

const ArcReactor = preload("res://resources/design_tokens.gd")

enum DefaultPosition { TOP_LEFT, TOP_RIGHT, CENTER }

# ─── Subclass configuration ───────────────────────────────────────────────
# Override these in _init() or before super._ready() runs.
var dialog_title: String = "Panel"
var dialog_size: Vector2 = Vector2(440, 380)
var default_position: int = DefaultPosition.TOP_RIGHT
var canvas_layer_index: int = 64

# ─── Signals ──────────────────────────────────────────────────────────────
signal closed()

# ─── Internal UI nodes (accessible to subclasses) ─────────────────────────
var _dialog_panel: PanelContainer = null
var _body_container: MarginContainer = null
var _drag_handle: Label = null
var _collapse_button: Button = null

# ─── Drag/collapse state ──────────────────────────────────────────────────
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _collapsed: bool = false

# ─── Project fonts (subclasses can use these for body controls) ───────────
var _font_sans: Font = null
var _font_sans_bold: Font = null
var _font_mono: Font = null


func _ready() -> void:
	visible = false
	layer = canvas_layer_index
	_load_project_fonts()
	_build_chrome()
	# Subclass populates the body. Defer in case the subclass needs
	# nodes from _build_chrome to be in tree first.
	_build_body(_body_container)
	# Position after the viewport size is known.
	_set_default_position.call_deferred()


func _load_project_fonts() -> void:
	if ResourceLoader.exists(ArcReactor.FONT_SANS_PATH):
		_font_sans = load(ArcReactor.FONT_SANS_PATH)
	if ResourceLoader.exists(ArcReactor.FONT_SANS_BOLD):
		_font_sans_bold = load(ArcReactor.FONT_SANS_BOLD)
	if ResourceLoader.exists(ArcReactor.FONT_MONO_PATH):
		_font_mono = load(ArcReactor.FONT_MONO_PATH)


# ─── Chrome construction (drag bar + body container) ──────────────────────

func _build_chrome() -> void:
	_dialog_panel = PanelContainer.new()
	_dialog_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_dialog_panel.custom_minimum_size = dialog_size
	_dialog_panel.size = dialog_size
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = ArcReactor.BG_DEEPEST
	style.border_color = ArcReactor.ARC_BORDER
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(ArcReactor.RADIUS_MD)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	_dialog_panel.add_theme_stylebox_override("panel", style)
	add_child(_dialog_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	_dialog_panel.add_child(root_vbox)

	_build_drag_bar(root_vbox)

	_body_container = MarginContainer.new()
	_body_container.add_theme_constant_override("margin_left", ArcReactor.SPACE_MD)
	_body_container.add_theme_constant_override("margin_right", ArcReactor.SPACE_MD)
	_body_container.add_theme_constant_override("margin_top", ArcReactor.SPACE_SM)
	_body_container.add_theme_constant_override("margin_bottom", ArcReactor.SPACE_SM)
	_body_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_body_container)


func _build_drag_bar(parent: VBoxContainer) -> void:
	var drag_bar := PanelContainer.new()
	var drag_style := StyleBoxFlat.new()
	drag_style.bg_color = ArcReactor.BG_DARK
	drag_style.corner_radius_top_left = ArcReactor.RADIUS_MD
	drag_style.corner_radius_top_right = ArcReactor.RADIUS_MD
	drag_style.corner_radius_bottom_left = 0
	drag_style.corner_radius_bottom_right = 0
	drag_style.content_margin_left = ArcReactor.SPACE_MD
	drag_style.content_margin_right = ArcReactor.SPACE_MD
	drag_style.content_margin_top = ArcReactor.SPACE_XS
	drag_style.content_margin_bottom = ArcReactor.SPACE_XS
	drag_bar.add_theme_stylebox_override("panel", drag_style)
	parent.add_child(drag_bar)

	var drag_row := HBoxContainer.new()
	drag_row.add_theme_constant_override("separation", ArcReactor.SPACE_SM)
	drag_bar.add_child(drag_row)

	_drag_handle = Label.new()
	_drag_handle.text = "≡ %s" % dialog_title
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


# ─── Subclass override hook ───────────────────────────────────────────────

## Override in subclasses to populate the panel body. The `parent`
## MarginContainer already has SPACE_MD horizontal + SPACE_SM
## vertical margins; subclasses just add their content as children.
func _build_body(parent: MarginContainer) -> void:
	# Default no-op so a bare FloatingPanel still renders.
	pass


# ─── Public API ───────────────────────────────────────────────────────────

func toggle() -> void:
	visible = not visible


# ─── Default-position helper ──────────────────────────────────────────────

func _set_default_position() -> void:
	if _dialog_panel == null:
		return
	var viewport_size: Vector2 = get_tree().root.get_visible_rect().size
	match default_position:
		DefaultPosition.TOP_LEFT:
			_dialog_panel.position = Vector2(20, 20)
		DefaultPosition.TOP_RIGHT:
			var x: float = max(20.0, viewport_size.x - dialog_size.x - 30.0)
			_dialog_panel.position = Vector2(x, 80.0)
		DefaultPosition.CENTER:
			_dialog_panel.position = Vector2(
				max(0.0, (viewport_size.x - dialog_size.x) * 0.5),
				max(0.0, (viewport_size.y - dialog_size.y) * 0.5))


# ─── Drag + collapse handlers ─────────────────────────────────────────────

func _on_close() -> void:
	visible = false
	closed.emit()


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
		_dialog_panel.custom_minimum_size = dialog_size
	_dialog_panel.size = Vector2.ZERO
	_dialog_panel.reset_size()
