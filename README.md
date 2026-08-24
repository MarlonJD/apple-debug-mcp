# Apple Debug MCP

Apple Debug MCP is an MCP server for AI-assisted debugging and reverse engineering of authorized Apple targets.

The project is designed to cover:

- macOS process debugging through LLDB;
- iOS Simulator debugging and lifecycle control;
- paired, development-authorized iOS device workflows;
- Mach-O, Objective-C, and Swift binary analysis;
- crash analysis and dSYM-based symbolication.

The repository starts with a small, safe foundation. The server exposes read-only capability and toolchain discovery, Mach-O inspection, LLDB-DAP adapter initialization, owned session lifecycle management, and specialized debugger inspection commands. Target launch, attach, memory mutation, and device operations are behind explicit capability and permission boundaries.

## Design

```text
MCP client
    │ stdio
    ▼
Apple Debug MCP
    ├── Debug core and session lifecycle
    ├── LLDB/DAP backend
    ├── Mach-O analysis backend
    ├── Xcode, Simulator, and device adapters
    └── Permission and audit policy
```

The public MCP surface will advertise only the capabilities supported by the active target. A physical iOS device is not treated as an unrestricted desktop process: stock App Store applications are outside the supported debugging boundary.

## Requirements

- macOS 13 or later;
- Xcode and its command-line tools;
- Swift 6 / Xcode 16 or later;
- an MCP-compatible client for local stdio connections.

## Build and test

```sh
swift build
swift test
make check
```

## Run

```sh
swift run apple-debug-mcp
```

Target launch is disabled by default. Enable it only for an authorized local target by setting APPLE_DEBUG_ALLOW_TARGET_LAUNCH=1 in the MCP server environment.

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

## Roadmap

1. LLDB/DAP target session management for local macOS targets.
2. Mach-O headers and segments are available now; add symbols, strings, disassembly, and dSYM analysis.
3. macOS crash/core analysis and controlled memory operations.
4. iOS Simulator build, install, launch, logs, UI inspection, and debugging.
5. Paired physical-device workflows for development-signed applications.
6. Fixtures, integration tests, audit logs, packaging, signing, and release automation.

## License

Copyright (C) 2026 Burak Karahan.

This project is licensed under the GNU General Public License, version 3 or any later version. See [LICENSE](LICENSE).
