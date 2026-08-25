#!/usr/bin/env python3
"""Exercise an authorized legacy iOS device through the MCP LLDB-DAP surface."""

import json
import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    device_identifier = os.environ.get("APPLE_DEBUG_PHYSICAL_UDID", "")
    app_path = os.environ.get(
        "APPLE_DEBUG_PHYSICAL_APP",
        str(root / ".build" / "ios-physical-fixture" / "Build" / "Products" / "Debug-iphoneos" / "DebugApp.app"),
    )
    if os.environ.get("APPLE_DEBUG_ALLOW_DEVICE_DEBUG") != "1":
        print("ios-legacy-debug-smoke: set APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1", file=sys.stderr)
        return 1
    if os.environ.get("APPLE_DEBUG_ALLOW_DEVICE_MUTATION") != "1":
        print("ios-legacy-debug-smoke: set APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1", file=sys.stderr)
        return 1
    if not device_identifier or not Path(app_path).is_dir():
        print("ios-legacy-debug-smoke: set APPLE_DEBUG_PHYSICAL_UDID and provide a signed .app", file=sys.stderr)
        return 1

    environment = dict(os.environ)
    server = subprocess.Popen(
        [str(server_path)],
        cwd=root,
        env=environment,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    sequence = 0
    session_id = None

    def request(method: str, params: dict) -> dict:
        nonlocal sequence
        sequence += 1
        if server.stdin is None or server.stdout is None:
            raise RuntimeError("MCP server pipes are unavailable")
        server.stdin.write(json.dumps({"jsonrpc": "2.0", "id": sequence, "method": method, "params": params}) + "\n")
        server.stdin.flush()
        while True:
            line = server.stdout.readline()
            if not line:
                stderr = server.stderr.read() if server.stderr else ""
                raise RuntimeError(f"MCP server exited: {stderr[-4_000:]}")
            message = json.loads(line)
            if message.get("id") == sequence:
                return message

    def tool(name: str, arguments: dict) -> dict:
        response = request("tools/call", {"name": name, "arguments": arguments})
        if response.get("result", {}).get("isError"):
            raise RuntimeError(json.dumps(response))
        return json.loads(response["result"]["content"][0]["text"])

    try:
        request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-legacy-smoke", "version": "0.1.0"},
            },
        )
        if server.stdin is None:
            raise RuntimeError("MCP server stdin is unavailable")
        server.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        server.stdin.flush()

        created = tool(
            "apple_debug_session_create",
            {"deviceIdentifier": device_identifier, "appPath": app_path},
        )
        session_id = created["sessionID"]
        threads = tool("apple_debug_threads", {"sessionID": session_id})["body"]["threads"]
        if not threads:
            raise RuntimeError("legacy LLDB-DAP returned no threads")
        thread_id = threads[0]["id"]
        stack = tool(
            "apple_debug_stack_trace",
            {"sessionID": session_id, "threadID": thread_id, "levels": 5},
        )["body"]["stackFrames"]
        if not stack:
            raise RuntimeError("legacy LLDB-DAP returned no stack frames")
        frame_id = stack[0]["id"]
        instruction_reference = stack[0]["instructionPointerReference"]
        tool("apple_debug_registers", {"sessionID": session_id, "frameID": frame_id})
        memory = tool(
            "apple_debug_read_memory",
            {"sessionID": session_id, "memoryReference": instruction_reference, "count": 16},
        )
        if not memory["body"].get("data"):
            raise RuntimeError("legacy LLDB-DAP returned no instruction bytes")
        tool(
            "apple_debug_disassemble",
            {"sessionID": session_id, "memoryReference": instruction_reference, "instructionCount": 4},
        )
        closed = tool("apple_debug_session_close", {"sessionID": session_id})
        session_id = None
        if not closed.get("closed"):
            raise RuntimeError("legacy debug session did not close")
        print(
            "ios-legacy-debug-smoke: install, debugserver attach, threads, stack, registers, memory, disassembly, and cleanup passed"
        )
        return 0
    except Exception as error:
        print(f"ios-legacy-debug-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if session_id is not None and server.poll() is None:
            try:
                tool("apple_debug_session_close", {"sessionID": session_id})
            except Exception:
                pass
        if server.stdin is not None:
            server.stdin.close()
        try:
            server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=10)


if __name__ == "__main__":
    raise SystemExit(main())
