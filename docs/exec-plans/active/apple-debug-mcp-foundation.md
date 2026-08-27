<!-- harness-plan:v1
id: apple-debug-mcp-foundation
status: active
created: 2026-08-24
updated: 2026-08-27
completed:
owner: Apple Debug MCP maintainers
-->

# Establish the Apple Debug MCP foundation

Maintain this plan according to the [configured planning policy](../../PLANS.md). The foundation release is published; the plan remains active only for explicitly recorded environment-dependent follow-up evidence.

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
- [x] (2026-08-25 15:45Z) Add an authorization-gated legacy `ios-deploy` debugserver transport, generated LLDB-Python `SBTarget.ConnectRemote`/`SBTarget.Launch` bridge, DAP attach wiring, owned-process cleanup, and physical iOS 15 debugger smoke evidence.
- [x] (2026-08-25 16:55Z) Add a deterministic background control probe, physical breakpoint-hit/control smoke, legacy stop-state polling for missing DAP stop events, and verified memory patch/rollback recovery.
- [x] (2026-08-25 20:35Z) Add paired modern CoreDevice physical-device lifecycle, PID discovery, remote LLDB-DAP attach, control, and cleanup evidence on iPhone 17.
- [x] (2026-08-26 00:15Z) Add CoreDevice process inventory, terminate/suspend/resume/signal controls, sysdiagnose validation, physical xctrace capture, and lifecycle smoke evidence.
- [x] (2026-08-26 00:20Z) Add the SwiftUI menu bar supervisor with bundled MCP child process control, login-at-startup toggles, server log action, Quit action, package integration, and run-button bootstrap.
- [x] (2026-08-26 01:46Z) Add the authenticated loopback MCP daemon mode, user-private endpoint discovery, menu-bar health/status supervision, graceful shutdown, fixed default port, transport smoke, and notarized release verification.
- [x] (2026-08-26 02:03Z) Push the final source/doc checkpoint, refresh the 33 HMAC evidence records, create the direct-child attestation, and receive `CERT000` for the standard harness profile.
- [x] (2026-08-26 02:34Z) Add bounded local checkpoint/source-location replay, deterministic-input manifests, a read-only remote KDP kernel-lab provider boundary, and explicit MCP capability/tool contracts; verify replay against the macOS fixture and keep native reverse/external replay and kernel writes fail-closed.
- [x] (2026-08-26 03:00Z) Harden Apple tool execution with wall-clock/output bounds and owned cleanup, add bounded DAP framing/event/stderr handling, enforce bounded file preflight, fix unique Xcode result bundles, and add core/MCP contract tests.
- [x] (2026-08-26 03:04Z) Give each stdio/daemon MCP server a distinct ToolCatalog context, close owned debugger/kernel-lab state with HTTP session cleanup, enforce an eight-session daemon limit, and verify DELETE cleanup through the daemon smoke.
- [x] (2026-08-26 09:45Z) Add all-registered-tool dispatch coverage, real daemon debugger-session isolation/owned-debuggee cleanup smoke, deterministic/host/Simulator/physical verification tiers, scheduled/manual CI routing, and the compatibility/SDK baseline matrix.
- [x] (2026-08-26 15:12Z) Split the MCP catalog into schema, support, router, and domain dispatch files; add representative domain success/error contract coverage; verify the refactor with `make check`, `make harness-check`, and `git diff --check`.
- [x] (2026-08-26 15:38Z) Repair CI SwiftPM manifest parsing by moving the tools-version marker to the first line; add the cross-domain MCP behavior matrix and verify foundation, artifact, debugger lifecycle, performance, Simulator, device, and Xcode dispatch contracts locally.
- [x] (2026-08-26 15:45Z) Move hosted CI from macOS-14 to the arm64 macOS-26 image after its Swift 5.10 toolchain could not resolve the current Swift 6.1/6.2 dependency graph; restore the current SDK/NIO pins and confirm the new CI run reaches package resolution.
- [x] (2026-08-26 16:14Z) Make the Mach-O regression test independent of whether the hosted Apple toolchain exposes a universal or thin `lldb-dap`, while retaining explicit thin-image parsing coverage.
- [x] (2026-08-26 16:34Z) Give the stdio MCP smoke enough bounded time for the hosted toolchain probe and require its actual response before validating the remaining transcript.
- [x] (2026-08-26 18:58Z) Align Simulator video recording with the current public `simctl` default codec (`hevc`) and run the selected `simctl` directly with bounded startup readiness, signal shutdown, and diagnostics after hosted macOS-26 produced an empty recording; wait up to 10 seconds for the first non-empty artifact, accept a valid finalized movie after the intentional SIGINT even when hosted `simctl` reports a non-zero status, and verify the video path remotely in CI run `32998363346` (`ios-mcp-tool-smoke` passed).
- [x] (2026-08-26 19:16Z) Promote the authorized macOS debugger fixture into a first-class local stdio MCP workflow with a bounded JSON evidence manifest plus explicit policy-rejection and failed-launch session-cleanup probes; verify it through `make mcp-mac-debug-workflow-smoke` and include it in `make check`.
- [x] (2026-08-26 19:52Z) Productize the native macOS Workbench with target selection, session state, automatic stop-snapshot refresh, and typed threads/stack/register/stop-evidence panels while preserving the existing analyzer surfaces; verify the SwiftPM Workbench product build.
- [x] (2026-08-26 20:38Z) Add a read-only Workbench Evidence panel that loads the bounded `mcp-mac-debug-workflow.json` manifest, renders workflow steps/probes/cleanup status, and limits raw JSON display to a bounded preview; verify the SwiftPM product build.
- [x] (2026-08-26 21:00Z) Add a local GUI-only Workbench UI smoke that stages the SwiftPM executable as a real `.app`, verifies the visible window plus `Open Target`, `Open Evidence`, and `Evidence` accessibility labels, writes bounded UI evidence, and leaves the menu bar run path unchanged.
- [x] (2026-08-26 22:52Z) Complete the menu bar surface with explicit Login Items settings guidance, OSLog action/state telemetry, synchronous owned-daemon cleanup during application termination, accessibility identifiers, and a GUI-only `menubar-ui-smoke` covering popover lifecycle, endpoint copy, Quit cleanup, and telemetry.
- [x] (2026-08-26 21:04Z) Run the authorized release gate with the available Developer ID identity: both app bundles passed strict codesign verification, Apple Notary Service returned `Accepted`, stapler validation passed, Gatekeeper accepted both bundles, and `dist/apple-debug-mcp-macos-arm64-notarized.zip` was produced; production publication remains release-authorized work.
- [x] (2026-08-26 23:02Z) Publish the final menu bar supervisor artifact as GitHub Release `v0.1.0` from commit `59bda01`; the release is non-draft/non-prerelease and carries `apple-debug-mcp-macos-arm64-v0.1.0-notarized.zip` after successful Developer ID/notarization/Gatekeeper validation.
- [x] (2026-08-27 00:42Z) Align the package and documentation with the real toolchain boundary: Swift tools 6.1 is required by the locked MCP SDK/NIO manifests, Xcode 26.6/Swift 6.3.3 is the verified build environment, and the release artifact retains a macOS 13 deployment target while macOS 13 runtime behavior remains candidate-only.
- [x] (2026-08-26 21:19Z) Split the hosted Simulator integration workflow into `simulator-check-core` and a dedicated `simulator-repro-bundle` job with a separate 20-minute budget; the combined local `make simulator-check` passes both targets, with hosted verification recorded below.
- [x] (2026-08-26 21:33Z) Repair legacy physical control timing by waiting for a bounded stop event after instruction stepping; the authorized iOS 15 iPod touch tier then passed breakpoint, evaluate, step, pause/continue, memory rollback, and cleanup.
- [ ] (blocked, 2026-08-27 00:42Z) Re-run the modern CoreDevice physical tier when the paired iPhone 17 is unlocked/connected and its CoreDevice tunnel is available; the current read-only inventory reports `tunnelState=unavailable`, `xcdevice` reports the phone unavailable, and `devicectl device info lockState` cannot locate the device, so no mutation was attempted.
- [x] (2026-08-26 22:17Z) Verify the hosted CI split in workflow run `33014844655`: the isolated Simulator repro-bundle job passed in 6 minutes, the core Simulator rerun passed in 41m35s, and host/macOS jobs passed; the initial core attempt’s LLDB-DAP attach timeout was a hosted flake and did not recur on rerun.
- [x] (2026-08-27 01:35Z) Upgrade every hosted checkout/upload step to the Node 24-based `actions/checkout@v7` and `actions/upload-artifact@v7`, then verify commit `d6b78a3` in workflow run `33028167208`: host integration passed in 2m22s, the isolated repro-bundle passed in 4m06s, deterministic macOS/package passed in 7m18s, and Simulator core passed in 43m47s without the former Node 20 action warning.
- [x] (2026-08-27 01:35Z) Re-run the repository definition of done after aligning the Swift tools and compatibility contracts: `make check`, `make harness-check`, `make workbench-ui-smoke`, `make menubar-ui-smoke`, and `make package` passed locally; a downloaded `v0.1.0` release asset matched its published SHA-256 digest and both app bundles passed strict codesign, stapler, and Gatekeeper readback.
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
- CoreDevice inventory can report a paired device with a disconnected tunnel until a read-only `devicectl device info lockState` probe acquires the tunnel; the adapter refreshes that state before authorization decisions and remains fail-closed when the probe fails.
- The connected iPhone 17 (CoreDevice UUID `02329A9F-84C9-5499-9EBF-074EFCB45F7C`, iOS 27 beta) is verified through CoreDevice install, deterministic terminate-existing launch, PID discovery, custom LLDB-DAP `device process attach --pid` attach, source breakpoint/control, memory rollback, and cleanup. The connected iPod touch 7 (iOS 15.8.8) remains covered by the separate legacy `ios-deploy` transport.
- CoreDevice LLDB-DAP can return from its attach command before the process is stopped and can emit the initial SIGSTOP after the attach response; the adapter pauses, waits for the initial stop, drains stale events, and bounds adapter shutdown so subsequent breakpoint waits observe only new stops.
- Checkpoint replay is verified only for the local macOS fixture: it captures a bounded JSON stop artifact and relaunches the stored program to the recorded source location. It intentionally does not restore exact registers, memory, scheduler, kernel, or external-I/O state.
- The kernel-lab provider is implemented as a read-only, explicit-grant LLDB `kdp-remote` boundary, but no two-machine KDK target was operated during this checkpoint; live KDP evidence remains environment-dependent.
- Legacy physical session creation requires `APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1`, `APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1`, a signed `.app` path, and `ios-deploy`; the session owns the debugserver and generated bridge and exposes typed DAP inspection after attach.
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
- The official Swift SDK provides the stateful Streamable HTTP transport but deliberately leaves the HTTP listener/framework adapter to the application; the daemon therefore adds a narrow NIO HTTP/1 adapter and keeps the SDK responsible for MCP framing, sessions, and SSE routing.
- A loopback-only endpoint still needs authentication: the daemon publishes a random bearer token, validates localhost host/origin and content type, caps request bodies at 2 MiB, and writes endpoint metadata with user-only permissions.
- Menu shutdown must request the authenticated `/shutdown` endpoint before its bounded kill fallback. Closing the listening channel can race the cleanup continuation, so endpoint metadata is removed before awaiting event-loop shutdown.

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
- Decision: Keep stdio as the default MCP transport and add an opt-in daemon mode supervised by the menu bar app.
  Rationale: Existing MCP clients and smoke scripts retain their process-boundary behavior, while the menu bar app gains one shared endpoint without silently changing client configuration or opening a remote listener.
  Date/Author: 2026-08-26 / Apple Debug MCP maintainers
