# Agent Capability Registry

| Capability | Entry point or command | Purpose | Expected signal | Owner or update trigger | Status |
| --- | --- | --- | --- | --- | --- |
| Repository setup | swift package resolve | Resolve SwiftPM dependencies | Exit 0 and dependency graph available | Maintainers; dependency changes | candidate |
| Focused tests | swift test --filter CapabilitiesTests | Verify platform policy and tool allowlist | XCTest exits 0 | Maintainers; core changes | candidate |
| Full validation | make check | Build, test, smoke, whitespace, and placeholder validation | Exit 0 with summary | Maintainers; every source change | candidate |
| Project-native harness gate | make harness-check | Verify product checks and repository harness structure | Exit 0; no unresolved routes/placeholders | Maintainers; every harness change | candidate |
| Safe harness convergence | Manual repair followed by make harness-check | Repair safe docs/check drift | Fresh gate pass and refreshed evidence | Maintainers; manual task completion | candidate |
| Optional production attestation | N/A | Repository has no production deployment action | N/A with documented reason | Human product owner; scope change | N/A |
| Repository-local tools or skills | scripts/check.sh, scripts/smoke_mcp.sh | Reuse deterministic local workflows | Scripts run from repository root | Maintainers; command changes | candidate |
| Source-control context | git status --short --branch, git diff --check | Inspect current source state | Clean/understood diff and whitespace check | Maintainers; every checkpoint | candidate |
| Dependency/API references | docs/references/mcp-swift-sdk.md | Make upstream MCP behavior discoverable | Package and SDK contract agree | Maintainers; SDK update | candidate |
| Runtime start | swift run apple-debug-mcp | Launch local MCP process | Stdio process accepts MCP initialize | Maintainers; runtime changes | candidate |
| Runtime reset | Close stdin; make clean for build state | Stop process and remove local build artifacts | Process exits; .build reset | Maintainers; lifecycle changes | candidate |
| UI or API exercise | scripts/smoke_mcp.sh | Exercise MCP protocol and LLDB-DAP initialization | Initialize, tools/list, read-only tool calls, and adapter response | Maintainers; tool surface changes | candidate |
| Debug session lifecycle | apple_debug_session_create/list/close | Create, inspect, and close an owned LLDB-DAP adapter session | Session ID appears, then adapter exits after close | Maintainers; session policy changes | candidate |
| Debugger inspection | apple_debug_set_breakpoint, apple_debug_threads, apple_debug_stack_trace, apple_debug_read_memory, apple_debug_disassemble, apple_debug_continue | Route specialized debugger inspection commands through a session | Tool schemas and DAP request mapping compile and pass checks | Maintainers; DAP surface changes | candidate |
| iOS Simulator inventory | apple_simulator_list | Discover available Simulator devices without mutation | JSON inventory with UDIDs, runtime, state, and availability | Maintainers; Apple tooling changes | candidate |
| Physical-device inventory | apple_device_list | Discover CoreDevice identifiers and development authorization state | JSON inventory with pairing/tunnel evidence | Maintainers; device tooling changes | candidate |
| Xcode project workflow | apple_xcode_discover and apple_xcode_build | Discover project schemes and run explicit destination builds | Structured discovery or policy-gated build output | Maintainers; Xcode tooling changes | candidate |
| Authorized debug fixture | make fixture | Compile and ad-hoc sign the local macOS debugger target | Existing Mach-O binary with get-task-allow entitlement | Maintainers; fixture changes | candidate |
| Debugger fixture behavior | python3 scripts/debug_fixture_smoke.py | Prove authorized launch and core debugger inspection end to end | Breakpoint, threads, stack, memory, disassembly, continue, and cleanup transcript | Maintainers; debugger surface changes | candidate |
| Logs, metrics, or traces | stderr transcript; metrics/traces N/A | Diagnose CLI failures | Actionable stderr or justified N/A | Maintainers; runtime changes | candidate |
