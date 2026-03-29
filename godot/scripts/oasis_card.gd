## Reusable card component with left accent bar.
##
## A styled PanelContainer with:
## - BG_CARD background
## - Left accent stripe (color varies by context)
## - Rounded corners (RADIUS_MD)
## - Shadow effect
## - Internal padding (SPACE_LG)
class_name OasisCard
extends PanelContainer

enum AccentColor { DEFAULT, SUCCESS, WARNING, ERROR, INFO, PURPLE }


static func create(accent: AccentColor = AccentColor.DEFAULT) -> OasisCard:
	var card = OasisCard.new()
	card._apply_style(accent)
	return card


func _apply_style(accent: AccentColor) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = ArcReactorDark.BG_CARD
	style.set_corner_radius_all(ArcReactorDark.RADIUS_MD)
	style.set_content_margin_all(ArcReactorDark.SPACE_LG)
	style.border_color = ArcReactorDark.BORDER_DEFAULT
	style.set_border_width_all(ArcReactorDark.BORDER_THIN)

	# Left accent stripe
	var accent_color: Color
	match accent:
		AccentColor.SUCCESS: accent_color = ArcReactorDark.STATUS_SUCCESS
		AccentColor.WARNING: accent_color = ArcReactorDark.STATUS_WARNING
		AccentColor.ERROR: accent_color = ArcReactorDark.STATUS_ERROR
		AccentColor.INFO: accent_color = ArcReactorDark.STATUS_INFO
		AccentColor.PURPLE: accent_color = ArcReactorDark.ACCENT_PURPLE
		_: accent_color = ArcReactorDark.ARC_CORE

	style.border_width_left = ArcReactorDark.BORDER_ACCENT
	style.border_color = accent_color

	# Shadow
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_offset = Vector2(2, 3)
	style.shadow_size = 8

	add_theme_stylebox_override("panel", style)
