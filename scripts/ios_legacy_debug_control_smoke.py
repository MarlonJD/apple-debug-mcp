#!/usr/bin/env python3
"""Exercise physical legacy breakpoint and control operations through MCP."""

import base64
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    device_identifier = os.environ.get("APPLE_DEBUG_PHYSICAL_UDID", "")
    app_path = os.environ.get(
        "APPLE_DEBUG_PHYSICAL_APP",
        str(root / ".build" / "ios-physical-fixture" / "Build" / "Products" / "Debug-iphoneos" / "DebugApp.app"),
    )
    source_path = root / "Tests" / "Fixtures" / "iOSDebugApp" / "DebugApp.swift"
    if os.environ.get("APPLE_DEBUG_ALLOW_DEVICE_DEBUG") != "1":
        print("ios-legacy-debug-control-smoke: set APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1", file=sys.stderr)
        return 1
    if os.environ.get("APPLE_DEBUG_ALLOW_DEVICE_MUTATION") != "1":
        print("ios-legacy-debug-control-smoke: set APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1", file=sys.stderr)
        return 1
    if os.environ.get("APPLE_DEBUG_ALLOW_EVALUATE") != "1":
        print("ios-legacy-debug-control-smoke: set APPLE_DEBUG_ALLOW_EVALUATE=1", file=sys.stderr)
        return 1
    if os.environ.get("APPLE_DEBUG_ALLOW_MEMORY_WRITE") != "1":
        print("ios-legacy-debug-control-smoke: set APPLE_DEBUG_ALLOW_MEMORY_WRITE=1", file=sys.stderr)
        return 1
    if not device_identifier or not Path(app_path).is_dir():
        print("ios-legacy-debug-control-smoke: set APPLE_DEBUG_PHYSICAL_UDID and provide a signed .app", file=sys.stderr)
        return 1

    source_lines = source_path.read_text().splitlines()
    probe_lines = [index for index, line in enumerate(source_lines, start=1) if "UserDefaults.standard.set" in line]
    if len(probe_lines) != 1:
        print("ios-legacy-debug-control-smoke: deterministic control probe line is missing or ambiguous", file=sys.stderr)
        return 1
    probe_line = probe_lines[0]

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

    def require_body(response: dict) -> dict:
        body = response.get("body")
        if not isinstance(body, dict):
            raise RuntimeError(f"DAP response has no body: {response}")
        return body

    def stopped_thread_and_frame() -> tuple[int, int, str]:
        threads = require_body(tool("apple_debug_threads", {"sessionID": session_id}))['threads']
        if not threads:
            raise RuntimeError("physical debugger returned no stopped threads")
        thread_id = threads[0]["id"]
        frames = require_body(
            tool("apple_debug_stack_trace", {"sessionID": session_id, "threadID": thread_id, "levels": 10})
        )["stackFrames"]
        if not frames:
            raise RuntimeError("physical debugger returned no stopped stack frames")
        return thread_id, frames[0]["id"], frames[0]["instructionPointerReference"]

    try:
        request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-legacy-control-smoke", "version": "0.1.0"},
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
        thread_id, frame_id, instruction_reference = stopped_thread_and_frame()

        breakpoint_response = tool(
            "apple_debug_set_breakpoint",
            {"sessionID": session_id, "file": str(source_path), "line": probe_line},
        )
        breakpoints = require_body(breakpoint_response).get("breakpoints", [])
        if not any(breakpoint.get("verified") for breakpoint in breakpoints):
            raise RuntimeError(f"deterministic control breakpoint was not verified: {breakpoint_response}")

        tool("apple_debug_continue", {"sessionID": session_id, "threadID": thread_id})
        wait = tool("apple_debug_wait_for_stop", {"sessionID": session_id, "timeoutMilliseconds": 30_000})
        if not wait.get("stopped") or wait.get("terminated"):
            raise RuntimeError(f"deterministic control breakpoint did not stop: {wait}")

        thread_id, frame_id, instruction_reference = stopped_thread_and_frame()
        evaluation = require_body(
            tool("apple_debug_evaluate", {"sessionID": session_id, "expression": "1 + 1", "frameID": frame_id})
        )
        if "2" not in str(evaluation.get("result", "")):
            raise RuntimeError(f"physical expression evaluation returned an unexpected result: {evaluation}")

        tool(
            "apple_debug_step",
            {"sessionID": session_id, "threadID": thread_id, "kind": "next", "granularity": "instruction"},
        )
        step_wait = tool("apple_debug_wait_for_stop", {"sessionID": session_id, "timeoutMilliseconds": 10_000})
        if not step_wait.get("stopped") or step_wait.get("terminated"):
            raise RuntimeError(f"physical instruction step did not stop: {step_wait}")
        stopped_thread_and_frame()

        tool("apple_debug_continue", {"sessionID": session_id, "threadID": thread_id})
        time.sleep(0.5)
        tool("apple_debug_pause", {"sessionID": session_id})
        pause_wait = tool("apple_debug_wait_for_stop", {"sessionID": session_id, "timeoutMilliseconds": 10_000})
        if not pause_wait.get("stopped") or pause_wait.get("terminated"):
            raise RuntimeError(f"physical pause did not produce a stop: {pause_wait}")

        thread_id, frame_id, instruction_reference = stopped_thread_and_frame()
        stack_pointer = require_body(
            tool("apple_debug_evaluate", {"sessionID": session_id, "expression": "$sp", "frameID": frame_id})
        ).get("result", "")
        match = re.search(r"0x[0-9a-fA-F]+", str(stack_pointer))
        if match is None:
            raise RuntimeError(f"physical debugger did not return a stack pointer: {stack_pointer}")
        stack_reference = match.group(0)
        original = base64.b64decode(
            require_body(
                tool("apple_debug_read_memory", {"sessionID": session_id, "memoryReference": stack_reference, "count": 4})
            )["data"]
        )
        requested = bytes([original[0] ^ 0xFF]) + original[1:]
        patch = tool(
            "apple_debug_patch_memory",
            {
                "sessionID": session_id,
                "memoryReference": stack_reference,
                "data": base64.b64encode(requested).decode(),
                "expectedData": base64.b64encode(original).decode(),
            },
        )
        if not patch.get("verified") or patch.get("rolledBack"):
            raise RuntimeError(f"physical memory patch was not verified: {patch}")
        restored = tool(
            "apple_debug_patch_memory",
            {
                "sessionID": session_id,
                "memoryReference": stack_reference,
                "data": patch["originalData"],
                "expectedData": patch["requestedData"],
            },
        )
        if not restored.get("verified"):
            raise RuntimeError(f"physical memory rollback was not verified: {restored}")

        closed = tool("apple_debug_session_close", {"sessionID": session_id})
        session_id = None
        if not closed.get("closed"):
            raise RuntimeError("physical control session did not close")
        print(
            "ios-legacy-debug-control-smoke: breakpoint hit, evaluate, instruction step, pause/continue, memory patch/rollback, and cleanup passed"
        )
        return 0
    except Exception as error:
        print(f"ios-legacy-debug-control-smoke: {error}", file=sys.stderr)
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
