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
| Xcode project discovery/build fails | apple_xcode_discover or apple_xcode_build returns a typed error | Inspect xcodebuild output and preserve the selected destination; do not run arbitrary shell fallback | AppleXcodeTests and xcode-artifact-smoke |
| Xcode build output deadlocks or is incomplete | xcodebuild does not return or app/dSYM artifacts are missing | Keep stdout/stderr file-backed and inspect the typed artifact manifest; do not infer success from a partial log | XcodeService and xcode-artifact-smoke |
| Apple tool output fills a pipe | A synchronous adapter stops before returning a typed result | Use the bounded file-backed process runner and preserve the first termination/error result | AppleProcessRunner and make check |
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
| Stop snapshot is incomplete | apple_debug_stop_snapshot lacks events, threads, stack, registers, or modules | Preserve the raw DAP response and inspect adapter capabilities before adding another request | macOS fixture smoke |
| Stop event is not observed after control | apple_debug_wait_for_stop returns timedOut without a stopped/exited/terminated event | Keep the session open, inspect buffered events, and retry with a bounded timeout; never infer a stop from the continue response alone | macOS fixture smoke |
| Memory patch verification fails | apple_debug_patch_memory cannot read back requested bytes | Roll back expected original bytes when possible and keep the result unverified | DebugPolicy and patch transaction path |
| Variable mutation is rejected | apple_debug_set_variable returns the explicit policy error | Keep the target stopped and enable the separate variable-write grant only for an authorized debugging session | DebugSessionTests and macOS fixture smoke |
| Crash report is malformed or unsupported | apple_crash_inspect returns a typed analysis error | Preserve the artifact and inspect it with the supported `.crash`/`.ips` parser | CrashReportTests |
| Crash frame has no matching artifact | apple_crash_symbolicate reports unmatchedFrameCount or a per-frame error | Supply an imageName-to-binary/dSYM mapping and preserve unmatched frames instead of guessing | CrashReportTests and MCP smoke |
| Apple binary intelligence tool is unavailable or noisy | apple_binary_inspect returns a typed command/size error | Inspect the first codesign/otool/nm/dyld_info error and keep the artifact unexecuted | AppleBinaryIntelligenceTests and MCP smoke |
| Runtime metadata tool is unavailable or noisy | apple_runtime_metadata returns a typed command/size error | Preserve the binary and rerun the focused Objective-C/Swift metadata test | AppleRuntimeMetadataTests |
| Binary diff cannot resolve an artifact | apple_binary_diff returns an artifact or bounded-tool error | Keep the inputs unexecuted, verify the `.app`/`.dSYM` layout, and rerun the focused diff test | AppleBinaryDiffTests and MCP smoke |
| Unified log query is too broad or unavailable | apple_log_show returns a bounded-output or command error | Narrow duration/predicate and verify host/Simulator logging availability | AppleLogsTests and tool error path |
| Simulator screenshot cannot be written | apple_simulator_screenshot returns a typed command error | Use a writable PNG path and keep the Simulator mutation gate explicit | SimulatorService and iOS fixture smoke |
| Simulator recording or location control fails | apple_simulator_record_video or location tools return a typed command error | Keep the selected UDID and output path explicit; preserve the first simctl diagnostic and clean generated media | ios-mcp-tool-smoke |
| Signed release validation fails | make release-package reports a codesign, notarization, staple, or Gatekeeper error | Preserve the release staging artifact path from the first failure, inspect the exact signing/notary diagnostic, and do not publish the zip until all three validations pass | scripts/release_macos.sh and docs/RELEASE.md |
| Unsigned package cannot be produced | make package or the release SwiftPM build fails | Inspect the first SwiftPM/archive error; signing and notarization are separate release steps | scripts/package_macos.sh |
| Hosted availability, failover, and production rollback | Not applicable to the current local CLI | N/A; define only when a hosted service is introduced | N/A |

## Failure policy

The server fails closed for unknown tools and reports missing allowlisted tool paths as data. It must not fall back to arbitrary shell execution or silently broaden target permissions.
