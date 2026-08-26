#!/usr/bin/env python3
"""Exercise per-client debugger ownership through the authenticated daemon."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

from mcp_daemon_smoke import delete_mcp, post_mcp, post_mcp_status, shutdown


ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / ".build" / "debug" / "apple-debug-mcp"
FIXTURE = ROOT / ".build" / "fixtures" / "apple-debug-mcp-debug-target"


def initialize(endpoint: dict[str, object], token: str, client_name: str) -> str:
    response, session_id = post_mcp(
        endpoint,
        token,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": client_name, "version": "0.1.0"},
            },
        },
    )
    if "result" not in response or not session_id:
        raise RuntimeError(f"MCP initialize failed for {client_name}: {response}")
    return session_id


def call_tool(
    endpoint: dict[str, object],
    token: str,
    session_id: str,
    name: str,
    arguments: dict[str, object],
) -> dict[str, object]:
    response, returned_session_id = post_mcp(
        endpoint,
        token,
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {"name": name, "arguments": arguments},
        },
        session_id,
    )
    if returned_session_id != session_id:
        raise RuntimeError(f"MCP session ID changed while calling {name}: {response}")
    if "result" not in response:
        raise RuntimeError(f"MCP call did not return a result for {name}: {response}")
    return response


def result_json(response: dict[str, object]) -> dict[str, object] | list[object]:
    result = response["result"]
    if not isinstance(result, dict) or result.get("isError"):
        raise RuntimeError(f"MCP tool returned an error: {response}")
    content = result.get("content")
    if not isinstance(content, list) or not content:
        raise RuntimeError(f"MCP tool returned no content: {response}")
    first = content[0]
    if not isinstance(first, dict) or not isinstance(first.get("text"), str):
        raise RuntimeError(f"MCP tool returned non-text content: {response}")
    return json.loads(first["text"])


def process_commands_containing(path: str) -> list[str]:
    output = subprocess.check_output(["ps", "-axo", "pid=,command="], text=True)
    current_pid = str(os.getpid())
    return [
        line.strip()
        for line in output.splitlines()
        if path in line and not line.lstrip().startswith(current_pid + " ")
    ]


def main() -> int:
    if not SERVER.is_file() or not FIXTURE.is_file():
        print("daemon-session-isolation-smoke: build the server and fixture first", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-session-isolation-") as directory:
        endpoint_path = Path(directory) / "endpoint.json"
        environment = os.environ.copy()
        environment["APPLE_DEBUG_MCP_ENDPOINT_FILE"] = str(endpoint_path)
        environment["APPLE_DEBUG_MCP_PORT"] = "0"
        environment["APPLE_DEBUG_ALLOW_TARGET_LAUNCH"] = "1"
        process = subprocess.Popen(
            [str(SERVER), "--daemon"],
            cwd=ROOT,
            env=environment,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        endpoint: dict[str, object] | None = None
        client_a: str | None = None
        client_b: str | None = None

        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline and not endpoint_path.exists():
                if process.poll() is not None:
                    break
                time.sleep(0.05)
            if not endpoint_path.exists():
                stdout, stderr = process.communicate(timeout=1)
                raise RuntimeError(
                    f"daemon did not publish endpoint (exit={process.returncode})\n"
                    f"stdout={stdout}\nstderr={stderr}"
                )

            endpoint = json.loads(endpoint_path.read_text())
            token = str(endpoint["token"])
            client_a = initialize(endpoint, token, "apple-debug-mcp-isolation-a")
            client_b = initialize(endpoint, token, "apple-debug-mcp-isolation-b")

            created = result_json(
                call_tool(endpoint, token, client_a, "apple_debug_session_create", {})
            )
            if not isinstance(created, dict) or not isinstance(created.get("sessionID"), str):
                raise RuntimeError(f"client A did not create a debugger session: {created}")
            debugger_session_id = created["sessionID"]

            a_sessions = result_json(
                call_tool(endpoint, token, client_a, "apple_debug_session_list", {})
            )
            b_sessions = result_json(
                call_tool(endpoint, token, client_b, "apple_debug_session_list", {})
            )
            if not isinstance(a_sessions, list) or len(a_sessions) != 1:
                raise RuntimeError(f"client A did not see exactly its own debugger session: {a_sessions}")
            if not isinstance(b_sessions, list) or b_sessions:
                raise RuntimeError(f"client B observed client A debugger state: {b_sessions}")

            launch = result_json(
                call_tool(
                    endpoint,
                    token,
                    client_a,
                    "apple_debug_launch",
                    {"sessionID": debugger_session_id, "program": str(FIXTURE), "stopOnEntry": True},
                )
            )
            if not isinstance(launch, dict):
                raise RuntimeError(f"client A launch returned an invalid DAP response: {launch}")
            threads = result_json(
                call_tool(
                    endpoint,
                    token,
                    client_a,
                    "apple_debug_threads",
                    {"sessionID": debugger_session_id},
                )
            )
            if not isinstance(threads, dict) or not threads.get("body", {}).get("threads"):
                raise RuntimeError(f"client A launch did not produce a stopped thread list: {threads}")

            foreign = call_tool(
                endpoint,
                token,
                client_b,
                "apple_debug_threads",
                {"sessionID": debugger_session_id},
            )
            foreign_result = foreign.get("result")
            if not isinstance(foreign_result, dict) or foreign_result.get("isError") is not True:
                raise RuntimeError(f"client B accessed client A debugger session: {foreign}")

            status, body = delete_mcp(endpoint, token, client_a)
            if status != 200:
                raise RuntimeError(f"client A MCP DELETE failed: HTTP {status} {body}")
            status, body = post_mcp_status(
                endpoint,
                token,
                {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "apple_debug_session_list", "arguments": {}}},
                client_a,
            )
            if status != 404:
                raise RuntimeError(f"deleted client A session remained routable: HTTP {status} {body}")

            time.sleep(0.3)
            remaining = process_commands_containing(str(FIXTURE))
            if remaining:
                raise RuntimeError(f"debuggee remained after client DELETE: {remaining}")

            print("daemon-session-isolation-smoke: per-client debugger isolation and DELETE-owned cleanup passed")
            return 0
        except Exception as error:
            print(f"daemon-session-isolation-smoke: {error}", file=sys.stderr)
            return 1
        finally:
            if endpoint is not None and process.poll() is None:
                try:
                    shutdown(endpoint, str(endpoint["token"]))
                except Exception:
                    pass
            if process.stdin is not None:
                try:
                    process.stdin.close()
                except BrokenPipeError:
                    pass
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.terminate()
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=2)
            if endpoint_path.exists():
                print("daemon-session-isolation-smoke: daemon did not remove endpoint metadata", file=sys.stderr)


if __name__ == "__main__":
    raise SystemExit(main())