- Decision: Bind the daemon to stable `127.0.0.1:49321` by default, allow explicit port `0` for isolated tests, and publish a random bearer token in `~/Library/Application Support/AppleDebugMCP/endpoint.json`.
  Rationale: A stable default makes client configuration durable; the test-only ephemeral override avoids collisions, while the private discovery file, token, and localhost validation prevent unauthenticated local or DNS-rebinding access.
  Date/Author: 2026-08-26 / Apple Debug MCP maintainers
- Decision: Keep hosted Simulator core and repro-bundle evidence in separate jobs.
  Rationale: The original combined job exceeded its 45-minute budget. Workflow run `33014844655` verified that the isolated repro-bundle job passes in 6 minutes and the core tier passes within its independent budget, preserving focused failure evidence without weakening either gate.
  Date/Author: 2026-08-26 / Apple Debug MCP maintainers

## Outcomes & Retrospective

The macOS, checkpoint replay, iOS Simulator, physical-device, Workbench, and menu bar product paths are locally verified with repository fixtures or explicitly authorized devices. The MCP server exposes analysis and debugger tools through typed schemas, bounds Apple-tool/DAP input and output, gives each MCP server instance isolated debugger ownership, cleans up owned LLDB-DAP, CoreDevice, legacy `ios-deploy`, kernel-lab, and menu-supervised child processes, and fails closed for unauthorized mutation. The authenticated daemon checkpoint is verified through health authorization, bearer rejection, MCP initialize/session routing, all-registered-tool dispatch coverage, per-client debugger isolation, bounded concurrent-session rejection, DELETE cleanup, graceful shutdown, and endpoint-file removal. Hosted workflow run `33028167208` passes deterministic macOS/package, host integration, Simulator core, and isolated repro-bundle jobs on the same source commit. The iPhone 17 CoreDevice fixture has prior lifecycle/debug-control evidence, while the current rerun remains blocked by device/tunnel availability; the physical iOS 15 fixture remains verified through its separate legacy debugserver path. The kernel-lab connection itself remains unverified without a configured two-machine KDK target. GitHub Release `v0.1.0` is published with an arm64 archive whose Developer ID signatures, notarization staples, Gatekeeper acceptance, and SHA-256 digest were read back after publication. Compatibility evidence is tiered separately: the artifact declares macOS 13, but runtime and toolchain behavior is verified only on macOS 26.5.2 with Xcode 26.6/Swift 6.3.3.

