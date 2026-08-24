#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

if [ "${APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION:-0}" != "1" ]; then
    printf '%s\n' 'ios-debug-fixture-smoke: set APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 for this explicit local workflow' >&2
    exit 1
fi

app_path=$(./scripts/build_ios_fixture.sh | tail -1)
simulator_id=$(xcrun simctl list devices available --json | python3 -c 'import json,sys; data=json.load(sys.stdin); devices=data["devices"]; candidates=[d for runtime,items in devices.items() if "iOS" in runtime for d in items if d.get("isAvailable",True)]; print(candidates[0]["udid"] if candidates else "")')
if [ -z "$simulator_id" ]; then
    printf '%s\n' 'ios-debug-fixture-smoke: no available iOS Simulator found' >&2
    exit 1
fi

cleanup() {
    xcrun simctl terminate "$simulator_id" com.burakkarahan.AppleDebugFixture >/dev/null 2>&1 || true
    xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

xcrun simctl boot "$simulator_id" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$simulator_id" -b >/dev/null
xcrun simctl install "$simulator_id" "$app_path" >/dev/null
launch_output=$(xcrun simctl launch "$simulator_id" com.burakkarahan.AppleDebugFixture)
process_id=$(printf '%s\n' "$launch_output" | awk -F': ' '{print $2}')

APPLE_DEBUG_ALLOW_TARGET_ATTACH=1 SIM_PROCESS_ID="$process_id" python3 - "$root" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
process_id = int(os.environ["SIM_PROCESS_ID"])
environment = dict(os.environ)
environment["APPLE_DEBUG_ALLOW_TARGET_ATTACH"] = "1"
server = subprocess.Popen(
    [str(root / ".build" / "debug" / "apple-debug-mcp")],
    cwd=root,
    env=environment,
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)
sequence = 0

def request(method, params):
    global sequence
    sequence += 1
    assert server.stdin is not None
    server.stdin.write(json.dumps({"jsonrpc": "2.0", "id": sequence, "method": method, "params": params}) + "\n")
    server.stdin.flush()
    assert server.stdout is not None
    while True:
        line = server.stdout.readline()
        if not line:
            raise RuntimeError("MCP server exited before responding")
        message = json.loads(line)
        if message.get("id") == sequence:
            return message

def tool(name, arguments):
    response = request("tools/call", {"name": name, "arguments": arguments})
    if response.get("result", {}).get("isError"):
        raise RuntimeError(response)
    return response

try:
    request("initialize", {
        "protocolVersion": "2025-11-25",
        "capabilities": {},
        "clientInfo": {"name": "apple-debug-mcp-ios-debug-smoke", "version": "0.1.0"},
    })
    assert server.stdin is not None
    server.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
    server.stdin.flush()

    created = tool("apple_debug_session_create", {})
    session_id = json.loads(created["result"]["content"][0]["text"])["sessionID"]
    tool("apple_debug_attach", {"sessionID": session_id, "processID": process_id})
    threads = json.loads(tool("apple_debug_threads", {"sessionID": session_id})["result"]["content"][0]["text"])["body"]["threads"]
    if not threads:
        raise RuntimeError("iOS Simulator attach returned no threads")
    thread_id = threads[0]["id"]
    stack = json.loads(tool("apple_debug_stack_trace", {"sessionID": session_id, "threadID": thread_id, "levels": 5})["result"]["content"][0]["text"])["body"]["stackFrames"]
    if not stack:
        raise RuntimeError("iOS Simulator attach returned no stack frames")
    reference = stack[0]["instructionPointerReference"]
    tool("apple_debug_read_memory", {"sessionID": session_id, "memoryReference": reference, "count": 16})
    tool("apple_debug_disassemble", {"sessionID": session_id, "memoryReference": reference, "instructionCount": 4})
    closed = json.loads(tool("apple_debug_session_close", {"sessionID": session_id})["result"]["content"][0]["text"])
    if not closed.get("closed"):
        raise RuntimeError("iOS Simulator debug session did not close")
    print("ios-debug-fixture-smoke: attach, threads, stack, memory, disassembly, and cleanup passed for %s" % process_id)
finally:
    if server.stdin is not None:
        server.stdin.close()
    try:
        server.wait(timeout=5)
    except subprocess.TimeoutExpired:
        server.kill()
        server.wait(timeout=5)
PY
