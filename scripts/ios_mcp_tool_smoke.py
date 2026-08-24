#!/usr/bin/env python3
"""Exercise the public MCP Simulator lifecycle and artifact tools end to end."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    if not server_path.is_file():
        print("ios-mcp-tool-smoke: build the server first", file=sys.stderr)
        return 1

    app_path = subprocess.check_output(
        [str(root / "scripts" / "build_ios_fixture.sh")],
        cwd=root,
        text=True,
    ).strip().splitlines()[-1]
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
    session_id = None
    simulator_id = None
    started_here = False
    screenshot_path = None
    video_path = None

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
                "clientInfo": {"name": "apple-debug-mcp-ios-tool-smoke", "version": "0.1.0"},
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
        candidates.sort(key=lambda device: (0 if "iPhone" in device.get("name", "") else 1, device["udid"]))
        simulator_id = candidates[0]["udid"]
        started_here = candidates[0].get("state") != "Booted"
        if started_here:
            tool("apple_simulator_boot", {"udid": simulator_id})
            subprocess.run(
                ["xcrun", "simctl", "bootstatus", simulator_id, "-b"],
                cwd=root,
                check=True,
                stdout=subprocess.DEVNULL,
            )

        tool("apple_simulator_install", {"udid": simulator_id, "appPath": app_path})
        launch = tool(
            "apple_simulator_launch",
            {
                "udid": simulator_id,
                "bundleID": "com.burakkarahan.AppleDebugFixture",
                "arguments": ["--mcp-tool-smoke"],
                "terminateRunning": True,
                "waitForDebugger": True,
            },
        )
        if not launch.get("output"):
            raise RuntimeError("Simulator launch returned no process output")

        info = tool(
            "apple_simulator_app_info",
            {"udid": simulator_id, "bundleID": "com.burakkarahan.AppleDebugFixture"},
        )
        if not info.get("output"):
            raise RuntimeError("Simulator app_info returned no metadata")
        container = tool(
            "apple_simulator_get_app_container",
            {
                "udid": simulator_id,
                "bundleID": "com.burakkarahan.AppleDebugFixture",
                "container": "data",
            },
        )
        if not container.get("path"):
            raise RuntimeError("Simulator data container path was empty")

        with tempfile.NamedTemporaryFile(prefix="apple-debug-mcp-", suffix=".png", delete=False) as handle:
            screenshot_path = Path(handle.name)
        screenshot_path.unlink()
        tool(
            "apple_simulator_screenshot",
            {"udid": simulator_id, "path": str(screenshot_path)},
        )
        if not screenshot_path.is_file() or screenshot_path.stat().st_size == 0:
            raise RuntimeError("Simulator MCP screenshot was missing or empty")
        tool(
            "apple_simulator_set_location",
            {"udid": simulator_id, "latitude": 37.3349, "longitude": -122.0090},
        )
        tool("apple_simulator_clear_location", {"udid": simulator_id})
        with tempfile.NamedTemporaryFile(prefix="apple-debug-mcp-", suffix=".mov", delete=False) as handle:
            video_path = Path(handle.name)
        video_path.unlink()
        tool(
            "apple_simulator_record_video",
            {
                "udid": simulator_id,
                "path": str(video_path),
                "durationSeconds": 1,
                "codec": "h264",
            },
        )
        if not video_path.is_file() or video_path.stat().st_size == 0:
            raise RuntimeError("Simulator MCP video recording was missing or empty")
        logs = tool(
            "apple_log_show",
            {
                "target": simulator_id,
                "last": "1s",
                "predicate": "process == \"DebugApp\"",
            },
        )
        if "output" not in logs:
            raise RuntimeError("Simulator unified-log result was malformed")
        tool(
            "apple_simulator_terminate",
            {"udid": simulator_id, "bundleID": "com.burakkarahan.AppleDebugFixture"},
        )
        print(
            "ios-mcp-tool-smoke: MCP list, boot, install, launch flags, app info, container, screenshot, location, video, logs, terminate, and cleanup passed for %s"
            % simulator_id
        )
        return 0
    except Exception as error:
        print(f"ios-mcp-tool-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if simulator_id is not None:
            try:
                tool(
                    "apple_simulator_terminate",
                    {"udid": simulator_id, "bundleID": "com.burakkarahan.AppleDebugFixture"},
                )
            except Exception:
                pass
            if started_here:
                try:
                    tool("apple_simulator_shutdown", {"udid": simulator_id})
                except Exception:
                    pass
        if screenshot_path is not None:
            screenshot_path.unlink(missing_ok=True)
        if video_path is not None:
            video_path.unlink(missing_ok=True)
        if process.stdin is not None:
            process.stdin.close()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
