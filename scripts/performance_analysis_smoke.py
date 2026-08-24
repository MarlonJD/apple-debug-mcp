#!/usr/bin/env python3
"""Exercise xctrace export parsing, hotspots, and folded flame-stack output."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    if not server_path.is_file():
        print("performance-analysis-smoke: build the server first", file=sys.stderr)
        return 1

    target = subprocess.Popen(["yes"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
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
                "clientInfo": {"name": "apple-debug-mcp-performance-analysis-smoke", "version": "0.1.0"},
            },
        )
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()

        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-analysis-") as directory:
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

            response = request(
                "tools/call",
                {
                    "name": "apple_performance_analyze",
                    "arguments": {
                        "tracePath": str(trace_path),
                        "schema": "time-profile",
                        "maximumRows": 300,
                        "includeRows": True,
                    },
                },
            )
            if response.get("result", {}).get("isError"):
                raise RuntimeError(response)
            payload = json.loads(response["result"]["content"][0]["text"])
            if payload.get("sampleCount", 0) <= 0 or not payload.get("rows"):
                raise RuntimeError("xctrace parser returned no Time Profiler rows")
            if not payload.get("hotspots"):
                raise RuntimeError("xctrace parser returned no hotspots")
            if not payload.get("flameStacks"):
                raise RuntimeError("xctrace parser returned no folded flame stacks")
            if payload.get("summary", {}).get("templateName") != "Time Profiler":
                raise RuntimeError("xctrace parser did not decode the trace summary")

        print("performance-analysis-smoke: xctrace XML produced rows, hotspots, and folded flame stacks")
        return 0
    except Exception as error:
        print(f"performance-analysis-smoke: {error}", file=sys.stderr)
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
