## Streaming chat backend for a local llama.cpp `llama-server` (OpenAI-compatible API).
##
## Talks to the server directly over HTTP, so no DAWN daemon or MQTT broker is needed:
##   POST /v1/chat/completions (stream: true)  — the reply, token by token (server-sent events)
##   GET  /health                               — online/offline, polled while idle
##   GET  /props                                — context size, for the context ring
##
## Keeps the conversation history itself (llama-server is stateless per request). Runs in the editor
## (@tool) and at runtime alike; it polls its HTTPClient from _process, so it must be in the tree.
@tool
extends Node

signal online_changed(online: bool)
signal reply_started()
signal reply_delta(text: String)
signal reasoning_delta(text: String)
signal reply_finished(full_text: String, metrics: Dictionary)
signal reply_failed(error: String)

const HEALTH_INTERVAL_S := 5.0
const CONNECT_TIMEOUT_S := 10.0

var server_url: String = "http://127.0.0.1:8080"
var api_key: String = ""
var system_prompt: String = ""

var _messages: Array = []          # [{role, content}], without the system prompt
var _online := false
var _n_ctx := 0

var _client: HTTPClient = null
var _state := ""                   # "", "connecting", "requesting", "body"
var _state_started_ms := 0
var _body := PackedByteArray()
var _pending_body := ""
var _reply := ""
var _metrics: Dictionary = {}
var _first_token_ms := 0
var _sent_ms := 0

var _health: HTTPRequest = null
var _props: HTTPRequest = null
var _health_timer := 0.0


func _ready() -> void:
	_health = HTTPRequest.new()
	_health.timeout = 3.0
	add_child(_health)
	_health.request_completed.connect(_on_health_completed)
	_props = HTTPRequest.new()
	_props.timeout = 3.0
	add_child(_props)
	_props.request_completed.connect(_on_props_completed)
	_poll_health()


func configure(url: String, key: String, prompt: String) -> void:
	var changed := url.strip_edges() != server_url
	server_url = url.strip_edges().trim_suffix("/")
	api_key = key.strip_edges()
	system_prompt = prompt
	if changed:
		_n_ctx = 0
		# Drop checks still pending against the old URL, so the new one is probed now.
		if _health:
			_health.cancel_request()
			_props.cancel_request()
		_poll_health()


func is_online() -> bool:
	return _online


func is_busy() -> bool:
	return _state != ""


## Replace the history, e.g. when the user switches to a past conversation.
## `entries` uses the history sidebar's format: [{role: "user"|"assistant", text}].
func reset(entries: Array = []) -> void:
	cancel()
	_messages.clear()
	for e in entries:
		var role := str(e.get("role", ""))
		if role in ["user", "assistant"] and not str(e.get("text", "")).is_empty():
			_messages.append({"role": role, "content": str(e.get("text", ""))})


func send(text: String) -> void:
	if is_busy():
		reply_failed.emit("still answering the previous message")
		return
	var parsed := _parse_url(server_url)
	if parsed.is_empty():
		reply_failed.emit("bad server URL: %s" % server_url)
		return
	_messages.append({"role": "user", "content": text})
	_client = HTTPClient.new()
	var err := _client.connect_to_host(parsed.host, parsed.port,
		TLSOptions.client() if parsed.tls else null)
	if err != OK:
		_fail("cannot connect to %s (error %d)" % [server_url, err])
		return
	_set_state("connecting")
	_body.clear()
	_reply = ""
	_metrics = {}
	_first_token_ms = 0
	_sent_ms = Time.get_ticks_msec()
	reply_started.emit()


## Stop the current reply. Whatever arrived so far is kept as the assistant's turn.
func cancel() -> void:
	if not is_busy():
		return
	_close()
	if not _reply.is_empty():
		_messages.append({"role": "assistant", "content": _reply})
		reply_finished.emit(_reply + " [stopped]", _metrics)
	else:
		_messages.pop_back()     # the unanswered user turn
		reply_failed.emit("stopped")


func _process(delta: float) -> void:
	if _state == "":
		_health_timer += delta
		if _health_timer >= HEALTH_INTERVAL_S:
			_poll_health()
		return
	_client.poll()
	var status := _client.get_status()
	match _state:
		"connecting":
			if status == HTTPClient.STATUS_CONNECTED:
				_send_request()
			elif status in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
				if Time.get_ticks_msec() - _state_started_ms > CONNECT_TIMEOUT_S * 1000:
					_fail("no answer from %s within %d s (is llama-server running?)" % [server_url, CONNECT_TIMEOUT_S])
			else:
				_fail("cannot reach %s (is llama-server running?)" % server_url)
		"requesting":
			if status == HTTPClient.STATUS_BODY or (status == HTTPClient.STATUS_CONNECTED and _client.has_response()):
				var code := _client.get_response_code()
				if code != 200:
					_set_state("error_body")
					_pending_body = "HTTP %d" % code
				else:
					_set_state("body")
			elif status != HTTPClient.STATUS_REQUESTING:
				_fail("connection lost while sending the request")
		"body", "error_body":
			if status == HTTPClient.STATUS_BODY:
				var chunk := _client.read_response_body_chunk()
				if chunk.size() > 0:
					_body.append_array(chunk)
					if _state == "body":
						_drain_lines()
			else:
				_finish_body()


