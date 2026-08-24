#!/usr/bin/env python3
"""Exercise the source-backed public swiftc AST MCP tool."""

import json
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    project_path = root / "Tests" / "Fixtures" / "iOSDebugApp" / "DebugApp.xcodeproj"
    process = subprocess.Popen(
        [str(server_path)], cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    try:
        assert process.stdin is not None and process.stdout is not None
        messages = [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "swift-ast-smoke", "version": "0.1.0"}}},
            {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}},
            {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": "apple_swift_ast_inspect",
                    "arguments": {
                        "projectPath": str(project_path),
                        "scheme": "DebugApp",
                        "configuration": "Debug",
                        "destination": "generic/platform=iOS Simulator",
                    },
                },
            },
        ]
        for message in messages:
            process.stdin.write(json.dumps(message) + "\n")
        process.stdin.flush()
        while True:
            line = process.stdout.readline()
            if not line:
                assert process.stderr is not None
                raise RuntimeError(process.stderr.read())
            response = json.loads(line)
            if response.get("id") == 2:
                if response.get("result", {}).get("isError"):
                    raise RuntimeError(response)
                report = json.loads(response["result"]["content"][0]["text"])
                break
        if report.get("nodeCount", 0) <= 0 or "DebugApp" not in report.get("types", []):
            raise RuntimeError("swiftc AST report did not contain the DebugApp type")
        if "SwiftUI" not in report.get("imports", []):
            raise RuntimeError("swiftc AST report did not contain the SwiftUI import")
        if report.get("targetName") != "DebugApp" or report.get("sourcePaths", []) != [str(project_path.parent / "DebugApp.swift")]:
            raise RuntimeError("Xcode target source/module context was incomplete")
        print("swift-ast-smoke: parsed %d target-backed public swiftc AST nodes, %d types, %d functions" % (report["nodeCount"], report["typeCount"], report["functionCount"]))
        return 0
    except Exception as error:
        print(f"swift-ast-smoke: {error}", file=sys.stderr)
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
