# Apple Debug MCP

Apple Debug MCP is a local, GPL-licensed MCP server for AI-assisted debugging and reverse engineering of authorized Apple targets.

The current product surface includes:

- macOS LLDB-DAP launch and attach sessions;
- source/function/exception/instruction breakpoints, breakpoint-location lookup, threads, stack traces, scopes, registers, variables, completions, modules, statement/line/instruction stepping, pause/continue, disassembly, and bounded memory reads;
- watchpoint plumbing through DAP data breakpoints;
- explicitly authorized expression evaluation and memory writes, plus target terminate/disconnect control;
- bounded memory pattern search and expected-bytes transactional patch/rollback (write permission required);
- authorized macOS `vmmap` memory-region reporting (attach permission required);
- bounded `xctrace` Time Profiler, Allocations, and System Trace capture for macOS or Simulator targets;
- parsed Time Profiler rows, symbol/frame hotspots, percentages, and folded flame-stack records from `.trace` bundles;
- semantic performance summaries for allocation bytes/events, running/blocked samples, hitches, signposts, and Swift concurrency task/actor/continuation rows;
- template-specific semantic xctrace reports with explicit domains and bounded numeric totals for Time Profiler, Allocations, System Trace, Power/Energy, Animation, Signposts, and Swift Concurrency;
- bounded xctrace timeline points plus trace-to-trace semantic/hotspot diffs for regression work;
- trace-backed Swift Concurrency task/actor/continuation graphs that merge the public `swift-task-*` and `swift-actor-*` xctrace schemas with explicit sampling and private-runtime boundaries;
- Apple-native heap/leaks/malloc-history/sample diagnostics for authorized macOS processes;
- bounded arm64/x86_64 assembly, disassembly, and transactional assembly patching through LLDB-DAP memory writes;
- Mach-O CFG/basic-block/call-graph/xref/relocation reports with address-based branch/call references, annotated decompiler-style pseudo-code, and a native workbench graph view;
- direct dyld shared-cache header/mapping/image parsing with selected-image export/nlist extraction, chained-fixup imports, ObjC/Swift runtime strings, and bounded pointer cross-references;
- typed vmmap region reports, persisted memory snapshots, and region diffs;
- Simulator status-bar/UI/privacy/pasteboard/keychain/media/push/environment controls and reproducible screenshot/appinfo/log evidence bundles;
- read-only signing/entitlement/Gatekeeper audits, patch previews, and release-authority re-sign plans;
- a native SwiftUI macOS workbench with session launch/threads/snapshots/pause/continue/instruction stepping/evaluation controls, CFG graph/pseudo-code, and trace timeline/diff panels;
- signed plugin manifest validation plus an App Sandbox XPC plugin protocol; third-party plugin code stays in its own independently signed `.xpc` service, while `transport=profile` is an explicit legacy diagnostic path;
- explicit forward execution stop traces plus fail-closed reports for unavailable reverse/time-travel and kernel-memory capabilities;
- structured stop snapshots that bundle stop events, threads, stack, scopes, registers, and modules;
- Mach-O/universal-binary headers, segments, symbols, and printable strings;
- Apple binary intelligence: code signatures, entitlements, linked libraries, nm symbols, and dyld exports;
- Objective-C classes/protocols/selectors and demangled Swift symbol metadata;
- deep bounded DWARF inspection from Mach-O/dSYM inputs, including DIE hierarchy, typed attributes, declaration locations, source lists, line-table rows, statistics, and address lookups;
- source-backed typed Swift AST inspection through public `swiftc -dump-ast`, with declarations, types, functions, variables, imports, compiler locations, bounded multi-file modules, and Xcode project/scheme SDK context;
- read-only binary diffing for Mach-O files, `.app` bundles, and `.dSYM` bundles, including symbols, exports, dependencies, signatures, entitlements, hashes, and UUIDs;
- `atos` symbolication from Mach-O files, `.app` executables, or `.dSYM` payloads, plus `.crash`/`.ips` crash-report inspection;
- crash-frame triage with multi-artifact image matching and per-frame symbolication errors;
- iOS Simulator inventory, lifecycle, app install/launch/terminate, screenshots, logs, and LLDB-DAP attach;
- generated XCUITest runners that inspect and act on arbitrary applications already installed in a Simulator, without requiring the target app’s Xcode project;
- Simulator URL opening, deterministic location injection/clear, and bounded video recording for automated reproduction;
- Xcode project discovery, explicitly authorized builds with derived-data/`.app`/`.dSYM` manifests, and test execution with `.xcresult` summaries;
- CoreDevice and legacy `xcdevice` physical-device inventory, plus optional `ios-deploy` authorization-gated development-app install/launch.

The server is intentionally local and capability-aware. It does not provide arbitrary shell execution, bypass Apple signing or entitlements, or attach to stock App Store applications without an authorized development boundary.

## Architecture

```text
MCP client
    │ stdio
    ▼
Apple Debug MCP
    ├── MCP tool catalog and policy gates
    ├── LLDB-DAP session manager
    ├── Mach-O, symbolication, and crash-report analyzers
    └── Xcode, Simulator, CoreDevice, and unified-log adapters
```

