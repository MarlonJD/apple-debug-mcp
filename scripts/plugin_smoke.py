#!/usr/bin/env python3
"""Exercise safe plugin-manifest discovery through MCP."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    environment = dict(os.environ)
    environment["APPLE_DEBUG_ALLOW_PLUGIN_EXECUTION"] = "1"
    process = subprocess.Popen([str(root / ".build/debug/apple-debug-mcp")], cwd=root, env=environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-plugin-") as directory:
            manifest = {"id": "com.example.analyzer", "name": "Example Analyzer", "version": "1.0.0", "capabilities": ["binary-analysis"], "entrypoint": "cat"}
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
            process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "apple_plugin_host_plan", "arguments": {"executablePath": "/bin/echo"}}}) + "\n")
            process.stdin.flush()
            while True:
                line = process.stdout.readline()
                if not line:
                    raise RuntimeError(process.stderr.read())
                response = json.loads(line)
                if response.get("id") == 3:
                    host = json.loads(response["result"]["content"][0]["text"])
                    break
            if not host.get("executionSupported") or not host.get("sandboxRequired"):
                raise RuntimeError("plugin host plan did not report the available sandbox boundary")
            process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "apple_plugin_host_execute", "arguments": {"executablePath": "/bin/cat", "manifestPath": str(Path(directory, "example.appledebugplugin.json")), "input": "{\"hello\":\"sandbox\"}\n", "transport": "profile"}}}) + "\n")
            process.stdin.flush()
            while True:
                line = process.stdout.readline()
                if not line:
                    raise RuntimeError(process.stderr.read())
                response = json.loads(line)
                if response.get("id") == 4:
                    execution = json.loads(response["result"]["content"][0]["text"])
                    break
            if not execution.get("sandboxed") or execution.get("exitCode") != 0 or '"sandbox"' not in execution.get("stdout", ""):
                raise RuntimeError(f"sandboxed plugin execution did not return the JSON-line payload: {execution}")
            host_process = subprocess.run(
                [
                    str(root / ".build/debug/apple-debug-plugin-host"),
                    "--manifest", str(Path(directory, "example.appledebugplugin.json")),
                    "--executable", "/bin/cat",
                ],
                input="{\"hello\":\"standalone\"}\n",
                cwd=root,
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )
            if host_process.returncode != 0:
                raise RuntimeError(host_process.stderr.strip() or "standalone plugin host failed")
            standalone = json.loads(host_process.stdout)
            if not standalone.get("sandboxed") or '"standalone"' not in standalone.get("stdout", ""):
                raise RuntimeError(f"standalone plugin host did not return sandbox evidence: {standalone}")
        print("plugin-smoke: signed manifest validation and separate sandboxed plugin execution passed")
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
