#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

export APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1

./scripts/ios_fixture_smoke.sh
./scripts/ios_debug_fixture_smoke.sh
python3 ./scripts/ios_mcp_tool_smoke.py
python3 ./scripts/ios_ui_tree_smoke.py
python3 ./scripts/ios_arbitrary_ui_smoke.py
APPLE_DEBUG_ALLOW_XCODE_BUILD=1 python3 ./scripts/xcode_artifact_smoke.py
APPLE_DEBUG_ALLOW_XCODE_BUILD=1 python3 ./scripts/xcode_test_smoke.py
python3 ./scripts/simulator_environment_smoke.py
python3 ./scripts/repro_bundle_smoke.py

printf '%s\n' 'simulator-check: lifecycle, debugger, MCP, UI, Xcode, environment, and repro-bundle integration passed'
