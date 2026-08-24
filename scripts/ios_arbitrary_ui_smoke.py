#!/usr/bin/env python3
"""Exercise the generated XCUITest runner against an installed Simulator app."""

import json
import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    app_path = root / ".build/ios-fixture/Build/Products/Debug-iphonesimulator/DebugApp.app"
    if not server_path.is_file() or not app_path.is_dir():
        print("ios-arbitrary-ui-smoke: build the server and iOS fixture first", file=sys.stderr)
        return 1

    environment = dict(os.environ)
    environment["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] = "1"
    process = subprocess.Popen(
        [str(server_path)],
        cwd=root,
        env=environment,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    sequence = 0
    simulator_id = None
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
                raise RuntimeError("MCP server exited before returning a response")
            message = json.loads(line)
            if message.get("id") == sequence:
                return message

    def tool(name: str, arguments: dict) -> dict:
        response = request("tools/call", {"name": name, "arguments": arguments})
        if response.get("result", {}).get("isError"):
            raise RuntimeError(response)
        return json.loads(response["result"]["content"][0]["text"])

    try:
        request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-arbitrary-ui-smoke", "version": "0.1.0"},
            },
        )
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()

        candidates = [
            device
            for device in tool("apple_simulator_list", {})
            if "iOS" in device.get("runtime", "")
            and device.get("isAvailable", True)
            and device.get("name", "").startswith("iPhone")
        ]
        if not candidates:
            raise RuntimeError("no available iOS Simulator found")
        simulator_id = candidates[0]["udid"]
        started_here = candidates[0].get("state") != "Booted"
        if started_here:
            tool("apple_simulator_boot", {"udid": simulator_id})
        tool("apple_simulator_install", {"udid": simulator_id, "appPath": str(app_path)})
        tool(
            "apple_simulator_launch",
            {"udid": simulator_id, "bundleID": "com.burakkarahan.AppleDebugFixture", "terminateRunning": True},
        )

        snapshot = tool(
            "apple_simulator_ui_probe",
            {"udid": simulator_id, "bundleID": "com.burakkarahan.AppleDebugFixture"},
        )
        identifiers = {element.get("identifier") for element in snapshot.get("elements", [])}
        if "debug.fixture.title" not in identifiers or snapshot.get("projectPath") != "generated://apple-debug-mcp-xctest-ui-probe":
            raise RuntimeError("generated UI probe did not return the installed app tree")

        action_result = tool(
            "apple_simulator_ui_probe_action",
            {
                "udid": simulator_id,
                "bundleID": "com.burakkarahan.AppleDebugFixture",
                "action": "tap",
                "identifier": "debug.fixture.button",
            },
        )
        if action_result.get("action") != "tap":
            raise RuntimeError("generated UI probe action did not preserve the action")
        coordinate_result = tool(
            "apple_simulator_ui_probe_action",
            {
                "udid": simulator_id,
                "bundleID": "com.burakkarahan.AppleDebugFixture",
                "action": "coordinateTap",
                "x": 0.5,
                "y": 0.5,
            },
        )
        if coordinate_result.get("action") != "coordinateTap":
            raise RuntimeError("generated UI probe coordinate action did not preserve the action")
        print(
            "ios-arbitrary-ui-smoke: generated XCUITest runner inspected and completed identifier/coordinate actions on an installed app (%s elements)"
            % len(snapshot.get("elements", []))
        )
        return 0
    except Exception as error:
        print(f"ios-arbitrary-ui-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if simulator_id is not None:
            try:
                tool("apple_simulator_terminate", {"udid": simulator_id, "bundleID": "com.burakkarahan.AppleDebugFixture"})
            except Exception:
                pass
            if started_here:
                try:
                    tool("apple_simulator_shutdown", {"udid": simulator_id})
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
