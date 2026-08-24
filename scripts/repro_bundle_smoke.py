#!/usr/bin/env python3
"""Exercise reproducible Simulator evidence bundle capture."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    app_path = root / ".build/ios-fixture/Build/Products/Debug-iphonesimulator/DebugApp.app"
    env = dict(os.environ)
    env["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] = "1"
    process = subprocess.Popen([str(root / ".build/debug/apple-debug-mcp")], cwd=root, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    sequence = 0
    udid = None
    started_here = False

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
        request("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "repro-bundle-smoke", "version": "0.1.0"}})
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()
        devices = [device for device in tool("apple_simulator_list", {}) if device.get("name", "").startswith("iPhone") and device.get("isAvailable", True)]
        if not devices:
            raise RuntimeError("no available iPhone Simulator")
        device = devices[0]
        udid = device["udid"]
        started_here = device.get("state") != "Booted"
        if started_here:
            tool("apple_simulator_boot", {"udid": udid})
        tool("apple_simulator_install", {"udid": udid, "appPath": str(app_path)})
        tool("apple_simulator_launch", {"udid": udid, "bundleID": "com.burakkarahan.AppleDebugFixture", "terminateRunning": True})
        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-repro-") as temp:
            output = str(Path(temp) / "bundle")
            result = tool("apple_simulator_repro_bundle", {"udid": udid, "bundleID": "com.burakkarahan.AppleDebugFixture", "outputDirectory": output, "includeLogs": False})
            files = set(result.get("manifest", {}).get("files", []))
            if not {"manifest.json", "screenshot.png", "appinfo.txt"}.issubset(files):
                raise RuntimeError(f"repro bundle is incomplete: {result}")
            if not (Path(output) / "screenshot.png").is_file():
                raise RuntimeError("repro bundle screenshot is missing")
        print(f"repro-bundle-smoke: screenshot, appinfo, and manifest bundle captured for {udid}")
        return 0
    except Exception as error:
        print(f"repro-bundle-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if udid is not None:
            try:
                tool("apple_simulator_terminate", {"udid": udid, "bundleID": "com.burakkarahan.AppleDebugFixture"})
            except Exception:
                pass
            if started_here:
                try:
                    tool("apple_simulator_shutdown", {"udid": udid})
                except Exception:
                    pass
        if process.stdin is not None:
            process.stdin.close()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
