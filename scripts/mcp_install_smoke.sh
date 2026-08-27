#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/apple-debug-mcp-install-smoke.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

log_file="$tmp_dir/commands.log"
PATH="$root/Tests/Fixtures/mcp-install/bin:$PATH" \
MCP_INSTALL_SMOKE_LOG="$log_file" \
    "$root/scripts/install_mcp.sh" \
        --client both \
        --name apple-debug-mcp-smoke \
        --scope user \
        --server-path "$root/.build/debug/apple-debug-mcp" >/dev/null

grep -Fq 'codex mcp get apple-debug-mcp-smoke' "$log_file"
grep -Fq "codex mcp add apple-debug-mcp-smoke -- $root/.build/debug/apple-debug-mcp" "$log_file"
grep -Fq 'claude mcp get apple-debug-mcp-smoke' "$log_file"
grep -Fq "claude mcp add --scope user --transport stdio apple-debug-mcp-smoke -- $root/.build/debug/apple-debug-mcp" "$log_file"

sh -n "$root/scripts/install_mcp.sh"
"$root/scripts/install_mcp.sh" --help >/dev/null
printf '%s\n' 'mcp-install-smoke: Codex and Claude Code registration commands passed without touching real client configuration'
exit_code=0
