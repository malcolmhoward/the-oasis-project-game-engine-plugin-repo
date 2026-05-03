#!/usr/bin/env python3
"""
Mock OCP traffic publisher — publishes realistic O.A.S.I.S. messages
to a local Mosquitto broker so Godot plugin demos work without Docker
or the E.C.H.O. simulation framework.

Usage:
    python tools/mock_ocp_traffic.py
    python tools/mock_ocp_traffic.py --broker localhost --port 1883 --interval 1.0

Requirements:
    pip install paho-mqtt
"""

import argparse
import json
import math
import random
import signal
import sys
import time

import paho.mqtt.client as mqtt


def make_motion(t, phase):
    heading = (phase * 57.3 + 45 * math.sin(2 * math.pi * t / 120 + phase)) % 360
    pitch = 5 * math.sin(2 * math.pi * t / 30 + phase)
    roll = 3 * math.sin(2 * math.pi * t / 20 + phase)
    return {
        "device": "Motion", "format": "Orientation",
        "heading": round(heading, 2), "pitch": round(pitch, 2), "roll": round(roll, 2),
        "w": round(math.cos(math.radians(heading/2)), 4),
        "x": 0.0, "y": round(math.sin(math.radians(pitch/2)), 4),
        "z": round(math.sin(math.radians(heading/2)), 4),
    }


def make_gps(t, phase):
    lat = 33.749 + 0.001 * math.sin(2 * math.pi * t / 300 + phase)
    lon = -84.388 + 0.001 * math.sin(2 * math.pi * t / 240 + phase)
    now = time.gmtime()
    return {
        "device": "GPS",
        "time": time.strftime("%H:%M:%S", now), "date": time.strftime("%Y-%m-%d", now),
        "fix": 1, "quality": 1,
        "latitude": round(lat, 6), "latitudeDegrees": round(lat, 6), "lat": "N",
        "longitude": round(lon, 6), "longitudeDegrees": round(lon, 6), "lon": "W",
        "speed": round(max(0, 0.5 * math.sin(2 * math.pi * t / 90 + phase)), 2),
        "angle": round(heading % 360, 1) if (heading := phase * 57.3 + 45 * math.sin(2 * math.pi * t / 120 + phase)) else 0,
        "altitude": round(320 + 2 * math.sin(2 * math.pi * t / 60 + phase), 1),
        "satellites": 8,
    }


def make_environmental(t, phase):
    temp = 22.5 + 2 * math.sin(2 * math.pi * t / 120 + phase)
    humidity = max(10, min(100, 65 + 5 * math.sin(2 * math.pi * t / 90 + phase)))
    eco2 = max(400, 400 + 50 * math.sin(2 * math.pi * t / 60 + phase))
    return {
        "device": "Enviro",
        "temp": round(temp, 1), "humidity": round(humidity, 1),
        "air_quality": round(85 + 10 * math.sin(2 * math.pi * t / 180 + phase), 1),
        "tvoc_ppb": round(max(0, 10 + 8 * math.sin(2 * math.pi * t / 45 + phase)), 1),
        "eco2_ppm": round(eco2, 1),
        "co2_ppm": round(eco2 + random.uniform(5, 20), 1),
        "heat_index_c": round(temp + 2, 1), "dew_point": round(temp - 8, 1),
    }


def make_system_metrics(t):
    return {
        "device": "SystemMetrics",
        "cpu_percent": round(35 + 10 * math.sin(2 * math.pi * t / 30) + random.uniform(-2, 2), 1),
        "memory_percent": 62.1, "disk_percent": 45.0,
        "system_temp": round(52 + 3 * math.sin(2 * math.pi * t / 60), 1),
        "uptime_seconds": int(t) % 86400,
    }


def make_battery():
    return {"device": "BatteryStatus", "voltage": 12.4, "current": 1.2,
            "power": 14.88, "percentage": 85, "charging": False}


def _format_elapsed(seconds):
    """Format seconds as HH:MM:SS."""
    h, rem = divmod(int(seconds), 3600)
    m, s = divmod(rem, 60)
    return f"{h}:{m:02d}:{s:02d}"


