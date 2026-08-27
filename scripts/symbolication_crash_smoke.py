#!/usr/bin/env python3
"""Build a real macOS binary+dSYM and prove bounded crash symbolication."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

from complex_debug_casebook import MCPClient, bounded, environment_without_grants


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Tests/Fixtures/symbolication_target.c"
SERVER = ROOT / ".build/debug/apple-debug-mcp"


def run(arguments: list[str], timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        arguments,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        raise RuntimeError(f"required tool is unavailable: {name}")


def parse_uuid_and_architecture(binary: Path) -> tuple[str, str]:
    result = run(["xcrun", "dwarfdump", "--uuid", str(binary)])
    if result.returncode != 0:
        raise RuntimeError(f"dwarfdump --uuid failed: {bounded(result.stderr)}")
    match = re.search(r"UUID:\s*([0-9A-Fa-f-]{32,36})\s*\(([^)]+)\)", result.stdout)
    if match is None:
        raise RuntimeError(f"dwarfdump did not return a UUID/architecture: {bounded(result.stdout)}")
    raw_uuid = match.group(1).lower().replace("-", "")
    normalized = f"{raw_uuid[:8]}-{raw_uuid[8:12]}-{raw_uuid[12:16]}-{raw_uuid[16:20]}-{raw_uuid[20:]}"
    return normalized, match.group(2)


def parse_text_segment(binary: Path, architecture: str) -> tuple[int, int]:
    result = run(["xcrun", "otool", "-arch", architecture, "-l", str(binary)])
    if result.returncode != 0:
        raise RuntimeError(f"otool -l failed: {bounded(result.stderr)}")
    lines = result.stdout.splitlines()
    for index, line in enumerate(lines):
        if line.strip() != "segname __TEXT":
            continue
        vmaddr: int | None = None
        vmsize: int | None = None
        for candidate in lines[index : index + 12]:
            vmaddr_match = re.search(r"vmaddr\s+(0x[0-9a-fA-F]+)", candidate)
            vmsize_match = re.search(r"vmsize\s+(0x[0-9a-fA-F]+)", candidate)
            if vmaddr_match:
                vmaddr = int(vmaddr_match.group(1), 16)
            if vmsize_match:
                vmsize = int(vmsize_match.group(1), 16)
        if vmaddr is not None and vmsize is not None and vmsize > 0:
            return vmaddr, vmsize
    raise RuntimeError("otool did not expose a usable __TEXT range")


def parse_symbol(binary: Path, architecture: str) -> int:
    result = run(["xcrun", "nm", "-arch", architecture, "-n", str(binary)])
    if result.returncode != 0:
        raise RuntimeError(f"nm failed: {bounded(result.stderr)}")
    for line in result.stdout.splitlines():
        if "symbolication_fixture_symbol" not in line:
            continue
        match = re.match(r"\s*([0-9a-fA-F]+)\s+[A-Za-z]\s+", line)
        if match:
            return int(match.group(1), 16)
    raise RuntimeError("nm did not expose the deterministic fixture symbol")


def json_result(response: dict[str, object]) -> object:
    result = response.get("result")
    if not isinstance(result, dict) or result.get("isError") is True:
        raise RuntimeError(f"MCP symbolication call failed: {bounded(response)}")
    content = result.get("content")
    if not isinstance(content, list):
        raise RuntimeError(f"MCP symbolication result has no content: {bounded(response)}")
    text = "\n".join(
        item.get("text", "")
        for item in content
        if isinstance(item, dict) and isinstance(item.get("text"), str)
    )
    try:
        return json.loads(text)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"MCP symbolication result was not JSON: {bounded(text)}") from error


def main() -> int:
    run_root = ROOT / ".build/demos/symbolication" / str(uuid.uuid4())
    run_root.mkdir(parents=True, exist_ok=True)
    object_path = run_root / "symbolication_target.o"
    binary = run_root / "SymbolicationFixture"
    dsym = run_root / "SymbolicationFixture.dSYM"
    crash = run_root / "symbolication.crash"
    ips = run_root / "symbolication.ips"
    evidence_path = ROOT / ".build/evidence/symbolication-crash-smoke.json"
    evidence: dict[str, object] = {
        "schemaVersion": 1,
        "workflow": "symbolication-crash-smoke-v1",
        "status": "running",
        "runDirectory": str(run_root),
        "source": {
            "path": str(SOURCE),
            "sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        },
        "execution": "fixture is compiled and inspected only; it is never launched",
    }
    client: MCPClient | None = None
    try:
        if not SERVER.is_file():
            raise RuntimeError("build .build/debug/apple-debug-mcp before running this smoke")
        for tool in ("clang", "xcrun"):
            require_tool(tool)
        compile_result = run([
            "clang", "-g", "-O0", "-fno-omit-frame-pointer", "-c", str(SOURCE), "-o", str(object_path)
        ])
        if compile_result.returncode != 0:
            raise RuntimeError(f"clang object build failed: {bounded(compile_result.stderr)}")
        link_result = run(["clang", str(object_path), "-Wl,-no_pie", "-o", str(binary)])
        if link_result.returncode != 0:
            raise RuntimeError(f"clang link failed: {bounded(link_result.stderr)}")
        dsym_result = run(["xcrun", "dsymutil", str(binary), "-o", str(dsym)])
        if dsym_result.returncode != 0:
            raise RuntimeError(f"dsymutil failed: {bounded(dsym_result.stderr)}")
        uuid_value, architecture = parse_uuid_and_architecture(binary)
        preferred_text, image_size = parse_text_segment(binary, architecture)
        symbol_address = parse_symbol(binary, architecture)
        if symbol_address < preferred_text:
            raise RuntimeError("fixture symbol address is below __TEXT preferred address")
        image_offset = symbol_address - preferred_text
        runtime_base = preferred_text
        runtime_address = runtime_base + image_offset
        image_end = runtime_base + image_size
        if not runtime_base or runtime_address >= image_end:
            raise RuntimeError("fixture symbol address is outside the observed image range")

        crash.write_text(
            "\n".join([
                "Process: SymbolicationFixture [1234]",
                "Identifier: com.example.SymbolicationFixture",
                "Exception Type: EXC_BAD_ACCESS (SIGSEGV)",
                "Triggered by Thread: 0",
                "",
                "Thread 0 Crashed:",
                f"0   SymbolicationFixture 0x{runtime_address:x} symbolication_fixture_symbol + 0",
                "",
                "Binary Images:",
                f"0x{runtime_base:x} - 0x{image_end:x} SymbolicationFixture {architecture} <{uuid_value}> {binary}",
                "",
            ]),
            encoding="utf-8",
        )
        ips.write_text(json.dumps({
            "name": "SymbolicationFixture",
            "bundleID": "com.example.SymbolicationFixture",
            "pid": 1234,
            "faultingThread": 0,
            "usedImages": [{
                "imageIndex": 0,
                "name": "SymbolicationFixture",
                "uuid": uuid_value.replace("-", ""),
                "arch": architecture,
                "base": str(runtime_base),
                "size": str(image_size),
                "path": str(binary),
            }],
            "threads": [{
                "id": 0,
                "triggered": True,
                "frames": [{
                    "imageIndex": 0,
                    "imageOffset": str(image_offset),
                    "symbol": "symbolication_fixture_symbol",
                }],
            }],
        }, indent=2) + "\n", encoding="utf-8")

        environment = environment_without_grants()
        client = MCPClient(environment, "apple-debug-mcp-symbolication-smoke")
        client.initialize()
        calls: list[dict[str, object]] = []
        text_value = client.call(
            "apple_crash_symbolicate",
            {
                "crashPath": str(crash),
                "artifacts": [{
                    "binaryPath": str(binary),
                    "architecture": architecture,
                    "dSYMPath": str(dsym),
                }],
            },
            calls,
        )
        ips_value = client.call(
            "apple_crash_symbolicate",
            {
                "crashPath": str(ips),
                "artifacts": [{
                    "binaryPath": str(binary),
                    "architecture": architecture,
                    "dSYMPath": str(dsym),
                }],
            },
            calls,
        )
        if not isinstance(text_value, dict) or not isinstance(ips_value, dict):
            raise RuntimeError("symbolication smoke returned a non-object result")
        for label, value in (("text", text_value), ("ips", ips_value)):
            images = value.get("images")
            frames = value.get("frames")
            if not isinstance(images, list) or not images or images[0].get("matchStatus") != "matched":
                raise RuntimeError(f"{label} crash did not prove exact UUID/architecture identity: {value}")
            if not isinstance(frames, list) or not frames:
                raise RuntimeError(f"{label} crash returned no frame evidence: {value}")
            if frames[0].get("status") not in {"resolvedSourceLine", "resolvedSymbolOnly"}:
                raise RuntimeError(f"{label} crash did not resolve a symbol: {value}")
        evidence.update({
            "status": "passed",
            "identity": {"uuid": uuid_value, "architecture": architecture},
            "imageRange": {
                "preferredText": f"0x{preferred_text:x}",
                "runtimeBase": f"0x{runtime_base:x}",
                "size": image_size,
                "symbolAddress": f"0x{symbol_address:x}",
                "imageOffset": image_offset,
            },
            "text": text_value,
            "ips": ips_value,
            "toolCalls": calls,
            "sourceLineProved": any(
                isinstance(value.get("frames"), list)
                and value["frames"]
                and value["frames"][0].get("status") == "resolvedSourceLine"
                for value in (text_value, ips_value)
            ),
        })
        evidence_path.parent.mkdir(parents=True, exist_ok=True)
        evidence_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"symbolication-crash-smoke: exact UUID/architecture identity and bounded text/.ips resolution passed; evidence written to {evidence_path}")
        return 0
    except Exception as error:
        evidence["status"] = "failed"
        evidence["failure"] = bounded(error)
        evidence_path.parent.mkdir(parents=True, exist_ok=True)
        evidence_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"symbolication-crash-smoke: {error}", file=sys.stderr)
        return 1
    finally:
        if client is not None:
            client.close()


if __name__ == "__main__":
    raise SystemExit(main())
