#!/usr/bin/env python3
"""Exercise read-only Apple signing/entitlement audit through MCP."""

import json
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    process = subprocess.Popen([str(root / ".build/debug/apple-debug-mcp")], cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        assert process.stdin is not None
        process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "signing-audit-smoke", "version": "0.1.0"}}}) + "\n")
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "apple_signing_audit", "arguments": {"path": "/bin/echo"}}}) + "\n")
        process.stdin.flush()
        assert process.stdout is not None
        while True:
            line = process.stdout.readline()
            if not line:
                raise RuntimeError(process.stderr.read())
            response = json.loads(line)
            if response.get("id") == 2:
                if response.get("result", {}).get("isError"):
                    raise RuntimeError(response)
                payload = json.loads(response["result"]["content"][0]["text"])
                break
        if not payload.get("identifier") or not isinstance(payload.get("entitlements"), (dict, type(None))):
            raise RuntimeError("signing audit returned incomplete identity/entitlement data")
        print("signing-audit-smoke: codesign identity, entitlement, authority, and Gatekeeper fields returned")
        return 0
    except Exception as error:
        print(f"signing-audit-smoke: {error}", file=sys.stderr)
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
