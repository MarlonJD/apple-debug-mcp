#!/usr/bin/env python3
"""Exercise the authorized macOS fixture through the MCP debugger surface."""

import json
import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server = root / ".build" / "debug" / "apple-debug-mcp"
    fixture = root / ".build" / "fixtures" / "apple-debug-mcp-debug-target"
    if not server.is_file() or not fixture.is_file():
        print("fixture-smoke: build the server and fixture before running", file=sys.stderr)
        return 1

    environment = dict(os.environ)
    environment["APPLE_DEBUG_ALLOW_TARGET_LAUNCH"] = "1"
    environment["APPLE_DEBUG_ALLOW_EVALUATE"] = "1"
    process = subprocess.Popen(
        [str(server)],
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
        assert process.stdin is not None
        process.stdin.write(
            json.dumps(
                {"jsonrpc": "2.0", "id": sequence, "method": method, "params": params},
                separators=(",", ":"),
            )
            + "\n"
        )
        process.stdin.flush()
        assert process.stdout is not None
        while True:
            line = process.stdout.readline()
            if not line:
                raise RuntimeError("MCP server exited before returning a response")
            message = json.loads(line)
            if message.get("id") == sequence:
                return message

    def tool(name: str, arguments: dict) -> dict:
        response = request(
            "tools/call",
            {"name": name, "arguments": arguments},
        )
        if response.get("result", {}).get("isError"):
            raise RuntimeError(response)
        return response

    try:
        request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-fixture-smoke", "version": "0.1.0"},
            },
        )
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()

        created = tool("apple_debug_session_create", {})
        session_id = json.loads(created["result"]["content"][0]["text"])["sessionID"]
        source_path = str(root / "Tests" / "Fixtures" / "debug_target.c")

        tool(
            "apple_debug_set_function_breakpoint",
            {"sessionID": session_id, "name": "main", "hitCondition": "1"},
        )
        tool(
            "apple_debug_set_exception_breakpoints",
            {"sessionID": session_id, "filters": ["cpp_throw"]},
        )

        breakpoint_result = tool(
            "apple_debug_set_breakpoint",
            {
                "sessionID": session_id,
                "file": source_path,
                "line": 10,
                "condition": "1 == 1",
                "hitCondition": "1",
                "logMessage": "fixture breakpoint",
            },
        )
        if "breakpoints" not in breakpoint_result["result"]["content"][0]["text"]:
            raise RuntimeError("breakpoint response did not contain breakpoints")

        tool(
            "apple_debug_launch",
            {
                "sessionID": session_id,
                "program": str(fixture),
                "stopOnEntry": True,
            },
        )
        threads = json.loads(
            tool("apple_debug_threads", {"sessionID": session_id})["result"]["content"][0]["text"]
        )["body"]["threads"]
        if not threads:
            raise RuntimeError("debugger returned no threads")
        thread_id = threads[0]["id"]
        tool("apple_debug_modules", {"sessionID": session_id, "moduleCount": 100})

        stack = json.loads(
            tool(
                "apple_debug_stack_trace",
                {"sessionID": session_id, "threadID": thread_id, "levels": 5},
            )["result"]["content"][0]["text"]
        )["body"]["stackFrames"]
        if not stack:
            raise RuntimeError("debugger returned no stack frames")
        frame_id = stack[0]["id"]
        instruction_reference = stack[0]["instructionPointerReference"]

        scopes = json.loads(
            tool("apple_debug_scopes", {"sessionID": session_id, "frameID": frame_id})["result"]["content"][0]["text"]
        )["body"]["scopes"]
        if not scopes:
            raise RuntimeError("debugger returned no frame scopes")
        variables_reference = scopes[0].get("variablesReference", 0)
        if variables_reference:
            tool(
                "apple_debug_variables",
                {"sessionID": session_id, "variablesReference": variables_reference},
            )
        registers = json.loads(
            tool("apple_debug_registers", {"sessionID": session_id, "frameID": frame_id})["result"]["content"][0]["text"]
        )
        if "scopes" not in registers:
            raise RuntimeError("register snapshot did not contain scopes")
        tool(
            "apple_debug_evaluate",
            {"sessionID": session_id, "expression": "1 + 1", "frameID": frame_id},
        )

        tool(
            "apple_debug_read_memory",
            {"sessionID": session_id, "memoryReference": instruction_reference, "count": 16},
        )
        tool(
            "apple_debug_disassemble",
            {"sessionID": session_id, "memoryReference": instruction_reference, "instructionCount": 4},
        )
        tool(
            "apple_debug_step",
            {"sessionID": session_id, "threadID": thread_id, "kind": "next"},
        )
        tool("apple_debug_continue", {"sessionID": session_id, "threadID": thread_id})
        closed = json.loads(
            tool("apple_debug_session_close", {"sessionID": session_id})["result"]["content"][0]["text"]
        )
        if not closed.get("closed"):
            raise RuntimeError("debug session did not close")
        session_id = None
        print("fixture-smoke: launch, breakpoints, exceptions, modules, threads, stack, registers, scopes, variables, evaluate, memory, disassembly, step, continue, and cleanup passed")
        return 0
    except Exception as error:
        print(f"fixture-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if session_id is not None and process.poll() is None:
            try:
                request("tools/call", {"name": "apple_debug_session_close", "arguments": {"sessionID": session_id}})
            except Exception:
                pass
        if process.stdin is not None:
            process.stdin.close()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
