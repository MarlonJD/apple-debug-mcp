# Platform Scope

## Product goal

Provide an MCP-native Apple debugging and reverse-engineering workbench that lets an authorized AI client inspect and control macOS processes, iOS Simulator targets, and development-authorized iOS applications through stable, capability-aware tools.

## Supported target classes

### macOS

The target is a local macOS process or binary for which the user has debugging authority. The implemented surface includes LLDB-DAP session control, launch/attach, breakpoints, stepping, forward stop tracing, bounded checkpoint artifacts and source-location replay for prior local launches, scopes/variables, stack, bounded memory read, explicitly gated expression evaluation and memory write, transactional assembly patching, Mach-O headers/segments/symbols/strings, CFG/basic-block/call-graph/xref/relocation analysis with annotated pseudo-code, dyld shared-cache tables and selected-image exports/symbols/chained-fixup imports/ObjC-Swift pointer cross-references, crash analysis, `atos` symbolication, unified logs, Apple binary intelligence, Objective-C/Swift/concurrency metadata, source-backed public Swift AST including multi-file and Xcode target/module context, deep bounded DWARF DIE/type/source/line-table analysis, typed vmmap snapshots/diffs, heap/leaks/malloc-history/sample diagnostics, xctrace timeline/diff analysis, signing audits, patch previews, and read-only binary diffing for local Mach-O and bundle artifacts. Reverse execution/time-travel and kernel memory debugging remain explicit restricted capabilities because the Apple toolchain/security boundary does not provide them here.

### iOS Simulator

The target is an application installed in a local Simulator. The implemented surface includes Xcode build/discovery, install, launch, terminate, screenshot, logs, forward stepping traces, Mach-O/CFG/shared-cache/binary-diff analysis, crash analysis, symbolication, Objective-C/Swift metadata, deep dSYM/DWARF reports, arm64/x86_64 assembly generation, Simulator environment controls, reproducible evidence bundles, project-backed XCUITest workflows, and a generated XCUITest runner that can inspect/act on an arbitrary installed app through `XCUIApplication(bundleIdentifier:)`. Reverse execution/time-travel and kernel memory remain restricted. Simulator results do not replace physical-device evidence.

### Physical iOS device

The target is a development application installed on a physical device that the user is authorized to develop and debug. Modern devices use CoreDevice pairing/tunnel state, deterministic install/launch with a returned process ID, process inventory/lifecycle controls, bounded sysdiagnose collection, xctrace performance capture, and the documented LLDB `device process attach --pid` path; CoreDevice sessions can consume a signed `.app` path for local symbols and source breakpoints. CoreDevice-incompatible legacy iOS devices use `xcdevice` plus `ios-deploy` and require the signed `.app` path when creating an LLDB-DAP session. All physical workflows require Apple signing, Developer Mode, the relevant entitlements, explicit debug/mutation grants, and targeted cleanup. Public file-backed physical screenshot/UI inspection remains restricted. Stock App Store applications are not a supported target class.

### Kernel lab

An optional, separately authorized kernel-lab profile can connect to a preconfigured remote KDP target using a matching KDK/debug-kernel image. The implemented provider is read-only and exposes bounded threads, stack, registers, and memory inspection through fixed LLDB commands. It does not prepare the target, change SIP or boot security, execute arbitrary LLDB commands, or write kernel memory. DriverKit/system-extension processes remain ordinary user-space macOS LLDB targets.

## Non-goals

- Circumventing Apple code-signing, sandbox, entitlement, or device-security controls.
- Attaching to arbitrary stock applications on a non-authorized device.
- Running an unauthenticated public debugger HTTP service.
- Replacing Xcode for every Apple development workflow before the core debugger behavior is proven.

## Deferred and platform-blocked boundaries

The following boundaries are recorded explicitly and are not part of the current core implementation work:

| Boundary | Current status | Truthful substitute or revisit trigger |
| --- | --- | --- |
| Apple LLDB reverse execution / time-travel | Blocked by the installed public Apple LLDB backend; process recording, reverse-step, reverse-continue, and replay are unavailable | Keep bounded forward stop traces; revisit only when Apple exposes a supported reversible process API |
| Kernel task/memory and kext debugging | Blocked by SIP, KDK, kernel code-signing, entitlements, and privileged debugger requirements | Keep kernel capabilities fail-closed and expose user-process vmmap, heap, leaks, sampling, and xctrace alternatives |
| Attaching to stock App Store applications | Out of scope without an authorized development boundary; no signing, entitlement, or sandbox bypass is permitted | Support only paired/development-authorized applications with explicit grants |
| Physical iOS file-backed screenshot/UI inspection | Not exposed by the supported public CoreDevice tooling | Keep physical UI capture restricted; use the Simulator XCUITest/UI bridge |
| Full Swift AST recovery from a compiled binary | Public `swiftc -dump-ast` requires source/compiler context and does not reconstruct a complete AST from an arbitrary binary | Keep source-backed AST and DWARF/symbol metadata bounded; revisit only if a stable public artifact exists |
| Real third-party plugin services | A production plugin must be an independently signed App Sandbox XPC service with service-specific mediation; the repository fixture is not a production analyzer | Keep the protocol and signed fixture bounded; defer real service integrations |

## Acceptance boundary

The product is successful in stages:

1. A local MCP client can initialize the server and discover tools.
2. macOS LLDB inspection and controlled process operations work against a signed fixture binary.
3. macOS controlled process operations remain policy-gated and cleanup-tested.
4. Simulator build/run/debug and UI/log evidence work against a fixture app.
5. Physical-device inventory, development-app lifecycle, and remote LLDB inspection/control work for paired, development-authorized fixtures through separate modern CoreDevice and legacy transports.

Each stage must have a fixture and an exact verification command before being called verified.
