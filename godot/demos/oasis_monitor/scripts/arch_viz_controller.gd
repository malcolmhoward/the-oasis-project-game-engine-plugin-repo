## Architecture visualization panel.
##
## Renders the three-layer ECHO architecture (Device, Network, Platform)
## with live data from MQTT subscriptions. The Network layer includes
## animated message packets flowing between peer nodes.
extends PanelContainer

# --- Layer references ---
@onready var platform_layer: Control = $LayerStack/PlatformLayer
@onready var network_layer: Control = $LayerStack/NetworkLayer
@onready var device_layer: Control = $LayerStack/DeviceLayer

# --- Data display nodes ---
@onready var imu_label: Label = find_child("IMULabel", true, false)
@onready var gps_label: Label = find_child("GPSLabel", true, false)
@onready var env_label: Label = find_child("EnvLabel", true, false)
@onready var peers_label: Label = find_child("PeersLabel", true, false)
@onready var topic_label: Label = find_child("TopicLabel", true, false)
@onready var heartbeat_bar: ProgressBar = find_child("HeartbeatBar", true, false)
@onready var packet_canvas: Control = find_child("PacketCanvas", true, false)
@onready var llm_status: Label = find_child("LLMStatus", true, false)
@onready var ha_status: Label = find_child("HAStatus", true, false)
@onready var memory_status: Label = find_child("MemoryStatus", true, false)

# --- Network layer animation ---
var _peer_nodes: Dictionary = {}  # peer_id -> {position: Vector2, embodiment: String}
var _active_packets: Array[Dictionary] = []  # {from, to, color, progress, label}
var _featured_topic: String = ""
var _heartbeat_progress: float = 0.0

# --- Device layer state ---
var _sensor_data: Dictionary = {
	"imu": {"pitch": 0.0, "roll": 0.0, "heading": 0.0},
	"gps": {"latitude": 33.749, "longitude": -84.388, "altitude": 320.0},
	"env": {"temp": 22.4, "humidity": 45.0, "aqi": 42},
}

# --- Platform layer state ---
var _platform_services: Dictionary = {
	"llm_mock": {"active": false, "mode": "mock", "detail": "idle"},
	"ha_mock": {"active": false, "mode": "mock", "detail": "0 entities"},
	"memory_mock": {"active": false, "mode": "mock", "detail": "0 facts"},
}

# --- Color constants matching wireframe spec ---
const COLOR_PLATFORM := Color("#2D1B4E")
const COLOR_NETWORK := Color("#1B2E4E")
const COLOR_DEVICE := Color("#1B3D2E")
const COLOR_MSG_STATUS := Color("#4488CC")
const COLOR_MSG_COMMAND := Color("#CC8844")
const COLOR_MSG_RESPONSE := Color("#44CC88")
const COLOR_MSG_HEARTBEAT := Color("#666666")
const COLOR_ONLINE := Color("#00CC66")
const COLOR_OFFLINE := Color("#CC3333")
const COLOR_MOCK := Color("#CCAA00")


func _ready() -> void:
	var oasis_mqtt := get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		oasis_mqtt.global_message.connect(_on_mqtt_message)
		oasis_mqtt.peer_discovered.connect(_on_peer_discovered)


func _process(delta: float) -> void:
	# Animate heartbeat progress bar (30s cycle)
	_heartbeat_progress += delta / 30.0
	if _heartbeat_progress >= 1.0:
		_heartbeat_progress = 0.0
	# Animate message packets
	var to_remove: Array[int] = []
	for i in range(_active_packets.size()):
		_active_packets[i]["progress"] += delta * 2.0  # 0.5s transit time
		if _active_packets[i]["progress"] >= 1.0:
			to_remove.append(i)
	to_remove.reverse()
	for idx in to_remove:
		_active_packets.remove_at(idx)

	# --- Update Device layer display ---
	if imu_label:
		var imu = _sensor_data["imu"]
		imu_label.text = "IMU: H:%.1f P:%.1f R:%.1f" % [imu["heading"], imu["pitch"], imu["roll"]]
	if gps_label:
		var gps = _sensor_data["gps"]
		gps_label.text = "GPS: %.4f, %.4f alt:%.0f" % [gps["latitude"], gps["longitude"], gps["altitude"]]
	if env_label:
		var env = _sensor_data["env"]
		env_label.text = "ENV: %.1f°C %d%% AQI:%d" % [env["temp"], int(env["humidity"]), int(env["aqi"])]

	# --- Update Network layer display ---
	if peers_label:
		var online = 0
		for p in _peer_nodes.values():
			if p.get("status") == "online":
				online += 1
		var names = ", ".join(_peer_nodes.keys().map(func(k): return k.get_file() if k.contains("-") else k))
		if names.is_empty():
			peers_label.text = "Peers: waiting..."
		else:
			peers_label.text = "Peers (%d): %s" % [online, names]
	if topic_label:
		topic_label.text = "Last: %s" % _featured_topic.left(40) if not _featured_topic.is_empty() else "Last: —"
	if heartbeat_bar:
		heartbeat_bar.value = _heartbeat_progress

	# --- Update Platform layer display ---
	if llm_status:
		var llm = _platform_services["llm_mock"]
		var icon = "●" if llm["active"] else "○"
		llm_status.text = "%s LLM: %s" % [icon, llm["detail"]]
	if ha_status:
		var ha = _platform_services["ha_mock"]
		var icon = "●" if ha["active"] else "○"
		ha_status.text = "%s HA: %s" % [icon, ha["detail"]]
	if memory_status:
		var mem = _platform_services["memory_mock"]
		var icon = "●" if mem["active"] else "○"
		memory_status.text = "%s Memory: %s" % [icon, mem["detail"]]

	# Trigger redraw for packet canvas animations
	if packet_canvas:
		packet_canvas.queue_redraw()


