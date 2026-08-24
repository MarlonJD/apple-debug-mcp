#!/usr/bin/env python3
"""Exercise generic MCP Xcode test execution and xcresult summary discovery."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    project_path = root / "Tests/Fixtures/iOSDebugApp/DebugApp.xcodeproj"
    if not server_path.is_file():
        print("xcode-test-smoke: build the server first", file=sys.stderr)
        return 1

    environment = dict(os.environ)
    environment["APPLE_DEBUG_ALLOW_XCODE_BUILD"] = "1"
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
        request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-xcode-test-smoke", "version": "0.1.0"},
            },
        )
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()
        devices = tool("apple_simulator_list", {})
        candidates = [
            device for device in devices
            if "iOS" in device.get("runtime", "") and device.get("isAvailable", True)
        ]
        candidates.sort(key=lambda device: (0 if "iPhone" in device.get("name", "") else 1, device["udid"]))
        if not candidates:
            raise RuntimeError("no available iOS Simulator found")
        simulator_id = candidates[0]["udid"]
        started_here = candidates[0].get("state") != "Booted"
        if started_here:
            tool("apple_simulator_boot", {"udid": simulator_id})
        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-xcode-test-") as directory:
            result = tool(
                "apple_xcode_test",
                {
                    "path": str(project_path),
                    "scheme": "DebugApp",
                    "configuration": "Debug",
                    "destination": f"platform=iOS Simulator,id={simulator_id}",
                    "derivedDataPath": str(Path(directory) / "DerivedData"),
                    "resultBundlePath": str(Path(directory) / "Tests.xcresult"),
                    "codeSigningAllowed": False,
                },
            )
            if not Path(result["resultBundlePath"]).is_dir():
                raise RuntimeError(f"xcresult bundle was not created: {result}")
            if result.get("summary") is None:
                raise RuntimeError(f"xcresult summary was missing: {result}")
        print(f"xcode-test-smoke: generic MCP test returned xcresult summary for {simulator_id}")
        return 0
    except Exception as error:
        print(f"xcode-test-smoke: {error}", file=sys.stderr)
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
