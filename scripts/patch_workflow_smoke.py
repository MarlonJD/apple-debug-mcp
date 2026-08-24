#!/usr/bin/env python3
"""Exercise non-destructive patch preview and re-sign planning through MCP."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    fixture = root / ".build/fixtures/apple-debug-mcp-debug-target"
    process = subprocess.Popen([str(root / ".build/debug/apple-debug-mcp")], cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
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
            response = json.loads(line)
            if response.get("id") == sequence:
                return response

    try:
        request("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "patch-workflow-smoke", "version": "0.1.0"}})
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()
        preview = request("tools/call", {"name": "apple_patch_preview", "arguments": {"path": str(fixture), "architecture": "arm64", "fileOffset": 0, "source": "nop\n"}})
        if preview.get("result", {}).get("isError"):
            raise RuntimeError(preview)
        preview_payload = json.loads(preview["result"]["content"][0]["text"])
        if preview_payload.get("applied") or not isinstance(preview_payload.get("changes"), list):
            raise RuntimeError("patch preview was not non-destructive/typed")
        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-resign-") as directory:
            plan = request("tools/call", {"name": "apple_resign_plan", "arguments": {"inputPath": str(fixture), "outputPath": str(Path(directory) / "patched.app"), "identity": "-"}})
            if plan.get("result", {}).get("isError"):
                raise RuntimeError(plan)
            plan_payload = json.loads(plan["result"]["content"][0]["text"])
            if plan_payload.get("executionSupported") or len(plan_payload.get("commands", [])) < 3:
                raise RuntimeError("re-sign plan did not fail closed or include verification commands")
        print("patch-workflow-smoke: non-destructive assembly preview and re-sign plan passed")
        return 0
    except Exception as error:
        print(f"patch-workflow-smoke: {error}", file=sys.stderr)
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
