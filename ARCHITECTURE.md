# Apple Debug MCP Architecture

## System context

Apple Debug MCP is a local macOS command-line server that exposes capability-aware Apple debugging and analysis operations through MCP. An MCP client launches it over stdio. The server delegates debugger transport to LLDB-DAP and delegates Apple platform operations to fixed Xcode command-line tools.

The current implementation supports verified macOS and iOS Simulator fixture workflows. Physical-device inventory and development-app lifecycle are present behind CoreDevice authorization checks; physical-device LLDB attach remains restricted until an authorized device fixture is available.

## Repository map

| Path | Responsibility | Owner or update trigger |
| --- | --- | --- |
| Package.swift | SwiftPM products and official MCP SDK dependency | Update when products or upstream SDK version changes |
| Sources/AppleDebugCore/ | Capability policy, toolchain probes, Apple adapters, and testable domain logic | Maintainers; update when a platform capability changes |
| Sources/AppleDebugCore/DAP.swift | DAP value model, Content-Length framing, and LLDB-DAP process lifecycle | Maintainers; update with DAP/backend behavior |
| Sources/AppleDebugCore/DebugSessions.swift | Session ownership, debugger operations, bounds, and mutation policy | Maintainers; update when session permissions or cleanup changes |
| Sources/AppleDebugCore/MachO.swift | Read-only Mach-O/universal-binary headers, segments, symbols, and strings | Maintainers; update with static-analysis behavior |
| Sources/AppleDebugCore/AppleSymbolication.swift | `atos` address resolution | Maintainers; update with symbolication inputs or output contract |
| Sources/AppleDebugCore/AppleBinaryIntelligence.swift | Code signatures, entitlements, linked libraries, nm symbols, and dyld exports | Maintainers; update with Apple toolchain output changes |
| Sources/AppleDebugCore/AppleRuntimeMetadata.swift | Objective-C metadata parsing and Swift symbol demangling | Maintainers; update with Objective-C/Swift ABI/toolchain changes |
| Sources/AppleDebugCore/AppleDWARF.swift | Bounded `dwarfdump` DIE hierarchy, attributes, source paths, line tables, statistics, and address lookup reports | Maintainers; update with DWARF/Xcode output changes |
| Sources/AppleDebugCore/AppleAssembler.swift | Self-contained arm64/x86_64 assembly, Mach-O text extraction, disassembly, and patch payload generation | Maintainers; update with clang/LLVM output changes |
| Sources/AppleDebugCore/AppleControlFlow.swift | Bounded instruction parsing, basic blocks, direct branch edges, call graph, and external-call reports | Maintainers; update with LLVM disassembly output changes |
| Sources/AppleDebugCore/AppleDyldSharedCache.swift | Direct dyld shared-cache header, mapping, UUID, code-signature, local-symbol, and image-table parser | Maintainers; update with public dyld cache layout changes |
| Sources/AppleDebugCore/AppleMemoryMaps.swift | Typed vmmap regions, persisted snapshots, and region diffs | Maintainers; update with vmmap report format changes |
| Sources/AppleDebugCore/AppleSimulatorEnvironment.swift | Fixed simctl environment controls and bounded input validation | Maintainers; update with simctl public subcommands |
| Sources/AppleDebugCore/AppleReproBundle.swift | Screenshot/appinfo/log/trace/crash evidence bundle capture | Maintainers; update with Simulator evidence surfaces |
| Sources/AppleDebugCore/AppleSigningAudit.swift | codesign, entitlements, provisioning, and Gatekeeper audit reports | Maintainers; update with signing tool output |
| Sources/AppleDebugCore/ApplePatchWorkflow.swift | Non-destructive file patch previews and release-authority re-sign plans | Maintainers; update with packaging/signing policy |
| Sources/AppleDebugCore/AppleDebugPlugins.swift | In-process plugin protocol, bounded manifest discovery, and registry | Maintainers; update only with a reviewed extension boundary |
| Sources/AppleDebugWorkbench/ | Native SwiftUI macOS analyzer workbench | Maintainers; update with GUI panels and core API changes |
| Sources/AppleDebugCore/AppleRuntimeDiagnostics.swift | Attach-gated heap, leaks, malloc-history, and sample adapters | Maintainers; update with Apple runtime diagnostic tools |
| Sources/AppleDebugCore/AppleReverseExecution.swift | Installed-LLDB reverse/time-travel capability report and fail-closed boundary | Maintainers; update with LLDB backend capabilities |
| Sources/AppleDebugCore/AppleKernelCapabilities.swift | Kernel-debugging boundary report and supported user-process alternatives | Maintainers; update with SIP/KDK/entitlement boundary changes |
| Sources/AppleDebugCore/CrashReports.swift | Bounded `.crash` text and `.ips` JSON analysis | Maintainers; update with Apple crash schema changes |
| Sources/AppleDebugCore/AppleSimulator.swift | Simulator inventory and policy-gated lifecycle/screenshot operations | Maintainers; update with simctl behavior |
| Sources/AppleDebugCore/AppleSimulatorUI.swift | Project-backed and generated XCUITest accessibility probes, bounded UI actions, and xcresult attachment decoding | Maintainers; update with XCTest/Xcode behavior |
| Sources/AppleDebugCore/AppleLogs.swift | Bounded host and Simulator unified-log queries | Maintainers; update with `log`/`simctl` behavior |
| Sources/AppleDebugCore/AppleDevice.swift | CoreDevice inventory and authorization-gated development-app operations | Maintainers; update with pairing/tunnel policy changes |
| Sources/AppleDebugCore/AppleXcode.swift | Xcode project discovery and policy-gated builds | Maintainers; update with project/build policy changes |
| Sources/AppleDebugMCP/ | MCP server startup and typed tool dispatch | Maintainers; update when the MCP surface changes |
| Tests/Fixtures/ | Signed macOS debugger target, iOS Simulator app, and crash-report fixture | Maintainers; update when fixture contracts change |
| scripts/ | Build, smoke, lifecycle, Simulator MCP, packaging, and repository-native harness commands | Maintainers; update when verification or cleanup changes |
| docs/ | Canonical product, architecture, security, reliability, and agent workflow knowledge | Maintainers; update with boundary or workflow changes |

