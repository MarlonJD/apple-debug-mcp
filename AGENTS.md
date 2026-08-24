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

- Sources/AppleDebugCore/ owns platform capabilities and safe Xcode toolchain discovery.
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
| Full repository check | make check | Build, tests, smoke protocol, whitespace, and placeholder checks pass |
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
