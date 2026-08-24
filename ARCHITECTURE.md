# Apple Debug MCP Architecture

## System context

Apple Debug MCP is a local macOS command-line server that exposes safe, capability-aware Apple debugging operations through MCP. An MCP client launches it over stdio. The server will eventually coordinate LLDB/DAP, Mach-O analysis, Xcode, Simulator, and authorized physical-device workflows.

The current implementation is intentionally read-only: it reports the supported platform boundary, discovers allowlisted Xcode command-line tools, and initializes the local LLDB-DAP adapter. No debug target is launched, attached, terminated, or modified.

## Repository map

| Path | Responsibility | Owner or update trigger |
| --- | --- | --- |
| Package.swift | SwiftPM products and official MCP SDK dependency | Update when products or upstream SDK version changes |
| Sources/AppleDebugCore/ | Platform-neutral capability reports and safe toolchain probing | Apple Debug MCP maintainers; update when a platform capability changes |
| Sources/AppleDebugCore/DAP.swift | DAP value model, Content-Length framing, and LLDB-DAP session lifecycle | Apple Debug MCP maintainers; update with DAP/backend behavior |
| Sources/AppleDebugCore/MachO.swift | Read-only Mach-O and universal-binary header, architecture, load-command, and segment inspection | Apple Debug MCP maintainers; update with static-analysis behavior |
| Sources/AppleDebugMCP/ | MCP server startup and tool dispatch | Apple Debug MCP maintainers; update when MCP surface changes |
| Tests/AppleDebugCoreTests/ | Core behavior and platform-boundary tests | Update with core behavior changes |
| scripts/ | Build, smoke, and repository-native harness commands | Update when verification or lifecycle commands change |
| docs/ | Canonical product, architecture, security, reliability, and agent-workflow knowledge | Update with boundary or workflow changes |

## Components and boundaries

The executable depends on AppleDebugCore and the official Swift MCP SDK. AppleDebugCore does not depend on MCP, so capability policy and toolchain discovery remain testable without a transport.

Future backend boundaries are:

- LLDBBackend: LLDB/DAP session lifecycle and debugger state.
- MachOBackend: Mach-O, Objective-C, Swift metadata, symbols, strings, and disassembly.
- AppleToolingBackend: Xcode, simctl, devicectl, logs, and symbolication.
- SecurityPolicy: filesystem roots, target authorization, destructive-operation approvals, and audit events.

Backends may be added only behind capability checks. The MCP layer must not expose an operation that the active target cannot safely support.

## Data and control flow

1. The MCP client starts apple-debug-mcp as a stdio child process.
2. The server completes MCP initialization and advertises read-only tools.
3. apple_capabilities returns the platform capability matrix and explicit restrictions.
4. apple_toolchain_status runs only fixed, allowlisted Xcode discovery commands without a shell.
5. apple_lldb_dap_initialize starts LLDB-DAP, completes the initialize handshake, drains adapter events, and tears down the adapter.
6. apple_macho_inspect reads a regular, size-bounded Mach-O file without executing it and returns structured architecture/header/segment data.
7. Future debugger calls create a target session in the core, select a backend, enforce policy, and return structured observations.

## Runtime topology

The current topology is local macOS only. There is no hosted service, persistent database, production environment, or release deployment in this repository. iOS Simulator and physical-device workflows are future local capabilities and require Xcode/device authorization.

## Cross-cutting concerns

- Authentication: stdio inherits the MCP client process boundary; future HTTP transport must bind locally and require explicit authentication.
- Authorization: capability reports and SecurityPolicy gate target selection and mutating operations.
- Configuration: no secrets or persistent configuration are required by the current foundation.
- Telemetry: current tools return structured MCP results; long-lived logging, metrics, and traces are not yet applicable.
- Reliability: failed discovery returns an absent tool path, DAP probe failures tear down the adapter, and Mach-O input is regular-file and size-bounded before parsing.
- Licensing: project code is GPL-3.0-or-later under Burak Karahan; upstream dependencies retain their own licenses.

## Mechanically enforced invariants

| Invariant | Enforcer | Recovery guidance |
| --- | --- | --- |
| Toolchain discovery uses a fixed allowlist and no shell | ToolchainProbeTests plus ToolchainProbe implementation | Extend the allowlist and test when adding a tool |
| Every Apple target has an explicit capability report | CapabilitiesTests | Add the platform to AppleDebugPlatform.allCases and CapabilityMatrix |
| Physical iOS restrictions are visible in the public report | CapabilitiesTests | Update the restricted set and product/security docs together |
| Build, tests, MCP smoke protocol, whitespace, and placeholder checks stay green | scripts/check.sh | Run make check, then fix the first reported failure |
| Harness routes and documents remain complete | scripts/harness_check.sh plus the bundled harness cross-check | Repair the named route or update the active ExecPlan |

## Architecture decisions

- The official Swift MCP SDK is used for MCP framing and transport; the project does not reimplement JSON-RPC framing.
- SwiftPM is the initial build boundary because the server runs on macOS and must coordinate Apple developer tooling.
- Capability restrictions are represented as data, not hidden in client-specific prompts.
- The project starts with read-only discovery before adding debugger control or code mutation.
