<!-- harness-plan:v1
id: apple-debug-mcp-foundation
status: active
created: 2026-08-24
updated: 2026-08-24
completed:
owner: Apple Debug MCP maintainers
-->

# Establish the Apple Debug MCP foundation

Maintain this plan according to the [configured planning policy](../../PLANS.md). The plan remains active while physical-device debugging, UI inspection, metadata analysis, and release engineering are outside the verified local boundary.

## Purpose / Big Picture

Deliver a local, GPL-3.0-or-later MCP workbench for authorized macOS and iOS debugging. The server must provide typed LLDB-DAP sessions, Apple artifact analysis, Simulator workflows, and explicit security boundaries without arbitrary shell execution or unauthorized device access.

## Progress

- [x] (2026-08-24 00:30Z) Inspect the empty GitHub repository, local instructions, and product boundary.
- [x] (2026-08-24 00:45Z) Apply the standard harness profile and create repository-local routing, evidence, and certification documents.
- [x] (2026-08-24 01:00Z) Add GPL-3.0-or-later licensing under Burak Karahan.
- [x] (2026-08-24 01:15Z) Add SwiftPM package, official MCP SDK, capability model, and stdio MCP server.
- [x] (2026-08-24 02:30Z) Add DAP framing, LLDB-DAP initialization, session ownership, cleanup, launch, attach, breakpoints, stack, memory, disassembly, and continue operations.
- [x] (2026-08-24 03:00Z) Add macOS fixture launch/inspection smoke with get-task-allow ad-hoc signing.
- [x] (2026-08-24 03:30Z) Add stepping, pause, scopes, variables, evaluate policy, data-breakpoint/watchpoint plumbing, bounded memory write policy, and fixture coverage.
- [x] (2026-08-24 03:45Z) Add Mach-O universal/thin parsing, segments, symbols, strings, `atos` symbolication, and crash-report analysis.
- [x] (2026-08-24 03:55Z) Add iOS Simulator inventory/lifecycle, Xcode fixture build, screenshot smoke, and LLDB-DAP attach smoke.
- [x] (2026-08-24 04:00Z) Add host/Simulator bounded unified-log adapter.
- [x] (2026-08-24 04:05Z) Add CoreDevice inventory, fail-closed development-app install/launch operations, and an authorization-gated LLDB `device select` session path.
- [ ] Add a paired physical-device fixture for remote LLDB attach and lifecycle evidence.
- [ ] Add dedicated Objective-C/Swift metadata reports and richer UI inspection.
- [ ] Add signed/notarized packaging and CI release artifacts.
- [x] (2026-08-24 04:25Z) Add unsigned macOS packaging with a reproducible release-build archive.
- [x] (2026-08-24 12:10Z) Add and verify the public MCP Simulator lifecycle smoke for launch flags, app metadata, containers, screenshots, and cleanup.
- [x] (2026-08-24 12:20Z) Stabilize the iOS fixture accessibility identifiers and verify a 9-element semantic UI snapshot through XcodeBuildMCP.
- [x] (2026-08-24 13:05Z) Add the standalone `apple_simulator_ui_snapshot` XCUITest/xcresult attachment bridge and verify the fixture tree through MCP.
- [x] (2026-08-24 14:35Z) Add bounded tap, typeText, swipe, and wait actions through the same XCUITest bridge and verify them end to end.
- [x] (2026-08-24 15:45Z) Add LLDB parity tools for function/exception breakpoints, modules, registers, terminate/disconnect, and conditional/log breakpoints; verify them with the macOS fixture.
- [x] (2026-08-24 15:50Z) Add the correlated `apple_debug_stop_snapshot` observation and verify it against the stopped macOS fixture.
- [x] (2026-08-24 15:55Z) Add `apple_binary_inspect` for code signatures, entitlements, linked libraries, nm symbols, and dyld exports; verify against `/bin/echo`.
- [x] (2026-08-24 16:00Z) Add `apple_runtime_metadata` for Objective-C classes/protocols/selectors and demangled Swift symbols; verify against `/usr/bin/shortcuts`.
- [x] (2026-08-24 16:05Z) Add bounded memory search and expected-bytes transactional patch/rollback with explicit write authorization; verify search against the macOS fixture and keep patch policy-gated.
- [x] (2026-08-24 16:15Z) Add read-only binary differential analysis for Mach-O files, `.app` bundles, and `.dSYM` bundles with signatures, dependencies, symbols, exports, hashes, metadata, and UUIDs.
- [x] (2026-08-24 16:20Z) Complete the supported LLDB-DAP parity surface with source breakpoint locations, instruction breakpoints, completions, variable-write policy, and instruction-granularity stepping; verify it against the macOS fixture.
- [x] (2026-08-24 16:26Z) Make `apple_symbolicate` resolve `.app` executables and `.dSYM` DWARF payloads; verify symbolication against a temporary dSYM bundle.
- [x] (2026-08-24 04:06Z) Commit and push every verified implementation checkpoint to `main`.

## Surprises & Discoveries

- The Xcode toolchain provides `lldb-dap` but not an `lldb-mcp` executable; the project therefore owns the typed MCP-to-DAP adapter while keeping DAP transport small.
- LLDB-DAP target launch against a system binary is denied when Developer Mode is disabled. An ad-hoc signed `get-task-allow` fixture works without changing the global setting.
- LLDB-DAP accepts `pid` for process attach; using another key causes a misleading adapter failure.
- The iOS Simulator fixture can be built, installed, launched, screenshot, attached with LLDB-DAP, inspected, and cleaned up on the local Xcode installation.
- The current CoreDevice inventory reports `pairingState=unsupported` and `tunnelState=unavailable`; no physical-device mutation or debug attach was attempted.
- Unified-log output is large even for a one-second host window, so the public adapter caps responses and the deterministic MCP smoke covers the tool schema rather than making log volume a required gate.

