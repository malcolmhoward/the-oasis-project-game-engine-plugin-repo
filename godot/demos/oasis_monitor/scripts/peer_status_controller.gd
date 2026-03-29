@warning_ignore("inferred_declaration")
## OCP Peer Status panel.
##
## Displays a live list of all discovered OCP peers with their
## embodiment type (E1-E5), online/offline status, and last-seen time.
extends PanelContainer

@onready var peer_list: VBoxContainer = $VBoxContainer/ScrollContainer/PeerList

const EMBODIMENT_COLORS = {
	"physical": Color("#CC8844"),       # E1 — warm amber
	"remote_physical": Color("#CC6644"),# E2 — orange
	"digital": Color("#008888"),        # E3 — teal
	"software": Color("#884488"),       # E4 — purple
	"hybrid": Color("#448888"),         # E5 — teal-blue
}

var _peer_rows: Dictionary = {}  # peer_id -> HBoxContainer


func _ready() -> void:
	var oasis_mqtt = get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_message)


func _on_message(topic: String, payload: String) -> void:
	if not topic.ends_with("/status"):
		return
	var msg = OCPMessage.parse(payload)
	if msg == null:
		return
	var device = OCPMessage.get_device(msg)
	var status: String = str(msg.get("status", "unknown"))
	var embodiment = OCPMessage.get_embodiment_type(msg)
	_update_peer_row(device, status, embodiment)


func _update_peer_row(peer_id: String, status: String, embodiment: String) -> void:
	if not _peer_rows.has(peer_id):
		_create_peer_row(peer_id)
	var row: HBoxContainer = _peer_rows[peer_id]
	# Update status indicator
	var indicator: Label = row.get_node("StatusIndicator")
<<<<<<< HEAD
	indicator.text = "��" if status == "online" else "○"
	indicator.add_theme_color_override("font_color",
		ArcReactorDark.STATUS_SUCCESS if status == "online" else ArcReactorDark.STATUS_ERROR
	)
	# Update embodiment badge
	var badge = row.get_node("EmbodimentBadge")
	if badge is Label:
		var type_short = _embodiment_short(embodiment)
		badge.text = type_short
		badge.add_theme_color_override("font_color",
			EMBODIMENT_COLORS.get(embodiment, ArcReactorDark.TEXT_TERTIARY)
		)
=======
	indicator.text = "●" if status == "online" else "○"
	indicator.add_theme_color_override("font_color",
		Color("#00CC66") if status == "online" else Color("#CC3333")
	)
	# Update embodiment badge
	var badge: Label = row.get_node("EmbodimentBadge")
	var type_short = _embodiment_short(embodiment)
	badge.text = type_short
	badge.add_theme_color_override("font_color",
		EMBODIMENT_COLORS.get(embodiment, Color("#888888"))
	)
>>>>>>> 9d2ddee (feat(godot): Add OCP plugin scaffold, validated in Godot 4.5)


func _create_peer_row(peer_id: String) -> void:
	var row = HBoxContainer.new()
	row.name = "Peer_%s" % peer_id.replace("-", "_")

	var indicator = Label.new()
	indicator.name = "StatusIndicator"
	indicator.text = "●"
	indicator.custom_minimum_size.x = 20
	row.add_child(indicator)

	var name_label = Label.new()
	name_label.name = "PeerName"
	name_label.text = peer_id
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	row.add_child(name_label)

	var badge = Label.new()
	badge.name = "EmbodimentBadge"
	badge.text = "E3"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_size_override("font_size", 11)
	row.add_child(badge)

	peer_list.add_child(row)
	_peer_rows[peer_id] = row


func _embodiment_short(embodiment: String) -> String:
	match embodiment:
		"physical": return "E1"
		"remote_physical": return "E2"
		"digital": return "E3"
		"software": return "E4"
		"hybrid": return "E5"
		_: return "E?"
