## Message bubble component matching DAWN WebUI transcript entries.
##
## User messages: right-margin indent, bg-tertiary background.
## Assistant messages: left-margin indent, accent-dim teal tint.
## System messages: red left border, red-tinted background.
##
## Role label uses IBM Plex Mono (uppercase, letter-spaced).
## Message text uses Source Sans 3 (sentence case).
class_name MessageBubble
extends PanelContainer

enum Role { USER, ASSISTANT, SYSTEM, DEBUG }

var _role: Role = Role.USER
var _msg_label: RichTextLabel = null


static func create(role: Role, sender: String, text: String) -> MessageBubble:
	var bubble = MessageBubble.new()
	bubble._role = role
	bubble._build(sender, text)
	return bubble


## Typewriter effect — reveals text character by character.
## Returns the tween so callers can await completion.
func typewrite(chars_per_sec: float = 40.0) -> Tween:
	if _msg_label == null or _msg_label.text.is_empty():
		return null
	var total_chars = _msg_label.text.length()
	_msg_label.visible_characters = 0
	var duration = total_chars / chars_per_sec
	var tween = create_tween()
	tween.tween_property(_msg_label, "visible_characters", total_chars, duration)
	return tween


func _build(sender: String, text: String) -> void:
	# Style the panel background based on role
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(ArcReactorDark.RADIUS_MD)
	style.set_content_margin_all(ArcReactorDark.SPACE_MD)

	match _role:
		Role.USER:
			style.bg_color = ArcReactorDark.MSG_USER_BG
		Role.ASSISTANT:
			style.bg_color = ArcReactorDark.MSG_ASSISTANT_BG
		Role.SYSTEM:
			style.bg_color = ArcReactorDark.MSG_SYSTEM_BG
			style.border_width_left = ArcReactorDark.BORDER_ACCENT
			style.border_color = ArcReactorDark.STATUS_ERROR
		Role.DEBUG:
			style.bg_color = ArcReactorDark.MSG_DEBUG_BG
			style.border_width_left = ArcReactorDark.BORDER_ACCENT
			style.border_color = ArcReactorDark.ACCENT_PURPLE

	# Apply margins for message alignment (DAWN pattern: margin on one side)
	# User messages: indented from left (right-aligned feel)
	# Assistant messages: indented from right (left-aligned feel)
	match _role:
		Role.USER:
			style.content_margin_left = ArcReactorDark.MSG_USER_MARGIN + ArcReactorDark.SPACE_MD
		Role.ASSISTANT:
			style.content_margin_right = ArcReactorDark.MSG_ASSIST_MARGIN + ArcReactorDark.SPACE_MD

	add_theme_stylebox_override("panel", style)

	# Fill available width
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Build content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", ArcReactorDark.SPACE_XS)
	add_child(vbox)

	# Role label — IBM Plex Mono, uppercase, letter-spaced
	var role_label = Label.new()
	role_label.text = sender.to_upper()
	role_label.add_theme_font_size_override("font_size", ArcReactorDark.FONT_ROLE)
	role_label.add_theme_color_override("font_color", ArcReactorDark.TEXT_SECONDARY)
	var mono_font = _load_font(ArcReactorDark.FONT_MONO_PATH)
	if mono_font:
		role_label.add_theme_font_override("font", mono_font)
	vbox.add_child(role_label)

	# Message text — Source Sans 3, sentence case
	_msg_label = RichTextLabel.new()
	var msg_label = _msg_label
	msg_label.bbcode_enabled = true
	msg_label.fit_content = true
	msg_label.scroll_active = false
	msg_label.text = text
	msg_label.add_theme_font_size_override("normal_font_size", 15)  # 0.9375rem
	msg_label.add_theme_color_override("default_color", ArcReactorDark.TEXT_PRIMARY)
	var sans_font = _load_font(ArcReactorDark.FONT_SANS_PATH)
	if sans_font:
		msg_label.add_theme_font_override("normal_font", sans_font)
	vbox.add_child(msg_label)


static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return null