## Components and boundaries

The executable depends on `AppleDebugCore` and the official Swift MCP SDK. `AppleDebugCore` does not depend on MCP, so policy, parsing, and platform adapters remain testable without a transport.

- `LLDBDAPSession`: owns one LLDB-DAP subprocess, DAP framing, request/response matching, event draining, and teardown.
- `DebugSessionManager`: owns session IDs and routes launch, attach, source/instruction breakpoint locations, source/function/exception breakpoints, inspection, registers, modules, completions, variable mutation, stepping, watchpoints, evaluation, memory reads/search/patch, macOS vmmap reporting, and target lifecycle through policy checks. Physical sessions initialize LLDB with a validated `device select <UUID>` command and remain separately gated.
- `MachOInspector`: parses bounded regular files without executing them; universal binaries expose architecture records and thin binaries expose header/load-command/segment data, symbols, and strings.
- `AppleBinaryIntelligenceService`, `AppleRuntimeMetadataService`, `DWARFService`, `AppleBinaryDiffService`, and `CrashSymbolicationService`: inspect signed Apple binaries, recover Objective-C/Swift metadata, decode bounded DWARF DIE/type/source data and line tables, compare regular Mach-O files or `.app`/`.dSYM` bundles, and triage crash frames without executing artifacts.
- `CrashReportAnalyzer`: parses only bounded Apple crash artifacts and returns structured metadata without executing or symbolically loading their contents.
- `AppleSimulatorService`, `AppleSimulatorUIService`, `AppleDeviceService`, `AppleXcodeService`, `AppleLogService`: invoke fixed Apple tools with explicit argument arrays and typed results; Xcode builds return discovered derived-data, product, and dSYM paths, while Xcode tests return an xcresult summary.
- `AppleProcessRunner`: owns file-backed, bounded stdout/stderr capture for Apple tool invocations so large diagnostics cannot deadlock a synchronous adapter.
- `ApplePerformanceService`: records bounded raw `.trace` artifacts through fixed `xctrace` templates and parses allowlisted Time Profiler export tables into typed rows, hotspots, and folded flame-stack data; the trace bundle remains the source artifact.
- `AppleAssemblerService`: compiles bounded self-contained assembly to a temporary Mach-O object, extracts `__TEXT,__text`, and returns LLVM disassembly; `apple_debug_patch_assembly` feeds only those bytes into the existing expected-bytes transactional memory patch path.
- `RuntimeDiagnosticsService`: runs fixed `heap`, `leaks`, `malloc_history`, and `sample` argument shapes against an attach-authorized process with bounded output; it never accepts shell fragments or arbitrary tool arguments.
- `ReverseExecutionService` and `AppleKernelCapabilityService`: expose the installed backend’s actual reverse/time-travel and kernel-debugging boundary instead of claiming Windows/x64dbg semantics on Apple.
- `AppleControlFlowService`, `AppleDyldSharedCacheService`, `AppleMemoryMapService`, `AppleSimulatorEnvironmentService`, `AppleReproBundleService`, `AppleSigningAuditService`, and `ApplePatchWorkflowService` provide the next Apple-native reverse-engineering and reproducibility layer.
- `AppleDebugPlugin` is an in-process extension contract; `AppleDebugPluginManifestService` only discovers explicit JSON manifests. Dynamic dylib loading and arbitrary plugin process execution are deliberately outside the MCP trust boundary.
- `AppleDebugWorkbench` is a SwiftUI macOS executable that consumes read-only core analyzers directly; the MCP server remains the automation surface.
- `ToolCatalog`: exposes only named MCP tools; unknown tools fail closed.

