# Reliability

Apple Debug MCP is currently a short-lived local CLI. It has no hosted availability target, persistent state, background worker, or production deployment.

## Reliability contract

| Risk or invariant | Detection | Recovery | Verification |
| --- | --- | --- | --- |
| Xcode tool is absent or unavailable | apple_toolchain_status returns a missing path | Install/select the required Xcode toolchain and rerun discovery | make check and MCP smoke output |
| MCP process exits before initialization | Smoke fixture receives no valid initialize response | Run swift build, inspect stderr, and retry the command | scripts/smoke_mcp.sh |
| LLDB-DAP adapter fails during initialization | apple_lldb_dap_initialize returns an MCP error | Inspect the reported DAP failure; do not launch a target as a fallback | scripts/smoke_mcp.sh |
| Mach-O input is malformed or too large | apple_macho_inspect returns a typed analysis error | Fix the input or reduce scope; never execute the file as a fallback | MachOTests and scripts/smoke_mcp.sh |
| Debug session leaks an adapter process | DebugSessionTests or process inspection finds lldb-dap after close | Close pipes, terminate, force-kill only the owned adapter, and wait | DebugSessionTests |
| LLDB-DAP capability is unsupported by the installed adapter | A named request times out or the initialize capability is absent | Do not expose the request as verified; use the adapter capability report and keep the tool fail-closed | DAP initialize response and fixture smoke |
| Simulator inventory is unavailable or malformed | apple_simulator_list returns a typed error | Verify Xcode/CoreSimulator availability; do not mutate state as fallback | AppleSimulatorTests and smoke |
| Physical-device inventory is unavailable or malformed | apple_device_list returns a typed error | Verify CoreDevice pairing/tunnel state; do not attempt install/launch as fallback | AppleDeviceTests |
| Xcode project discovery/build fails | apple_xcode_discover or apple_xcode_build returns a typed error | Inspect xcodebuild output and preserve the selected destination; do not run arbitrary shell fallback | AppleXcodeTests and build transcript |
| Debug fixture cannot be prepared | make fixture fails during clang or codesign | Inspect the first toolchain error; do not bypass signing or launch an unverified target | scripts/build_debug_fixture.sh |
| Debugger fixture behavior regresses | debug_fixture_smoke.py fails or leaves a child process | Capture the first MCP/DAP response and rerun cleanup; keep the feature unverified until fixed | make check |
| iOS fixture build regresses | make ios-fixture fails or app bundle/dSYM is missing | Inspect xcodebuild’s first error and preserve the selected Simulator destination | make ios-fixture |
| iOS Simulator fixture leaves state behind | ios-fixture-smoke fails before cleanup | Rerun targeted terminate/shutdown for the known fixture UDID; do not erase the device | make ios-fixture-smoke |
| iOS Simulator debugger attach regresses | ios-debug-fixture-smoke fails or leaves a session/process | Close the owned LLDB session, terminate the known bundle, and shutdown the known UDID | make ios-debug-fixture-smoke |
| Simulator MCP lifecycle regresses | ios-mcp-tool-smoke fails during app info, container, launch flags, or screenshot | Use the known fixture UDID, terminate the fixture bundle, and preserve the first MCP error | make ios-mcp-tool-smoke |
| Semantic UI snapshot is empty | XCUITest attachment is missing or contains no stable identifiers | Keep explicit accessibility identifiers on fixture controls and rerun the standalone MCP UI-tree smoke | make ios-ui-tree-smoke |
| Simulator UI action regresses | XCUITest action probe fails or returns no post-action tree | Preserve the first action failure, terminate the fixture, and rerun one action at a time | make ios-ui-tree-smoke |
| Tool output becomes non-deterministic | Core tests or sorted JSON output changes unexpectedly | Reproduce with the same fixture and update the contract intentionally | swift test |
| Debugger operation leaves a target or adapter running | Fixture smoke fails or process inspection finds an owned child | Close the session and rerun targeted cleanup; do not kill unrelated processes | macOS and iOS Simulator fixture smoke |
| Crash report is malformed or unsupported | apple_crash_inspect returns a typed analysis error | Preserve the artifact and inspect it with the supported `.crash`/`.ips` parser | CrashReportTests |
| Unified log query is too broad or unavailable | apple_log_show returns a bounded-output or command error | Narrow duration/predicate and verify host/Simulator logging availability | AppleLogsTests and tool error path |
| Simulator screenshot cannot be written | apple_simulator_screenshot returns a typed command error | Use a writable PNG path and keep the Simulator mutation gate explicit | SimulatorService and iOS fixture smoke |
| Unsigned package cannot be produced | make package or the release SwiftPM build fails | Inspect the first SwiftPM/archive error; signing and notarization are separate release steps | scripts/package_macos.sh |
| Hosted availability, failover, and production rollback | Not applicable to the current local CLI | N/A; define only when a hosted service is introduced | N/A |

## Failure policy

The server fails closed for unknown tools and reports missing allowlisted tool paths as data. It must not fall back to arbitrary shell execution or silently broaden target permissions.
