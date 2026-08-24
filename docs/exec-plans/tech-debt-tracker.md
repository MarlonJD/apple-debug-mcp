# Technical Debt Tracker

| ID | Area | Evidence | Impact | Owner | Next action or revisit trigger | Status |
| --- | --- | --- | --- | --- | --- | --- |
| DEBT-001 | Physical iOS debugging | CoreDevice inventory and fail-closed install/launch exist; current device is not paired/tunnel-ready | Remote LLDB attach and breakpoint evidence cannot be certified locally | Apple Debug MCP maintainers | Re-run the authorized-device suite after pairing, Developer Mode, signing, and user authorization are available | blocked-by-environment |
| DEBT-002 | Static analysis metadata | Mach-O headers, segments, symbols, strings, symbolication, and crash reports are implemented | Objective-C/Swift metadata and richer disassembly are not yet exposed as dedicated reports | Apple Debug MCP maintainers | Add metadata parsers when a fixture and stable output contract are defined | open |
| DEBT-003 | Simulator UI inspection | Screenshot capture is implemented and verified | Accessibility-tree inspection and UI action targeting are not exposed | Apple Debug MCP maintainers | Choose a Simulator-native accessibility source and add a fixture before advertising `ui-inspection` | open |
| DEBT-004 | Release engineering | Local SwiftPM build and GPL source distribution are verified | No signed/notarized release artifact or CI matrix exists | Apple Debug MCP maintainers | Add packaging, signing, notarization, and GitHub CI only with explicit release scope | open |
