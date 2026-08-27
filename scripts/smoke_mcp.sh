#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

swift build >/dev/null

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/apple-debug-mcp-smoke.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

output_file="$tmp_dir/output.jsonl"
error_file="$tmp_dir/stderr.log"

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    if [ "$status" -ne 0 ]; then
        printf '%s\n' 'smoke: protocol transcript failed; stderr:' >&2
        tail -n 80 "$error_file" >&2 || true
        printf '%s\n' 'smoke: protocol transcript failed; last responses:' >&2
        tail -n 20 "$output_file" >&2 || true
    fi
    rm -rf "$tmp_dir"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

{
    sleep 0.2
    printf '%s\n' \
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"apple-debug-mcp-smoke","version":"0.1.0"}}}' \
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' \
        '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
        '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"apple_capabilities","arguments":{}}}' \
        '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"apple_toolchain_status","arguments":{}}}' \
        '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"apple_lldb_dap_initialize","arguments":{}}}' \
        '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"apple_macho_inspect","arguments":{"path":"/bin/echo"}}}' \
        '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"apple_simulator_list","arguments":{}}}' \
        '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"apple_crash_inspect","arguments":{"path":"Tests/Fixtures/example.crash"}}}' \
        '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"apple_log_show","arguments":{"target":"host","last":"1s","predicate":"process == \"apple-debug-mcp\""}}}' \
        '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"apple_binary_inspect","arguments":{"path":"/bin/echo"}}}' \
        '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"apple_binary_diff","arguments":{"leftPath":"/bin/echo","rightPath":"/bin/echo"}}}' \
        '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"apple_crash_symbolicate","arguments":{"crashPath":"Tests/Fixtures/example.crash","artifacts":[{"imageName":"AppleDebugFixture","binaryPath":"/bin/echo","architecture":"arm64e"}]}}}'
    sleep 45
} | .build/debug/apple-debug-mcp > "$output_file" 2> "$error_file"

grep -q '"id":1' "$output_file"
grep -q '"instructions":' "$output_file"
grep -q 'Prefer Build for iOS/macOS for' "$output_file"
grep -q 'apple_capabilities' "$output_file"
grep -q 'apple_toolchain_status' "$output_file"
grep -q '"id":4' "$output_file"
grep -q 'ios-device' "$output_file"
grep -q 'lldb-dap' "$output_file"
grep -q 'Mach-O' "$output_file"
grep -q 'iPhone' "$output_file"
grep -q 'apple_debug_step' "$output_file"
grep -q 'apple_debug_registers' "$output_file"
grep -q 'apple_debug_modules' "$output_file"
grep -q 'apple_debug_set_function_breakpoint' "$output_file"
grep -q 'apple_debug_set_exception_breakpoints' "$output_file"
grep -q 'apple_debug_breakpoint_locations' "$output_file"
grep -q 'apple_debug_set_instruction_breakpoint' "$output_file"
grep -q 'apple_debug_completions' "$output_file"
grep -q 'apple_debug_set_variable' "$output_file"
grep -q 'apple_debug_stop_snapshot' "$output_file"
grep -q 'apple_debug_memory_map' "$output_file"
grep -q 'apple_performance_record' "$output_file"
grep -q 'apple_debug_wait_for_stop' "$output_file"
grep -q 'apple_debug_search_memory' "$output_file"
grep -q 'apple_debug_patch_memory' "$output_file"
grep -q 'apple_debug_checkpoint' "$output_file"
grep -q 'apple_debug_replay' "$output_file"
grep -q 'apple_kernel_lab_connect' "$output_file"
grep -q 'apple_kernel_lab_inspect' "$output_file"
grep -q 'EXC_BAD_ACCESS' "$output_file"
grep -q 'apple_simulator_app_info' "$output_file"
grep -q 'apple_simulator_get_app_container' "$output_file"
grep -q 'apple_simulator_open_url' "$output_file"
grep -q 'apple_simulator_set_location' "$output_file"
grep -q 'apple_simulator_clear_location' "$output_file"
grep -q 'apple_simulator_record_video' "$output_file"
grep -q 'apple_simulator_ui_snapshot' "$output_file"
grep -q 'apple_simulator_ui_action' "$output_file"
grep -q '"id":9.*"isError":false' "$output_file"
grep -q '"id":10.*"isError":false' "$output_file"
grep -q 'codeSignature' "$output_file"
grep -q 'dyldExports' "$output_file"
grep -q 'apple_runtime_metadata' "$output_file"
grep -q 'apple_binary_diff' "$output_file"
grep -q 'apple_xcode_test' "$output_file"
grep -q '"id":11.*"isError":false' "$output_file"
grep -q 'apple_crash_symbolicate' "$output_file"
grep -q '"id":12.*"isError":false' "$output_file"

printf '%s\n' 'smoke: MCP initialize, tool discovery, capability, and toolchain calls passed'
