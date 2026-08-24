#!/usr/bin/env python3
"""Capture a real Swift Concurrency trace and build its public task graph."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    fixture = root / "Tests" / "Fixtures" / "swift_concurrency_target.swift"
    if not server_path.is_file():
        print("swift-concurrency-graph-smoke: build the server first", file=sys.stderr)
        return 1

    environment = dict(os.environ)
    environment["APPLE_DEBUG_ALLOW_TARGET_ATTACH"] = "1"
    target = None
    server = None
    sequence = 0

    try:
        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-swift-concurrency-") as directory:
            directory_path = Path(directory)
            target_binary = directory_path / "swift-concurrency-target"
            compile_result = subprocess.run(
                ["xcrun", "swiftc", "-parse-as-library", str(fixture), "-o", str(target_binary)],
                cwd=root,
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )
            if compile_result.returncode != 0:
                raise RuntimeError(compile_result.stderr.strip() or "swift concurrency fixture compilation failed")

            target = subprocess.Popen(
                [str(target_binary)],
                cwd=root,
                env=environment,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            server = subprocess.Popen(
                [str(server_path)],
                cwd=root,
                env=environment,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )

            def request(method: str, params: dict) -> dict:
                nonlocal sequence
                sequence += 1
                assert server is not None and server.stdin is not None and server.stdout is not None
                server.stdin.write(json.dumps({"jsonrpc": "2.0", "id": sequence, "method": method, "params": params}) + "\n")
                server.stdin.flush()
                while True:
                    line = server.stdout.readline()
                    if not line:
                        assert server.stderr is not None
                        raise RuntimeError(server.stderr.read())
                    message = json.loads(line)
                    if message.get("id") == sequence:
                        return message

            request(
                "initialize",
                {
                    "protocolVersion": "2025-11-25",
                    "capabilities": {},
                    "clientInfo": {"name": "apple-debug-mcp-swift-concurrency-graph-smoke", "version": "0.1.0"},
                },
            )
            assert server.stdin is not None
            server.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
            server.stdin.flush()

            trace_path = directory_path / "swift-concurrency.trace"
            response = request(
                "tools/call",
                {
                    "name": "apple_performance_record",
                    "arguments": {
                        "processID": target.pid,
                        "template": "Swift Concurrency",
                        "durationSeconds": 2,
                        "outputPath": str(trace_path),
                    },
                },
            )
            if response.get("result", {}).get("isError"):
                raise RuntimeError(response)

            response = request(
                "tools/call",
                {
                    "name": "apple_swift_concurrency_graph",
                    "arguments": {"tracePath": str(trace_path), "maximumRows": 5_000},
                },
            )
            if response.get("result", {}).get("isError"):
                raise RuntimeError(response)
            payload = json.loads(response["result"]["content"][0]["text"])
            nodes = payload.get("nodes", [])
            edges = payload.get("edges", [])
            kinds = {node.get("kind") for node in nodes}
            edge_kinds = {edge.get("kind") for edge in edges}
            if not payload.get("liveDataAvailable") or payload.get("sampleCount", 0) <= 0:
                raise RuntimeError("Swift Concurrency export returned no graph rows")
            if "task" not in kinds or "actor" not in kinds:
                raise RuntimeError(f"Swift Concurrency graph kinds were incomplete: {sorted(kinds)}")
            if "executes" not in edge_kinds:
                raise RuntimeError(f"Swift Concurrency graph returned no actor/task edge: {sorted(edge_kinds)}")
            print(
                "swift-concurrency-graph-smoke: "
                f"parsed {payload['sampleCount']} rows, {len(nodes)} nodes, {len(edges)} edges"
            )
            return 0
    except Exception as error:
        print(f"swift-concurrency-graph-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if server is not None:
            if server.stdin is not None:
                server.stdin.close()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=10)
        if target is not None and target.poll() is None:
            target.terminate()
            try:
                target.wait(timeout=5)
            except subprocess.TimeoutExpired:
                target.kill()
                target.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
