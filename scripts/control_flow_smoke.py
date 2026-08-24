#!/usr/bin/env python3
"""Exercise Mach-O control-flow and call-graph extraction through MCP."""

import json
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    fixture = root / ".build/fixtures/apple-debug-mcp-debug-target"
    process = subprocess.Popen(
        [str(server_path)], cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
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
            {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "control-flow-smoke", "version": "0.1.0"}},
        )
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()
        response = request(
            "tools/call",
            {"name": "apple_control_flow", "arguments": {"path": str(fixture), "architecture": "arm64"}},
        )
        if response.get("result", {}).get("isError"):
            raise RuntimeError(response)
        payload = json.loads(response["result"]["content"][0]["text"])
        if not payload.get("functions") or not any(function.get("blocks") for function in payload["functions"]):
            raise RuntimeError("control-flow report did not contain basic blocks")
        if "_usleep" not in payload.get("externalCalls", []):
            raise RuntimeError("control-flow report did not contain the fixture external call")
        if not any(symbol.get("name") == "_usleep" for symbol in payload.get("indirectSymbols", [])):
            raise RuntimeError("control-flow report did not contain indirect symbol/xref evidence")
        print("control-flow-smoke: Mach-O instructions, basic blocks, and external call graph returned")
        return 0
    except Exception as error:
        print(f"control-flow-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if process.stdin is not None:
            process.stdin.close()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
