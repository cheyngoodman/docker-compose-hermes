#!/usr/bin/env bash
# /opt/data/scripts/hermes-init.sh
# Container init — starts the Hermes gateway and WebUI daemon.
# Lives on the persistent /opt/data volume so it survives container rebuilds.
#
# Used as docker-compose `command:`:
#   command: /opt/data/scripts/hermes-init.sh
#
# The container's main-wrapper.sh (entrypoint) activates the agent venv,
# sets HOME=/opt/data, and drops privileges to the hermes user before
# exec-ing this script. We inherit all of that.

set -euo pipefail

GATEWAY_READY_TIMEOUT=${GATEWAY_READY_TIMEOUT:-30}
WEBUI_DIR="${WEBUI_DIR:-/opt/data/hermes-webui}"
HERMES_HOME="${HERMES_HOME:-/opt/data}"

log() { printf '[hermes-init] %s\n' "$*"; }

# ── Gateway ────────────────────────────────────────────────────────
log "Starting gateway…"
hermes gateway run &
GATEWAY_PID=$!

# Forward signals to the gateway so the container shuts down cleanly.
cleanup() {
    log "Caught signal — stopping gateway (PID $GATEWAY_PID)"
    kill -TERM "$GATEWAY_PID" 2>/dev/null || true
    wait "$GATEWAY_PID" 2>/dev/null || true
    exit 0
}
trap cleanup TERM INT QUIT

# Wait for gateway health.
log "Waiting for gateway health…"
_start=$(date +%s)
while true; do
    if curl -sf http://localhost:9119/api/status >/dev/null 2>&1; then
        log "Gateway healthy after $(( $(date +%s) - _start ))s"
        break
    fi
    if ! kill -0 "$GATEWAY_PID" 2>/dev/null; then
        log "ERROR: gateway exited prematurely"
        wait "$GATEWAY_PID" 2>/dev/null || true
        exit 1
    fi
    if [ $(( $(date +%s) - _start )) -ge "$GATEWAY_READY_TIMEOUT" ]; then
        log "ERROR: gateway did not become healthy within ${GATEWAY_READY_TIMEOUT}s"
        exit 1
    fi
    sleep 1
done

# ── WebUI ──────────────────────────────────────────────────────────
if [ "${HERMES_WEBUI_ENABLED:-1}" != "1" ]; then
    log "WebUI disabled (HERMES_WEBUI_ENABLED != 1)"
elif [ -d "$WEBUI_DIR" ]; then
    log "Starting WebUI…"
    cd "$WEBUI_DIR"
    export HERMES_HOME
    if ./ctl.sh start 2>&1; then
        log "WebUI started"
    else
        log "WARNING: WebUI failed to start (see /opt/data/webui.log)"
    fi
    cd "$HERMES_HOME"
else
    log "WebUI not installed at $WEBUI_DIR — skipping"
    log "Clone it: git clone https://github.com/nesquena/hermes-webui.git $WEBUI_DIR"
    log "Then configure: cp $WEBUI_DIR/.env.example $WEBUI_DIR/.env"
fi

# ── Wait ───────────────────────────────────────────────────────────
log "Gateway running (PID $GATEWAY_PID) — waiting…"
wait "$GATEWAY_PID"