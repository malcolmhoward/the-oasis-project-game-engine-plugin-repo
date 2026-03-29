## OCP Peer component. Attach to any Node to make it a first-class OCP network peer.
##
## Handles: peer announcement, status heartbeat, discovery publication,
## command subscription, and graceful offline on exit.
##
## Usage:
##   1. Add as child of any Node (or use custom type "OCPPeer" in editor)
##   2. Set peer_id, component_name, embodiment_type, capabilities
##   3. The node will automatically announce itself and maintain heartbeat
class_name OCPPeer
extends Node

signal command_received(action: String, parameters: Dictionary)
signal inhabit_requested(operator_session: String, mode: String)
signal release_requested()
signal peer_status_changed(peer_id: String, status: String)

@export var peer_id: String = "godot-peer"
@export var component_name: String = "godot"
@export var embodiment_type: OCPMessage.EmbodimentType = OCPMessage.EmbodimentType.E3_DIGITAL
@export var capabilities: PackedStringArray = []
@export var simulated_capabilities: PackedStringArray = []
@export var real_capabilities: PackedStringArray = []
@export var heartbeat_interval_sec: float = 30.0
@export var version: String = "0.1.0"

## Optional: set to a peer_id if this peer simulates another (ECHO use case)
@export var simulates_peer: String = ""

## Optional: operator session ID when this peer is inhabited
var inhabited_by: String = ""

var _heartbeat_timer: float = 0.0
var _mqtt: MQTTBridge = null
var _is_announced: bool = false


func _ready() -> void:
	# Find the MQTT bridge — either the autoload singleton or a sibling node
	_mqtt = _find_mqtt_bridge()
	if _mqtt == null:
		push_warning("OCPPeer '%s': No MQTTBridge found. Peer will not connect." % peer_id)
		return
	# Wait for connection before announcing
	if _mqtt.get_connection_state() == MQTTBridge.State.CONNECTED:
		_announce()
	_mqtt.connected.connect(_on_mqtt_connected)
	_mqtt.message_received.connect(_on_mqtt_message)


func _process(delta: float) -> void:
	if not _is_announced:
		return
	_heartbeat_timer += delta
	if _heartbeat_timer >= heartbeat_interval_sec:
		_publish_status("online")
		_heartbeat_timer = 0.0


func _exit_tree() -> void:
	if _is_announced and _mqtt != null:
		_publish_status("offline")


# --- Public API ---

## Publish a command to another peer.
func send_command(target_device: String, action: String, params: Dictionary = {}) -> void:
	if _mqtt == null:
		return
	var msg := OCPMessage.build_command(target_device, action, params)
	_mqtt.publish(
		OCPMessage.topic_for(target_device, "command"),
		OCPMessage.serialize(msg)
	)


## Update the peer's status (e.g., "online", "busy", "error").
func set_status(status: String) -> void:
	_publish_status(status)


## Set the inhabited_by field and publish an inhabit event.
func inhabit(operator_session: String, mode: String = "full_control") -> void:
	inhabited_by = operator_session
	if _mqtt:
		var event := OCPMessage.build_inhabit_event(peer_id, operator_session, mode)
		_mqtt.publish("oasis/%s" % peer_id, OCPMessage.serialize(event))


## Clear the inhabited_by field and publish a release event.
func release() -> void:
	inhabited_by = ""
	if _mqtt:
		var event := OCPMessage.build_release_event(peer_id)
		_mqtt.publish("oasis/%s" % peer_id, OCPMessage.serialize(event))


# --- Internal ---

func _find_mqtt_bridge() -> MQTTBridge:
	# Try autoload first
	if has_node("/root/OasisMQTT"):
		var autoload := get_node("/root/OasisMQTT")
		if autoload is MQTTBridge:
			return autoload
		# Autoload might be a wrapper — check children
		for child in autoload.get_children():
			if child is MQTTBridge:
				return child
	# Walk up the tree looking for a MQTTBridge sibling or ancestor
	var node := get_parent()
	while node != null:
		for child in node.get_children():
			if child is MQTTBridge:
				return child
		node = node.get_parent()
	return null


func _on_mqtt_connected() -> void:
	_announce()


func _announce() -> void:
	# Subscribe to this peer's command topic
	_mqtt.subscribe(OCPMessage.topic_for(component_name, "command"))
	_mqtt.subscribe("oasis/%s" % peer_id)
	# Subscribe to all status for peer awareness
	_mqtt.subscribe("oasis/+/status")
	# Publish initial status
	_publish_status("online")
	# Publish discovery if simulating another peer
	if not simulates_peer.is_empty():
		var discovery := OCPMessage.build_discovery(
			peer_id, component_name, "software", capabilities
		)
		_mqtt.publish(OCPMessage.discovery_topic(), OCPMessage.serialize(discovery))
	_is_announced = true
	_heartbeat_timer = 0.0


func _publish_status(status: String) -> void:
	if _mqtt == null:
		return
	var msg := OCPMessage.build_status(
		peer_id, status, version, capabilities,
		embodiment_type, simulated_capabilities, real_capabilities
	)
	if not inhabited_by.is_empty():
		msg["inhabited_by"] = inhabited_by
	_mqtt.publish(
		OCPMessage.topic_for(component_name, "status"),
		OCPMessage.serialize(msg),
		true  # Retained — last status visible to new subscribers
	)


func _on_mqtt_message(topic: String, payload: String) -> void:
	var msg := OCPMessage.parse(payload)
	if msg == null:
		return
	var msg_type := OCPMessage.get_msg_type(msg)
	var device := OCPMessage.get_device(msg)

	# Command addressed to this peer
	if msg_type == "command" and device == peer_id:
		command_received.emit(
			msg.get("action", ""),
			msg.get("parameters", {})
		)

	# Inhabitation event addressed to this peer
	if msg_type == "event" and device == peer_id:
		match msg.get("event", ""):
			"inhabit":
				inhabited_by = msg.get("operator_session", "")
				inhabit_requested.emit(inhabited_by, msg.get("mode", "full_control"))
			"release":
				inhabited_by = ""
				release_requested.emit()

	# Status from other peers (for awareness)
	if msg_type == "status" and device != peer_id:
		peer_status_changed.emit(device, msg.get("status", "unknown"))
