#!/usr/bin/env python3
"""Exercise the embedded App Sandbox XPC plugin service in a signed test bundle."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def run(command, **kwargs):
    result = subprocess.run(command, text=True, capture_output=True, **kwargs)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(command)}: {result.stderr.strip()}")
    return result


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    try:
        run(["swift", "build", "--product", "apple-debug-mcp"], cwd=root)
        run(["swift", "build", "--product", "apple-debug-plugin-host"], cwd=root)
        run(["swift", "build", "--product", "apple-debug-plugin-xpc-service"], cwd=root)
        with tempfile.TemporaryDirectory(prefix="apple-debug-mcp-xpc-") as directory:
            app = Path(directory) / "AppleDebugPluginSmoke.app"
            contents = app / "Contents"
            main_dir = contents / "MacOS"
            xpc_contents = contents / "XPCServices" / "AppleDebugPluginHost.xpc" / "Contents"
            resources_dir = xpc_contents / "Resources"
            main_dir.mkdir(parents=True)
            (xpc_contents / "MacOS").mkdir(parents=True)
            resources_dir.mkdir(parents=True)

            main_binary = main_dir / "apple-debug-plugin-host"
            shutil.copy2(root / ".build" / "debug" / "apple-debug-plugin-host", main_binary)
            manifest_path = resources_dir / "cat.appledebugplugin.json"
            manifest_path.write_text(
                json.dumps(
                    {
                        "id": "com.burakkarahan.apple-debug.plugin-host",
                        "name": "XPC Analyzer",
                        "version": "1.0.0",
                        "capabilities": ["binary-analysis"],
                        "entrypoint": "apple-debug-plugin-xpc-service",
                    }
                )
            )

            app_plist = (root / "Resources" / "AppleDebugMCP-Info.plist").read_text()
            app_plist = app_plist.replace("<string>apple-debug-mcp</string>", "<string>apple-debug-plugin-host</string>")
            app_plist = app_plist.replace("com.burakkarahan.apple-debug-mcp", "com.burakkarahan.apple-debug-plugin-smoke")
            (contents / "Info.plist").write_text(app_plist)
            plugin_binary = xpc_contents / "MacOS" / "apple-debug-plugin-xpc-service"
            shutil.copy2(root / ".build" / "debug" / "apple-debug-plugin-xpc-service", plugin_binary)
            shutil.copy2(root / "Resources" / "AppleDebugPluginHostXPC-Info.plist", xpc_contents / "Info.plist")

            run(
                [
                    "codesign",
                    "--force",
                    "--sign",
                    "-",
                    "--entitlements",
                    str(root / "Resources" / "AppleDebugPluginHostXPC.entitlements"),
                    str(xpc_contents.parent),
                ]
            )
            run(["codesign", "--force", "--sign", "-", str(app)])
            run(["codesign", "--verify", "--deep", "--strict", str(app)])

            environment = dict(os.environ)
            environment["APPLE_DEBUG_ALLOW_PLUGIN_EXECUTION"] = "1"
            result = subprocess.run(
                [
                    str(main_binary),
                    "--manifest",
                    str(manifest_path),
                    "--executable",
                    str(plugin_binary),
                    "--transport",
                    "xpc",
                    "--service-name",
                    "com.burakkarahan.apple-debug.plugin-host",
                ],
                input='{"hello":"xpc"}\n',
                cwd=root,
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode != 0:
                raise RuntimeError(result.stderr.strip() or "XPC host returned a non-zero exit code")
            payload = json.loads(result.stdout)
            if not payload.get("sandboxed") or '"hello"' not in payload.get("stdout", ""):
                raise RuntimeError(f"XPC service did not return sandbox evidence: {payload}")
            if not any("XPC service" in note for note in payload.get("notes", [])):
                raise RuntimeError(f"XPC result did not identify the App Sandbox boundary: {payload}")
        print("plugin-xpc-smoke: embedded signed App Sandbox XPC plugin service handled the protocol")
        return 0
    except Exception as error:
        print(f"plugin-xpc-smoke: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
