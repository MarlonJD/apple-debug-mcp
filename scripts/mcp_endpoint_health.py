#!/usr/bin/env python3
"""Verify the user-local MCP daemon endpoint published by the menu-bar app."""

from __future__ import annotations

import json
import os
from pathlib import Path
import urllib.request


def main() -> None:
    configured = os.environ.get("APPLE_DEBUG_MCP_ENDPOINT_FILE")
    endpoint_path = (
        Path(configured)
        if configured
        else Path.home() / "Library" / "Application Support" / "AppleDebugMCP" / "endpoint.json"
    )
    endpoint = json.loads(endpoint_path.read_text())
    health_url = str(endpoint["url"]).replace("/mcp", "/healthz")
    request = urllib.request.Request(
        health_url,
        headers={"Authorization": f"Bearer {endpoint['token']}"},
    )
    with urllib.request.urlopen(request, timeout=3) as response:
        if response.status != 200:
            raise RuntimeError(f"health check returned HTTP {response.status}")
    print(f"endpoint-health: {endpoint['url']} is healthy")


if __name__ == "__main__":
    main()
