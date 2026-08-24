#!/usr/bin/env python3
"""Exercise read-only Apple assembly generation through MCP."""

import json
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    process = subprocess.Popen(
        [str(server_path)],
        cwd=root,
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
                "clientInfo": {"name": "apple-debug-mcp-assembler-smoke", "version": "0.1.0"},
            },
        )
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()
        for architecture, source, expected in (
            ("arm64", "mov x0, x0\nret\n", "e00300aac0035fd6"),
            ("x86_64", "nop\nret\n", "90c3"),
        ):
            response = request(
                "tools/call",
                {
                    "name": "apple_assemble",
                    "arguments": {"architecture": architecture, "source": source},
                },
            )
            if response.get("result", {}).get("isError"):
                raise RuntimeError(response)
            payload = json.loads(response["result"]["content"][0]["text"])
            if payload.get("bytesHex") != expected or not payload.get("disassembly"):
                raise RuntimeError(f"assembly output mismatch for {architecture}: {payload}")
        print("assembler-smoke: arm64 and x86_64 assembly returned bytes and disassembly")
        return 0
    except Exception as error:
        print(f"assembler-smoke: {error}", file=sys.stderr)
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
