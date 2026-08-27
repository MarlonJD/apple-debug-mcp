#!/usr/bin/env python3
"""Compare a manual Simulator screenshot with MCP UI/evidence for a visual fix."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from datetime import datetime, timezone
import uuid

from complex_debug_casebook import MCPClient, bounded, mcp_environment


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Tests/Fixtures/iOSDebugApp/DebugApp.xcodeproj"
BUNDLE_ID = "com.burakkarahan.AppleDebugFixture"
SERVER = ROOT / ".build/debug/apple-debug-mcp"


def elapsed_ms(start: float) -> int:
    return int(round((time.monotonic() - start) * 1_000))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--evidence-output",
        type=Path,
        default=ROOT / ".build/evidence/visual-regression-casebook.json",
        help="write bounded JSON evidence to this path",
    )
    parser.add_argument(
        "--simulator-id",
        help="use this available iPhone Simulator instead of selecting one automatically",
    )
    parser.add_argument("--model", default="deterministic-fixture")
    parser.add_argument("--reasoning", default="not-applicable")
    return parser.parse_args()


def run_command(arguments: list[str], timeout: int = 60) -> dict[str, object]:
    started = time.monotonic()
    result = subprocess.run(
        arguments,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    return {
        "command": arguments,
        "exitCode": result.returncode,
        "durationMs": elapsed_ms(started),
        "stdout": bounded(result.stdout),
        "stderr": bounded(result.stderr),
    }


def available_simulator(requested_id: str | None) -> dict[str, object]:
    result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"simctl inventory failed: {bounded(result.stderr)}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("simctl inventory was not JSON") from error
    candidates = [
        device
        for runtime, devices in payload.get("devices", {}).items()
        if "iOS" in runtime
        for device in devices
        if device.get("isAvailable", True) and device.get("name", "").startswith("iPhone")
    ]
    if not candidates:
        raise RuntimeError("no available iPhone Simulator")
    if requested_id is not None:
        for candidate in candidates:
            if candidate.get("udid") == requested_id:
                return candidate
        raise RuntimeError(f"requested iPhone Simulator is not available: {requested_id}")
    # Prefer a shutdown device so an automatic run does not disturb an already
    # running user Simulator. An explicit --simulator-id can override this.
    candidates.sort(key=lambda device: (0 if device.get("state") != "Booted" else 1, device.get("name", ""), device.get("udid", "")))
    return candidates[0]


def build_variant(output_root: Path, simulator_id: str, fixed: bool) -> dict[str, object]:
    derived = output_root / ("fixed-derived-data" if fixed else "buggy-derived-data")
    conditions = "APPLE_DEBUG_VISUAL_CASE"
    if fixed:
        conditions += " APPLE_DEBUG_VISUAL_FIXED"
    command = [
        "xcodebuild",
        "-project",
        str(PROJECT),
        "-scheme",
        "DebugApp",
        "-configuration",
        "Debug",
        "-destination",
        f"platform=iOS Simulator,id={simulator_id}",
        "-derivedDataPath",
        str(derived),
        "CODE_SIGNING_ALLOWED=NO",
        f"SWIFT_ACTIVE_COMPILATION_CONDITIONS={conditions}",
        "build",
    ]
    result = run_command(command, timeout=180)
    if result["exitCode"] != 0:
        details = "\n".join(
            part for part in (str(result["stderr"]), str(result["stdout"])) if part and part != ""
        )
        raise RuntimeError(f"visual {('fixed' if fixed else 'buggy')} build failed: {details[-6_000:]}")
    app_path = derived / "Build/Products/Debug-iphonesimulator/DebugApp.app"
    if not app_path.is_dir():
        raise RuntimeError(f"visual app was not produced: {app_path}")
    result.update({"fixed": fixed, "appPath": str(app_path), "conditions": conditions})
    return result


def element(snapshot: object, identifier: str) -> dict[str, object]:
    if not isinstance(snapshot, dict):
        raise RuntimeError(f"UI snapshot was not an object: {snapshot}")
    elements = snapshot.get("elements")
    if not isinstance(elements, list):
        raise RuntimeError(f"UI snapshot has no elements: {snapshot}")
    for item in elements:
        if isinstance(item, dict) and item.get("identifier") == identifier:
            return item
    raise RuntimeError(f"UI snapshot did not contain {identifier}")


def card_measurements(snapshot: object) -> dict[str, object]:
    card = element(snapshot, "debug.fixture.visual.card")
    title = element(snapshot, "debug.fixture.visual.title")
    status = element(snapshot, "debug.fixture.visual.status")
    frame = card.get("frame")
    title_frame = title.get("frame")
    if not isinstance(frame, dict) or not isinstance(title_frame, dict):
        raise RuntimeError("visual elements did not return frame dictionaries")
    return {
        "card": {
            "frame": frame,
            "label": card.get("label", ""),
            "hittable": card.get("hittable"),
        },
        "title": {
            "frame": title_frame,
            "label": title.get("label", ""),
            "hittable": title.get("hittable"),
        },
        "status": status.get("label", ""),
    }


def screenshot_exists(path: Path) -> bool:
    return path.is_file() and path.stat().st_size > 0


def frame_contains(outer: object, inner: object) -> bool:
    if not isinstance(outer, dict) or not isinstance(inner, dict):
        return False
    try:
        outer_x = float(outer["x"])
        outer_y = float(outer["y"])
        outer_width = float(outer["width"])
        outer_height = float(outer["height"])
        inner_x = float(inner["x"])
        inner_y = float(inner["y"])
        inner_width = float(inner["width"])
        inner_height = float(inner["height"])
    except (KeyError, TypeError, ValueError):
        return False
    tolerance = 1.0
    return (
        inner_x >= outer_x - tolerance
        and inner_y >= outer_y - tolerance
        and inner_x + inner_width <= outer_x + outer_width + tolerance
        and inner_y + inner_height <= outer_y + outer_height + tolerance
    )


def terminate_mcp_app(client: MCPClient, simulator_id: str, calls: list[dict[str, object]]) -> None:
    try:
        client.call(
            "apple_simulator_terminate",
            {"udid": simulator_id, "bundleID": BUNDLE_ID},
            calls,
        )
    except Exception as error:
        if "found nothing to terminate" not in str(error).lower():
            raise


def probe_mcp_ui(
    client: MCPClient,
    simulator_id: str,
    calls: list[dict[str, object]],
) -> object:
    last_error: Exception | None = None
    for attempt in range(2):
        try:
            return client.call(
                "apple_simulator_ui_probe",
                {"udid": simulator_id, "bundleID": BUNDLE_ID},
                calls,
            )
        except Exception as error:
            last_error = error
            if attempt == 0:
                time.sleep(2.0)
                try:
                    client.call(
                        "apple_simulator_launch",
                        {"udid": simulator_id, "bundleID": BUNDLE_ID, "terminateRunning": True},
                        calls,
                    )
                except Exception:
                    pass
                time.sleep(2.0)
    assert last_error is not None
    raise last_error


def write_evidence(path: Path, payload: dict[str, object]) -> None:
    path = path if path.is_absolute() else ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    evidence_path = args.evidence_output if args.evidence_output.is_absolute() else ROOT / args.evidence_output
    run_root = ROOT / ".build/demos/visual-regression" / str(uuid.uuid4())
    run_root.mkdir(parents=True, exist_ok=True)
    evidence: dict[str, object] = {
        "schemaVersion": 1,
        "workflow": "complex-visual-regression-v1",
        "status": "running",
        "createdAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "runner": {"model": args.model, "reasoning": args.reasoning},
        "case": {
            "bundleID": BUNDLE_ID,
            "sourceFile": str(ROOT / "Tests/Fixtures/iOSDebugApp/DebugApp.swift"),
            "sourceSHA256": hashlib.sha256((ROOT / "Tests/Fixtures/iOSDebugApp/DebugApp.swift").read_bytes()).hexdigest(),
            "bug": "fixed-height card clips a long title at accessibility content size",
            "fix": "adaptive card height with a two-line title",
            "contentSize": "accessibility-extra-extra-extra-large",
            "repairMode": "pre-authored-compile-variant; not an agent-repair benchmark",
        },
        "artifacts": {"runDirectory": str(run_root)},
    }
    client: MCPClient | None = None
    simulator_id: str | None = None
    started_here = False
    original_content_size: str | None = None
    app_was_installed: bool | None = None
    try:
        if not SERVER.is_file():
            raise RuntimeError("build .build/debug/apple-debug-mcp before running the visual casebook")
        device = available_simulator(args.simulator_id)
        simulator_id = str(device["udid"])
        started_here = device.get("state") != "Booted"
        if started_here:
            boot = run_command(["xcrun", "simctl", "boot", simulator_id], timeout=60)
            if boot["exitCode"] != 0 and "already booted" not in str(boot["stderr"]).lower():
                raise RuntimeError(f"Simulator boot failed: {boot}")
            bootstatus = run_command(["xcrun", "simctl", "bootstatus", simulator_id, "-b"], timeout=180)
            if bootstatus["exitCode"] != 0:
                raise RuntimeError(f"Simulator bootstatus failed: {bootstatus}")

        app_probe = run_command(["xcrun", "simctl", "get_app_container", simulator_id, BUNDLE_ID, "app"], timeout=30)
        app_was_installed = app_probe["exitCode"] == 0

        buggy_build = build_variant(run_root, simulator_id, fixed=False)
        fixed_build = build_variant(run_root, simulator_id, fixed=True)
        evidence["builds"] = {"buggy": buggy_build, "fixed": fixed_build}

        content_size_query = run_command(["xcrun", "simctl", "ui", simulator_id, "content_size"], timeout=30)
        if content_size_query["exitCode"] == 0:
            output = str(content_size_query["stdout"]).strip()
            if output and output != "unknown":
                original_content_size = output.splitlines()[-1].strip()
        set_content_size = run_command(
            ["xcrun", "simctl", "ui", simulator_id, "content_size", "accessibility-extra-extra-extra-large"],
            timeout=30,
        )
        if set_content_size["exitCode"] != 0:
            raise RuntimeError(f"could not set accessibility content size: {set_content_size}")

        manual_screenshot = run_root / "manual-buggy.png"
        manual_started = time.monotonic()
        manual_steps = [
            run_command(["xcrun", "simctl", "install", simulator_id, str(buggy_build["appPath"])]),
            run_command(["xcrun", "simctl", "launch", simulator_id, BUNDLE_ID]),
        ]
        time.sleep(1.0)
        manual_steps.append(run_command(["xcrun", "simctl", "io", simulator_id, "screenshot", str(manual_screenshot)]))
        terminate_manual = run_command(["xcrun", "simctl", "terminate", simulator_id, BUNDLE_ID])
        if any(step["exitCode"] != 0 for step in manual_steps) or not screenshot_exists(manual_screenshot):
            raise RuntimeError(f"manual visual lane failed: {manual_steps}")
        if terminate_manual["exitCode"] != 0 and "found nothing to terminate" not in str(terminate_manual["stderr"]).lower():
            raise RuntimeError(f"manual visual lane did not terminate the fixture: {terminate_manual}")
        evidence["manual"] = {
            "durationMs": elapsed_ms(manual_started),
            "steps": manual_steps + [terminate_manual],
            "screenshot": str(manual_screenshot),
            "resultKind": "image-only",
        }

        environment = mcp_environment(with_grants=False)
        environment["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] = "1"
        mcp_started = time.monotonic()
        client = MCPClient(environment, "apple-debug-mcp-visual-regression-case")
        client.initialize()
        calls: list[dict[str, object]] = []
        client.call(
            "apple_simulator_environment",
            {
                "udid": simulator_id,
                "operation": "ui_set",
                "service": "content_size",
                "value": "accessibility-extra-extra-extra-large",
            },
            calls,
        )
        client.call("apple_simulator_install", {"udid": simulator_id, "appPath": str(buggy_build["appPath"])}, calls)
        client.call(
            "apple_simulator_launch",
            {"udid": simulator_id, "bundleID": BUNDLE_ID, "terminateRunning": True},
            calls,
        )
        time.sleep(1.0)
        buggy_screenshot = run_root / "mcp-buggy.png"
        client.call("apple_simulator_screenshot", {"udid": simulator_id, "path": str(buggy_screenshot)}, calls)
        buggy_tree = probe_mcp_ui(client, simulator_id, calls)
        buggy_measurements = card_measurements(buggy_tree)
        terminate_mcp_app(client, simulator_id, calls)

        client.call("apple_simulator_install", {"udid": simulator_id, "appPath": str(fixed_build["appPath"])}, calls)
        client.call(
            "apple_simulator_launch",
            {"udid": simulator_id, "bundleID": BUNDLE_ID, "terminateRunning": True},
            calls,
        )
        time.sleep(1.0)
        fixed_screenshot = run_root / "mcp-fixed.png"
        client.call("apple_simulator_screenshot", {"udid": simulator_id, "path": str(fixed_screenshot)}, calls)
        fixed_tree = probe_mcp_ui(client, simulator_id, calls)
        fixed_measurements = card_measurements(fixed_tree)
        logs = client.call(
            "apple_log_show",
            {
                "target": simulator_id,
                "last": "1s",
                "predicate": "process == \"DebugApp\"",
            },
            calls,
        )
        repro_parent = run_root / "repro-parent"
        repro_parent.mkdir(parents=True, exist_ok=True)
        repro_directory = repro_parent / "fixed-repro-bundle"
        repro = client.call(
            "apple_simulator_repro_bundle",
            {
                "udid": simulator_id,
                "bundleID": BUNDLE_ID,
                "outputDirectory": str(repro_directory),
                "includeScreenshot": True,
                "includeAppInfo": True,
                "includeLogs": False,
            },
            calls,
        )
        terminate_mcp_app(client, simulator_id, calls)

        bug_height = float(buggy_measurements["card"]["frame"]["height"])
        fixed_height = float(fixed_measurements["card"]["frame"]["height"])
        bug_title_height = float(buggy_measurements["title"]["frame"]["height"])
        fixed_title_height = float(fixed_measurements["title"]["frame"]["height"])
        if fixed_title_height <= bug_title_height:
            raise RuntimeError(
                "fixed title did not expand beyond buggy title: "
                f"title {bug_title_height} -> {fixed_title_height}; "
                f"card {bug_height} -> {fixed_height}"
            )
        if fixed_height <= bug_height:
            raise RuntimeError(f"fixed card did not expand beyond buggy card: {bug_height} -> {fixed_height}")
        if buggy_measurements["status"] != "BUGGY":
            raise RuntimeError(f"bug variant status marker missing: {buggy_measurements}")
        if fixed_measurements["status"] != "FIXED":
            raise RuntimeError(f"fixed variant status marker missing: {fixed_measurements}")
        expected_title = "Order\nready"
        if buggy_measurements["title"]["label"] != expected_title or fixed_measurements["title"]["label"] != expected_title:
            raise RuntimeError("visual title accessibility labels were not stable")
        if not frame_contains(fixed_measurements["card"]["frame"], fixed_measurements["title"]["frame"]):
            raise RuntimeError(f"fixed title is outside its card frame: {fixed_measurements}")
        if fixed_measurements["card"]["hittable"] is not True or fixed_measurements["title"].get("hittable") is not True:
            raise RuntimeError(f"fixed visual elements are not hittable: {fixed_measurements}")
        if not screenshot_exists(buggy_screenshot) or not screenshot_exists(fixed_screenshot):
            raise RuntimeError("MCP visual screenshots were missing")
        if not isinstance(logs, dict) or "output" not in logs:
            raise RuntimeError(f"bounded fixture logs were not returned: {logs}")
        if not isinstance(repro, dict) or not isinstance(repro.get("manifest"), dict):
            raise RuntimeError(f"repro bundle result was incomplete: {repro}")
        repro_files = repro["manifest"].get("files")
        if not isinstance(repro_files, list) or not {"manifest.json", "screenshot.png", "appinfo.txt"}.issubset(repro_files):
            raise RuntimeError(f"repro bundle files were incomplete: {repro}")
        evidence.update(
            {
                "status": "passed",
                "mcp": {
                    "durationMs": elapsed_ms(mcp_started),
                    "toolCalls": calls,
                    "buggy": {"screenshot": str(buggy_screenshot), "measurements": buggy_measurements},
                    "fixed": {"screenshot": str(fixed_screenshot), "measurements": fixed_measurements},
                    "logs": logs,
                    "reproBundle": repro,
                    "resultKind": "typed-ui-json-plus-artifacts",
                },
                "oracle": {
                    "buggyCardHeight": bug_height,
                    "fixedCardHeight": fixed_height,
                    "buggyTitleHeight": bug_title_height,
                    "fixedTitleHeight": fixed_title_height,
                    "fixedTitleExpanded": True,
                    "screenshotsCaptured": True,
                    "reproBundleCaptured": True,
                },
                "comparison": {
                    "timingComparable": False,
                    "manualScope": "native simctl install, launch, screenshot, and terminate for the buggy variant",
                    "mcpScope": "MCP install/launch/screenshot/UI probe for buggy and fixed variants, bounded logs, repro bundle, and cleanup",
                    "reason": "The MCP lane intentionally returns richer before/after evidence; elapsed times must not be presented as a speedup claim.",
                },
                "cleanup": {
                    "targetSimulator": simulator_id,
                    "bundleTerminated": True,
                    "simulatorShutdown": started_here,
                },
            }
        )
        write_evidence(evidence_path, evidence)
        print(f"visual-regression-casebook: buggy/fixed screenshots and UI geometry verified; evidence written to {evidence_path}")
        return 0
    except Exception as error:
        evidence["status"] = "failed"
        evidence["failure"] = bounded(error)
        write_evidence(evidence_path, evidence)
        print(f"visual-regression-casebook: {error}", file=sys.stderr)
        return 1
    finally:
        if client is not None and simulator_id is not None:
            try:
                client.call(
                    "apple_simulator_terminate",
                    {"udid": simulator_id, "bundleID": BUNDLE_ID},
                    [],
                )
            except Exception:
                pass
        if simulator_id is not None:
            cleanup = evidence.setdefault("cleanup", {})
            direct_terminate = run_command(["xcrun", "simctl", "terminate", simulator_id, BUNDLE_ID], timeout=30)
            if isinstance(cleanup, dict):
                cleanup["bundleTerminated"] = (
                    direct_terminate["exitCode"] == 0
                    or "found nothing to terminate" in str(direct_terminate["stderr"]).lower()
                )
                cleanup["bundleTerminationAttempt"] = direct_terminate
            restore_content_size = original_content_size or "medium"
            restored = run_command(
                ["xcrun", "simctl", "ui", simulator_id, "content_size", restore_content_size],
                timeout=30,
            )
            if isinstance(cleanup, dict):
                cleanup["contentSizeRestored"] = restored["exitCode"] == 0
                cleanup["contentSizeRestoredTo"] = restore_content_size
            if app_was_installed is False:
                uninstall = run_command(["xcrun", "simctl", "uninstall", simulator_id, BUNDLE_ID], timeout=30)
                if isinstance(cleanup, dict):
                    cleanup["fixtureUninstalled"] = uninstall["exitCode"] == 0
                    cleanup["fixtureUninstallAttempt"] = uninstall
            elif isinstance(cleanup, dict):
                cleanup["fixtureUninstalled"] = False
            if isinstance(cleanup, dict):
                cleanup["fixtureWasPreexisting"] = app_was_installed
            if started_here:
                shutdown = run_command(["xcrun", "simctl", "shutdown", simulator_id], timeout=60)
                if isinstance(cleanup, dict):
                    cleanup["simulatorShutdownSucceeded"] = shutdown["exitCode"] == 0
            elif isinstance(cleanup, dict):
                cleanup["simulatorShutdownSucceeded"] = True
        if client is not None:
            client.close()
        write_evidence(evidence_path, evidence)


if __name__ == "__main__":
    raise SystemExit(main())
