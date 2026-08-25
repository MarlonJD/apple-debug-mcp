#!/usr/bin/env python3
"""Validate the Apple Debug MCP repository's operational harness contract.

This checker is intentionally repository-local and read-only. It validates the
authorities and evidence references that make agent work repeatable, but it
does not perform commit-bound certification, HMAC verification, or external
writes.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Iterable


ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / "docs/agent-harness/config.json"
COVERAGE_PATH = ROOT / "docs/agent-harness/coverage-matrix.md"
REGISTRY_PATH = ROOT / "docs/agent-harness/registry.md"
ENVIRONMENT_PATH = ROOT / "docs/agent-harness/environment-contract.md"
ENTROPY_PATH = ROOT / "docs/agent-harness/entropy-cleanup-checklist.md"
PLAN_INDEX_PATH = ROOT / "docs/exec-plans/index.md"

REQUIRED_AUTHORITY_KEYS = {
    "instructions",
    "architecture",
    "planning",
    "exec_plan_index",
    "registry",
    "environment",
    "verification",
    "coverage",
}

PLAN_HEADINGS = (
    "Purpose / Big Picture",
    "Progress",
    "Surprises & Discoveries",
    "Decision Log",
    "Outcomes & Retrospective",
    "Context and Orientation",
    "Plan of Work",
    "Concrete Steps",
    "Validation and Acceptance",
    "Idempotence and Recovery",
    "Artifacts and Notes",
    "Interfaces and Dependencies",
    "Revision History",
)

EVIDENCE_KEYS = {
    "schema_version",
    "repository_commit",
    "repository_identity",
    "deployment_target_id",
    "capabilities",
    "environment",
    "command",
    "exit_code",
    "observed_at",
    "result",
    "artifacts",
    "issuer",
    "key_id",
    "signature",
}

LOCAL_LINK_RE = re.compile(r"(?<!!)(?:\[[^\]]+\])\(([^)]+)\)")
MAKE_TARGET_RE = re.compile(r"(?m)^([A-Za-z0-9][A-Za-z0-9_-]*):")
MAKE_REFERENCE_RE = re.compile(r"\bmake ([A-Za-z0-9][A-Za-z0-9_-]*)\b")
PLAN_METADATA_RE = re.compile(
    r"<!--\s*harness-plan:v1\s+(.*?)\s*-->", re.DOTALL
)
PLAN_FIELD_RE = re.compile(r"(?m)^([a-z_]+):[ \t]*(.*?)\s*$")
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
STATUS_RE = re.compile(r"^(verified|n\s*/\s*a)\s*(?:—|–|-)\s*(.+)$", re.I)


class Contract:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.groups: list[tuple[str, bool]] = []

    def error(self, path: str, message: str, remedy: str) -> None:
        self.errors.append(f"{path}: {message}. Fix: {remedy}.")

    def run_group(self, name: str, function: Callable[[], None]) -> None:
        before = len(self.errors)
        try:
            function()
        except (OSError, ValueError, json.JSONDecodeError) as error:
            self.error(name, f"checker could not complete: {error}", "repair the named repository authority")
        self.groups.append((name, len(self.errors) == before))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def regular_file(contract: Contract, path: Path, label: str | None = None) -> bool:
    display = label or path.relative_to(ROOT).as_posix()
    if path.is_symlink() or not path.is_file():
        contract.error(display, "required authority is missing or not a regular file", "restore the repository-owned file")
        return False
    return True


def safe_relative_path(raw: object) -> bool:
    if not isinstance(raw, str) or not raw.strip():
        return False
    path = Path(raw)
    return not path.is_absolute() and ".." not in path.parts


def markdown_files() -> Iterable[Path]:
    roots = [ROOT / "AGENTS.md", ROOT / "ARCHITECTURE.md"]
    docs_root = ROOT / "docs"
    if docs_root.is_dir():
        roots.extend(
            path
            for path in docs_root.rglob("*.md")
            if path.is_file() and not path.is_symlink()
        )
    seen: set[Path] = set()
    for path in roots:
        resolved = path.resolve()
        if resolved not in seen and path.is_file() and not path.is_symlink():
            seen.add(resolved)
            yield path


def markdown_link_target(source: Path, raw: str) -> Path | None:
    value = raw.strip().split()[0].strip("<>")
    if not value or value.startswith(("#", "http://", "https://", "mailto:", "file:")):
        return None
    value = value.split("#", 1)[0]
    if not value:
        return source
    if value.startswith("/"):
        return ROOT / value.lstrip("/")
    return source.parent / value


def check_markdown_links(contract: Contract) -> None:
    for path in markdown_files():
        in_fence = False
        for line_number, line in enumerate(read_text(path).splitlines(), 1):
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for raw in LOCAL_LINK_RE.findall(line):
                target = markdown_link_target(path, raw)
                if target is None:
                    continue
                try:
                    target.relative_to(ROOT)
                except ValueError:
                    contract.error(
                        path.relative_to(ROOT).as_posix(),
                        f"line {line_number} links outside the repository: {raw}",
                        "use a repository-contained relative link",
                    )
                    continue
                if not target.exists():
                    contract.error(
                        path.relative_to(ROOT).as_posix(),
                        f"line {line_number} points to a missing path: {raw}",
                        "correct the link or restore its target",
                    )


def check_authorities(contract: Contract) -> None:
    required = (
        "AGENTS.md",
        "ARCHITECTURE.md",
        "docs/index.md",
        "docs/PLANS.md",
        "docs/SECURITY.md",
        "docs/RELIABILITY.md",
        "docs/agent-harness/index.md",
        "docs/agent-harness/registry.md",
        "docs/agent-harness/operating-loop.md",
        "docs/agent-harness/environment-contract.md",
        "docs/agent-harness/output-contract.md",
        "docs/agent-harness/verification-matrix.md",
        "docs/agent-harness/entropy-cleanup-checklist.md",
        "docs/agent-harness/coverage-matrix.md",
        "docs/exec-plans/index.md",
        "docs/exec-plans/plan-template.md",
        "docs/exec-plans/tech-debt-tracker.md",
        "scripts/check.sh",
        "scripts/harness_check.sh",
        "scripts/harness_contract.py",
    )
    for relative in required:
        regular_file(contract, ROOT / relative)

    if not CONFIG_PATH.is_file() or CONFIG_PATH.is_symlink():
        contract.error(
            "docs/agent-harness/config.json",
            "authority configuration is missing or unsafe",
            "restore a regular JSON authority map",
        )
        return
    payload = json.loads(read_text(CONFIG_PATH))
    if payload.get("schema_version") != 1 or not isinstance(payload.get("authorities"), dict):
        contract.error(
            "docs/agent-harness/config.json",
            "authority configuration does not use schema_version 1",
            "declare a schema_version 1 authorities object",
        )
        return
    authorities = payload["authorities"]
    missing_keys = sorted(REQUIRED_AUTHORITY_KEYS - set(authorities))
    if missing_keys:
        contract.error(
            "docs/agent-harness/config.json",
            f"missing required authority keys: {', '.join(missing_keys)}",
            "map every required harness authority",
        )
    for key, raw_path in authorities.items():
        if not safe_relative_path(raw_path):
            contract.error(
                "docs/agent-harness/config.json",
                f"authority {key!r} has an unsafe path",
                "use a normalized repository-relative path",
            )
            continue
        target = ROOT / raw_path
        if key == "architecture":
            exists = target.is_file() or target.is_dir()
        else:
            exists = target.is_file() and not target.is_symlink()
        if not exists:
            contract.error(
                "docs/agent-harness/config.json",
                f"authority {key!r} does not resolve to {raw_path}",
                "create or correct the configured authority",
            )

    agents = read_text(ROOT / "AGENTS.md")
    required_routes = (
        "docs/index.md",
        "ARCHITECTURE.md",
        "docs/PLANS.md",
        "docs/exec-plans/index.md",
        "docs/agent-harness/index.md",
        "make check",
        "make harness-check",
    )
    for route in required_routes:
        if route not in agents:
            contract.error(
                "AGENTS.md",
                f"canonical route is missing: {route}",
                "add the route to the concise root instruction map",
            )


def plan_metadata(path: Path) -> dict[str, str] | None:
    match = PLAN_METADATA_RE.search(read_text(path))
    if match is None:
        return None
    return {key: value.strip() for key, value in PLAN_FIELD_RE.findall(match.group(1))}


def check_plan_file(contract: Contract, path: Path, state: str) -> None:
    display = path.relative_to(ROOT).as_posix()
    text = read_text(path)
    metadata = plan_metadata(path)
    if metadata is None:
        contract.error(display, "managed plan metadata block is missing", "start the file with harness-plan:v1 metadata")
        return
    if metadata.get("id") != path.stem:
        contract.error(display, "plan id does not match its filename", "use the lowercase-hyphenated filename stem")
    if metadata.get("status") != state:
        contract.error(display, f"plan metadata status is not {state}", "synchronize metadata with its lifecycle directory")
    if not metadata.get("owner") or metadata.get("owner", "").casefold() in {"none", "unknown", "unassigned", "n/a"}:
        contract.error(display, "plan owner is not substantive", "name the maintainers or responsible team")
    for field in ("created", "updated"):
        if DATE_RE.fullmatch(metadata.get(field, "")) is None:
            contract.error(display, f"plan {field} date is missing or malformed", "use YYYY-MM-DD")
    completed = metadata.get("completed", "")
    if state == "active" and completed:
        contract.error(display, "active plan has a completed date", "leave completed empty until lifecycle completion")
    if state == "completed" and DATE_RE.fullmatch(completed) is None:
        contract.error(display, "completed plan lacks a completed date", "record the completion date")

    headings = re.findall(r"(?m)^##\s+(.+?)\s*$", text)
    if tuple(headings) != PLAN_HEADINGS:
        contract.error(display, "plan headings do not match the managed thirteen-section schema", "restore the exact required heading order")
    if re.search(r"(?im)^(?:\s*[-*+]\s+)?(?:TODO|TBD|YYYY-MM-DD|Plan title|None yet)\b", text):
        contract.error(display, "managed plan contains an unresolved placeholder", "replace the template marker with repository-specific facts")
    if state == "completed" and re.search(r"(?m)^\s*[-*+]\s+\[ \]", text):
        contract.error(display, "completed plan contains unchecked progress", "finish the item or keep the plan active")
    outcomes = re.search(r"(?ms)^## Outcomes / Retrospective\s*\n(.*?)(?=^## |\Z)", text)
    if outcomes is None:
        outcomes = re.search(r"(?ms)^## Outcomes & Retrospective\s*\n(.*?)(?=^## |\Z)", text)
    if outcomes is None or not re.search(r"[A-Za-z]{3}", outcomes.group(1)):
        contract.error(display, "outcomes section is empty", "record the achieved behavior and remaining gaps")


def index_region(text: str, start: str, end: str) -> str | None:
    matches = re.findall(rf"(?ms)^{re.escape(start)}\s*\n(.*?)^\s*{re.escape(end)}\s*$", text)
    return matches[0] if len(matches) == 1 else None


def check_plans(contract: Contract) -> None:
    if not regular_file(contract, PLAN_INDEX_PATH):
        return
    active_root = ROOT / "docs/exec-plans/active"
    completed_root = ROOT / "docs/exec-plans/completed"
    indexed: dict[str, int] = {}
    index_text = read_text(PLAN_INDEX_PATH)
    for marker in ("harness:plans:active", "harness:plans:completed"):
        if index_text.count(f"<!-- {marker}:start -->") != 1 or index_text.count(f"<!-- {marker}:end -->") != 1:
            contract.error("docs/exec-plans/index.md", f"{marker} lifecycle markers are not unique", "keep one start/end pair for each lifecycle")
    for section, directory in (("active", active_root), ("completed", completed_root)):
        if not directory.is_dir():
            contract.error(directory.relative_to(ROOT).as_posix(), "managed plan directory is missing", "restore the active/completed directory")
            continue
        for path in sorted(directory.glob("*.md")):
            if path.name == ".gitkeep":
                continue
            check_plan_file(contract, path, section)
            relative = f"{section}/{path.name}"
            indexed[relative] = len(re.findall(rf"\]\({re.escape(relative)}\)", index_text))
    for relative, count in indexed.items():
        if count != 1:
            contract.error("docs/exec-plans/index.md", f"managed plan {relative} appears {count} times", "index each plan exactly once in its lifecycle table")
    for section in ("active", "completed"):
        region = index_region(index_text, f"<!-- harness:plans:{section}:start -->", f"<!-- harness:plans:{section}:end -->")
        if region is None:
            contract.error("docs/exec-plans/index.md", f"{section} lifecycle region is malformed", "keep the managed region markers around the table rows")


def markdown_cell_text(cell: str) -> str:
    match = re.search(r"\[([^]]+)\]\(([^)]+)\)", cell)
    return (match.group(1) if match else cell).strip()


def parse_coverage_rows(text: str) -> list[tuple[int, list[str]]]:
    rows: list[tuple[int, list[str]]] = []
    for line_number, line in enumerate(text.splitlines(), 1):
        if not line.startswith("|") or not line.endswith("|"):
            continue
        cells = [cell.strip() for cell in line[1:-1].split("|")]
        if len(cells) != 4 or all(set(cell) <= {"-", ":", " "} for cell in cells):
            continue
        if cells[0].casefold() in {"source principle or capability", "openai case-study choice"}:
            continue
        rows.append((line_number, cells))
    return rows


def parse_observed_at(value: object) -> bool:
    if not isinstance(value, str) or not value.endswith("Z"):
        return False
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError:
        return False
    return parsed.tzinfo is not None and parsed.utcoffset() == timezone.utc.utcoffset(parsed)


def check_evidence(contract: Contract, row_identity: str, evidence_path: Path, display: str) -> None:
    if not regular_file(contract, evidence_path, display):
        return
    payload = json.loads(read_text(evidence_path))
    if set(payload) != EVIDENCE_KEYS:
        contract.error(display, "evidence JSON keys do not match the local v2 record shape", "retain the documented evidence fields")
        return
    if payload.get("schema_version") != 2:
        contract.error(display, "evidence schema_version is not 2", "write a version-2 local evidence record")
    if not isinstance(payload.get("repository_commit"), str) or not re.fullmatch(r"[0-9a-f]{40}", payload["repository_commit"]):
        contract.error(display, "repository_commit is not a full lowercase Git object ID", "record the source commit identifier")
    if not isinstance(payload.get("capabilities"), list) or row_identity not in payload["capabilities"]:
        contract.error(display, "evidence does not name the covered capability", "include the exact coverage-row identity")
    if payload.get("result") not in {"passed", "not-applicable"}:
        contract.error(display, "evidence result is not passed or not-applicable", "record the observed local result")
    if payload.get("result") == "passed" and payload.get("exit_code") != 0:
        contract.error(display, "passed evidence does not have exit_code 0", "record the command result accurately")
    if payload.get("result") == "not-applicable" and payload.get("exit_code") is not None:
        contract.error(display, "not-applicable evidence must have a null exit_code", "record applicability without a command exit code")
    if not parse_observed_at(payload.get("observed_at")):
        contract.error(display, "observed_at is not a UTC timestamp", "record an RFC3339 UTC observation time")
    if not isinstance(payload.get("artifacts"), list) or not payload["artifacts"]:
        contract.error(display, "evidence has no artifact or rationale", "name the local artifact or applicability rationale")


def check_coverage(contract: Contract) -> None:
    if not regular_file(contract, COVERAGE_PATH):
        return
    text = read_text(COVERAGE_PATH)
    rows = parse_coverage_rows(text)
    if len(rows) != 31:
        contract.error("docs/agent-harness/coverage-matrix.md", f"coverage inventory has {len(rows)} rows instead of 31", "retain the complete standard capability inventory")
    if "not a certification" not in text.casefold() or "without" not in text.casefold():
        contract.error("docs/agent-harness/coverage-matrix.md", "coverage scope does not explain the no-certification default", "state that local evidence references are not commit-bound certification")
    identities: set[str] = set()
    for line_number, cells in rows:
        identity = re.sub(r"\s+", " ", cells[0]).strip().casefold()
        if not identity or identity in identities:
            contract.error("docs/agent-harness/coverage-matrix.md", f"line {line_number} has a missing or duplicate capability identity", "keep one row per capability")
        identities.add(identity)
        status = STATUS_RE.match(markdown_cell_text(cells[3]))
        if status is None:
            contract.error("docs/agent-harness/coverage-matrix.md", f"line {line_number} has an unexplained or incomplete status", "use verified or N/A with a concrete reason")
            continue
        evidence_links = re.findall(r"\]\((evidence/[^)]+\.json)\)", cells[3])
        if len(evidence_links) != 1:
            contract.error("docs/agent-harness/coverage-matrix.md", f"line {line_number} has {len(evidence_links)} evidence links", "link exactly one repository-local evidence record")
            continue
        evidence_path = ROOT / "docs/agent-harness" / evidence_links[0]
        check_evidence(contract, cells[0], evidence_path, f"coverage line {line_number} -> {evidence_links[0]}")


def check_registry(contract: Contract) -> None:
    if not regular_file(contract, REGISTRY_PATH):
        return
    makefile = read_text(ROOT / "Makefile")
    registry = read_text(REGISTRY_PATH)
    targets = set(MAKE_TARGET_RE.findall(makefile))
    references = set(MAKE_REFERENCE_RE.findall(registry))
    missing = sorted(targets - references)
    unknown = sorted(references - targets)
    if missing:
        contract.error("docs/agent-harness/registry.md", f"Makefile targets are absent from the registry: {', '.join(missing)}", "add one command-catalog row for every target")
    if unknown:
        contract.error("docs/agent-harness/registry.md", f"registry references unknown Makefile targets: {', '.join(unknown)}", "remove stale references or add the target")
    if "python3 scripts/harness_contract.py" not in registry:
        contract.error("docs/agent-harness/registry.md", "the native harness contract checker is not directly invocable", "document its exact command and expected signal")
    gate = read_text(ROOT / "scripts/harness_check.sh")
    if "harness_contract.py" not in gate:
        contract.error("scripts/harness_check.sh", "the project gate does not invoke the native contract checker", "call python3 scripts/harness_contract.py")


def check_maintenance_status(contract: Contract) -> None:
    for path in (ENVIRONMENT_PATH, ENTROPY_PATH):
        if not regular_file(contract, path):
            continue
        text = read_text(path)
        for line_number, line in enumerate(text.splitlines(), 1):
            if re.match(r"^\s*[-*+]\s*\[[ ]\]", line):
                contract.error(path.relative_to(ROOT).as_posix(), f"line {line_number} leaves a maintenance item unchecked", "complete the sweep or record an explicit N/A reason")
            if line.startswith("|") and line.endswith("|"):
                cells = [cell.strip().casefold() for cell in line[1:-1].split("|")]
                if cells and cells[-1] in {"candidate", "blocked"}:
                    contract.error(path.relative_to(ROOT).as_posix(), f"line {line_number} retains status {cells[-1]}", "verify the surface or record a scoped N/A reason")


def main() -> int:
    if not ROOT.is_dir():
        print("harness-contract: repository root is unavailable", file=sys.stderr)
        return 1
    contract = Contract()
    contract.run_group("authorities", lambda: check_authorities(contract))
    contract.run_group("markdown routes", lambda: check_markdown_links(contract))
    contract.run_group("managed ExecPlans", lambda: check_plans(contract))
    contract.run_group("coverage and evidence", lambda: check_coverage(contract))
    contract.run_group("command registry", lambda: check_registry(contract))
    contract.run_group("maintenance status", lambda: check_maintenance_status(contract))

    if contract.errors:
        for error in contract.errors:
            print(f"harness-contract: ERROR {error}", file=sys.stderr)
        print(f"harness-contract: {len(contract.errors)} contract failure(s)", file=sys.stderr)
        return 1
    for name, passed in contract.groups:
        if passed:
            print(f"harness-contract: {name}: passed")
    print("harness-contract: all repository contracts passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
