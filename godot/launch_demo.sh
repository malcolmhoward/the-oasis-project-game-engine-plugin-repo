#!/usr/bin/env bash
# O.A.S.I.S. Godot Demo Launcher
# Starts Mosquitto broker, ECHO simulation stack, and the Godot demo.
#
# Usage: ./launch_demo.sh [--no-echo] [--no-godot] [--broker-only]
#
# Prerequisites:
#   - mosquitto installed and in PATH
#   - Python 3.8+ with simulation framework installed (pip install -e ".[all]")
#   - Godot 4.6 in PATH (or set GODOT_BIN environment variable)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
MOSQUITTO_CONF="${SCRIPT_DIR}/mosquitto_demo.conf"
PIDS=()

# Parse arguments
NO_ECHO=false
NO_GODOT=false
BROKER_ONLY=false

for arg in "$@"; do
    case $arg in
        --no-echo) NO_ECHO=true ;;
        --no-godot) NO_GODOT=true ;;
        --broker-only) BROKER_ONLY=true; NO_ECHO=true; NO_GODOT=true ;;
        *) echo "Unknown arg: $arg"; exit 1 ;;
    esac
done

# Cleanup on exit
cleanup() {
    echo ""
    echo "[launcher] Shutting down..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    echo "[launcher] Done."
}
trap cleanup EXIT

# Generate Mosquitto config if not present
if [ ! -f "$MOSQUITTO_CONF" ]; then
    cat > "$MOSQUITTO_CONF" <<EOF
# Auto-generated for O.A.S.I.S. demo
listener 1883
protocol mqtt

listener 9001
protocol websockets

allow_anonymous true
log_type error
log_type warning
EOF
    echo "[launcher] Generated $MOSQUITTO_CONF"
fi

# Start Mosquitto
echo "[launcher] Starting Mosquitto MQTT broker..."
mosquitto -c "$MOSQUITTO_CONF" &
PIDS+=($!)
sleep 1

# Start ECHO simulation (if available and not skipped)
if [ "$NO_ECHO" = false ]; then
    if python3 -c "import simulation" 2>/dev/null; then
        echo "[launcher] Starting ECHO simulation stack..."
        python3 -m simulation.demo &
        PIDS+=($!)
        sleep 2
    else
        echo "[launcher] ECHO simulation not installed. Skipping."
        echo "           Install with: pip install -e path/to/simulation-repo[all]"
    fi
fi

# Start Godot
if [ "$NO_GODOT" = false ]; then
    echo "[launcher] Starting Godot demo..."
    "$GODOT_BIN" --path "$SCRIPT_DIR" &
    PIDS+=($!)
fi

echo "[launcher] All services started. Press Ctrl+C to stop."
echo "  MQTT broker: localhost:1883 (MQTT), localhost:9001 (WebSocket)"
if [ "$NO_ECHO" = false ]; then
    echo "  ECHO simulation: publishing to oasis/# topics"
fi
if [ "$NO_GODOT" = false ]; then
    echo "  Godot demo: connecting via ws://localhost:9001"
fi

# Wait for all background processes
wait
