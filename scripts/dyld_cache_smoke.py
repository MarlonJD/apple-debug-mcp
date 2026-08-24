#!/usr/bin/env python3
"""Verify bounded dyld shared-cache discovery and truthful empty-environment reporting."""

import json
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    process = subprocess.Popen([str(root / ".build/debug/apple-debug-mcp")], cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        assert process.stdin is not None
        process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "dyld-cache-smoke", "version": "0.1.0"}}}) + "\n")
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "apple_dyld_shared_cache_discover", "arguments": {}}}) + "\n")
        process.stdin.flush()
        assert process.stdout is not None
        while True:
            line = process.stdout.readline()
            if not line:
                raise RuntimeError(process.stderr.read())
            response = json.loads(line)
            if response.get("id") == 2:
                payload = json.loads(response["result"]["content"][0]["text"])
                break
        if not payload.get("searchedRoots") or not isinstance(payload.get("candidates"), list):
            raise RuntimeError("dyld cache discovery report was incomplete")
        if len(payload["searchedRoots"]) < 4 or not payload.get("notes") or not isinstance(payload.get("runtimeHelpers"), list):
            raise RuntimeError("dyld cache discovery did not explain bounded mount/helper state")
        print(
            "dyld-cache-smoke: searched %d bounded roots; candidates=%d, runtimeHelpers=%d, utilityAvailable=%s"
            % (
                len(payload["searchedRoots"]),
                len(payload["candidates"]),
                len(payload["runtimeHelpers"]),
                payload.get("utilityAvailable"),
            )
        )
        return 0
    except Exception as error:
        print(f"dyld-cache-smoke: {error}", file=sys.stderr)
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
