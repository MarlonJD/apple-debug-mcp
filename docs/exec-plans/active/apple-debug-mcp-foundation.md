<!-- harness-plan:v1
id: apple-debug-mcp-foundation
status: active
created: 2026-08-24
updated: 2026-08-25
completed:
owner: Apple Debug MCP maintainers
-->

# Establish the Apple Debug MCP foundation

Maintain this plan according to the [configured planning policy](../../PLANS.md). The plan remains active while physical-device debugging is outside the verified local boundary.

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
- [x] (2026-08-25 13:35Z) Add legacy `xcdevice` inventory fallback, transport-aware authorization, optional `ios-deploy` install/launch, and fail-closed legacy LLDB-DAP behavior for CoreDevice-incompatible iOS 15 devices.
- [x] (2026-08-24 16:00Z) Add dedicated Objective-C/Swift metadata reports and bounded Simulator UI inspection/action evidence.
- [x] (2026-08-24 16:34Z) Add signed/notarized packaging workflow; CI validation remains unsigned and external notarization requires release authority.
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
- [x] (2026-08-24 16:30Z) Add macOS CI checks and unsigned package artifact upload for pushes and pull requests; keep signing/notarization release-gated.
- [x] (2026-08-24 16:40Z) Add typed `apple_debug_wait_for_stop` event synchronization after continue/step and verify it against the macOS fixture.
- [x] (2026-08-24 17:16Z) Add multi-artifact crash-frame triage through `apple_crash_symbolicate`; verify per-frame output against the text crash fixture.
- [x] (2026-08-24 17:20Z) Make generic `apple_xcode_build` return derived-data, app, and dSYM artifact metadata and fix xcodebuild pipe deadlocks; verify with `make xcode-artifact-smoke`.
- [x] (2026-08-24 17:31Z) Add policy-gated Simulator URL, location, clear-location, and bounded video controls; verify location/video through `make ios-mcp-tool-smoke`.
- [x] (2026-08-24 17:40Z) Add policy-gated generic `apple_xcode_test` execution with xcresult summary discovery; verify through `make xcode-test-smoke`.
- [x] (2026-08-24 17:45Z) Expand XCUITest action schemas with doubleTap, longPress, and bounded pinch support; verify extra gestures through `make ios-ui-tree-smoke`.
- [x] (2026-08-24 17:52Z) Add attach-gated macOS `apple_debug_memory_map` vmmap reporting with bounded output and policy coverage.
- [x] (2026-08-24 17:58Z) Add DAP stack/variable paging, hex formatting, and exception filter-option schemas; verify paged stack/variables through the macOS fixture.
- [x] (2026-08-24 18:04Z) Add bounded policy-gated `apple_performance_record` xctrace capture for macOS PID or Simulator targets.
- [x] (2026-08-24 18:08Z) Add `make performance-smoke` to capture and validate a short non-empty host Time Profiler trace bundle.
- [x] (2026-08-24 18:55Z) Add `apple_performance_analyze` and an allowlisted xctrace XML parser for summary metadata, rows, frame/binary data, hotspots, and folded flame stacks; verify with `make performance-analysis-smoke`.
- [x] (2026-08-24 18:10Z) Harden LLDB-DAP EOF/process-status handling after a real fixture crash and preserve typed process-exit errors.
- [x] (2026-08-24 17:36Z) Replace pipe-before-wait Apple tool invocations with a bounded file-backed process runner across logs, Simulator, CoreDevice, symbolication, capability, and binary adapters.
- [x] (2026-08-24 18:45Z) Add deep bounded DWARF inspection for Mach-O/dSYM inputs, including DIE hierarchy/attributes, declaration locations, source lists, line-table rows, statistics, and address lookup plumbing; verify it through `make dwarf-smoke` against the generic iOS fixture.
- [x] (2026-08-24 19:08Z) Add generated UI-test-only Xcode projects for arbitrary installed Simulator bundle IDs, with snapshot/action MCP tools and end-to-end install/probe/tap evidence through `make ios-arbitrary-ui-smoke`.
- [x] (2026-08-24 19:25Z) Add Apple-native heap/leaks/malloc-history/sample diagnostics, self-contained arm64/x86_64 assembler/disassembly, transactional assembly patching, bounded forward stop traces, and explicit reverse/kernel capability reports; verify with runtime, assembler, macOS fixture, and reverse-boundary smokes.
- [x] (2026-08-24 22:05Z) Add CFG/basic-block/call-graph analysis, direct dyld shared-cache table parsing, typed vmmap snapshots/diffs, expanded xctrace schema support, Simulator environment controls, reproducible evidence bundles, signing audits, patch/re-sign plans, native workbench build, and safe plugin manifest discovery.
- [x] (2026-08-24 22:20Z) Add semantic xctrace summaries, workbench debugger thread/snapshot controls, and signed plugin-host validation with sandbox-required non-executing plans.
- [x] (2026-08-24 22:35Z) Add indirect-symbol/data-in-code CFG evidence and bounded dyld cache discovery smoke; current host reports no mounted cache and no `dyld_shared_cache_util`.
- [x] (2026-08-24 23:05Z) Merge the public Swift Concurrency xctrace schemas, resolve reference nodes, reconstruct task/actor/continuation edges, and verify a live async fixture through `make swift-concurrency-graph-smoke`.
- [x] (2026-08-24 23:15Z) Promote address-based branch/call xrefs to the CFG report and verify direct call references in the fixture smoke.
- [x] (2026-08-24 23:45Z) Add Mach-O relocation records and bounded dyld cache/helper discovery evidence; smoke the object-file `_usleep` relocation and the current runtime-helper/no-cache state.
- [x] (2026-08-24 23:55Z) Add template-specific semantic reports and MCP dispatch for public xctrace domains; verify the live Time Profiler report plus allocation/concurrency domain unit cases.
- [x] (2026-08-25 00:05Z) Surface template semantic metrics and CFG xref/relocation counts in the native workbench; verify the SwiftUI product build.
- [x] (2026-08-25 00:45Z) Replace the non-executing plugin plan with a separately built signed-audit/sandbox-exec host boundary, explicit execution grant, JSON stdin/stdout protocol, timeout/output caps, and standalone/MCP smoke evidence.
- [x] (2026-08-25 00:55Z) Add source-backed public Swift AST inspection with typed node/declaration summaries and a fixture MCP smoke.
- [x] (2026-08-25 01:05Z) Add coordinateTap/coordinateLongPress/coordinateSwipe actions to project-backed and arbitrary installed-app XCUITest probes for custom-drawn UI surfaces.
- [x] (2026-08-24 23:25Z) Expand the native workbench debugger panel with pause/continue/instruction stepping and explicitly grant-gated expression evaluation; verify the SwiftUI product build.
- [x] (2026-08-24 04:06Z) Commit and push every verified implementation checkpoint to `main`.
- [x] (2026-08-25 02:05Z) Add dyld chained-fixup/import decoding plus bounded ObjC/Swift runtime strings and direct pointer cross-reference evidence for selected shared-cache images.
- [x] (2026-08-25 02:10Z) Add xctrace timeline points, trace-to-trace semantic/hotspot diffs, CFG annotated pseudo-code, and native workbench graph/timeline/diff panels.
- [x] (2026-08-25 02:15Z) Add bounded multi-file Swift AST inspection and Xcode project/scheme target context with SDK and target-triple resolution.
- [x] (2026-08-25 02:20Z) Replace production plugin execution transport with an independently signed App Sandbox XPC plugin protocol; retain sandbox-exec only as explicit legacy diagnostics and verify a signed XPC fixture.