The capability report distinguishes macOS, iOS Simulator, and physical iOS device targets. Legacy iOS 15 inventory and profiling are available; physical-device remote LLDB attach remains restricted until a CoreDevice-capable or dedicated legacy LLDB bridge is available. Simulator screenshot capture, the policy-gated standalone MCP accessibility-tree bridge, and fixture UI actions are available.

## Requirements

- macOS 13 or later;
- Xcode and its command-line tools;
- Swift 6 / Xcode 16 or later;
- an MCP-compatible client with local stdio support.

## Build and verify

```sh
swift build
swift test
make check
make harness-check
make package
make release-package
make fixture
make ios-fixture
make ios-fixture-smoke
make ios-debug-fixture-smoke
make ios-mcp-tool-smoke
make ios-ui-tree-smoke
make ios-arbitrary-ui-smoke
make dwarf-smoke
make swift-ast-smoke
make performance-analysis-smoke
make swift-concurrency-graph-smoke
make runtime-diagnostics-smoke
make assembler-smoke
make reverse-capability-smoke
make control-flow-smoke
make memory-map-smoke
make simulator-environment-smoke
make repro-bundle-smoke
make signing-audit-smoke
make patch-workflow-smoke
make plugin-smoke
make plugin-xpc-smoke
make plugin-host-build-smoke
make workbench-build-smoke
```

`make check` proves the MCP protocol, tool discovery, Mach-O/crash fixtures, signed macOS debugger fixture, and debugger cleanup. The iOS targets are explicit Simulator workflows; `ios-mcp-tool-smoke` exercises the public MCP lifecycle, `ios-ui-tree-smoke` exercises the XCUITest accessibility bridge end to end, `dwarf-smoke` builds the generic iOS fixture and verifies typed dSYM entries, source paths, line rows, and statistics, `performance-analysis-smoke` verifies xctrace XML rows/hotspots/flame stacks, `swift-concurrency-graph-smoke` compiles an async fixture, records the public Swift Concurrency template, and verifies task/actor graph evidence, `runtime-diagnostics-smoke` verifies Apple heap/leaks/sample tools, and `assembler-smoke` verifies arm64/x86_64 code generation.

Pushes and pull requests run the macOS core/MCP checks and upload the reproducible unsigned package as a CI artifact. Signing and notarization require a separate release workflow with Apple Developer credentials.

For a signed and notarized archive on a configured release Mac, see [docs/RELEASE.md](docs/RELEASE.md) and run `CODESIGN_IDENTITY='Developer ID Application: Burak Karahan (UPK4SC93AN)' NOTARY_PROFILE=general-notary make release-package`.

## Run

```sh
swift run apple-debug-mcp
```

Safe defaults and opt-in boundaries:

- `APPLE_DEBUG_ALLOW_TARGET_LAUNCH=1` — launch a known local target;
- `APPLE_DEBUG_ALLOW_TARGET_ATTACH=1` — attach to an explicitly selected local process ID;
- `APPLE_DEBUG_ALLOW_EVALUATE=1` — permit LLDB expression evaluation;
- `APPLE_DEBUG_ALLOW_MEMORY_WRITE=1` — permit at most 4096-byte DAP memory writes;
- `APPLE_DEBUG_ALLOW_VARIABLE_WRITE=1` — permit explicit DAP variable mutation for an authorized stopped target;
- `APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1` — boot, install, launch, terminate, shut down, or screenshot a Simulator;
- `APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1` — mutate only a paired, tunnel-ready development device;
- `APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1` — create a physical-device LLDB session only after a CoreDevice UUID or legacy UDID, transport-specific authorization, signing, and Developer Mode checks pass;
- `APPLE_DEBUG_ALLOW_XCODE_BUILD=1` — run an explicitly selected Xcode project/scheme/configuration/destination build.

Do not enable a boundary for software or devices you are not authorized to debug.

Example MCP configuration after building:

```json
{
  "mcpServers": {
    "apple-debug-mcp": {
      "command": "/absolute/path/to/apple-debug-mcp/.build/debug/apple-debug-mcp"
    }
  }
}
```

## Current verification boundary

The local macOS debugger and iOS Simulator workflows are verified against repository fixtures on the development machine. The iOS 15 physical fixture builds and signs for the connected iPod touch; legacy `xcdevice`/`xctrace` inventory and process profiling are available, while install/launch through MCP requires optional `ios-deploy` and physical LLDB-DAP still requires the CoreDevice transport. `make package` produces an unsigned relocatable macOS archive, while `make release-package` produces the separately authorized signed/notarized archive. Apple LLDB reverse execution/time-travel and kernel memory debugging are explicit platform/toolchain restrictions; the server reports them as unsupported and exposes forward tracing plus Apple-native user-process alternatives.

## License

Copyright (C) 2026 Burak Karahan.

This project is licensed under the GNU General Public License, version 3 or any later version. See [LICENSE](LICENSE).
