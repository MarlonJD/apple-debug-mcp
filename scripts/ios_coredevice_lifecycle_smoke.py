#!/usr/bin/env python3
"""Exercise authorized CoreDevice process lifecycle operations through MCP."""

import json
import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    device_identifier = os.environ.get("APPLE_DEBUG_COREDEVICE_ID", "")
    app_path = os.environ.get(
        "APPLE_DEBUG_PHYSICAL_APP",
        str(root / ".build" / "ios-physical-fixture" / "Build" / "Products" / "Debug-iphoneos" / "DebugApp.app"),
    )
    if os.environ.get("APPLE_DEBUG_ALLOW_DEVICE_MUTATION") != "1":
        print("ios-coredevice-lifecycle-smoke: set APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1", file=sys.stderr)
        return 1
    if not device_identifier or not Path(app_path).is_dir():
        print("ios-coredevice-lifecycle-smoke: set APPLE_DEBUG_COREDEVICE_ID and provide a signed .app", file=sys.stderr)
        return 1

    server = subprocess.Popen(
        [str(server_path)],
        cwd=root,
        env=dict(os.environ),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    sequence = 0
    process_id = None

    def request(method: str, params: dict) -> dict:
        nonlocal sequence
        sequence += 1
        if server.stdin is None or server.stdout is None:
            raise RuntimeError("MCP server pipes are unavailable")
        server.stdin.write(json.dumps({"jsonrpc": "2.0", "id": sequence, "method": method, "params": params}) + "\n")
        server.stdin.flush()
        while True:
            line = server.stdout.readline()
            if not line:
                stderr = server.stderr.read() if server.stderr else ""
                raise RuntimeError(f"MCP server exited: {stderr[-4_000:]}")
            message = json.loads(line)
            if message.get("id") == sequence:
                return message

    def tool(name: str, arguments: dict):
        response = request("tools/call", {"name": name, "arguments": arguments})
        if response.get("result", {}).get("isError"):
            raise RuntimeError(json.dumps(response))
        return json.loads(response["result"]["content"][0]["text"])

    try:
        request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-coredevice-lifecycle-smoke", "version": "0.1.0"},
            },
        )
        if server.stdin is None:
            raise RuntimeError("MCP server stdin is unavailable")
        server.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        server.stdin.flush()

        inventory = tool("apple_device_list", {})
        device = next((item for item in inventory if item.get("identifier") == device_identifier), None)
        if not device or not device.get("isAuthorizedForDevelopment"):
            raise RuntimeError(f"CoreDevice is not authorized: {device}")

        launch = tool(
            "apple_device_launch",
            {
                "identifier": device_identifier,
                "bundleID": "com.burakkarahan.AppleDebugFixture",
                "startStopped": True,
                "appPath": app_path,
            },
        )
        process_id = launch.get("processID")
        if not isinstance(process_id, int) or process_id <= 0:
            raise RuntimeError(f"CoreDevice launch did not return a process ID: {launch}")

        processes = tool("apple_device_processes", {"identifier": device_identifier})
        if not any(item.get("processID") == process_id for item in processes):
            raise RuntimeError(f"Launched process was missing from CoreDevice inventory: {process_id}")

        tool("apple_device_resume", {"identifier": device_identifier, "processID": process_id})
        tool("apple_device_suspend", {"identifier": device_identifier, "processID": process_id})
        tool("apple_device_resume", {"identifier": device_identifier, "processID": process_id})
        terminated = tool(
            "apple_device_terminate",
            {"identifier": device_identifier, "processID": process_id},
        )
        if terminated.get("processID") != process_id:
            raise RuntimeError(f"CoreDevice terminate result did not identify the process: {terminated}")
        process_id = None
        print("ios-coredevice-lifecycle-smoke: process inventory, launch PID, resume, suspend, resume, terminate, and cleanup passed")
        return 0
    except Exception as error:
        print(f"ios-coredevice-lifecycle-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if process_id is not None:
            try:
                subprocess.run(
                    [
                        "xcrun", "devicectl", "device", "process", "terminate",
                        "--device", device_identifier, "--pid", str(process_id), "--quiet",
                    ],
                    check=False,
                    timeout=30,
                )
            except (OSError, subprocess.TimeoutExpired):
                pass
        if server.stdin is not None:
            server.stdin.close()
        try:
            server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=10)


if __name__ == "__main__":
    raise SystemExit(main())
