#!/bin/sh
set -eu

swift build
swift test
./scripts/build_debug_fixture.sh >/dev/null
./scripts/smoke_mcp.sh
python3 ./scripts/debug_fixture_smoke.py
git diff --check

if command -v rg >/dev/null 2>&1; then
    if rg -n --glob '!docs/exec-plans/plan-template.md' 'TODO\(harness\)|<replace-with|<TODO>|TBD:|YYYY-MM-DD|Plan title|None yet' AGENTS.md ARCHITECTURE.md docs 2>/dev/null; then
        printf '%s\n' 'check: unresolved harness placeholder found' >&2
        exit 1
    fi
fi

printf '%s\n' 'check: build, tests, whitespace, and documentation placeholder checks passed'
