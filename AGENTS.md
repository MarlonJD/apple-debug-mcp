# Apple Debug MCP Agent Guide

This repository is a Swift Package Manager command-line MCP server for authorized macOS and iOS debugging workflows.

## Start here

- Documentation map: [docs/index.md](docs/index.md)
- Current architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Product scope: [docs/product-specs/platform-scope.md](docs/product-specs/platform-scope.md)
- Plan policy: [docs/PLANS.md](docs/PLANS.md)
- Active work: [docs/exec-plans/index.md](docs/exec-plans/index.md)
- Agent harness: [docs/agent-harness/index.md](docs/agent-harness/index.md)

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
| iOS fixture | make ios-fixture | xcodebuild produces the Simulator app bundle and dSYM |
| iOS fixture smoke | make ios-fixture-smoke | Explicitly boot/install/launch/screenshot/terminate/shutdown a Simulator fixture |
| iOS debug fixture smoke | make ios-debug-fixture-smoke | Attach LLDB-DAP to the Simulator fixture and inspect its process |
| iOS MCP tool smoke | make ios-mcp-tool-smoke | Exercise public MCP Simulator lifecycle, launch flags, app metadata, container, screenshot, and cleanup |
| iOS UI tree/action smoke | make ios-ui-tree-smoke | Run the XCUITest accessibility and tap/typeText/swipe/wait bridge through the standalone MCP server |
| Arbitrary installed-app UI smoke | make ios-arbitrary-ui-smoke | Generate a UI-test-only project and inspect/action an installed Simulator app by bundle ID |
| DWARF smoke | make dwarf-smoke | Build the generic iOS fixture and verify typed dSYM DIE/source/line/statistics output |
| Performance analysis smoke | make performance-analysis-smoke | Capture a short Time Profiler trace and verify parsed rows, hotspots, and folded flame stacks |
| Unsigned macOS package | make package | Release-build the server and create a relocatable unsigned tar archive |
| Full repository check | make check | Build, all tests, smoke protocol, macOS debugger fixture, whitespace, and placeholder checks pass |
| Harness check | make harness-check | Project-native and harness structural checks pass |
| Run server | swift run apple-debug-mcp | MCP stdio process remains available until stdin closes |

## Working contract

- Read the relevant local documentation before editing.
- Keep AppleDebugCore independent of MCP transport details.
- Add process launch, attach, memory mutation, and device operations only behind explicit capabilities and permission policy.
- Do not treat a physical iOS device as an unrestricted desktop process; stock App Store applications are out of scope.
- Preserve unrelated changes and do not perform branch operations unless explicitly requested.
- Do not push, release, sign, notarize, or operate production infrastructure without explicit authorization.
- Use the active ExecPlan for cross-cutting work and keep it current.

## Definition of done

For repository changes, run make check, review the diff, update affected durable documentation, and report exact verification evidence. For harness changes, run make harness-check and distinguish verified locally from candidate-only or blocked.

## License

Source files are licensed under GPL-3.0-or-later. Copyright holder: Burak Karahan.
