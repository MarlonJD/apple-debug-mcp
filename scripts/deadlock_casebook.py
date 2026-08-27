#!/usr/bin/env python3
"""Run a deterministic lock-order deadlock case through sample and MCP."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone

from complex_debug_casebook import MCPClient, bounded, mcp_environment


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "Tests/Fixtures/complex_deadlock_target.c"
ENTITLEMENTS = ROOT / "Tests/Fixtures/debug_target.entitlements"
SERVER = ROOT / ".build/debug/apple-debug-mcp"


def elapsed_ms(start: float) -> int:
    return int(round((time.monotonic() - start) * 1_000))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--evidence-output",
        type=Path,
        default=ROOT / ".build/evidence/deadlock-casebook.json",
    )
    parser.add_argument("--model", default="deterministic-fixture")
    parser.add_argument("--reasoning", default="not-applicable")
    return parser.parse_args()


def build_variant(output: Path, fixed: bool) -> dict[str, object]:
    output.parent.mkdir(parents=True, exist_ok=True)
    compile_command = ["clang", "-g", "-O0", "-fno-omit-frame-pointer", "-pthread"]
    if fixed:
        compile_command.append("-DAPPLE_DEBUG_DEMO_FIXED=1")
    compile_command += [str(FIXTURE), "-o", str(output)]
    started = time.monotonic()
    compile_result = subprocess.run(
        compile_command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if compile_result.returncode != 0:
        raise RuntimeError(f"clang failed: {bounded(compile_result.stderr)}")
    sign_result = subprocess.run(
        ["codesign", "--force", "--sign", "-", "--entitlements", str(ENTITLEMENTS), str(output)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if sign_result.returncode != 0:
        raise RuntimeError(f"codesign failed: {bounded(sign_result.stderr)}")
    return {
        "fixed": fixed,
        "path": str(output),
        "durationMs": elapsed_ms(started),
        "compileCommand": compile_command,
    }


def start_process(binary: Path) -> subprocess.Popen[str]:
    process = subprocess.Popen(
        [str(binary)],
        cwd=ROOT,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    if process.stdout is None:
        raise RuntimeError("deadlock fixture stdout is unavailable")
    marker = process.stdout.readline().strip()
    if marker != "workers-started":
        stop_process(process)
        raise RuntimeError(f"deadlock fixture did not start: {marker!r}")
    time.sleep(0.2)
    if process.poll() is not None:
        stop_process(process)
        raise RuntimeError("deadlock fixture exited before inspection")
    return process


def stop_process(process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait(timeout=5)


def run_manual_sample(process: subprocess.Popen[str], output_path: Path) -> dict[str, object]:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    command = ["sample", str(process.pid), "1", "1", "-file", str(output_path)]
    started = time.monotonic()
    result = subprocess.run(
        command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    output = output_path.read_text(encoding="utf-8", errors="replace") if output_path.is_file() else ""
    output = bounded(output, 6_000)
    return {
        "command": command,
        "durationMs": elapsed_ms(started),
        "exitCode": result.returncode,
        "threadMarkers": len(re.findall(r"Thread_", output)),
        "mutexWaitMarkers": len(re.findall(r"mutex|psynch_mutexwait|pthread_join", output, re.IGNORECASE)),
        "stdout": output,
        "stderr": bounded(result.stderr),
        "resultKind": "sample-text",
    }


def run_mcp_diagnosis(binary: Path) -> dict[str, object]:
    environment = mcp_environment(with_grants=False)
    environment["APPLE_DEBUG_ALLOW_TARGET_ATTACH"] = "1"
    client = MCPClient(environment, "apple-debug-mcp-deadlock-case")
    calls: list[dict[str, object]] = []
    process = start_process(binary)
    try:
        client.initialize()
        sample = client.call(
            "apple_debug_runtime_diagnose",
            {
                "processID": process.pid,
                "tool": "sample",
                "mode": "sample",
                "durationSeconds": 1,
                "sampleIntervalMilliseconds": 10,
            },
            calls,
        )
        if not isinstance(sample, dict) or not isinstance(sample.get("output"), str):
            raise RuntimeError(f"MCP runtime diagnosis returned no sample output: {sample}")
        output = sample["output"]
        return {
            "toolCalls": calls,
            "processID": process.pid,
            "sample": {
                "outputBytes": len(output.encode("utf-8")),
                "threadMarkers": len(re.findall(r"Thread_", output)),
                "mutexWaitMarkers": len(re.findall(r"mutex|psynch_mutexwait|pthread_join", output, re.IGNORECASE)),
            },
            "resultKind": "bounded-diagnostic-json",
        }
    finally:
        client.close()
        stop_process(process)


def run_fixed(binary: Path) -> dict[str, object]:
    started = time.monotonic()
    result = subprocess.run(
        [str(binary)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=5,
        check=False,
    )
    return {
        "durationMs": elapsed_ms(started),
        "exitCode": result.returncode,
        "stdout": bounded(result.stdout),
        "stderr": bounded(result.stderr),
    }


def write_evidence(path: Path, payload: dict[str, object]) -> None:
    path = path if path.is_absolute() else ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    evidence_path = args.evidence_output if args.evidence_output.is_absolute() else ROOT / args.evidence_output
    evidence: dict[str, object] = {
        "schemaVersion": 1,
        "workflow": "complex-deadlock-casebook-v1",
        "status": "running",
        "createdAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "runner": {"model": args.model, "reasoning": args.reasoning},
        "case": {
            "fixture": str(FIXTURE),
            "sourceSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
            "bug": "two workers acquire cache and metrics locks in reverse order",
            "fix": "all workers acquire cache before metrics",
            "repairMode": "pre-authored-compile-variant; not an agent-repair benchmark",
        },
    }
    manual_process: subprocess.Popen[str] | None = None
    try:
        if not SERVER.is_file():
            raise RuntimeError("build .build/debug/apple-debug-mcp before running the casebook")
        demo_dir = ROOT / ".build/demos/deadlock"
        buggy = demo_dir / "deadlock-buggy"
        fixed = demo_dir / "deadlock-fixed"
        evidence["builds"] = {
            "buggy": build_variant(buggy, fixed=False),
            "fixed": build_variant(fixed, fixed=True),
        }
        manual_process = start_process(buggy)
        manual = run_manual_sample(manual_process, demo_dir / "manual-sample.txt")
        stop_process(manual_process)
        manual_process = None
        mcp_started = time.monotonic()
        mcp = run_mcp_diagnosis(buggy)
        mcp["durationMs"] = elapsed_ms(mcp_started)
        fixed_run = run_fixed(fixed)
        if manual.get("threadMarkers", 0) < 3 or manual.get("mutexWaitMarkers", 0) < 2:
            raise RuntimeError(f"manual sample did not expose all deadlocked threads: {manual}")
        if mcp.get("sample", {}).get("threadMarkers", 0) < 3 or mcp.get("sample", {}).get("mutexWaitMarkers", 0) < 2:
            raise RuntimeError(f"MCP did not expose the deadlock threads: {mcp}")
        if fixed_run.get("exitCode") != 0 or "fixed-ok" not in str(fixed_run.get("stdout")):
            raise RuntimeError(f"fixed deadlock variant did not pass: {fixed_run}")
        evidence.update(
            {
                "status": "passed",
                "manual": manual,
                "mcp": mcp,
                "repair": {"fixedRun": fixed_run, "verified": True},
                "comparison": {
                    "timingComparable": False,
                    "manualScope": "native sample capture and text stack report",
                    "mcpScope": "typed bounded runtime diagnosis with explicit process policy and structured sample envelope",
                    "reason": "The MCP lane intentionally returns correlated per-thread evidence; elapsed times are descriptive, not a speedup claim.",
                },
                "cleanup": {"mcpProcessTerminated": True, "manualProcessTerminated": True},
            }
        )
        write_evidence(evidence_path, evidence)
        print(f"deadlock-casebook: lock-order deadlock diagnosed, fixed variant passed, evidence written to {evidence_path}")
        return 0
    except Exception as error:
        evidence["status"] = "failed"
        evidence["failure"] = bounded(error)
        write_evidence(evidence_path, evidence)
        print(f"deadlock-casebook: {error}", file=sys.stderr)
        return 1
    finally:
        if manual_process is not None:
            stop_process(manual_process)


if __name__ == "__main__":
    raise SystemExit(main())
