extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

const ARC_CORE := Color("2dd4bf")
const TEXT_SECONDARY := Color("a0a0a0")
const JSON_KEY := Color("88ccff")    # light blue for keys
const JSON_STRING := Color("ccee88") # light green for string values
const JSON_NUMBER := Color("ffaa66") # orange for numbers
const JSON_BRACE := Color("cccccc")  # gray for braces

# Formatted JSON with syntax highlighting via BBCode
const LEFT_JSON := """[color=#888888]publishes →[/color] [color=#2dd4bf]oasis/mirage/status[/color]

[color=#cccccc]{[/color]
  [color=#88ccff]"device"[/color]  : [color=#ccee88]"mirage"[/color],
  [color=#88ccff]"uptime"[/color]  : [color=#ffaa66]120[/color],
  [color=#88ccff]"battery"[/color] : [color=#ffaa66]85[/color]
[color=#cccccc]}[/color]"""

const RIGHT_JSON := """[color=#888888]publishes →[/color] [color=#2dd4bf]oasis/e3-avatar/status[/color]

[color=#cccccc]{[/color]
  [color=#88ccff]"device"[/color]  : [color=#ccee88]"e3-avatar"[/color],
  [color=#88ccff]"uptime"[/color]  : [color=#ffaa66]45[/color],
  [color=#88ccff]"battery"[/color] : [color=#ffaa66]100[/color]
[color=#cccccc]}[/color]"""


func _ready():
	total_steps = 4

	# Style title
	$Title.add_theme_color_override("font_color", ARC_CORE)

	# Style headers
	$LeftHeader.add_theme_color_override("font_color", Color("f0a050"))  # orange for physical
	$RightHeader.add_theme_color_override("font_color", Color("008888"))  # teal for digital

	# Style panels with dark code-block backgrounds
	for panel in [$LeftPanel, $RightPanel]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1a1e24")
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 24.0
		style.content_margin_right = 24.0
		style.content_margin_top = 20.0
		style.content_margin_bottom = 20.0
		panel.add_theme_stylebox_override("panel", style)

	# Set monospace font and size for JSON content
	var mono_font = load("res://resources/fonts/IBMPlexMono-Regular.ttf")
	for rtl in [$LeftPanel/LeftContent, $RightPanel/RightContent]:
		if mono_font:
			rtl.add_theme_font_override("normal_font", mono_font)
		rtl.add_theme_font_size_override("normal_font_size", 26)

	# Set JSON content
	$LeftPanel/LeftContent.text = LEFT_JSON
	$RightPanel/RightContent.text = RIGHT_JSON

	# Hide animated elements
	$LeftHeader.visible = false
	$LeftPanel.visible = false
	$RightHeader.visible = false
	$RightPanel.visible = false
	$MatchHighlight.visible = false
	$Tagline.visible = false

	# Tag panels for morph transition to live demo
	$LeftPanel.add_to_group("morph_panel")
	$RightPanel.add_to_group("morph_panel")


func _animate_step(step: int) -> void:
	match step:
		1:
			_fade_in($LeftHeader, 0.3)
			_slide_in_left($LeftPanel, 0.5, 60.0, 0.1)
		2:
			_fade_in($RightHeader, 0.3)
			_slide_in_left($RightPanel, 0.5, 60.0, 0.1)
		3:
			_fade_in($MatchHighlight, 0.5)
		4:
			_slide_up($Tagline, 0.5, 25.0)


func _animate_step_instant(step: int) -> void:
	match step:
		1:
			$LeftHeader.visible = true
			$LeftHeader.modulate.a = 1.0
			$LeftPanel.visible = true
			$LeftPanel.modulate.a = 1.0
		2:
			$RightHeader.visible = true
			$RightHeader.modulate.a = 1.0
			$RightPanel.visible = true
			$RightPanel.modulate.a = 1.0
		3:
			$MatchHighlight.visible = true
			$MatchHighlight.modulate.a = 1.0
		4:
			$Tagline.visible = true
			$Tagline.modulate.a = 1.0


func _reset_animations() -> void:
	$LeftHeader.visible = false
	$LeftHeader.modulate.a = 0.0
	$LeftPanel.visible = false
	$LeftPanel.modulate.a = 0.0
	$RightHeader.visible = false
	$RightHeader.modulate.a = 0.0
	$RightPanel.visible = false
	$RightPanel.modulate.a = 0.0
	$MatchHighlight.visible = false
	$MatchHighlight.modulate.a = 0.0
	$Tagline.visible = false
	$Tagline.modulate.a = 0.0
