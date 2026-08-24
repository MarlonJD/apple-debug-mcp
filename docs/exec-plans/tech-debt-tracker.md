# Technical Debt Tracker

| ID | Area | Evidence | Impact | Owner | Next action or revisit trigger | Status |
| --- | --- | --- | --- | --- | --- | --- |
| DEBT-001 | Physical iOS debugging | CoreDevice inventory and fail-closed install/launch exist; current device is not paired/tunnel-ready | Remote LLDB attach and breakpoint evidence cannot be certified locally | Apple Debug MCP maintainers | Re-run the authorized-device suite after pairing, Developer Mode, signing, and user authorization are available | blocked-by-environment |
| DEBT-002 | Static analysis metadata | Mach-O headers, segments, symbols, strings, symbolication, and crash reports are implemented | Objective-C/Swift metadata and richer disassembly are not yet exposed as dedicated reports | Apple Debug MCP maintainers | Add metadata parsers when a fixture and stable output contract are defined | open |
| DEBT-003 | Simulator UI inspection | Fixture accessibility identifiers and a 9-element XCTest/XcodeBuildMCP snapshot are verified | Standalone Apple Debug MCP UI-tree inspection and UI action targeting are not exposed | Apple Debug MCP maintainers | Add a self-contained XCTest/UI-tree bridge before advertising `ui-inspection` from the standalone MCP server | open |
| DEBT-004 | Release engineering | `make package` produces an unsigned macOS archive | No signed/notarized release artifact or CI matrix exists | Apple Debug MCP maintainers | Add signing, notarization, and GitHub CI only with explicit release scope | open |
