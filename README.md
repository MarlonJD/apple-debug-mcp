# Apple Debug MCP

Apple Debug MCP is a local, GPL-licensed MCP server for AI-assisted debugging and reverse engineering of authorized Apple targets.

The current product surface includes:

- macOS LLDB-DAP launch and attach sessions;
- source/function/exception/instruction breakpoints, breakpoint-location lookup, threads, stack traces, scopes, registers, variables, completions, modules, statement/line/instruction stepping, pause/continue, disassembly, and bounded memory reads;
- watchpoint plumbing through DAP data breakpoints;
- explicitly authorized expression evaluation and memory writes, plus target terminate/disconnect control;
- bounded memory pattern search and expected-bytes transactional patch/rollback (write permission required);
- structured stop snapshots that bundle stop events, threads, stack, scopes, registers, and modules;
- Mach-O/universal-binary headers, segments, symbols, and printable strings;
- Apple binary intelligence: code signatures, entitlements, linked libraries, nm symbols, and dyld exports;
- Objective-C classes/protocols/selectors and demangled Swift symbol metadata;
- read-only binary diffing for Mach-O files, `.app` bundles, and `.dSYM` bundles, including symbols, exports, dependencies, signatures, entitlements, hashes, and UUIDs;
- `atos` symbolication from Mach-O files, `.app` executables, or `.dSYM` payloads, plus `.crash`/`.ips` crash-report inspection;
- crash-frame triage with multi-artifact image matching and per-frame symbolication errors;
- iOS Simulator inventory, lifecycle, app install/launch/terminate, screenshots, logs, and LLDB-DAP attach;
- Xcode project discovery and explicitly authorized builds;
- CoreDevice physical-device inventory plus authorization-gated development-app install/launch.

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

The capability report distinguishes macOS, iOS Simulator, and physical iOS device targets. Physical-device remote LLDB attach remains restricted until a paired, development-authorized device fixture is available. Simulator screenshot capture, the policy-gated standalone MCP accessibility-tree bridge, and fixture UI actions are available.

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
```

`make check` proves the MCP protocol, tool discovery, Mach-O/crash fixtures, signed macOS debugger fixture, and debugger cleanup. The iOS targets are explicit Simulator workflows; `ios-mcp-tool-smoke` exercises the public MCP lifecycle and `ios-ui-tree-smoke` exercises the XCUITest accessibility bridge end to end.

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
- `APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1` — create a physical-device LLDB session only after UUID, pairing, tunnel, signing, and Developer Mode checks pass;
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

The local macOS debugger and iOS Simulator workflows are verified against repository fixtures on the development machine. `make package` produces an unsigned relocatable macOS archive, while `make release-package` produces the separately authorized signed/notarized archive. Physical-device inventory and fail-closed authorization are verified, but actual device install/launch/debug evidence requires a paired device, Developer Mode, signing, and user authorization.

## License

Copyright (C) 2026 Burak Karahan.

This project is licensed under the GNU General Public License, version 3 or any later version. See [LICENSE](LICENSE).
