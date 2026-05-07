## D.A.W.N. (Digital Assistant for Workflow Neural-inference) — Godot recreation.
##
## Phase 1 scope: header status, transcript with selection/copy, input field
## that publishes to dawn/cmd, response rendering from the dawn topic, online
## detection from dawn/status (LWT-aware).
##
## Phase 2+ stubs are present (telemetry rings, thinking blocks, plan
## orchestrator, tool execution entries) and consume dawn/events payloads
## when upstream begins publishing them. Until then they no-op cleanly.
extends Control

const ArcReactor = preload("res://resources/design_tokens.gd")
const MessageBubble = preload("res://scripts/message_bubble.gd")
const ThinkingBlockClass = preload("res://demos/dawn_ui/scripts/thinking_block.gd")
const ToolCallEntryClass = preload("res://demos/dawn_ui/scripts/tool_call_entry.gd")
const PlanOrchestratorBlockClass = preload("res://demos/dawn_ui/scripts/plan_orchestrator_block.gd")

@onready var status_dot: Label = $VBox/Header/StatusDot
@onready var status_label: Label = $VBox/Header/StatusLabel
@onready var connection_label: Label = $VBox/Header/ConnectionLabel
@onready var transcript_toolbar: HBoxContainer = $VBox/TranscriptToolbar
@onready var transcript_scroll: ScrollContainer = $VBox/TranscriptScroll
@onready var transcript_box: VBoxContainer = $VBox/TranscriptScroll/TranscriptBox
@onready var input_field: LineEdit = $VBox/InputRow/InputField
@onready var send_button: Button = $VBox/InputRow/SendButton
@onready var telemetry_rings = $VBox/TelemetryRings  # Phase 2 placeholder Control
@onready var llm_controls = $VBox/LLMControls         # Phase 4 LLM controls bar

var _mqtt: MQTTBridge = null
var _dawn_online: bool = false
var _copy_button: Button = null
var _clear_button: Button = null
# Phase 2+ telemetry state (empty until dawn/events lands or schema is defined)
var _last_metrics: Dictionary = {}
# Phase 3 — active thinking blocks keyed by orchestrator_id so streaming
# deltas land in the right block when several arrive interleaved.
var _thinking_blocks: Dictionary = {}
# Phase 3 — active tool entries keyed by call_id so tool_result lands on
# the matching entry even when multiple tools run interleaved.
var _tool_entries: Dictionary = {}
# Phase 3 — active plan blocks keyed by orchestrator_id so step updates
# reach the right plan even when multiple plans run interleaved.
var _plan_blocks: Dictionary = {}


func _ready() -> void:
	_style_header()
	_style_input()
	_install_transcript_toolbar()

	if send_button:
		send_button.pressed.connect(_on_send_pressed)
	if input_field:
		input_field.text_submitted.connect(_on_text_submitted)
		input_field.keep_editing_on_text_submit = true
		input_field.grab_focus.call_deferred()

	var oasis_mqtt := get_node_or_null("/root/OasisMQTT")
	if oasis_mqtt:
		_mqtt = oasis_mqtt.get_mqtt()
		oasis_mqtt.global_message.connect(_on_message)

	_update_status()


# ─── Header ───────────────────────────────────────────────────────────────

func _style_header() -> void:
	if status_dot:
		status_dot.text = "●"
		status_dot.add_theme_color_override("font_color", ArcReactor.STATUS_WARNING)
		status_dot.add_theme_font_size_override("font_size", ArcReactor.FONT_BODY)
	if status_label:
		status_label.text = "D.A.W.N."
		status_label.add_theme_color_override("font_color", ArcReactor.ARC_CORE)
		status_label.add_theme_font_size_override("font_size", ArcReactor.FONT_HEADING)
		var mono := _load_font(ArcReactor.FONT_MONO_PATH)
		if mono:
			status_label.add_theme_font_override("font", mono)
	if connection_label:
		connection_label.text = "WAITING"
		connection_label.add_theme_color_override("font_color", ArcReactor.TEXT_SECONDARY)
		connection_label.add_theme_font_size_override("font_size", ArcReactor.FONT_SMALL)


func _update_status() -> void:
	if status_dot:
		status_dot.add_theme_color_override("font_color",
			ArcReactor.STATUS_SUCCESS if _dawn_online else ArcReactor.STATUS_WARNING)
	if connection_label:
		connection_label.text = "ONLINE" if _dawn_online else "WAITING"


