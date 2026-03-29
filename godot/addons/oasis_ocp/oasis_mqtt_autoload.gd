## O.A.S.I.S. MQTT autoload singleton.
##
## Provides a global MQTTBridge instance that all OCPPeer nodes connect through.
## Configured via exported properties or command-line arguments.
##
## Autoload name: OasisMQTT (set in project.godot)
extends Node

@export var broker_host: String = "localhost"
@export var broker_port: int = 9001

var mqtt: MQTTBridge
var peer_registry: Dictionary = {}  # peer_id -> {status, embodiment, last_seen}

signal peer_discovered(peer_id: String, data: Dictionary)
signal peer_lost(peer_id: String)
signal global_message(topic: String, payload: String)


func _ready() -> void:
	# Apply Arc Reactor Dark theme globally
	var theme = ThemeBuilder.build_theme()
	get_tree().root.theme = theme

	# Set window background color
	RenderingServer.set_default_clear_color(ArcReactorDark.BG_DEEPEST)

	# Allow command-line override: --mqtt-host=x --mqtt-port=y
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--mqtt-host="):
			broker_host = arg.get_slice("=", 1)
		elif arg.begins_with("--mqtt-port="):
			broker_port = arg.get_slice("=", 1).to_int()

	mqtt = MQTTBridge.new()
	mqtt.client_id = "godot-oasis-main-%d" % randi()
	add_child(mqtt)

	mqtt.connected.connect(_on_connected)
	mqtt.disconnected.connect(_on_disconnected)
	mqtt.message_received.connect(_on_message)

	# Connect to broker
	mqtt.connect_to_broker(broker_host, broker_port)


func _on_connected() -> void:
	print("[OasisMQTT] Connected to %s:%d" % [broker_host, broker_port])
	# Subscribe to O.A.S.I.S. MQTT topics
	mqtt.subscribe("oasis/#")       # OCP peer status (oasis/<peer_id>/status)
	mqtt.subscribe("echo/#")        # Simulation discovery (echo/discovery/simulates)
	mqtt.subscribe("aura")          # A.U.R.A. sensor data (motion, GPS, environmental)
	mqtt.subscribe("stat")          # S.T.A.T. system metrics and battery
	mqtt.subscribe("hud/#")         # M.I.R.A.G.E. HUD status and discovery
	mqtt.subscribe("dawn")          # D.A.W.N. AI state and commands


func _on_disconnected() -> void:
	print("[OasisMQTT] Disconnected from broker")


func _on_message(topic: String, payload: String) -> void:
	global_message.emit(topic, payload)
	# Track peer status
	if topic.ends_with("/status"):
		var msg := OCPMessage.parse(payload)
		if msg != null:
			var device := OCPMessage.get_device(msg)
			var status: String = str(msg.get("status", "unknown"))
			var was_known := peer_registry.has(device)
			peer_registry[device] = {
				"status": status,
				"embodiment": OCPMessage.get_embodiment_type(msg),
				"capabilities": msg.get("capabilities", []),
				"last_seen": Time.get_unix_time_from_system(),
				"inhabited_by": msg.get("inhabited_by", ""),
			}
			if not was_known:
				peer_discovered.emit(device, peer_registry[device])
			if status == "offline":
				peer_lost.emit(device)


## Get a snapshot of all known peers.
func get_peers() -> Dictionary:
	return peer_registry.duplicate(true)


## Get the MQTTBridge for direct access.
func get_mqtt() -> MQTTBridge:
	return mqtt
