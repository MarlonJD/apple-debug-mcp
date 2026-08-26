#!/usr/bin/env python3
"""Exercise the authorized macOS fixture through the MCP debugger surface."""

import argparse
import base64
import json
import os
import platform
import re
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone


def bounded_text(value: object, limit: int = 2_000) -> str:
    text = str(value)
    return text if len(text) <= limit else f"{text[:limit]}..."


class WorkflowEvidence:
    def __init__(self, output_path: Path | None, server: Path, fixture: Path) -> None:
        self.output_path = output_path
        self.payload: dict[str, object] = {
            "schemaVersion": 1,
            "workflow": "macos-debugger-v1",
            "transport": "stdio",
            "status": "running",
            "createdAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "target": {
                "kind": "authorized-local-fixture",
                "serverPath": str(server),
                "fixturePath": str(fixture),
            },
            "steps": [],
            "toolCalls": [],
            "cleanup": {
                "sessionClosed": False,
                "serverExited": False,
            },
        }

    def step(self, name: str, **details: object) -> None:
        record: dict[str, object] = {"name": name, "status": "passed"}
        record.update(details)
        steps = self.payload["steps"]
        assert isinstance(steps, list)
        steps.append(record)

    def tool_call(self, name: str, status: str, **details: object) -> None:
        record: dict[str, object] = {"name": name, "status": status}
        record.update(details)
        calls = self.payload["toolCalls"]
        assert isinstance(calls, list)
        calls.append(record)

    def failure(self, error: object, last_request: str) -> None:
        self.payload["status"] = "failed"
        self.payload["failure"] = {
            "error": bounded_text(error),
            "lastRequest": last_request,
        }

    def passed(self) -> None:
        self.payload["status"] = "passed"

    def write(self) -> None:
        if self.output_path is None:
            return
        self.output_path.parent.mkdir(parents=True, exist_ok=True)
        self.output_path.write_text(
            json.dumps(self.payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )


class MCPClient:
    def __init__(self, server: Path, environment: dict[str, str], client_name: str) -> None:
        self.process = subprocess.Popen(
            [str(server)],
            cwd=server.parents[2],
            env=environment,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
        self.client_name = client_name
        self.sequence = 0
        self.last_request = "startup"

    def request(self, method: str, params: dict) -> dict:
        self.sequence += 1
        self.last_request = f"{method}#{self.sequence}"
        if self.process.stdin is None or self.process.stdout is None:
            raise RuntimeError("MCP server pipes are unavailable")
        self.process.stdin.write(
            json.dumps(
                {"jsonrpc": "2.0", "id": self.sequence, "method": method, "params": params},
                separators=(",", ":"),
            )
            + "\n"
        )
        self.process.stdin.flush()
        while True:
            line = self.process.stdout.readline()
            if not line:
                stderr = self.process.stderr.read().strip() if self.process.stderr is not None else ""
                detail = f"; stderr: {bounded_text(stderr)}" if stderr else ""
                raise RuntimeError(f"MCP server exited during {self.last_request}{detail}")
            message = json.loads(line)
            if message.get("id") == self.sequence:
                return message

    def initialize(self) -> None:
        self.request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": self.client_name, "version": "0.1.0"},
            },
        )
        if self.process.stdin is None:
            raise RuntimeError("MCP server stdin is unavailable")
        self.process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        self.process.stdin.flush()

    def call(self, name: str, arguments: dict | None = None) -> dict:
        response = self.request(
            "tools/call",
            {"name": name, "arguments": arguments or {}},
        )
        result = response.get("result")
        if not isinstance(result, dict):
            raise RuntimeError(f"{name} did not return an MCP result: {response}")
        if result.get("isError") is True:
            raise RuntimeError(f"{name} returned an error: {self.text(result)}")
        return response

    @staticmethod
    def text(result: dict) -> str:
        content = result.get("content")
        if not isinstance(content, list):
            raise RuntimeError(f"MCP result has no content: {result}")
        texts = [
            item.get("text")
            for item in content
            if isinstance(item, dict) and isinstance(item.get("text"), str)
        ]
        if not texts:
            raise RuntimeError(f"MCP result has no text content: {result}")
        return "\n".join(texts)

    def success(self, name: str, arguments: dict | None = None) -> object:
        response = self.call(name, arguments)
        try:
            return json.loads(self.text(response["result"]))
        except json.JSONDecodeError as error:
            raise RuntimeError(f"{name} did not return JSON content") from error

    def error(self, name: str, arguments: dict | None = None) -> str:
        response = self.request(
            "tools/call",
            {"name": name, "arguments": arguments or {}},
        )
        result = response.get("result")
        if not isinstance(result, dict) or result.get("isError") is not True:
            raise RuntimeError(f"{name} unexpectedly succeeded: {response}")
        message = self.text(result).strip()
        if not message:
            raise RuntimeError(f"{name} returned an empty error")
        return message

    def close(self) -> bool:
        if self.process.stdin is not None:
            try:
                self.process.stdin.close()
            except OSError:
                pass
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(self.process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(self.process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                self.process.wait(timeout=5)
        return self.process.poll() is not None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--evidence-output",
        type=Path,
        help="write a bounded JSON workflow manifest to this path",
    )
    parser.add_argument(
        "--extended",
        action="store_true",
        help="also verify policy rejection and failed-launch session cleanup",
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


def run_policy_probe(server: Path, fixture: Path, evidence: WorkflowEvidence) -> dict[str, object]:
    client = MCPClient(server, environment_without_grants(), "apple-debug-mcp-policy-probe")
    session_id = None
    try:
        client.initialize()
        created = client.success("apple_debug_session_create")
        if not isinstance(created, dict) or not isinstance(created.get("sessionID"), str):
            raise RuntimeError(f"policy probe created no session: {created}")
        session_id = created["sessionID"]
        message = client.error(
            "apple_debug_launch",
            {"sessionID": session_id, "program": str(fixture), "stopOnEntry": True},
        )
        if "disabled" not in message.lower():
            raise RuntimeError(f"launch policy error was not explicit: {message}")
        closed = client.success("apple_debug_session_close", {"sessionID": session_id})
        if not isinstance(closed, dict) or closed.get("closed") is not True:
            raise RuntimeError(f"policy probe session did not close: {closed}")
        evidence.step(
            "policy_rejection",
            operation="target_launch",
            rejected=True,
            error=bounded_text(message),
            sessionClosed=True,
        )
        return {"status": "passed", "operation": "target_launch", "sessionClosed": True}
    finally:
        client.close()


def run_failed_launch_probe(server: Path, evidence: WorkflowEvidence) -> dict[str, object]:
    with tempfile.NamedTemporaryFile(prefix="apple-debug-invalid-target-", suffix=".txt", delete=False) as handle:
        invalid_target = Path(handle.name)
        handle.write(b"not an executable target\n")
    environment = environment_without_grants()
    environment["APPLE_DEBUG_ALLOW_TARGET_LAUNCH"] = "1"
    client = MCPClient(server, environment, "apple-debug-mcp-failure-probe")
    session_id = None
    try:
        client.initialize()
        created = client.success("apple_debug_session_create")
        if not isinstance(created, dict) or not isinstance(created.get("sessionID"), str):
            raise RuntimeError(f"failed-launch probe created no session: {created}")
        session_id = created["sessionID"]
        message = client.error(
            "apple_debug_launch",
            {"sessionID": session_id, "program": str(invalid_target), "stopOnEntry": True},
        )
        sessions = client.success("apple_debug_session_list")
        if not isinstance(sessions, list) or any(
            isinstance(item, dict) and item.get("sessionID") == session_id for item in sessions
        ):
            raise RuntimeError(f"failed launch left an owned session behind: {sessions}")
        closed = client.success("apple_debug_session_close", {"sessionID": session_id})
        if not isinstance(closed, dict) or closed.get("closed") is not False:
            raise RuntimeError(f"failed-launch cleanup was not authoritative: {closed}")
        evidence.step(
            "failed_launch_cleanup",
            rejected=True,
            error=bounded_text(message),
            sessionRemoved=True,
            closeAfterRemoval=False,
        )
        return {"status": "passed", "sessionRemoved": True, "closeAfterRemoval": False}
    finally:
        client.close()
        try:
            invalid_target.unlink()
        except FileNotFoundError:
            pass


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parents[1]
    server = root / ".build" / "debug" / "apple-debug-mcp"
    fixture = root / ".build" / "fixtures" / "apple-debug-mcp-debug-target"
    evidence_path = args.evidence_output
    if evidence_path is not None and not evidence_path.is_absolute():
        evidence_path = root / evidence_path
    evidence = WorkflowEvidence(evidence_path, server, fixture)
    if not server.is_file() or not fixture.is_file():
        print("fixture-smoke: build the server and fixture before running", file=sys.stderr)
        evidence.failure("server or fixture is missing", "startup")
        evidence.write()
        return 1

    environment = dict(os.environ)
    environment["APPLE_DEBUG_ALLOW_TARGET_LAUNCH"] = "1"
    environment["APPLE_DEBUG_ALLOW_EVALUATE"] = "1"
    environment["APPLE_DEBUG_ALLOW_MEMORY_WRITE"] = "1"
    process = subprocess.Popen(
        [str(server)],
        cwd=root,
        env=environment,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    time.sleep(0.2)
    sequence = 0
    session_id = None
    last_request = "startup"

    def request(method: str, params: dict) -> dict:
        nonlocal sequence, last_request
        sequence += 1
        last_request = f"{method}#{sequence}"
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
                assert process.stderr is not None
                stderr = process.stderr.read().strip()
                detail = f"; stderr: {stderr[:2_000]}" if stderr else ""
                raise RuntimeError(f"MCP server exited during {last_request}{detail}")
            message = json.loads(line)
            if message.get("id") == sequence:
                return message

    def tool(name: str, arguments: dict) -> dict:
        response = request(
            "tools/call",
            {"name": name, "arguments": arguments},
        )
        if response.get("result", {}).get("isError"):
            evidence.tool_call(name, "error")
            raise RuntimeError(response)
        evidence.tool_call(name, "passed")
        return response

    try:
        request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-fixture-smoke", "version": "0.1.0"},
            },
        )
        evidence.step("initialize", protocolVersion="2025-11-25")
        assert process.stdin is not None
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.flush()

        created = tool("apple_debug_session_create", {})
        session_id = json.loads(created["result"]["content"][0]["text"])["sessionID"]
        evidence.step("session_create", sessionID=session_id)
        source_path = str(root / "Tests" / "Fixtures" / "debug_target.c")

        tool(
            "apple_debug_set_function_breakpoint",
            {"sessionID": session_id, "name": "main", "hitCondition": "1"},
        )
        tool(
            "apple_debug_set_exception_breakpoints",
            {"sessionID": session_id, "filters": ["cpp_throw"]},
        )

        breakpoint_result = tool(
            "apple_debug_set_breakpoint",
            {
                "sessionID": session_id,
                "file": source_path,
                "line": 10,
                "condition": "1 == 1",
                "hitCondition": "1",
                "logMessage": "fixture breakpoint",
            },
        )
        if "breakpoints" not in breakpoint_result["result"]["content"][0]["text"]:
            raise RuntimeError("breakpoint response did not contain breakpoints")
        evidence.step("breakpoints", sourceLine=10, function="main", exceptionFilter="cpp_throw")

        tool(
            "apple_debug_launch",
            {
                "sessionID": session_id,
                "program": str(fixture),
                "stopOnEntry": True,
            },
        )
        evidence.step("launch", target="authorized-local-fixture", stopOnEntry=True)
        tool(
            "apple_debug_breakpoint_locations",
            {"sessionID": session_id, "file": source_path, "line": 10},
        )
        threads = json.loads(
            tool("apple_debug_threads", {"sessionID": session_id})["result"]["content"][0]["text"]
        )["body"]["threads"]
        if not threads:
            raise RuntimeError("debugger returned no threads")
        thread_id = threads[0]["id"]
        evidence.step("threads", count=len(threads), selectedThreadID=thread_id)
        stop_snapshot = json.loads(
            tool(
                "apple_debug_stop_snapshot",
                {"sessionID": session_id, "threadID": thread_id, "levels": 10},
            )["result"]["content"][0]["text"]
        )
        if not stop_snapshot.get("threads") or not stop_snapshot.get("modules"):
            raise RuntimeError("stop snapshot did not contain threads and modules")
        evidence.step(
            "stop_snapshot",
            threadCount=len(stop_snapshot.get("threads", [])),
            moduleCount=len(stop_snapshot.get("modules", [])),
        )
        tool("apple_debug_modules", {"sessionID": session_id, "moduleCount": 100})

        stack = json.loads(
            tool(
                "apple_debug_stack_trace",
                {"sessionID": session_id, "threadID": thread_id, "levels": 5, "startFrame": 0},
            )["result"]["content"][0]["text"]
        )["body"]["stackFrames"]
        if not stack:
            raise RuntimeError("debugger returned no stack frames")
        frame_id = stack[0]["id"]
        instruction_reference = stack[0]["instructionPointerReference"]
        evidence.step("stack_scopes_registers", stackFrames=len(stack), frameID=frame_id)
        tool(
            "apple_debug_set_instruction_breakpoint",
            {"sessionID": session_id, "instructionReference": instruction_reference},
        )

        scopes = json.loads(
            tool("apple_debug_scopes", {"sessionID": session_id, "frameID": frame_id})["result"]["content"][0]["text"]
        )["body"]["scopes"]
        if not scopes:
            raise RuntimeError("debugger returned no frame scopes")
        variables_reference = scopes[0].get("variablesReference", 0)
        if variables_reference:
            tool(
                "apple_debug_variables",
                {
                    "sessionID": session_id,
                    "variablesReference": variables_reference,
                    "start": 0,
                    "count": 10,
                    "formatHex": True,
                },
            )
        registers = json.loads(
            tool("apple_debug_registers", {"sessionID": session_id, "frameID": frame_id})["result"]["content"][0]["text"]
        )
        if "scopes" not in registers:
            raise RuntimeError("register snapshot did not contain scopes")
        tool(
            "apple_debug_evaluate",
            {"sessionID": session_id, "expression": "1 + 1", "frameID": frame_id},
        )
        stack_pointer_evaluation = tool(
            "apple_debug_evaluate",
            {"sessionID": session_id, "expression": "$sp", "frameID": frame_id},
        )
        stack_pointer_text = stack_pointer_evaluation["result"]["content"][0]["text"]
        stack_pointer_match = re.search(r"0x[0-9a-fA-F]+", stack_pointer_text)
        if stack_pointer_match is None:
            raise RuntimeError("debugger did not return a stack pointer for assembly patch evidence")
        stack_reference = stack_pointer_match.group(0)
        tool(
            "apple_debug_completions",
            {"sessionID": session_id, "text": "debug_", "column": 7},
        )

        memory_response = tool(
            "apple_debug_read_memory",
            {"sessionID": session_id, "memoryReference": instruction_reference, "count": 16},
        )
        memory_body = json.loads(memory_response["result"]["content"][0]["text"])["body"]
        memory_bytes = base64.b64decode(memory_body["data"])
        search_result = json.loads(
            tool(
                "apple_debug_search_memory",
                {
                    "sessionID": session_id,
                    "memoryReference": instruction_reference,
                    "count": 16,
                    "pattern": base64.b64encode(memory_bytes[:2]).decode("ascii"),
                },
            )["result"]["content"][0]["text"]
        )
        if not search_result.get("matches"):
            raise RuntimeError("memory search did not find the bytes returned by readMemory")
        evidence.step("memory_search", bytesRead=len(memory_bytes), matches=len(search_result.get("matches", [])))
        architecture = "arm64" if platform.machine() in {"arm64", "aarch64"} else "x86_64"
        evidence.payload["target"]["architecture"] = architecture
        assembly_source = "nop\n"
        assembled = json.loads(
            tool(
                "apple_assemble",
                {"architecture": architecture, "source": assembly_source},
            )["result"]["content"][0]["text"]
        )
        assembled_bytes = base64.b64decode(assembled["bytesBase64"])
        stack_memory = json.loads(
            tool(
                "apple_debug_read_memory",
                {"sessionID": session_id, "memoryReference": stack_reference, "count": len(assembled_bytes)},
            )["result"]["content"][0]["text"]
        )["body"]
        original_bytes = base64.b64decode(stack_memory["data"])
        assembly_patch = json.loads(
            tool(
                "apple_debug_patch_assembly",
                {
                    "sessionID": session_id,
                    "memoryReference": stack_reference,
                    "architecture": architecture,
                    "source": assembly_source,
                    "expectedData": base64.b64encode(original_bytes).decode("ascii"),
                },
            )["result"]["content"][0]["text"]
        )
        if not assembly_patch.get("patch", {}).get("verified"):
            raise RuntimeError("assembly patch was not verified")
        tool(
            "apple_debug_patch_memory",
            {
                "sessionID": session_id,
                "memoryReference": stack_reference,
                "data": assembly_patch["patch"]["originalData"],
                "expectedData": base64.b64encode(assembled_bytes).decode("ascii"),
            },
        )
        evidence.step("patch_rollback", verified=True, restored=True, byteCount=len(assembled_bytes))
        forward_trace = json.loads(
            tool(
                "apple_debug_forward_trace",
                {
                    "sessionID": session_id,
                    "threadID": thread_id,
                    "steps": 1,
                    "kind": "next",
                    "granularity": "instruction",
                },
            )["result"]["content"][0]["text"]
        )
        if forward_trace.get("reverseExecutionSupported") or forward_trace.get("completedSteps") != 1:
            raise RuntimeError("forward execution trace did not return one explicit non-reversible stop point")
        evidence.step(
            "forward_trace",
            completedSteps=forward_trace.get("completedSteps"),
            reverseExecutionSupported=forward_trace.get("reverseExecutionSupported"),
        )
        tool(
            "apple_debug_disassemble",
            {"sessionID": session_id, "memoryReference": instruction_reference, "instructionCount": 4},
        )
        tool(
            "apple_debug_step",
            {"sessionID": session_id, "threadID": thread_id, "kind": "next", "granularity": "instruction"},
        )
        tool("apple_debug_continue", {"sessionID": session_id, "threadID": thread_id})
        wait_result = json.loads(
            tool(
                "apple_debug_wait_for_stop",
                {"sessionID": session_id, "timeoutMilliseconds": 10_000},
            )["result"]["content"][0]["text"]
        )
        if not wait_result.get("stopped") and not wait_result.get("terminated"):
            raise RuntimeError("wait_for_stop did not observe a stopped or terminated event")
        evidence.step("continue_and_wait", stopped=wait_result.get("stopped", False), terminated=wait_result.get("terminated", False))
        closed = json.loads(
            tool("apple_debug_session_close", {"sessionID": session_id})["result"]["content"][0]["text"]
        )
        if not closed.get("closed"):
            raise RuntimeError("debug session did not close")
        closed_session_id = session_id
        session_id = None
        evidence.payload["cleanup"]["sessionClosed"] = True
        evidence.step("session_close", sessionID=closed_session_id, closed=True)
        if args.extended:
            evidence.payload["extendedProbes"] = {
                "policy": run_policy_probe(server, fixture, evidence),
                "failedLaunchCleanup": run_failed_launch_probe(server, evidence),
            }
        evidence.passed()
        print("fixture-smoke: launch, source/instruction breakpoints, exceptions, stop snapshot, modules, threads, stack, registers, scopes, variables, completions, evaluate, memory, assembler patch/rollback, disassembly, instruction stepping, continue, stop-event wait, and cleanup passed")
        if evidence.output_path is not None:
            print(f"fixture-smoke: evidence manifest written to {evidence.output_path}")
        return 0
    except Exception as error:
        evidence.failure(error, last_request)
        print(f"fixture-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if session_id is not None and process.poll() is None:
            try:
                request("tools/call", {"name": "apple_debug_session_close", "arguments": {"sessionID": session_id}})
            except Exception:
                pass
        if process.stdin is not None:
            process.stdin.close()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
        evidence.payload["cleanup"]["serverExited"] = process.poll() is not None
        evidence.write()


if __name__ == "__main__":
    raise SystemExit(main())