func _send_request() -> void:
	var msgs: Array = []
	if not system_prompt.strip_edges().is_empty():
		msgs.append({"role": "system", "content": system_prompt})
	msgs.append_array(_messages)
	var body := JSON.stringify({
		"messages": msgs,
		"stream": true,
		"stream_options": {"include_usage": true},
	})
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: text/event-stream"])
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	var err := _client.request(HTTPClient.METHOD_POST, "/v1/chat/completions", headers, body)
	if err != OK:
		_fail("request failed (error %d)" % err)
		return
	_set_state("requesting")


## Split complete lines out of the byte buffer (decoding only whole lines, so a multi-byte
## character split across chunks is never broken) and handle each server-sent event.
func _drain_lines() -> void:
	while _state != "":
		var nl := _body.find(10)
		if nl < 0:
			return
		var line := _body.slice(0, nl).get_string_from_utf8().strip_edges()
		_body = _body.slice(nl + 1)
		if not line.begins_with("data:"):
			continue
		var data := line.substr(5).strip_edges()
		if data == "[DONE]":
			continue
		var ev = JSON.parse_string(data)
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		_handle_event(ev)


func _handle_event(ev: Dictionary) -> void:
	if ev.has("error"):
		var e = ev.error
		_fail(str(e.get("message", e)) if typeof(e) == TYPE_DICTIONARY else str(e))
		return
	for c in ev.get("choices", []):
		var d: Dictionary = c.get("delta", {})
		var reasoning := str(d.get("reasoning_content", "")) if d.get("reasoning_content") != null else ""
		var content := str(d.get("content", "")) if d.get("content") != null else ""
		if not reasoning.is_empty():
			reasoning_delta.emit(reasoning)
		if not content.is_empty():
			if _first_token_ms == 0:
				_first_token_ms = Time.get_ticks_msec()
			_reply += content
			reply_delta.emit(content)
	# TTFT is measured here, send to first token, at _finish_body: the server's prompt_ms
	# leaves out connecting and the first decode step (it read 56 ms for a ~200 ms wait).
	var t = ev.get("timings")
	if typeof(t) == TYPE_DICTIONARY:
		_metrics["token_rate"] = float(t.get("predicted_per_second", -1.0))
	var u = ev.get("usage")
	if typeof(u) == TYPE_DICTIONARY and _n_ctx > 0:
		_metrics["context_percent"] = 100.0 * float(u.get("total_tokens", 0)) / _n_ctx


func _finish_body() -> void:
	if _state == "error_body":
		var text := _body.get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		var msg := text
		if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("error")) == TYPE_DICTIONARY:
			msg = str(parsed.error.get("message", text))
		_fail("%s: %s" % [_pending_body, msg.left(300)])
		return
	_body.append(10)
	_drain_lines()
	if _state == "":     # an error event already failed the request
		return
	_close()
	if _reply.is_empty():
		_messages.pop_back()
		reply_failed.emit("the server returned an empty reply")
		return
	if _first_token_ms > 0:
		_metrics["ttft_ms"] = float(_first_token_ms - _sent_ms)
	_messages.append({"role": "assistant", "content": _reply})
	reply_finished.emit(_reply, _metrics)
	_set_online(true)


func _fail(msg: String) -> void:
	_close()
	if not _messages.is_empty() and _messages.back().role == "user":
		_messages.pop_back()
	reply_failed.emit(msg)
	_poll_health()


func _close() -> void:
	if _client:
		_client.close()
	_client = null
	_set_state("")


func _set_state(s: String) -> void:
	_state = s
	_state_started_ms = Time.get_ticks_msec()


# ─── Health and context size ──────────────────────────────────────────────

func _poll_health() -> void:
	_health_timer = 0.0
	if _health == null or _health.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	if _health.request(server_url + "/health", _auth_headers()) != OK:
		_set_online(false)


func _on_health_completed(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	_set_online(result == HTTPRequest.RESULT_SUCCESS and code == 200)
	if _online and _n_ctx == 0 and _props.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_props.request(server_url + "/props", _auth_headers())


func _on_props_completed(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var d = JSON.parse_string(body.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY:
		return
	for src in [d, d.get("default_generation_settings", {})]:
		if typeof(src) == TYPE_DICTIONARY and src.get("n_ctx") != null:
			_n_ctx = int(src.n_ctx)
			return


func _set_online(v: bool) -> void:
	if v != _online:
		_online = v
		online_changed.emit(v)


func _auth_headers() -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer " + api_key]) if not api_key.is_empty() else PackedStringArray()


static func _parse_url(url: String) -> Dictionary:
	var u := url.strip_edges()
	var tls := u.begins_with("https://")
	if u.begins_with("http://") or tls:
		u = u.substr(u.find("//") + 2)
	else:
		return {}
	var slash := u.find("/")
	if slash >= 0:
		u = u.left(slash)
	var host := u
	var port := 443 if tls else 80
	var colon := u.rfind(":")
	if colon > 0:
		host = u.left(colon)
		port = int(u.substr(colon + 1))
	if host.is_empty() or port <= 0:
		return {}
	return {"host": host, "port": port, "tls": tls}
