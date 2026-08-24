#!/usr/bin/env python3
"""Exercise generic Xcode dSYM discovery and bounded DWARF inspection."""

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
        print("dwarf-smoke: build the server first", file=sys.stderr)
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
                raise RuntimeError(process.stderr.read())
            message = json.loads(line)
            if message.get("id") == sequence:
                return message

    try:
        request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-dwarf-smoke", "version": "0.1.0"},
            },
        )
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()

        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-dwarf-") as directory:
            response = request(
                "tools/call",
                {
                    "name": "apple_xcode_build",
                    "arguments": {
                        "path": str(project_path),
                        "scheme": "DebugApp",
                        "configuration": "Debug",
                        "destination": "generic/platform=iOS Simulator",
                        "derivedDataPath": str(Path(directory) / "DerivedData"),
                    },
                },
            )
            if response.get("result", {}).get("isError"):
                raise RuntimeError(response)
            build_payload = json.loads(response["result"]["content"][0]["text"])
            dwarf_paths = [
                artifact["path"]
                for artifact in build_payload.get("artifacts", [])
                if artifact.get("kind") == "dSYM" and artifact.get("exists")
            ]
            if not dwarf_paths:
                raise RuntimeError(f"Xcode build did not return an existing dSYM: {build_payload}")

            response = request(
                "tools/call",
                {
                    "name": "apple_dwarf_inspect",
                    "arguments": {
                        "path": dwarf_paths[0],
                        "architecture": "x86_64",
                        "name": "DebugApp",
                        "depth": 4,
                        "includeSources": True,
                        "includeStatistics": True,
                        "includeLineTable": True,
                        "includeRaw": False,
                    },
                },
            )
            if response.get("result", {}).get("isError"):
                raise RuntimeError(response)
            payload = json.loads(response["result"]["content"][0]["text"])
            entries = payload.get("entries", [])
            names = {entry.get("name") for entry in entries}
            if "DebugApp" not in names:
                raise RuntimeError(f"DWARF report did not contain the queried type (entries={len(entries)})")
            if not any(path.endswith("DebugApp.swift") for path in payload.get("sources", [])):
                raise RuntimeError("DWARF report did not contain the fixture source")
            if not isinstance(payload.get("statistics"), dict):
                raise RuntimeError("DWARF report did not contain parsed statistics")
            if not payload.get("lineEntries"):
                raise RuntimeError("DWARF report did not contain parsed line-table rows")

        print("dwarf-smoke: generic Xcode dSYM returned typed entries, source paths, and statistics")
        return 0
    except Exception as error:
        print(f"dwarf-smoke: {error}", file=sys.stderr)
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
