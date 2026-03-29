## MQTT client over WebSocket for Godot 4.5.
##
## Connects to an MQTT broker's WebSocket listener (e.g., Mosquitto on port 9001).
## Implements enough of MQTT v3.1.1 over WebSocket to support OCP message flow:
## CONNECT, CONNACK, SUBSCRIBE, SUBACK, PUBLISH, PINGREQ, PINGRESP, DISCONNECT.
##
## Usage:
##   var mqtt = MQTTBridge.new()
##   add_child(mqtt)
##   mqtt.connect_to_broker("localhost", 9001)
##   mqtt.subscribe("oasis/#")
##   mqtt.message_received.connect(_on_message)
##
## For production use, consider replacing with godot-mqtt addon from AssetLib.
class_name MQTTBridge
extends Node

signal connected()
signal disconnected()
signal message_received(topic: String, payload: String)
signal connection_failed(reason: String)

enum State { DISCONNECTED, CONNECTING, AWAITING_CONNACK, CONNECTED, CLOSING }

@export var client_id: String = "godot-oasis-%d" % randi()
@export var keep_alive_sec: int = 60
@export var auto_reconnect: bool = true
@export var reconnect_delay_sec: float = 3.0

var _ws: WebSocketPeer = WebSocketPeer.new()
var _state: State = State.DISCONNECTED
var _broker_url: String = ""
var _subscriptions: PackedStringArray = []
var _ping_timer: float = 0.0
var _reconnect_timer: float = 0.0
var _packet_id: int = 1

# --- Public API ---

func connect_to_broker(host: String = "localhost", port: int = 9001) -> Error:
	_broker_url = "ws://%s:%d" % [host, port]
	_state = State.CONNECTING
	# MQTT over WebSocket requires the "mqtt" subprotocol
	_ws.supported_protocols = PackedStringArray(["mqtt"])
	var tls = TLSOptions.client_unsafe() if _broker_url.begins_with("wss://") else null
	print("[MQTTBridge] Connecting to %s..." % _broker_url)
	var err := _ws.connect_to_url(_broker_url, tls)
	if err != OK:
		_state = State.DISCONNECTED
		connection_failed.emit("WebSocket connect failed: %s" % error_string(err))
	return err


func subscribe(topic: String, qos: int = 0) -> void:
	if not topic in _subscriptions:
		_subscriptions.append(topic)
	if _state == State.CONNECTED:
		_send_subscribe(topic, qos)


func publish(topic: String, payload: String, retain: bool = false) -> void:
	if _state == State.CONNECTED:
		_send_publish(topic, payload, retain)


func disconnect_from_broker() -> void:
	if _state == State.CONNECTED:
		_send_disconnect()
		_ws.close()
	_state = State.DISCONNECTED
	disconnected.emit()


func get_connection_state() -> State:
	return _state

# --- Lifecycle ---

func _process(delta: float) -> void:
	_ws.poll()

	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if _state == State.CONNECTING:
				print("[MQTTBridge] WebSocket open, sending MQTT CONNECT...")
				_state = State.AWAITING_CONNACK
				_send_connect()
			# Read incoming packets
			while _ws.get_available_packet_count() > 0:
				var packet := _ws.get_packet()
				_parse_mqtt_packet(packet)
			# Keep-alive ping
			_ping_timer += delta
			if _ping_timer >= keep_alive_sec * 0.8:
				_send_pingreq()
				_ping_timer = 0.0

		WebSocketPeer.STATE_CLOSING:
			pass  # Keep polling for clean close

		WebSocketPeer.STATE_CLOSED:
			if _state != State.DISCONNECTED:
				var code = _ws.get_close_code()
				var reason = _ws.get_close_reason()
				print("[MQTTBridge] WebSocket closed (code=%d, reason=%s)" % [code, reason])
				_state = State.DISCONNECTED
				disconnected.emit()
				if auto_reconnect:
					_reconnect_timer = reconnect_delay_sec

	# Auto-reconnect
	if _state == State.DISCONNECTED and auto_reconnect and _reconnect_timer > 0:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0:
			# Parse host and port from stored URL (ws://host:port)
			var url_body = _broker_url.get_slice("://", 1)  # "host:port"
			var host = url_body.get_slice(":", 0)
			var port = url_body.get_slice(":", 1).to_int()
			if port > 0:
				print("[MQTTBridge] Reconnecting to %s:%d..." % [host, port])
				connect_to_broker.call_deferred(host, port)

# --- MQTT Packet Construction ---
# Implements minimal MQTT v3.1.1 binary protocol over WebSocket.
# Reference: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html

