#!/usr/bin/env python3
"""Exercise safe plugin-manifest discovery through MCP."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    process = subprocess.Popen([str(root / ".build/debug/apple-debug-mcp")], cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-plugin-") as directory:
            manifest = {"id": "com.example.analyzer", "name": "Example Analyzer", "version": "1.0.0", "capabilities": ["binary-analysis"], "entrypoint": "plugin-process"}
            Path(directory, "example.appledebugplugin.json").write_text(json.dumps(manifest))
            assert process.stdin is not None
            process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "plugin-smoke", "version": "0.1.0"}}}) + "\n")
            process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
            process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "apple_plugin_list", "arguments": {"directory": directory}}}) + "\n")
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
            if payload != [manifest]:
                raise RuntimeError(f"plugin manifest mismatch: {payload}")
        print("plugin-smoke: safe plugin manifest discovery passed without code loading")
        return 0
    except Exception as error:
        print(f"plugin-smoke: {error}", file=sys.stderr)
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
