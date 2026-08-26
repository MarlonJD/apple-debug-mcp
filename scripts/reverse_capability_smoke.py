#!/usr/bin/env python3
"""Verify the reverse-execution capability report fails closed on Apple LLDB."""

import json
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    server_path = root / ".build" / "debug" / "apple-debug-mcp"
    process = subprocess.Popen(
        [str(server_path)],
        cwd=root,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        assert process.stdin is not None
        process.stdin.write(json.dumps({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "apple-debug-mcp-reverse-smoke", "version": "0.1.0"},
            },
        }) + "\n")
        process.stdin.flush()
        assert process.stdout is not None
        while process.stdout.readline():
            break
        process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n')
        process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "apple_debug_reverse_capabilities", "arguments": {}}}) + "\n")
        process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "apple_kernel_capabilities", "arguments": {}}}) + "\n")
        process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "apple_debug_replay_capabilities", "arguments": {}}}) + "\n")
        process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": 5, "method": "tools/call", "params": {"name": "apple_kernel_lab_capabilities", "arguments": {}}}) + "\n")
        process.stdin.flush()
        reverse_payload = None
        kernel_payload = None
        replay_payload = None
        kernel_lab_payload = None
        while True:
            line = process.stdout.readline()
            if not line:
                raise RuntimeError(process.stderr.read())
            response = json.loads(line)
            if response.get("id") == 2:
                reverse_payload = json.loads(response["result"]["content"][0]["text"])
            if response.get("id") == 3:
                kernel_payload = json.loads(response["result"]["content"][0]["text"])
            if response.get("id") == 4:
                replay_payload = json.loads(response["result"]["content"][0]["text"])
            if response.get("id") == 5:
                kernel_lab_payload = json.loads(response["result"]["content"][0]["text"])
            if all(payload is not None for payload in (reverse_payload, kernel_payload, replay_payload, kernel_lab_payload)):
                break
        if any(reverse_payload.get(key) for key in ("processRecordSupported", "reverseStepSupported", "reverseContinueSupported", "timeTravelSupported")):
            raise RuntimeError(f"reverse capability report claimed unsupported Apple features: {reverse_payload}")
        if any(kernel_payload.get(key) for key in ("kernelTaskAttachSupported", "kernelMemoryReadSupported", "kernelMemoryWriteSupported", "kextDebuggingSupported")):
            raise RuntimeError(f"kernel capability report claimed unsupported Apple features: {kernel_payload}")
        if not replay_payload.get("checkpointReplaySupported") or replay_payload.get("nativeReverseExecutionSupported") or replay_payload.get("externalRecordReplaySupported"):
            raise RuntimeError(f"replay capability boundary is incorrect: {replay_payload}")
        if kernel_lab_payload.get("memoryWriteSupported"):
            raise RuntimeError(f"kernel lab capability report exposed memory write: {kernel_lab_payload}")
        print("reverse-capability-smoke: reverse/time-travel, checkpoint replay, kernel memory, and kernel-lab write boundaries passed")
        return 0
    except Exception as error:
        print(f"reverse-capability-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if process.stdin is not None:
            process.stdin.close()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
