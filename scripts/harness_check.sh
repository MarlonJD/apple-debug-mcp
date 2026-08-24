#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

./scripts/check.sh

required_files='AGENTS.md ARCHITECTURE.md docs/PLANS.md docs/index.md docs/agent-harness/config.json docs/agent-harness/coverage-matrix.md docs/agent-harness/registry.md docs/agent-harness/verification-matrix.md docs/agent-harness/certification.json docs/exec-plans/index.md docs/exec-plans/active/apple-debug-mcp-foundation.md'
for file in $required_files; do
    if [ ! -f "$file" ]; then
        printf 'harness-check: missing required repository authority: %s\n' "$file" >&2
        exit 1
    fi
done

if rg -n --glob '!docs/exec-plans/plan-template.md' 'TODO\(harness\)|<replace-with|<TODO>|TBD:|YYYY-MM-DD|Plan title|None yet' AGENTS.md ARCHITECTURE.md docs 2>/dev/null; then
    printf '%s\n' 'harness-check: unresolved harness placeholder found' >&2
    exit 1
fi

grep -q 'Establish the Apple Debug MCP foundation' docs/exec-plans/index.md
grep -q 'make harness-check' AGENTS.md

printf '%s\n' 'harness-check: project-native build, test, smoke, and repository authority checks passed'