## Context and Orientation

The repository contains `AppleDebugCore` and `AppleDebugMCP`. The core owns capability policy, DAP framing/session lifecycle, debugger policy, Mach-O/crash/symbolication analyzers, Simulator/CoreDevice/Xcode/log adapters, and their tests. The executable owns MCP tool schemas and dispatch. Product scope is in `docs/product-specs/platform-scope.md`; security and reliability boundaries are in `docs/SECURITY.md` and `docs/RELIABILITY.md`.

## Plan of Work

1. Keep the current local debugger and Simulator workflows green with fixture-based regression checks.
2. Keep both modern CoreDevice and legacy physical evidence authorization-gated by signed app, Developer Mode, signing, explicit device grants, and explicit user direction.
3. Add metadata/UI/release/reverse-engineering increments as separate fixture-backed checkpoints rather than advertising unsupported capabilities.
4. Refresh harness evidence and create a direct-child attestation after each source/documentation checkpoint.

## Concrete Steps

Work from `/Users/marlonjd/Developer/monorepos/apple-debug-mcp`.

1. Run `swift package resolve` and `swift build`.
2. Run `swift test` and `make check`.
3. Run `make ios-fixture-smoke` and `make ios-debug-fixture-smoke` only for the explicit local Simulator workflow.
4. Run `make ios-coredevice-lifecycle-smoke` and `make ios-coredevice-debug-control-smoke` with `APPLE_DEBUG_COREDEVICE_ID` and the explicit physical-device grants when a paired modern device is available; run the legacy target separately for iOS 15 hardware.
5. Run `make mcp-daemon-smoke`, `./script/build_and_run.sh --verify`, and `make package` for the daemon, menu bar app, and bundle contract.
6. Run `make pr-check` for the deterministic gate, `make host-integration-check` for host session/replay/plugin integration, `make simulator-check` for the manual/scheduled Simulator tier, and `make physical-device-check` only with explicit authorized device inputs.
7. Run `make harness-check` and the bundled harness validator when the source commit is final.
8. Review `git diff --check`, `git status --short --branch`, and the staged diff before each authorized Conventional Commit.
9. Push verified source commits and the direct-child harness attestation commit to `main`.

