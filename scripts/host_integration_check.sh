#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

python3 ./scripts/mcp_daemon_smoke.py
python3 ./scripts/daemon_session_isolation_smoke.py
python3 ./scripts/replay_smoke.py
python3 ./scripts/plugin_xpc_smoke.py

printf '%s\n' 'host-integration-check: daemon isolation, replay, and XPC plugin integration passed'
