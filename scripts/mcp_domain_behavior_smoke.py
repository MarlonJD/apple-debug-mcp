#!/usr/bin/env python3
"""Exercise representative success/error behavior for every MCP dispatch domain."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / ".build" / "debug" / "apple-debug-mcp"
FIXTURE = ROOT / ".build" / "fixtures" / "apple-debug-mcp-debug-target"
PROJECT = ROOT / "Tests" / "Fixtures" / "iOSDebugApp" / "DebugApp.xcodeproj"
SOURCE = ROOT / "Tests" / "Fixtures" / "iOSDebugApp" / "DebugApp.swift"
CRASH = ROOT / "Tests" / "Fixtures" / "example.crash"


class MCPDomainSmoke:
    def __init__(self, process: subprocess.Popen[str]) -> None:
        self.process = process
        self.sequence = 0

    def request(self, method: str, params: dict[str, object]) -> dict[str, object]:
        self.sequence += 1
        if self.process.stdin is None or self.process.stdout is None:
            raise RuntimeError("MCP process pipes are unavailable")
        self.process.stdin.write(
            json.dumps(
                {"jsonrpc": "2.0", "id": self.sequence, "method": method, "params": params},
                separators=(",", ":"),
            )
            + "\n"
        )
        self.process.stdin.flush()
        while True:
            line = self.process.stdout.readline()
            if not line:
                stderr = self.process.stderr.read() if self.process.stderr is not None else ""
                raise RuntimeError(f"MCP process ended unexpectedly: {stderr}")
            message = json.loads(line)
            if message.get("id") == self.sequence:
                return message

    def initialize(self) -> None:
        self.request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-domain-smoke", "version": "0.1.0"},
            },
        )
        if self.process.stdin is None:
            raise RuntimeError("MCP process stdin is unavailable")
        self.process.stdin.write(
            '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n'
        )
        self.process.stdin.flush()

    def call(self, name: str, arguments: dict[str, object] | None = None) -> dict[str, object]:
        response = self.request(
            "tools/call",
            {"name": name, "arguments": arguments or {}},
        )
        result = response.get("result")
        if not isinstance(result, dict):
            raise RuntimeError(f"{name} did not return an MCP result: {response}")
        return result

    @staticmethod
    def text(result: dict[str, object]) -> str:
        content = result.get("content")
        if not isinstance(content, list):
            raise RuntimeError(f"MCP result has no content: {result}")
        texts = [
            item.get("text")
            for item in content
            if isinstance(item, dict) and isinstance(item.get("text"), str)
        ]
        if not texts:
            raise RuntimeError(f"MCP result has no text content: {result}")
        return "\n".join(texts)

    def success(self, name: str, arguments: dict[str, object] | None = None) -> object:
        result = self.call(name, arguments)
        if result.get("isError") is True:
            raise RuntimeError(f"{name} returned an error: {self.text(result)}")
        try:
            return json.loads(self.text(result))
        except json.JSONDecodeError as error:
            raise RuntimeError(f"{name} did not return JSON content: {self.text(result)}") from error

    def error(self, name: str, arguments: dict[str, object] | None = None) -> str:
        result = self.call(name, arguments)
        if result.get("isError") is not True:
            raise RuntimeError(f"{name} unexpectedly succeeded: {result}")
        message = self.text(result).strip()
        if not message:
            raise RuntimeError(f"{name} returned an empty error")
        return message


def environment_without_mutation_grants() -> dict[str, str]:
    environment = os.environ.copy()
    for key in (
        "APPLE_DEBUG_ALLOW_DEVICE_DEBUG",
        "APPLE_DEBUG_ALLOW_DEVICE_MUTATION",
        "APPLE_DEBUG_ALLOW_EVALUATE",
        "APPLE_DEBUG_ALLOW_MEMORY_WRITE",
        "APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION",
        "APPLE_DEBUG_ALLOW_TARGET_ATTACH",
        "APPLE_DEBUG_ALLOW_TARGET_LAUNCH",
        "APPLE_DEBUG_ALLOW_VARIABLE_WRITE",
        "APPLE_DEBUG_ALLOW_XCODE_BUILD",
    ):
        environment.pop(key, None)
    return environment


def main() -> int:
    if not SERVER.is_file():
        print("mcp-domain-behavior-smoke: build .build/debug/apple-debug-mcp first", file=sys.stderr)
        return 1
    if not FIXTURE.is_file():
        print("mcp-domain-behavior-smoke: build the authorized macOS fixture first", file=sys.stderr)
        return 1

    process = subprocess.Popen(
        [str(SERVER)],
        cwd=ROOT,
        env=environment_without_mutation_grants(),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    smoke = MCPDomainSmoke(process)
    counts: dict[str, int] = {}
    session_id: str | None = None

    try:
        smoke.initialize()
        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-domain-") as directory:
            plugin_directory = Path(directory) / "plugins"
            plugin_directory.mkdir()
            (plugin_directory / "matrix.appledebugplugin.json").write_text(
                json.dumps(
                    {
                        "id": "matrix.fixture",
                        "name": "Domain Matrix Fixture",
                        "version": "1.0.0",
                        "capabilities": ["inspect"],
                    }
                ),
                encoding="utf-8",
            )

            foundation_successes = [
                ("apple_capabilities", {}),
                ("apple_debug_reverse_capabilities", {}),
                ("apple_debug_replay_capabilities", {}),
                ("apple_kernel_capabilities", {}),
                ("apple_kernel_lab_capabilities", {}),
                ("apple_toolchain_status", {}),
                ("apple_lldb_dap_initialize", {}),
                ("apple_plugin_list", {"directory": str(plugin_directory)}),
            ]
            for name, arguments in foundation_successes:
                smoke.success(name, arguments)
            counts["foundation"] = len(foundation_successes)

            artifact_successes = [
                ("apple_macho_inspect", {"path": "/bin/echo"}),
                ("apple_binary_inspect", {"path": "/bin/echo"}),
                ("apple_binary_diff", {"leftPath": "/bin/echo", "rightPath": "/bin/echo"}),
                ("apple_crash_inspect", {"path": str(CRASH)}),
                (
                    "apple_crash_symbolicate",
                    {
                        "crashPath": str(CRASH),
                        "artifacts": [
                            {
                                "imageName": "AppleDebugFixture",
                                "binaryPath": "/bin/echo",
                                "architecture": "arm64e",
                            }
                        ],
                    },
                ),
                ("apple_swift_ast_inspect", {"path": str(SOURCE), "moduleName": "DebugApp"}),
                ("apple_assemble", {"architecture": "arm64", "source": "mov x0, x0\nret\n"}),
                ("apple_control_flow", {"path": str(FIXTURE), "architecture": "arm64"}),
                (
                    "apple_patch_preview",
                    {"path": str(FIXTURE), "architecture": "arm64", "fileOffset": 0, "source": "nop\n"},
                ),
                (
                    "apple_resign_plan",
                    {
                        "inputPath": str(FIXTURE),
                        "outputPath": str(Path(directory) / "planned-output"),
                        "identity": "-",
                    },
                ),
            ]
            for name, arguments in artifact_successes:
                smoke.success(name, arguments)
            counts["artifacts"] = len(artifact_successes)

            create_payload = smoke.success("apple_debug_session_create", {})
            if not isinstance(create_payload, dict) or not isinstance(create_payload.get("sessionID"), str):
                raise RuntimeError(f"debug session create returned no session ID: {create_payload}")
            session_id = create_payload["sessionID"]

            list_payload = smoke.success("apple_debug_session_list", {})
            if not isinstance(list_payload, list) or not any(
                isinstance(item, dict) and item.get("sessionID") == session_id for item in list_payload
            ):
                raise RuntimeError(f"debug session list did not include created session: {list_payload}")

            launch_error = smoke.error(
                "apple_debug_launch",
                {"sessionID": session_id, "program": "/bin/echo"},
            )
            if "disabled" not in launch_error.lower():
                raise RuntimeError(f"debug launch did not expose its policy boundary: {launch_error}")

            close_payload = smoke.success("apple_debug_session_close", {"sessionID": session_id})
            if not isinstance(close_payload, dict) or close_payload.get("closed") is not True:
                raise RuntimeError(f"debug session close did not report closed=true: {close_payload}")
            session_id = None
            if smoke.success("apple_debug_session_list", {}) != []:
                raise RuntimeError("debug session list was not empty after close")
            counts["debugger"] = 5

            smoke.error(
                "apple_performance_analyze",
                {"tracePath": str(Path(directory) / "missing.trace")},
            )
            smoke.error(
                "apple_performance_record",
                {
                    "processID": 1,
                    "template": "Time Profiler",
                    "durationSeconds": 1,
                    "outputPath": str(Path(directory) / "missing-permission.trace"),
                },
            )
            counts["performance"] = 2

            smoke.success("apple_simulator_list", {})
            smoke.error("apple_simulator_boot", {"udid": "not-a-simulator-udid"})
            counts["simulator"] = 2

            smoke.success("apple_device_list", {})
            smoke.error("apple_device_terminate", {"identifier": "not-a-device"})
            counts["device"] = 2

            smoke.success("apple_xcode_discover", {"path": str(PROJECT)})
            smoke.error(
                "apple_xcode_build",
                {
                    "path": str(PROJECT),
                    "scheme": "DebugApp",
                    "destination": "generic/platform=iOS Simulator",
                },
            )
            counts["xcode"] = 2

        summary = ", ".join(f"{domain}={count}" for domain, count in counts.items())
        print(f"mcp-domain-behavior-smoke: representative success/error contracts passed ({summary})")
        return 0
    except Exception as error:
        print(f"mcp-domain-behavior-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if session_id is not None:
            try:
                smoke.success("apple_debug_session_close", {"sessionID": session_id})
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
