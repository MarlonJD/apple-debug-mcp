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
| Sources/AppleDebugCore/CrashReports.swift | Bounded `.crash` text and `.ips` JSON analysis | Maintainers; update with Apple crash schema changes |
| Sources/AppleDebugCore/AppleSimulator.swift | Simulator inventory and policy-gated lifecycle/screenshot operations | Maintainers; update with simctl behavior |
| Sources/AppleDebugCore/AppleSimulatorUI.swift | XCUITest accessibility-tree probe and xcresult attachment decoding | Maintainers; update with XCTest/Xcode behavior |
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
- `DebugSessionManager`: owns session IDs and routes launch, attach, source/instruction breakpoint locations, source/function/exception breakpoints, inspection, registers, modules, completions, variable mutation, stepping, watchpoints, evaluation, memory writes, and target lifecycle through policy checks. Physical sessions initialize LLDB with a validated `device select <UUID>` command and remain separately gated.
- `MachOInspector`: parses bounded regular files without executing them; universal binaries expose architecture records and thin binaries expose header/load-command/segment data, symbols, and strings.
- `AppleBinaryIntelligenceService`, `AppleRuntimeMetadataService`, `AppleBinaryDiffService`, and `CrashSymbolicationService`: inspect signed Apple binaries, recover Objective-C/Swift metadata, compare regular Mach-O files or `.app`/`.dSYM` bundles, and triage crash frames without executing artifacts.
- `CrashReportAnalyzer`: parses only bounded Apple crash artifacts and returns structured metadata without executing or symbolically loading their contents.
- `AppleSimulatorService`, `AppleSimulatorUIService`, `AppleDeviceService`, `AppleXcodeService`, `AppleLogService`: invoke fixed Apple tools with explicit argument arrays and typed results; Xcode builds return discovered derived-data, product, and dSYM paths, while Xcode tests return an xcresult summary.
- `AppleProcessRunner`: owns file-backed, bounded stdout/stderr capture for Apple tool invocations so large diagnostics cannot deadlock a synchronous adapter.
- `ToolCatalog`: exposes only named MCP tools; unknown tools fail closed.

No backend may expose arbitrary shell execution or silently broaden a target’s authorization boundary.

## Data and control flow

1. The MCP client starts `apple-debug-mcp` as a stdio child process.
2. The server completes MCP initialization and advertises the current tool schemas.
3. `apple_capabilities` returns platform-specific support and restrictions.
4. `apple_toolchain_status` probes a fixed allowlist through `xcrun`/`xcode-select`.
5. `apple_lldb_dap_initialize` starts LLDB-DAP, completes initialization, drains events, and tears down the probe adapter.
6. `apple_debug_session_create` creates an owned persistent adapter session.
7. Session tools send typed DAP requests for launch/attach, breakpoints, threads, stack, scopes, variables, memory, disassembly, stepping, watchpoints, evaluation, memory search/patch, and continuation.
8. `apple_debug_stop_snapshot` drains pending stop events and collects a bounded, correlated threads/stack/scopes/registers/modules observation.
9. `apple_macho_inspect`, `apple_binary_inspect`, `apple_runtime_metadata`, `apple_binary_diff`, `apple_symbolicate`, `apple_crash_inspect`, and `apple_crash_symbolicate` analyze local artifacts without launching them.
10. Simulator and CoreDevice tools validate known identifiers and explicit mutation policies before changing target state.
11. Xcode discovery/build tools use explicit project, scheme, configuration, and destination arguments.
12. `apple_simulator_ui_snapshot` runs the fixture/project XCUITest target, exports the named JSON attachment from the result bundle, and returns a bounded accessibility tree.
13. `apple_simulator_ui_action` runs a bounded tap, text-entry, swipe, or wait command through the same XCUITest runner and returns the post-action tree.
14. `apple_log_show` reads bounded host or Simulator unified logs; it never starts an unbounded stream.
15. Server shutdown closes every owned LLDB-DAP adapter before the process exits.

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
