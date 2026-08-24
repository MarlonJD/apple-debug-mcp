#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

swift build >/dev/null

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/apple-debug-mcp-smoke.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

output_file="$tmp_dir/output.jsonl"
error_file="$tmp_dir/stderr.log"

{
    sleep 0.2
    printf '%s\n' \
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"apple-debug-mcp-smoke","version":"0.1.0"}}}' \
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' \
        '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
        '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"apple_capabilities","arguments":{}}}' \
        '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"apple_toolchain_status","arguments":{}}}' \
        '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"apple_lldb_dap_initialize","arguments":{}}}' \
        '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"apple_macho_inspect","arguments":{"path":"/bin/echo"}}}'
    sleep 0.5
} | .build/debug/apple-debug-mcp > "$output_file" 2> "$error_file"

grep -q '"id":1' "$output_file"
grep -q 'apple_capabilities' "$output_file"
grep -q 'apple_toolchain_status' "$output_file"
grep -q 'ios-device' "$output_file"
grep -q 'lldb-dap' "$output_file"
grep -q 'Mach-O' "$output_file"

printf '%s\n' 'smoke: MCP initialize, tool discovery, capability, and toolchain calls passed'
