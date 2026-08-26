# Apple Debug MCP Agent Guide

This repository is a Swift Package Manager command-line MCP server for authorized macOS and iOS debugging workflows.

## Start here

- Documentation map: [docs/index.md](docs/index.md)
- Current architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Product scope: [docs/product-specs/platform-scope.md](docs/product-specs/platform-scope.md)
- Plan policy: [docs/PLANS.md](docs/PLANS.md)
- Active work: [docs/exec-plans/index.md](docs/exec-plans/index.md)
- Agent harness: [docs/agent-harness/index.md](docs/agent-harness/index.md)
- Agent command catalog: [docs/agent-harness/registry.md](docs/agent-harness/registry.md)

## Repository orientation

- Sources/AppleDebugCore/ owns platform capabilities, policy gates, DAP sessions, artifact analysis, and Apple-tool adapters.
- Sources/AppleDebugMCP/ owns the MCP server entry point and tool registry.
- Tests/AppleDebugCoreTests/ owns deterministic core behavior tests.
- scripts/ owns repeatable build, smoke, and harness checks.
- docs/ owns durable architecture, product, security, reliability, and agent-workflow knowledge.

## Commands

| Intent | Command | Expected evidence |
| --- | --- | --- |
| Resolve and build | swift build | SwiftPM exits 0 and produces apple-debug-mcp |
| Focused tests | swift test --filter CapabilitiesTests | XCTest exits 0 |
| Authorized fixture | make fixture | clang/codesign produces the get-task-allow fixture binary |
| macOS MCP debugger workflow | make mcp-mac-debug-workflow-smoke | Real stdio MCP flow covers launch, stop inspection, memory patch/rollback, policy rejection, failed-launch cleanup, and a bounded JSON evidence manifest |
| iOS fixture | make ios-fixture | xcodebuild produces the Simulator app bundle and dSYM |
| iOS fixture smoke | make ios-fixture-smoke | Explicitly boot/install/launch/screenshot/terminate/shutdown a Simulator fixture |
| iOS debug fixture smoke | make ios-debug-fixture-smoke | Attach LLDB-DAP to the Simulator fixture and inspect its process |
| iOS MCP tool smoke | make ios-mcp-tool-smoke | Exercise public MCP Simulator lifecycle, launch flags, app metadata, container, screenshot, and cleanup |
| MCP daemon smoke | make mcp-daemon-smoke | Exercise the authenticated loopback HTTP daemon, endpoint discovery, MCP session routing, and graceful cleanup |
| iOS UI tree/action smoke | make ios-ui-tree-smoke | Run the XCUITest accessibility and tap/typeText/swipe/wait bridge through the standalone MCP server |
| Arbitrary installed-app UI smoke | make ios-arbitrary-ui-smoke | Generate a UI-test-only project and inspect/action an installed Simulator app by bundle ID |
| DWARF smoke | make dwarf-smoke | Build the generic iOS fixture and verify typed dSYM DIE/source/line/statistics output |
| Performance analysis smoke | make performance-analysis-smoke | Capture a short Time Profiler trace and verify parsed rows, hotspots, and folded flame stacks |
| Runtime diagnostics smoke | make runtime-diagnostics-smoke | Run bounded heap, leaks, and sample reports against an authorized local process |
| Assembler smoke | make assembler-smoke | Assemble arm64/x86_64 source and verify bytes plus disassembly |
| Reverse boundary smoke | make reverse-capability-smoke | Verify Apple LLDB reverse/time-travel and kernel memory capabilities fail closed |
| Control-flow smoke | make control-flow-smoke | Build a Mach-O CFG/basic-block/call-graph report |
| Memory-map smoke | make memory-map-smoke | Capture typed vmmap regions and snapshot diffs |
| Simulator environment smoke | make simulator-environment-smoke | Exercise bounded Simulator UI/status/pasteboard/privacy controls |
| Repro bundle smoke | make repro-bundle-smoke | Capture screenshot/appinfo/manifest evidence for an installed Simulator app |
| Signing audit smoke | make signing-audit-smoke | Audit codesign identity, entitlements, authorities, and Gatekeeper output |
| Patch workflow smoke | make patch-workflow-smoke | Verify non-destructive assembly preview and re-sign plan generation |
| Plugin smoke | make plugin-smoke | Discover explicit plugin manifests without executing code |
| Plugin XPC smoke | make plugin-xpc-smoke | Build a signed App Sandbox XPC plugin fixture and verify bounded protocol execution |
| Workbench build smoke | make workbench-build-smoke | Build the native macOS SwiftUI workbench executable |
| Unsigned macOS package | make package | Release-build the server and create a relocatable unsigned tar archive |
| Full repository check | make check | Build, all tests, smoke protocol, macOS debugger fixture, whitespace, and placeholder checks pass |
| Harness check | make harness-check | Project-native and harness structural checks pass |
| Verification tiers | make pr-check; make host-integration-check; make simulator-check; make physical-device-check | Run deterministic PR, host, Simulator, or explicitly authorized physical-device validation; see docs/product-specs/compatibility-matrix.md |
| Harness contract only | python3 scripts/harness_contract.py | Read-only authority, plan, coverage/evidence, registry, route, and maintenance checks pass |
| Run server | swift run apple-debug-mcp | MCP stdio process remains available until stdin closes; `swift run apple-debug-mcp --daemon` publishes an authenticated loopback endpoint |

## Working contract

- Read the relevant local documentation before editing.
- Keep AppleDebugCore independent of MCP transport details.
- Add process launch, attach, memory mutation, and device operations only behind explicit capabilities and permission policy.
- Do not treat a physical iOS device as an unrestricted desktop process; stock App Store applications are out of scope.
- The supervised daemon binds only to `127.0.0.1`, requires the private endpoint bearer token, and writes endpoint metadata with user-only permissions.
- Preserve unrelated changes and do not perform branch operations unless explicitly requested.
- Do not push, release, sign, notarize, or operate production infrastructure without explicit authorization.
- Use the active ExecPlan for cross-cutting work and keep it current.

## Definition of done

For repository changes, run make check, review the diff, update affected durable documentation, and report exact verification evidence. For harness changes, run make harness-check and distinguish verified locally from candidate-only or blocked.

## License

Source files are licensed under GPL-3.0-or-later. Copyright holder: Burak Karahan.
