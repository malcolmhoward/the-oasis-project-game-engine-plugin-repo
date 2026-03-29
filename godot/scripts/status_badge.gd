## Status badge component matching DAWN WebUI .dawn-badge styling.
##
## Small pill-shaped label with background color indicating state.
class_name StatusBadge
extends PanelContainer

enum BadgeType { ACCENT, SUCCESS, WARNING, ERROR, MUTED }


static func create(text: String, type: BadgeType = BadgeType.MUTED) -> StatusBadge:
	var badge = StatusBadge.new()
	badge._build(text, type)
	return badge


func _build(text: String, type: BadgeType) -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2

	var label = Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 11)

	var mono_font = load(ArcReactorDark.FONT_MONO_PATH) if ResourceLoader.exists(ArcReactorDark.FONT_MONO_PATH) else null
	if mono_font:
		label.add_theme_font_override("font", mono_font)

	match type:
		BadgeType.ACCENT:
			style.bg_color = ArcReactorDark.ARC_CORE
			label.add_theme_color_override("font_color", ArcReactorDark.TEXT_INVERSE)
		BadgeType.SUCCESS:
			style.bg_color = ArcReactorDark.STATUS_SUCCESS
			label.add_theme_color_override("font_color", ArcReactorDark.TEXT_INVERSE)
		BadgeType.WARNING:
			style.bg_color = ArcReactorDark.STATUS_WARNING
			label.add_theme_color_override("font_color", ArcReactorDark.TEXT_INVERSE)
		BadgeType.ERROR:
			style.bg_color = ArcReactorDark.STATUS_ERROR
			label.add_theme_color_override("font_color", Color.WHITE)
		BadgeType.MUTED:
			style.bg_color = ArcReactorDark.BG_DARK
			style.border_color = ArcReactorDark.BORDER_DEFAULT
			style.set_border_width_all(1)
			label.add_theme_color_override("font_color", ArcReactorDark.TEXT_SECONDARY)

	add_theme_stylebox_override("panel", style)
	add_child(label)