## Validation and Acceptance

The current verified checkpoint requires:

- `make check` and `make harness-check` exit 0;
- MCP initialize, tools/list, capability, toolchain, LLDB-DAP probe, Mach-O, and crash calls return valid JSON-RPC responses;
- daemon health rejects missing credentials, accepts the private bearer token, routes Streamable HTTP/SSE MCP sessions, and removes endpoint metadata on graceful shutdown;
- all registered MCP tools reach a named dispatch branch under bounded empty-argument contract exercise, without requiring mutation or physical-device access;
- the CI-compatible SwiftPM manifest resolves successfully and the domain behavior matrix exercises real MCP success/error envelopes across all dispatch domains;
- separate daemon MCP clients cannot see or use one another’s debugger sessions, and deleting a client session cleans its launched fixture/debugger state;
- deterministic PR, host integration, Simulator, physical-device, and compatibility baseline tiers have explicit commands and authority boundaries;
- macOS fixture smoke covers launch, breakpoint, threads, stack, scopes, variables, evaluate, memory, disassembly, step, continue, and cleanup;
- iOS Simulator smoke covers build/install/launch/screenshot/terminate/shutdown and LLDB-DAP attach/threads/stack/memory/disassembly/cleanup;
- modern CoreDevice evidence covers paired/tunnel refresh, install, deterministic launch/PID discovery, LLDB-DAP attach, inspection/control, rollback, and cleanup;
- modern CoreDevice lifecycle evidence covers process inventory, resume/suspend, termination, and physical xctrace capture;
- menu bar evidence covers a real `.app` bundle, bundled daemon child startup/health, package contents, login-at-startup controls, log action, endpoint status, and Quit action;
- authorized legacy physical-device evidence covers `ios-deploy` debugserver ownership and MCP LLDB-DAP inspection;
- authorized legacy physical-device control evidence covers breakpoint hit, stepping, pause/continue, evaluation, and memory patch/rollback;
- no unresolved harness placeholders remain;
- source and attestation commit boundaries are direct-child and clean before certification.

