#!/usr/bin/env python3
"""Exercise the standalone MCP accessibility-tree bridge on the iOS fixture."""

import json
import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    if not server_path.is_file():
        print("ios-ui-tree-smoke: build the server first", file=sys.stderr)
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
        process.stdin.write(
            json.dumps(
                {"jsonrpc": "2.0", "id": sequence, "method": method, "params": params},
                separators=(",", ":"),
            )
            + "\n"
        )
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
                "clientInfo": {"name": "apple-debug-mcp-ui-tree-smoke", "version": "0.1.0"},
            },
        )
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()

        devices = tool("apple_simulator_list", {})
        candidates = [
            device
            for device in devices
            if "iOS" in device.get("runtime", "") and device.get("isAvailable", True)
        ]
        if not candidates:
            raise RuntimeError("no available iOS Simulator found")
        simulator_id = candidates[0]["udid"]
        started_here = candidates[0].get("state") != "Booted"

        snapshot = tool(
            "apple_simulator_ui_snapshot",
            {
                "udid": simulator_id,
                "bundleID": "com.burakkarahan.AppleDebugFixture",
                "projectPath": str(root / "Tests/Fixtures/iOSDebugApp/DebugApp.xcodeproj"),
                "scheme": "DebugApp",
                "configuration": "Debug",
            },
        )
        identifiers = {element.get("identifier") for element in snapshot.get("elements", [])}
        required = {"debug.fixture.title", "debug.fixture.subtitle"}
        if not required.issubset(identifiers):
            raise RuntimeError(f"UI tree did not contain required identifiers: {sorted(identifiers)}")
        if not snapshot.get("debugDescription"):
            raise RuntimeError("UI tree did not contain XCTest debugDescription")
        for action in (
            {"action": "typeText", "identifier": "debug.fixture.input", "text": "hello"},
            {"action": "tap", "identifier": "debug.fixture.button"},
            {"action": "swipe", "direction": "up"},
            {"action": "wait", "identifier": "debug.fixture.status"},
        ):
            action_result = tool(
                "apple_simulator_ui_action",
                {
                    "udid": simulator_id,
                    "bundleID": "com.burakkarahan.AppleDebugFixture",
                    "projectPath": str(root / "Tests/Fixtures/iOSDebugApp/DebugApp.xcodeproj"),
                    "scheme": "DebugApp",
                    "configuration": "Debug",
                    **action,
                },
            )
            if action_result.get("action") != action["action"]:
                raise RuntimeError("UI action result did not preserve the requested action")
        print(
            "ios-ui-tree-smoke: standalone MCP XCUITest bridge returned %d elements and completed tap, typeText, swipe, and wait actions for %s"
            % (len(snapshot["elements"]), simulator_id)
        )
        return 0
    except Exception as error:
        print(f"ios-ui-tree-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if simulator_id is not None and started_here:
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
