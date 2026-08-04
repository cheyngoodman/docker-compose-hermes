#!/usr/bin/env bash
# Start the Hermes WebUI daemon inside the container.
# Run from the host after container rebuild:
#   docker exec hermes /opt/data/scripts/start-webui.sh
set -euo pipefail

WEBUI_DIR="${WEBUI_DIR:-/opt/data/hermes-webui}"
HERMES_HOME="${HERMES_HOME:-/opt/data}"
MISSING_MSG="WebUI not installed at ${WEBUI_DIR}. Clone it first:
  docker exec -it hermes bash -c 'git clone https://github.com/nesquena/hermes-webui.git /opt/data/hermes-webui'"

if [ ! -d "${WEBUI_DIR}" ]; then
    echo "${MISSING_MSG}"
    exit 1
fi

# Check if already running
if [ -f "${HERMES_HOME}/webui.pid" ]; then
    PID=$(cat "${HERMES_HOME}/webui.pid" 2>/dev/null || true)
    if [ -n "${PID}" ] && kill -0 "${PID}" 2>/dev/null; then
        echo "WebUI already running (PID ${PID})"
        exit 0
    fi
fi

cd "${WEBUI_DIR}"
export HERMES_HOME
./ctl.sh start
echo "WebUI started — http://<host>:8787"