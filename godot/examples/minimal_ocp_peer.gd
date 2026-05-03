## Minimal O.A.S.I.S. OCP Peer Example
##
## The simplest possible OCP peer in Godot. Demonstrates:
## - Connecting to MQTT broker
## - Announcing as an E4 software-only peer
## - Publishing status heartbeat
## - Receiving and handling commands
##
## Run this scene standalone to see a peer appear on the OCP network.
## Any OCP subscriber (ECHO, DAWN, another Godot instance) will see it.
extends Node

var mqtt: MQTTBridge
var peer: OCPPeer


func _ready() -> void:
	# Create MQTT connection
	mqtt = MQTTBridge.new()
	mqtt.client_id = "godot-minimal-example"
	add_child(mqtt)
	mqtt.connect_to_broker("localhost", 9001)
	mqtt.connected.connect(_on_connected)

	# Create OCP peer
	peer = OCPPeer.new()
	peer.peer_id = "minimal-peer"
	peer.component_name = "example"
	peer.embodiment_type = OCPMessage.EmbodimentType.E4_SOFTWARE
	peer.capabilities = PackedStringArray(["demo", "example"])
	peer.version = "0.1.0"
	add_child(peer)

	# Listen for commands
	peer.command_received.connect(_on_command)
	peer.peer_status_changed.connect(_on_peer_status)


func _on_connected() -> void:
	print("Connected to MQTT broker!")
	print("This peer is now visible as 'minimal-peer' on the OCP network.")
	print("Try publishing a command:")
	print('  mosquitto_pub -t example/cmd -m \'{"device":"minimal-peer","msg_type":"command","action":"hello","parameters":{}}\'')


func _on_command(action: String, parameters: Dictionary) -> void:
	print("Received command: %s with params: %s" % [action, parameters])
	match action:
		"hello":
			print("  -> Hello from the minimal OCP peer!")
		"quit":
			get_tree().quit()
		_:
			print("  -> Unknown command: %s" % action)


func _on_peer_status(other_peer_id: String, status: String) -> void:
	print("Peer '%s' is now: %s" % [other_peer_id, status])
