#!/usr/bin/env python3
"""Exercise bounded host xctrace capture through the MCP surface."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    target = subprocess.Popen(["sleep", "15"])
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
                "clientInfo": {"name": "apple-debug-mcp-performance-smoke", "version": "0.1.0"},
            },
        )
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()
        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-trace-") as directory:
            trace_path = Path(directory) / "profile.trace"
            response = request(
                "tools/call",
                {
                    "name": "apple_performance_record",
                    "arguments": {
                        "processID": target.pid,
                        "template": "Time Profiler",
                        "durationSeconds": 2,
                        "outputPath": str(trace_path),
                    },
                },
            )
            if response.get("result", {}).get("isError"):
                raise RuntimeError(response)
            payload = json.loads(response["result"]["content"][0]["text"])
            if not trace_path.is_dir() or not any(trace_path.iterdir()):
                raise RuntimeError(f"xctrace did not produce a trace bundle: {payload}")
        print("performance-trace-smoke: bounded host Time Profiler trace bundle captured")
        return 0
    except Exception as error:
        print(f"performance-trace-smoke: {error}", file=sys.stderr)
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
