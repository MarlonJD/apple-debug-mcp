#!/usr/bin/env python3
"""Exercise typed vmmap capture, snapshot persistence, and region diffing."""

import json
from pathlib import Path
import os
import subprocess
import sys
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    target = subprocess.Popen(["sleep", "20"])
    env = dict(os.environ)
    env["APPLE_DEBUG_ALLOW_TARGET_ATTACH"] = "1"
    process = subprocess.Popen([str(server_path)], cwd=root, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
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

    def tool(name: str, arguments: dict) -> dict:
        response = request("tools/call", {"name": name, "arguments": arguments})
        if response.get("result", {}).get("isError"):
            raise RuntimeError(response)
        return json.loads(response["result"]["content"][0]["text"])

    try:
        request("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "memory-map-smoke", "version": "0.1.0"}})
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()
        report = tool("apple_debug_memory_analyze", {"processID": target.pid})
        if not report.get("regions"):
            raise RuntimeError("typed vmmap report returned no regions")
        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-memory-") as directory:
            left = str(Path(directory) / "left.json")
            right = str(Path(directory) / "right.json")
            tool("apple_debug_memory_snapshot", {"processID": target.pid, "outputPath": left})
            tool("apple_debug_memory_snapshot", {"processID": target.pid, "outputPath": right})
            diff = tool("apple_debug_memory_diff", {"leftPath": left, "rightPath": right})
            if not isinstance(diff.get("added"), list) or not isinstance(diff.get("changed"), list):
                raise RuntimeError("memory snapshot diff was not typed")
        print("memory-map-smoke: typed vmmap regions, persisted snapshots, and region diff returned")
        return 0
    except Exception as error:
        print(f"memory-map-smoke: {error}", file=sys.stderr)
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
