#!/bin/sh
set -eu

swift build
swift test
PYTHONPATH=./scripts python3 -m unittest discover -s scripts -p 'test_adaptive_verification.py'
./scripts/build_debug_fixture.sh >/dev/null
./scripts/smoke_mcp.sh
./scripts/mcp_install_smoke.sh
python3 ./scripts/codex_plugin_smoke.py
python3 ./scripts/mcp_domain_behavior_smoke.py
python3 ./scripts/mcp_daemon_smoke.py
python3 ./scripts/daemon_session_isolation_smoke.py
python3 ./scripts/debug_fixture_smoke.py --extended --evidence-output .build/evidence/mcp-mac-debug-workflow.json
python3 ./scripts/replay_smoke.py
python3 ./scripts/plugin_xpc_smoke.py
git diff --check

if command -v rg >/dev/null 2>&1; then
    if rg -n --glob '!docs/exec-plans/plan-template.md' 'TODO\(harness\)|<replace-with|<TODO>|TBD:|YYYY-MM-DD|Plan title|None yet' AGENTS.md ARCHITECTURE.md docs 2>/dev/null; then
        printf '%s\n' 'check: unresolved harness placeholder found' >&2
        exit 1
    fi
fi

printf '%s\n' 'check: build, tests, whitespace, and documentation placeholder checks passed'
