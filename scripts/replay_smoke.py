#!/usr/bin/env python3
"""Exercise checkpoint capture and source-location replay on the macOS fixture."""

import json
import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server = root / ".build" / "debug" / "apple-debug-mcp"
    fixture = root / ".build" / "fixtures" / "apple-debug-mcp-debug-target"
    if not server.is_file() or not fixture.is_file():
        print("replay-smoke: build the server and fixture before running", file=sys.stderr)
        return 1

    environment = dict(os.environ)
    environment["APPLE_DEBUG_ALLOW_TARGET_LAUNCH"] = "1"
    process = subprocess.Popen(
        [str(server)],
        cwd=root,
        env=environment,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    sequence = 0
    session_id = None
    checkpoint_path = None

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
                stderr = process.stderr.read() if process.stderr is not None else ""
                raise RuntimeError(f"server exited: {stderr[:2_000]}")
            message = json.loads(line)
            if message.get("id") == sequence:
                return message

    def tool(name: str, arguments: dict) -> dict:
        response = request("tools/call", {"name": name, "arguments": arguments})
        if response.get("result", {}).get("isError"):
            raise RuntimeError(f"{name} failed: {response}")
        return json.loads(response["result"]["content"][0]["text"])

    try:
        request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-replay-smoke", "version": "0.1.0"},
            },
        )
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()

        session_id = tool("apple_debug_session_create", {})["sessionID"]
        source_path = str(root / "Tests" / "Fixtures" / "debug_target.c")
        tool(
            "apple_debug_set_breakpoint",
            {"sessionID": session_id, "file": source_path, "line": 10},
        )
        tool(
            "apple_debug_launch",
            {
                "sessionID": session_id,
                "program": str(fixture),
                "stopOnEntry": False,
            },
        )
        wait = tool(
            "apple_debug_wait_for_stop",
            {"sessionID": session_id, "timeoutMilliseconds": 10_000},
        )
        if not wait.get("stopped"):
            raise RuntimeError(f"fixture did not stop at the replay checkpoint: {wait}")

        checkpoint = tool(
            "apple_debug_checkpoint",
            {
                "sessionID": session_id,
                "label": "fixture-main-breakpoint",
                "determinismManifest": {
                    "fixture": "debug_target.c",
                    "seed": "fixed-smoke-seed",
                },
            },
        )
        checkpoint_path = Path(checkpoint["outputPath"])
        replay = tool(
            "apple_debug_replay",
            {
                "sessionID": session_id,
                "checkpointPath": str(checkpoint_path),
                "timeoutMilliseconds": 10_000,
            },
        )
        if not replay.get("replayed") or replay.get("exactStateRestored"):
            raise RuntimeError(f"checkpoint replay contract was incorrect: {replay}")
        if not replay.get("wait", {}).get("stopped"):
            raise RuntimeError(f"replay did not stop at the recorded source location: {replay}")

        closed = tool("apple_debug_session_close", {"sessionID": session_id})
        if not closed.get("closed"):
            raise RuntimeError("replay debug session did not close")
        session_id = None
        print("replay-smoke: checkpoint capture, local relaunch, source-location replay, and explicit non-restoration boundary passed")
        return 0
    except Exception as error:
        print(f"replay-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if session_id is not None and process.poll() is None:
            try:
                request("tools/call", {"name": "apple_debug_session_close", "arguments": {"sessionID": session_id}})
            except Exception:
                pass
        if checkpoint_path is not None:
            try:
                checkpoint_path.unlink()
            except FileNotFoundError:
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
