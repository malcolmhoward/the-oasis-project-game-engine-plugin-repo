## Embodiment type badge — color-coded pill showing E1-E5 type.
class_name EmbodimentBadge
extends PanelContainer


static func create(embodiment_type: String) -> EmbodimentBadge:
	var badge = EmbodimentBadge.new()
	badge._build(embodiment_type)
	return badge


func _build(embodiment_type: String) -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2

	var color: Color
	var display_text: String

	match embodiment_type.to_lower():
		"physical", "e1":
			color = ArcReactorDark.E1_PHYSICAL
			display_text = "E1 PHYSICAL"
		"remote", "e2":
			color = ArcReactorDark.E2_REMOTE
			display_text = "E2 REMOTE"
		"digital", "e3", "software":
			color = ArcReactorDark.E3_DIGITAL
			display_text = "E3 DIGITAL"
		"software-only", "e4":
			color = ArcReactorDark.E4_SOFTWARE
			display_text = "E4 SOFTWARE"
		"hybrid", "e5":
			color = ArcReactorDark.E5_HYBRID
			display_text = "E5 HYBRID"
		_:
			color = ArcReactorDark.TEXT_TERTIARY
			display_text = embodiment_type.to_upper()

	style.bg_color = Color(color, 0.2)
	style.border_color = color
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = display_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	var mono_font = load(ArcReactorDark.FONT_MONO_PATH) if ResourceLoader.exists(ArcReactorDark.FONT_MONO_PATH) else null
	if mono_font:
		label.add_theme_font_override("font", mono_font)
	add_child(label)
