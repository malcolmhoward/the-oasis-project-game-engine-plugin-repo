extends "res://scenes/demos/demo_presentation/SlideTemplate.gd"

# Design tokens
const BG_DEEPEST := Color("121417")
const ARC_CORE := Color("2dd4bf")
const TEXT_PRIMARY := Color("e6e6e6")
const TEXT_SECONDARY := Color("a0a0a0")
const TEXT_TERTIARY := Color("666666")

# Layer tint colors
const DEVICE_TINT := Color("3d2a1a")    # warm orange-brown
const NETWORK_TINT := Color("1a2a3d")   # cool blue
const PLATFORM_TINT := Color("1a3d36")  # teal, matches ARC_CORE

# Label colors per layer
const DEVICE_TEXT := Color("f0a050")     # orange
const NETWORK_TEXT := Color("60a0e0")    # blue
const PLATFORM_TEXT := Color("2dd4bf")   # teal / ARC_CORE


func _ready() -> void:
	total_steps = 4

	# Title
	var title := $Title as Label
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", ARC_CORE)

	# Style each panel with its tint and label color
	_style_panel($DevicePanel, DEVICE_TINT, $DevicePanel/DeviceLabel, DEVICE_TEXT)
	_style_panel($NetworkPanel, NETWORK_TINT, $NetworkPanel/NetworkLabel, NETWORK_TEXT)
	_style_panel($PlatformPanel, PLATFORM_TINT, $PlatformPanel/PlatformLabel, PLATFORM_TEXT)

	# Add panels to morph_panel group for MorphTransition
	$DevicePanel.add_to_group("morph_panel")
	$NetworkPanel.add_to_group("morph_panel")
	$PlatformPanel.add_to_group("morph_panel")

	# Set morph_target metadata so MorphTransition can locate each panel
	$DevicePanel.set_meta("morph_target", "device_layer")
	$NetworkPanel.set_meta("morph_target", "network_layer")
	$PlatformPanel.set_meta("morph_target", "platform_layer")


func _style_panel(panel: PanelContainer, bg_color: Color,
		label: Label, label_color: Color) -> void:
	# Create a StyleBoxFlat for the panel background
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", style)

	# Style the label
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", label_color)


func _animate_step(step: int) -> void:
	match step:
		1:
			# Title fades in
			_fade_in($Title, 0.4)
		2:
			# Device layer slides up from below (bottom of stack)
			_slide_up($DevicePanel, 0.5, 40.0)
		3:
			# Network layer stacks on top
			_slide_up($NetworkPanel, 0.5, 40.0)
		4:
			# Platform layer completes the stack
			_slide_up($PlatformPanel, 0.5, 40.0)


func _reset_animations() -> void:
	$Title.visible = false
	$Title.modulate.a = 0.0
	$DevicePanel.visible = false
	$DevicePanel.modulate.a = 0.0
	$NetworkPanel.visible = false
	$NetworkPanel.modulate.a = 0.0
	$PlatformPanel.visible = false
	$PlatformPanel.modulate.a = 0.0
