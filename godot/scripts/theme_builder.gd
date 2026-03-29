## Builds the Arc Reactor Dark theme programmatically.
##
## Run this as a tool script or call build_theme() from any @tool script
## to generate the theme resource. The theme is then applied to the root
## Control node of any scene.
##
## Usage in a scene's _ready():
##   var theme = ThemeBuilder.build_theme()
##   get_tree().root.theme = theme
class_name ThemeBuilder


static func build_theme() -> Theme:
	var theme := Theme.new()

	# Load fonts (matched to DAWN WebUI: Source Sans 3 + IBM Plex Mono)
	var font_sans = _load_font(ArcReactorDark.FONT_SANS_PATH, ArcReactorDark.FONT_BODY)
	var font_sans_medium = _load_font(ArcReactorDark.FONT_SANS_MEDIUM, ArcReactorDark.FONT_BODY)
	var font_sans_semibold = _load_font(ArcReactorDark.FONT_SANS_SEMIBOLD, ArcReactorDark.FONT_BODY)
	var font_sans_bold = _load_font(ArcReactorDark.FONT_SANS_BOLD, ArcReactorDark.FONT_BODY)
	var font_mono = _load_font(ArcReactorDark.FONT_MONO_PATH, ArcReactorDark.FONT_CODE)

	# Default font
	if font_sans:
		theme.default_font = font_sans
	theme.default_font_size = ArcReactorDark.FONT_BODY

	# --- PanelContainer ---
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ArcReactorDark.BG_DARK
	panel_style.border_color = ArcReactorDark.BORDER_DEFAULT
	panel_style.set_border_width_all(ArcReactorDark.BORDER_THIN)
	panel_style.set_corner_radius_all(ArcReactorDark.RADIUS_MD)
	panel_style.set_content_margin_all(ArcReactorDark.SPACE_LG)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# --- Button (matched to DAWN: solid accent background, dark text) ---
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = ArcReactorDark.ARC_CORE
	btn_normal.border_color = Color.TRANSPARENT
	btn_normal.set_border_width_all(ArcReactorDark.BORDER_THIN)
	btn_normal.set_corner_radius_all(ArcReactorDark.RADIUS_MD)
	btn_normal.set_content_margin_all(ArcReactorDark.SPACE_MD)
	btn_normal.content_margin_left = ArcReactorDark.SPACE_XL
	btn_normal.content_margin_right = ArcReactorDark.SPACE_XL
	theme.set_stylebox("normal", "Button", btn_normal)

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = ArcReactorDark.ARC_CORE.lightened(0.1)
	theme.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = ArcReactorDark.ARC_CORE.darkened(0.1)
	theme.set_stylebox("pressed", "Button", btn_pressed)

	var btn_focus := btn_normal.duplicate()
	btn_focus.border_color = ArcReactorDark.BORDER_FOCUS
	theme.set_stylebox("focus", "Button", btn_focus)

	theme.set_color("font_color", "Button", ArcReactorDark.TEXT_INVERSE)
	theme.set_color("font_hover_color", "Button", ArcReactorDark.TEXT_INVERSE)
	theme.set_color("font_pressed_color", "Button", ArcReactorDark.TEXT_INVERSE)
	if font_sans_semibold:
		theme.set_font("font", "Button", font_sans_semibold)

	# --- LineEdit ---
	var line_normal := StyleBoxFlat.new()
	line_normal.bg_color = ArcReactorDark.BG_INPUT
	line_normal.border_color = ArcReactorDark.BORDER_DEFAULT
	line_normal.set_border_width_all(ArcReactorDark.BORDER_THIN)
	line_normal.set_corner_radius_all(ArcReactorDark.RADIUS_SM)
	line_normal.set_content_margin_all(ArcReactorDark.SPACE_SM)
	theme.set_stylebox("normal", "LineEdit", line_normal)

	var line_focus := line_normal.duplicate()
	line_focus.border_color = ArcReactorDark.BORDER_FOCUS
	theme.set_stylebox("focus", "LineEdit", line_focus)

	theme.set_color("font_color", "LineEdit", ArcReactorDark.TEXT_PRIMARY)
	theme.set_color("font_placeholder_color", "LineEdit", ArcReactorDark.TEXT_TERTIARY)
	theme.set_color("caret_color", "LineEdit", ArcReactorDark.ARC_CORE)
	theme.set_color("selection_color", "LineEdit", ArcReactorDark.ARC_DIM)

	# --- Label ---
	theme.set_color("font_color", "Label", ArcReactorDark.TEXT_PRIMARY)

	# --- RichTextLabel ---
	theme.set_color("default_color", "RichTextLabel", ArcReactorDark.TEXT_PRIMARY)
	var rtl_normal := StyleBoxFlat.new()
	rtl_normal.bg_color = Color.TRANSPARENT
	theme.set_stylebox("normal", "RichTextLabel", rtl_normal)
	if font_mono:
		theme.set_font("normal_font", "RichTextLabel", font_mono)
	theme.set_font_size("normal_font_size", "RichTextLabel", ArcReactorDark.FONT_CODE)

	# --- ScrollContainer ---
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = ArcReactorDark.BG_DARK
	theme.set_stylebox("panel", "ScrollContainer", scroll_bg)

	# --- ProgressBar ---
	var progress_bg := StyleBoxFlat.new()
	progress_bg.bg_color = ArcReactorDark.BG_MEDIUM
	progress_bg.set_corner_radius_all(ArcReactorDark.RADIUS_SM)
	theme.set_stylebox("background", "ProgressBar", progress_bg)

	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = ArcReactorDark.ARC_CORE
	progress_fill.set_corner_radius_all(ArcReactorDark.RADIUS_SM)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)

	# --- HSplitContainer / VSplitContainer ---
	var split_dragger := StyleBoxFlat.new()
	split_dragger.bg_color = ArcReactorDark.BORDER_DIVIDER
	split_dragger.set_content_margin_all(2)
	theme.set_stylebox("split", "HSplitContainer", split_dragger)
	theme.set_stylebox("split", "VSplitContainer", split_dragger)
	theme.set_constant("separation", "HSplitContainer", 4)
	theme.set_constant("separation", "VSplitContainer", 4)

	# --- Window background ---
	theme.set_color("font_color", "TooltipLabel", ArcReactorDark.TEXT_PRIMARY)

	return theme


static func _load_font(path: String, size: int) -> Font:
	if ResourceLoader.exists(path):
		var font_file = load(path)
		return font_file
	return null