## Surprises & Discoveries

- The Xcode toolchain provides `lldb-dap` but not an `lldb-mcp` executable; the project therefore owns the typed MCP-to-DAP adapter while keeping DAP transport small.
- LLDB-DAP target launch against a system binary is denied when Developer Mode is disabled. An ad-hoc signed `get-task-allow` fixture works without changing the global setting.
- LLDB-DAP accepts `pid` for process attach; using another key causes a misleading adapter failure.
- The iOS Simulator fixture can be built, installed, launched, screenshot, attached with LLDB-DAP, inspected, and cleaned up on the local Xcode installation.
- The current CoreDevice inventory reports `pairingState=unsupported` and `tunnelState=unavailable`; legacy `xcdevice`/`xctrace` inventory and profiling are available, while MCP legacy install/launch requires optional `ios-deploy` and legacy LLDB attach remains fail-closed.
- The connected iPod touch 7 (iOS 15.8.8) is online in legacy `xcdevice`/`xctrace`, while CoreDevice reports unsupported pairing, unavailable tunnel, unavailable DDI services, and no usage assertion; the signed iOS 15 fixture builds successfully, but the current MCP LLDB-DAP adapter has no legacy bridge.
- Unified-log output is large even for a one-second host window, so the public adapter caps responses and the deterministic MCP smoke covers the tool schema rather than making log volume a required gate.
- `dwarfdump --name` with `--show-children` returns a nested DIE stream rather than a flat symbol list; the DWARF adapter preserves offsets, depth, parent links, attributes, source paths, and bounded line rows so type/source evidence is not reduced to `atos` names.
- `xctrace export --xpath` returns a bounded XML query result with deduplicated reference nodes; the parser preserves the first materialized frame/sample records and rejects arbitrary XPath/schema input so trace analysis stays deterministic and bounded.
- A UI-test target can inspect an already installed Simulator app with `XCUIApplication(bundleIdentifier:)`; a generated UI-testing-only project is sufficient, but Apple still requires XCTest/Xcode and an accessibility-exposed target, so this does not bypass app UI privacy or entitlements.
- The installed Apple LLDB (`lldb-2100.0.17.203`) exposes `process trace start/stop` but `apropos reverse`, `apropos replay`, and `process record` are unavailable; a forward DAP stop trace is therefore the strongest truthful execution-history feature on this host.
- Apple `heap`, `leaks`, `malloc_history`, `sample`, and `vmmap` provide strong user-process runtime counterparts, while SIP/KDK/entitlement requirements keep kernel task and kext debugging outside the supported boundary.
- The current Xcode template catalog includes Power Profiler, Animation Hitches, Swift Concurrency, Processor Trace, CPU Profiler, Network, File Activity, and Game Performance; the xctrace parser now accepts bounded allowlisted schema names and preserves generic row fields when a template emits a different table shape.
- The Swift compiler can emit a multi-file `-dump-ast` to stderr for some temporary source sets; the public AST service uses stdout first and stderr only when stdout is empty, while preserving the compiler output as bounded evidence.
- An Xcode scheme's `CURRENT_ARCH` can be `undefined_arch` during `-showBuildSettings`; target-triple resolution therefore falls back to the first concrete `ARCHS` entry before invoking `swiftc`.
- A sandboxed XPC service cannot be treated as a generic child-process launcher on this host; the production plugin contract is therefore service-to-service XPC with each third-party plugin independently signed and App Sandbox enabled.
- The Swift Concurrency template exposes several public `swift-task-*` and `swift-actor-*` tables rather than one `swift-concurrency` table. The virtual analysis distributes its bounded row budget across available tables, resolves deduplicated references, and reports only public export evidence; task creation, actor execution, and continuation-state rows are not private runtime memory inspection.
- `dyld_shared_cache_util` is not installed on this host, so shared-cache inspection uses the public header/mapping/image table layout and keeps live-tool absence visible rather than inventing a utility result.

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
- Decision: Treat third-party plugin code as an independently signed App Sandbox XPC service, not as an executable child of a sandboxed broker.
  Rationale: The host environment rejects generic child-process launch from the sandboxed XPC service; service-to-service XPC is the Apple-supported isolation boundary and keeps plugin code out of the MCP process.
  Date/Author: 2026-08-25 / Apple Debug MCP maintainers

## Outcomes & Retrospective

The macOS and iOS Simulator product paths are locally verified with repository fixtures. The MCP server exposes analysis and debugger tools through typed schemas, cleans up owned LLDB-DAP adapters, and fails closed for unauthorized mutation. The physical iOS 15 fixture now builds/signs and legacy inventory is verified; lifecycle mutation requires optional `ios-deploy`, and remote LLDB remains blocked for the legacy transport until a supported bridge exists.

## Context and Orientation

The repository contains `AppleDebugCore` and `AppleDebugMCP`. The core owns capability policy, DAP framing/session lifecycle, debugger policy, Mach-O/crash/symbolication analyzers, Simulator/CoreDevice/Xcode/log adapters, and their tests. The executable owns MCP tool schemas and dispatch. Product scope is in `docs/product-specs/platform-scope.md`; security and reliability boundaries are in `docs/SECURITY.md` and `docs/RELIABILITY.md`.

## Plan of Work

1. Keep the current local debugger and Simulator workflows green with fixture-based regression checks.
2. Add physical-device evidence only after an authorized paired device, Developer Mode, signing, and explicit user direction are present.
3. Add metadata/UI/release/reverse-engineering increments as separate fixture-backed checkpoints rather than advertising unsupported capabilities.
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