No backend may expose arbitrary shell execution or silently broaden a target’s authorization boundary.

## Data and control flow

1. The MCP client starts `apple-debug-mcp` as a stdio child process.
2. The server completes MCP initialization and advertises the current tool schemas.
3. `apple_capabilities` returns platform-specific support and restrictions.
4. `apple_toolchain_status` probes a fixed allowlist through `xcrun`/`xcode-select`.
5. `apple_lldb_dap_initialize` starts LLDB-DAP, completes initialization, drains events, and tears down the probe adapter.
6. `apple_debug_session_create` creates an owned persistent adapter session.
7. Session tools send typed DAP requests for launch/attach, breakpoints, threads, paged stack/variables, exception filter options, memory, disassembly, stepping, watchpoints, evaluation, memory search/patch, and continuation.
8. `apple_debug_stop_snapshot` drains pending stop events and collects a bounded, correlated threads/stack/scopes/registers/modules observation.
9. `apple_macho_inspect`, `apple_binary_inspect`, `apple_runtime_metadata`, `apple_dwarf_inspect`, `apple_binary_diff`, `apple_symbolicate`, `apple_crash_inspect`, and `apple_crash_symbolicate` analyze local artifacts without launching them.
10. Simulator and CoreDevice tools validate known identifiers and explicit mutation policies before changing target state.
11. Xcode discovery/build tools use explicit project, scheme, configuration, and destination arguments.
12. `apple_simulator_ui_snapshot` runs the fixture/project XCUITest target, exports the named JSON attachment from the result bundle, and returns a bounded accessibility tree.
13. `apple_simulator_ui_action` runs a bounded tap, text-entry, swipe, or wait command through the same XCUITest runner and returns the post-action tree.
14. `apple_simulator_ui_probe` and `apple_simulator_ui_probe_action` generate a temporary UI-testing-only Xcode project and use `XCUIApplication(bundleIdentifier:)` to inspect an installed Simulator application; they never need to build or inject code into that application.
15. `apple_debug_runtime_diagnose` invokes bounded Apple heap/runtime tools for authorized host processes; `apple_assemble` produces static code bytes, and `apple_debug_patch_assembly` applies them only through the existing write grant and readback/rollback path.
16. `apple_debug_forward_trace` records bounded forward stop events; `apple_debug_reverse_capabilities` and `apple_kernel_capabilities` report unsupported reverse/time-travel and kernel-memory operations explicitly.
17. `apple_debug_memory_analyze`, `apple_debug_memory_snapshot`, and `apple_debug_memory_diff` expose typed vmmap state without replacing the attach gate.
18. `apple_simulator_environment` and `apple_simulator_repro_bundle` use fixed simctl workflows and bounded artifact paths; they do not erase or pair devices.
19. `apple_signing_audit`, `apple_patch_preview`, and `apple_resign_plan` inspect or plan release operations without silently signing or overwriting artifacts.
20. `apple_plugin_list` discovers manifests only; `apple-debug-workbench` provides a local native GUI over selected analyzers.
21. `apple_log_show` reads bounded host or Simulator unified logs; it never starts an unbounded stream.
22. Server shutdown closes every owned LLDB-DAP adapter before the process exits.

