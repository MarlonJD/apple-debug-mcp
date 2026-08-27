#!/usr/bin/env python3
"""Validate the repo-local Codex plugin and exercise its stdio MCP launcher."""

from __future__ import annotations

import json
import os
from pathlib import Path
import select
import subprocess
import sys
from typing import NoReturn


ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "plugins" / "apple-debug"
MANIFEST = PLUGIN / ".codex-plugin" / "plugin.json"
CLAUDE_MANIFEST = PLUGIN / ".claude-plugin" / "plugin.json"
MCP_MANIFEST = PLUGIN / ".mcp.json"
SKILL = PLUGIN / "skills" / "apple-debug" / "SKILL.md"
LAUNCHER = PLUGIN / "bin" / "apple-debug-mcp-launcher"
MARKETPLACE = ROOT / ".agents" / "plugins" / "marketplace.json"
SERVER = ROOT / ".build" / "debug" / "apple-debug-mcp"


def fail(message: str) -> NoReturn:
    raise SystemExit(f"codex-plugin-smoke: {message}")


def read_json(path: Path) -> dict[str, object]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"{path.relative_to(ROOT)} is not valid JSON: {error}")
    if not isinstance(payload, dict):
        fail(f"{path.relative_to(ROOT)} must contain a JSON object")
    return payload


def require_regular_file(path: Path) -> None:
    if path.is_symlink() or not path.is_file():
        fail(f"required regular file is missing: {path.relative_to(ROOT)}")


def main() -> None:
    for path in (MANIFEST, CLAUDE_MANIFEST, MCP_MANIFEST, SKILL, LAUNCHER, MARKETPLACE, SERVER):
        require_regular_file(path)

    if not os.access(LAUNCHER, os.X_OK):
        fail("MCP launcher is not executable")
    if not os.access(SERVER, os.X_OK):
        fail("built MCP server is not executable")

    manifest = read_json(MANIFEST)
    if manifest.get("name") != "apple-debug":
        fail("plugin manifest name is not apple-debug")
    if manifest.get("version") != "0.2.0":
        fail("Codex plugin manifest version is not 0.2.0")
    if manifest.get("skills") != "./skills/":
        fail("plugin manifest does not point at ./skills/")
    if manifest.get("mcpServers") != "./.mcp.json":
        fail("plugin manifest does not point at ./.mcp.json")

    claude_manifest = read_json(CLAUDE_MANIFEST)
    if claude_manifest.get("name") != "apple-debug":
        fail("Claude Code plugin manifest name is not apple-debug")
    if claude_manifest.get("version") != "0.2.0":
        fail("Claude Code plugin manifest version is not 0.2.0")

    mcp_manifest = read_json(MCP_MANIFEST)
    servers = mcp_manifest.get("mcpServers")
    if not isinstance(servers, dict) or not isinstance(servers.get("apple-debug"), dict):
        fail(".mcp.json does not define the apple-debug server")
    server_config = servers["apple-debug"]
    if server_config.get("command") != "/bin/sh":
        fail(".mcp.json does not use the portable plugin shell launcher")
    if server_config.get("args") != [
        "-c",
        'plugin_root="${CLAUDE_PLUGIN_ROOT:-.}"; exec "$plugin_root/bin/apple-debug-mcp-launcher"',
    ]:
        fail(".mcp.json does not resolve the launcher through CLAUDE_PLUGIN_ROOT")
    if server_config.get("cwd") != ".":
        fail(".mcp.json must run from the plugin root")

    skill_text = SKILL.read_text(encoding="utf-8")
    if not skill_text.startswith("---\n") or "\n---\n" not in skill_text[4:]:
        fail("skill is missing valid YAML frontmatter delimiters")
    if "name: apple-debug" not in skill_text:
        fail("skill frontmatter name is not apple-debug")
    if "description:" not in skill_text:
        fail("skill frontmatter description is missing")
    if "[TODO:" in skill_text:
        fail("skill contains a TODO placeholder")

    marketplace = read_json(MARKETPLACE)
    if marketplace.get("name") != "apple-debug-mcp":
        fail("marketplace name is not apple-debug-mcp")
    entries = marketplace.get("plugins")
    if not isinstance(entries, list):
        fail("marketplace plugins field is not an array")
    entry = next((item for item in entries if isinstance(item, dict) and item.get("name") == "apple-debug"), None)
    if entry is None:
        fail("marketplace does not expose the apple-debug plugin")
    source = entry.get("source")
    if not isinstance(source, dict) or source.get("path") != "./plugins/apple-debug":
        fail("marketplace source path is not ./plugins/apple-debug")

    initialize = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-11-25",
            "capabilities": {},
            "clientInfo": {"name": "apple-debug-codex-plugin-smoke", "version": "0.1.0"},
        },
    }
    environment = os.environ.copy()
    environment["APPLE_DEBUG_MCP_EXECUTABLE"] = str(SERVER)
    environment["CLAUDE_PLUGIN_ROOT"] = str(PLUGIN)
    mcp_command = [str(server_config["command"]), *server_config["args"]]
    process = subprocess.Popen(
        mcp_command,
        cwd=PLUGIN,
        env=environment,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        if process.stdin is None or process.stdout is None or process.stderr is None:
            fail("launcher pipes are unavailable")
        process.stdin.write(json.dumps(initialize) + "\n")
        process.stdin.flush()
        ready, _, _ = select.select([process.stdout], [], [], 5)
        if not ready:
            fail("launcher did not return an initialize response within the bound")
        response_line = process.stdout.readline()
        process.stdin.close()
        process.wait(timeout=5)
        stdout = response_line
        stderr = process.stderr.read()
    except subprocess.TimeoutExpired:
        process.terminate()
        process.wait(timeout=5)
        fail("launcher did not finish the bounded initialize smoke")
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
    if process.returncode != 0:
        fail(f"launcher exited {process.returncode}: {stderr.strip()}")
    try:
        responses = [json.loads(line) for line in stdout.splitlines() if line.strip()]
    except json.JSONDecodeError as error:
        fail(f"launcher returned invalid MCP JSON: {error}; stdout={stdout!r}; stderr={stderr!r}")
    initialize_response = next((item for item in responses if item.get("id") == 1), None)
    if not isinstance(initialize_response, dict) or "result" not in initialize_response:
        fail(f"launcher did not return an initialize result: {stdout.strip()}")
    result = initialize_response["result"]
    if not isinstance(result, dict) or "instructions" not in result:
        fail("MCP initialize result did not include server instructions")

    print("codex-plugin-smoke: Codex/Claude manifests, marketplace, MCP config, skill, launcher, and stdio handshake passed")


if __name__ == "__main__":
    main()
