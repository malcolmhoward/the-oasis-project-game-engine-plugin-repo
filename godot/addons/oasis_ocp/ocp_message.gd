## OCP (O.A.S.I.S. Communications Protocol) message builder and parser.
##
## Constructs and parses JSON messages conforming to the OCP v1.4 schema,
## including the embodiment extension from ADR-0003 Amendment 5.
##
## v1.4 alignment: timestamps are Unix milliseconds (was seconds in v1.0/v1.3).
## Use OCPMessage.now_ms() for any new timestamp value.
class_name OCPMessage
extends RefCounted

## Returns the current time as Unix milliseconds (per OCP v1.4).
static func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

# --- Embodiment Types (ADR-0003 Amendment 5) ---
enum EmbodimentType { E1_PHYSICAL, E2_REMOTE, E3_DIGITAL, E4_SOFTWARE, E5_HYBRID }

# --- Message Types ---
enum MsgType { STATUS, COMMAND, DISCOVERY, EVENT, RESPONSE }

static var _embodiment_labels := {
	EmbodimentType.E1_PHYSICAL: "physical",
	EmbodimentType.E2_REMOTE: "remote_physical",
	EmbodimentType.E3_DIGITAL: "digital",
	EmbodimentType.E4_SOFTWARE: "software",
	EmbodimentType.E5_HYBRID: "hybrid",
}

static var _msg_type_labels := {
	MsgType.STATUS: "status",
	MsgType.COMMAND: "command",
	MsgType.DISCOVERY: "discovery",
	MsgType.EVENT: "event",
	MsgType.RESPONSE: "response",
}

# --- Builder Functions ---

## Build a status message with optional embodiment block.
static func build_status(
	device: String,
	status: String = "online",
	version: String = "0.1.0",
	capabilities: PackedStringArray = [],
	embodiment_type: EmbodimentType = EmbodimentType.E3_DIGITAL,
	simulated_capabilities: PackedStringArray = [],
	real_capabilities: PackedStringArray = []
) -> Dictionary:
	var msg := {
		"device": device,
		"msg_type": "status",
		"status": status,
		"timestamp": now_ms(),
		"version": version,
		"capabilities": Array(capabilities),
	}
	# Add embodiment block (E1 peers may omit for backward compat)
	if embodiment_type != EmbodimentType.E1_PHYSICAL:
		msg["embodiment"] = {
			"type": _embodiment_labels[embodiment_type],
			"label": _embodiment_labels[embodiment_type],
			"simulated_capabilities": Array(simulated_capabilities),
			"real_capabilities": Array(real_capabilities),
		}
	return msg


## Build a command message.
static func build_command(
	device: String,
	action: String,
	parameters: Dictionary = {}
) -> Dictionary:
	return {
		"device": device,
		"msg_type": "command",
		"action": action,
		"parameters": parameters,
		"timestamp": now_ms(),
	}


## Build a discovery message for simulated peers (echo/discovery/simulates).
static func build_discovery(
	peer_id: String,
	component: String,
	embodiment: String = "software",
	capabilities: PackedStringArray = []
) -> Dictionary:
	return {
		"peer_id": peer_id,
		"component": component,
		"embodiment": embodiment,
		"capabilities": Array(capabilities),
		"timestamp": now_ms(),
	}


## Build an inhabitation event message.
static func build_inhabit_event(
	peer_id: String,
	operator_session: String,
	mode: String = "full_control"
) -> Dictionary:
	return {
		"device": peer_id,
		"msg_type": "event",
		"event": "inhabit",
		"timestamp": now_ms(),
		"operator_session": operator_session,
		"mode": mode,
	}


## Build a release event message.
static func build_release_event(peer_id: String) -> Dictionary:
	return {
		"device": peer_id,
		"msg_type": "event",
		"event": "release",
		"timestamp": now_ms(),
	}


# --- Parser Functions ---

## Parse a JSON string into a Dictionary. Returns null on failure.
static func parse(json_string: String) -> Variant:
	var result := JSON.parse_string(json_string)
	if result == null:
		push_warning("OCPMessage: Failed to parse JSON: %s" % json_string.left(100))
	return result


## Serialize a Dictionary to JSON string.
static func serialize(msg: Dictionary) -> String:
	return JSON.stringify(msg)


## Extract the message type from a parsed OCP message.
static func get_msg_type(msg: Dictionary) -> String:
	return msg.get("msg_type", "unknown")


## Extract the device/peer ID from a parsed OCP message.
static func get_device(msg: Dictionary) -> String:
	return msg.get("device", msg.get("peer_id", "unknown"))


## Extract embodiment type from a parsed OCP message.
## Handles both formats: flat string ("software") and dictionary ({"type": "E4"})
static func get_embodiment_type(msg: Dictionary) -> String:
	var embodiment = msg.get("embodiment", "physical")
	if embodiment is Dictionary:
		return embodiment.get("type", "physical")
	return str(embodiment)  # Flat string format from current E.C.H.O. implementation


## Construct the OCP topic for a given component and message type.
## Examples: oasis/mirage/status, oasis/dawn/command, echo/discovery/simulates
static func topic_for(component: String, msg_type: String) -> String:
	return "oasis/%s/%s" % [component, msg_type]


## Construct the discovery topic for simulated peers.
static func discovery_topic() -> String:
	return "echo/discovery/simulates"