func _on_mqtt_message(topic: String, payload: String) -> void:
	var msg: Dictionary = OCPMessage.parse(payload)
	if msg == null:
		return
	var msg_type: String = OCPMessage.get_msg_type(msg)
	var device: String = OCPMessage.get_device(msg)

	# Update featured topic
	_featured_topic = topic

	# Reset heartbeat on status messages
	if msg_type == "status":
		_heartbeat_progress = 0.0

	# Spawn animated packet in network layer
	var color := _color_for_msg_type(msg_type)
	_spawn_packet(device, msg_type, color)

	# Update device layer sensor data
	# Sensor topics: "aura" (motion/GPS/enviro), "stat" (system metrics/battery),
	# or legacy "oasis/sensors/..." format
	if topic == "aura" or topic == "stat" or topic.contains("/sensors/") or topic.contains("/status"):
		_update_sensor_data(msg)

	# Update platform layer service state
	_update_platform_state(topic, msg)


func _on_peer_discovered(peer_id: String, data: Dictionary) -> void:
	# Position new peer on the network visualization bus
	var count := _peer_nodes.size()
	var x_pos := 80.0 + count * 140.0
	_peer_nodes[peer_id] = {
		"position": Vector2(x_pos, 60.0),
		"embodiment": data.get("embodiment", "physical"),
		"status": data.get("status", "online"),
	}


func _spawn_packet(device: String, msg_type: String, color: Color) -> void:
	_active_packets.append({
		"from": device,
		"to": "bus",
		"color": color,
		"progress": 0.0,
		"label": msg_type.left(4),
	})
	# Cap active packets to prevent memory growth
	if _active_packets.size() > 20:
		_active_packets.remove_at(0)


func _update_sensor_data(msg: Dictionary) -> void:
	# IMU data
	if msg.has("heading"):
		_sensor_data["imu"]["heading"] = msg.get("heading", 0.0)
		_sensor_data["imu"]["pitch"] = msg.get("pitch", 0.0)
		_sensor_data["imu"]["roll"] = msg.get("roll", 0.0)
	# GPS data
	if msg.has("latitude"):
		_sensor_data["gps"]["latitude"] = msg.get("latitude", 0.0)
		_sensor_data["gps"]["longitude"] = msg.get("longitude", 0.0)
		_sensor_data["gps"]["altitude"] = msg.get("altitude", 0.0)
	# Environmental data
	if msg.has("temp"):
		_sensor_data["env"]["temp"] = msg.get("temp", 0.0)
		_sensor_data["env"]["humidity"] = msg.get("humidity", 0.0)
		_sensor_data["env"]["aqi"] = msg.get("air_quality", 0)


func _update_platform_state(topic: String, msg: Dictionary) -> void:
	if topic.contains("dawn") and msg.get("msg_type") == "status":
		_platform_services["llm_mock"]["active"] = true
		_platform_services["llm_mock"]["detail"] = "kw→tool"
	if topic.contains("ha_mock") or (msg.has("action") and msg["action"].begins_with("homeassistant")):
		_platform_services["ha_mock"]["active"] = true


func _color_for_msg_type(msg_type: String) -> Color:
	match msg_type:
		"status": return COLOR_MSG_STATUS
		"command": return COLOR_MSG_COMMAND
		"response": return COLOR_MSG_RESPONSE
		_: return COLOR_MSG_HEARTBEAT


## Returns current sensor data for external consumers (e.g., device layer labels).
func get_sensor_data() -> Dictionary:
	return _sensor_data


## Returns current platform service state.
func get_platform_state() -> Dictionary:
	return _platform_services


## Returns the current featured topic string.
func get_featured_topic() -> String:
	return _featured_topic


## Returns heartbeat progress (0.0 to 1.0).
func get_heartbeat_progress() -> float:
	return _heartbeat_progress


## Returns active peer nodes for network visualization.
func get_peer_nodes() -> Dictionary:
	return _peer_nodes


## Returns active animated packets.
func get_active_packets() -> Array[Dictionary]:
	return _active_packets