## Runtime topology

The topology is local macOS only: one short-lived MCP process, zero listening ports, no hosted service, and no persistent database. Build artifacts remain under `.build`; `make package` creates an unsigned archive and `make release-package` creates an explicitly authorized signed/notarized app archive under ignored `dist/`; simulator/device state belongs to Apple tooling and is changed only by explicit workflows. Remote HTTP transport remains outside the current repository boundary.

## Cross-cutting concerns

- Authentication: stdio inherits the MCP client process boundary; a future HTTP transport must bind locally and require explicit authentication.
- Authorization: capability reports and environment-gated policy checks guard process control, expression evaluation, memory writes, Simulator mutation, device mutation, and Xcode builds.
- Filesystem safety: Mach-O/crash analyzers accept bounded regular files; binary diff accepts only a regular Mach-O, an `.app`, or a `.dSYM` with a discovered Mach-O payload; debugger launch requires a regular target and explicit user authorization.
- Cleanup: failed launches remove their session; explicit close, server shutdown, and adapter failures close pipes and terminate only the owned LLDB-DAP process.
- Reliability: external-tool failures become typed MCP errors; no arbitrary-shell fallback is permitted.
- Licensing: project code is GPL-3.0-or-later under Burak Karahan; upstream dependencies retain their own licenses.

## Mechanically enforced invariants

| Invariant | Enforcer | Recovery guidance |
| --- | --- | --- |
| Toolchain discovery uses a fixed allowlist and no shell | `ToolchainProbeTests` and implementation | Extend the allowlist and test when adding a tool |
| Every Apple target has an explicit capability report | `CapabilitiesTests` | Add the platform to `AppleDebugPlatform.allCases` and `CapabilityMatrix` |
| Unsupported physical-device capabilities remain visible | `CapabilitiesTests` and capability JSON | Keep the capability restricted until device evidence exists |
| Artifact analyzers are regular-file and size bounded | Mach-O/crash tests and implementations | Reject the input; never execute it as a fallback |
| Mutating debugger operations are explicitly gated | `DebugPolicy` and `DebugSessionTests` | Keep the operation disabled and add a reproducing policy test |
| Build, tests, MCP smoke, fixture smoke, whitespace, and placeholder checks stay green | `scripts/check.sh` | Run `make check` and fix the first reported failure |
| Harness routes and documents remain complete | `scripts/harness_check.sh` plus bundled validator | Repair the named route or update the active ExecPlan |

## Architecture decisions

- Use the official Swift MCP SDK for MCP framing and transport; do not reimplement JSON-RPC framing.
- Use SwiftPM as the build boundary because the server runs locally on macOS and coordinates Xcode tooling.
- Keep capability restrictions as data, not hidden in client-specific prompts.
- Prefer LLDB-DAP over arbitrary LLDB shell commands so the MCP surface is typed, bounded, and reviewable.
- Make dangerous operations opt-in and fixture-tested before promoting them to a verified capability.
