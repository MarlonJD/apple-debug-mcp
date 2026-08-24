#!/usr/bin/env python3
"""Exercise bounded Simulator environment controls through MCP."""

import json
import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
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
        request("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "simulator-environment-smoke", "version": "0.1.0"}})
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
        tool("apple_simulator_environment", {"udid": udid, "operation": "ui_set", "service": "appearance", "value": "dark"})
        appearance = tool("apple_simulator_environment", {"udid": udid, "operation": "ui_get", "value": "appearance"})
        tool("apple_simulator_environment", {"udid": udid, "operation": "status_bar_override", "statusOverrides": {"wifiBars": "3", "batteryLevel": "87"}})
        tool("apple_simulator_environment", {"udid": udid, "operation": "status_bar_list"})
        tool("apple_simulator_environment", {"udid": udid, "operation": "status_bar_clear"})
        tool("apple_simulator_environment", {"udid": udid, "operation": "pasteboard_set", "value": "apple-debug-mcp"})
        pasteboard = tool("apple_simulator_environment", {"udid": udid, "operation": "pasteboard_get"})
        tool("apple_simulator_environment", {"udid": udid, "operation": "list_apps"})
        tool("apple_simulator_environment", {"udid": udid, "operation": "privacy", "value": "reset", "service": "all"})
        if "dark" not in appearance.get("output", "") or "apple-debug-mcp" not in pasteboard.get("output", ""):
            raise RuntimeError("Simulator environment controls did not return expected state")
        print(f"simulator-environment-smoke: UI, status-bar, pasteboard, apps, and privacy controls passed for {udid}")
        return 0
    except Exception as error:
        print(f"simulator-environment-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if udid is not None and started_here:
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
