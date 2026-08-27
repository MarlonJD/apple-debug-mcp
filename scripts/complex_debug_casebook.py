#!/usr/bin/env python3
"""Run a deterministic runtime-bug repair case through LLDB and Apple Debug MCP."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import select
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone

from adaptive_verification import (
    Observation,
    StateResult,
    StateStatus,
    compute_identity,
    run_adaptive_verification,
)


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "Tests/Fixtures/complex_runtime_target.c"
ENTITLEMENTS = ROOT / "Tests/Fixtures/debug_target.entitlements"
SERVER = ROOT / ".build/debug/apple-debug-mcp"
SOURCE_LINE = 21
READ_LINE = 23


def bounded(value: object, limit: int = 2_000) -> str:
    text = str(value)
    return text if len(text) <= limit else f"{text[:limit]}..."


def elapsed_ms(start: float) -> int:
    return int(round((time.monotonic() - start) * 1_000))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--evidence-output",
        type=Path,
        default=ROOT / ".build/evidence/complex-runtime-casebook.json",
        help="write bounded JSON evidence to this path",
    )
    parser.add_argument(
        "--model",
        default="deterministic-fixture",
        help="model/runner label to preserve in the evidence metadata",
    )
    parser.add_argument(
        "--reasoning",
        default="not-applicable",
        help="reasoning setting to preserve in the evidence metadata",
    )
    return parser.parse_args()


def environment_without_grants() -> dict[str, str]:
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


def build_variant(output: Path, fixed: bool) -> dict[str, object]:
    output.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    compile_command = [
        "clang",
        "-g",
        "-O0",
        "-fno-omit-frame-pointer",
    ]
    if fixed:
        compile_command.append("-DAPPLE_DEBUG_DEMO_FIXED=1")
    compile_command += [str(FIXTURE), "-o", str(output)]
    compile_result = subprocess.run(
        compile_command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if compile_result.returncode != 0:
        raise RuntimeError(f"clang failed: {bounded(compile_result.stderr)}")

    sign_result = subprocess.run(
        ["codesign", "--force", "--sign", "-", "--entitlements", str(ENTITLEMENTS), str(output)],
        cwd=ROOT,
        capture_output=True,
        text=True,
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


def run_program(binary: Path, timeout: int = 10) -> dict[str, object]:
    started = time.monotonic()
    result = subprocess.run(
        [str(binary)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    return {
        "path": str(binary),
        "exitCode": result.returncode,
        "stdout": bounded(result.stdout),
        "stderr": bounded(result.stderr),
        "durationMs": elapsed_ms(started),
        "ownedProcessTerminated": True,
    }


def run_manual_lldb(binary: Path) -> dict[str, object]:
    commands = [
        f"target create {binary}",
        f"breakpoint set --file {FIXTURE} --line {READ_LINE} --condition \"index == count\"",
        "process launch",
        "thread backtrace --count 4",
        "frame variable count index total",
        "expression -- readings[index]",
        "process continue",
        "quit",
    ]
    arguments = ["-b"]
    for command in commands:
        arguments += ["-o", command]
    started = time.monotonic()
    result = subprocess.run(
        ["xcrun", "lldb", *arguments],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    output = bounded(result.stdout)
    count_match = re.search(r"\(int\) count = (-?\d+)", output)
    index_match = re.search(r"\(int\) index = (-?\d+)", output)
    sentinel_matches = re.findall(r"\(const int\) \$\d+ = (-?\d+)", output)
    target_exit_match = re.search(r"exited with status = (\d+)", output)
    return {
        "commands": commands,
        "exitCode": result.returncode,
        "durationMs": elapsed_ms(started),
        "stdout": output,
        "stderr": bounded(result.stderr),
        "observedCount": int(count_match.group(1)) if count_match else None,
        "observedIndex": int(index_match.group(1)) if index_match else None,
        "observedSentinel": int(sentinel_matches[-1]) if sentinel_matches else None,
        "targetExitCode": int(target_exit_match.group(1)) if target_exit_match else None,
        "resultKind": "unstructured-text",
    }


def json_result(response: dict) -> object:
    result = response.get("result")
    if not isinstance(result, dict):
        raise RuntimeError(f"MCP response has no result: {bounded(response)}")
    if result.get("isError") is True:
        content = result.get("content", [])
        text = " ".join(
            item.get("text", "")
            for item in content
            if isinstance(item, dict) and isinstance(item.get("text"), str)
        )
        raise RuntimeError(f"MCP tool error: {bounded(text)}")
    content = result.get("content")
    if not isinstance(content, list):
        raise RuntimeError(f"MCP result has no content: {bounded(response)}")
    texts = [
        item.get("text")
        for item in content
        if isinstance(item, dict) and isinstance(item.get("text"), str)
    ]
    if not texts:
        raise RuntimeError(f"MCP result has no text content: {bounded(response)}")
    try:
        return json.loads("\n".join(texts))
    except json.JSONDecodeError as error:
        raise RuntimeError(f"MCP result was not JSON: {bounded(texts[0])}") from error


def shape(value: object) -> dict[str, object]:
    if isinstance(value, dict):
        return {"kind": "object", "keys": sorted(value.keys())[:32]}
    if isinstance(value, list):
        return {"kind": "array", "count": len(value)}
    return {"kind": type(value).__name__}


def evaluated_int(value: object) -> int | None:
    """Decode the final integer from an LLDB evaluate response."""
    if not isinstance(value, dict) or not isinstance(value.get("body"), dict):
        return None
    result = value["body"].get("result")
    if isinstance(result, int):
        return result
    if not isinstance(result, str):
        return None
    matches = re.findall(r"-?\d+", result)
    return int(matches[-1]) if matches else None


def process_exit_code(value: object) -> int | None:
    if not isinstance(value, dict) or not isinstance(value.get("events"), list):
        return None
    for event in value["events"]:
        if not isinstance(event, dict) or event.get("event") != "exited":
            continue
        body = event.get("body")
        if isinstance(body, dict) and isinstance(body.get("exitCode"), int):
            return body["exitCode"]
    return None


def mcp_environment(with_grants: bool) -> dict[str, str]:
    environment = environment_without_grants()
    if with_grants:
        environment["APPLE_DEBUG_ALLOW_TARGET_LAUNCH"] = "1"
        environment["APPLE_DEBUG_ALLOW_EVALUATE"] = "1"
    return environment


class MCPClient:
    def __init__(self, environment: dict[str, str], name: str) -> None:
        self.process = subprocess.Popen(
            [str(SERVER)],
            cwd=ROOT,
            env=environment,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
        self.name = name
        self.sequence = 0
        self.last_request = "startup"

    def request(self, method: str, params: dict, timeout_seconds: float | None = None) -> dict:
        self.sequence += 1
        self.last_request = f"{method}#{self.sequence}"
        if self.process.stdin is None or self.process.stdout is None:
            raise RuntimeError("MCP server pipes are unavailable")
        response_deadline = None if timeout_seconds is None else time.monotonic() + timeout_seconds
        self.process.stdin.write(
            json.dumps(
                {"jsonrpc": "2.0", "id": self.sequence, "method": method, "params": params},
                separators=(",", ":"),
            )
            + "\n"
        )
        self.process.stdin.flush()
        while True:
            if timeout_seconds is not None:
                remaining = (response_deadline or time.monotonic()) - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError(f"MCP response exceeded {timeout_seconds:.3f} seconds")
                ready, _, _ = select.select(
                    [self.process.stdout.fileno()],
                    [],
                    [],
                    remaining,
                )
                if not ready:
                    raise TimeoutError(f"MCP response exceeded {timeout_seconds:.3f} seconds")
            line = self.process.stdout.readline()
            if not line:
                stderr = self.process.stderr.read().strip() if self.process.stderr is not None else ""
                detail = f"; stderr: {bounded(stderr)}" if stderr else ""
                raise RuntimeError(f"MCP server exited during {self.last_request}{detail}")
            message = json.loads(line)
            if message.get("id") == self.sequence:
                return message

    def initialize(self, timeout_seconds: float | None = None) -> None:
        self.request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": self.name, "version": "0.1.0"},
            },
            timeout_seconds=timeout_seconds,
        )
        if self.process.stdin is None:
            raise RuntimeError("MCP server stdin is unavailable")
        self.process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        self.process.stdin.flush()

    def call(
        self,
        name: str,
        arguments: dict,
        calls: list[dict[str, object]],
        timeout_seconds: float | None = None,
    ) -> object:
        started = time.monotonic()
        response = self.request(
            "tools/call",
            {"name": name, "arguments": arguments},
            timeout_seconds=timeout_seconds,
        )
        value = json_result(response)
        calls.append({"name": name, "durationMs": elapsed_ms(started), "result": shape(value)})
        return value

    def error(self, name: str, arguments: dict) -> str:
        response = self.request("tools/call", {"name": name, "arguments": arguments})
        result = response.get("result")
        if not isinstance(result, dict) or result.get("isError") is not True:
            raise RuntimeError(f"{name} unexpectedly succeeded: {bounded(response)}")
        content = result.get("content", [])
        message = " ".join(
            item.get("text", "")
            for item in content
            if isinstance(item, dict) and isinstance(item.get("text"), str)
        ).strip()
        if not message:
            raise RuntimeError(f"{name} returned an empty error")
        return message

    def close(self, timeout_seconds: float = 5.0) -> bool:
        if self.process.stdin is not None:
            try:
                self.process.stdin.close()
            except OSError:
                pass
        try:
            self.process.wait(timeout=timeout_seconds)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(self.process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                self.process.wait(timeout=min(2.0, timeout_seconds))
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(self.process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                self.process.wait(timeout=min(2.0, timeout_seconds))
        return self.process.poll() is not None


def run_mcp_diagnosis(binary: Path, timeout_seconds: float | None = None) -> dict[str, object]:
    client = MCPClient(mcp_environment(with_grants=True), "apple-debug-mcp-complex-runtime-case")
    calls: list[dict[str, object]] = []
    session_id: str | None = None
    started = time.monotonic()

    def bounded_call(name: str, arguments: dict) -> object:
        if timeout_seconds is None:
            return client.call(name, arguments, calls)
        remaining = timeout_seconds - (time.monotonic() - started)
        if remaining <= 0:
            raise TimeoutError("MCP diagnosis attempt deadline exhausted")
        return client.call(name, arguments, calls, timeout_seconds=remaining)

    def bounded_wait_milliseconds(default: int = 10_000) -> int:
        if timeout_seconds is None:
            return default
        remaining = timeout_seconds - (time.monotonic() - started)
        return max(1, min(default, int(remaining * 1_000)))

    try:
        client.initialize(timeout_seconds=timeout_seconds)
        created = bounded_call("apple_debug_session_create", {})
        if not isinstance(created, dict) or not isinstance(created.get("sessionID"), str):
            raise RuntimeError(f"session creation returned no session ID: {created}")
        session_id = created["sessionID"]
        bounded_call(
            "apple_debug_set_breakpoint",
            {
                "sessionID": session_id,
                "file": str(FIXTURE),
                "line": READ_LINE,
                "condition": "index == count",
                "hitCondition": "1",
            },
        )
        bounded_call(
            "apple_debug_launch",
            {"sessionID": session_id, "program": str(binary), "stopOnEntry": False},
        )
        wait = bounded_call(
            "apple_debug_wait_for_stop",
            {"sessionID": session_id, "timeoutMilliseconds": bounded_wait_milliseconds()},
        )
        if not isinstance(wait, dict) or not wait.get("stopped"):
            raise RuntimeError(f"function breakpoint did not stop the target: {wait}")
        threads = bounded_call("apple_debug_threads", {"sessionID": session_id})
        if not isinstance(threads, dict):
            raise RuntimeError(f"thread response was not an object: {threads}")
        thread_values = threads.get("body", {}).get("threads", []) if isinstance(threads.get("body"), dict) else []
        if not isinstance(thread_values, list) or not thread_values:
            raise RuntimeError(f"no stopped thread was returned: {threads}")
        thread_id = thread_values[0].get("id") if isinstance(thread_values[0], dict) else None
        if not isinstance(thread_id, int):
            raise RuntimeError(f"stopped thread had no numeric ID: {threads}")
        snapshot = bounded_call(
            "apple_debug_stop_snapshot",
            {"sessionID": session_id, "threadID": thread_id, "levels": 8},
        )
        stack = bounded_call(
            "apple_debug_stack_trace",
            {"sessionID": session_id, "threadID": thread_id, "levels": 4, "startFrame": 0},
        )
        stack_frames = stack.get("body", {}).get("stackFrames", []) if isinstance(stack, dict) and isinstance(stack.get("body"), dict) else []
        frame_id = stack_frames[0].get("id") if isinstance(stack_frames, list) and stack_frames and isinstance(stack_frames[0], dict) else None
        if not isinstance(frame_id, int):
            raise RuntimeError(f"no frame ID was returned: {stack}")
        scopes = bounded_call("apple_debug_scopes", {"sessionID": session_id, "frameID": frame_id})
        scope_values = scopes.get("body", {}).get("scopes", []) if isinstance(scopes, dict) and isinstance(scopes.get("body"), dict) else []
        variables_reference = scope_values[0].get("variablesReference", 0) if isinstance(scope_values, list) and scope_values and isinstance(scope_values[0], dict) else 0
        variables = None
        if isinstance(variables_reference, int) and variables_reference > 0:
            variables = bounded_call(
                "apple_debug_variables",
                {
                    "sessionID": session_id,
                    "variablesReference": variables_reference,
                    "start": 0,
                    "count": 16,
                    "formatHex": False,
                },
            )
        count_result = bounded_call(
            "apple_debug_evaluate",
            {"sessionID": session_id, "expression": "count", "frameID": frame_id},
        )
        index_result = bounded_call(
            "apple_debug_evaluate",
            {"sessionID": session_id, "expression": "index", "frameID": frame_id},
        )
        sentinel_result = bounded_call(
            "apple_debug_evaluate",
            {"sessionID": session_id, "expression": "readings[index]", "frameID": frame_id},
        )
        count = evaluated_int(count_result)
        index = evaluated_int(index_result)
        sentinel = evaluated_int(sentinel_result)
        bounded_call("apple_debug_continue", {"sessionID": session_id, "threadID": thread_id})
        completion = bounded_call(
            "apple_debug_wait_for_stop",
            {"sessionID": session_id, "timeoutMilliseconds": bounded_wait_milliseconds()},
        )
        if not isinstance(completion, dict) or not completion.get("terminated"):
            raise RuntimeError(f"buggy target did not terminate after continue: {completion}")
        closed = bounded_call("apple_debug_session_close", {"sessionID": session_id})
        session_id = None
        top_frame = stack_frames[0] if isinstance(stack_frames, list) and stack_frames and isinstance(stack_frames[0], dict) else {}
        snapshot_threads = snapshot.get("threads") if isinstance(snapshot, dict) else None
        snapshot_modules = snapshot.get("modules") if isinstance(snapshot, dict) else None
        return {
            "toolCalls": calls,
            "sessionClosed": isinstance(closed, dict) and closed.get("closed") is True,
            "threadID": thread_id,
            "frameID": frame_id,
            "observedCount": count,
            "observedIndex": index,
            "observedSentinel": sentinel,
            "topFrame": top_frame.get("name"),
            "topFrameSource": top_frame.get("source"),
            "topFrameLine": top_frame.get("line"),
            "stopSnapshot": {
                "hasThreads": bool(snapshot_threads),
                "hasModules": bool(snapshot_modules),
                "hasRegisters": isinstance(snapshot, dict) and snapshot.get("registers") is not None,
            },
            "stack": {"frameCount": len(stack_frames) if isinstance(stack_frames, list) else 0},
            "scopes": {"scopeCount": len(scope_values) if isinstance(scope_values, list) else 0},
            "variables": shape(variables) if variables is not None else None,
            "completion": {
                "terminated": completion.get("terminated"),
                "exitCode": process_exit_code(completion),
            },
            "ownedState": {
                "mcpSessionCreated": True,
                "mcpSessionClosed": isinstance(closed, dict) and closed.get("closed") is True,
                "ownedFixtureProcessTerminated": completion.get("terminated") is True,
            },
            "resultKind": "typed-json",
        }
    finally:
        if session_id is not None and client.process.poll() is None:
            try:
                client.call("apple_debug_session_close", {"sessionID": session_id}, calls)
            except Exception:
                pass
        client.close()


def computed_fixture_identity(binary: Path, fixed: bool) -> dict[str, object]:
    result = subprocess.run(
        ["xcrun", "dwarfdump", "--uuid", str(binary)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"could not compute fixture Mach-O identity: {bounded(result.stderr)}")
    match = re.search(r"UUID:\s*([0-9A-Fa-f-]{32,36})\s*\(([^)]+)\)", result.stdout)
    if match is None:
        raise RuntimeError(f"fixture UUID/architecture was not exposed: {bounded(result.stdout)}")
    return compute_identity(
        binary,
        macho_uuid=match.group(1),
        architecture=match.group(2),
        build_source_identity={
            "sourceSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
            "compileVariant": "fixed" if fixed else "buggy",
        },
        environment={"platform": sys.platform, "fixture": "complex-runtime"},
        target={"kind": "macOS-host", "fixture": str(FIXTURE)},
        scenario_oracle={
            "version": "complex-runtime-v1",
            "failureSignature": {"count": 4, "index": 4, "sentinel": -1000},
        },
    )


def run_adaptive_casebook_verification(
    buggy: Path,
    fixed: Path,
) -> tuple[object, dict[str, object]]:
    """Use the real MCP diagnosis as the baseline phase of the shared runner."""
    holder: dict[str, object] = {}
    owned_state = {"clean": True, "sequence": 0}
    pre_fix_identity = computed_fixture_identity(buggy, fixed=False)
    candidate_identity = computed_fixture_identity(fixed, fixed=True)

    def fresh_state(context) -> StateResult:
        if not owned_state["clean"]:
            return StateResult(
                StateStatus.FAILED,
                "previous owned casebook state was not cleaned",
                operation="fresh-owned-state",
            )
        owned_state["clean"] = False
        owned_state["sequence"] += 1
        return StateResult(
            StateStatus.FRESH,
            operation=f"fresh-owned-{context.phase.value}-state-{owned_state['sequence']}",
        )

    def cleanup_state(context) -> StateResult:
        if context.phase.value == "baseline":
            mcp = holder.get("mcp")
            if isinstance(mcp, dict):
                state = mcp.get("ownedState")
                if isinstance(state, dict) and state.get("mcpSessionClosed") and state.get("ownedFixtureProcessTerminated"):
                    owned_state["clean"] = True
                    return StateResult(
                        StateStatus.RESTORED,
                        operation="mcp-session-closed-and-owned-baseline-terminated",
                    )
            return StateResult(
                StateStatus.FAILED,
                "MCP session or owned baseline fixture process cleanup was not verified",
                operation="cleanup-owned-baseline",
            )
        fixed_run = holder.get("fixedRun")
        if isinstance(fixed_run, dict) and fixed_run.get("ownedProcessTerminated") is True:
            owned_state["clean"] = True
            return StateResult(
                StateStatus.RESTORED,
                operation="owned-fixed-candidate-process-waited-and-reaped",
            )
        return StateResult(
            StateStatus.FAILED,
            "owned fixed candidate process cleanup was not verified",
            operation="cleanup-owned-candidate",
        )

    def baseline_attempt(context) -> Observation:
        remaining = max(0.2, min(context.deadline - time.monotonic(), context.cumulative_deadline - time.monotonic()))
        mcp = run_mcp_diagnosis(buggy, timeout_seconds=remaining)
        holder["mcp"] = mcp
        decisive = (
            mcp.get("observedCount") == 4
            and mcp.get("observedIndex") == 4
            and mcp.get("observedSentinel") == -1000
            and mcp.get("completion", {}).get("exitCode") == 1
        )
        return Observation(
            decisive=decisive,
            signature={
                "observedCount": mcp.get("observedCount"),
                "observedIndex": mcp.get("observedIndex"),
                "observedSentinel": mcp.get("observedSentinel"),
                "topFrame": mcp.get("topFrame"),
            },
            complete=decisive and mcp.get("sessionClosed") is True,
            diagnostic=None if decisive else "MCP baseline did not reproduce the typed runtime failure",
            evidence=(
                {
                    "kind": "mcp-baseline",
                    "resultKind": mcp.get("resultKind"),
                    "observedCount": mcp.get("observedCount"),
                    "observedIndex": mcp.get("observedIndex"),
                    "observedSentinel": mcp.get("observedSentinel"),
                    "sessionClosed": mcp.get("sessionClosed"),
                },
            ),
            identity=pre_fix_identity,
        )

    def candidate_attempt(context) -> Observation:
        remaining = max(0.2, min(context.deadline - time.monotonic(), context.cumulative_deadline - time.monotonic()))
        timeout = max(1, int(remaining))
        try:
            fixed_run = run_program(fixed, timeout=timeout)
        except subprocess.TimeoutExpired:
            fixed_run = {"path": str(fixed), "exitCode": None, "timeout": True}
        holder["fixedRun"] = fixed_run
        accepted = fixed_run.get("exitCode") == 0
        return Observation(
            accepted=accepted,
            guardrails_passed=accepted,
            regression_decisive=not accepted,
            diagnostic=None if accepted else "fixed fixture failed its post-fix guardrail",
            evidence=(
                {
                    "kind": "fixed-candidate",
                    "exitCode": fixed_run.get("exitCode"),
                    "stdout": bounded(fixed_run.get("stdout", "")),
                    "stderr": bounded(fixed_run.get("stderr", "")),
                },
            ),
            identity=candidate_identity,
        )

    result = run_adaptive_verification(
        baseline_attempt,
        candidate_attempt,
        fresh_state=fresh_state,
        cleanup=cleanup_state,
        pre_fix_identity=pre_fix_identity,
        candidate_identity=candidate_identity,
    )
    return result, holder


def run_policy_probe(binary: Path) -> dict[str, object]:
    client = MCPClient(mcp_environment(with_grants=False), "apple-debug-mcp-complex-policy-case")
    session_id: str | None = None
    try:
        client.initialize()
        created = json_result(client.request("tools/call", {"name": "apple_debug_session_create", "arguments": {}}))
        if not isinstance(created, dict) or not isinstance(created.get("sessionID"), str):
            raise RuntimeError(f"policy session creation returned no session ID: {created}")
        session_id = created["sessionID"]
        message = client.error(
            "apple_debug_launch",
            {"sessionID": session_id, "program": str(binary), "stopOnEntry": True},
        )
        if "disabled" not in message.lower():
            raise RuntimeError(f"launch was not rejected by policy: {message}")
        closed = json_result(
            client.request(
                "tools/call",
                {"name": "apple_debug_session_close", "arguments": {"sessionID": session_id}},
            )
        )
        session_id = None
        return {
            "launchRejected": True,
            "message": bounded(message),
            "sessionClosed": isinstance(closed, dict) and closed.get("closed") is True,
        }
    finally:
        if session_id is not None and client.process.poll() is None:
            try:
                client.request(
                    "tools/call",
                    {"name": "apple_debug_session_close", "arguments": {"sessionID": session_id}},
                )
            except Exception:
                pass
        client.close()


def write_evidence(path: Path, payload: dict[str, object]) -> None:
    path = path if path.is_absolute() else ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    evidence_path = args.evidence_output if args.evidence_output.is_absolute() else ROOT / args.evidence_output
    evidence: dict[str, object] = {
        "schemaVersion": 1,
        "workflow": "complex-runtime-bug-fix-v1",
        "status": "running",
        "createdAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "runner": {"model": args.model, "reasoning": args.reasoning},
        "case": {
            "fixture": str(FIXTURE),
            "sourceSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
            "bug": "length-bound loop uses index <= count",
            "expectedCount": 4,
            "expectedTotal": 47,
            "sourceLine": SOURCE_LINE,
            "readLine": READ_LINE,
            "repairMode": "pre-authored-compile-variant; not an agent-repair benchmark",
        },
    }
    try:
        if not SERVER.is_file():
            raise RuntimeError("build .build/debug/apple-debug-mcp before running the casebook")
        if not FIXTURE.is_file():
            raise RuntimeError(f"fixture is missing: {FIXTURE}")

        demo_dir = ROOT / ".build/demos/complex-runtime"
        buggy = demo_dir / "complex-runtime-buggy"
        fixed = demo_dir / "complex-runtime-fixed"
        build_records = {
            "buggy": build_variant(buggy, fixed=False),
            "fixed": build_variant(fixed, fixed=True),
        }
        buggy_run = run_program(buggy)
        if buggy_run["exitCode"] == 0:
            raise RuntimeError(f"buggy fixture unexpectedly passed: {buggy_run}")
        manual = run_manual_lldb(buggy)
        adaptive_result, adaptive_evidence = run_adaptive_casebook_verification(buggy, fixed)
        mcp = adaptive_evidence.get("mcp")
        fixed_run = adaptive_evidence.get("fixedRun")
        if not isinstance(mcp, dict) or not isinstance(fixed_run, dict):
            raise RuntimeError(f"adaptive casebook did not retain baseline/candidate evidence: {adaptive_evidence}")
        if adaptive_result.outcome.value != "verified":
            raise RuntimeError(f"adaptive post-fix verification was not verified: {adaptive_result.as_dict()}")
        policy = run_policy_probe(buggy)
        if fixed_run["exitCode"] != 0:
            raise RuntimeError(f"fixed fixture did not pass: {fixed_run}")
        if manual.get("targetExitCode") != 1 or manual.get("observedCount") != 4 or manual.get("observedIndex") != 4 or manual.get("observedSentinel") != -1000:
            raise RuntimeError(f"manual lane did not observe the failing length-boundary case: {manual}")
        if mcp.get("observedCount") != 4:
            raise RuntimeError(f"MCP observed an unexpected count: {mcp}")
        if mcp.get("observedIndex") != 4:
            raise RuntimeError(f"MCP did not stop at the invalid loop boundary: {mcp}")
        if mcp.get("observedSentinel") != -1000:
            raise RuntimeError(f"MCP did not observe the sentinel outside the logical range: {mcp}")
        if mcp.get("topFrame") != "sum_readings" or mcp.get("topFrameLine") != READ_LINE:
            raise RuntimeError(f"MCP stopped in an unexpected frame: {mcp}")
        top_frame_source = mcp.get("topFrameSource")
        if not isinstance(top_frame_source, dict) or top_frame_source.get("path") != str(FIXTURE):
            raise RuntimeError(f"MCP stopped without the fixture source mapping: {mcp}")
        stop_snapshot = mcp.get("stopSnapshot")
        if not isinstance(stop_snapshot, dict) or not stop_snapshot.get("hasThreads") or not stop_snapshot.get("hasModules"):
            raise RuntimeError(f"MCP stop snapshot did not contain correlated thread/module evidence: {mcp}")
        if mcp.get("completion", {}).get("exitCode") != 1:
            raise RuntimeError(f"MCP did not preserve the buggy process exit evidence: {mcp}")
        if not mcp.get("sessionClosed"):
            raise RuntimeError(f"MCP session cleanup was not verified: {mcp}")
        if not policy.get("launchRejected") or not policy.get("sessionClosed"):
            raise RuntimeError(f"MCP policy cleanup was not verified: {policy}")

        evidence.update(
            {
                "status": "passed",
                "builds": build_records,
                "buggyRun": buggy_run,
                "manual": manual,
                "mcp": mcp,
                "adaptiveVerification": adaptive_result.as_dict(),
                "policy": policy,
                "repair": {
                    "change": "index <= count -> index < count",
                    "fixedRun": fixed_run,
                    "verified": True,
                },
                "cleanup": {
                    "mcpSessionClosed": mcp.get("sessionClosed") is True,
                    "policySessionClosed": policy.get("sessionClosed") is True,
                },
                "comparison": {
                    "timingComparable": False,
                    "manualScope": "native LLDB breakpoint, text inspection, and continue",
                    "mcpScope": "MCP session, typed stop snapshot, scopes, variables, two evaluations, continue, wait, and close",
                    "reason": "The MCP lane intentionally returns richer evidence; elapsed times must not be presented as a speedup claim.",
                },
            }
        )
        write_evidence(evidence_path, evidence)
        print(f"complex-debug-casebook: runtime bug diagnosed, fixed variant passed, evidence written to {evidence_path}")
        return 0
    except Exception as error:
        evidence["status"] = "failed"
        evidence["failure"] = bounded(error)
        write_evidence(evidence_path, evidence)
        print(f"complex-debug-casebook: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