def main():
    parser = argparse.ArgumentParser(description="Mock OCP traffic publisher")
    parser.add_argument("--broker", default="localhost", help="MQTT broker host")
    parser.add_argument("--port", type=int, default=1883, help="MQTT broker port")
    parser.add_argument("--interval", type=float, default=1.0, help="Publish interval (seconds)")
    args = parser.parse_args()

    phase = random.uniform(0, 2 * math.pi)
    peers = [
        ("aura", "echo-aura-mock", ["motion", "gps", "environmental"]),
        ("stat", "echo-stat-mock", ["system_metrics", "battery"]),
        ("scope", "echo-scope-mock", ["coordination", "monitoring"]),
        ("dawn", "echo-dawn-mock", ["conversation", "tool_execution", "reasoning"]),
    ]
    msg_count = [0]  # mutable counter for closure access
    dawn_count = [0]

    # --- MQTT callbacks (set BEFORE connect) ---

    def on_connect(c, u, flags, rc, properties=None):
        if rc == 0 or (hasattr(rc, 'value') and rc.value == 0):
            print(f"  [MQTT] Connected to {args.broker}:{args.port}")
            # (Re-)subscribe on every connect — survives broker restarts
            # v1.4 input: dawn/cmd; v1.3 input: dawn (kept for backward compat)
            c.subscribe("dawn", qos=1)
            c.subscribe("dawn/cmd", qos=1)
            # Publish peer status on (re)connect (v1.4: <component>/status)
            for component, peer_id, caps in peers:
                c.publish(f"{component}/status", json.dumps({
                    "device": component, "msg_type": "status", "status": "online",
                    "timestamp": int(time.time() * 1000), "version": "0.1.0-mock",
                    "capabilities": caps,
                }), qos=1, retain=True)
                c.publish("echo/discovery/simulates", json.dumps({
                    "peer_id": peer_id, "component": component,
                    "embodiment": "software", "capabilities": caps,
                    "timestamp": int(time.time() * 1000),
                }), qos=1, retain=True)
        else:
            print(f"  [MQTT] Connection refused: {rc}")

    def on_disconnect(c, u, flags, rc, properties=None):
        print(f"  [MQTT] Disconnected (rc={rc}). Auto-reconnect will retry...")

    def on_message(c, u, msg):
        if msg.topic not in ("dawn", "dawn/cmd"):
            return
        try:
            p = json.loads(msg.payload.decode())
        except Exception:
            return
        # v1.4 cmd format: {action: "process_intent", parameters: {text: "..."}}
        # v1.3 dawn topic: {value: "..."} or {text: "..."}
        params = p.get("parameters", {}) or {}
        text = params.get("text") or p.get("value") or p.get("text") or ""
        if not text or p.get("device") == "echo-dawn-mock":
            return
        r = "I'm not sure how to help with that. Try 'help' to see what I can do."
        confused = True
        ocp_command = None  # If set, also publish an OCP command to the avatar
        tl = text.lower()
        if "hello" in tl or "hi" in tl or "hey" in tl:
            r = "Hey! I'm D.A.W.N. — Digital Assistant for Workflow Neural-inference. Try 'help' to see what I can do."
            confused = False
        elif "help" in tl or "what can you do" in tl or "commands" in tl:
            r = ("I can respond to: 'hello', 'status', 'turn on/off', "
                 "'who are you', 'peers', 'temperature', 'battery'. "
                 "Movement: 'move up/down/left/right', 'turn left/right', 'jump'.")
            confused = False
        elif "who are you" in tl or "what are you" in tl:
            r = ("I'm D.A.W.N. — the AI assistant for the O.A.S.I.S. ecosystem. "
                 "Right now I'm running as a mock responder.")
            confused = False
        elif "peer" in tl or "online" in tl or "who else" in tl:
            r = ("4 mock peers online: echo-aura-mock (sensors), echo-stat-mock "
                 "(system metrics), echo-scope-mock (coordination), echo-dawn-mock (me).")
            confused = False
        elif "move forward" in tl or "go forward" in tl or "move up" in tl:
            r = "Moving the avatar forward."
            confused = False
            ocp_command = {"action": "move_forward", "parameters": {"distance": 1.5}}
        elif "move back" in tl or "go back" in tl or "move down" in tl:
            r = "Moving the avatar backward."
            confused = False
            ocp_command = {"action": "move_back", "parameters": {"distance": 1.5}}
        elif "move left" in tl or "go left" in tl:
            r = "Moving the avatar left."
            confused = False
            ocp_command = {"action": "move_left", "parameters": {"distance": 1.5}}
        elif "move right" in tl or "go right" in tl:
            r = "Moving the avatar right."
            confused = False
            ocp_command = {"action": "move_right", "parameters": {"distance": 1.5}}
        elif "turn left" in tl:
            r = "Turning the avatar left."
            confused = False
            ocp_command = {"action": "turn_left", "parameters": {}}
        elif "turn right" in tl:
            r = "Turning the avatar right."
            confused = False
            ocp_command = {"action": "turn_right", "parameters": {}}
        elif "jump" in tl:
            r = "The avatar is jumping!"
            confused = False
            ocp_command = {"action": "jump", "parameters": {}}
        elif "turn on" in tl:
            r = "Done. Kitchen Lights is now on. (mock)"
            confused = False
        elif "turn off" in tl:
            r = "Done. Kitchen Lights is now off. (mock)"
            confused = False
        elif "temperature" in tl or "temp" in tl or "weather" in tl:
            r = "Current: 22.5°C, 65% humidity, air quality 85/100. (mock)"
            confused = False
        elif "battery" in tl or "power" in tl:
            r = "Battery at 85%, 12.4V, discharging. (mock)"
            confused = False
        elif "status" in tl:
            elapsed = _format_elapsed(time.time() - t0)
            r = (f"All mock peers online. {msg_count[0]} messages published "
                 f"over {elapsed}. D.A.W.N. responded {dawn_count[0]} times.")
            confused = False
        # Publish a dawn/events metrics_update payload that approximates the
        # response cost so the Godot DAWN UI's telemetry rings show movement.
        # TTFT scales loosely with response length; token rate stays in a
        # plausible band; context grows slowly with each turn.
        ttft_ms = max(80, 60 + len(r) * 1.2)
        token_rate = round(28 + 12 * math.sin(time.time() * 0.3), 1)
        ctx_pct = min(95.0, 8.0 + dawn_count[0] * 1.5)
        c.publish("dawn/events", json.dumps({
            "device": "dawn", "msg_type": "event",
            "event": "metrics_update",
            "ttft_ms": round(ttft_ms, 0),
            "token_rate": token_rate,
            "context_percent": round(ctx_pct, 1),
            "timestamp": int(time.time() * 1000),
        }))
        # Publish DAWN response
        c.publish("dawn", json.dumps({
            "device": "echo-dawn-mock", "action": "speak",
            "value": r, "confused": confused, "timestamp": int(time.time() * 1000),
        }))
        # Publish OCP command to avatar if applicable
        if ocp_command:
            # v1.4: <component>/cmd. The avatar's component_name is "e3-avatar".
            c.publish("e3-avatar/cmd", json.dumps({
                "device": "e3-avatar", "msg_type": "command",
                "action": ocp_command["action"],
                "parameters": ocp_command.get("parameters", {}),
                "timestamp": int(time.time() * 1000),
            }))
            print(f"  [OCP] -> e3-avatar/cmd: {ocp_command['action']}")
        dawn_count[0] += 1
        print(f"  [DAWN] {text} -> {r}")

    # Set callbacks BEFORE connecting (paho-mqtt best practice)
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    client.connect(args.broker, args.port, 60)
    client.loop_start()

    print(f"Mock OCP traffic: {args.broker}:{args.port} at {args.interval}s")
    print(f"  Peers: {', '.join(p[1] for p in peers)}")
    print(f"  Ctrl+C to stop")

    signal.signal(signal.SIGTERM, lambda s, f: sys.exit(0))
    signal.signal(signal.SIGINT, lambda s, f: sys.exit(0))

    # Notification scenario tape (seconds offset from start, payload).
    # Replays once on a 5-minute loop so the toast visibly fires during demos.
    notification_tape = [
        (45.0, {"category": "incoming_call", "caller_name": "Pepper Potts",
                "status": "Mobile - 555-0142"}),
        (52.0, {"category": "call_active", "caller_name": "Pepper Potts",
                "status": "Connected - 00:07"}),
        (62.0, {"category": "call_ended", "caller_name": "Pepper Potts",
                "status": "Duration 00:17"}),
        (95.0, {"category": "sms_received", "caller_name": "Rhodey",
                "status": "ETA 20 minutes."}),
    ]

    t0 = time.time()
    last_heartbeat = 0
    last_notification_idx = -1
    while True:
        t = time.time() - t0
        client.publish("aura", json.dumps(make_motion(t, phase)))
        client.publish("aura", json.dumps(make_gps(t, phase)))
        client.publish("aura", json.dumps(make_environmental(t, phase)))
        client.publish("stat", json.dumps(make_system_metrics(t)))
        client.publish("stat", json.dumps(make_battery()))
        msg_count[0] += 5

        # Loop the notification tape every 300s. Publish at most one
        # entry per tick: the next un-fired entry whose 'when' has been
        # reached. last_notification_idx tracks the index of the most
        # recently fired entry; reset on the loop boundary.
        loop_t = t % 300.0
        if loop_t < 1.0 and last_notification_idx >= 0:
            last_notification_idx = -1
        next_idx = last_notification_idx + 1
        if next_idx < len(notification_tape):
            when, payload = notification_tape[next_idx]
            if loop_t >= when:
                last_notification_idx = next_idx
                event = {
                    "device": "mirage", "msg_type": "event",
                    "event": "notification",
                    "timestamp": int(time.time() * 1000),
                    **payload,
                }
                client.publish("mirage/events", json.dumps(event))
                print(f"  [NOTIFY] {payload['category']}: {payload['caller_name']}")

        if int(t) % 30 == 0 and int(t) != last_heartbeat:
            last_heartbeat = int(t)
            for comp, pid, caps in peers:
                client.publish(f"{comp}/status", json.dumps({
                    "device": comp, "msg_type": "status", "status": "online",
                    "timestamp": int(time.time() * 1000), "version": "0.1.0-mock",
                    "capabilities": caps,
                }), qos=1, retain=True)
            elapsed = _format_elapsed(t)
            print(f"  [{elapsed}] {msg_count[0]} msgs | "
                  f"DAWN: {dawn_count[0]} responses | "
                  f"connected: {client.is_connected()}")
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
