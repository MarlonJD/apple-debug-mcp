# Agent Capability Registry

| Capability | Entry point or command | Purpose | Expected signal | Owner or update trigger | Status |
| --- | --- | --- | --- | --- | --- |
| Repository setup | swift package resolve | Resolve SwiftPM dependencies | Exit 0 and dependency graph available | Maintainers; dependency changes | verified |
| Focused tests | swift test --filter CapabilitiesTests | Verify platform policy and tool allowlist | XCTest exits 0 | Maintainers; core changes | verified |
| Full validation | make check | Build, test, smoke, whitespace, and placeholder validation | Exit 0 with summary | Maintainers; every source change | verified |
| Project-native harness gate | make harness-check | Verify product checks and repository harness structure | Exit 0; no unresolved routes/placeholders | Maintainers; every harness change | verified |
| Safe harness convergence | Manual repair followed by make harness-check | Repair safe docs/check drift | Fresh gate pass and refreshed evidence | Maintainers; manual task completion | verified |
| Optional production attestation | N/A | Repository has no production deployment action | N/A with documented reason | Human product owner; scope change | N/A |
| Repository-local tools or skills | scripts/check.sh, scripts/smoke_mcp.sh | Reuse deterministic local workflows | Scripts run from repository root | Maintainers; command changes | verified |
| Source-control context | git status --short --branch, git diff --check | Inspect current source state | Clean/understood diff and whitespace check | Maintainers; every checkpoint | verified |
| Dependency/API references | docs/references/mcp-swift-sdk.md | Make upstream MCP behavior discoverable | Package and SDK contract agree | Maintainers; SDK update | verified |
| Runtime start | swift run apple-debug-mcp | Launch local MCP process | Stdio process accepts MCP initialize | Maintainers; runtime changes | verified |
| Runtime reset | Close stdin; make clean for build state | Stop process and remove local build artifacts | Process exits; .build reset | Maintainers; lifecycle changes | verified |
| UI or API exercise | scripts/smoke_mcp.sh | Exercise MCP protocol, tool schemas, crash analysis, and LLDB-DAP initialization | Initialize, tools/list, analysis calls, and adapter response | Maintainers; tool surface changes | verified |
| Debug session lifecycle | apple_debug_session_create/list/close | Create, inspect, and close an owned local or authorization-gated physical-device LLDB-DAP adapter session | Session ID and target appear, then adapter exits after close | Maintainers; session policy changes | verified-with-boundary |
| Debugger inspection | apple_debug_set_breakpoint, apple_debug_threads, apple_debug_stack_trace, apple_debug_scopes, apple_debug_variables, apple_debug_evaluate, apple_debug_read_memory, apple_debug_disassemble, apple_debug_step, apple_debug_continue | Route typed debugger inspection/control commands through a session | macOS fixture transcript covers inspection/control and cleanup | Maintainers; DAP surface changes | verified |
| iOS Simulator inventory | apple_simulator_list | Discover available Simulator devices without mutation | JSON inventory with UDIDs, runtime, state, and availability | Maintainers; Apple tooling changes | verified |
| Physical-device inventory | apple_device_list | Discover CoreDevice identifiers and development authorization state | JSON inventory with pairing/tunnel evidence | Maintainers; Apple tooling changes | verified-with-boundary |
| Xcode project workflow | apple_xcode_discover and apple_xcode_build | Discover project schemes and run explicit destination builds | Structured discovery or policy-gated build output | Maintainers; Apple tooling changes | verified |
| Authorized debug fixture | make fixture | Compile and ad-hoc sign the local macOS debugger target | Existing Mach-O binary with get-task-allow entitlement | Maintainers; fixture changes | verified |
| Debugger fixture behavior | python3 scripts/debug_fixture_smoke.py | Prove authorized launch and debugger inspection end to end | Breakpoint, threads, stack, scopes, variables, evaluate, memory, disassembly, step, continue, and cleanup transcript | Maintainers; debugger surface changes | verified |
| iOS fixture build | make ios-fixture | Build the SwiftUI Simulator app and dSYM artifact | DebugApp.app and DebugApp.app.dSYM exist under .build/ios-fixture | Maintainers; fixture/project changes | verified |
| iOS Simulator fixture smoke | make ios-fixture-smoke | Exercise explicit Simulator app lifecycle | Install, launch, screenshot, terminate, and shutdown evidence | Maintainers; explicit mutation-authorized task | verified |
| iOS Simulator debugger smoke | make ios-debug-fixture-smoke | Attach LLDB-DAP to the Simulator fixture | Attach, threads, stack, memory, disassembly, and cleanup evidence | Maintainers; explicit mutation-authorized task | verified |
| iOS MCP Simulator smoke | make ios-mcp-tool-smoke | Exercise public MCP Simulator lifecycle and artifact tools | Boot, install, launch flags, app info, container, screenshot, terminate, and cleanup evidence | Maintainers; explicit mutation-authorized task | verified |
| Crash report analysis | apple_crash_inspect | Parse bounded Apple .crash/.ips artifacts | Fixture report returns exception, threads, and frames | Maintainers; crash schema changes | verified |
| Symbolication | apple_symbolicate | Resolve an address with atos | Universal-binary symbolication test passes | Maintainers; Xcode tool changes | verified |
| Unsigned packaging | make package | Create a relocatable macOS archive from the release build | Archive contains executable, GPL license, README, and architecture docs | Maintainers; release workflow changes | verified-with-boundary |
| Logs, metrics, or traces | apple_log_show; stderr transcript; metrics/traces N/A | Read bounded unified logs and diagnose CLI failures | Typed log result or actionable stderr | Maintainers; runtime changes | verified-with-boundary |
