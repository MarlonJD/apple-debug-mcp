# Platform Scope

## Product goal

Provide an MCP-native Apple debugging and reverse-engineering workbench that lets an authorized AI client inspect and control macOS processes, iOS Simulator targets, and development-authorized iOS applications through stable, capability-aware tools.

## Supported target classes

### macOS

The target is a local macOS process or binary for which the user has debugging authority. The implemented surface includes LLDB-DAP session control, launch/attach, breakpoints, stepping, forward stop tracing, scopes/variables, stack, bounded memory read, explicitly gated expression evaluation and memory write, transactional assembly patching, Mach-O headers/segments/symbols/strings, CFG/basic-block/call-graph/xref/relocation analysis with annotated pseudo-code, dyld shared-cache tables and selected-image exports/symbols/chained-fixup imports/ObjC-Swift pointer cross-references, crash analysis, `atos` symbolication, unified logs, Apple binary intelligence, Objective-C/Swift/concurrency metadata, source-backed public Swift AST including multi-file and Xcode target/module context, deep bounded DWARF DIE/type/source/line-table analysis, typed vmmap snapshots/diffs, heap/leaks/malloc-history/sample diagnostics, xctrace timeline/diff analysis, signing audits, patch previews, and read-only binary diffing for local Mach-O and bundle artifacts. Reverse execution/time-travel and kernel memory debugging remain explicit restricted capabilities because the Apple toolchain/security boundary does not provide them here.

### iOS Simulator

The target is an application installed in a local Simulator. The implemented surface includes Xcode build/discovery, install, launch, terminate, screenshot, logs, forward stepping traces, Mach-O/CFG/shared-cache/binary-diff analysis, crash analysis, symbolication, Objective-C/Swift metadata, deep dSYM/DWARF reports, arm64/x86_64 assembly generation, Simulator environment controls, reproducible evidence bundles, project-backed XCUITest workflows, and a generated XCUITest runner that can inspect/act on an arbitrary installed app through `XCUIApplication(bundleIdentifier:)`. Reverse execution/time-travel and kernel memory remain restricted. Simulator results do not replace physical-device evidence.

### Physical iOS device

The target is a development application installed on a physical device that the user is authorized to develop and debug. Modern devices use CoreDevice pairing/tunnel state; CoreDevice-incompatible legacy iOS devices use `xcdevice` plus `ios-deploy` and require the signed `.app` path when creating an LLDB-DAP session. All physical workflows require Apple signing, Developer Mode, and the relevant entitlements. Stock App Store applications are not a supported target class.

## Non-goals

- Circumventing Apple code-signing, sandbox, entitlement, or device-security controls.
- Attaching to arbitrary stock applications on a non-authorized device.
- Running an unauthenticated public debugger HTTP service.
- Replacing Xcode for every Apple development workflow before the core debugger behavior is proven.

## Acceptance boundary

The product is successful in stages:

1. A local MCP client can initialize the server and discover tools.
2. macOS LLDB inspection and controlled process operations work against a signed fixture binary.
3. macOS controlled process operations remain policy-gated and cleanup-tested.
4. Simulator build/run/debug and UI/log evidence work against a fixture app.
5. Physical-device inventory and development-app lifecycle work only for paired, development-authorized fixtures; remote LLDB attach remains gated until a paired-device fixture is available.

Each stage must have a fixture and an exact verification command before being called verified.
