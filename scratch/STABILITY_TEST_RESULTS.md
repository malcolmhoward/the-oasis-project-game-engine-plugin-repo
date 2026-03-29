# Stability Test Results

**Date**: 2026-03-29
**Duration**: ~10-11 minutes (estimated from 3200+ messages at ~5 msg/sec)
**Data source**: tools/mock_ocp_traffic.py (standalone, no Docker)

## Results

| Component | Status | Notes |
|-----------|--------|-------|
| OCP message stream | **STABLE** | 3200+ messages displayed without crash |
| Architecture visualization | **STABLE** | Sensor data updating continuously |
| 3D game scene | **STABLE** | E3 avatar rendered correctly |
| HUD companion face | **STABLE** | Blinking, expression changes observed |
| DAWN conversation panel | **DEGRADED** | Stopped responding to input after ~10 minutes |
| Mock traffic script | **STABLE** | Python process running, MQTT publishing continuously |
| MQTT broker | **STABLE** | Mosquitto handling all traffic without issues |

## Bug: DAWN Panel Input Unresponsive After Extended Use

**Symptom**: After ~10 minutes, typing in the DAWN panel input field has no effect. The message stream continues to update (sensor data still flows), but the DAWN conversation panel no longer sends messages or displays responses.

**Likely cause**: The DAWN conversation panel (`dawn_panel.gd`) adds a new MessageBubble node for each message but never removes old ones. After extended use, the ScrollContainer accumulates thousands of child nodes, causing performance degradation and eventual input loss.

**Fix needed**: Add message cleanup to `dawn_panel.gd` — remove oldest messages when count exceeds a threshold (e.g., 100 messages). The `dawn_demo_controller.gd` already does this for the OCP stream (clears after 200 lines).

**Priority**: Fix before demo — a 20-minute presentation must not hit this bug.

## Improvement: Add Timer UI Element

The OCP message stream should display elapsed runtime so the presenter can gauge how long the demo has been running. Suggested location: the global status bar (already has MsgRate and Uptime labels in oasis_monitor).

## Recommendations

1. Add message cleanup to dawn_panel.gd (max 100 bubbles)
2. Add runtime timer to unified demo status area
3. Re-test for 20+ minutes after fix