Modern CoreDevice debugging is verified on the paired iPhone 17 fixture. A future unavailable or incompatible device must remain an explicit transport blocker and must not be conflated with legacy iOS 15 coverage.

## Idempotence and Recovery

Build and test commands are safe to rerun. `make clean` removes only SwiftPM build artifacts. If a Simulator smoke stops before its trap runs, target only the known fixture bundle and selected UDID; do not erase unrelated devices. If certification evidence is stale, leave the claim invalid, refresh records from the current source commit, and create a new direct-child attestation.

## Artifacts and Notes

- Source: `Package.swift`, `Sources/`, `Tests/`, `Makefile`, and `scripts/`.
- Product contract: `docs/product-specs/platform-scope.md`.
- Architecture/security: `ARCHITECTURE.md`, `docs/SECURITY.md`, and `docs/RELIABILITY.md`.
- Harness routes: `docs/agent-harness/`.
- Follow-up debt: `docs/exec-plans/tech-debt-tracker.md`.

## Interfaces and Dependencies

The MCP server uses `MCP.Server`, `MCP.StdioTransport`, `MCP.StatefulHTTPServerTransport`, `MCP.ListTools`, `MCP.CallTool`, `MCP.Tool`, and `MCP.Value` from the official Swift SDK. `ToolCatalog.tools` is the MCP surface and each `ToolCatalog.Context` owns one debugger/replay/kernel-lab manager set for one MCP server instance; `ToolCatalog.call(_:context:)` dispatches calls. `AppleDebugMCPDaemonServer` owns the loopback NIO listener, bearer validation, endpoint publication, per-client session routing, bounded concurrency, and graceful context cleanup while the SDK owns MCP framing and Streamable HTTP/SSE behavior. `AppleDebugDaemonEndpoint` is the shared endpoint contract. `CapabilityMatrix.reports()` is the stable policy interface. `LLDBDAPSession` owns the adapter process; `DAPFraming` owns bounded Content-Length framing; `DebugSessionManager` owns session policy and cleanup. `AppleDebugMenuBar` owns the SwiftUI `MenuBarExtra`, `SMAppService.mainApp` login registration, health-aware daemon supervision, and bounded shutdown.

## Revision History

- 2026-08-24: Created the repository plan, applied the harness profile, and recorded licensing, scope, and authorization decisions.
- 2026-08-25: Added and verified the legacy iOS 15 physical-device LLDB-DAP bridge through `ios-deploy`, including owned cleanup and MCP thread/stack/register/memory/disassembly evidence; retained the modern CoreDevice transport as a separate path.
- 2026-08-25: Added and verified deterministic physical breakpoint/control coverage, memory rollback, and legacy stop-state polling through `make ios-legacy-debug-control-smoke`.
- 2026-08-25: Added CoreDevice tunnel activation, PID-returning deterministic launch, custom remote LLDB-DAP attach synchronization, bounded adapter cleanup, and full iPhone 17 control evidence through `make ios-coredevice-debug-control-smoke`.
- 2026-08-26: Added CoreDevice process lifecycle/sysdiagnose/performance tools and smoke evidence, plus the signed-ready SwiftUI menu bar supervisor and package/run integration.
- 2026-08-26: Added authenticated loopback daemon mode with official SDK Stateful HTTP transport, NIO listener adapter, user-private endpoint discovery, menu-bar health/shutdown supervision, endpoint smoke coverage, and documentation routes.
- 2026-08-26: Added bounded external-process/DAP handling, preflighted file inputs, MCP contract tests, unique Xcode test bundles, per-server ToolCatalog contexts, daemon session limits, and HTTP DELETE ownership cleanup.
- 2026-08-26: Repaired SwiftPM tools-version parsing for hosted CI and added the cross-domain MCP behavior matrix with debugger lifecycle and policy-boundary evidence.
- 2026-08-24: Added symbolication, crash analysis, unified logs, Simulator screenshot capture, richer debugger control, and bounded mutation gates.