# ─── Input ────────────────────────────────────────────────────────────────

func _style_input() -> void:
	if input_field:
		input_field.placeholder_text = "Ask D.A.W.N..."
		input_field.add_theme_color_override("font_color", ArcReactor.TEXT_PRIMARY)
	if send_button:
		send_button.text = "Send"


func _on_send_pressed() -> void:
	if input_field:
		_on_text_submitted(input_field.text)


func _on_text_submitted(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return

	# Show the user message immediately.
	_append_bubble(MessageBubble.Role.USER, "You", trimmed)

	# Publish v1.4 OCP command: dawn/cmd, action=process_intent.
	if _mqtt:
		var msg := {
			"device": "godot-dawn-ui",
			"msg_type": "command",
			"action": "process_intent",
			"parameters": {"text": trimmed},
			"timestamp": OCPMessage.now_ms(),
		}
		_mqtt.publish(OCPMessage.cmd_topic("dawn"), JSON.stringify(msg))

	if input_field:
		input_field.clear()
		input_field.grab_focus()


# ─── Transcript ───────────────────────────────────────────────────────────

func _append_bubble(role: int, sender: String, text: String) -> void:
	if transcript_box == null:
		return
	var bubble: MessageBubble = MessageBubble.create(role, sender, text)
	transcript_box.add_child(bubble)
	# Auto-scroll: defer one frame so layout settles before we move the bar.
	_scroll_to_bottom.call_deferred()


func _scroll_to_bottom() -> void:
	if transcript_scroll == null:
		return
	var bar := transcript_scroll.get_v_scroll_bar()
	if bar:
		bar.value = bar.max_value


func _install_transcript_toolbar() -> void:
	if transcript_toolbar == null:
		return
	_copy_button = Button.new()
	_copy_button.text = "Copy"
	_copy_button.tooltip_text = "Copy entire transcript to clipboard"
	_copy_button.pressed.connect(_on_copy_transcript)
	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.tooltip_text = "Clear the transcript"
	_clear_button.pressed.connect(_on_clear_transcript)
	transcript_toolbar.add_child(_copy_button)
	transcript_toolbar.add_child(_clear_button)


func _on_copy_transcript() -> void:
	var lines: Array[String] = []
	for child in transcript_box.get_children():
		if child is MessageBubble:
			# MessageBubble doesn't expose its text directly; pull from children.
			for grandchild in child.get_children():
				if grandchild is VBoxContainer:
					var role_text := ""
					var msg_text := ""
					for label in grandchild.get_children():
						if label is Label:
							role_text = label.text
						elif label is RichTextLabel:
							msg_text = label.get_parsed_text()
					if not msg_text.is_empty():
						lines.append("%s: %s" % [role_text, msg_text])
	var blob := "\n".join(lines)
	if not blob.is_empty():
		DisplayServer.clipboard_set(blob)
		if _copy_button:
			_copy_button.text = "Copied!"
			await get_tree().create_timer(1.0).timeout
			if is_instance_valid(_copy_button):
				_copy_button.text = "Copy"


func _on_clear_transcript() -> void:
	if transcript_box == null:
		return
	for child in transcript_box.get_children():
		child.queue_free()


# ─── MQTT ─────────────────────────────────────────────────────────────────

func _on_message(topic: String, payload: String) -> void:
	if topic == "dawn/status":
		_handle_status(payload)
	elif topic == "dawn":
		_handle_dawn_response(payload)
	elif topic == "dawn/events":
		_handle_dawn_event(payload)


func _handle_status(payload: String) -> void:
	var msg = OCPMessage.parse(payload)
	if msg == null:
		return
	var status: String = str(msg.get("status", ""))
	var was_online := _dawn_online
	_dawn_online = status == "online"
	if _dawn_online != was_online:
		_update_status()


func _handle_dawn_response(payload: String) -> void:
	var msg = OCPMessage.parse(payload)
	if msg == null:
		return
	# Skip our own outbound commands echoed back via wildcard subscriptions.
	if msg.get("device", "") == "godot-dawn-ui":
		return
	# Mock format uses "value"; future server format may use "text" or "response".
	var text: String = msg.get("value", msg.get("text", msg.get("response", "")))
	if text.is_empty():
		return
	var sender: String = msg.get("speaker", "D.A.W.N.")
	_append_bubble(MessageBubble.Role.ASSISTANT, sender, text)


## Phase 2+ entry point. Routes dawn/events payloads to the right stub. When
## upstream begins publishing thinking/tool/plan/metrics events, fill in the
## handlers; until then the events log to the scratch console for visibility.
func _handle_dawn_event(payload: String) -> void:
	var msg = OCPMessage.parse(payload)
	if msg == null:
		return
	var event: String = str(msg.get("event", ""))
	match event:
		"metrics_update":
			_on_metrics_event(msg)
		"thinking_start", "thinking_delta", "thinking_end":
			_on_thinking_event(event, msg)
		"tool_call", "tool_result":
			_on_tool_event(event, msg)
		"plan_start", "plan_step_update", "plan_end":
			_on_plan_event(event, msg)
		"config_update":
			if llm_controls and llm_controls.has_method("apply_config_update"):
				llm_controls.apply_config_update(msg)
		_:
			# Unknown event — log to stdout for now, not the transcript.
			print("[DawnUI] unrecognized dawn/events: %s" % event)


# ─── Phase 2 stubs (telemetry rings) ──────────────────────────────────────

func _on_metrics_event(msg: Dictionary) -> void:
	_last_metrics = msg
	if telemetry_rings == null:
		return
	# Pass -1.0 for any missing key so the ring keeps its prior value rather
	# than dropping back into the no-data placeholder.
	telemetry_rings.set_metrics(
		float(msg.get("ttft_ms", -1.0)),
		float(msg.get("token_rate", -1.0)),
		float(msg.get("context_percent", -1.0))
	)


# ─── Phase 3 stubs (thinking, tool, plan blocks) ──────────────────────────

func _on_thinking_event(event: String, msg: Dictionary) -> void:
	var orch_id: String = str(msg.get("orchestrator_id", "default"))
	match event:
		"thinking_start":
			# Spawn a new thinking block in the transcript and remember it.
			var block: ThinkingBlockClass = ThinkingBlockClass.new()
			if transcript_box:
				transcript_box.add_child(block)
			block.start(orch_id, str(msg.get("provider", "")))
			_thinking_blocks[orch_id] = block
			_scroll_to_bottom.call_deferred()
		"thinking_delta":
			var existing = _thinking_blocks.get(orch_id)
			if existing and is_instance_valid(existing):
				existing.append_delta(str(msg.get("delta", "")))
				_scroll_to_bottom.call_deferred()
		"thinking_end":
			var ending = _thinking_blocks.get(orch_id)
			if ending and is_instance_valid(ending):
				ending.finish(int(msg.get("duration_ms", 0)))
			_thinking_blocks.erase(orch_id)


func _on_tool_event(event: String, msg: Dictionary) -> void:
	var call_id: String = str(msg.get("call_id", ""))
	if call_id.is_empty():
		return
	match event:
		"tool_call":
			var entry: ToolCallEntryClass = ToolCallEntryClass.new()
			if transcript_box:
				transcript_box.add_child(entry)
			var args: Dictionary = msg.get("arguments", {})
			entry.start(call_id, str(msg.get("tool_name", "tool")), args)
			_tool_entries[call_id] = entry
			_scroll_to_bottom.call_deferred()
		"tool_result":
			var existing = _tool_entries.get(call_id)
			if existing and is_instance_valid(existing):
				existing.finish(msg.get("result", null),
					int(msg.get("duration_ms", 0)))
			_tool_entries.erase(call_id)


func _on_plan_event(event: String, msg: Dictionary) -> void:
	var orch_id: String = str(msg.get("orchestrator_id", ""))
	if orch_id.is_empty():
		return
	match event:
		"plan_start":
			var block: PlanOrchestratorBlockClass = PlanOrchestratorBlockClass.new()
			if transcript_box:
				transcript_box.add_child(block)
			block.start(orch_id, msg.get("steps", []))
			_plan_blocks[orch_id] = block
			_scroll_to_bottom.call_deferred()
		"plan_step_update":
			var existing = _plan_blocks.get(orch_id)
			if existing and is_instance_valid(existing):
				existing.update_step(
					int(msg.get("step_index", -1)),
					str(msg.get("status", "running")),
					str(msg.get("note", ""))
				)
		"plan_end":
			var ending = _plan_blocks.get(orch_id)
			if ending and is_instance_valid(ending):
				ending.finish(
					str(msg.get("summary", "")),
					int(msg.get("duration_ms", 0))
				)
			_plan_blocks.erase(orch_id)


static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return null
