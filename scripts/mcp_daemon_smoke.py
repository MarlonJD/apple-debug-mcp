#!/usr/bin/env python3
"""Exercise the authenticated loopback MCP daemon without a GUI client."""

from __future__ import annotations

import http.client
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / ".build" / "debug" / "apple-debug-mcp"


def load_endpoint(path: Path) -> dict[str, object]:
    return json.loads(path.read_text())


def health(endpoint: dict[str, object], token: str | None = None) -> tuple[int, str]:
    url = str(endpoint["url"]).replace("/mcp", "/healthz")
    headers = {}
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    request = Request(url, headers=headers)
    try:
        with urlopen(request, timeout=3) as response:
            return response.status, response.read().decode()
    except HTTPError as error:
        return error.code, error.read().decode()


def shutdown(endpoint: dict[str, object], token: str) -> None:
    url = str(endpoint["url"]).replace("/mcp", "/shutdown")
    request = Request(
        url,
        data=b"",
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    with urlopen(request, timeout=3) as response:
        if response.status != 200:
            raise RuntimeError(f"daemon shutdown returned HTTP {response.status}")


def post_mcp(
    endpoint: dict[str, object],
    token: str,
    message: dict[str, object],
    session_id: str | None = None,
) -> tuple[dict[str, object], str | None]:
    parts = urlsplit(str(endpoint["url"]))
    connection = http.client.HTTPConnection(parts.hostname, parts.port, timeout=3)
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json, text/event-stream",
        "Content-Type": "application/json",
        "Origin": f"http://127.0.0.1:{parts.port}",
        "MCP-Protocol-Version": "2025-11-25",
    }
    if session_id is not None:
        headers["MCP-Session-Id"] = session_id
    connection.request("POST", parts.path, json.dumps(message).encode(), headers)
    response = connection.getresponse()
    if response.status != 200:
        body = response.read().decode()
        connection.close()
        raise RuntimeError(f"MCP POST returned HTTP {response.status}: {body}")

    deadline = time.monotonic() + 3
    try:
        while time.monotonic() < deadline:
            line = response.readline()
            if not line:
                break
            if not line.startswith(b"data:"):
                continue
            payload = line.split(b":", 1)[1].strip()
            if not payload:
                continue
            decoded = json.loads(payload.decode())
            if "result" in decoded or "error" in decoded:
                return decoded, response.getheader("MCP-Session-Id")
    finally:
        connection.close()
    raise RuntimeError("MCP daemon did not return an SSE JSON-RPC response")


def main() -> None:
    if not SERVER.is_file():
        raise SystemExit("mcp-daemon-smoke: build .build/debug/apple-debug-mcp first")

    with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-daemon-") as directory:
        endpoint_path = Path(directory) / "endpoint.json"
        environment = os.environ.copy()
        environment["APPLE_DEBUG_MCP_ENDPOINT_FILE"] = str(endpoint_path)
        environment["APPLE_DEBUG_MCP_PORT"] = "0"
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

            endpoint = load_endpoint(endpoint_path)
            token = str(endpoint["token"])
            if int(endpoint["pid"]) != process.pid:
                raise RuntimeError("endpoint PID does not match daemon process")
            if endpoint_path.stat().st_mode & 0o777 != 0o600:
                raise RuntimeError(
                    f"endpoint file permissions are too broad: {oct(endpoint_path.stat().st_mode & 0o777)}"
                )

            status, body = health(endpoint, token)
            if status != 200 or '"status":"ok"' not in body:
                raise RuntimeError(f"authenticated health check failed: HTTP {status} {body}")
            unauthenticated_status, _ = health(endpoint)
            if unauthenticated_status != 401:
                raise RuntimeError(
                    f"unauthenticated health check was not rejected: HTTP {unauthenticated_status}"
                )

            initialize, session_id = post_mcp(
                endpoint,
                token,
                {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2025-11-25",
                        "capabilities": {},
                        "clientInfo": {"name": "apple-debug-mcp-daemon-smoke", "version": "0.1.0"},
                    },
                },
            )
            if "result" not in initialize or not session_id:
                raise RuntimeError(f"MCP initialize failed: {initialize}")

            tools, returned_session_id = post_mcp(
                endpoint,
                token,
                {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
                session_id,
            )
            if returned_session_id != session_id or "result" not in tools:
                raise RuntimeError(f"MCP tools/list failed: {tools}")
            tool_names = {tool["name"] for tool in tools["result"]["tools"]}
            required = {"apple_capabilities", "apple_toolchain_status", "apple_debug_session_create"}
            if not required.issubset(tool_names):
                raise RuntimeError(f"MCP tool list is incomplete: missing {sorted(required - tool_names)}")

            capabilities, _ = post_mcp(
                endpoint,
                token,
                {
                    "jsonrpc": "2.0",
                    "id": 3,
                    "method": "tools/call",
                    "params": {"name": "apple_capabilities", "arguments": {}},
                },
                session_id,
            )
            if "result" not in capabilities:
                raise RuntimeError(f"MCP capabilities call failed: {capabilities}")

            print(
                "daemon-smoke: authenticated health, bearer rejection, MCP initialize, "
                f"session routing, tool discovery ({len(tool_names)} tools), and capability call passed"
            )
        finally:
            if endpoint is not None and process.poll() is None:
                shutdown(endpoint, str(endpoint["token"]))
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
                raise RuntimeError("daemon did not remove its endpoint file during graceful shutdown")
            if process.returncode != 0:
                stderr = process.stderr.read() if process.stderr is not None else ""
                raise RuntimeError(f"daemon exited with {process.returncode}: {stderr}")


if __name__ == "__main__":
    main()