## Decision Log

- Decision: Use SwiftPM and the official Swift MCP SDK.
  Rationale: The product runs locally on macOS and must coordinate Apple developer tooling while leaving MCP framing upstream-owned.
  Date/Author: 2026-08-24 / Apple Debug MCP maintainers
- Decision: Keep dangerous operations opt-in through environment gates and bounded arguments.
  Rationale: Launch, attach, evaluation, memory write, Simulator mutation, device mutation, and Xcode builds can affect user state or target security.
  Date/Author: 2026-08-24 / Apple Debug MCP maintainers
- Decision: Use GPL-3.0-or-later with Burak Karahan as copyright holder.
  Rationale: Explicit product-owner licensing request.
  Date/Author: 2026-08-24 / Apple Debug MCP maintainers
- Decision: Keep the project separate from AviaWorkspace.
  Rationale: AviaWorkspace owns platform composition; this repository owns the Apple debugger lifecycle and its release boundary.
  Date/Author: 2026-08-24 / Apple Debug MCP maintainers

## Outcomes & Retrospective

The macOS and iOS Simulator product paths are locally verified with repository fixtures. The MCP server exposes analysis and debugger tools through typed schemas, cleans up owned LLDB-DAP adapters, and fails closed for unauthorized mutation. Physical-device support is intentionally partial: inventory and development-app lifecycle code exist, but the current machine has no paired/tunnel-ready device, so remote LLDB evidence remains a documented environmental blocker.

## Context and Orientation

The repository contains `AppleDebugCore` and `AppleDebugMCP`. The core owns capability policy, DAP framing/session lifecycle, debugger policy, Mach-O/crash/symbolication analyzers, Simulator/CoreDevice/Xcode/log adapters, and their tests. The executable owns MCP tool schemas and dispatch. Product scope is in `docs/product-specs/platform-scope.md`; security and reliability boundaries are in `docs/SECURITY.md` and `docs/RELIABILITY.md`.

## Plan of Work

1. Keep the current local debugger and Simulator workflows green with fixture-based regression checks.
2. Add physical-device evidence only after an authorized paired device, Developer Mode, signing, and explicit user direction are present.
3. Add metadata/UI/release increments as separate fixture-backed checkpoints rather than advertising unsupported capabilities.
4. Refresh harness evidence and create a direct-child attestation after each source/documentation checkpoint.

## Concrete Steps

Work from `/Users/marlonjd/Developer/monorepos/apple-debug-mcp`.

1. Run `swift package resolve` and `swift build`.
2. Run `swift test` and `make check`.
3. Run `make ios-fixture-smoke` and `make ios-debug-fixture-smoke` only for the explicit local Simulator workflow.
4. Run `make harness-check` and the bundled harness validator when the source commit is final.
5. Review `git diff --check`, `git status --short --branch`, and the staged diff before each authorized Conventional Commit.
6. Push verified source commits and the direct-child harness attestation commit to `main`.

## Validation and Acceptance

The current verified checkpoint requires:

- `make check` and `make harness-check` exit 0;
- MCP initialize, tools/list, capability, toolchain, LLDB-DAP probe, Mach-O, and crash calls return valid JSON-RPC responses;
- macOS fixture smoke covers launch, breakpoint, threads, stack, scopes, variables, evaluate, memory, disassembly, step, continue, and cleanup;
- iOS Simulator smoke covers build/install/launch/screenshot/terminate/shutdown and LLDB-DAP attach/threads/stack/memory/disassembly/cleanup;
- physical-device capability restrictions and current CoreDevice state are explicit;
- no unresolved harness placeholders remain;
- source and attestation commit boundaries are direct-child and clean before certification.

Physical-device remote debugging must remain `blocked-by-environment` until the required external authorization state exists; local assertions must not be substituted for that evidence.

## Idempotence and Recovery

Build and test commands are safe to rerun. `make clean` removes only SwiftPM build artifacts. If a Simulator smoke stops before its trap runs, target only the known fixture bundle and selected UDID; do not erase unrelated devices. If certification evidence is stale, leave the claim invalid, refresh records from the current source commit, and create a new direct-child attestation.

## Artifacts and Notes

- Source: `Package.swift`, `Sources/`, `Tests/`, `Makefile`, and `scripts/`.
- Product contract: `docs/product-specs/platform-scope.md`.
- Architecture/security: `ARCHITECTURE.md`, `docs/SECURITY.md`, and `docs/RELIABILITY.md`.
- Harness routes: `docs/agent-harness/`.
- Follow-up debt: `docs/exec-plans/tech-debt-tracker.md`.

## Interfaces and Dependencies

The MCP server uses `MCP.Server`, `MCP.StdioTransport`, `MCP.ListTools`, `MCP.CallTool`, `MCP.Tool`, and `MCP.Value` from the official Swift SDK. `ToolCatalog.tools` is the MCP surface and `ToolCatalog.call(_:)` dispatches calls. `CapabilityMatrix.reports()` is the stable policy interface. `LLDBDAPSession` owns the adapter process; `DAPFraming` owns Content-Length framing; `DebugSessionManager` owns session policy and cleanup.

## Revision History

- 2026-08-24: Created the repository plan, applied the harness profile, and recorded licensing, scope, and authorization decisions.
- 2026-08-24: Added and verified MCP/DAP, Mach-O, session lifecycle, Simulator, CoreDevice, Xcode, macOS fixture, iOS fixture, and iOS Simulator debugger checkpoints.
- 2026-08-24: Added symbolication, crash analysis, unified logs, Simulator screenshot capture, richer debugger control, and bounded mutation gates; retained the physical-device blocker explicitly.