func _send_connect() -> void:
	var packet := PackedByteArray()
	# Variable header
	var var_header := PackedByteArray()
	# Protocol Name "MQTT"
	var_header.append_array(_encode_utf8_string("MQTT"))
	# Protocol Level (4 = v3.1.1)
	var_header.append(4)
	# Connect Flags: Clean Session
	var_header.append(0x02)
	# Keep Alive
	var_header.append((keep_alive_sec >> 8) & 0xFF)
	var_header.append(keep_alive_sec & 0xFF)
	# Payload: Client ID
	var payload := _encode_utf8_string(client_id)
	# Fixed header: CONNECT (0x10)
	var remaining := var_header.size() + payload.size()
	packet.append(0x10)
	packet.append_array(_encode_remaining_length(remaining))
	packet.append_array(var_header)
	packet.append_array(payload)
	_ws.send(packet)


func _send_subscribe(topic: String, qos: int = 0) -> void:
	var packet := PackedByteArray()
	# Variable header: Packet ID
	var var_header := PackedByteArray()
	var_header.append((_packet_id >> 8) & 0xFF)
	var_header.append(_packet_id & 0xFF)
	_packet_id = (_packet_id % 65535) + 1
	# Payload: Topic Filter + QoS
	var payload := _encode_utf8_string(topic)
	payload.append(qos)
	# Fixed header: SUBSCRIBE (0x82 — must have bit 1 set)
	var remaining := var_header.size() + payload.size()
	packet.append(0x82)
	packet.append_array(_encode_remaining_length(remaining))
	packet.append_array(var_header)
	packet.append_array(payload)
	_ws.send(packet)


func _send_publish(topic: String, payload_str: String, retain: bool = false) -> void:
	var packet := PackedByteArray()
	# Variable header: Topic
	var var_header := _encode_utf8_string(topic)
	# Payload
	var payload := payload_str.to_utf8_buffer()
	# Fixed header: PUBLISH (0x30, retain bit 0)
	var flags := 0x30
	if retain:
		flags |= 0x01
	var remaining := var_header.size() + payload.size()
	packet.append(flags)
	packet.append_array(_encode_remaining_length(remaining))
	packet.append_array(var_header)
	packet.append_array(payload)
	_ws.send(packet)


func _send_pingreq() -> void:
	_ws.send(PackedByteArray([0xC0, 0x00]))


func _send_disconnect() -> void:
	_ws.send(PackedByteArray([0xE0, 0x00]))

# --- MQTT Packet Parsing ---

func _parse_mqtt_packet(data: PackedByteArray) -> void:
	if data.size() < 2:
		return
	var packet_type := (data[0] >> 4) & 0x0F
	match packet_type:
		2:  # CONNACK
			if data.size() >= 4 and data[3] == 0:
				_state = State.CONNECTED
				_ping_timer = 0.0
				connected.emit()
				# Re-subscribe to all topics
				for topic in _subscriptions:
					_send_subscribe(topic)
			else:
				var code := data[3] if data.size() >= 4 else -1
				connection_failed.emit("CONNACK rejected: code %d" % code)
		3:  # PUBLISH
			_handle_publish(data)
		9:  # SUBACK
			pass  # Subscription acknowledged
		13:  # PINGRESP
			pass  # Keep-alive acknowledged


func _handle_publish(data: PackedByteArray) -> void:
	# Decode remaining length
	var idx := 1
	var remaining := 0
	var multiplier := 1
	while idx < data.size():
		var encoded_byte := data[idx]
		remaining += (encoded_byte & 127) * multiplier
		multiplier *= 128
		idx += 1
		if (encoded_byte & 128) == 0:
			break

	# Topic length (2 bytes, MSB first)
	if idx + 2 > data.size():
		return
	var topic_len := (data[idx] << 8) | data[idx + 1]
	idx += 2

	# Topic string
	if idx + topic_len > data.size():
		return
	var topic := data.slice(idx, idx + topic_len).get_string_from_utf8()
	idx += topic_len

	# QoS check — if QoS > 0, skip packet ID (2 bytes)
	var qos := (data[0] >> 1) & 0x03
	if qos > 0:
		idx += 2

	# Payload (rest of packet)
	var payload := data.slice(idx).get_string_from_utf8()
	message_received.emit(topic, payload)

# --- Encoding Helpers ---

func _encode_utf8_string(s: String) -> PackedByteArray:
	var buf := s.to_utf8_buffer()
	var result := PackedByteArray()
	result.append((buf.size() >> 8) & 0xFF)
	result.append(buf.size() & 0xFF)
	result.append_array(buf)
	return result


func _encode_remaining_length(length: int) -> PackedByteArray:
	var result := PackedByteArray()
	while true:
		var encoded_byte := length % 128
		length = length / 128
		if length > 0:
			encoded_byte |= 128
		result.append(encoded_byte)
		if length <= 0:
			break
	return result
