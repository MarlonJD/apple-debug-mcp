#!/usr/bin/env python3
"""Exercise bounded Apple heap/leaks/sample diagnostics through MCP."""

import json
import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    target = subprocess.Popen(["sleep", "20"])
    environment = dict(os.environ)
    environment["APPLE_DEBUG_ALLOW_TARGET_ATTACH"] = "1"
    process = subprocess.Popen(
        [str(server_path)],
        cwd=root,
        env=environment,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    sequence = 0

    def request(method: str, params: dict) -> dict:
        nonlocal sequence
        sequence += 1
        assert process.stdin is not None
        process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": sequence, "method": method, "params": params}) + "\n")
        process.stdin.flush()
        assert process.stdout is not None
        while True:
            line = process.stdout.readline()
            if not line:
                raise RuntimeError(process.stderr.read())
            message = json.loads(line)
            if message.get("id") == sequence:
                return message

    try:
        request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-runtime-diagnostics-smoke", "version": "0.1.0"},
            },
        )
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()
        for tool_name, mode in (("heap", "summary"), ("leaks", "summary"), ("sample", "sample")):
            arguments = {"processID": target.pid, "tool": tool_name, "mode": mode}
            if tool_name == "sample":
                arguments.update({"durationSeconds": 1, "sampleIntervalMilliseconds": 10})
            response = request(
                "tools/call",
                {"name": "apple_debug_runtime_diagnose", "arguments": arguments},
            )
            if response.get("result", {}).get("isError"):
                raise RuntimeError(response)
            payload = json.loads(response["result"]["content"][0]["text"])
            if payload.get("tool") != tool_name or not payload.get("output"):
                raise RuntimeError(f"runtime diagnostic returned an incomplete {tool_name} report")
        print("runtime-diagnostics-smoke: heap, leaks, and sample reports returned bounded Apple diagnostics")
        return 0
    except Exception as error:
        print(f"runtime-diagnostics-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if process.stdin is not None:
            process.stdin.close()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
        if target.poll() is None:
            target.terminate()
        target.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
