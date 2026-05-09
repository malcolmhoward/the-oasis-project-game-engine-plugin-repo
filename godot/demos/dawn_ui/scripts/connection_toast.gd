## D.A.W.N. connection state toast (Phase 5).
##
## Fade-in/out label that appears at the top of DawnUI when the
## connection state to D.A.W.N. transitions (online ↔ offline). The
## status dot in the header still gives the at-a-glance view; this
## toast is the explicit acknowledgment that "something just changed."
##
## Public API:
##   show_online()   — flash a green "D.A.W.N. online" toast
##   show_offline()  — flash an amber "D.A.W.N. offline" toast
##
## Both share a single Tween — calling either while another is
## in-flight kills the old one and starts the new one cleanly.
extends PanelContainer

const ArcReactor = preload("res://resources/design_tokens.gd")

const VISIBLE_SEC: float = 2.5
const FADE_SEC: float = 0.4

var _label: Label = null
var _active_tween: Tween = null
var _font_sans: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	if ResourceLoader.exists(ArcReactor.FONT_SANS_PATH):
		_font_sans = load(ArcReactor.FONT_SANS_PATH)
	_build()


func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = ArcReactor.BG_DARK
	style.set_corner_radius_all(ArcReactor.RADIUS_MD)
	style.content_margin_left = ArcReactor.SPACE_MD
	style.content_margin_right = ArcReactor.SPACE_MD
	style.content_margin_top = ArcReactor.SPACE_XS
	style.content_margin_bottom = ArcReactor.SPACE_XS
	style.border_width_left = 3
	style.border_color = ArcReactor.STATUS_SUCCESS  # overwritten per state
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.text = ""
	_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)
	if _font_sans:
		_label.add_theme_font_override("font", _font_sans)
	add_child(_label)


func show_online() -> void:
	_show("D.A.W.N. online", ArcReactor.STATUS_SUCCESS, ArcReactor.TEXT_PRIMARY)


func show_offline() -> void:
	_show("D.A.W.N. offline", ArcReactor.STATUS_WARNING, ArcReactor.TEXT_PRIMARY)


func _show(text: String, accent: Color, label_color: Color) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", label_color)
	# Repaint the border accent.
	var style: StyleBoxFlat = get_theme_stylebox("panel")
	if style:
		style.border_color = accent
	visible = true
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	# Fade in from current alpha (0 on first show, mid-fade on overlap).
	if modulate.a < 1.0:
		_active_tween.tween_property(self, "modulate:a", 1.0, FADE_SEC)
	_active_tween.tween_interval(VISIBLE_SEC)
	_active_tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	_active_tween.tween_callback(func(): visible = false)
